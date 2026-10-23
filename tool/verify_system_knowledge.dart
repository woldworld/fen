// 纯 Dart 校验脚本：守住《系统知识库》`lib/core/system_knowledge.dart` 的更新纪律。
// 运行：dart run tool/verify_system_knowledge.dart
//
// ★★ 为什么需要这个脚本（0.69.0 的血泪）：
//   `system_knowledge.dart` 顶部白纸黑字写着 ——
//   「Entries ship with the app; **feature changes update the matching entry in the same
//     commit**; app update = KB update」。
//   但 0.67.0（晨间问候 + 三日回顾）与 0.68.0（长期画像）**两轮都没有动 KB**，
//   原因很直接：**46 个 verify_* 脚本里，零个引用过 `HelpEntry` / `kbVersion`**
//   ⇒ 这条纪律**没有任何机器盯着**，只能靠人记得，而人一定会忘（已实证两次）。
//
// 本脚本盯四件事：
//   ① **结构完整**：每条 HelpEntry 四个字段都非空、steps 有实质内容；
//   ② **id 唯一**（重复 id 会让检索静默丢条目）；
//   ③ **功能 ↔ 条目对账**：[_requiredIds] 是一份**登记簿** ——
//      ★ 新增用户可见功能时，**必须在同一份提交里往这里加一行**；
//      缺一条就红。它可以被人绕过（改清单），但**它让"忘记"必须先被写下来**。
//   ④ **开关可检索**：主人问「怎么关掉画像 / 自动回忆」时要能命中 ⇒
//      那几个隐私开关的关键词必须出现在某条目的 keywords 里。
//   ⑤ **语言契约**：KB 按既定设计以**英文**为唯一事实源。
//      ★ 允许的例外形态（0.69.0 考据后的修订，**不要改回一刀切**）：
//        正文里可以写 `Xiaohuang Community page (小荒社区)` —— **英文译名在前、
//        界面原名在括号内**。这不是"中文泄漏"，而是与 R7 同名纪律对齐：
//        界面上显示的是中文名，KB 若不附原名，中文用户拿着条目对不上界面。
//      ⇒ 判据改为：**剔除所有括号片段后再扫**，括号外的中文仍一律红灯。

import 'dart:io';

/// 剔除括号（含全角括号）后的文本才算"正文"，用于语言契约检查（判据⑤的说明见文件头）。
String _stripParenthesized(String s) =>
    s.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '()');

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

/// ★ 用户可见功能的 KB 对账清单（**新功能上线必须同步补一行**，见文件头说明 ③）。
const List<String> _requiredIds = [
  'onboarding',
  'free_trial',
  'apikey',
  'local_model',
  'backup_code',
  'export_archive',
  'import_archive',
  'device_migration',
  'identity_did',
  'radar',
  'channels',
  'world_rooms',
  'room_create',
  'room_hosting',
  'room_pacing',
  'delegation',
  'suggestion_cards',
  'observation_mode',
  'intercards',
  'passport',
  'endorsements',
  'contributions',
  'skill_market',
  'reputation',
  'main_chat',
  'memory',
  'dream_reflection',
  'daily_digest',
  // ↓ 0.67.0（晨间问候 + 三日回顾）——两轮漏登记后补上
  'morning_greeting',
  // ↓ 0.70.0 W1（提醒/待办 + 记忆管理）
  'reminders',
  // ↓ 0.71.0 W2（真搜索：自备 Key 直连 + 基础模式兜底）
  'search',
  // ↓ 0.72.0 W3（语音：长按转文字输入 + 默认关的语音播报）
  'voice',
  // ↓ 0.73.0 W4（文档理解：本地解析零上传 + 试用互斥门）
  'documents',
  // ↓ 0.74.0 W5（只读系统日历 + 智能体周报）
  'system_calendar',
  'agent_weekly_report',
  // ↓ 0.75.0 W6（通知监听 + 短信·只读；sideload 渠道专属）
  'notify_sms',
  // ↓ 0.68.0 / 0.69.0（长期画像 + 画像注入开关）
  'long_term_profile',
  'notifications_mute',
  'serendipity',
  'device_control',
  'builtin_tools',
  'email',
  'custom_tools',
  'social_logs',
  'contacts_roster',
  // ↓ 0.89.0（联邦名册自动拉取：默认关 + 只收录不发信 + 可一键清空）
  'federation_auto_pull',
  'gifting',
  'circles',
  'privacy_data',
  'language',
  'theme',
  'full_mode',
  'glossary',
  'trial_exhausted',
  'input_limits',
  'admin_server',
  // ↓ 0.79.0（系统自检：只读底座事实 + FTS5 降级显形）
  'diagnostics',
  // ↓ 0.88.0（边界条目：能 / 不能替主人做什么）
  'agent_boundary',
  // ↓ 0.115.0（客户端内举报入口：入口 / 工单号 / 查状态 / 申诉一次为限）
  'report',
];

/// 主人最可能问"怎么关"的隐私开关 ⇒ KB 必须能被这些词命中。
const List<String> _switchKeywords = [
  'recall',
  'profile',
];

/// ⑥ 边界条目把"能 / 不能替主人做什么"讲给用户（0.88.0）。
///
/// 判据 = 四句话都在：① 清单来自**真实工具表**；② 隐私能力**不能替主人开启**；
/// ③ 外发/不可逆动作**先确认**；④ **不伪造成功**。
bool boundaryTellsLimits(String src) =>
    src.contains("HelpEntry('agent_boundary'") &&
    src.contains('real tool list') &&
    src.contains('CANNOT switch on privacy abilities') &&
    src.contains('confirmed first') &&
    src.contains('never invents steps or fakes success');

/// ⑦ 联邦名册自动拉取条目把"默认关 / 只收录不发信 / 可清空"讲给用户（0.89.0）。
///
/// 判据 = 四句话都在：① 开关**默认关**且**只有主人**能开；② 有**节流与上限**
/// （6h / 20 / 200）；③ **绝不自动发信**（仍走审查网关/观察模式/预算闸）；
/// ④ 可**一键清空**机器收录项、且**不动主人的手动收录**。
bool federationAutoPullTellsLimits(String src) =>
    src.contains("HelpEntry('federation_auto_pull'") &&
    src.contains('OFF by default; only you can turn it on') &&
    src.contains('max once per 6h, 20 per pull, 200 total') &&
    src.contains('never sends messages') &&
    src.contains('Clear auto-collected');

/// ⑧ 举报条目把"客户端内提交 / 工单号 / 申诉一次为限 / 被举报人不知举报人"
/// 讲给用户（0.115.0）。
///
/// 判据 = 四句话都在：① 举报**在应用内**提交（不靠邮件）；② 提交后
/// **立刻拿到工单号**；③ **申诉一次为限**；④ **被举报人看不到举报人身份**。
///
/// ★★ **判据必须按「条目切片」断言，不能对整份 src 做子串搜索**
///   （承 0.105.0 决策 #69「判据断言的是事实，不是字符串」）：
///   初版写成 `src.contains('in-app')`，而 KB 里 **`in-app` 出现 5 处**
///   （`battery_autostart` 的 in-app guide / `builtin_tools` 的 in-app pages /
///   `glossary` 的 in-app dictionary …）⇒ 正控把标题改成 "by email" 之后，
///   整份 src 里**仍然有** 'in-app' ⇒ 判据仍为真 ⇒ 正控⑧b **判不出**。
///   ⇒ 修法：从 src 里**先抠出 `report` 这一条**（用与 ① 相同的正则），
///   再在那一条的 title / keywords / steps 上断言。
String _entryById(String src, String id) {
  // ★★ 必须用 raw 串**拼接**：Dart 的 raw string（r"..."）**不做插值**，
  //   写成 r"...'$id'..." 会把 `$id` 当**字面量**匹配 ⇒ 永远抠不出条目
  //   （本轮实测：初版就是这么写的 ⇒ 切片恒为空 ⇒ 三条断言全红）。
  //   id 由调用方给固定字面量（'report'），故只需按正则元字符转义一下。
  final escapedId = id.replaceAll(r'\', r'\\').replaceAll(r'$', r'\$');
  final re = RegExp(r"HelpEntry\(\s*'" +
      escapedId +
      r"',\s*'((?:[^']|\\')*)',\s*'((?:[^']|\\')*)',\s*'((?:[^']|\\')*)'\)");
  final m = re.firstMatch(src);
  if (m == null) return '';
  return '${m.group(1)} ${m.group(2)} ${m.group(3)}';
}

bool reportTellsLimits(String src) {
  final e = _entryById(src, 'report');
  if (e.isEmpty) return false;
  return e.contains('in-app') &&
      e.contains('ticket number') &&
      e.contains('one appeal per ticket') &&
      e.contains('never sees who reported them');
}

/// ⑨ 隐私条目的「数据去哪」必须与真实行为一致（0.116.0）。
///
/// 判据 = 四句话都在：① 限流计数按**截断网段**做键；② **全量 IP 不落盘**；
/// ③ 分钟级计数 **2 小时内**清掉；④ 按日计数 **25 小时内**清掉。
///
/// ★ 为什么必须钉：P0-b / P0-c 让 hub 真的开始处理来源 IP（截断 + 限流 + 定时清扫），
///   隐私政策五语种已披露，但 KB 那条还写着 "the server sees signatures and public-log
///   hashes only" —— **KB 是 App 内 /docs /faq 的唯一事实源**，它不改就等于 App 里继续骗人。
bool privacyDataTellsIpHandling(String src) {
  final e = _entryById(src, 'privacy_data');
  if (e.isEmpty) return false;
  return e.contains('truncated network prefix') &&
      e.contains('never written to disk') &&
      e.contains('within 2 hours of inactivity') &&
      e.contains('within 25 hours');
}

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

void main() {
  print('== verify_system_knowledge (知识库更新纪律) ==');

  final src = _read('lib/core/system_knowledge.dart');
  check(src.isNotEmpty, 'system_knowledge.dart 存在');
  if (src.isEmpty) {
    print('');
    print('== 结果：PASS=$_pass  FAIL=$_fail ==');
    exit(1);
  }

  // ① 结构：抓每条 entry 的四段（格式固定，见该文件常量区）
  final entryRe = RegExp(
      r"HelpEntry\(\s*'([^']+)',\s*'((?:[^']|\\')*)',\s*'((?:[^']|\\')*)',\s*'((?:[^']|\\')*)'\)");
  final entries = entryRe.allMatches(src).toList();
  check(entries.length >= 50, '解析出 ${entries.length} 条 KB 条目（>= 50）');

  final ids = <String>[];
  var empty = 0;
  var shortSteps = 0;
  for (final m in entries) {
    final id = m.group(1)!;
    final steps = m.group(4)!;
    ids.add(id);
    if (id.trim().isEmpty ||
        m.group(2)!.trim().isEmpty ||
        m.group(3)!.trim().isEmpty ||
        steps.trim().isEmpty) {
      empty++;
    }
    if (steps.trim().length < 40) shortSteps++;
  }
  check(empty == 0, '所有条目四字段非空${empty == 0 ? '' : '（有 $empty 条残缺）'}');
  check(shortSteps == 0,
      '所有条目 steps 有实质内容（>=40 字符）${shortSteps == 0 ? '' : '（有 $shortSteps 条过短）'}');

  // ② id 唯一
  final unique = ids.toSet();
  check(unique.length == ids.length,
      '条目 id 唯一（${ids.length} 条 / ${unique.length} 个 id）');

  // ③ 功能 ↔ 条目对账
  final missing = _requiredIds.where((id) => !unique.contains(id)).toList();
  check(missing.isEmpty,
      'KB 覆盖 ${_requiredIds.length} 个登记在册的功能${missing.isEmpty ? '' : '，缺: $missing'}');

  // ④ 隐私开关可检索
  for (final kw in _switchKeywords) {
    check(src.contains(kw),
        'KB 含关键词 "$kw"（主人问「怎么关」时能命中）');
  }
  // ★★ 0.84.0：KB 的**指路必须指向当前的信息架构** —— 引擎 / 记忆 / 灵魂已在
  //   0.83.0 搬进「进阶设置」独立页，主题 / 语言 / 模式其实在**顶部工具栏**。
  //   只钉"提到了设置页"是不够的：指向错页 = 用户照做却找不到，等于没有。
  check(src.contains('Settings -> Advanced settings -> Memory'),
      'KB 把「记忆」指向进阶设置页（Settings -> Advanced settings -> Memory）');
  check(src.contains('Settings → Advanced settings → Big Brain Engine'),
      'KB 把「大脑引擎」指向进阶设置页');
  check(!src.contains('Settings → Theme') && !src.contains('Settings → Language'),
      '★ KB 不再把主题 / 语言说成"在设置里"（它们在顶部工具栏）');
  check(src.contains('TOP TOOLBAR'), 'KB 明说主题 / 语言 / 模式切换在顶部工具栏');
  check(src.contains('NO mode switch inside Settings'),
      '★ KB 明说"设置里刻意没有模式开关"（防用户来回找）');

  // ⑤ 语言契约：KB 刻意的语言 = 纯英文
  final cjk = RegExp(r'[\u4e00-\u9fff]');
  final polluted = <String>[];
  for (final m in entries) {
    final blob = _stripParenthesized(
        '${m.group(2)!} ${m.group(3)!} ${m.group(4)!}');
    if (cjk.hasMatch(blob)) polluted.add(m.group(1)!);
  }
  check(polluted.isEmpty,
      'KB 正文为英文（括号内界面原名除外）${polluted.isEmpty ? '' : '，含中文的条目: $polluted'}');
  final byId = {for (final m in entries) m.group(1)!: m.group(4)!};
  check(byId.containsKey('long_term_profile') &&
          byId['long_term_profile']!.contains('Auto recall'),
      'long_term_profile 条目说明了「回忆开关是总闸」（二级 gate 的对外口径）');

  // ⑥ 边界条目：把"能 / 不能替主人做什么"讲给用户（0.88.0）
  check(boundaryTellsLimits(src),
      'agent_boundary 条目讲清三条边界（真清单 / 隐私不可代开 / 外发先确认 / 不伪造成功）');
  check(src.contains('what can you do for me'),
      '边界条目关键词覆盖"你能替我做什么"（主人问得出、KB 命得中）');
  check(src.contains('what can you not do'),
      '边界条目关键词覆盖"你不能做什么"');
  // 正控：抹掉"不能替主人开启" ⇒ 判据必须判出
  check(
      !boundaryTellsLimits(
          src.replaceAll('CANNOT switch on privacy abilities', '')),
      '正控⑥：抹掉"不能替主人开启" ⇒ 判出 ✓');
  // 正控：把清单来源改成"凭记忆" ⇒ 判据必须判出（同源纪律）
  check(!boundaryTellsLimits(src.replaceAll('real tool list', 'my memory')),
      '正控⑥b：把清单来源改成"凭记忆" ⇒ 判出 ✓');

  // ⑦ 联邦名册自动拉取条目：默认关 / 节流上限 / 不发信 / 可清空（0.89.0）
  check(federationAutoPullTellsLimits(src),
      'federation_auto_pull 条目讲清四条（默认关且主人专属 / 节流上限 / 绝不自动发信 / 可一键清空）');
  check(src.contains('never sends messages'),
      '自动拉取条目明确"绝不自动发信"（红线：对外动作不可由拉取流程触发）');
  // 正控：抹掉"默认关"⇒ 判据必须判出（默认开是红线之反面）
  check(
      !federationAutoPullTellsLimits(
          src.replaceAll('OFF by default; only you can turn it on', 'ON by default')),
      '正控⑦：抹掉"默认关" ⇒ 判出 ✓');
  // 正控：抹掉"节流上限"⇒ 判据必须判出（无节流 = 拉爆名册）
  check(
      !federationAutoPullTellsLimits(
          src.replaceAll('max once per 6h, 20 per pull, 200 total', 'no limit')),
      '正控⑦b：抹掉"节流上限" ⇒ 判出 ✓');

  // ⑧ 举报条目：客户端内提交 / 工单号 / 申诉一次为限 / 被举报人不知举报人
  //    （0.115.0 · 《服务条款》§6 的对外承诺必须能在 KB 里被查到）
  check(reportTellsLimits(src),
      'report 条目讲清四条（应用内提交 / 工单号 / 申诉一次为限 / 被举报人不知举报人）');
  // ★ 下面两条同样**按条目切片**断言（不搜整份 src）—— 理由同上：
  //   整份 src 里 'legal@wold.world' 可能出现在**别的**条目，
  //   那时"举报条目里有邮箱"就被别处的邮箱顶替 ⇒ 判据恒真。
  final reportEntry = _entryById(src, 'report');
  check(reportEntry.contains('how do I report someone'),
      '举报条目关键词覆盖"how do I report someone"（主人问得出、KB 命得中）');
  check(reportEntry.contains('legal@wold.world'),
      '举报条目区分：对人的举报走应用内、对服务本身的投诉走邮箱');
  // 正控：抹掉"申诉一次为限" ⇒ 判据必须判出（无限申诉 = 条款承诺失信）
  check(
      !reportTellsLimits(
          src.replaceAll('one appeal per ticket', 'unlimited appeals')),
      '正控⑧：抹掉"申诉一次为限" ⇒ 判出 ✓');
  // 正控：把"应用内提交"改成"邮件提交" ⇒ 判据必须判出
  check(
      !reportTellsLimits(src.replaceAll('Report a user (in-app)',
          'Report a user (by email)')),
      '正控⑧b：把"应用内提交"改成"邮件提交" ⇒ 判出 ✓');

  // ⑨ 隐私条目：IP 处理必须写进 KB（0.116.0）
  check(privacyDataTellsIpHandling(src),
      'privacy_data 条目讲清 IP 处理（截断网段 / 全量 IP 不落盘 / 两档保留期）');
  // 正控：抹掉"全量 IP 不落盘" ⇒ 判出（这句最容易被下一轮"顺手精简"删掉）
  check(
      !privacyDataTellsIpHandling(
          src.replaceAll('never written to disk', 'stored indefinitely')),
      '正控⑨：抹掉「全量 IP 不落盘」 ⇒ 判出 ✓');
  // 正控：抹掉按日保留期 ⇒ 判出（只留分钟级 = 保留期承诺残缺）
  check(
      !privacyDataTellsIpHandling(
          src.replaceAll('within 25 hours', 'indefinitely')),
      '正控⑨b：抹掉按日保留期 ⇒ 判出 ✓');

  print('');
  print('== 结果：PASS=$_pass  FAIL=$_fail ==');
  exit(_fail == 0 ? 0 : 1);
}
