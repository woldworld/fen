/// 主人画像卡 —— 「主人是个什么样的人」的**可写事实层**。
///
/// ---------------------------------------------------------------------------
/// 与 `UserProfileStore`（长期画像）是什么关系 —— 两层，不是一个东西
/// ---------------------------------------------------------------------------
/// 本仓此前已有一份"画像"：`UserProfileStore`，它是 `session_events` 的
/// **派生聚合**（常关注话题 + 常在时段），**只读、不落库**（R8「派生值不落库」）。
/// 它回答的是"主人**行为上**在关注什么"。
///
/// 本文件回答的是**另一个问题**："主人**自述**是什么样的人" —— 职业、偏好、
/// 目标、习惯、约束。这一类信息**不是任何历史数据的函数**：主人说"我是结构工程师"
/// 之后，你没法从 `session_events` 里重算出来。所以它**必须落库**，也因此
/// **不受** R8 的约束（R8 禁的是"同一份事实留两个可写副本"，而这里只有一份）。
///
/// ⇒ 两层共存，但**注入只有一个入口**（`AgentService._augmentWithRecall`），
///   界面上也只有**一个**画像页签（见 `ui/profile_cards_screen.dart`）。
///   R21「同一件事禁止两个入口」是这条设计唯一的硬约束。
///
/// ---------------------------------------------------------------------------
/// 冲突规则（一张表说清，实现见 [upsert]）
/// ---------------------------------------------------------------------------
/// **不变式：一个 `slot` 同时只有一张 `active` 卡。**
/// 于是"矛盾"这件事不需要模糊判断 —— 同 slot 出现不同陈述，就是矛盾。
///
/// | 情形 | 处置 |
/// |---|---|
/// | 同 slot 无卡 | 插入新卡（`inserted`） |
/// | 同 slot 已有卡，陈述**规范化后相同** | **只**提升置信度与更新时间，不改陈述（`reinforced`） |
/// | 同 slot 已有卡，陈述不同，旧卡是**主人手写** | **不覆盖**，新卡落 `pending` 等主人裁决（`pendingOwnerConflict`） |
/// | 同 slot 已有卡，陈述不同，旧卡来自对话/沉淀 | 旧卡置 `superseded` 并**留痕**，新卡 `active`（`superseded`） |
///
/// 为什么"主人手写"要特权：主人亲口说的优先级高于系统从对话里猜的。
/// 让机器覆盖主人的自述，正是"画像越用越不像我"的来源。
///
/// 为什么 supersede 而不是原地改：旧值要**能回看**（"更新时间与来源依据"是需求
/// 原文）。原地改会让画像变成"只有现在、没有来路"，主人无法判断它凭什么这么说。
library;

import 'profile_card_extractor.dart';
import 'profile_taxonomy.dart';

import 'package:sqflite/sqflite.dart';

import 'app_logger.dart';
import 'db_helper.dart';

/// 一张画像卡。
class ProfileCard {
  const ProfileCard({
    required this.id,
    required this.category,
    required this.slot,
    required this.statement,
    required this.confidence,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.evidence,
    this.supersedesId,
    this.supersededBy,
  });

  /// 稳定 id（由 slot + 首次出现时间派生，**不用随机数** ⇒ 重放同一段对话幂等）。
  final String id;

  final String category;

  /// 槽位：冲突判定的键。规范化后**唯一标识一件事**。
  final String slot;

  /// 客观简洁的陈述（给主人看的、也是注入给模型的那一句）。
  final String statement;

  /// 0..1。
  final double confidence;

  final String status;
  final String source;

  /// 来源依据：可读的一句话或对话片段（**已过脱敏**，由调用方负责）。
  final String? evidence;

  final int createdAt;
  final int updatedAt;

  /// 被本卡取代的旧卡 id（可回溯"它是怎么变成现在这样的"）。
  final String? supersedesId;

  /// 取代本卡的卡 id（本卡 status==superseded 时非空）。
  final String? supersededBy;

  bool get isActive => status == ProfileStatus.active;
  bool get isPending => status == ProfileStatus.pending;

  Map<String, Object?> toRow() => {
        'id': id,
        'category': category,
        'slot': slot,
        'statement': statement,
        'confidence': confidence,
        'status': status,
        'source': source,
        'evidence': evidence,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'supersedes_id': supersedesId,
        'superseded_by': supersededBy,
      };

  static ProfileCard fromRow(Map<String, Object?> r) => ProfileCard(
        id: (r['id'] as String?) ?? '',
        category: ProfileCategory.of((r['category'] as String?) ?? ''),
        slot: (r['slot'] as String?) ?? '',
        statement: (r['statement'] as String?) ?? '',
        confidence: ((r['confidence'] as num?) ?? 0).toDouble(),
        status: (r['status'] as String?) ?? ProfileStatus.active,
        source: (r['source'] as String?) ?? '',
        evidence: r['evidence'] as String?,
        createdAt: ((r['created_at'] as num?) ?? 0).toInt(),
        updatedAt: ((r['updated_at'] as num?) ?? 0).toInt(),
        supersedesId: r['supersedes_id'] as String?,
        supersededBy: r['superseded_by'] as String?,
      );
}

class ProfileMergeResult {
  const ProfileMergeResult(this.outcome, {this.cardId, this.replacedId});
  final ProfileMergeOutcome outcome;
  final String? cardId;
  final String? replacedId;

  String get name => outcome.name;
}

/// 画像卡的读写入口（**唯一写入方**）。
class ProfileCardStore {
  ProfileCardStore._();
  static final ProfileCardStore i = ProfileCardStore._();


  /// 单次注入最多带几张卡（提示词要短）。
  static const int injectTopN = 10;

  /// 卡片变更计数，供 `DBHelper.dataRevision` 之外需要感知变化的调用方使用。
  static int revision = 0;

  // ── 读 ──────────────────────────────────────────────────────────────

  /// 取生效中的卡（按置信度降序、更新时间降序）。任何异常返回空表 ——
  /// 画像是增强，绝不能因为它让对话发不出去。
  Future<List<ProfileCard>> listActive({String? category}) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'owner_profile_cards',
        where: category == null ? 'status = ?' : 'status = ? AND category = ?',
        whereArgs: category == null
            ? [ProfileStatus.active]
            : [ProfileStatus.active, category],
        orderBy: 'confidence DESC, updated_at DESC',
      );
      return rows.map(ProfileCard.fromRow).toList();
    } catch (e) {
      AppLogger.w('profileCard.listActive', e);
      return const [];
    }
  }

  /// 取待裁决的卡（与主人自述冲突的那些）。
  Future<List<ProfileCard>> listPending() async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'owner_profile_cards',
        where: 'status = ?',
        whereArgs: [ProfileStatus.pending],
        orderBy: 'updated_at DESC',
      );
      return rows.map(ProfileCard.fromRow).toList();
    } catch (e) {
      AppLogger.w('profileCard.listPending', e);
      return const [];
    }
  }

  /// 取某个 slot 的**全部**历史（含已取代），供"回看旧值"。
  Future<List<ProfileCard>> historyOfSlot(String slot) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'owner_profile_cards',
        where: 'slot = ?',
        whereArgs: [slot],
        orderBy: 'updated_at DESC',
      );
      return rows.map(ProfileCard.fromRow).toList();
    } catch (e) {
      AppLogger.w('profileCard.history', e);
      return const [];
    }
  }

  // ── 写 ──────────────────────────────────────────────────────────────

  /// 写入/合并一张卡。规则的唯一实现，见文件头那张表。
  ///
  /// [statement] 必须**已经是客观简洁的一句**（抽取器负责这一层）。
  Future<ProfileMergeResult> upsert({
    required String slot,
    required String statement,
    required String source,
    String? category,
    String? evidence,
    double? confidence,
    int? nowMs,
  }) async {
    final s = slot.trim();
    final st = statement.trim();
    if (s.isEmpty || st.isEmpty) {
      return const ProfileMergeResult(ProfileMergeOutcome.rejected);
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final owner = ProfileSource.isOwner(source);
    final conf = confidence ??
        (owner ? ProfileConfidence.owner : ProfileConfidence.firstSeen);

    try {
      final db = await DBHelper.db;
      final existing = await db.query(
        'owner_profile_cards',
        where: 'slot = ? AND status != ?',
        whereArgs: [s, ProfileStatus.superseded],
        orderBy: 'updated_at DESC',
        limit: 1,
      );

      // ① 全新 slot
      if (existing.isEmpty) {
        final card = ProfileCard(
          id: _cardId(s, now),
          category: ProfileCategory.of(category ?? ''),
          slot: s,
          statement: st,
          confidence: conf,
          status: ProfileStatus.active,
          source: source,
          evidence: evidence,
          createdAt: now,
          updatedAt: now,
        );
        await db.insert('owner_profile_cards', card.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        revision++;
        await _touchRevision();
        return ProfileMergeResult(ProfileMergeOutcome.inserted, cardId: card.id);
      }

      final old = ProfileCard.fromRow(existing.first);

      // ② 同陈述 ⇒ 重复观察：只提置信度与时间（**不动陈述**，避免措辞漂移）
      if (_sameStatement(old.statement, st)) {
        final raised =
            (old.confidence + ProfileConfidence.step).clamp(0.0, ProfileConfidence.cap);
        await db.update(
          'owner_profile_cards',
          {
            'confidence': owner ? ProfileConfidence.owner : raised,
            'updated_at': now,
            // 来源补记：一条事实被多个来源印证时，把新来源附在后面（可追溯）
            if (evidence != null && (old.evidence ?? '') != evidence)
              'evidence': [old.evidence, evidence]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(' / '),
          },
          where: 'id = ?',
          whereArgs: [old.id],
        );
        revision++;
        await _touchRevision();
        return ProfileMergeResult(ProfileMergeOutcome.reinforced, cardId: old.id);
      }

      // ③ 与**主人自述**冲突 ⇒ 不覆盖，落 pending 等裁决（机器不夺主人的笔）
      if (ProfileSource.isOwner(old.source) && !owner) {
        final pending = ProfileCard(
          id: _cardId('$s|pending|$now', now),
          category: ProfileCategory.of(category ?? old.category),
          slot: s,
          statement: st,
          confidence: conf,
          status: ProfileStatus.pending,
          source: source,
          evidence: evidence,
          createdAt: now,
          updatedAt: now,
          supersedesId: old.id,
        );
        await db.insert('owner_profile_cards', pending.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        revision++;
        await _touchRevision();
        return ProfileMergeResult(ProfileMergeOutcome.pendingOwnerConflict,
            cardId: pending.id, replacedId: old.id);
      }

      // ④ 同 slot 不同陈述 ⇒ 取代。旧卡**留痕**（superseded），不删。
      final newCard = ProfileCard(
        id: _cardId('$s|$now', now),
        category: ProfileCategory.of(category ?? old.category),
        slot: s,
        statement: st,
        confidence: conf,
        status: ProfileStatus.active,
        source: source,
        evidence: evidence,
        createdAt: now,
        updatedAt: now,
        supersedesId: old.id,
      );
      await db.transaction((txn) async {
        await txn.update(
          'owner_profile_cards',
          {'status': ProfileStatus.superseded, 'superseded_by': newCard.id},
          where: 'id = ?',
          whereArgs: [old.id],
        );
        await txn.insert('owner_profile_cards', newCard.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
      revision++;
      await _touchRevision();
      return ProfileMergeResult(ProfileMergeOutcome.superseded,
          cardId: newCard.id, replacedId: old.id);
    } catch (e) {
      AppLogger.w('profileCard.upsert', e);
      return const ProfileMergeResult(ProfileMergeOutcome.rejected);
    }
  }

  /// **一轮对话的观察入口**：从主人的原话里抽取候选并合并入库。
  ///
  /// 设计要点（对应需求「在后续多轮对话中持续观察并整理」）：
  /// · 只吃**主人的话**，不吃 AI 回复 —— 否则"你是一个很有条理的人"会被
  ///   当成主人的自述记下来。
  /// · **非阻塞、不抛**：画像是增强，任何失败都不许影响对话本身。
  /// · 抽取器与库分离（`ProfileCardExtractor.extract` 是纯函数）⇒ 规则能单测，
  ///   而"合并/冲突"这一层只在这里实现一次。
  ///
  /// 返回本轮实际写库的条数（0 表示没有新信息，属正常）。
  Future<int> observeTurn(String ownerText) async {
    final cands = ProfileCardExtractor.extract(ownerText);
    if (cands.isEmpty) return 0;
    var written = 0;
    for (final c in cands) {
      final r = await upsert(
        slot: c.slot,
        statement: c.statement,
        source: '${ProfileSource.agentPrefix}turn',
        category: c.category,
        evidence: c.evidence,
        confidence: c.confidence,
      );
      if (r.outcome != ProfileMergeOutcome.rejected) written++;
    }
    return written;
  }

  /// 主人手写的写入通道（界面用）。**唯一入口**：别处不要再拼 source=owner。
  Future<ProfileMergeResult> upsertByOwner({
    required String slot,
    required String statement,
    String? category,
    String? evidence,
  }) =>
      upsert(
        slot: slot,
        statement: statement,
        source: ProfileSource.owner,
        category: category,
        evidence: evidence ?? '主人在「画像卡」页手动填写',
      );

  /// 主人修改某张卡的陈述（原地改，但**保留**来源与创建时间）。
  Future<void> editStatement(String id, String statement) async {
    try {
      final db = await DBHelper.db;
      await db.update(
        'owner_profile_cards',
        {
          'statement': statement.trim(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          // 主人改过 ⇒ 它就是主人的话，置信度拉满（否则下次抽取还会来抢）
          'source': ProfileSource.owner,
          'confidence': ProfileConfidence.owner,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      revision++;
      await _touchRevision();
    } catch (e) {
      AppLogger.w('profileCard.edit', e);
    }
  }

  /// 采纳一张 pending 卡（主人裁决"这条对"）：它取代原卡生效。
  Future<void> acceptPending(String id) async {
    try {
      final db = await DBHelper.db;
      final rows =
          await db.query('owner_profile_cards', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final card = ProfileCard.fromRow(rows.first);
      final oldId = card.supersedesId;
      await db.transaction((txn) async {
        if (oldId != null) {
          await txn.update(
            'owner_profile_cards',
            {'status': ProfileStatus.superseded, 'superseded_by': id},
            where: 'id = ?',
            whereArgs: [oldId],
          );
        }
        await txn.update(
          'owner_profile_cards',
          {
            'status': ProfileStatus.active,
            'source': ProfileSource.owner,
            'confidence': ProfileConfidence.owner,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      revision++;
      await _touchRevision();
    } catch (e) {
      AppLogger.w('profileCard.accept', e);
    }
  }

  /// 否决一张 pending 卡（主人裁决"这条不对"）：直接删掉，不留噪声。
  Future<void> rejectPending(String id) async {
    try {
      final db = await DBHelper.db;
      await db.delete('owner_profile_cards', where: 'id = ?', whereArgs: [id]);
      revision++;
      await _touchRevision();
    } catch (e) {
      AppLogger.w('profileCard.reject', e);
    }
  }

  /// 主人删除一张卡。
  ///
  /// ⚠️ 删除是**主人意志**：这里做真删（而不是软删）——
  /// 画像是"主人的自述"，他删了就不该还留在库里被下一次注入捞出来。
  /// （与 `session_events` 的软删不同：那张表还承担审计与可重算职责。）
  Future<void> deleteCard(String id) async {
    try {
      final db = await DBHelper.db;
      await db.delete('owner_profile_cards', where: 'id = ?', whereArgs: [id]);
      revision++;
      await _touchRevision();
    } catch (e) {
      AppLogger.w('profileCard.delete', e);
    }
  }

  /// 清空（切换账号 / 清数据后调用）。
  Future<void> clear() async {
    try {
      final db = await DBHelper.db;
      await db.delete('owner_profile_cards');
      revision++;
      await _touchRevision();
    } catch (e) {
      AppLogger.w('profileCard.clear', e);
    }
  }

  // ── 注入 ────────────────────────────────────────────────────────────

  /// 组装注入给模型的"主人自述画像"块。空则返回空串（调用方据此不注入）。
  ///
  /// ⚠️ 文案是**硬编码中文**（与 `UserProfileStore.buildProfileBlock` 一致）：
  /// 它是喂给模型的系统背景，不是给主人看的界面文案，故不进 ARB。
  /// ⚠️ 调用方**必须**按不可信输入包裹，并对对外分身带护栏 —— 这是主人私事的浓缩。
  Future<String> buildCardsBlock({int maxChars = 600}) async {
    final cards = await listActive();
    if (cards.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('■ 主人的自述画像（由主人填写或系统从对话中整理，客观事实，仅供参考）：');
    for (final c in cards.take(injectTopN)) {
      buf.writeln('- [${_categoryZh(c.category)}] ${c.statement}');
    }
    final s = buf.toString().trim();
    return s.length > maxChars ? '${s.substring(0, maxChars)}…' : s;
  }

  static String _categoryZh(String c) => switch (c) {
        ProfileCategory.identity => '身份',
        ProfileCategory.career => '职业',
        ProfileCategory.preference => '偏好',
        ProfileCategory.goal => '目标',
        ProfileCategory.habit => '习惯',
        ProfileCategory.constraint => '约束',
        _ => '背景',
      };

  // ── 内部 ────────────────────────────────────────────────────────────

  /// 稳定 id：由 slot + 时间派生。同一段对话重放两次得到同一个 id ⇒ 幂等
  /// （用随机数会让"重复观察"变成"两张卡"，正好破坏 [ProfileMergeOutcome.reinforced]）。
  static String _cardId(String key, int nowMs) {
    var h = 0x811c9dc5;
    for (final code in key.codeUnits) {
      h ^= code;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return 'pc_${h.toRadixString(36)}_${nowMs.toRadixString(36)}';
  }

  /// 陈述是否"同一件事"。规范化：去空白、去标点、可比。
  ///
  /// ⚠️ 这是**字面**比较，不是语义比较 —— 项目已拍板不做端侧语义/向量检索
  /// （见 `user_profile_store.dart` 的同类说明）。所以措辞不同但意思相同的两条
  /// 会被判为"取代"而不是"重复"。这是可接受的取舍：结果仍然正确（新值生效），
  /// 代价只是旧措辞进了历史而不是被合并。守卫有一条断言钉住"这里没有语义计算"。
  static bool _sameStatement(String a, String b) => _norm(a) == _norm(b);

  /// 标点/空白类。**引号单独处理**：raw 串里 `\'` 是"反斜杠+引号"，
  /// 放进字符类就是非法正则（analyzer 的 `valid_regexps` 会当场报出来）。
  static final RegExp _punct =
      RegExp(r'[\s，,。.；;：:！!？?、（）()【】\[\]「」『』]');

  static String _norm(String s) => s
      .replaceAll(_punct, '')
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .toLowerCase();

  /// 让 `AgentService` 的 Prompt 缓存失效（档案类数据变了，系统提示词要重建）。
  Future<void> _touchRevision() async {
    DBHelper.dataRevision++;
  }
}
