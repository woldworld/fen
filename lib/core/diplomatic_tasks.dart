/// M-外交 · 内置外交任务库（Diplomatic Task Library）。
///
/// **为什么存在**：外交分身的「密令任务」(`social_task`) 由主人在
/// 「小荒社区 → 外交假面」页填写；**若主人不知道写什么、留空，任务就是空串**，
/// 分身带着一条空指令进入自由聊天 ⇒ 只会说"你好 / 在吗 / 哈哈"这类无目的寒暄
/// （实测反馈：分身们陷入无意义的空聊）。本模块提供一组**内置的、可执行的
/// 外交任务**，在任务为空（或只是占位空话）时按人格模式自动补一条，
/// 让分身一开口就带着**目的**，聊得**有营养**。
///
/// ---------------------------------------------------------------------------
/// 三条设计纪律（本层强制，均有 `tool/verify_diplomatic_tasks.dart` 复算）
/// ---------------------------------------------------------------------------
/// 1. **只补空，不覆盖** —— 主人填的永远优先。`effective()` 只在 stored 为空 /
///    仅占位空话时回落内置库；一旦主人写过实质任务，原样使用。
/// 2. **确定性** —— 同一 (人格模式, 分身 ID) 永远得到**同一条**任务，不会每次
///    刷新 UI 都换一句（否则"密令"抖得主人无法预期、也没法复算）。
///    需要另一条时，走**显式**的 [reroll]（UI 的"🎲 换一个"）。
/// 3. **零平台依赖** —— 不 import Flutter / sqflite / SharedPreferences，
///    `dart run tool/verify_diplomatic_tasks.dart` 可直接复算（与 `persona_mode.dart` 同款）。
///
/// ⚠️ 语言：任务文案是**注入 LLM 的提示词**（`【主人的密令任务】`），
/// 与 `persona_mode.dart` 的 `behaviorBody` 同性质 —— **刻意保持中文单语**，
/// 不随 UI 语种本地化（服务端/提示词不本地化，见项目 i18n 纪律 R7）。
library;

import 'dart:math' as math;

/// 内置外交任务库（**唯一事实源**）。
abstract final class DiplomaticTasks {
  /// 各人格模式的任务池。键 = `PersonaModes` 的稳定 ID。
  ///
  /// 每条都是**可执行、有目的、能推进对话**的动作 —— 不是"聊天吧"这种空话。
  static const Map<String, List<String>> pools = {
    // 闲聊分身（松弛幽默的邻居）：自然破冰 + 交换见闻
    'casual': [
      '和对方聊聊你最近读到/听到的一个冷知识，再问问对方有没有类似的趣闻。',
      '问问对方今天过得怎么样，分享一件让你自己也觉得好笑的小事。',
      '和对方交换一个各自家乡的风土人情或一道特色吃食。',
      '聊一部最近看过的电影或一本书，说说最打动你的那个细节。',
      '从天气 / 通勤 / 宠物这类日常小事切入，聊出一个双方都有话说的具体话题。',
      '分享一个最近的小确幸，并邀请对方也分享一件开心的事。',
    ],
    // 商务助理（冷酷高效）：互换资源、找对接
    'business': [
      '用三句话向对方说明你能提供的资源，并直问对方当前最缺的一环。',
      '找出你与对方业务的互补点，提出一个可落地的小合作。',
      '询问对方的主营方向与需求，尝试约一个下一步对接的时间。',
      '向对方简短自我介绍业务范围，并交换一个可继续联络的方式（不涉隐私）。',
      '就对方公开的业务方向给出一个具体建议，观察是否有合作意愿。',
    ],
    // 寻缘僚机（高情商）：找共同点、真诚搭讪
    'dating': [
      '从对方的人设签名里找一个线索，自然地展开一个共同话题。',
      '聊聊各自的兴趣爱好，找出至少一个共同点并深入聊下去。',
      '用轻松的方式问问对方理想的周末是怎么过的（别查户口）。',
      '分享一个你最近的小爱好，并邀请对方聊聊 ta 的。',
      '找一件两个人都可能感兴趣的活动，试探对方的兴趣点。',
    ],
    // 紧急求助广播：说清困境 + 给出回报
    'emergency': [
      '说明你方遇到的紧急困难，明确说出需要什么样的一臂之力。',
      '向对方发出求助，并说明你方在事后能提供什么回报。',
      '简述眼下的困境，请对方帮忙牵线或提供一条可行的线索。',
    ],
    // 自定义分身（空任务兜底）：通用目的型任务
    'custom': [
      '先礼貌破冰，再抛出一个具体话题，让这轮对话有实质内容。',
      '问问对方最近在忙什么，看有没有你帮得上忙的地方。',
      '找一个双方都可能关心的具体问题，交换一下看法。',
    ],
  };

  /// 未知 / 未注册模式的兜底任务池（fail-safe，绝不返回空）。
  static const List<String> generic = [
    '先礼貌破冰，再找一个具体话题，让对话有实质内容。',
    '了解对方是谁、在做什么，并说明你能提供什么。',
  ];

  /// 被视作"没有实质任务"的占位空话（历史默认值 / 用户留白）。
  ///
  /// 为什么要连**占位空话**一起当"空"：`casual` 的历史默认值是
  /// 「无特定任务，自由友善交谈。」、`custom` 是「自由交流」——
  /// 它们字面上有内容，语义上却**等于没任务**，正是"无意义空聊"的源头。
  /// 只补真空串是不够的，必须把这类占位值一并视作空。
  static const List<String> placeholders = [
    '',
    '自由交流',
    '无特定任务，自由友善交谈。',
  ];

  /// stored 是否"没有实质任务"（空串 / 纯空白 / 占位空话）。
  static bool isBlank(String? stored) {
    final s = (stored ?? '').trim();
    if (s.isEmpty) return true;
    if (placeholders.contains(s)) return true;
    // "无特定任务…" 这类自述式占位（保留 contains 以覆盖细微标点差异）
    if (s.contains('无特定任务')) return true;
    return false;
  }

  /// 按模式取任务池；未知模式 → [generic]（fail-safe，永不空）。
  static List<String> poolFor(String? mode) {
    final p = pools[mode];
    if (p != null && p.isNotEmpty) return p;
    return generic;
  }

  /// **确定性**取一条任务：同一 (模式, seed) 永远得到同一条。
  ///
  /// [seed] 通常传分身 ID（`my_agent_id`）—— 让"同一分身"的任务稳定，
  /// 不会因为 UI 刷新而抖动。**seed 为空 → 取该模式池首条**（可预测的稳定兜底）。
  static String pick(String? mode, {String? seed}) {
    final pool = poolFor(mode);
    final s = seed ?? '';
    if (s.isEmpty) return pool.first;
    final idx = _hash('${mode ?? ''}|$s') % pool.length;
    return pool[idx];
  }

  /// 计算**有效任务**：主人填了实质任务就用主人的，否则回落内置库（确定性）。
  ///
  /// 这是所有"读 `social_task`"的地方应改用的入口 —— 它保证调用方拿到的
  /// 永远是**一条有目的的任务**，而不是空串 / 占位空话。
  static String effective({
    String? mode,
    String? stored,
    required String agentId,
  }) {
    final s = (stored ?? '').trim();
    if (!isBlank(s)) return s;
    return pick(mode, seed: agentId);
  }

  /// **显式**换一条（给 UI 的"🎲 换一个"）。
  ///
  /// 用真随机，尽量避开 [avoid]（当前这条）—— 池子只有一条时返回它自己。
  /// 与 [pick] 的确定性刻意分开：自动补空要**稳**，用户主动换要**变**。
  static String reroll(String? mode, {String? avoid}) {
    final pool = poolFor(mode);
    if (pool.length == 1) return pool.first;
    final cur = (avoid ?? '').trim();
    final candidates = pool.where((t) => t != cur).toList();
    final src = candidates.isEmpty ? pool : candidates;
    return src[math.Random().nextInt(src.length)];
  }

  /// 已注册模式的全部任务（供校验/展示）。
  static List<String> get allTasks =>
      [for (final p in pools.values) ...p, ...generic];

  /// FNV-1a 32-bit：跨运行稳定的字符串散列（不依赖 `String.hashCode` ——
  /// 后者在 Web/不同 VM 上不保证稳定，会让"确定性"失效）。
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
