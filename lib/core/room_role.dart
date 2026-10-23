/// M10 · 房间角色 Room Roles（PRD §4 M10，P1）。
///
/// **定位（PRD 原话）**：主持活动（主持人、NPC、嘉宾），
/// **✅ 同一身份，角色属于房间**，Host 层权益，架构成本小（房间内的临时属性）。
///
/// 为什么这样更好（PRD 原话）：**房间角色让"多角色"成为活动内属性，
/// 而非账号带来的权力（防刷）**。
///
/// ---------------------------------------------------------------------------
/// 两条铁律（本层强制，且可离线复算）
/// ---------------------------------------------------------------------------
/// 1. **角色永远属于房间，不存在"全局角色"**。
///    —— `grant` 缺房间出处直接拒（`no_room`）；[RoomRoleService.globalRole]
///    恒返回 [RoomRoleKind.participant]，即"离开房间我什么都不是"。
///    防的就是"我在 A 房间当主持人 → 到 B 房间也自带权力"这种账号级特权。
/// 2. **授予角色是 Host 层权益，且 fail-closed**。
///    —— 只有本房间的主持层（host / cohost）能授予或撤销；默认**没有人**是主持人
///    （新房间所有成员都是 participant），第一个认领者成为主持人
///    （[RoomRoleService.claimHost]），房间已有主持人时认领被拒（`host_exists`），
///    防止"二次占位夺权"。授予者自己不是主持层 → `not_host`。
///
/// ---------------------------------------------------------------------------
/// 诚实边界（必读）—— **v1.15 起这条边界已被补上**
/// ---------------------------------------------------------------------------
/// 此前（v1.7）角色是**本机模型 + 本机 UI 生效**：服务端没参与，所以"对面是不是
/// 真的主持人"**无法被第三方验证**。v1.15 把这一半补齐了 ——
/// [RoomRoleGrant] 现在可以**由授予人签名**，[RoomRoleAuthority.verify] 让任何人
/// 只凭记录本体即可独立验签，Hub 侧的 `/api/rooms/*` 只保管字节、自己也复算一遍，
/// 并把叶子并进 §16 那棵**同一棵**透明日志（改动可被包含证明抓住）。
///
/// 仍然**没做**的（诚实写在这里，不假装）：断点续传、按房间计费、
/// "服务端强制踢人"这三件事要 Hub 参与调度，属 **M10 P2**。本模块只保证
/// **"谁在什么时候、由谁授予了什么角色"是可验证的**，不保证"服务端会不会拦人"。
///
/// 签名载荷与校验语义与 npm 包 `@woldworld/protocol` 的 `roomRole` 模块**逐字节同构**
/// （跨语言由 `tool/verify_room_role_hub.js` 钉住：Dart 签的字，Node 必须验得过）。
///
/// 本文件**零平台依赖**（不 import sqflite / SharedPreferences / Flutter）。

library;

import 'dart:convert';

// 验签**不自己实现**：与 M6 背书 / M9 技能清单 / M10 贡献账本共用 `Ed25519Sig`
// 同一份实现。四处各写一份必然漂移，而漂移的形态是"这边拒的假签名那边却收了"。
import 'ed25519_sig.dart' show Ed25519Sig;

/// 房间内的角色。**同一身份在 A 房间是主持人、在 B 房间可以是普通参与者。**
enum RoomRoleKind {
  /// 普通参与者（默认值：进房间就是它，不需要任何授予）。
  participant,

  /// 主持人（房间的主理人；Host 层）。
  host,

  /// 联合主持人（由主持人授予；Host 层）。
  cohost,

  /// 嘉宾（受邀参与的特别来宾；非 Host 层，无管理权）。
  guest,

  /// NPC（房间内的功能角色，如引导员 / 定时播报；非 Host 层）。
  npc;

  /// 落库值：与 `name` 相同（稳定，禁止改名）。
  String get id => name;

  /// 是否属于 **Host 层**（拥有授予 / 撤销角色的权力）。
  bool get isHostLayer => this == RoomRoleKind.host || this == RoomRoleKind.cohost;

  /// 是否有管理权（当前 = Host 层；集中在一处，将来加"场控"只改这里）。
  bool get canModerate => isHostLayer;

  /// 是否是默认角色（默认角色**不落库** —— 没有记录即 participant）。
  bool get isDefault => this == RoomRoleKind.participant;

  /// 解析落库值；未知 / null → [participant]（fail-safe，绝不抛异常）。
  static RoomRoleKind fromId(String? id) {
    for (final r in RoomRoleKind.values) {
      if (r.id == id) return r;
    }
    return RoomRoleKind.participant;
  }
}

/// 一条角色授予记录。**主键 = (roomId, agentId)** —— 一人在一个房间里只有一个角色。
///
/// 刻意没有 `id` 字段里的"全局"概念：`roomId` 是必填且非空，
/// 想构造一个"没有房间的角色"会先撞上 [RoomRoleService.grant] 的 `no_room` 闸。
///
/// 后三个字段（[agentPub] / [granterPub] / [sig]）是 **v1.15 新增的可验证层**：
/// 填齐即成为一份**可被第三方独立验签**的凭证。缺省为空串 ——
/// 此时它仍是一条**合法的本地记录**（旧行为完全不变），只是"不可被外人验证"。
/// 这种"可选"是刻意的：**不允许把不可验证的记录伪装成可验证的**，
/// 所以 [RoomRoleAuthority.verify] 对缺公钥的记录一律拒（`bad_pubkey`）。
class RoomRoleGrant {
  final String roomId;
  final String agentId;
  final RoomRoleKind role;

  /// 授予人（主持人自己认领主持人时 = 自己）。
  final String grantedBy;

  /// 授予时刻。
  final int atMs;

  /// 被授权人的 Ed25519 公钥（base58）。空串 = 未签名（仅本地有效）。
  final String agentPub;

  /// 授予人的 Ed25519 公钥（base58）。空串 = 未签名。
  final String granterPub;

  /// 授予人的签名（base64）。空串 = 未签名。
  final String sig;

  const RoomRoleGrant({
    required this.roomId,
    required this.agentId,
    required this.role,
    required this.grantedBy,
    required this.atMs,
    this.agentPub = '',
    this.granterPub = '',
    this.sig = '',
  });

  /// 复合主键的字符串形式（日志 / 排错用；不是新的一等概念）。
  String get key => '$roomId::$agentId';

  /// 是否已带齐可验证层（三者缺一即不可被第三方验证）。
  bool get isSigned =>
      agentPub.isNotEmpty && granterPub.isNotEmpty && sig.isNotEmpty;

  /// 幂等键：**一个 (房间, 人) 只有一个角色**，与客户端 DB 主键
  /// `(room_id, agent_id)` 同构。与 `@woldworld/protocol` 的 `roomRole.keyOf` 一致。
  String get idempotencyKey => RoomRoleAuthority.keyOf(roomId, agentId);

  /// 签名载荷 —— 与 `packages/protocol/src/roomRole.js` 的 `canonical()` **同序同形**。
  ///
  /// ⚠️ 键序 = 插入序（Dart `jsonEncode` 与 JS `JSON.stringify` 都不排序）。
  /// 改动这里的顺序 = 让历史签名与对端全部失效，**禁止重排**。
  String canonical() => jsonEncode({
        'alg': Ed25519Sig.alg,
        'kind': 'room_role',
        'room_id': roomId,
        'agent_id': agentId,
        'agent_pub': agentPub,
        'role': role.id,
        'granted_by': grantedBy,
        'granter_pub': granterPub,
        'at': atMs,
      });

  List<int> canonicalBytes() => utf8.encode(canonical());

  /// §16 公开叶子字节 —— 与 JS 的 `logBytes()` 同构。
  ///
  /// ⚠️ **有意不含 `agent_id` / `granted_by`**：那是人自己取的名字，
  /// 而日志是任何人都能下载的。公开的断言只关于**公钥**（本就假名化）：
  /// "公钥 P 在房间 X 持有角色 R，由公钥 Q 于时刻 T 授予"。
  List<int> logBytes() => utf8.encode(jsonEncode({
        'kind': 'room_role',
        'room_id': roomId,
        'agent_pub': agentPub,
        'role': role.id,
        'granter_pub': granterPub,
        'at': atMs,
      }));

  RoomRoleGrant copyWith({String? sig, RoomRoleKind? role, int? atMs}) =>
      RoomRoleGrant(
        roomId: roomId,
        agentId: agentId,
        role: role ?? this.role,
        grantedBy: grantedBy,
        atMs: atMs ?? this.atMs,
        agentPub: agentPub,
        granterPub: granterPub,
        sig: sig ?? this.sig,
      );

  Map<String, Object?> toMap() => {
        'room_id': roomId,
        'agent_id': agentId,
        'role': role.id,
        'granted_by': grantedBy,
        'at_ms': atMs,
      };

  /// 可验证层的落库形态（Hub / 账本用；**不是** `room_roles` 表的列）。
  Map<String, Object?> toSignedMap() => {
        'room_id': roomId,
        'agent_id': agentId,
        'agent_pub': agentPub,
        'role': role.id,
        'granted_by': grantedBy,
        'granter_pub': granterPub,
        'at_ms': atMs,
        'sig': sig,
      };

  static RoomRoleGrant fromMap(Map<String, dynamic> m) => RoomRoleGrant(
        roomId: (m['room_id'] as String?) ?? '',
        agentId: (m['agent_id'] as String?) ?? '',
        role: RoomRoleKind.fromId(m['role'] as String?),
        grantedBy: (m['granted_by'] as String?) ?? '',
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
      );

  /// 从 JSON（Hub 响应 / 跨语言载荷）还原。字段名与 `toSignedMap` 一致。
  static RoomRoleGrant fromJson(Map<String, dynamic> m) => RoomRoleGrant(
        roomId: (m['room_id'] as String?) ?? '',
        agentId: (m['agent_id'] as String?) ?? '',
        role: RoomRoleKind.fromId(m['role'] as String?),
        grantedBy: (m['granted_by'] as String?) ?? '',
        atMs: (m['at_ms'] as num?)?.toInt() ?? 0,
        agentPub: (m['agent_pub'] as String?) ?? '',
        granterPub: (m['granter_pub'] as String?) ?? '',
        sig: (m['sig'] as String?) ?? '',
      );
}

/// 被拒原因码（UI 侧翻译成文案）。
abstract final class RoomRoleBlockCode {
  /// 缺少房间出处（铁律 1）。
  static const String noRoom = 'no_room';

  /// 缺少被授权人。
  static const String noAgent = 'no_agent';

  /// 授予人自己不是本房间的主持层（铁律 2）。
  static const String notHost = 'not_host';

  /// 房间已有主持人，认领被拒（防二次占位）。
  static const String hostExists = 'host_exists';

  /// 会撤掉房间里**最后一个**主持层成员（房间失去主持）→ 拒绝。
  static const String lastHost = 'last_host';
}

/// 可验证层（签名凭证）的判定码。与 `@woldworld/protocol` 的 `roomRole.verify`
/// 返回码**逐一对应** —— 两端对同一份记录必须给同一个码，否则"谁说了算"就没了。
abstract final class RoomRoleVerifyCode {
  static const String ok = 'ok';

  /// 缺签名（其余必填项齐全也一律先判这里）。
  static const String missingFields = 'missing_fields';

  /// **缺房间出处**（铁律 1 的可验证形式）。
  ///
  /// ★ 这条**先于验签**：即使签名完美，一个"不属于任何房间的角色"也不合法 ——
  /// 于是"账号级角色"在字节层就没有可表达的形式。
  static const String noRoom = 'no_room';

  /// 房间 id 过长。
  static const String badRoom = 'bad_room';

  /// 缺被授权人。
  static const String noAgent = 'no_agent';

  /// 被授权人 id 过长。
  static const String badAgent = 'bad_agent';

  /// 缺授予人。
  static const String noGranter = 'no_granter';

  /// 被授权人 / 授予人的公钥不是合法 Ed25519 公钥（含"未签名"的空串）。
  static const String badPubkey = 'bad_pubkey';

  /// 角色取值非法。
  static const String badRole = 'bad_role';

  /// 授予时刻缺失 / 非正。
  static const String badWindow = 'bad_window';

  /// 验签失败（含"签名后又被改过"）。
  static const String badSignature = 'bad_signature';
}

/// 某条授予**是否真的有权这么做**的判定码（由第三方复算，与本地同口径）。
abstract final class RoomRoleAuthorityCode {
  /// 空房间被第一个认领者自封为主持人（合法）。
  static const String claimed = 'claimed';

  /// 主持层授出的角色（合法）。
  static const String accepted = 'accepted';

  /// 授予人不是本房间的主持层（拒绝）。
  static const String notHost = 'not_host';

  /// 房间已有主持层，且授予人不是其中一员 → 不能认领（防二次占位夺权）。
  static const String hostExists = 'host_exists';

  /// 会撤掉房间里最后一个主持层成员（拒绝）。
  static const String lastHost = 'last_host';
}

/// 一条授予的**权威判定**结果。
class RoomRoleAuthorityResult {
  final bool accept;
  final String code; // RoomRoleAuthorityCode.*

  const RoomRoleAuthorityResult({required this.accept, required this.code});
}

/// 可验证层的结果。
class RoomRoleVerifyResult {
  final bool ok;
  final String code; // RoomRoleVerifyCode.*

  const RoomRoleVerifyResult({required this.ok, required this.code});
}

class RoomRoleResult {
  final RoomRoleGrant? grant;
  final bool blocked;
  final String? reason; // RoomRoleBlockCode.*
  final bool changed; // true = 本次真的写了库

  const RoomRoleResult({
    this.grant,
    this.blocked = false,
    this.reason,
    this.changed = false,
  });

  bool get ok => !blocked;
}

/// 存储抽象（生产实现见 `room_role_store_db.dart`）。
abstract class RoomRoleStore {
  /// 幂等写入（主键 = (roomId, agentId)）。
  Future<void> upsert(RoomRoleGrant g);

  /// 取某人在某房间的角色记录（无记录 = null，语义上等价于 participant）。
  Future<RoomRoleGrant?> get(String roomId, String agentId);

  /// 某房间的全部角色记录（不含默认 participant —— 他们本来就没记录）。
  Future<List<RoomRoleGrant>> inRoom(String roomId);

  /// 某人在各房间的角色记录（用于"我在哪些房间有身份"）。
  Future<List<RoomRoleGrant>> forAgent(String agentId);
}

class MemoryRoomRoleStore implements RoomRoleStore {
  final Map<String, RoomRoleGrant> _rows = {};

  @override
  Future<void> upsert(RoomRoleGrant g) async => _rows[g.key] = g;

  @override
  Future<RoomRoleGrant?> get(String roomId, String agentId) async =>
      _rows['$roomId::$agentId'];

  @override
  Future<List<RoomRoleGrant>> inRoom(String roomId) async => _rows.values
      .where((g) => g.roomId == roomId)
      .toList()
    ..sort((a, b) => b.atMs.compareTo(a.atMs));

  @override
  Future<List<RoomRoleGrant>> forAgent(String agentId) async => _rows.values
      .where((g) => g.agentId == agentId)
      .toList()
    ..sort((a, b) => b.atMs.compareTo(a.atMs));
}

/// 房间角色服务（纯逻辑，可离线复算）。
class RoomRoleService {
  final RoomRoleStore store;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  /// 本地落库成功后的**上行钩子**（best-effort，由装配层 `wold_runtime` 提供）。
  ///
  /// 只在**真的写了库**时触发 —— 幂等分支（角色没变）不触发：
  /// 没发生过的事不该被公示第二遍，否则公开日志会被"什么都没变"的记录灌满，
  /// 而第三方要复算的东西反而更难看清。
  final void Function(RoomRoleGrant grant)? onCommit;

  RoomRoleService({required this.store, this.onEvent, this.onCommit});

  RoomRoleResult _block(String code, Map<String, Object?> ctx) {
    onEvent?.call('room_role_blocked', {'reason': code, ...ctx});
    return RoomRoleResult(blocked: true, reason: code);
  }

  /// 某人在某房间的角色（无记录 → participant）。
  Future<RoomRoleKind> roleIn(String roomId, String agentId) async {
    final g = await store.get(roomId, agentId);
    return g?.role ?? RoomRoleKind.participant;
  }

  /// 某房间的角色分布（只含**非默认**角色，即真正被授予过的人）。
  Future<Map<String, RoomRoleKind>> rolesIn(String roomId) async {
    final out = <String, RoomRoleKind>{};
    for (final g in await store.inRoom(roomId)) {
      out[g.agentId] = g.role;
    }
    return out;
  }

  /// 某人在**各个房间**的角色记录（"我在哪些房间有身份"）。
  ///
  /// 注意返回值里每一条都带 `roomId` —— 这正是铁律 1 的体现：
  /// 角色永远和房间成对出现，不存在一条"不属于任何房间"的角色记录。
  Future<List<RoomRoleGrant>> rolesOf(String agentId) =>
      store.forAgent(agentId);

  /// **铁律 1 的可证形式**：不存在"全局角色"。
  ///
  /// 无论这个人在多少房间里当了主持人，一旦问"他脱离房间是什么身份"，
  /// 答案恒为 [RoomRoleKind.participant]。账号本身不携带任何权力。
  Future<RoomRoleKind> globalRole(String agentId) async =>
      RoomRoleKind.participant;

  /// 房间是否已有主持层成员。
  Future<bool> hasHost(String roomId) async {
    final rows = await store.inRoom(roomId);
    return rows.any((g) => g.role.isHostLayer);
  }

  /// 认领主持人：**房间当前无人主持**时，第一个认领者成为主持人。
  ///
  /// fail-closed：
  /// - 缺房间出处 → `no_room`；
  /// - 缺认领人 → `no_agent`；
  /// - 房间已有主持层 → `host_exists`（防二次占位夺权）。
  Future<RoomRoleResult> claimHost({
    required String roomId,
    required String agentId,
    required int atMs,
  }) async {
    if (roomId.trim().isEmpty) {
      return _block(RoomRoleBlockCode.noRoom, {'agent': agentId});
    }
    if (agentId.trim().isEmpty) {
      return _block(RoomRoleBlockCode.noAgent, {'room': roomId});
    }
    if (await hasHost(roomId)) {
      return _block(RoomRoleBlockCode.hostExists, {'room': roomId, 'agent': agentId});
    }
    final g = RoomRoleGrant(
      roomId: roomId,
      agentId: agentId,
      role: RoomRoleKind.host,
      grantedBy: agentId,
      atMs: atMs,
    );
    await store.upsert(g);
    onEvent?.call('room_role_claimed_host',
        {'room': roomId, 'agent': agentId, 'at_ms': atMs});
    onCommit?.call(g);
    return RoomRoleResult(grant: g, changed: true);
  }

  /// 授予 / 变更角色（**铁律 2**：只有本房间主持层能操作，fail-closed）。
  ///
  /// 把 [role] 传成 [RoomRoleKind.participant] 即等价于**撤销**。
  Future<RoomRoleResult> grant({
    required String roomId,
    required String agentId,
    required RoomRoleKind role,
    required String granterId,
    required int atMs,
  }) async {
    if (roomId.trim().isEmpty) {
      return _block(RoomRoleBlockCode.noRoom, {'agent': agentId});
    }
    if (agentId.trim().isEmpty) {
      return _block(RoomRoleBlockCode.noAgent, {'room': roomId});
    }

    final granterRole = await roleIn(roomId, granterId);
    if (!granterRole.isHostLayer) {
      return _block(RoomRoleBlockCode.notHost, {
        'room': roomId,
        'granter': granterId,
        'granter_role': granterRole.id,
        'agent': agentId,
      });
    }

    final current = await roleIn(roomId, agentId);

    // 撤销/降级掉**房间最后一个**主持层 → 房间失去主持，拒绝
    // （否则房间会变成"有人可以管但没人负责"的悬空态）。
    if (current.isHostLayer && !role.isHostLayer) {
      final rows = await store.inRoom(roomId);
      final hostCount = rows.where((g) => g.role.isHostLayer).length;
      if (hostCount <= 1) {
        return _block(RoomRoleBlockCode.lastHost, {
          'room': roomId,
          'agent': agentId,
          'role': current.id,
        });
      }
    }

    if (current == role) {
      // 幂等：角色没变，不写库、不算失败
      return RoomRoleResult(
        grant: RoomRoleGrant(
          roomId: roomId,
          agentId: agentId,
          role: role,
          grantedBy: granterId,
          atMs: atMs,
        ),
      );
    }

    final g = RoomRoleGrant(
      roomId: roomId,
      agentId: agentId,
      role: role,
      grantedBy: granterId,
      atMs: atMs,
    );
    await store.upsert(g);
    onEvent?.call('room_role_granted', {
      'room': roomId,
      'agent': agentId,
      'role': role.id,
      'granter': granterId,
      'from': current.id,
    });
    onCommit?.call(g);
    return RoomRoleResult(grant: g, changed: true);
  }

  /// 撤销角色（等价于授予 participant）。
  Future<RoomRoleResult> revoke({
    required String roomId,
    required String agentId,
    required String granterId,
    required int atMs,
  }) =>
      grant(
        roomId: roomId,
        agentId: agentId,
        role: RoomRoleKind.participant,
        granterId: granterId,
        atMs: atMs,
      );
}

/// **可验证层**：把"谁在什么时候、由谁授予了什么角色"做成**任何人可独立复算**的判定。
///
/// 为什么这一层值得单独存在：上面那个 [RoomRoleService] 管的是**本地行为对不对**
/// （幂等、铁律、fail-closed）。但"对面那个人到底是不是主持人"这个问题的答案
/// 不能由我们自己宣布 —— 必须让第三方**只凭记录本体**就能算出来。
/// 这就是 [verify]（这条记录是不是真的）与 [grantDecision]（他有没有权这么授）
/// 存在的理由。
///
/// 纯静态、无状态、零平台依赖，因此 `dart run tool/verify_room_role_host.dart`
/// 可离线复算全部判定。
abstract final class RoomRoleAuthority {
  static const int maxRoomIdChars = 200;
  static const int maxAgentIdChars = 200;

  /// 幂等键：**一个 (房间, 人) 只有一个角色**。与 `@woldworld/protocol` 的
  /// `roomRole.keyOf` 逐字符同构（跨语言由 Node 侧校验脚本钉住）。
  static String keyOf(String roomId, String agentId) => 'room|$roomId|$agentId';

  /// 校验一条授予**形式上合法且签名有效**。fail-closed。
  ///
  /// 检查顺序与返回码刻意与 `@woldworld/protocol` 的 `roomRole.verify` **逐条对齐**
  /// （先便宜后昂贵、密码学放最后）—— 两端给同一个码，才有"同一个判定"可言。
  static Future<RoomRoleVerifyResult> verify(RoomRoleGrant g) async {
    if (g.sig.trim().isEmpty) {
      return const RoomRoleVerifyResult(
          ok: false, code: RoomRoleVerifyCode.missingFields);
    }
    // ★ 铁律 1 的可验证形式，**先于验签**：不属于任何房间的角色不合法。
    //   于是"账号级角色"在字节层就没有可表达的形式（签名再完美也救不回来）。
    if (g.roomId.trim().isEmpty) {
      return const RoomRoleVerifyResult(ok: false, code: RoomRoleVerifyCode.noRoom);
    }
    if (g.roomId.length > maxRoomIdChars) {
      return const RoomRoleVerifyResult(ok: false, code: RoomRoleVerifyCode.badRoom);
    }
    if (g.agentId.trim().isEmpty) {
      return const RoomRoleVerifyResult(ok: false, code: RoomRoleVerifyCode.noAgent);
    }
    if (g.agentId.length > maxAgentIdChars) {
      return const RoomRoleVerifyResult(ok: false, code: RoomRoleVerifyCode.badAgent);
    }
    if (g.grantedBy.trim().isEmpty) {
      return const RoomRoleVerifyResult(
          ok: false, code: RoomRoleVerifyCode.noGranter);
    }
    // 未签名（空公钥）也走这里 —— 不许把"不可验证"伪装成"可验证"。
    if (!Ed25519Sig.isPubkey(g.agentPub) ||
        !Ed25519Sig.isPubkey(g.granterPub)) {
      return const RoomRoleVerifyResult(
          ok: false, code: RoomRoleVerifyCode.badPubkey);
    }
    if (!RoomRoleKind.values.any((r) => r.id == g.role.id)) {
      return const RoomRoleVerifyResult(ok: false, code: RoomRoleVerifyCode.badRole);
    }
    if (g.atMs <= 0) {
      return const RoomRoleVerifyResult(
          ok: false, code: RoomRoleVerifyCode.badWindow);
    }
    final ok = await Ed25519Sig.verify(
      message: g.canonicalBytes(),
      signatureB64: g.sig,
      publicKeyBase58: g.granterPub,
    );
    return RoomRoleVerifyResult(
      ok: ok,
      code: ok ? RoomRoleVerifyCode.ok : RoomRoleVerifyCode.badSignature,
    );
  }

  /// 按时间顺序重放，得到**每个 agent 的当前角色**（缺省 = participant）。
  static Map<String, RoomRoleKind> latestRoles(
    List<RoomRoleGrant> grants,
    String roomId,
  ) {
    final out = <String, RoomRoleKind>{};
    for (final g in grants) {
      if (g.roomId != roomId) continue;
      out[g.agentId] = g.role;
    }
    return out;
  }

  /// 某人在某房间的角色 —— **铁律 1 的正向表述**：离开房间，你什么都不是。
  static RoomRoleKind roleOf(
    List<RoomRoleGrant> grants,
    String roomId,
    String agentId,
  ) =>
      latestRoles(grants, roomId)[agentId] ?? RoomRoleKind.participant;

  /// 权威判定：给定**此前**的授予序列，这条授予该不该被接受。
  ///
  /// 这是第三方跑的那一步 —— 把同一份列表喂给它，它不问我就能得出同一个结论。
  static RoomRoleAuthorityResult grantDecision(
    RoomRoleGrant g,
    List<RoomRoleGrant> priorGrants,
  ) {
    if (g.roomId.trim().isEmpty) {
      return const RoomRoleAuthorityResult(
          accept: false, code: RoomRoleVerifyCode.noRoom);
    }
    if (g.agentId.trim().isEmpty) {
      return const RoomRoleAuthorityResult(
          accept: false, code: RoomRoleVerifyCode.noAgent);
    }
    if (g.grantedBy.trim().isEmpty) {
      return const RoomRoleAuthorityResult(
          accept: false, code: RoomRoleAuthorityCode.notHost);
    }

    final roles = latestRoles(priorGrants, g.roomId);
    final granterRole = roles[g.grantedBy] ?? RoomRoleKind.participant;
    final hostCount = roles.values.where((r) => r.isHostLayer).length;

    if (!granterRole.isHostLayer) {
      // 唯一的例外：空房间、自封主持人、且只能是自己。
      if (g.role == RoomRoleKind.host &&
          hostCount == 0 &&
          g.grantedBy == g.agentId) {
        return const RoomRoleAuthorityResult(
            accept: true, code: RoomRoleAuthorityCode.claimed);
      }
      // 房间已经有主持人了，晚到者不能靠"自称"上位。
      if (g.role == RoomRoleKind.host && hostCount > 0) {
        return const RoomRoleAuthorityResult(
            accept: false, code: RoomRoleAuthorityCode.hostExists);
      }
      return const RoomRoleAuthorityResult(
          accept: false, code: RoomRoleAuthorityCode.notHost);
    }

    // 不许把房间的最后一个主持层成员撤掉 —— 那会留下"有人能管、没人负责"的悬空态。
    final currentRole = roles[g.agentId] ?? RoomRoleKind.participant;
    if (currentRole.isHostLayer && !g.role.isHostLayer && hostCount <= 1) {
      return const RoomRoleAuthorityResult(
          accept: false, code: RoomRoleAuthorityCode.lastHost);
    }

    return const RoomRoleAuthorityResult(
        accept: true, code: RoomRoleAuthorityCode.accepted);
  }

  // ------------------------------------------------------------------
  // 上行：把**本地判定**升级成**可被第三方复算的签名记录**
  // ------------------------------------------------------------------

  /// 把一条本地 grant 补成**可上行的签名 grant**。
  ///
  /// 为什么需要这一步：[RoomRoleService] 只管**本地行为对不对**（幂等、铁律、
  /// fail-closed），它造出的 grant **既不带公钥也不带签名** —— 这本身是合理的
  /// 分层（私钥不出设备，签名是"本机身份"的职责）。但"他到底是不是主持人"
  /// 这个问题要能被**第三方**回答，就必须在记录里留下签名与双方公钥。
  /// Hub 的 `roomRoleVerify` 要求 `granter_pub` 非空且 `sig` 覆盖 `canonical()`，
  /// 所以**未签名的 grant 根本没法上行** —— 这一步不是可选项。
  ///
  /// fail-closed 返回 `null` 的两种情形（**绝不伪造**）：
  /// - 拿不到被授予人的公钥（`agent_pub`）：改用 Agent ID 代替，等于让
  ///   "换一次 ID 就甩掉历史"重新成立 —— 那正是本层存在的理由；
  /// - 拿不到授予人的公钥。
  ///
  /// [sign] 用本机身份私钥对 [RoomRoleGrant.canonicalBytes] 签名（base64）。
  static Future<RoomRoleGrant?> signGrant({
    required RoomRoleGrant g,
    required String? agentPub,
    required String? granterPub,
    required Future<String> Function(List<int> bytes) sign,
  }) async {
    final ap = (agentPub ?? '').trim();
    final gp = (granterPub ?? '').trim();
    if (ap.isEmpty || gp.isEmpty) return null;
    final draft = RoomRoleGrant(
      roomId: g.roomId,
      agentId: g.agentId,
      role: g.role,
      grantedBy: g.grantedBy,
      atMs: g.atMs,
      agentPub: ap,
      granterPub: gp,
    );
    final sig = await sign(draft.canonicalBytes());
    return draft.copyWith(sig: sig);
  }
}
