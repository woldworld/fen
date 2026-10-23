// 邮箱工具（0.64.0）离线断言
//
// 为什么要有这个脚本 —— 三条判据在**别处照不到**：
//
//   ① **迁移落没落地**：`schemaVersion` 必须等于 `_migrations` 最大键、且 V37 真建了三张表。
//      （历史事故：`schemaVersion=32` 生效但迁移表项没写进去 ⇒ 只在老库升级路径炸。）
//   ② **红线在结构上**：`mail_accounts` 里**不许有凭据列**；邮箱三表**不许有**
//      转让/兑现/收益类列（PRD §9.1）。这两条只能靠读建表语句钉住。
//   ③ **权限承诺没被打破**：`mail_send` 必须是 `critical`、且必须在
//      `neverAllowlist` 里（否则"每次弹窗"是假的）；critical 审计必须先脱敏
//      （否则邮件正文明文进审计表）。
//
// 另外把**协议实现**在离线环境真跑一遍：IMAP 用预置字节流驱动（含 `{n}` 字面量），
// SMTP 用脚本化响应驱动 —— 这两条是"能编译 ≠ 能说话"的区别。
//
// 用法：`dart run tool/verify_mail_tools.dart`（退出码 0 = 全过）

import 'dart:convert';
import 'dart:io';

import 'package:dahuang_ai/core/mail/imap_client.dart';
import 'package:dahuang_ai/core/mail/mail_transport.dart';
import 'package:dahuang_ai/core/mail/mail_types.dart';
import 'package:dahuang_ai/core/mail/mime_codec.dart';
import 'package:dahuang_ai/core/mail/smtp_client.dart';

int _pass = 0;
int _fail = 0;
final List<String> _failures = [];

void check(bool cond, String label) {
  if (cond) {
    _pass++;
  } else {
    _fail++;
    _failures.add(label);
    print('  ✗ $label');
  }
}

String _read(String p) => File(p).readAsStringSync();

/// 掐掉注释，避免"注释里写了关键字"把断言骗过。
String _stripComments(String s) {
  final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return noBlock
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

/// 截取某方法体（花括号配平；容忍命名参数花括号）。
String? _methodBody(String src, String signature) {
  final start = src.indexOf(signature);
  if (start < 0) return null;
  final open = src.indexOf('{', start);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    final c = src[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return src.substring(open, i + 1);
    }
  }
  return null;
}

/// 从 CREATE TABLE 语句里取列名（用于"不许有某列"的断言）。
List<String> _columnsOfCreate(String sql) {
  final open = sql.indexOf('(');
  final close = sql.lastIndexOf(')');
  if (open < 0 || close <= open) return const [];
  final body = sql.substring(open + 1, close);
  final cols = <String>[];
  for (final rawLine in body.split(',')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final upper = line.toUpperCase();
    if (upper.startsWith('PRIMARY KEY') ||
        upper.startsWith('UNIQUE') ||
        upper.startsWith('FOREIGN KEY') ||
        upper.startsWith('CHECK')) {
      continue;
    }
    cols.add(line.split(RegExp(r'\s+')).first);
  }
  return cols;
}

/// 迁移表已注册的键（升序）。
List<int> _migrationKeys(String dbHelper) => RegExp(
        r'^\s*(\d+):\s*_migrateV(\d+),',
        multiLine: true)
    .allMatches(dbHelper)
    .map((m) => int.parse(m.group(1)!))
    .toList()
  ..sort();

int? _declaredVersion(String dbHelper) => int.tryParse(
    RegExp(r'schemaVersion\s*=\s*(\d+)').firstMatch(dbHelper)?.group(1) ?? '');

// ★ 三个"可被判出"的谓词 —— 抽出来才能做正对照（自检）。
bool versionInconsistent(String dbHelper) {
  final d = _declaredVersion(dbHelper);
  final keys = _migrationKeys(dbHelper);
  if (d == null || keys.isEmpty) return true;
  return d != keys.last;
}

bool auditLeaksRawArgs(String policySrc) =>
    policySrc.contains(r"draftText: '${tool.name} $args'");

bool allowlistUnprotected(String policySrc) =>
    !policySrc.contains("neverAllowlist = {'mail_send'}");

/// 预置里是否**六台主机齐备**（163/126/QQ 各 imap+smtp）。
///
/// ★ 钉的是**数据**（主机字面量）而不是符号名：改个变量名不该让断言失效，
///   而漏掉一家服务商必须被判出。
bool hasAllPresetHosts(String screenSrc) => const [
      "'imap.163.com'",
      "'smtp.163.com'",
      "'imap.126.com'",
      "'smtp.126.com'",
      "'imap.qq.com'",
      "'smtp.qq.com'",
    ].every(screenSrc.contains);

/// 地址域名表是否覆盖国内三家 + Gmail（这是"输入地址即自动匹配"的依据）。
bool hasAutoMatchDomains(String screenSrc) => const [
      "'163.com'",
      "'126.com'",
      "'qq.com'",
      "'gmail.com'",
    ].every(screenSrc.contains);

/// 是否仍把 Gmail 服务器**当默认预填**（真机截图"163 地址 + Office365 服务器"事故）。
bool defaultsToGmailServers(String screenSrc) =>
    screenSrc.contains("TextEditingController(text: 'imap.gmail.com')") ||
    screenSrc.contains("TextEditingController(text: 'smtp.gmail.com')");

/// `mail_read` 是否把**信封也包进了**同一处 `wrapUntrusted`（0.90.0 · 专家 #1）。
///
/// 判据 = `return wrapUntrusted(` —— 即整个返回值（含发件人/主题等信封）走包裹，
/// 而不是 `return '发件人：…${wrapUntrusted(正文)}'`（信封裸奔）。正控见 caller。
bool envelopeWrapped(String readBlock) =>
    RegExp(r'return\s+wrapUntrusted\(').hasMatch(readBlock);

/// 取 ARB 里某个键的字符串值（用于"是否英文占位"的比对；取不到 = 空串）。
String arbValue(String src, String key) {
  final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(src);
  return m?.group(1) ?? '';
}

// ---------------------------------------------------------------------------

Future<void> main() async {
  final dbHelper = _stripComments(_read('lib/core/db_helper.dart'));
  final policy =
      _stripComments(_read('lib/harness_host/harness_permission_policy.dart'));
  final agent = _stripComments(_read('lib/core/agent_service.dart'));
  final tools = _stripComments(_read('lib/core/mail/mail_tools.dart'));
  final creds =
      _stripComments(_read('lib/core/mail/mail_credential_store.dart'));
  final pubspec = _read('pubspec.yaml');
  final appEvents = _stripComments(_read('lib/core/app_events.dart'));
  final mainDart = _stripComments(_read('lib/main.dart'));
  final mailScreen = _stripComments(_read('lib/ui/mail_account_screen.dart'));
  // 0.90.0（专家 #1/#2/#5/#6/#8）
  final mailTypes = _stripComments(_read('lib/core/mail/mail_types.dart'));
  final storeDb = _stripComments(_read('lib/core/mail/mail_store_db.dart'));
  final toolSpec = _stripComments(
      _read('packages/pocket_harness/lib/src/tools/tool_spec.dart'));
  final toolBridge = _stripComments(
      _read('packages/pocket_harness/lib/src/tools/tool_bridge.dart'));

  // ========================= ① 迁移 =========================
  final declared = _declaredVersion(dbHelper);
  final migKeys = _migrationKeys(dbHelper);
  check(declared != null && migKeys.isNotEmpty, '（前提）解析到 schemaVersion 与迁移表');
  check(!versionInconsistent(dbHelper),
      'schemaVersion($declared) == 迁移表最大键(${migKeys.isEmpty ? '?' : migKeys.last})');
  check(migKeys.contains(37), '_migrations 注册了 37');

  final v37 = _methodBody(dbHelper, 'static Future<void> _migrateV37(');
  check(v37 != null, '_migrateV37 方法体找得到');
  if (v37 != null) {
    for (final t in const ['mail_accounts', 'mail_seen', 'mail_outbox']) {
      check(v37.contains(t), '_migrateV37 建 $t');
    }

    final accCreate = RegExp(
            r'CREATE TABLE IF NOT EXISTS mail_accounts\([\s\S]*?\)',
            caseSensitive: false)
        .firstMatch(v37)
        ?.group(0) ??
        '';
    check(accCreate.isNotEmpty, '（前提）取到 mail_accounts 建表语句');
    final accCols = _columnsOfCreate(accCreate);
    check(accCols.contains('address'), '（前提）列解析器真取到了列（拿到 address）');
    for (final forbidden in const [
      'password',
      'passwd',
      'pwd',
      'secret',
      'token',
      'refresh_token',
      'access_token',
      'credential',
      'app_password',
      'private_key',
    ]) {
      check(!accCols.contains(forbidden),
          '红线：mail_accounts 不得有凭据列 $forbidden');
    }

    for (final forbidden in const [
      'owner_id',
      'to_pub',
      'redeem_at',
      'transfer_to',
      'payout_cents',
      'sell_price',
      'royalty',
      'price_cents',
    ]) {
      check(!v37.contains(forbidden),
          '红线：邮箱三表不得出现 $forbidden（可转让/可兑现，PRD §9.1）');
    }

    check(v37.contains('preview'), 'mail_outbox 只存 preview 摘要');
    check(!v37.contains('body_text') && !v37.contains('body_full'),
        'mail_outbox 不得有正文全文列');
  }

  // ========================= ② 权限与审计 =========================
  String toolBlock(String name) {
    final i = tools.indexOf("name: '$name'");
    if (i < 0) return '';
    final next = tools.indexOf('ToolSpec(', i + 10);
    return tools.substring(i, next < 0 ? tools.length : next);
  }

  check(toolBlock('mail_send').contains('PermissionLevel.critical'),
      'mail_send 档位 = critical');
  check(
      toolBlock('mail_list').contains('PermissionLevel.sensitive') &&
          toolBlock('mail_list').contains('kMailReadGrantKey'),
      'mail_list 档位 = sensitive 且共享读信授权键');
  check(
      toolBlock('mail_read').contains('PermissionLevel.sensitive') &&
          toolBlock('mail_read').contains('kMailReadGrantKey'),
      'mail_read 档位 = sensitive 且共享读信授权键');
  check(toolBlock('mail_draft').contains('PermissionLevel.normal'),
      'mail_draft 档位 = normal（只写本地，不出网）');

  check(!allowlistUnprotected(policy),
      '★ mail_send 在 neverAllowlist（不可加入免弹窗白名单）');
  check(policy.contains('!neverAllowlist.contains(tool.name)'),
      '★ 白名单查询已被 neverAllowlist 拦住');

  check(policy.contains('_redactForAudit'), 'policy 引入 _redactForAudit');
  check(!auditLeaksRawArgs(policy),
      '★ critical 审计不再直接写全文参数（正文不入审计表）');
  check(_methodBody(policy, 'static String _redactForAudit(') != null,
      '_redactForAudit 方法体找得到');
  // 脱敏清单是**另一个声明**（`_auditSensitiveKeys`），不在方法体里 ——
  // 先取它的集合字面量，再断言关键项（施工时踩过：查方法体永远为空）
  final keysDecl = RegExp(r'_auditSensitiveKeys\s*=\s*\{([\s\S]*?)\}')
          .firstMatch(policy)
          ?.group(1) ??
      '';
  check(keysDecl.contains("'body'"), '脱敏清单含 body（邮件正文）');
  check(keysDecl.contains("'token'"), '脱敏清单含 token');
  check(keysDecl.contains("'password'"), '脱敏清单含 password');

  check(agent.contains('_builtinCaps'), 'agent_service 引入内置工具能力表');
  check(
      RegExp(r'_builtinCaps[\s\S]{0,220}PluginCapability\.network')
          .hasMatch(agent),
      '★ 内置工具能力表把读信一组登记为 network（不再误报本地）');

  check(agent.contains('buildMailTools('), 'agent_service 注册了邮件工具组');
  check(RegExp(r'buildMailTools\([\s\S]{0,500}isTrialMode').hasMatch(agent),
      '★ 邮件工具接入了 isTrialMode（0.82.0 起为**试用可见告知**，非互斥门）');
  // ★ 0.82.0 改判：0.64.0 的 `trialRefusal()`（硬拒绝）已删——主人反馈"试用期不让
  //   操作邮箱不合理" ⇒ 改为放行 + 每轮可见告知。判据随之改为钉**告知**实现，
  //   并**反证**旧的拒绝语已不存在（防"改了调用点、忘了删旧函数"的僵尸分支）。
  check(tools.contains('withTrialNotice'), 'mail_tools 提供试用可见告知包装（放行，不拒绝）');
  check(tools.contains('trialNotice'), 'mail_tools 明确试用下内容经官方服务器转发');
  check(!tools.contains('trialRefusal'), '★ 旧的试用硬拒绝（trialRefusal）已彻底移除');

  check(tools.contains('wrapUntrusted('), '读信正文经 wrapUntrusted 包裹');
  check(
      RegExp(r'buildMailTools\([\s\S]{0,400}wrapUntrusted: _wrapUntrusted')
          .hasMatch(agent),
      '宿主把 _wrapUntrusted 注入进邮件工具');

  check(appEvents.contains('sendMail'), 'app_events 定义 PermissionAction.sendMail');
  check(policy.contains("case 'mail_send':"), 'policy 为 mail_send 定制弹窗/拒绝文案');
  check(policy.contains('PermissionAction.sendMail'),
      '★ mail_send 弹窗带收件人（操作码 send-mail）');
  check(mainDart.contains('l10n.permActionSendMail'), 'main.dart 渲染 send-mail 文案');

  // ========================= ③ 数据只在手机 / 无新增依赖 =========================
  check(!creds.contains('DBHelper'), '凭据存储不碰数据库');
  check(!creds.contains('CloudService') && !creds.contains('httpClient'),
      '凭据存储不出网');
  check(creds.contains('mail_credential_scheme'), '凭据存储带迁移标记');

  for (final forbiddenDep in const [
    'enough_mail',
    'mailer',
    'dartimap',
    'flutter_imap',
    'googleapis',
    'google_sign_in',
    'flutter_secure_storage',
  ]) {
    check(!pubspec.contains(forbiddenDep), 'pubspec 未引入邮件/OAuth 依赖 $forbiddenDep');
  }
  for (final forbidden in const ['CloudService', 'world_service', 'hub/']) {
    check(!tools.contains(forbidden),
        '邮件工具不依赖服务端代理（不得出现 $forbidden）');
  }

  // ========================= ④ 纯函数真跑 =========================
  check(isPlausibleEmail('a@b.com'), '地址：常规通过');
  check(isPlausibleEmail('first.last+tag@gmail.com'), '地址：点/加号通过');
  check(!isPlausibleEmail('a@b'), '地址：无 TLD 拒绝');
  check(!isPlausibleEmail('a b@c.com'), '地址：含空格拒绝');
  check(!isPlausibleEmail('a@b.com\nBcc: x@y.com'), '地址：换行注入拒绝');
  check(!isPlausibleEmail('a@@b.com'), '地址：双 @ 拒绝');
  check(!isPlausibleEmail('@b.com'), '地址：空 local 拒绝');
  check(!isPlausibleEmail('a@.com'), '地址：空标签拒绝');

  check(hasHeaderInjection('hi\r\nBcc: x@y.com'), '头注入：CRLF 被识别');
  check(!hasHeaderInjection('hi there'), '头注入：正常文本不误报');

  check(isPublicHost('imap.gmail.com'), '主机：公网域名通过');
  check(!isPublicHost('localhost'), '主机：localhost 拒绝');
  check(!isPublicHost('127.0.0.1'), '主机：127.0.0.1 拒绝');
  check(!isPublicHost('10.0.0.5'), '主机：10/8 拒绝');
  check(!isPublicHost('192.168.1.9'), '主机：192.168 拒绝');
  check(!isPublicHost('172.16.0.1'), '主机：172.16 拒绝');
  check(!isPublicHost('169.254.169.254'), '主机：链路本地（云元数据）拒绝');
  check(isPublicHost('8.8.8.8'), '主机：公网 IP 通过');

  check(decodeEncodedWords('=?UTF-8?B?5L2g5aW9?=') == '你好', 'RFC2047：B 编码');
  check(decodeEncodedWords('=?UTF-8?Q?hello_=E4=BD=A0?=') == 'hello 你',
      'RFC2047：Q 编码（下划线=空格，=XX 十六进制）');
  check(decodeEncodedWords('plain subject') == 'plain subject', 'RFC2047：无编码原样');
  check(decodeEncodedWords('=?UTF-8?B?5L2g?= =?UTF-8?B?5aW9?=') == '你好',
      'RFC2047：相邻编码字之间的空白必须丢弃');

  check(
      utf8.decode(decodeTransfer(base64.encode(utf8.encode('中文')), 'base64')) ==
          '中文',
      '传输编码：base64');
  check(utf8.decode(decodeTransfer('a=3Db=0A', 'quoted-printable')) == 'a=b\n',
      '传输编码：QP 的 =3D/=0A');
  check(
      utf8.decode(decodeTransfer('line=\r\nnext', 'quoted-printable')) ==
          'linenext',
      '传输编码：QP 软换行');
  check(utf8.decode(decodeTransfer('raw', '7bit')) == 'raw', '传输编码：7bit 原样');

  const rawMail = 'From: A <a@x.com>\r\n'
      'Subject: =?UTF-8?B?5L2g5aW9?=\r\n'
      'Content-Type: multipart/alternative; boundary="BND"\r\n'
      '\r\n'
      '--BND\r\n'
      'Content-Type: text/plain; charset=UTF-8\r\n'
      '\r\n'
      '纯文本正文\r\n'
      '--BND\r\n'
      'Content-Type: text/html; charset=UTF-8\r\n'
      '\r\n'
      '<p>HTML <b>正文</b></p>\r\n'
      '--BND--\r\n';
  final node = parseMessage(rawMail);
  check(node.isMultipart, 'multipart：识别为 multipart');
  check(node.children.length == 2, 'multipart：拆出 2 个 part');
  check(extractPlainText(node) == '纯文本正文', '正文挑选：优先 text/plain');

  const boilerplate = 'Content-Type: multipart/alternative; boundary="B"\r\n'
      '\r\n'
      '--B\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n'
      'View this email in your browser\r\n'
      '--B\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n'
      '<p>真正的正文</p>\r\n'
      '--B--\r\n';
  check(extractPlainText(parseMessage(boilerplate)).contains('真正的正文'),
      '正文挑选：样板 text/plain 时回落到 HTML');

  const withAtt = 'Content-Type: multipart/mixed; boundary="M"\r\n\r\n'
      '--M\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nhi\r\n'
      '--M\r\nContent-Type: application/pdf; name="a.pdf"\r\n'
      'Content-Disposition: attachment; filename="=?UTF-8?B?5oql5ZGK?=.pdf"\r\n\r\n'
      'JVBERi0=\r\n--M--\r\n';
  final atts = attachmentNames(parseMessage(withAtt));
  check(atts.length == 1 && atts.first.contains('报告'),
      '附件：只取（解码后的）文件名，不取内容');

  final msg = buildRfc5322(
    from: 'me@gmail.com',
    to: ['you@example.com'],
    subject: '=?UTF-8?B?5L2g5aW9?=',
    body: '第一行\n第二行',
    now: DateTime(2026, 10, 8, 8, 30, 0),
  );
  check(msg.contains('From: me@gmail.com\r\n'), '报文：From 头');
  check(msg.contains('To: you@example.com\r\n'), '报文：To 头');
  check(msg.contains('Content-Transfer-Encoding: base64'), '报文：正文走 base64');
  check(msg.contains('Message-ID: <'), '报文：带 Message-ID');
  check(!msg.contains('第一行'), '报文：正文不进明文（base64 编码）');
  final bodyPart = msg.split('\r\n\r\n').last.trim();
  check(
      utf8.decode(base64.decode(bodyPart.replaceAll('\r\n', ''))) ==
          '第一行\n第二行',
      '报文：正文可无损还原');
  check(!RegExp(r'^\.$', multiLine: true).hasMatch(msg),
      '报文：不该出现行首单点（base64 天然免疫 dot-stuffing）');

  check(encodeHeaderValue('hello') == 'hello', '头部编码：纯 ASCII 不编码');
  check(encodeHeaderValue('你好').startsWith('=?UTF-8?B?'),
      '头部编码：非 ASCII 走 RFC2047');
  check(!encodeHeaderValue('你好' * 40).contains('\n\n'),
      '头部编码：长值折行不产生空行（否则会提前结束头部区）');

  // ========================= ⑤ 协议真跑（离线驱动） =========================
  await _probeImapSession();
  await _probeImapNoId();
  await _probeImapCredEscape();
  await _probeSmtpSession();

  // ========================= ⑦ 绑定页：163/126/QQ + 地址自动匹配 =========================
  check(hasAllPresetHosts(mailScreen),
      '★ 预置含国内三家（163/126/QQ 的 imap+smtp 主机齐备）');
  check(hasAutoMatchDomains(mailScreen),
      '★ 地址域名表覆盖 163/126/qq/gmail（输入地址即可自动匹配服务器）');
  check(!defaultsToGmailServers(mailScreen),
      '★ 服务器字段不再预填 Gmail 默认（真机截图"163 地址 + Office365 服务器"事故）');
  check(
      mailScreen.contains('_serversTouched') &&
          mailScreen.contains('_markServersTouched'),
      '手动改过服务器后停用自动覆盖（页面明说"自动/手动"两态）');
  check(
      mailScreen.contains('mailAutoFilled') &&
          mailScreen.contains('mailNeedServers') &&
          mailScreen.contains('mailManualServers'),
      '页面为"自动填入 / 需填服务器 / 已手动"三个状态都留了文案出口');

  // 五语种：新键必须都在，且 zh/zh_Hant/ja/vi **不得是英文占位**。
  const newMailKeys = [
    'mailAppPasswordHintGmail',
    'mailAppPasswordHintNetease',
    'mailAppPasswordHintQQ',
    'mailAppPasswordHintOutlook',
    'mailAutoFilled',
    'mailManualServers',
    'mailNeedServers',
    'mailErrAuth',
    'mailErrUnsafe',
  ];
  final enArb = _read('lib/l10n/app_en.arb');
  for (final lang in const ['en', 'zh', 'zh_Hant', 'ja', 'vi']) {
    final src = _read('lib/l10n/app_$lang.arb');
    final missing = newMailKeys.where((k) => arbValue(src, k).isEmpty).toList();
    check(missing.isEmpty, 'app_$lang.arb 含全部新邮箱键（缺：$missing）');
  }
  for (final lang in const ['zh', 'zh_Hant', 'ja', 'vi']) {
    final src = _read('lib/l10n/app_$lang.arb');
    final same =
        newMailKeys.where((k) => arbValue(src, k) == arbValue(enArb, k)).toList();
    check(same.isEmpty, '★ app_$lang.arb 新键是真译文，非英文占位（同值：$same）');
  }

  // ============ ⑧ 0.90.0 · 专家 #1/#2/#3/#5/#6/#8 ============

  // #1 信封也是外部不可信输入 ⇒ 与正文一并包裹
  check(envelopeWrapped(toolBlock('mail_read')),
      '★ mail_read：信封（发件人/收件人/主题/日期/附件）与正文一并 wrapUntrusted');
  check(toolBlock('mail_list').contains('wrapUntrusted('),
      '★ mail_list：信封行（主题/发件人/日期）经 wrapUntrusted 包裹');
  check(envelopeWrapped("return wrapUntrusted('发件人：' + from);"),
      '自检⑨a：包裹信封的写法被认作已包');
  check(!envelopeWrapped(r"return '发件人：${body.from}\n${wrapUntrusted(text)}';"),
      '自检⑨b：信封裸奔、只包正文必须被判出');

  // #3 只给 draft_id 而不给 body ⇒ 拒绝（不再静默发预览截断）
  check(toolBlock('mail_send').contains('缺少正文'),
      '★ mail_send：缺 body 时**拒绝**（不再静默发预览截断）');
  check(!tools.contains('?? draft.preview'),
      '★ mail_send：旧的 `?? draft.preview` 静默降级已移除');

  // #2 工具级整体 deadline
  check(tools.contains('kMailToolTimeout'), 'mail_tools 定义整体超时常量 kMailToolTimeout');
  for (final n in const ['mail_list', 'mail_read', 'mail_send']) {
    check(toolBlock(n).contains('callTimeout: kMailToolTimeout'),
        '★ $n 设了工具级整体超时（专家 #2）');
  }
  check(toolSpec.contains('callTimeout'), 'ToolSpec 暴露 callTimeout 字段');
  check(
      toolBridge.contains('callTimeout') && toolBridge.contains('TimeoutException'),
      '★ bridgeTool 在工具级落实超时（含 TimeoutException 收口）');

  // #5 hasTools 与 _agent.tools 同源（一次快照两处共用）
  check(agent.contains('_agentHasTools'), 'agent_service 引入 _agentHasTools');
  check(agent.contains('hasTools: () => _agentHasTools'),
      '★ hasTools 读 _agentHasTools（不再即时快照）');
  check(
      RegExp(r'_rebuildAgent[\s\S]{0,400}_agentHasTools\s*=\s*snapshot\.isNotEmpty')
          .hasMatch(agent),
      '★ _rebuildAgent 用同一快照写 _agentHasTools');

  // #6 死代码移除
  check(!mailTypes.contains('looksLikeAppPassword'),
      '★ 死代码 looksLikeAppPassword 已移除（全仓零引用）');

  // #8 台账滚动裁剪
  check(storeDb.contains('pruneOutbox') && storeDb.contains('keepOutboxMax'),
      '★ 出站台账滚动裁剪（pruneOutbox / keepOutboxMax）');
  check(RegExp(r'insertDraft[\s\S]{0,1200}pruneOutbox\(').hasMatch(storeDb),
      '★ insertDraft 写入后顺手裁剪台账');

  // #8 真跑：日期分量自洽（跨零点不差一天）
  final utcT = DateTime.utc(2026, 10, 8, 23, 30, 0);
  final lt = utcT.toLocal();
  String pad2(int n) => n.toString().padLeft(2, '0');
  const moAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  check(
      rfc5322Date(utcT).contains('${pad2(lt.day)} ${moAbbr[lt.month - 1]} ${lt.year} '
          '${pad2(lt.hour)}:${pad2(lt.minute)}:${pad2(lt.second)}'),
      '★ rfc5322Date：日期与时间取同一（本地）分量，跨零点不差一天');

  // #8 真跑：中文主题走 RFC 2047
  final cnMsg = buildRfc5322(
    from: 'me@gmail.com',
    to: ['you@example.com'],
    subject: '会议纪要',
    body: 'x',
    now: DateTime(2026, 10, 8, 8, 30, 0),
  );
  check(cnMsg.contains('Subject: =?UTF-8?B?'), '★ 报文：中文主题走 RFC 2047 编码');
  check(!cnMsg.contains('Subject: 会议纪要'), '★ 报文：主题不以非 ASCII 原文出头部');
  final asciiMsg = buildRfc5322(
    from: 'a@b.com',
    to: ['c@d.com'],
    subject: 'Hello',
    body: 'x',
    now: DateTime(2026, 10, 8, 8, 30, 0),
  );
  check(asciiMsg.contains('Subject: Hello\r\n'), '报文：ASCII 主题原样不编码');

  // ========================= ⑥ 自检（positive control） =========================
  final brokenVer = dbHelper.replaceFirst(
      RegExp(r'schemaVersion\s*=\s*\d+'), 'schemaVersion = 99');
  check(!versionInconsistent(dbHelper), '自检⓪：原文件版本一致（前提成立）');
  check(versionInconsistent(brokenVer),
      '自检①：版本号与迁移表不一致必须被判出');
  check(allowlistUnprotected(policy.replaceFirst(
      "neverAllowlist = {'mail_send'}", 'neverAllowlist = {}')),
      '自检②：neverAllowlist 被清空必须被判出');
  const legacyAuditLine =
      r"""await DBHelper.insertAudit(draftText: '${tool.name} $args',);""";
  check(auditLeaksRawArgs(legacyAuditLine),
      '自检③：未脱敏的审计写法必须被判出');
  check(
      _columnsOfCreate(
              'CREATE TABLE IF NOT EXISTS mail_accounts(id TEXT, password TEXT)')
          .contains('password'),
      '自检④：列解析器真能取到列名（否则"无凭据列"是空断言）');
  check(
      !hasAllPresetHosts("_Preset('gmail','Gmail',['gmail.com'],'imap.gmail.com',"
          "993,'smtp.gmail.com',465,MailSecurity.tls)"),
      '自检⑤：只留 Gmail 预置必须被判出（163/126/QQ 缺失）');
  check(!hasAutoMatchDomains("_Preset('gmail','Gmail',['gmail.com'], ...)"),
      '自检⑥：域名表缺 163/126/qq 必须被判出');
  check(
      defaultsToGmailServers(
          "final _imapHost = TextEditingController(text: 'imap.gmail.com');"),
      '自检⑦：预填 Gmail 默认必须被判出');
  check(
      arbValue('{"mailNeedServers": "x"}', 'mailNeedServers') == 'x' &&
          arbValue('{"a": 1}', 'mailNeedServers').isEmpty,
      '自检⑧：ARB 取值器真能取到值（否则"键齐备"是空断言）');

  // ========================= 汇总 =========================
  print('');
  print('—' * 60);
  if (_fail == 0) {
    print('✅ 邮箱工具离线断言全过（$_pass 项）');
  } else {
    print('❌ 失败 $_fail 项 / 共 ${_pass + _fail} 项');
    for (final f in _failures) {
      print('   · $f');
    }
  }
  // ★ 末行必须是汇总器认得的 `PASS=n FAIL=m`（`tool/run_all_verify.dart` 靠它抓读数）。
  //   ★ 教训：本条最初只打印「✅ …（128 项）」，汇总器抓不到 ⇒ 表里显示 `0 0`、
  //   这 128 项**根本没被计入交付总数**（读数被静默漏算）。格式不是审美问题（同技能 §2）。
  print('PASS=$_pass FAIL=$_fail');
  exit(_fail == 0 ? 0 : 1);
}

// ---------------------------------------------------------------------------
// IMAP：用预置字节流驱动完整会话（含 `{n}` 字面量）
// ---------------------------------------------------------------------------
Future<void> _probeImapSession() async {
  final headers1 = 'Subject: =?UTF-8?B?5L2g5aW9?=\r\n'
      'From: Alice <alice@example.com>\r\n'
      'Date: Mon, 06 Oct 2026 09:00:00 +0800\r\n';
  final headers2 = 'Subject: Second\r\n'
      'From: Bob <bob@example.com>\r\n'
      'Date: Mon, 06 Oct 2026 10:00:00 +0800\r\n';
  final h1 = utf8.encode(headers1).length;
  final h2 = utf8.encode(headers2).length;

  // ★ 命令序列 = LOGIN(a1) → CAPABILITY(a2) → ID(a3) → SELECT(a4) →
  //   UID SEARCH(a5) → UID FETCH(a6) → LOGOUT(a7)。
  //   脚本里**广告 ID**，把"网易形态"这条路也真跑一遍（0.66.0 起登录后按需发 ID）。
  final script = StringBuffer()
    ..write('* OK IMAP4rev1 ready\r\n')
    ..write('a1 OK LOGIN completed\r\n')
    ..write('* CAPABILITY IMAP4rev1 XLIST SPECIAL-USE ID LITERAL+ STARTTLS UIDPLUS\r\n')
    ..write('a2 OK CAPABILITY completed\r\n')
    ..write('a3 OK ID completed\r\n')
    ..write('* 3 EXISTS\r\na4 OK [READ-WRITE] SELECT completed\r\n')
    ..write('* SEARCH 10 11 12\r\na5 OK SEARCH completed\r\n')
    ..write('* 1 FETCH (UID 11 FLAGS () BODY[HEADER.FIELDS '
        '(SUBJECT FROM DATE MESSAGE-ID)] {$h1}\r\n')
    ..write(headers1)
    ..write(')\r\n')
    ..write('* 2 FETCH (UID 12 FLAGS (\\Seen) BODY[HEADER.FIELDS '
        '(SUBJECT FROM DATE MESSAGE-ID)] {$h2}\r\n')
    ..write(headers2)
    ..write(')\r\n')
    ..write('a6 OK FETCH completed\r\n')
    ..write('a7 OK LOGOUT done\r\n');

  final sent = <String>[];
  try {
    final client = ImapClient(
      host: 'imap.example.com',
      port: 993,
      user: 'me@example.com',
      password: 'app-pw',
      connector: (h, p) async => MailTransport.fromStream(
        Stream<List<int>>.value(utf8.encode(script.toString())),
        outgoing: (b) => sent.add(utf8.decode(b)),
      ),
    );
    final list = await client.list(limit: 2);
    check(list.length == 2, 'IMAP：列出 2 封（取最近 limit 封）');
    check(list.isNotEmpty && list.first.subject == '你好',
        'IMAP：主题 RFC2047 解码正确');
    check(list.length > 1 && list[1].seen, 'IMAP：\\Seen 标记被识别');
    check(list.isNotEmpty && list.first.uid == '11', 'IMAP：UID 解析正确');
    check(list.isNotEmpty && list.first.from.contains('alice@example.com'),
        'IMAP：发件人解析正确');
    final joined = sent.join();
    check(joined.contains('LOGIN "me@example.com" "app-pw"'), 'IMAP：LOGIN 引用串正确');
    check(joined.contains('UID SEARCH ALL'), 'IMAP：搜索命令正确');
    // ★ 0.66.0：网易（163/126）在 LOGIN 之后不发 `ID` 会一路拒到 SELECT。
    check(joined.contains('a2 CAPABILITY'), 'IMAP：登录后先探 CAPABILITY（不无脑发 ID）');
    check(
        joined.contains('a3 ID ("name" "Fen" "version" "1.0" "vendor" "Wold")'),
        '★ IMAP：服务端广告 ID 时必须发出身份声明（163 Unsafe Login 的根因）');
    check(joined.contains('a4 SELECT "INBOX"'), 'IMAP：ID 之后照常 SELECT');
  } catch (e) {
    check(false, 'IMAP：会话异常 → $e');
  }
}

/// 反向：服务端**不广告 ID** ⇒ 一个多余的 `ID` 都不许发。
///
/// 这条为什么必须单独钉：有的服务端对不认识的命令回**不带 tag** 的
/// `* BAD Command!`，而 `readUntilTagged` 会一直等带 tag 的完成行 ⇒ 挂到超时。
/// 把"该跳过的可选命令"变成"整条链路不可用"。
Future<void> _probeImapNoId() async {
  final script = '* OK IMAP4rev1 ready\r\n'
      'a1 OK LOGIN completed\r\n'
      '* CAPABILITY IMAP4rev1 UIDPLUS\r\n'
      'a2 OK CAPABILITY completed\r\n'
      '* 0 EXISTS\r\na3 OK [READ-WRITE] SELECT completed\r\n';
  final sent = <String>[];
  try {
    final client = ImapClient(
      host: 'imap.example.com',
      port: 993,
      user: 'me@example.com',
      password: 'app-pw',
      connector: (h, p) async => MailTransport.fromStream(
        Stream<List<int>>.value(utf8.encode(script)),
        outgoing: (b) => sent.add(utf8.decode(b)),
      ),
    );
    await client.testConnection();
    final joined = sent.join();
    check(!joined.contains('ID ('), '★ IMAP：未广告 ID 时绝不发 ID（否则可能挂死）');
    check(joined.contains('a3 SELECT "INBOX"'), 'IMAP：不发 ID 也照常 SELECT（标签序列不跳号）');
  } catch (e) {
    check(false, 'IMAP(无 ID)：会话异常 → $e');
  }
}

// ---------------------------------------------------------------------------
// IMAP：凭证含 CRLF / 引号时**禁止帧注入**（0.90.0 · 专家 #6）
// ---------------------------------------------------------------------------
//
// 为什么必须真跑：`_q` 只转义 `\` 与 `"` 时，一个含 `\r\n` 的口令会**提前结束**
// LOGIN 行、把后半段当成下一条 IMAP 命令执行（攻击者可借"授权码"字段注入）。
// 这里喂一个带 `\r\nA4 EVIL` 的口令，断言输出字节流里**没有**以注入语开头的整行。
Future<void> _probeImapCredEscape() async {
  final script = '* OK IMAP4rev1 ready\r\n'
      'a1 OK LOGIN completed\r\n'
      '* CAPABILITY IMAP4rev1\r\n'
      'a2 OK CAPABILITY completed\r\n'
      '* 0 EXISTS\r\na3 OK [READ-WRITE] SELECT completed\r\n';
  final sent = <String>[];
  try {
    final client = ImapClient(
      host: 'imap.example.com',
      port: 993,
      user: 'me@example.com',
      // 口令里塞 CRLF + 一条伪造命令
      password: 'p"w\r\nA4 EVIL',
      connector: (h, p) async => MailTransport.fromStream(
        Stream<List<int>>.value(utf8.encode(script)),
        outgoing: (b) => sent.add(utf8.decode(b)),
      ),
    );
    await client.testConnection();
    final joined = sent.join();
    check(!RegExp(r'^A4 EVIL', multiLine: true).hasMatch(joined),
        '★ IMAP：口令里的 CRLF 不得另起一行形成注入命令（帧注入防护）');
    check(joined.contains(r'p\"w'), 'IMAP：口令里的引号被转义（\\"）');
  } catch (e) {
    check(false, 'IMAP(转义)：会话异常 → $e');
  }
}

// ---------------------------------------------------------------------------
// SMTP：脚本化响应驱动一封完整投递
// ---------------------------------------------------------------------------
Future<void> _probeSmtpSession() async {
  final script = StringBuffer()
    ..write('220 smtp.example.com ESMTP\r\n')
    ..write('250-smtp.example.com\r\n250-AUTH LOGIN PLAIN\r\n250 SIZE 35882577\r\n')
    ..write('334 VXNlcm5hbWU6\r\n')
    ..write('334 UGFzc3dvcmQ6\r\n')
    ..write('235 2.7.0 Accepted\r\n')
    ..write('250 2.1.0 OK\r\n')
    ..write('250 2.1.5 OK\r\n')
    ..write('354 Go ahead\r\n')
    ..write('250 2.0.0 OK queued\r\n')
    ..write('221 Bye\r\n');

  final sent = <String>[];
  try {
    final client = SmtpClient(
      host: 'smtp.example.com',
      port: 465,
      user: 'me@example.com',
      password: 'app-pw',
      implicitTls: true,
      connector: (h, p, tls) async => MailTransport.fromStream(
        Stream<List<int>>.value(utf8.encode(script.toString())),
        outgoing: (b) => sent.add(utf8.decode(b)),
      ),
    );
    final resp = await client.send(
      from: 'me@example.com',
      to: ['you@example.com'],
      subject: '=?UTF-8?B?5L2g5aW9?=',
      body: '正文',
    );
    check(resp.contains('250'), 'SMTP：投递返回 250');

    final joined = sent.join();
    check(joined.contains('AUTH LOGIN'), 'SMTP：走了 AUTH LOGIN');
    check(joined.contains(base64.encode(utf8.encode('me@example.com'))),
        'SMTP：用户名按 base64 送出');
    check(!joined.contains('app-pw'), 'SMTP：明文口令不出现在报文里');
    check(joined.contains('MAIL FROM:<me@example.com>'), 'SMTP：MAIL FROM 正确');
    check(joined.contains('RCPT TO:<you@example.com>'), 'SMTP：RCPT TO 正确');
    check(joined.contains('\r\n.\r\n'), 'SMTP：DATA 以单独一行点结束');
    check(joined.contains('Subject: =?UTF-8?B?5L2g5aW9?='),
        'SMTP：主题按 RFC2047 送出');
    check(joined.startsWith('QUIT') || joined.contains('\r\nQUIT'),
        'SMTP：收尾发了 QUIT');
  } catch (e) {
    check(false, 'SMTP：会话异常 → $e');
  }

  // 失败路径：认证被拒必须抛出**带服务端原文**的异常（否则主人无从修）
  try {
    final badScript = '220 x\r\n250-x\r\n250 OK\r\n334 a\r\n334 b\r\n'
        '535 5.7.8 Username and Password not accepted\r\n';
    final client = SmtpClient(
      host: 'smtp.example.com',
      port: 465,
      user: 'me@example.com',
      password: 'wrong',
      implicitTls: true,
      connector: (h, p, tls) async => MailTransport.fromStream(
        Stream<List<int>>.value(utf8.encode(badScript)),
        outgoing: (_) {},
      ),
    );
    await client.send(
      from: 'me@example.com',
      to: ['you@example.com'],
      subject: 's',
      body: 'b',
    );
    check(false, 'SMTP：认证失败必须抛异常（这里不该走到）');
  } catch (e) {
    final s = '$e';
    check(s.contains('535') && s.contains('not accepted'),
        'SMTP：认证失败异常带上服务端原文（可照做修）');
  }
}
