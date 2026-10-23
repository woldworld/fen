/// M10 · 人格模式 Persona Modes（PRD §4 M10，P1）。
///
/// **定位（PRD 原话）**：同一个人、不同场合（职业 / 社交 / 家庭语气），
/// **✅ 同一身份**，按模式收费（买"专门的模式"），架构成本 **近零**
/// （prompt / 策略层分场景配置）。
///
/// 为什么这样更好（PRD 原话）：**人格模式避免了"哪个才是真的你"的信任稀释**。
///
/// ---------------------------------------------------------------------------
/// 本模块就是把这句话变成可验证的规则
/// ---------------------------------------------------------------------------
/// 改造前，这套"分场合语气"是**散落的硬编码**：
/// ① 行为准则的 5 段文案直接写死在 `agent_service.dart` 的 `switch (mode)` 里；
/// ② 模式自带的头像 / 昵称 / 任务默认值又抄了一份在 `social_screen.dart` 的下拉框回调里；
/// ③ 切换模式会 `clearAllSocialLogsAndResetHandshakes()` —— 把**全部**聊天记录删掉、
///    把**所有人**的握手状态打回 `none`。
///
/// ③ 与 M10 的定位**直接冲突**：如果换一种语气就让对方重新变成陌生人，
/// 那"同一身份"就是假的，而"信任稀释"恰恰是 M10 要消灭的东西。
/// 因此本模块显式声明 [PersonaModes.wipesMemoryOnSwitch] == false，
/// 并把"切换人格 ≠ 换身份、≠ 清记忆"写成**可复算的断言**（`tool/verify_persona_role.dart`）。
///
/// 三条铁律（本层强制）：
/// 1. **人格不改身份** —— 人格是 prompt / 策略层属性；对外真身 ID、Ed25519 密钥、
///    与谁说过什么，全部不变。行为准则文案里**不得**出现任何 Agent ID
///    （人格不该记住"我是谁"，那是身份层的事）。
/// 2. **人格不删记忆** —— 切语气不清空社交记忆、不重置握手（否则"同一身份"失效）。
/// 3. **未知模式一律降级到 [PersonaModes.casual]** —— fail-safe，绝不抛异常，
///    也绝不把未知值当"自定义"透传（那会让 LLM 收到空准则）。
///
/// 本文件**零平台依赖**（不 import sqflite / SharedPreferences / Flutter），
/// `dart run tool/verify_persona_role.dart` 可直接复算全部判定。

library;

/// 人格模式的计费档（PRD："按模式收费（买'专门的模式'）"）。
///
/// ⚠️ 本档位**只是数据模型**，不是计费实现：真正收费要等定价与支付上线
/// （PRD §4 M10 ② 永久价格锁定 / §4 M8 试用额度）。P1 阶段只把"哪个模式是
/// 专门模式"这件事**说清楚、可复算**，避免将来定价时又要回头猜。
enum PersonaTier {
  /// 基础模式：默认可用，不单独收费。
  free,

  /// 专门模式：需单独购买（PRD 的"买专门的模式"）。
  paid,
}

/// 一个人格模式：**同一身份的另一种场合语气**。
class PersonaMode {
  /// 稳定 ID（落库用；一旦发布不得改名）。
  final String id;

  /// 行为准则前缀（与正文分开，便于校验"正文里没有身份信息"）。
  final String behaviorPrefix;

  /// 行为准则正文（不含身份信息；见铁律 1）。
  final String behaviorBody;

  /// 是否把主人的临时任务追加在正文之后（`custom` 模式）。
  final bool appendsTask;

  /// 该模式默认的头像 / 昵称（切模式时用，避免 UI 与工具各写一份）。
  final String avatar;
  final String nickname;

  /// 该模式默认的社交任务。
  final String defaultTask;

  /// 计费档。
  final PersonaTier tier;

  /// 购买键（`paid` 档非空；将来接定价用）。
  final String purchaseKey;

  const PersonaMode({
    required this.id,
    required this.behaviorPrefix,
    required this.behaviorBody,
    this.appendsTask = false,
    required this.avatar,
    required this.nickname,
    required this.defaultTask,
    this.tier = PersonaTier.free,
    this.purchaseKey = '',
  });

  /// 铁律 1 的显式声明：人格**永不**改变身份。
  ///
  /// 之所以做成一个恒为 false 的 getter 而不是"不写"，是因为"不写"没法被断言；
  /// 写成字段后，验证脚本可以断言"所有模式都声明不改身份"这条不变量。
  bool get changesIdentity => false;

  /// 铁律 2 的显式声明：人格**永不**清除记忆（见文件头 ③ 的说明）。
  bool get wipesMemory => false;

  /// 生成注入 prompt 的【行为准则】文本。
  ///
  /// 与改造前 `agent_service.dart` 的 5 段硬编码**逐字节一致** ——
  /// 本模块只做"把散落文案收拢成单一事实源"，不偷偷改语气。
  String directiveFor(String socialTask) => '$behaviorPrefix'
      '${appendsTask ? '$behaviorBody$socialTask' : behaviorBody}';

  /// 是否为基础（免费）模式。
  bool get isFree => tier == PersonaTier.free;

  @override
  String toString() => 'PersonaMode($id, ${tier.name})';
}

/// 人格模式注册表（**唯一事实源**）。
///
/// 文案与默认值的唯一出处：`agent_service` 的 prompt 组装、工具的参数兜底、
/// `social_screen` 的下拉框，都从这里取 —— 不再各写一份。
abstract final class PersonaModes {
  // ---- 稳定 ID 常量（落库值，禁止改）----
  static const String casual = 'casual';
  static const String business = 'business';
  static const String dating = 'dating';
  static const String emergency = 'emergency';
  static const String custom = 'custom';

  /// 全部模式（顺序 = UI 下拉框顺序，与改造前一致）。
  static const List<PersonaMode> all = [
    PersonaMode(
      id: casual,
      behaviorPrefix: '【行为准则】',
      behaviorBody: '松弛幽默的邻居。自然破冰，随性沟通。',
      avatar: '☕',
      nickname: '闲聊分身',
      defaultTask: '无特定任务，自由友善交谈。',
    ),
    PersonaMode(
      id: business,
      behaviorPrefix: '【行为准则】',
      behaviorBody: '冷酷高效商务代理。不许废话，直击痛点，互换资源。',
      avatar: '💼',
      nickname: '商务助理',
      defaultTask: '向周边节点自我介绍并寻求业务资源对接，互换联系方式。',
      tier: PersonaTier.paid,
      purchaseKey: 'persona.business',
    ),
    PersonaMode(
      id: dating,
      behaviorPrefix: '【行为准则】',
      behaviorBody: '高情商赛博僚机。幽默温和，优先找共同话题，绝不查户口。',
      avatar: '✨',
      nickname: '寻缘僚机',
      defaultTask: '友好温和地探寻对方兴趣，寻找共同喜好并真诚搭讪。',
      tier: PersonaTier.paid,
      purchaseKey: 'persona.dating',
    ),
    PersonaMode(
      id: emergency,
      behaviorPrefix: '【行为准则】',
      behaviorBody: '紧急求助！忽略闲聊，立刻求助并承诺回报。',
      avatar: '🚨',
      nickname: '紧急求助广播',
      defaultTask: '我的主人遇到了困难，需要即时求助，请伸出救援之手！',
      tier: PersonaTier.paid,
      purchaseKey: 'persona.emergency',
    ),
    PersonaMode(
      id: custom,
      behaviorPrefix: '【行为准则】',
      // 正文以换行结尾，拼上主人的临时任务 → 与改造前逐字节一致
      behaviorBody: '严格执行主人临时战术：\n',
      appendsTask: true,
      avatar: '🛠️',
      nickname: '自定义分身',
      defaultTask: '自由交流',
    ),
  ];

  static final Map<String, PersonaMode> _byId = {
    for (final m in all) m.id: m,
  };

  /// 默认模式（也是所有未知输入的降级目标）。
  static PersonaMode get defaultMode => _byId[casual]!;

  /// 按 ID 取模式；未知 / null → null（调用方自行决定是否降级）。
  static PersonaMode? byIdOrNull(String? id) => _byId[id];

  /// **fail-safe 解析**：未知 / null / 空串 一律降级到 [casual]。
  ///
  /// 为什么不降级到 `custom`：`custom` 的行为准则是"严格执行主人临时战术"，
  /// 若把未知值当 custom 透传，而主人又没填任务，LLM 会收到一条**空准则**
  /// （"严格执行：" 后面什么都没有）。降级到 casual 至少语义完整。
  static PersonaMode resolve(String? id) => _byId[id] ?? defaultMode;

  /// 直接产出可直接注入 prompt 的准则文本（未知模式自动降级）。
  static String directiveFor(String? id, {String task = ''}) =>
      resolve(id).directiveFor(task);

  /// 需要单独购买的模式（M10 "买专门的模式"）。
  static List<PersonaMode> get paidModes =>
      all.where((m) => m.tier == PersonaTier.paid).toList();

  /// 免费模式。
  static List<PersonaMode> get freeModes =>
      all.where((m) => m.tier == PersonaTier.free).toList();

  /// 铁律 2：切换人格**不**清记忆（改造前是清的，与"同一身份"冲突）。
  static bool get wipesMemoryOnSwitch => false;

  /// 铁律 1：切换人格**不**改身份。
  static bool get changesIdentityOnSwitch => false;
}
