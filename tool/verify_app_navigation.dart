// 0.86.0 守卫：**App 内导航（`open_app_page`）的"白名单与真实页面同源"**。
//
// 缘起（主人指令，逐步进行）：「其他 app 本身的操作，可用直接默认可调用……
// 用户一句话，主智能体都能帮用户搞定。」除了改设置，助手还应能**替主人打开页面**
// （「帮我打开设置 / 邮箱 / 工具页」）。
//
// 这个能力有一个**特有的失效模式**：页面白名单被**手抄两份**（工具里一份、
// UI 里一份）⇒ 迟早对不上：① 工具能"打开"一个 UI 里不存在的页面（用户看到报错面板）；
// ② UI 新增了页面，工具却不知道（能力缩水）；③ 某个页面后来需要参数了，
// 工具还按"无参"去构造（一打开就崩）。
//
// 本脚本把这几条钉住：
//   ① `lib/core/app_navigation.dart` **不 import 任何 ui/**（依赖方向是"UI 注入 core"）；
//   ② 注册表与工具**同源**：工具描述里的页面清单由 `${appPageKeys...}` 生成，
//      **不得**出现手抄的页面列表；工具只经 `openAppPage/resolveAppPageKey/appPageLabel`
//      访问（不自己拼页面名）；
//   ③ 工具档位 = `normal`（只导航 ⇒ 默认可直接调用，主人指令原话）；
//   ④ `main.dart` 启动时真的注册了 + 与 UI 共用同一个 `appNavigatorKey`；
//   ⑤ ★★ **别名表的每个目标键都必须在注册表里**（别名不得指向一个不存在的页面）；
//   ⑥ ★ 注册表**不得**收录"需要参数"的页面（WorldRoomScreen / TopicDetailScreen /
//      DigestScreen / BackupNudgeScreen）—— 那种入口一打开就报错；
//   ⑦ KB 把这条能力讲给用户（`kbVersion` 同步）；
//   ⑧ ★★ 注册表**不得**收录带「唯一入口」红线的审批页（`AgentActionInboxScreen`）——
//      它是 0.61.0 定死的红线（日志页签恒常显、不得门控，`verify_mode_visibility` ②
//      正面钉住"除社交页与其自身定义外无别处引用"）。登记它 = 凭空多一个引用点，
//      那条红线会**静默失效**（实测：0.86.0 首跑回归被 `verify_mode_visibility` 抓红）。
//
// 源文本扫描型脚本必须带**正控**（把好副本人为改坏，判据必须判出），否则匹配式一坏
// 就"扫到 0 处 → 恒绿"。
import 'dart:io';

int _pass = 0;
int _fail = 0;

void _check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

/// 剥注释（先块后行）——避免"说明文字里举的坏例子"被算成真实代码。
String _stripComments(String s) {
  var out = s.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  out = out.replaceAll(RegExp(r'//[^\n]*'), '');
  return out;
}

// ------------------------------------------------------------------
// 判据（纯函数，可被正控喂坏副本）
// ------------------------------------------------------------------

/// ① core 导航表**不依赖 UI**。
bool coreNavIsUiFree(String nav) {
  final code = _stripComments(nav);
  return !RegExp(r"import\s+'[^']*ui/").hasMatch(code) &&
      code.contains('appNavigatorKey') &&
      code.contains('registerAppPages(') &&
      code.contains('openAppPage(') &&
      code.contains('appPageKeys');
}

/// ② 注册表存在且用 `AppPage` 装配。
bool registryAssemblesPages(String pages) {
  final code = _stripComments(pages);
  return code.contains('List<AppPage> buildAppPages()') &&
      RegExp(r"AppPage\(\s*\n?\s*key:").hasMatch(code) &&
      code.contains("import '../core/app_navigation.dart';");
}

/// ③ 工具存在、档位 normal、**只经注册表 API**、且清单由 `${appPageKeys` 生成。
bool toolUsesRegistry(String agent) {
  final code = _stripComments(agent);
  final i = code.indexOf("name: 'open_app_page'");
  if (i < 0) return false;
  final seg = code.substring(i, (i + 2200).clamp(0, code.length));
  return seg.contains('permission: PermissionLevel.normal') &&
      seg.contains('resolveAppPageKey(raw, appPageKeys)') &&
      seg.contains('openAppPage(key)') &&
      seg.contains('appPageLabel(key)') &&
      // ★ 清单**必须**来自注册表（同源），不是手抄
      seg.contains(r'${appPageKeys.join(');
}

/// ④ main.dart 启动时注册 + 共用同一个导航键。
bool mainWiresNav(String main) {
  final code = _stripComments(main);
  return code.contains('registerAppPages(buildAppPages());') &&
      code.contains("import 'core/app_navigation.dart';") &&
      code.contains("import 'ui/app_pages.dart';") &&
      code.contains('navigatorKey = appNavigatorKey;');
}

/// ⑤ 别名表每个目标键都必须是注册表里的键。
///    （抽 string-literal 的 `key: '<x>'` 作为注册表键集。）
bool aliasesResolveIntoRegistry(String settings, String pages) {
  final regKeys = RegExp(r"key:\s*'([a-z0-9_]+)'")
      .allMatches(_stripComments(pages))
      .map((m) => m.group(1)!)
      .toSet();
  if (regKeys.isEmpty) return false;
  final s = _stripComments(settings);
  final i = s.indexOf('const alias = <String, String>{');
  if (i < 0) return false;
  final j = s.indexOf('};', i);
  if (j < 0) return false;
  final block = s.substring(i, j);
  final targets = RegExp(r":\s*'([a-z0-9_]+)'")
      .allMatches(block)
      .map((m) => m.group(1)!)
      .toList();
  if (targets.isEmpty) return false;
  return targets.every(regKeys.contains);
}

/// ⑥ 注册表**不得**收录需要参数的页面（会一打开就报错）。
bool registryExcludesArgPages(String pages) {
  final code = _stripComments(pages);
  for (final c in const [
    'WorldRoomScreen',
    'TopicDetailScreen',
    'DigestScreen',
    'BackupNudgeScreen',
  ]) {
    if (code.contains(c)) return false;
  }
  return true;
}

/// ⑦ KB 把"可替主人打开页面"讲给用户。
bool kbTellsNavigation(String kb) {
  return kb.contains('open in-app pages for you') &&
      kbAtLeast(kb, 28);
}

/// ⑧ 注册表**不得**收录审批页（0.61.0「唯一入口」红线）。
bool registryExcludesApprovalPage(String pages) {
  return !_stripComments(pages).contains('AgentActionInboxScreen');
}

/// ⑨ ★★ 0.107.0：隐私能力页名单（`privacyCapabilityPages`）**必须与注册表同源**。
///
/// 即：名单里的每个键都得是 `buildAppPages()` 真注册过的页面键 —— 手抄错一个字
/// / 页面后来改名 ⇒ 附注挂在了一个不存在的页面上（静默失效，正是本守卫的宿敌）。
/// 同时点名三类必须齐全（与 KB `agent_boundary` 的「不能代开的三类」逐一对应）。
bool privacyPagesAreRealPages(String nav, String pages) {
  final regKeys = RegExp(r"key:\s*'([a-z0-9_]+)'")
      .allMatches(_stripComments(pages))
      .map((m) => m.group(1)!)
      .toSet();
  if (regKeys.isEmpty) return false;
  final s = _stripComments(nav);
  final i = s.indexOf('const Map<String, String> privacyCapabilityPages');
  if (i < 0) return false;
  final j = s.indexOf('};', i);
  if (j < 0) return false;
  final keys = RegExp(r"'([a-z0-9_]+)':")
      .allMatches(s.substring(i, j))
      .map((m) => m.group(1)!)
      .toList();
  if (keys.isEmpty) return false;
  for (final must in const ['mail', 'phone_control', 'notify_sms']) {
    if (!keys.contains(must)) return false;
  }
  return keys.every(regKeys.contains);
}

/// ⑩ ★★ 0.107.0：导航回执必须 ①**显式定性「仅导航」** ②**带真实开关状态**。
///
/// 反的就是那次真机事故：回执只有一句「已为主人打开「邮箱」页面。」，
/// 模型转述成「邮箱已打开」，主人读成"邮箱已配好可用了"，模型还自撰了
/// 「之后我就能帮你读邮件、回邮件、自动处理了」。
/// ⇒ 定性语 + 开关事实**两个都在**才算过；缺任何一个都判红。
bool receiptDeclaresNavigationOnly(String agent) {
  final code = _stripComments(agent);
  final i = code.indexOf("name: 'open_app_page'");
  if (i < 0) return false;
  final seg = code.substring(i, (i + 2600).clamp(0, code.length));
  return seg.contains('**仅导航**') &&
      seg.contains('没有启用任何能力') &&
      seg.contains('_privacyCapabilityNoteFor(key)');
}

// ------------------------------------------------------------------

/// kbVersion 是**单调递增的整数串**。旧写法（断言某个具体快照值）属于**写死的版本快照**
/// （红线 13）—— 每次 KB bump 这几条守卫就集体假红。
/// ⇒ 只断言**下限**：该能力自 KB v28 起存在，之后怎么涨都算满足。
bool kbAtLeast(String kb, int min) {
  final m = RegExp(r"kbVersion\s*=\s*'(\d+)'").firstMatch(kb);
  if (m == null) return false;
  final v = int.tryParse(m.group(1)!);
  return v != null && v >= min;
}

void main() {
  // 自检：kbAtLeast 认下限、不认快照（否则下次 KB bump 又集体假红）
  _check(kbAtLeast("const String kbVersion = '29';", 28),
      '自检：kbVersion 29 满足「大于或等于 28」');
  _check(!kbAtLeast("const String kbVersion = '27';", 28),
      '自检：kbVersion 27 不满足「大于或等于 28」（证明不是恒真）');

  print('== App 内导航守卫（open_app_page）==');
  final nav = _read('lib/core/app_navigation.dart');
  final pages = _read('lib/ui/app_pages.dart');
  final agent = _read('lib/core/agent_service.dart');
  final main = _read('lib/main.dart');
  final kb = _read('lib/core/system_knowledge.dart');
  final settings = _read('lib/core/app_self_settings.dart');

  print('  --- 文件可读 ---');
  _check(nav.isNotEmpty, '读得到 app_navigation.dart');
  _check(pages.isNotEmpty, '读得到 ui/app_pages.dart');
  _check(agent.isNotEmpty && main.isNotEmpty, '读得到 agent_service.dart / main.dart');
  _check(kb.isNotEmpty && settings.isNotEmpty, '读得到 system_knowledge.dart / app_self_settings.dart');

  print('  --- ①–⑦ 判据 ---');
  _check(coreNavIsUiFree(nav), '① core 导航表不 import ui/（依赖方向：UI 注入 core）');
  _check(registryAssemblesPages(pages), '② 注册表 buildAppPages() 用 AppPage 装配');
  _check(toolUsesRegistry(agent),
      '③ open_app_page：normal 档 + 只经注册表 API + 清单由 \${appPageKeys} 生成（同源）');
  _check(mainWiresNav(main), '④ main.dart 启动时注册 + 与 UI 共用同一个 appNavigatorKey');
  _check(aliasesResolveIntoRegistry(settings, pages),
      '⑤ ★★ 别名表每个目标键都在注册表里（别名不得指向不存在的页面）');
  _check(registryExcludesArgPages(pages), '⑥ 注册表未收录"需要参数"的页面');
  _check(kbTellsNavigation(kb), '⑦ KB 讲给用户 + kbVersion 大于或等于 28');
  _check(registryExcludesApprovalPage(pages),
      '⑧ ★★ 注册表未收录审批页 AgentActionInboxScreen（0.61.0「唯一入口」红线：日志页签恒常显）');
  _check(privacyPagesAreRealPages(nav, pages),
      '⑨ ★★ 隐私能力页名单与注册表同源（mail/phone_control/notify_sms 三类齐全、且都真在注册表里）');
  _check(receiptDeclaresNavigationOnly(agent),
      '⑩ ★★ 导航回执显式定性「仅导航」+ 带真实开关状态（杜绝"打开页面"被说成"能力已启用"）');

  print('  --- 交叉核验（注册表键 ⟷ 工具可用性）---');
  final regKeys = RegExp(r"key:\s*'([a-z0-9_]+)'")
      .allMatches(_stripComments(pages))
      .map((m) => m.group(1)!)
      .toSet();
  _check(regKeys.length >= 15, '注册页数量 = ${regKeys.length}（≥15，证明不是空表）');
  for (final must in const [
    'settings', 'advanced_settings', 'mail', 'phone_control', 'notify_sms',
    'memory', 'diagnostics', 'tools', 'passport', 'identity_backup',
  ]) {
    _check(regKeys.contains(must), "注册表含关键页 '$must'");
  }

  print('  --- positive control ---');
  _check(!coreNavIsUiFree(nav + "\nimport '../ui/settings_screen.dart';"),
      '正控①：core 里加 ui import ⇒ 判出 ✓');
  _check(!registryAssemblesPages(pages.replaceAll('List<AppPage> buildAppPages()', '')),
      '正控②：抹掉 buildAppPages 签名 ⇒ 判出 ✓');
  _check(!toolUsesRegistry(agent.replaceAll('openAppPage(key)', '')),
      '正控③：工具绕过 openAppPage ⇒ 判出 ✓');
  _check(
      !toolUsesRegistry(agent.replaceAll(r'${appPageKeys.join(', '')),
      '正控③b：清单改成手抄字面量（不同源）⇒ 判出 ✓');
  _check(!mainWiresNav(main.replaceAll('registerAppPages(buildAppPages());', '')),
      '正控④：main 不注册 ⇒ 判出 ✓');
  _check(
      !aliasesResolveIntoRegistry(
          settings.replaceAll("'设置': 'settings',", "'设置': 'nonexistent_page',"),
          pages),
      '正控⑤：别名指向不存在的页面 ⇒ 判出 ✓');
  _check(!registryExcludesArgPages(pages + "\nAppPage(key: 'z', label: 'z', builder: (_) => const DigestScreen())"),
      '正控⑥：收录需参数页面 ⇒ 判出 ✓');
  _check(!kbTellsNavigation(kb.replaceAll('open in-app pages for you', '')),
      '正控⑦：KB 抹掉该句 ⇒ 判出 ✓');
  _check(
      !registryExcludesApprovalPage(pages +
          "\nAppPage(key: 'pending_suggestions', label: 'x', builder: (_) => const AgentActionInboxScreen())"),
      '正控⑧：把审批页登记进注册表 ⇒ 判出 ✓');
  _check(!privacyPagesAreRealPages(nav.replaceAll("'mail':", "'mail_typo':"), pages),
      '正控⑨：隐私页名单键抄错（不在注册表里）⇒ 判出 ✓');
  _check(
      !privacyPagesAreRealPages(
          nav.replaceAll(
              'const Map<String, String> privacyCapabilityPages',
              'const Map<String, String> _renamedAway'),
          pages),
      '正控⑨b：名单整段改名（事实源不存在了）⇒ 判出 ✓（反向：恒绿才是坏）');
  _check(!receiptDeclaresNavigationOnly(agent.replaceAll('**仅导航**', '')),
      '正控⑩：回执抹掉「仅导航」定性 ⇒ 判出 ✓');
  _check(!receiptDeclaresNavigationOnly(agent.replaceAll('_privacyCapabilityNoteFor(key)', '')),
      '正控⑩b：回执不带真实开关状态 ⇒ 判出 ✓');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) exitCode = 1;
}
