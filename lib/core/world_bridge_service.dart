/// M5 · 世界房间 = 圈的载体（PRD §4 M5）。
///
/// **定位（PRD 原话）**：房间不是装饰，是**网络效应的唯一供给源** ——
/// 让 N 个圈子互相连接。
///
/// 为什么只有房间能干这件事：圈内是熟人，圈子之间默认**没有边**，
/// 整个社交图天然是一堆孤岛；房间是唯一会把"不同圈的人"放进同一个
/// 可观测空间的地方。所以 M5 的唯一机制是：
/// **把房间里遇到的圈外人，变成一条跨圈边。**
///
/// 四条铁律（本层强制，UI 想违反都难）：
/// 1. **边必须有出处** —— 没在该房间出现过的人，建不出跨圈边（`not_in_room`）。
///    这条挡的是"凭一个 ID 就宣称认识了"的假边。
/// 2. **同圈不重复建边** —— 圈内本来就有边（`same_circle`）。
/// 3. **原本不认识才算** —— 已有连接（互介过 / 委托过 / 聊过）的人走既有关系，
///    不占跨圈边的名额（`already_linked`）。
/// 4. **幂等** —— 同一对人只留一条边，重复调用不改账（`duplicate`）。
///
/// 指标口径（诚实版）：PRD 的指标是**人均跨圈连接数**。全平台人均需要服务端
/// 汇总，而 world-server **刻意不携带用户的圈子关系**（带了就等于向所有人
/// 广播社交图谱，与"圈子是私域"的定位冲突）。因此本机只能给出
/// 「我的跨圈边数 ÷ 我接触过的不同分身数」，**分子分母都如实标注**，
/// 绝不用估算数字凑出一个好看的比值。
///
/// 本文件**零平台依赖**（不 import sqflite / SharedPreferences），
/// `dart run tool/verify_world_bridge.dart` 可直接复算全部判定。

library;

// ---------------------------------------------------------------------------
// 观测数据
// ---------------------------------------------------------------------------

/// 一条「某人在某房间出现过」的观测行。
///
/// 这是本机从房间消息流里累积出来的**事实**（谁说过话），
/// 也是跨圈边唯一的合法出处：没有这行，就没有边。
class RoomPresence {
  final String roomId;
  final String agentId;

  /// 房间内昵称（服务端下发，仅用于显示；不参与任何判定）。
  final String nickname;

  /// 本机累计观测到的发言条数（≥1）。
  final int msgCount;

  /// 最后一次出现的时刻。
  final int lastSeenMs;

  const RoomPresence({
    required this.roomId,
    required this.agentId,
    this.nickname = '',
    this.msgCount = 1,
    required this.lastSeenMs,
  });

  RoomPresence copyWith({String? nickname, int? msgCount, int? lastSeenMs}) =>
      RoomPresence(
        roomId: roomId,
        agentId: agentId,
        nickname: nickname ?? this.nickname,
        msgCount: msgCount ?? this.msgCount,
        lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      );

  Map<String, Object?> toMap() => {
        'room_id': roomId,
        'agent_id': agentId,
        'nickname': nickname,
        'msg_count': msgCount,
        'last_seen': lastSeenMs,
      };

  static RoomPresence fromMap(Map<String, dynamic> m) => RoomPresence(
        roomId: m['room_id'] as String,
        agentId: m['agent_id'] as String,
        nickname: (m['nickname'] as String?) ?? '',
        msgCount: (m['msg_count'] as num?)?.toInt() ?? 1,
        lastSeenMs: (m['last_seen'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// 关系判定
// ---------------------------------------------------------------------------

/// 房间里的人与我的关系（决定他能不能进"朋友池互荐"）。
enum BridgeKind {
  /// 与我在同一个圈 —— 边上已有，不重复推荐。
  sameCircle,

  /// 跨圈，但已经连接过（互介 / 委托 / 聊天）—— 走既有关系。
  alreadyLinked,

  /// ✅ 跨圈且原本不认识 —— M5 要找的正是这种人。
  crossCircle,
}

class BridgeCandidate {
  final String agentId;
  final String nickname;
  final BridgeKind kind;

  /// 在哪些房间遇见过（**可解释性**：UI 要能回答"你为什么推荐他"）。
  final List<String> rooms;

  /// 本机累计观测到的消息条数。
  final int msgCount;

  final int lastSeenMs;

  const BridgeCandidate({
    required this.agentId,
    required this.nickname,
    required this.kind,
    required this.rooms,
    required this.msgCount,
    required this.lastSeenMs,
  });

  /// 共同房间数（≥2 = 在多个场合反复遇见，是亲近度信号）。
  int get sharedRooms => rooms.length;

  /// 可发起跨圈互荐。
  bool get bridgeable => kind == BridgeKind.crossCircle;
}

/// 朋友池：一次采集的完整分类结果。
class BridgePool {
  final String roomId;

  /// 跨圈且原本不认识（可建边，已按"共同房间数 → 消息数 → ID"降序）。
  final List<BridgeCandidate> crossCircle;

  /// 同圈的人。
  final List<BridgeCandidate> sameCircle;

  /// 跨圈但已连接的人。
  final List<BridgeCandidate> linked;

  const BridgePool({
    required this.roomId,
    required this.crossCircle,
    required this.sameCircle,
    required this.linked,
  });

  int get crossCircleCount => crossCircle.length;
  int get total => crossCircle.length + sameCircle.length + linked.length;
  bool get isEmpty => total == 0;
}

// ---------------------------------------------------------------------------
// 房间活跃度三档
// ---------------------------------------------------------------------------

enum RoomVibrancy {
  /// 🔥 热闹
  hot,

  /// 🌤 正常
  warm,

  /// 🌙 冷清
  cold,
}

/// 房间活跃度（判据全部显式，可复算）。
///
/// 两个判据取**较热**的一档：
/// - 发言人数（本机从消息流观测，窗口内独立发言者）
/// - 消息条数（优先用服务端日报的精确值；没有则用本机累计观测值）
///
/// 本机口径下"发言人数"比"消息条数"更可靠（条数受冷启动影响），
/// 因此窗口内人数是主判据，条数是补强。
class RoomActivity {
  final String roomId;
  final RoomVibrancy vibrancy;

  /// 窗口内独立发言者数（本机观测）。
  final int activeSpeakers;

  /// 窗口内发言者的消息条数（服务端有精确值就用它）。
  final int messages;

  /// 本机口径标记：messages 是否来自服务端日报的精确值。
  final bool messagesAreExact;

  /// 其中圈外发言者数（跨圈浓度 —— 这个房间到底有没有在"连圈"）。
  final int crossCircleSpeakers;

  const RoomActivity({
    required this.roomId,
    required this.vibrancy,
    required this.activeSpeakers,
    required this.messages,
    required this.messagesAreExact,
    required this.crossCircleSpeakers,
  });

  // 判据阈值（改这里就是改口径，别散落到 UI）
  static const int hotSpeakers = 5;
  static const int warmSpeakers = 2;
  static const int hotMessages = 20;
  static const int warmMessages = 5;

  static RoomVibrancy grade({required int speakers, required int messages}) {
    final bySpeakers = speakers >= hotSpeakers
        ? RoomVibrancy.hot
        : speakers >= warmSpeakers
            ? RoomVibrancy.warm
            : RoomVibrancy.cold;
    final byMessages = messages >= hotMessages
        ? RoomVibrancy.hot
        : messages >= warmMessages
            ? RoomVibrancy.warm
            : RoomVibrancy.cold;
    return bySpeakers.index <= byMessages.index ? bySpeakers : byMessages;
  }
}

// ---------------------------------------------------------------------------
// 跨圈边（append-only 账本）
// ---------------------------------------------------------------------------

/// 一条跨圈边：因某个房间，我认识了一个圈外人。
///
/// `id` 恒为 `$selfId->$peerId` —— 天然幂等，同一对人不可能落两条。
class BridgeLink {
  final String selfId;
  final String peerId;

  /// **因哪个房间**而连上（M5 验收要的正是这个：边的出处是房间，不是通讯录）。
  final String roomId;

  /// 我这边所在的圈（互介卡的 circleId 用它，不再是硬编码的 'direct'）。
  final String myCircleId;

  /// 建边时刻。
  final int atMs;

  const BridgeLink({
    required this.selfId,
    required this.peerId,
    required this.roomId,
    required this.myCircleId,
    required this.atMs,
  });

  String get id => '$selfId->$peerId';

  Map<String, Object?> toMap() => {
        'id': id,
        'self_id': selfId,
        'peer_id': peerId,
        'room_id': roomId,
        'my_circle_id': myCircleId,
        'at_ms': atMs,
      };

  static BridgeLink fromMap(Map<String, dynamic> m) => BridgeLink(
        selfId: m['self_id'] as String,
        peerId: m['peer_id'] as String,
        roomId: (m['room_id'] as String?) ?? '',
        myCircleId: (m['my_circle_id'] as String?) ?? '',
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
      );
}

/// 建边被拒的原因码（UI 侧翻译成文案）。
abstract final class BridgeBlockCode {
  /// 不能和自己建边。
  static const String self = 'self';

  /// 这个人没在该房间出现过（铁律 1）。
  static const String notInRoom = 'not_in_room';

  /// 同圈（铁律 2）。
  static const String sameCircle = 'same_circle';

  /// 已经连接过（铁律 3）。
  static const String alreadyLinked = 'already_linked';

  /// 已经有这条边（铁律 4，幂等）。
  static const String duplicate = 'duplicate';

  /// 缺少必填的房间出处。
  static const String noRoom = 'no_room';
}

class BridgeLinkResult {
  final BridgeLink? link;
  final bool blocked;
  final String? reason; // BridgeBlockCode.*
  final bool created; // true = 本次真的新落了一条边

  const BridgeLinkResult({
    this.link,
    this.blocked = false,
    this.reason,
    this.created = false,
  });

  bool get ok => !blocked && link != null;
}

// ---------------------------------------------------------------------------
// 指标
// ---------------------------------------------------------------------------

/// 人均跨圈连接数（**本机口径**）。
///
/// `crossCircleLinks / knownAgents`：分子是我建过的跨圈边数，
/// 分母是我接触过的不同分身数（圈内 + 跨圈）。全平台人均需服务端汇总，
/// 详见文件头说明。
class BridgeMetric {
  final int crossCircleLinks;
  final int sameCircleAgents;
  final int crossCircleContacts;

  const BridgeMetric({
    required this.crossCircleLinks,
    required this.sameCircleAgents,
    required this.crossCircleContacts,
  });

  /// 我接触过的不同分身数。
  int get knownAgents => sameCircleAgents + crossCircleContacts;

  double get perCapita => knownAgents == 0 ? 0 : crossCircleLinks / knownAgents;

  /// 两位小数（展示用，避免浮点尾巴）。
  double get perCapita2 =>
      (perCapita * 100).roundToDouble() / 100;
}

// ---------------------------------------------------------------------------
// 采集输入
// ---------------------------------------------------------------------------

/// 一次判定的完整输入（纯数据，便于离线复算与验证）。
class WorldBridgeInput {
  final String selfId;

  /// 本机观测到的全部房间出现记录。
  final List<RoomPresence> presences;

  /// 我所有圈的成员（去重、**不含自己**）。
  final Set<String> circleMembers;

  /// 已连接过的人（互介 / 委托 / 聊天 + 已建的跨圈边）。
  final Set<String> linkedPeers;

  /// 已落账的跨圈边。
  final List<BridgeLink> links;

  final int nowMs;

  const WorldBridgeInput({
    required this.selfId,
    this.presences = const [],
    this.circleMembers = const {},
    this.linkedPeers = const {},
    this.links = const [],
    required this.nowMs,
  });
}

// ---------------------------------------------------------------------------
// 存储抽象（生产实现见 world_bridge_store_db.dart）
// ---------------------------------------------------------------------------

abstract class BridgeLinkStore {
  /// 幂等写入（PK = `self->peer`）。
  Future<void> insert(BridgeLink l);

  Future<List<BridgeLink>> linksOf(String selfId);

  Future<BridgeLink?> find(String selfId, String peerId);
}

abstract class RoomPresenceStore {
  /// 观测到一条发言：同 (room, agent) 累加计数并刷新时间。
  Future<void> observe({
    required String roomId,
    required String agentId,
    required String nickname,
    required int atMs,
  });

  /// 全部观测（**不含自己**；selfId 由调用方给出）。
  Future<List<RoomPresence>> presences(String selfId);

  /// 某个房间的观测（不含自己）。
  Future<List<RoomPresence>> inRoom(String roomId, String selfId);
}

class MemoryBridgeLinkStore implements BridgeLinkStore {
  final Map<String, BridgeLink> _rows = {};

  @override
  Future<void> insert(BridgeLink l) async => _rows[l.id] = l;

  @override
  Future<List<BridgeLink>> linksOf(String selfId) async =>
      _rows.values.where((l) => l.selfId == selfId).toList()
        ..sort((a, b) => b.atMs.compareTo(a.atMs));

  @override
  Future<BridgeLink?> find(String selfId, String peerId) async =>
      _rows['$selfId->$peerId'];
}

class MemoryRoomPresenceStore implements RoomPresenceStore {
  final Map<String, RoomPresence> _rows = {};

  String _key(String roomId, String agentId) => '$roomId::$agentId';

  @override
  Future<void> observe({
    required String roomId,
    required String agentId,
    required String nickname,
    required int atMs,
  }) async {
    final k = _key(roomId, agentId);
    final prev = _rows[k];
    _rows[k] = prev == null
        ? RoomPresence(
            roomId: roomId,
            agentId: agentId,
            nickname: nickname,
            msgCount: 1,
            lastSeenMs: atMs,
          )
        : prev.copyWith(
            nickname: nickname.isEmpty ? prev.nickname : nickname,
            msgCount: prev.msgCount + 1,
            lastSeenMs: atMs,
          );
  }

  @override
  Future<List<RoomPresence>> presences(String selfId) async =>
      _rows.values.where((p) => p.agentId != selfId).toList();

  @override
  Future<List<RoomPresence>> inRoom(String roomId, String selfId) async =>
      _rows.values
          .where((p) => p.roomId == roomId && p.agentId != selfId)
          .toList();
}

// ---------------------------------------------------------------------------
// 服务
// ---------------------------------------------------------------------------

class WorldBridgeService {
  final BridgeLinkStore store;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  WorldBridgeService({required this.store, this.onEvent});

  /// 采集：把房间里的人分成 圈内 / 跨圈新人 / 已连接。
  ///
  /// 纯函数（输入 [input] 自带 nowMs 与全部事实），便于离线复算。
  ///
  /// 注意口径细节：**候选范围**限定在本房间（[roomId] 里说过话的人），
  /// 但每个候选人的 **`rooms` 跨全部房间统计** —— 共同房间数 ≥2 表示
  /// "在别的场合也遇见过"，是亲近度信号，也是"凭什么推荐他"的解释依据。
  BridgePool pool(WorldBridgeInput input, {required String roomId}) {
    // 本房间出现过的人
    final inRoom = <String>{};
    for (final p in input.presences) {
      if (p.roomId != roomId) continue;
      if (p.agentId == input.selfId) continue;
      inRoom.add(p.agentId);
    }

    // 全部房间的观测（供出处统计）
    final byAgent = <String, List<RoomPresence>>{};
    for (final p in input.presences) {
      if (p.agentId == input.selfId) continue;
      byAgent.putIfAbsent(p.agentId, () => []).add(p);
    }

    final cross = <BridgeCandidate>[];
    final same = <BridgeCandidate>[];
    final linked = <BridgeCandidate>[];

    for (final agentId in inRoom) {
      final rows = byAgent[agentId]!;
      final rooms = rows.map((r) => r.roomId).toSet().toList()..sort();
      final msg = rows.fold<int>(0, (a, r) => a + r.msgCount);
      final lastSeen =
          rows.map((r) => r.lastSeenMs).reduce((a, b) => a > b ? a : b);
      final nickname = rows
          .map((r) => r.nickname)
          .firstWhere((n) => n.isNotEmpty, orElse: () => '');

      final kind = input.circleMembers.contains(agentId)
          ? BridgeKind.sameCircle
          : input.linkedPeers.contains(agentId)
              ? BridgeKind.alreadyLinked
              : BridgeKind.crossCircle;

      final c = BridgeCandidate(
        agentId: agentId,
        nickname: nickname,
        kind: kind,
        rooms: rooms,
        msgCount: msg,
        lastSeenMs: lastSeen,
      );
      switch (kind) {
        case BridgeKind.crossCircle:
          cross.add(c);
        case BridgeKind.sameCircle:
          same.add(c);
        case BridgeKind.alreadyLinked:
          linked.add(c);
      }
    }

    // 排序：共同房间多 → 消息多 → ID 稳定序（可复算）
    int byRank(BridgeCandidate a, BridgeCandidate b) {
      final r = b.sharedRooms.compareTo(a.sharedRooms);
      if (r != 0) return r;
      final m = b.msgCount.compareTo(a.msgCount);
      if (m != 0) return m;
      return a.agentId.compareTo(b.agentId);
    }

    cross.sort(byRank);
    same.sort(byRank);
    linked.sort(byRank);

    return BridgePool(
      roomId: roomId,
      crossCircle: cross,
      sameCircle: same,
      linked: linked,
    );
  }

  /// 房间活跃度三档。[serverMessages] 有则用服务端日报的精确条数。
  RoomActivity activity(
    WorldBridgeInput input, {
    required String roomId,
    Duration window = const Duration(hours: 24),
    int? serverMessages,
  }) {
    final from = input.nowMs - window.inMilliseconds;
    final rows = input.presences
        .where((p) => p.roomId == roomId && p.agentId != input.selfId)
        .where((p) => p.lastSeenMs >= from)
        .toList();

    final speakers = rows.map((p) => p.agentId).toSet();
    final observed = rows.fold<int>(0, (a, r) => a + r.msgCount);
    final messages = serverMessages ?? observed;
    final crossCircle =
        speakers.where((id) => !input.circleMembers.contains(id)).length;

    return RoomActivity(
      roomId: roomId,
      vibrancy:
          RoomActivity.grade(speakers: speakers.length, messages: messages),
      activeSpeakers: speakers.length,
      messages: messages,
      messagesAreExact: serverMessages != null,
      crossCircleSpeakers: crossCircle,
    );
  }

  /// 建一条跨圈边（**fail-closed**：四条铁律全过才落账）。
  Future<BridgeLinkResult> link({
    required WorldBridgeInput input,
    required String roomId,
    required String peerId,
    required String myCircleId,
  }) async {
    Future<BridgeLinkResult> block(String code) async {
      onEvent?.call('bridge_link_blocked', {
        'self': input.selfId,
        'peer': peerId,
        'room_id': roomId,
        'reason': code,
      });
      return BridgeLinkResult(blocked: true, reason: code);
    }

    if (roomId.trim().isEmpty) return block(BridgeBlockCode.noRoom);
    if (peerId == input.selfId) return block(BridgeBlockCode.self);

    // 铁律 1：必须在该房间出现过（有观测事实才算数）
    final seen = input.presences.any(
        (p) => p.roomId == roomId && p.agentId == peerId && p.msgCount >= 1);
    if (!seen) return block(BridgeBlockCode.notInRoom);

    // 铁律 2 / 3
    if (input.circleMembers.contains(peerId)) {
      return block(BridgeBlockCode.sameCircle);
    }
    if (input.linkedPeers.contains(peerId)) {
      return block(BridgeBlockCode.alreadyLinked);
    }

    // 铁律 4：幂等
    final existing = await store.find(input.selfId, peerId);
    if (existing != null) {
      return BridgeLinkResult(link: existing, reason: BridgeBlockCode.duplicate);
    }

    final l = BridgeLink(
      selfId: input.selfId,
      peerId: peerId,
      roomId: roomId,
      myCircleId: myCircleId,
      atMs: input.nowMs,
    );
    await store.insert(l);
    onEvent?.call('bridge_link_created', {
      'self': input.selfId,
      'peer': peerId,
      'room_id': roomId,
      'circle_id': myCircleId,
    });
    return BridgeLinkResult(link: l, created: true);
  }

  /// 人均跨圈连接数（本机口径）。
  BridgeMetric metric(WorldBridgeInput input) {
    final crossIds = <String>{};
    for (final p in input.presences) {
      if (p.agentId == input.selfId) continue;
      if (!input.circleMembers.contains(p.agentId)) crossIds.add(p.agentId);
    }
    final linkedIds =
        input.links.where((l) => l.selfId == input.selfId).map((l) => l.peerId).toSet();
    return BridgeMetric(
      crossCircleLinks: linkedIds.length,
      sameCircleAgents:
          input.presences.map((p) => p.agentId).toSet().intersection(input.circleMembers).length,
      crossCircleContacts: crossIds.length,
    );
  }

  /// M5 验收（二值）：**两个原本不认识的圈子，因同一房间产生 ≥1 次互介**。
  ///
  /// 本机侧的可证形式 = 存在一条边，同时满足：
  /// ① 边有房间出处（`roomId` 非空）—— 边是**因房间**产生的，不是通讯录里翻出来的；
  /// ② 对端不在我任一成员圈内 —— 因此必然来自**另一个圈**（否则它会出现在成员表里）；
  /// ③ 我的圈 ID 非空 —— 这条边挂在"我的圈"这个端点上。
  ///
  /// ③"原本不认识"（建边前无既有连接）在 [link] 时代已强制且留痕，
  /// 这里**不再重复要求**（边一旦建立，对端自然进入"已连接"集合，
  /// 再拿它判"不认识"会自我否定）。验收证据里给出 `room_backed_cross_circle`
  /// 这条理由，配合 telemetry 的 `bridge_link_created` 可完整回溯。
  BridgeAcceptance acceptance(WorldBridgeInput input) {
    final members = input.circleMembers;
    for (final l in input.links) {
      if (l.selfId != input.selfId) continue;
      final ok = l.roomId.trim().isNotEmpty &&
          !members.contains(l.peerId) &&
          l.myCircleId.trim().isNotEmpty;
      if (ok) {
        return BridgeAcceptance(
          met: true,
          evidence: l,
          reason: 'room_backed_cross_circle',
        );
      }
    }
    return const BridgeAcceptance(met: false, reason: 'no_room_backed_link');
  }
}

/// 验收结果（带证据：能当场回答"哪条边、因哪个房间"）。
class BridgeAcceptance {
  final bool met;
  final BridgeLink? evidence;
  final String reason;

  const BridgeAcceptance({required this.met, this.evidence, required this.reason});
}
