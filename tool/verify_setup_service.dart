// 纯 Dart 校验脚本：新手接入向导服务（lib/core/setup_service.dart）。
// 运行：dart run tool/verify_setup_service.dart
//
// 为什么验它：这是**完全不懂技术的用户**进入产品的第一屏（"三分钟接入向导"）。
// 它的核心承诺是"每一步的错误都说清哪里错了、怎么办，绝不抛技术栈给用户"。
// 此前该文件（398 行）**零直接覆盖** —— 而它的 `testModel` / `testHub` 是**网络路径**，
// 一直被认为"没法离线验"。本脚本用**本地 HttpServer 假服务端**把它变成可离线复算的：
// 让假服务端分别返回 200 / 400 / 401 / 403 / 402 / 404 / 429 / 500 / 418 /
// 非 JSON / 空体 / 超长 message，断言 `_mapHttpError` 归类出的**原因码**。
// 同时钉死：地址规范化边界、预设查找回落、请求线上的（Authorization / model 字段）真实内容。
//
// ★ 0.110.0（本地化修复）起，本文件**只产语言无关结果码**（SetupResultCode），
// 文案在 UI 层 `lib/ui/setup_result_text.dart` 按当前语言渲染。于是：
//   ① 既有断言从"标题等于某句中文"升级为"code 等于某个枚举值"——**与语言无关**，
//     五语种齐换也不会再误红；
//   ② 新增 ⑦「ARB 闸门」：每个 code 都有 case、引用的键五语种齐、en 值零中文、
//     占位符五语种对齐 —— 用户实测 bug（英语版引导页弹中文）的回归判据，带三条正控。
//
// ⚠️ 本脚本必须保持**零 Flutter 依赖**（只 import dart:* + package:dahuang_ai/core）：
// `setup_service.dart` 同样零依赖，任何一侧拉进 flutter/shared_preferences，
// 这条守卫就会 `dart:ui is not available` 直接崩 —— "网络路径没法离线验"就是这么来的。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dahuang_ai/core/setup_service.dart';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

// ------------------------------------------------------------------
// ⑦ ARB 闸门用的纯函数（可被正控直接调用：改坏样本必须被判出）
// ------------------------------------------------------------------

final RegExp _cjk = RegExp('[\u4e00-\u9fff]');

Set<String> _placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

/// 读一份 ARB 成 Map（剥掉 `@key` 元数据与 `@@locale`）。
Map<String, dynamic> _arb(String locale) {
  final f = File('lib/l10n/app_$locale.arb');
  if (!f.existsSync()) throw StateError('missing $f');
  final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  m.removeWhere((k, v) => k.startsWith('@'));
  return m;
}

/// 解析器里 `case SetupResultCode.` 的分支数必须 == 枚举值个数
/// （漏一个 case 编译期就报 exhaustive switch 错——这是第二道保险）。
bool casesComplete(String src) =>
    RegExp(r'case SetupResultCode\.').allMatches(src).length ==
    SetupResultCode.values.length;

/// 每个预设 id 在解析器里都要有对应 case。
bool presetCasesComplete(String src) => SetupService.presets
    .every((p) => src.contains("case '${p.id}':"));

/// en 模板里这些键的值必须零中文（用户 bug 的核心判据）。
bool enValuesFreeOfCjk(Map<String, dynamic> en, Set<String> keys) =>
    keys.every((k) {
      final v = en[k];
      return v is String && !_cjk.hasMatch(v);
    });

/// 这些键在五个语种里都必须存在。
bool keysEverywhere(
        Map<String, dynamic> en, List<Map<String, dynamic>> others,
        Set<String> keys) =>
    keys.every((k) =>
        en.containsKey(k) && others.every((o) => o.containsKey(k)));

/// 占位符五语种对齐（en 有几个 {x}，其余语种就必须有同样的几个）。
bool placeholdersAligned(Map<String, dynamic> en,
    List<Map<String, dynamic>> others, Set<String> keys) {
  for (final k in keys) {
    final e = en[k];
    if (e is! String) return false;
    final want = _placeholders(e);
    for (final o in others) {
      final v = o[k];
      if (v is! String) return false;
      final got = _placeholders(v);
      if (want.length != got.length || !want.containsAll(got)) return false;
    }
  }
  return true;
}

Future<void> main() async {
  // ---- 本地假服务端：路径首段决定返回什么 ----
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  final base = 'http://127.0.0.1:$port';
  String? lastAuth;
  Map<String, dynamic>? lastBody;

  server.listen((HttpRequest req) async {
    final segs = req.uri.pathSegments;
    final key = segs.isEmpty ? '' : segs.first;
    if (req.method == 'POST') {
      final raw = await utf8.decoder.bind(req).join();
      lastAuth = req.headers.value(HttpHeaders.authorizationHeader);
      try {
        lastBody = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        lastBody = null;
      }
    }
    final res = req.response;
    void send(int status, String body, {bool json = true}) {
      res.statusCode = status;
      if (json) res.headers.contentType = ContentType.json;
      res.write(body);
    }

    switch (key) {
      case 'ok':
        send(200, '{"id":"x","choices":[]}');
        break;
      case 's400':
        send(400, '{"error":{"message":"bad model"}}');
        break;
      case 's401':
        send(401, '{"error":{"message":"invalid key"}}');
        break;
      case 's403':
        send(403, '{"error":{"message":"forbidden"}}');
        break;
      case 's402':
        send(402, '{"error":{"message":"insufficient balance"}}');
        break;
      case 's404':
        send(404, '{"error":{"message":"not found"}}');
        break;
      case 's429':
        send(429, '{"error":{"message":"rate limited"}}');
        break;
      case 's500':
        send(500, '{"error":{"message":"server error"}}');
        break;
      case 's418':
        send(418, '{"error":{"message":"teapot"}}');
        break;
      case 's400b':
        send(400, 'plain text error', json: false);
        break;
      case 's400c':
        send(400, '');
        break;
      case 's401long':
        send(401,
            jsonEncode({'error': {'message': List.filled(300, 'X').join()}}));
        break;
      case 'hubok':
        send(200, '{"ok":true}');
        break;
      case 'hubfalse':
        send(200, '{"ok":false}');
        break;
      case 'hubtext':
        send(200, 'hello world', json: false);
        break;
      case 'hub500':
        send(500, '{"ok":false}');
        break;
      default:
        send(404, '{"error":{"message":"unknown"}}');
    }
    await res.close();
  });

  print('--- ① 地址规范化（多打一个 / 就是最常见的填错）---');
  check(SetupService.normalizeBaseUrl('  https://a.com/  ') == 'https://a.com',
      '去空格 + 去尾斜杠');
  check(SetupService.normalizeBaseUrl('https://a.com///') == 'https://a.com',
      '多个尾斜杠全去');
  check(SetupService.normalizeBaseUrl('https://a.com/v1/') == 'https://a.com/v1',
      '保留 /v1，只去尾斜杠');
  check(SetupService.normalizeBaseUrl('https://a.com') == 'https://a.com',
      '无尾斜杠 → 原样');
  check(SetupService.normalizeBaseUrl('/') == '', '全是斜杠 → 空串');
  check(SetupService.normalizeBaseUrl('   ') == '', '全空格 → 空串');
  check(SetupService.normalizeBaseUrl('') == '', '空串 → 空串');

  print('--- ② 模型预设（查找与回落）---');
  check(SetupService.presets.length == 7, '预设 7 个');
  final ids = SetupService.presets.map((p) => p.id).toList();
  check(ids.toSet().length == ids.length, 'id 无重复');
  check(ids.every((i) => i.isNotEmpty), 'id 均非空');
  check(
      SetupService.presets
          .every((p) => p.baseUrl == SetupService.normalizeBaseUrl(p.baseUrl)),
      '★ 所有预设 baseUrl 已规范化（无尾斜杠，避免拼出 //chat）');
  check(SetupService.presetById('deepseek').id == 'deepseek', '按 id 精确命中');
  check(SetupService.presetById('openai').defaultModel == 'gpt-5.6-luna',
      'openai 预设字段正确');
  check(SetupService.presetById('不存在的id').id == SetupService.presets.first.id,
      '未知 id → 回落到第 1 个（不抛）');
  check(
      SetupService.presets.firstWhere((p) => p.id == 'custom').baseUrl.isEmpty,
      '自定义预设 baseUrl 为空（需用户自填）');

  print('--- ②b 官方后端默认地址（出厂预填；换域名只改这一处）---');
  check(SetupService.defaultHubUrl == 'https://hub.wold.world',
      '默认中转站地址 = https://hub.wold.world');
  check(SetupService.defaultWorldUrl == 'https://world.wold.world',
      '默认世界服务器地址 = https://world.wold.world');
  // 公网非 HTTPS 会被 cloud_service / world_service 静默拒绝 ⇒ 默认值一旦写成
  // http:// 就会变成"界面填好了、实际连不上"。这里把它钉成不可能发生。
  check(SetupService.defaultHubUrl.startsWith('https://'),
      '★ 默认中转站必须是 HTTPS（http 会被运行时守卫拒绝）');
  check(SetupService.defaultWorldUrl.startsWith('https://'),
      '★ 默认世界地址必须是 HTTPS（http 会被运行时守卫拒绝）');
  check(
      SetupService.defaultHubUrl ==
          SetupService.normalizeBaseUrl(SetupService.defaultHubUrl),
      '默认中转站地址已规范化（无尾斜杠）');
  check(
      SetupService.defaultWorldUrl ==
          SetupService.normalizeBaseUrl(SetupService.defaultWorldUrl),
      '默认世界地址已规范化（无尾斜杠）');
  check(SetupService.defaultHubUrl != SetupService.defaultWorldUrl,
      '★ 两者是不同域名（世界站点不是 Hub 的子路径 —— hub/world 实测 404）');

  print('--- ②d 访问 Key 申请入口（ADR-002 准入闸配套，0.119.0 新增）---');
  // 空串 = 不渲染申请按钮（**安全阀**：没有真实渠道时宁可不显示）。
  // 一旦填了值，就必须是**用户点进去真能打开**的地址 —— 这条断言堵的是
  // "占位假链接"：写个 example.com 进去，按钮会渲染、用户会点、然后打不开，
  // 比压根不显示更失信（与 SetupService.hubKeyApplyUrl 注释同一判据）。
  if (SetupService.hubKeyApplyUrl.isEmpty) {
    check(true, '未配置申请渠道 → 按钮不渲染（空串 = 安全阀）');
  } else {
    check(SetupService.hubKeyApplyUrl.startsWith('https://'),
        '★ 申请入口必须是 HTTPS（http 会被运行时守卫拒绝）');
    check(!SetupService.hubKeyApplyUrl.contains(' '),
        '申请入口不得含空格（防手滑粘错）');
    check(
        SetupService.hubKeyApplyUrl ==
            SetupService.normalizeBaseUrl(SetupService.hubKeyApplyUrl),
        '申请入口已规范化（无尾斜杠）');
    check(Uri.tryParse(SetupService.hubKeyApplyUrl)?.hasAuthority == true,
        '申请入口可解析为带 authority 的 URI');
  }

  print('--- ②c 输入框默认值解析（"键存在性 ≠ 值为空"；引导页/设置页共用）---');
  check(
      SetupService.resolveStoredOrDefault(
              keyPresent: false, stored: null, fallback: 'X') ==
          'X',
      '键不存在 + 无值 → 用默认值');
  check(
      SetupService.resolveStoredOrDefault(
              keyPresent: false, stored: 'stale', fallback: 'X') ==
          'X',
      '★ 键不存在 → 一律用默认值（不吃遗留值）');
  check(
      SetupService.resolveStoredOrDefault(
              keyPresent: true, stored: 'https://mine', fallback: 'X') ==
          'https://mine',
      '键存在 + 有值 → 用用户的值');
  check(
      SetupService.resolveStoredOrDefault(
              keyPresent: true, stored: '', fallback: 'X') ==
          '',
      '★ 键存在 + 空串 → 保持空（用户显式清空 = 不连云端，默认值不许翻案）');
  check(
      SetupService.resolveStoredOrDefault(
              keyPresent: true, stored: null, fallback: 'X') ==
          '',
      '键存在 + null → 空串（不抛）');

  print('--- ③ testModel 前置校验（不触网，逐条原因码；顺序即契约）---');
  final noBase = await SetupService.testModel(
      baseUrl: '   ', apiKey: 'sk', model: 'm');
  check(!noBase.ok && noBase.code == SetupResultCode.modelEmptyUrl,
      '空地址 → modelEmptyUrl');
  final badScheme = await SetupService.testModel(
      baseUrl: 'ftp://x', apiKey: 'sk', model: 'm');
  check(!badScheme.ok && badScheme.code == SetupResultCode.modelBadUrl,
      '非 http(s) → modelBadUrl');
  final noKey = await SetupService.testModel(
      baseUrl: '$base/ok', apiKey: '   ', model: 'm');
  check(!noKey.ok && noKey.code == SetupResultCode.modelEmptyKey,
      '空密钥 → modelEmptyKey');
  final noModel = await SetupService.testModel(
      baseUrl: '$base/ok', apiKey: 'sk', model: '');
  check(!noModel.ok && noModel.code == SetupResultCode.modelEmptyName,
      '空模型名 → modelEmptyName');
  // 顺序契约：三项全空必须先报地址；地址合法但密钥/模型名全空必须先报密钥。
  final allEmpty = await SetupService.testModel(
      baseUrl: '   ', apiKey: '   ', model: '');
  check(allEmpty.code == SetupResultCode.modelEmptyUrl,
      '★ 三项全空 → 先报地址（地址是第一个闸）');
  final keyBeforeModel = await SetupService.testModel(
      baseUrl: '$base/ok', apiKey: '   ', model: '');
  check(keyBeforeModel.code == SetupResultCode.modelEmptyKey,
      '★ 密钥与模型名全空 → 先报密钥（顺序即契约）');

  print('--- ④ testModel 错误映射（假服务端逐状态码）---');
  Future<SetupTestResult> model(String seg) => SetupService.testModel(
      baseUrl: '$base/$seg', apiKey: 'sk-test', model: 'mymodel');

  final okRes = await model('ok');
  check(okRes.ok && okRes.code == SetupResultCode.modelOk, '200 → modelOk');
  final r400 = await model('s400');
  check(r400.code == SetupResultCode.http400 && r400.detail == 'bad model',
      '400 → http400 + 透传服务商原文');
  final r401 = await model('s401');
  check(!r401.ok && r401.code == SetupResultCode.http401, '401 → http401');
  final r403 = await model('s403');
  check(!r403.ok && r403.code == SetupResultCode.http401, '403 → 与 401 同类');
  final r402 = await model('s402');
  check(!r402.ok && r402.code == SetupResultCode.http402, '402 → http402');
  final r404 = await model('s404');
  check(!r404.ok && r404.code == SetupResultCode.http404, '404 → http404');
  final r429 = await model('s429');
  check(!r429.ok && r429.code == SetupResultCode.http429, '429 → http429');
  final r500 = await model('s500');
  check(r500.code == SetupResultCode.http5xx && r500.status == 500,
      '500 → http5xx（带状态码）');
  final r418 = await model('s418');
  check(r418.code == SetupResultCode.httpOther && r418.status == 418,
      '418 → 走 httpOther 分支');
  final rText = await model('s400b');
  check(rText.detail == 'plain text error', '非 JSON 体 → 原文兜底');
  final rEmpty = await model('s400c');
  check(rEmpty.detail == null, '空体 → 无 detail（UI 层用默认提示）');
  final rLong = await model('s401long');
  check(rLong.detail != null &&
      rLong.detail!.endsWith('…') &&
      rLong.detail!.length == 161,
      '超长 message → 截断到 160 + 省略号（实测 ${rLong.detail?.length} 字）');

  print('--- ⑤ testModel 请求线上真实内容 ---');
  check(lastAuth == 'Bearer sk-test', 'Authorization: Bearer <key> 已发出');
  check(lastBody != null && lastBody!['model'] == 'mymodel',
      'POST 体带 model 字段');
  check(
      lastBody != null &&
          lastBody!['messages'] is List &&
          (lastBody!['messages'] as List).isNotEmpty,
      'POST 体带 messages');

  print('--- ⑥ testHub 前置校验与响应判定 ---');
  final hubEmpty = await SetupService.testHub('  ');
  check(!hubEmpty.ok && hubEmpty.code == SetupResultCode.hubEmpty,
      '空地址 → hubEmpty');
  final hubScheme = await SetupService.testHub('ftp://x');
  check(!hubScheme.ok && hubScheme.code == SetupResultCode.hubBadUrl,
      '非 http(s) → hubBadUrl');
  final hubOk = await SetupService.testHub('$base/hubok');
  check(hubOk.ok && hubOk.code == SetupResultCode.hubOk,
      '200 + {"ok":true} → hubOk');
  final hubFalse = await SetupService.testHub('$base/hubfalse');
  check(!hubFalse.ok && hubFalse.code == SetupResultCode.hubNotOurs,
      '200 + {"ok":false} → hubNotOurs');
  final hubText = await SetupService.testHub('$base/hubtext');
  check(!hubText.ok && hubText.code == SetupResultCode.hubNotOurs,
      '200 + 非 JSON → hubNotOurs');
  final hub500 = await SetupService.testHub('$base/hub500');
  check(hub500.code == SetupResultCode.hubBadStatus && hub500.status == 500,
      '500 → hubBadStatus（带状态码）');

  await server.close(force: true);

  print('--- ⑦ ARB 闸门（英语版引导页不许冒中文：用户实测 bug 的回归判据）---');
  final resolverSrc = File('lib/ui/setup_result_text.dart').readAsStringSync();
  final en = _arb('en');
  final others = ['zh', 'zh_Hant', 'ja', 'vi'].map(_arb).toList();
  final refKeys = RegExp(r'l10n\.(setup[A-Z]\w*)')
      .allMatches(resolverSrc)
      .map((m) => m.group(1)!)
      .toSet();
  check(refKeys.length >= 80, '解析器引用的 setup* 键 ≥ 80（实测 ${refKeys.length}）');
  check(casesComplete(resolverSrc),
      '★ 每个 SetupResultCode 都有 case（${SetupResultCode.values.length} 个枚举值）');
  check(presetCasesComplete(resolverSrc), '每个预设 id 都有 case');
  check(keysEverywhere(en, others, refKeys), '引用的键五语种齐（无缺失）');
  check(enValuesFreeOfCjk(en, refKeys), '★ en 值零中文（英语界面不许冒中文）');
  check(placeholdersAligned(en, others, refKeys), '占位符五语种对齐');
  // 占位符键必须真的带占位符（防"键存在但 {status} 被写成字面量"）
  check(_placeholders(en['setupHubBadStatusTitle'] as String)
      .contains('status'), 'setupHubBadStatusTitle 带 {status}');
  check(_placeholders(en['setupHttp5xxTitle'] as String).contains('status'),
      'setupHttp5xxTitle 带 {status}');
  check(_placeholders(en['setupModelFailBody'] as String).contains('detail'),
      'setupModelFailBody 带 {detail}');
  check(_placeholders(en['setupHubFailBody'] as String).contains('detail'),
      'setupHubFailBody 带 {detail}');

  print('--- ⑦b 正控（改坏样本必须被判出，否则判据自身失效）---');
  // pc1：抽掉一个 case → 分支数判据必须转假
  final srcNoCase =
      resolverSrc.replaceFirst('case SetupResultCode.hubOk:', '');
  check(!casesComplete(srcNoCase), '正控① 抽掉 hubOk 的 case → 必须判出不完整');
  check(casesComplete(resolverSrc), '正控①b 复原后必须判回完整');
  // pc2：把 en 值污染成中文 → 零中文判据必须转假
  final enPoisoned = Map<String, dynamic>.from(en);
  enPoisoned['setupHubOkTitle'] = '中转站连接成功 ✅';
  check(!enValuesFreeOfCjk(enPoisoned, refKeys),
      '正控② en 值被换成中文 → 必须判出（这就是用户报的 bug 形态）');
  check(enValuesFreeOfCjk(en, refKeys), '正控②b 复原后必须判回零中文');
  // pc3：从越南语里偷删一个键 → 齐备性判据必须转假
  final othersMissingKey =
      others.map((o) => Map<String, dynamic>.from(o)..remove('setupHubOkTitle')).toList();
  check(!keysEverywhere(en, othersMissingKey, refKeys),
      '正控③ 某语种缺键 → 必须判出');
  check(keysEverywhere(en, others, refKeys), '正控③b 复原后必须判回齐备');
  // pc4：占位符被改成不一致 → 对齐判据必须转假
  final othersBadPh = others
      .map((o) => Map<String, dynamic>.from(o)
        ..['setupHubBadStatusTitle'] = 'no placeholder here')
      .toList();
  check(!placeholdersAligned(en, othersBadPh, refKeys),
      '正控④ 某语种丢占位符 → 必须判出');
  check(placeholdersAligned(en, others, refKeys), '正控④b 复原后必须判回对齐');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
