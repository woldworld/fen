// 试用代调（trial proxy）守卫（0.56.0 新增）。
//
// 背景：《首批用户方案》§一——零 Key 新用户靠服务端代调拿到 20 轮免费体验，
// 这是"10 分钟旅程"的第一个致命断点（必须自带 API Key）的解药。
// 它是一条**跨端链子**：App（模式判定 / 余量 / 耗尽引导）↔ Hub（额度台账 / 账号池 /
// 模态路由）↔ 合规（隐私政策披露）↔ 部署包（模板带上、真 Key 不入库）。
// 任一端单独改都不会报错，症状却是"用户看到 20 轮、第 11 轮就被切断"或
// "真 Key 被提交进仓库"——上线/发布后才发现。
//
// ★ 与 `verify_social_budget.dart` 同族：本仓踩过两次的"两层额度闸"陷阱
//   （App 侧声明值 vs 服务端实际值，实际生效 = min(两道闸)）。试用额度是**同一形态**：
//   App 按钮写着 20 轮、服务端 `TRIAL_TURN_LIMIT` 才是硬顶 ⇒ 这里跨语言比数值。
//
// ★ 与 `verify_legal_links.dart` 同款：源文本扫描脚本必须带**正向自检**，
//   匹配式一坏就会"扫到 0 处 → 恒绿"。下面的判据抽成纯函数，末尾对人为改坏的副本断言。
//
// ★★ 0.57.0 新增 ⑬⑭ —— **失败分类的跨端覆盖**。0.56.0 的客户端只认 402，
//   服务端另外 7 类码（400/401/413/415/429/502/503）全落进"网络接口发生异常"
//   或离线兜底 ⇒ 用户看到"分身坏了"，实情是"官方池还没配 Key"或"不支持图片"。
//   两端各自改都不会报错，所以把覆盖关系**跨语言**钉在这里：
//   ⑬ 扫 `hub.js` 试用地带的所有 `sendJson(res, NNN` ⇒ 每个都必须在客户端的
//      `statusToFailure` 表里；⑭ 每个 `TrialFailure` 值必须在 `agent_service`
//      有分支、且新增文案键在 ARB 里真有。
//
// ★★ 0.57.0 又加 ⑮ —— **部署接线真能生效**。取证时抓到真缺陷：
//   `install-server.ps1` / 部署说明里 `TRIAL_POOL_FILE=<dir>\trial-pool.json`
//   的 `\t` 被写成了**真制表符** ⇒ 路径不存在 ⇒ 池为空 ⇒ 新用户永远 503，
//   而安装脚本还在打印"✅ 试用代调已接线"。不报错、不崩溃，只是静默失效。
//
// ★★ 0.66.0 又加 ⑯⑰ —— **轮次计量口径**与**上游非 2xx 透传**（真机反馈驱动）：
//   ⑯ 只有"新一轮用户提问"才计数：工具续跑轮（role:'tool' / assistant.tool_calls）
//      既**不计数**、也**不被额度闸拦**（否则最后一轮答到一半就被 402 打断）。
//      实证形态：真机"问一句邮箱，剩余 20 → 16" = 一次问答产生了 4 次成功透传。
//   ⑰ 上游**任何非 2xx** 都换下一个账号 —— 旧实现只拦 400/429/5xx，于是
//      401/404/409/422 被当成"正常答复"原样透传给客户端；客户端只认 8 类状态码
//      ⇒ 认不出的退化成「网络接口发生异常」（真机偶发）。配套行为冒烟见
//      `lib/hub/test-trial.js` 第 7 组（工具续跑轮：额度读数不增）。
//
// ★★ 0.66.0 再加 ⑱ —— **客户端单请求口径的接线**。harness 的行为测试
//   （`packages/pocket_harness/test/agent_runtime_test.dart`，用真 HTTP 计数）
//   只证明「API 支持一轮只发一次」；**证明不了 App 真的用了** —— 接线一旦漏掉，
//   同轮双计会悄悄回来，而 harness 测试**照样全绿**。所以在这里跨文件钉住：
//   宿主把试用模式接进 `allowPlainRetry`，且 harness 主路径不得退回 `sendFor<`。
import 'dart:io';

int _pass = 0;
int _fail = 0;
void check(bool ok, String label) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    print('  FAIL: $label');
  }
}

/// 行注释用**负向后顾** `(?<!:)//`：只剥真注释，**不剥 URL 里的 `://`**
///（本仓既有坑：剥掉 `://` 会让一切依赖 URL/路径的判据恒绿）。
String _stripComments(String s) {
  final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  return noBlock
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'(?<!:)//.*$'), ''))
      .join('\n');
}

String _read(String p) => File(p).readAsStringSync();

/// 容错读取：嵌套仓（`packages/pocket_harness`）在极端情况下可能不在盘上。
/// 读不到返回空串 ⇒ 判据 ⑱ 会**明确报 FAIL**（而不是把脚本崩掉，
/// 让「文件缺失」看起来像「环境坏了」）。
String _readOpt(String p) {
  final f = File(p);
  return f.existsSync() ? f.readAsStringSync() : '';
}

// ── 判据（纯函数，供自检复用）──────────────────────────────────────────
class Facts {
  Facts({
    required this.hub,
    required this.client,
    required this.agent,
    required this.onboarding,
    required this.arbEn,
    required this.gitignore,
    required this.makePkg,
    required this.privacy,
    required this.poolExample,
    required this.installPs1,
    required this.deployTxt,
    required this.harness,
  });
  final String hub;
  final String client;
  final String agent;
  final String onboarding;
  final String arbEn;
  final String gitignore;
  final String makePkg;
  final String privacy;
  final String poolExample;
  final String installPs1;
  final String deployTxt;
  final String harness;
}

/// 服务端**试用地带**里所有 `sendJson(res, NNN, ...)` 的状态码。
///
/// 为什么必须限定地带：`hub.js` 全文件里有两百多处 `sendJson`（普通路由的
/// 429 / 404 等），照全文件扫会把一堆**与试用无关**的码算进来。
/// 地带 = `'/api/trial/chat/completions'` 到 `'/api/trial/pool'` 之间
///（`/quota` 与 `/pool` 只回 200/400，不在链路里）。
Set<int> serverTrialStatusCodes(String hub) {
  final start = hub.indexOf("'/api/trial/chat/completions'");
  final end = hub.indexOf("'/api/trial/pool'");
  if (start < 0 || end <= start) return <int>{};
  final region = hub.substring(start, end);
  final literal = RegExp(r'sendJson\(\s*res\s*,\s*(\d{3})')
      .allMatches(region)
      .map((m) => int.parse(m.group(1)!))
      .toSet();
  return <int>{...literal, ...trialIdentityStatusCodes(hub)};
}

/// 身份解析层（`resolveTrialIdentity`）返回的状态码。
///
/// ★ 0.118.0+1 试用滥用面收口时**实测踩到**：把身份判定收进独立函数后，端点只剩
/// `sendJson(res, trialId.code, …)` —— 纯扫字面量让扫描面从 8 类掉到 7 类，
/// 本脚本的正控（"扫到的码数 ≥ 8"）当场报红。**判据是活的**，但覆盖悄悄变窄：
/// 若没人管，新加的码就会绕开⑬ 的跨端比对，用户照样看到"分身坏了"。
/// 所以这里改为**并集**：字面量 + 数据化返回的 `code: NNN`。
Set<int> trialIdentityStatusCodes(String hub) {
  final at = hub.indexOf('function resolveTrialIdentity(');
  if (at < 0) return <int>{};
  // 到下一个顶层 `function ` 为止（缩进 0 开头），避免把整个文件都算进来。
  final rest = hub.substring(at + 1);
  final next = RegExp(r'\nfunction ').firstMatch(rest);
  final body = next == null ? hub.substring(at) : hub.substring(at, at + 1 + next.start);
  return RegExp(r'code:\s*(\d{3})')
      .allMatches(body)
      .map((m) => int.parse(m.group(1)!))
      .toSet();
}

/// 客户端 `statusToFailure` 表里登记的裸状态码。
Set<int> clientTrialStatusCodes(String client) {
  final start = client.indexOf('statusToFailure');
  if (start < 0) return <int>{};
  final end = client.indexOf('};', start);
  if (end < 0) return <int>{};
  return RegExp(r'(\d{3})\s*:\s*TrialFailure\.')
      .allMatches(client.substring(start, end))
      .map((m) => int.parse(m.group(1)!))
      .toSet();
}

/// `enum TrialFailure` 的值清单（解析源码，**不手抄** —— 手抄会漂移）。
List<String> trialFailureValues(String client) {
  final start = client.indexOf('enum TrialFailure {');
  if (start < 0) return const [];
  final open = client.indexOf('{', start);
  final close = client.indexOf('}', open);
  if (open < 0 || close < 0) return const [];
  return client
      .substring(open + 1, close)
      .split(',')
      .map((s) => s.trim())
      .where((s) => RegExp(r'^[A-Za-z]\w*$').hasMatch(s))
      .toList();
}

/// 服务端硬顶轮数（`process.env.TRIAL_TURN_LIMIT || '20'` 里的默认值）。
int? serverTurnLimit(String hub) {
  final m = RegExp(r"TRIAL_TURN_LIMIT\s*\|\|\s*'(\d+)'").firstMatch(hub);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// App 侧对外宣称的轮数（`onbFreeTrialBtn` 文案里的 "(20 turns)"）。
int? advertisedTurns(String arbEn) {
  final line =
      RegExp(r'"onbFreeTrialBtn"\s*:\s*"([^"]*)"').firstMatch(arbEn);
  if (line == null) return null;
  final m = RegExp(r'\((\d+)\s*turns?\)').firstMatch(line.group(1)!);
  return m == null ? null : int.tryParse(m.group(1)!);
}

List<String> violations(Facts f) {
  final bad = <String>[];
  final hub = _stripComments(f.hub);
  final cli = _stripComments(f.client);

  void want(bool ok, String label) {
    if (!ok) bad.add(label);
  }

  // ① 三条服务端路由齐备（少一条 = 客户端拿到 404 而非可读错误）
  want(hub.contains("pathname === '/api/trial/chat/completions'"),
      '① 服务端缺 POST /api/trial/chat/completions');
  want(hub.contains("pathname === '/api/trial/quota'"),
      '① 服务端缺 GET /api/trial/quota');
  want(hub.contains("pathname === '/api/trial/pool'"),
      '① 服务端缺 GET /api/trial/pool');

  // ② 额度硬顶：超限返回 402 + 客户端能认的错误码串
  want(hub.contains('used.turns >= TRIAL_TURN_LIMIT'),
      '② 服务端不再按 TRIAL_TURN_LIMIT 卡额度');
  want(RegExp(r'402,\s*\{[^}]*trial_quota_exhausted').hasMatch(hub),
      '② 额度耗尽的 402 响应体不含 trial_quota_exhausted');
  want(cli.contains("'trial_quota_exhausted'"),
      '② 客户端不再识别 trial_quota_exhausted（耗尽会被当成普通故障）');

  // ③ ★ 跨层同值：App 文案的轮数 == 服务端硬顶（两层额度闸）
  final srv = serverTurnLimit(hub);
  final adv = advertisedTurns(f.arbEn);
  want(srv != null && adv != null, '③ 解析不到某一侧的轮数（服务端=$srv 文案=$adv）');
  want(srv == adv, '③ 两层额度闸不同值：服务端硬顶 $srv ≠ App 文案 $adv');

  // ④ 模式键与鉴权：客户端键名/取值 ↔ 服务端 agent_id 校验
  //   ★ 0.82.0：键名/取值的**字面量**搬进 `lib/core/trial_config.dart`（单一事实源），
  //     `trial_client.dart` 只做转发 ⇒ 这里改查「客户端确已委托单一事实源」；
  //     字面量**取值本身**（`llm_mode` / `trial`）由 `verify_trial_switch.dart` **实跑**
  //     `TrialConfig.modeKey == 'llm_mode'` 等断言钉住（行为判据强于字符串判据）。
  want(cli.contains('TrialConfig.modeKey'),
      '④ 客户端 modeKey 未委托单一事实源（TrialConfig）');
  want(cli.contains('TrialConfig.trialModeValue'),
      '④ 客户端 trialModeValue 未委托单一事实源（TrialConfig）');
  want(hub.contains(r'AG-[A-Za-z0-9]{4,32}'), '④ 服务端不再校验 agent_id 格式');

  // ⑤ 余量查询路径闭环：base_url 末段 /api/trial + 客户端 '/quota'
  //   ★ 0.82.0：试用端点（`<hub>/api/trial`）的拼接抽到 **零 Flutter 依赖**的
  //     `lib/core/trial_config.dart`（`TrialConfig.trialApiBase`）作**单一事实源**，
  //     引导页改为经 `applyTrialConfig` 落库 ⇒ 判据不能再只查引导页/trial_client
  //     的字面量，改查「client 层确已委托单一事实源 + 引导页确已委托写库」。
  //     （`/api/trial` 字面量本体由 `verify_trial_switch.dart` **实跑** `trialApiBase` 钉住。）
  want(cli.contains('TrialConfig.trialApiBase') &&
          f.onboarding.contains('applyTrialConfig('),
      '⑤ 引导页落库的 base_url 末段不是 /api/trial（0.82.0：单一事实源在 TrialConfig，两侧均只委托）');
  want(cli.contains('/quota?agent_id='),
      '⑤ 客户端余量查询路径不再是 <base>/quota');
  want(hub.contains("pathname === '/api/trial/quota'"),
      '⑤ 服务端 /api/trial/quota 与客户端拼出的路径不再对得上');

  // ⑥ 账号池：耗尽**持久化**（重启不复活），且只有 402/403 才标记
  want(hub.contains('db.trial_pool_state.exhausted[entry.name] = {'),
      '⑥ 账号耗尽不再写 trial_pool_state.exhausted（重启即复活）');
  want(hub.contains('r.status === 402 || r.status === 403'),
      '⑥ 标记条件不再是 402/403（会把限流误判成永久耗尽）');
  want(RegExp(r'trial_pool_state\.exhausted').hasMatch(hub),
      '⑥ 服务端不再有 trial_pool_state 台账');

  // ⑦ 每 IP 双闸（分钟 + 日）——防"重装刷额度"之外的批量滥用
  want(hub.contains('trialIpDaily') && hub.contains('TRIAL_IP_PER_MIN'),
      '⑦ 每 IP 双闸（分钟/日）缺了一道');

  // ⑧ 输入模态路由：无可用池必须 415 明说，不许 200 假装成功
  want(hub.contains("'input_type_unsupported'"),
      '⑧ 模态不支持时不再返回 input_type_unsupported（会把失败伪装成成功）');

  // ⑨ 额度可观测（响应头）——否则"还剩几轮"只能靠猜
  want(hub.contains("'X-Trial-Used'") && hub.contains("'X-Trial-Limit'"),
      '⑨ 响应头不再带 X-Trial-Used / X-Trial-Limit');

  // ⑩ 真 Key 绝不入库：忽略规则 + 模板占位化
  want(f.gitignore.contains('lib/hub/trial-pool.json'),
      '⑩ .gitignore 不再排除 lib/hub/trial-pool.json（真 Key 会入库）');
  final keys = RegExp(r'"key"\s*:\s*"([^"]*)"').allMatches(f.poolExample);
  want(keys.isNotEmpty, '⑩ 模板 trial-pool.example.json 里没解析到 key 字段');
  want(keys.every((m) {
        final v = m.group(1)!;
        return v.contains('你的') || v.startsWith('sk-你的') || v.isEmpty;
      }),
      '⑩ 模板里出现了疑似真实 Key 的值（应全部是占位符）');

  // ⑪ 部署包要带模板（否则服务器上手搓配置）
  want(f.makePkg.contains("'trial-pool.example.json'"),
      '⑪ 部署包脚本不再复制 trial-pool.example.json');

  // ⑫ 合规：试用期"内容经我们转发"必须在隐私政策里如实写明
  want(f.privacy.contains('试用') && f.privacy.contains('转发'),
      '⑫ 隐私政策不再披露"试用期由官方服务器转发"');

  // ⑬ ★★ 跨端覆盖（0.57.0）：服务端试用地带**产出的每一个状态码**，
  //    客户端都必须归类 —— 否则那一类失败会退化成通用文案（"分身坏了"）。
  //    这是"两端各自改都不报错、上线后用户看到错话术"的同一族缺陷。
  final srvCodes = serverTrialStatusCodes(hub);
  final cliCodes = clientTrialStatusCodes(cli);
  want(srvCodes.isNotEmpty, '⑬ 扫不到服务端试用地带的状态码（判据失效：锚点变了）');
  want(cliCodes.isNotEmpty, '⑬ 扫不到客户端 statusToFailure 表（判据失效：锚点变了）');
  final uncovered = srvCodes.difference(cliCodes);
  want(uncovered.isEmpty,
      '⑬ 服务端会返回、客户端归不了类的状态码：$uncovered（用户会看到"分身坏了"）');

  // ⑭ 枚举 ↔ 接线不变式：每个 TrialFailure 值都要在 agent_service 有分支，
  //    且新增的那批文案必须真被引用、ARB 里真有键（防"加了枚举没加话术"）。
  final values = trialFailureValues(cli);
  want(values.isNotEmpty, '⑭ 解析不到 enum TrialFailure 的值（判据失效）');
  // ⚠️ 必须带**词边界**：裸 `contains('TrialFailure.poolBusy')` 会被
  // `TrialFailure.poolBusyX` 前缀命中 ⇒ 判据假绿（本脚本自检⑪ 当场抓到过）。
  bool mentions(String src, String symbol) =>
      RegExp('$symbol(?![A-Za-z0-9_])').hasMatch(src);
  final unwired =
      values.where((v) => !mentions(f.agent, 'TrialFailure\\.$v')).toList();
  want(unwired.isEmpty, '⑭ 枚举值未接线到 agent_service 的 switch：$unwired');
  for (final k in const [
    'trialNotConfiguredReply',
    'trialInputUnsupportedReply',
    'trialRateLimitedReply',
    'trialPoolBusyReply',
    'trialUnavailableReply',
  ]) {
    want(mentions(f.agent, 'l10n\\.$k'), '⑭ 新增文案键 $k 未被 agent_service 引用');
    want(f.arbEn.contains('"$k"'), '⑭ ARB(en) 里没有键 $k');
  }

  // ⑮ ★★ 部署接线**真能**把试用池接上（0.57.0 取证时抓到的真缺陷）。
  //    `install-server.ps1` 会给生成的 run-hub.cmd 注入 `TRIAL_POOL_FILE`。
  //    踩过：路径里的 `\t` 被写成了**真制表符**（`$DataDir<TAB>rial-pool.json`）
  //    ⇒ 路径不存在 ⇒ hub.js 读到空池 ⇒ 新用户永远 503，**而安装脚本一路打印
  //    "✅ 试用代调已接线"**。这就是"接线看着有、实际不通"的典型形态：
  //    不报错、不崩溃，只是静默失效。tab 化与整行删掉是两种不同的失败，都判。
  want(f.installPs1.contains('TRIAL_POOL_FILE='),
      '⑮ 安装脚本不再给 run-hub.cmd 注入 TRIAL_POOL_FILE（试用池接不上）');
  want(!f.installPs1.contains('\t'),
      '⑮ 安装脚本出现制表符（路径里的 \\t 被写成真 TAB ⇒ 试用池静默 503）');
  want(f.installPs1.contains(r'TRIAL_POOL_FILE=$DataDir\trial-pool.json'),
      r'⑮ TRIAL_POOL_FILE 不再指向 <数据目录>\trial-pool.json');
  want(!f.deployTxt.contains('\t'),
      '⑮ 部署说明出现制表符（同一处 \\t 被写成真 TAB，照着填就是错路径）');
  want(f.deployTxt.contains(r'TRIAL_POOL_FILE=C:\hub\trial-pool.json'),
      r'⑮ 部署说明里的 TRIAL_POOL_FILE 示例路径不对（应是 C:\hub\trial-pool.json）');

  // ⑯ ★★ 0.66.0 **轮次计量口径**：只有"新一轮用户提问"才计数。
  //   真机反馈：只问了「如何帮我收发邮箱」一句，剩余轮数 20 → 16。一次问答在客户端
  //   会产生多次 `/chat/completions` 往返（工具调用轮最常见），旧实现**每次成功透传
  //   都 +1**。修正后工具续跑轮（role:'tool' / assistant.tool_calls）不计。
  //   三种形态缺一不可 —— 少任何一种都会让"用户看得见的一轮"重新被多扣：
  want(hub.contains('const isToolRound = '),
      '⑯ 服务端不再计算 isToolRound（工具续跑轮会被当新提问计数）');
  want(hub.contains("m.role === 'tool'"),
      '⑯ isToolRound 不再识别 role:tool 续跑消息');
  want(hub.contains('m.tool_calls'),
      '⑯ isToolRound 不再识别 assistant.tool_calls');
  final incCount = RegExp(r'used\.turns \+= 1').allMatches(hub).length;
  want(incCount == 1, '⑯ 计数点不再唯一（有 $incCount 处 `used.turns += 1`）');
  want(RegExp(r'if \(!isToolRound\) \{\s*used\.turns \+= 1;').hasMatch(hub),
      '⑯ `used.turns += 1` 未被 `if (!isToolRound)` 包住（工具轮会被计数）');
  want(hub.contains('if (!isToolRound && used.turns >= TRIAL_TURN_LIMIT)'),
      '⑯ 额度闸不再排除工具续跑轮（已用满时最后一轮会被 402 打断）');

  // ⑰ ★★ 0.66.0 **上游非 2xx 一律换下一个账号**。旧实现只拦 400/429/5xx，
  //   于是 401/404/409/422 会被当成"上游的正常答复"原样透传 ⇒ 客户端只认 8 类
  //   状态码，认不出的退化成「网络接口发生异常」（真机偶发）。顺带旧实现还会
  //   为这类失败 +1 计数（因为设了 upstreamRes）。
  want(hub.contains('r.status < 200 || r.status >= 300'),
      '⑰ 上游非 2xx 不再一律判失败（怪状态码会被原样透传成"答复"）');
  want(!hub.contains('r.status === 400 || r.status === 429 || r.status >= 500'),
      '⑰ 旧的三态白名单又回来了（401/404/409/422 会漏过透传）');

  // ⑱ ★★ 0.66.0 **客户端单请求口径的接线**（跨文件，见文件头说明）。
  //   两头都要钉：① 宿主是否把试用模式接进 allowPlainRetry；
  //   ② harness 主路径是否仍是「一次请求、两种解读」。
  final hz = _stripComments(f.harness);
  want(f.harness.isNotEmpty,
      '⑱ 读不到 pocket_harness 的 agent_runtime.dart（嵌套仓缺失，无法验证单请求口径）');
  want(f.agent.contains('allowPlainRetry:'),
      '⑱ agent_service 没把 allowPlainRetry 传给 AgentRuntime（试用模式会二次请求）');
  want(RegExp(r'allowPlainRetry:\s*\(\)\s*async\s*=>\s*!\s*await\s*TrialClient\.isTrialMode\(\)')
          .hasMatch(f.agent),
      '⑱ allowPlainRetry 不再与 !TrialClient.isTrialMode() 绑定（试用模式会二次请求）');
  want(!hz.contains('sendFor<'),
      '⑱ harness 主路径退回 sendFor（结构化失败会再发一次请求 = 同轮双计）');
  //     ★ 钉结构不钉名字：重命名解码器是无害的，钉符号名会假红。
  want(RegExp(r'outputSchema:').allMatches(hz).length == 1,
      '⑱ harness 的 schema 不再只发一次（主路径/补发各带一次 ⇒ 同轮双计）');
  want(hz.contains('structured_output_unparsed_reused_response'),
      '⑱ harness 缺「复用同一响应」的解读器（纯文本回复会走补发）');
  want(RegExp(r'if\s*\(allowPlain\)\s*\{').hasMatch(hz),
      '⑱ harness 的补发不再受 allowPlain 开关约束（试用模式会二次请求）');

  return bad;
}

Facts _load() => Facts(
      hub: _read('lib/hub/hub.js'),
      client: _read('lib/core/trial_client.dart'),
      agent: _read('lib/core/agent_service.dart'),
      onboarding: _read('lib/ui/onboarding_screen.dart'),
      arbEn: _read('lib/l10n/app_en.arb'),
      gitignore: _read('.gitignore'),
      makePkg: _read('lib/hub/deploy/make-package.ps1'),
      privacy: _read('lib/compliance/隐私政策.md'),
      poolExample: _read('lib/hub/trial-pool.example.json'),
      installPs1: _read('lib/hub/deploy/install-server.ps1'),
      deployTxt: _read('lib/hub/deploy/先看我-使用说明.txt'),
      harness: _readOpt(
          'packages/pocket_harness/lib/src/runtime/agent_runtime.dart'),
    );

Facts _with(Facts f,
        {String? hub,
        String? client,
        String? agent,
        String? onboarding,
        String? arbEn,
        String? gitignore,
        String? makePkg,
        String? privacy,
        String? poolExample,
        String? installPs1,
        String? deployTxt,
        String? harness}) =>
    Facts(
      hub: hub ?? f.hub,
      client: client ?? f.client,
      agent: agent ?? f.agent,
      onboarding: onboarding ?? f.onboarding,
      arbEn: arbEn ?? f.arbEn,
      gitignore: gitignore ?? f.gitignore,
      makePkg: makePkg ?? f.makePkg,
      privacy: privacy ?? f.privacy,
      poolExample: poolExample ?? f.poolExample,
      installPs1: installPs1 ?? f.installPs1,
      deployTxt: deployTxt ?? f.deployTxt,
      harness: harness ?? f.harness,
    );

void main() {
  final f = _load();
  final bad = violations(f);
  for (final b in bad) {
    print('  FAIL: $b');
  }
  check(bad.isEmpty, '试用代调全链（18 组判据）无违规');

  // ── 正向断言：证明"真读到了"，而不是"扫到 0 处" ──
  check(f.hub.length > 10000, 'hub.js 真被读到（${f.hub.length} 字节）');
  check(f.client.contains('TrialClient'), 'trial_client.dart 真被读到');
  check(f.agent.contains('class AgentService'), 'agent_service.dart 真被读到');
  check(serverTurnLimit(f.hub) != null,
      '服务端硬顶被解析到（${serverTurnLimit(f.hub)} 轮）');
  check(advertisedTurns(f.arbEn) != null,
      'App 文案轮数被解析到（${advertisedTurns(f.arbEn)} 轮）');
  check(serverTrialStatusCodes(_read('lib/hub/hub.js')).length >= 8,
      '服务端试用地带状态码被解析到（${serverTrialStatusCodes(_read('lib/hub/hub.js'))}）');
  check(trialFailureValues(_read('lib/core/trial_client.dart')).length == 8,
      '客户端 8 个 TrialFailure 值被解析到（${trialFailureValues(_read('lib/core/trial_client.dart'))}）');

  // ── ★ 自检（positive control）：改坏副本，每份都必须被判出 ──
  // ① 两层额度闸漂移（服务端抬到 30、App 仍写 20）
  final m1 = _with(f,
      hub: f.hub.replaceFirst("TRIAL_TURN_LIMIT || '20'", "TRIAL_TURN_LIMIT || '30'"));
  check(violations(m1).any((s) => s.startsWith('③')), '自检①：两层额度闸不同值必须被判出');

  // ② 服务端错误码串改名，客户端识别不到
  final m2 = _with(f, hub: f.hub.replaceAll('trial_quota_exhausted', 'trial_exhausted_v2'));
  check(violations(m2).isNotEmpty, '自检②：耗尽错误码串改名必须被判出');

  // ③ 池耗尽不持久化（重启即复活 = 赠送额度被当成可回充）
  final m3 = _with(f,
      hub: f.hub.replaceFirst(
          'db.trial_pool_state.exhausted[entry.name] = {', '// removed'));
  check(violations(m3).any((s) => s.startsWith('⑥')), '自检③：耗尽不持久化必须被判出');

  // ④ 真 Key 可能入库
  final m4 = _with(f, gitignore: f.gitignore.replaceFirst('lib/hub/trial-pool.json', ''));
  check(violations(m4).any((s) => s.startsWith('⑩')), '自检④：.gitignore 漏排真 Key 文件必须被判出');

  // ⑤ 模板里混进真实 Key
  final m5 = _with(f,
      poolExample: f.poolExample.replaceFirst('sk-你的百炼Key', 'sk-1a2b3c4d5e6f7a8b9c0d'));
  check(violations(m5).any((s) => s.startsWith('⑩')), '自检⑤：模板里出现真实形态 Key 必须被判出');

  // ⑥ 客户端余量查询拼错路径
  //    ★ 锚点必须带 `'$hub/` 前缀：`/quota?agent_id=` 在**文件头的文档注释**里也有一份，
  //      裸替换只会改到注释、代码行不变 ⇒ 自检假绿（与"剥注释"同族的污染方向）。
  final m6 = _with(f,
      client: f.client.replaceFirst(r"'$hub/quota?agent_id=", r"'$hub/quota2?agent_id="));
  check(violations(m6).any((s) => s.startsWith('⑤')), '自检⑥：客户端查询路径写错必须被判出');

  // ⑦ 模态不支持时假装成功
  final m7 = _with(f, hub: f.hub.replaceAll("'input_type_unsupported'", "'ok_fake'"));
  check(violations(m7).any((s) => s.startsWith('⑧')), '自检⑦：模态不支持却假装成功必须被判出');

  // ⑧ 隐私政策删掉披露
  final m8 = _with(f, privacy: f.privacy.replaceAll('转发', ''));
  check(violations(m8).any((s) => s.startsWith('⑫')), '自检⑧：隐私政策删掉转发披露必须被判出');

  // ⑨ 服务端新增一类错误码、客户端没跟上（`sendJson(res, 402` 在试用地带里只此一处）
  final m9 = _with(f, hub: f.hub.replaceFirst('sendJson(res, 402', 'sendJson(res, 409'));
  check(violations(m9).any((s) => s.startsWith('⑬')),
      '自检⑨：服务端多出一种客户端归不了类的码必须被判出');

  // ⑩ 客户端表里漏登一个状态码
  final m10 = _with(f,
      client: f.client.replaceFirst('415: TrialFailure.inputUnsupported,', ''));
  check(violations(m10).any((s) => s.startsWith('⑬')),
      '自检⑩：客户端 statusToFailure 漏登状态码必须被判出');

  // ⑪ 枚举值没有接线到 agent_service（加了类别却没加话术）
  final m11 = _with(f,
      agent: f.agent.replaceFirst('TrialFailure.poolBusy', 'TrialFailure.poolBusyX'));
  check(violations(m11).any((s) => s.startsWith('⑭')),
      '自检⑪：枚举值未接线必须被判出');

  // ⑫ 接线了但 ARB 里没有对应键
  final m12 = _with(f,
      arbEn: f.arbEn.replaceFirst('"trialPoolBusyReply"', '"trialPoolBusyReplyX"'));
  check(violations(m12).any((s) => s.startsWith('⑭')),
      '自检⑫：ARB(en) 缺新文案键必须被判出');

  // ⑬ 部署接线里的 `\t` 被写成真 TAB（本轮抓到的真缺陷形态）
  final m13 = _with(f,
      installPs1: f.installPs1.replaceFirst(
          r'TRIAL_POOL_FILE=$DataDir\trial-pool.json',
          'TRIAL_POOL_FILE=\$DataDir\trial-pool.json'));
  check(violations(m13).any((s) => s.startsWith('⑮')),
      '自检⑬：部署脚本路径被写成真 TAB 必须被判出');

  // ⑭ 安装脚本干脆不再注入 TRIAL_POOL_FILE（另一种失败：功能没接上）
  final m14 = _with(f,
      installPs1: f.installPs1.replaceFirst('TRIAL_POOL_FILE=', 'TRIAL_POOL_FILE_DISABLED='));
  check(violations(m14).any((s) => s.startsWith('⑮')),
      '自检⑭：安装脚本不再注入 TRIAL_POOL_FILE 必须被判出');

  // ⑮ 工具续跑轮被重新计数（增量退回"无脑 +1"）
  final m15 = _with(f,
      hub: f.hub.replaceFirst(
          RegExp(r'if \(!isToolRound\) \{\s*used\.turns \+= 1;'), 'used.turns += 1;'));
  check(violations(m15).any((s) => s.startsWith('⑯')),
      '自检⑮：工具续跑轮被重新计数必须被判出');

  // ⑯ 额度闸退回裸判据（已用满时最后一轮的工具续跑会被 402 打断）
  final m16 = _with(f,
      hub: f.hub.replaceFirst('if (!isToolRound && used.turns >= TRIAL_TURN_LIMIT)',
          'if (used.turns >= TRIAL_TURN_LIMIT)'));
  check(violations(m16).any((s) => s.startsWith('⑯')),
      '自检⑯：额度闸不再排除工具续跑轮必须被判出');

  // ⑰ 上游非 2xx 退回三态白名单（401/404/409/422 会被透传）
  final m17 = _with(f,
      hub: f.hub.replaceFirst('r.status < 200 || r.status >= 300',
          'r.status === 400 || r.status === 429 || r.status >= 500'));
  check(violations(m17).any((s) => s.startsWith('⑰')),
      '自检⑰：上游非 2xx 退回三态白名单必须被判出');

  // ⑱a 宿主不再把试用模式接进 allowPlainRetry（接线被删）
  final m18a = _with(f,
      agent: f.agent.replaceFirst(
          'allowPlainRetry: () async => !await TrialClient.isTrialMode(),', ''));
  check(violations(m18a).any((s) => s.startsWith('⑱')),
      '自检⑱a：宿主丢掉 allowPlainRetry 接线必须被判出');

  // ⑱b harness 主路径丢了「复用同一响应」的解读器
  final m18b = _with(f,
      harness: f.harness.replaceFirst(
          'structured_output_unparsed_reused_response', 'reused_x'));
  check(violations(m18b).any((s) => s.startsWith('⑱')),
      '自检⑱b：harness 丢解读器必须被判出');

  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
