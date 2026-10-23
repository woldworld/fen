/// 长期用户画像（P1「双向记忆层」的**读侧**）—— 离线聚合，隐私不出本机。
///
/// ---------------------------------------------------------------------------
/// 它是什么
/// ---------------------------------------------------------------------------
/// 三日回顾（P0）回答的是"最近三天发生了什么"；本模块回答的是
/// "主人是个什么样的人、长期关心什么"。它把 append-only 的 `session_events`
/// 聚合成长周期画像：**常关注主题**（关键词频次 + 时间衰减）+ **常在时段**
/// + **活跃强度**，供主智能体在每轮对话前"回灌"到上下文里。
///
/// ---------------------------------------------------------------------------
/// 为什么**不建表**（R8「派生值不落库」）
/// ---------------------------------------------------------------------------
/// 画像完全是 `session_events` 的**聚合派生值**，而该表 append-only、
/// **无时间裁剪**（只在单个 session 被删时按 session_id 删），历史全量留着
/// ⇒ 任何时候都能重算出同样的结果。若再落一张"画像表"，就等于同一份事实
/// 有第二个可写副本，必然漂移（改了历史却没改画像 / 反之）。派生 + 只读 =
/// 没有漂移的余地。这也让我们**不必动 DB 版本**（无迁移风险）。
///
/// ★ 0.70.0 修订：会话遗忘（`DBHelper.forgetSession`）给该表引入了**软删**
/// （`deleted_at` 列）——这是**主人意志**，画像聚合已排除软删行。"重算出
/// 同样结果"的承诺从此以「尊重删除」为前提：删除前可重算，删除后重算也
/// 必须不再包含，两条都对才是对的。
///
/// ---------------------------------------------------------------------------
/// 为什么**不做向量 / 语义检索**
/// ---------------------------------------------------------------------------
/// 项目已拍板（10-04）：记忆检索只做「关键词 + 时间」，端侧 embedding /
/// sqlite-vec 会**加重手机端负担**，不做。所以这里的"画像"就是
/// **关键词频次 × 时间衰减**的纯结构化统计 —— 没有任何语义相似度计算，
/// 也没有任何模型调用（零成本、可离线）。
///
/// ---------------------------------------------------------------------------
/// 隐私边界
/// ---------------------------------------------------------------------------
/// 只取模型回执里**已落库的元数据**（`topic` / `keywords`）与时间戳，
/// **不读对话正文**（与 P0 三日回顾客同一条纪律）。聚合结果只在本进程内
/// 缓存，不出本机。
library;

import 'dart:convert';
import 'dart:math' as math;

import 'app_logger.dart';
import 'db_helper.dart';

/// 一条长期关注主题。
class ProfileTopic {
  final String name;

  /// 窗口内累计命中次数（原始频次）。
  final int hits;

  /// 时间衰减后的权重：`hits × 0.5^(距今天数 / 半衰期)`。
  /// 越久没出现，权重越低 ⇒ 画像跟着主人的近况走，不会被陈年话题锁死。
  final double weight;

  /// 末次出现时间（ms）。
  final int lastSeenMs;

  const ProfileTopic({
    required this.name,
    this.hits = 0,
    this.weight = 0,
    this.lastSeenMs = 0,
  });
}

/// 一份长期画像快照。
class UserProfile {
  /// 常关注主题（按 [ProfileTopic.weight] 降序）。
  final List<ProfileTopic> topics;

  /// 常在时段（小时 0–23，按活跃度降序）。
  final List<int> topHours;

  /// 窗口内事件总数（活跃强度的粗糙刻度）。
  final int turns;

  /// 聚合窗口（天）。
  final int windowDays;

  const UserProfile({
    this.topics = const [],
    this.topHours = const [],
    this.turns = 0,
    this.windowDays = UserProfileStore.defaultWindowDays,
  });

  bool get isEmpty => topics.isEmpty && topHours.isEmpty;
}

class UserProfileStore {
  UserProfileStore._();
  static final UserProfileStore i = UserProfileStore._();

  /// 聚合窗口：半年。再长也只剩噪声（主人的兴趣会变）。
  static const int defaultWindowDays = 180;

  /// 半衰期：三周。即"三周没碰的话题，权重掉一半"。
  static const int defaultHalfLifeDays = 21;

  /// 画像里最多带几个主题（注入提示词要短，撑爆上下文反而更笨）。
  static const int defaultTopN = 8;

  /// 单次聚合**最多扫多少条事件**（取窗口内最新的这些）。
  ///
  /// 为什么要有上限：聚合是 Dart 侧逐条 `jsonDecode`（`topic`/`keywords` 在 JSON 里），
  /// 成本 O(事件数)。`session_events` 只增不减，长用之后量可能很大 ⇒ 不设上限的话
  /// 首次聚合可能成为一次可感知的卡顿。**取最新 N 条**对"画像"这个用途是正确的
  /// 取舍：它关心的是近况，而不是把三年前的第 3 条也算进来。
  static const int maxScanRows = 20000;

  /// 进程内缓存有效期。画像是**慢变量**，没必要每轮对话重扫一遍全表。
  static const Duration _ttl = Duration(minutes: 30);

  /// 噪声主题：模型回执里"没话题"时的占位，不代表主人真的关注它
  /// （与 P0 `chat_stats_source` 同一份口径，避免两处各写一套）。
  static const Set<String> _stopTopics = {
    '未分类',
    '日常交流',
    '日常',
    '其他',
    '其他交流',
  };

  UserProfile? _cached;
  int _cachedAtMs = 0;

  /// 取画像。默认走缓存；[force] = true 强制重算（每日沉淀用）。
  ///
  /// 任何异常（库未就绪 / JSON 损坏）都返回**空画像** —— 画像是增强，
  /// 不是主流程，绝不能因为它让对话发不出去。
  Future<UserProfile> load({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && _cached != null && now - _cachedAtMs < _ttl.inMilliseconds) {
      return _cached!;
    }
    final p = await _aggregate(windowDays: defaultWindowDays);
    _cached = p;
    _cachedAtMs = now;
    return p;
  }

  /// 强制重算并刷新缓存（= 每日沉淀那一下）。
  Future<UserProfile> refresh() => load(force: true);

  /// 丢弃缓存（切换账号 / 清数据后调用，避免串到别人的画像）。
  void invalidate() {
    _cached = null;
    _cachedAtMs = 0;
  }

  Future<UserProfile> _aggregate({required int windowDays}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final since = now - Duration(days: windowDays).inMilliseconds;
      final db = await DBHelper.db;
      final rows = await db.query(
        'session_events',
        columns: ['ts', 'data'],
        // ★ 0.70.0：排除软删行 —— 主人删掉的记忆不得再进画像（"删了却还在"
        //   = 静默不符预期，R14 同款教训）。
        where: 'ts >= ? AND deleted_at IS NULL',
        whereArgs: [since],
        orderBy: 'ts DESC', // 配 maxScanRows：超量时保留**最新**的一批
        limit: maxScanRows,
      );
      if (rows.isEmpty) {
        return UserProfile(windowDays: windowDays);
      }

      final counts = <String, int>{};
      final lastSeen = <String, int>{};
      final hourCounts = <int, int>{};

      for (final r in rows) {
        final ts = (r['ts'] as int?) ?? 0;
        if (ts > 0) {
          final h = DateTime.fromMillisecondsSinceEpoch(ts).hour;
          hourCounts[h] = (hourCounts[h] ?? 0) + 1;
        }

        final data = _parseData(r['data']);
        final topic = (data['topic'] as String?)?.trim();
        if (topic != null && topic.isNotEmpty && !_stopTopics.contains(topic)) {
          _bump(counts, lastSeen, topic, ts);
        }
        final kw = (data['keywords'] as String?)?.trim();
        if (kw != null && kw.isNotEmpty) {
          for (final k in kw.split(RegExp(r'[，,、\s]+'))) {
            final t = k.trim();
            if (t.isNotEmpty && !_stopTopics.contains(t)) {
              _bump(counts, lastSeen, t, ts);
            }
          }
        }
      }

      // 主题：按衰减权重降序
      final topics = <ProfileTopic>[];
      for (final e in counts.entries) {
        final last = lastSeen[e.key] ?? 0;
        topics.add(ProfileTopic(
          name: e.key,
          hits: e.value,
          weight: _decayedWeight(e.value, last, now),
          lastSeenMs: last,
        ));
      }
      topics.sort((a, b) => b.weight.compareTo(a.weight));
      final topTopics = topics.take(defaultTopN).toList();

      // 时段：按活跃度降序，只取前 3 个
      final hours = hourCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topHours = hours.take(3).map((e) => e.key).toList();

      return UserProfile(
        topics: topTopics,
        topHours: topHours,
        turns: rows.length,
        windowDays: windowDays,
      );
    } catch (e) {
      AppLogger.w('userProfile', e);
      return UserProfile(windowDays: windowDays);
    }
  }

  static void _bump(
      Map<String, int> counts, Map<String, int> lastSeen, String key, int ts) {
    counts[key] = (counts[key] ?? 0) + 1;
    if (ts > (lastSeen[key] ?? 0)) lastSeen[key] = ts;
  }

  /// 时间衰减权重：半衰期 [defaultHalfLifeDays] 天。
  static double _decayedWeight(int hits, int lastSeenMs, int nowMs) {
    if (lastSeenMs <= 0) return hits.toDouble();
    final ageDays = (nowMs - lastSeenMs) / Duration.millisecondsPerDay;
    if (ageDays <= 0) return hits.toDouble();
    // math.pow 返回 num（int 底数 + 整指数会给出 int），显式转 double。
    return (hits * math.pow(0.5, ageDays / defaultHalfLifeDays)).toDouble();
  }

  static Map<String, dynamic> _parseData(Object? raw) {
    if (raw == null) return const {};
    try {
      final decoded = (raw is String) ? jsonDecode(raw) : raw;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return const {};
  }

  /// 组装注入给智能体的"长期画像"块。空画像返回空串（调用方据此不注入）。
  ///
  /// ⚠️ 文案是**硬编码中文**（与既有 `buildRecallBlock` 的回忆块一致）：
  /// 它是喂给模型的系统背景，不是给主人看的界面文案，故不进 ARB。
  ///
  /// ⚠️ 调用方**必须**按不可信输入包裹（`AgentService._wrapUntrusted`），
  /// 且对外分身必须带护栏 —— 画像是主人私事的浓缩，绝不可转述给外人。
  Future<String> buildProfileBlock({int maxChars = 400}) async {
    final p = await load();
    if (p.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('■ 主人的长期画像（系统按近${p.windowDays}天对话元数据自动统计，仅供参考）：');
    if (p.topics.isNotEmpty) {
      final t = p.topics
          .take(5)
          .map((e) => '${e.name}(${e.hits})')
          .join('、');
      buf.writeln('- 常关注的话题：$t');
    }
    if (p.topHours.isNotEmpty) {
      buf.writeln('- 常在时段：${p.topHours.map((h) => '$h点').join('、')}');
    }
    final s = buf.toString().trim();
    return s.length > maxChars ? '${s.substring(0, maxChars)}…' : s;
  }
}
