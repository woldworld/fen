/// 从主人的发言里**离线、确定性**地抽取画像候选。
///
/// ---------------------------------------------------------------------------
/// ⚠️ 先说清楚它**不是**什么（不夸大是硬纪律）
/// ---------------------------------------------------------------------------
/// 这**不是**模型驱动的理解，是**规则匹配**：
/// 「我是结构工程师」→ 命中"职业"规则 → 产出候选卡 `career:job = 结构工程师`。
///
/// 为什么不做模型抽取（虽然那会更聪明）：
/// 本仓的**上游试用模型从未真正跑通**（R6：不得称"已上线"），自配 Key 属于
/// 用户侧不可控变量。把画像更新**挂在一条跑不通的链路上**，结果是"看起来有这功能、
/// 实际永远不更新" —— 那比没有更糟。规则抽取的代价是**覆盖率有限**
/// （主人用很绕的说法表达偏好时抽不到），但它的收益是**零依赖、可离线、可单测、
/// 结果可预测**（同样的输入永远得到同样的卡，便于主人理解系统为什么这么记）。
///
/// ⇒ 模型抽取是**将来的增强**，接上时只需实现同一个
/// [ProfileCandidate] 产出接口，`ProfileCardStore.upsert` 一行都不用改。
///
/// ---------------------------------------------------------------------------
/// 三条设计约束
/// ---------------------------------------------------------------------------
/// 1. **只看主人的话**，不看 AI 回复。回复里会出现"你是一个…"这类句子，
///    拿它当主人的自述会记出完全相反的东西。
/// 2. **槽位决定粒度**：单值槽（职业 / 基本身份）上，不同值就是矛盾（会取代）；
///    多值槽（偏好 / 目标 / 习惯）上，键里带上对象，所以"喜欢咖啡"与"喜欢徒步"
///    并存，而"喜欢咖啡 → 讨厌咖啡"能被判为矛盾并取代。
/// 3. **不做语义相似度计算**：项目已拍板端侧不做向量 / embedding
///    （见 `user_profile_store.dart`）。这里的槽位归一化是**字面**操作。
library;

// ★ 唯一的 import，而且它**零依赖** —— 这样本文件能在纯 Dart VM 里 `dart run`，
//   于是规则可以被**真的执行**并逐条断言，而不是只靠扫源码猜它对不对。
//   ⚠️ 不许在这里 import `profile_card_store.dart`（它带 sqflite / Flutter，
//   一旦引入，`tool/verify_profile_cards.dart` 就再也跑不了行为断言）。
import 'profile_taxonomy.dart';

/// 规则抽取器。无状态、无 IO、可单测。
abstract final class ProfileCardExtractor {
  /// 一次最多抽取几条（防止一句长文刷出十几张卡）。
  static const int maxPerTurn = 5;

  /// 输入过短不抽（"好的" / "嗯"）。
  static const int minInputChars = 4;

  /// 主人**显式要求记住**时的置信度（比自动抽取高，但仍低于主人手写 1.0）。
  static const double explicitRememberConfidence = 0.8;

  static const String _slotCareerJob = 'career:job';
  static const String _slotIdentity = 'identity:basic';

  /// 职业词尾。用它把"我是我家里的老大"这类**不是职业**的句子挡掉。
  static const List<String> _jobSuffixes = <String>[
    '工程师', '设计师', '建筑师', '结构师', '建造师', '造价师', '监理',
    '老师', '教师', '教授', '讲师', '医生', '医师', '护士', '药师',
    '律师', '法官', '会计', '出纳', '审计', '税务师',
    '程序员', '开发', '架构师', '产品经理', '项目经理', '测试', '运维',
    '运营', '市场', '销售', '采购', '客服', '人事', 'HR',
    '老板', '创始人', '创业者', '合伙人', '个体户', '店主',
    '学生', '研究生', '博士生', '本科生',
    '司机', '厨师', '厨师长', '服务员', '保安', '快递员', '骑手',
    '编辑', '记者', '作家', '翻译', '导游', '公务员',
    '顾问', '研究员', '分析师', '咨询师', '经纪人', '摄影师',
    '自由职业', '画家', '音乐人', '主播', '教练',
  ];

  /// 抽取候选。[text] 必须是**主人本轮的原话**。
  ///
  /// ⚠️ 返回顺序 = 规则声明顺序（确定性）。同样的输入永远得到同样的结果，
  /// 这是"主人能理解系统为什么这么记"的前提。
  static List<ProfileCandidate> extract(String text) {
    final t = text.trim();
    if (t.length < minInputChars) return const [];

    final out = <ProfileCandidate>[];
    void add(ProfileCandidate c) {
      if (out.length >= maxPerTurn) return;
      // 同 slot 一场只留一条（后出现的更近，覆盖前面的）
      out.removeWhere((e) => e.slot == c.slot);
      out.add(c);
    }

    _explicitRemember(t, add);
    _career(t, add);
    _preference(t, add);
    _goal(t, add);
    _habit(t, add);
    _constraint(t, add);
    _residence(t, add);

    return out;
  }

  // ── 规则 ────────────────────────────────────────────────────────────

  /// 「记住：我下个月要搬到杭州」—— 主人显式下达，优先级最高。
  static void _explicitRemember(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'记(?:住|一下|下来)\s*[:：，,]?\s*(.{2,50})').firstMatch(t);
    if (m == null) return;
    final body = _clean(m.group(1)!);
    if (body.isEmpty) return;
    // ⚠️ 槽位必须由**陈述**算出，不能由清洗前的原文算 ——
    //   否则「记住：我下个月搬家」与「记住：下个月搬家」会算出两个槽位，
    //   同一件事在库里存两份，恰好破坏需求要求的"合并重复描述"
    //   （这条是一次实跑抓出来的：原文带「我」⇒ 前 8 字与陈述不同）。
    final statement = _asStatement(body);
    if (statement.isEmpty) return;
    add(ProfileCandidate(
      category: ProfileCategory.context,
      // 逐条独立：用内容做槽位 ⇒ 不同的事并存、同一件事能去重
      slot: 'explicit:${_slotKey(statement)}',
      statement: statement,
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
      confidence: explicitRememberConfidence,
    ));
  }

  /// 「我是结构工程师」/「我做前端开发」/「我干销售的」
  static void _career(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'我(?:是|做|干)(?:一[名个位]|个)?([^，。,.！!？?\s]{1,12})').firstMatch(t);
    if (m == null) return;
    final job = _clean(m.group(1)!);
    if (job.isEmpty) return;
    final isJob = _jobSuffixes.any((s) => job.endsWith(s) || job.contains(s));
    if (!isJob) return;
    add(ProfileCandidate(
      category: ProfileCategory.career,
      slot: _slotCareerJob,
      statement: '职业是$job',
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
    ));
  }

  /// 「我喜欢喝黑咖啡」/「我不喜欢开会」/「我讨厌被打断」
  static void _preference(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'我(?:更|比较|特别|很)?(喜欢|偏爱|爱|不喜欢|讨厌|反感|受不了)([^，。,.！!？?]{1,18})')
        .firstMatch(t);
    if (m == null) return;
    final polarity = m.group(1)!;
    final obj = _clean(m.group(2)!);
    if (obj.isEmpty) return;
    // 把同义的褒贬词**收敛成两个词**（喜欢 / 不喜欢）：
    // 这样"我爱咖啡"与"我喜欢喝咖啡"更容易落成同一条，"喜欢咖啡"与"讨厌咖啡"
    // 则明确落在同槽位的两个不同陈述上 ⇒ 判为矛盾并取代。
    final negative = polarity == '不喜欢' || polarity == '讨厌' ||
        polarity == '反感' || polarity == '受不了';
    // 槽位带**对象** ⇒ 不同对象并存；同一对象正负相反 ⇒ 判为矛盾并取代。
    add(ProfileCandidate(
      category: ProfileCategory.preference,
      slot: 'preference:${_slotKey(obj)}',
      statement: '${negative ? '不喜欢' : '喜欢'}$obj',
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
    ));
  }

  /// 「我想学英语」/「我打算明年换工作」/「我的目标是跑全马」
  static void _goal(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'我(?:的目标是|想|打算|计划|准备|希望)([^，。,.！!？?]{2,26})').firstMatch(t);
    if (m == null) return;
    final obj = _clean(m.group(1)!);
    if (obj.isEmpty) return;
    add(ProfileCandidate(
      category: ProfileCategory.goal,
      slot: 'goal:${_slotKey(obj)}',
      statement: '想$obj',
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
    ));
  }

  /// 「我每天早上六点起来跑步」/「我经常加班到十点」
  static void _habit(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'我(每天|每周|每月|每年|经常|通常|总是|一般不|向来)([^，。,.！!？?]{2,26})')
        .firstMatch(t);
    if (m == null) return;
    final freq = m.group(1)!;
    final obj = _clean(m.group(2)!);
    if (obj.isEmpty) return;
    add(ProfileCandidate(
      category: ProfileCategory.habit,
      slot: 'habit:${_slotKey(obj)}',
      statement: '$freq$obj',
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
    ));
  }

  /// 「我不能吃辣」/「我千万别在周末打扰我」/「我必须每天午休」
  static void _constraint(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'我(?:不能|不可以|不方便|必须|一定要|千万别|受不了)([^，。,.！!？?]{2,26})')
        .firstMatch(t);
    if (m == null) return;
    final obj = _clean(m.group(1)!);
    if (obj.isEmpty) return;
    final marker = m.group(0)!;
    final kind = marker.contains('必须') || marker.contains('一定要')
        ? '必须'
        : marker.contains('千万别')
            ? '不要'
            : '不能';
    add(ProfileCandidate(
      category: ProfileCategory.constraint,
      slot: 'constraint:${_slotKey(obj)}',
      statement: '$kind$obj',
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
    ));
  }

  /// 「我住在杭州」/「我在武汉工作」
  static void _residence(String t, void Function(ProfileCandidate) add) {
    final m = RegExp(r'我(?:住在|来自|老家是|在)([^，。,.！!？?\s]{2,10})(?:工作|生活|上班|定居)?')
        .firstMatch(t);
    if (m == null) return;
    final place = _clean(m.group(1)!);
    // 只认像地名/机构的短串，避免把"我在写代码"记成居住地
    if (place.length < 2 || place.length > 10) return;
    if (RegExp(r'(写|做|看|听|想|说|忙|吃|睡)').hasMatch(place)) return;
    add(ProfileCandidate(
      category: ProfileCategory.identity,
      slot: _slotIdentity,
      statement: '常在$place',
      evidence: '主人说「${_ellipsis(m.group(0)!)}」',
    ));
  }

  // ── 工具 ────────────────────────────────────────────────────────────

  /// 去掉首尾标点与语气助词。
  static String _clean(String s) => s
      .replaceAll(RegExp(r'^[\s，,。.！!？?：:、]+'), '')
      .replaceAll(RegExp(r'[\s，,。.！!？?：:、]+$'), '')
      .replaceAll(RegExp(r'^(那个|就是|嗯|呃|啊)'), '')
      .trim();

  /// 槽位键：**字面**截断（不做语义归一化，见文件头约束 3）。
  /// 取前 8 个字符：足够区分"咖啡"与"徒步"，又能让"喝黑咖啡"与"喝咖啡"
  /// 落到同一槽（前 8 字相同）—— 这是有意的粗粒度，宁可多取代一次，
  /// 也不要在同一件事上留两张互相打架的卡。
  static String _slotKey(String s) {
    final n = s.replaceAll(RegExp(r'[\s，,。.！!？?：:、]'), '');
    return n.length <= 8 ? n : n.substring(0, 8);
  }

  /// 把主人的第一人称原话转成客观陈述（需求要求"措辞客观简洁"）。
  static String _asStatement(String body) {
    var s = body;
    if (s.startsWith('我')) s = s.substring(1);
    return s.replaceAll(RegExp(r'^(的|是|要|会)'), '').trim();
  }

  static String _ellipsis(String s, {int max = 24}) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
