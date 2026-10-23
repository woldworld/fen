import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'agent_identity.dart';
import 'app_logger.dart';
import 'attestation_service.dart';
import 'attestation_store_db.dart';
import 'circle_service.dart';
import 'circle_store_db.dart';
import 'cloud_service.dart';
import 'contribution_ledger.dart';
import 'contribution_store_db.dart';
import 'db_helper.dart';
import 'delegation_service.dart';
import 'delegation_store_db.dart';
import 'delegation_transport.dart';
import 'device_migration_service.dart';
import 'digest_service.dart';
import 'chat_stats_source.dart';
import 'hub_outbox.dart';
import 'hub_write_service.dart';
import 'intercard_service.dart';
import 'intercard_store_db.dart';
import 'presence_service.dart';
import 'presence_store_db.dart';
import 'room_role.dart';
import 'room_role_store_db.dart';
import 'skill_registry.dart';
import 'skill_store_db.dart';
import 'reputation_network.dart';
import 'reputation_network_store_db.dart';
import 'rotation_chain.dart';
import 'trial_gateway.dart';
import 'trial_store_db.dart';
import 'telemetry.dart';
import 'telemetry_store_db.dart';
import 'transparency_log.dart';
import 'transparency_store_db.dart';
import 'world_bridge_service.dart';
import 'world_bridge_store_db.dart';
import 'wold_did.dart';

/// 大荒运行时：**M1 入场即进圈 + M2 事务委托的唯一装配点**。
///
/// 为什么要有这一层：
/// - `circle_service.dart` / `delegation_service.dart` 刻意保持零平台依赖（好验证）；
/// - 生产要用真设备身份（AgentIdentity，私钥不出设备）+ SQLite 落库 + 埋点落盘；
/// - 装配只应该发生在一个地方，否则会出现"一处用了测试 signer、一处没绑埋点"。
///
/// 用法：App 启动时 `await WoldRuntime.i.init()`，之后取 `i.circles` / `i.delegations`。
class WoldRuntime {
  WoldRuntime._();
  static final WoldRuntime i = WoldRuntime._();

  bool _ready = false;
  bool get isReady => _ready;

  /// 启动期失败的**可见留痕**（null = 正常）。
  ///
  /// 为什么要有它：`init()` 失败以前只 `debugPrint` 一行 —— App 照样启动，
  /// 用户看到的是"某些功能莫名不可用"的半死界面，而排障的人在没有日志的
  /// 设备上无从下手（`debugPrint` 在 release 包里根本看不见）。
  /// 现在把原因留在这个单例上：一边落 `system_logs`（可查），一边由 UI 显式呈现。
  String? initError;

  /// 记录启动失败。**由宿主在自己的 catch 里调用**，不在 `init()` 内部吞 ——
  /// 谁启动谁负责，内部吞掉会让"失败"变回静默，那正是这个字段要终结的行为。
  void rememberInitFailure(Object error, [StackTrace? st]) {
    initError = error.toString();
    AppLogger.e('WoldRuntime', error, st);
  }

  late final Signer signer;
  late final DbCircleStore circleStore;
  late final DbDelegationStore delegationStore;
  late final CircleService circles;
  late final DelegationService delegations;
  late final DelegationRelay relay;
  late final DigestService digest;
  late final InterCardService intercards;
  late final InterCardRelay intercardRelay;
  late final DbInterCardStore interCardStore;
  late final DbPresenceStore presenceStore;
  late final DbSelfIntroStore selfIntroStore;
  late final PresenceRelay presenceRelay;
  late final SelfIntroService selfIntros;

  /// M5 跨圈桥：房间出现记录（跨圈边的唯一出处）+ 跨圈边账本。
  late final DbRoomPresenceStore roomPresences;
  late final DbBridgeLinkStore bridgeLinks;
  late final WorldBridgeService bridges;

  /// M10 房间角色：**角色属于房间**（同一身份在 A 房间当主持人、在 B 房间是普通人）。
  /// 默认角色 participant 不落库，因此新房间天然"无人主持"。
  late final DbRoomRoleStore roomRoleStore;
  late final RoomRoleService roomRoles;

  /// M9 技能生态：**签名上架 → 作者分成 → 可复算账本**。
  /// 注册表判定（验签/幂等/单层分账）是零依赖纯函数（`skill_registry.dart`），
  /// 这里只把"判定"接到落库与审计事件上。
  late final DbSkillStore skillStore;
  late final SkillRegistryService skills;

  /// M8 试用额度代调网关（PRD §4 M8 / §9.1 红线）。
  ///
  /// ⚠️ `trialGateway.enabled` **默认 false** —— 代调会让我们从"传话人"变成
  /// "内容生产者"（中/欧/美三法域责任落到我们头上）。所以默认一律不代调，
  /// 只有显式开启 + 用途在白名单 + 服务商在白名单 + 额度落库未超，才放行。
  late final DbTrialStore trialStore;
  late final TrialGatewayService trialGateway;

  /// M6 网络级信誉：**签名背书 + 可验证的信任传播**（不做全局信誉分，理由见模块头）。
  late final DbReputationStore reputationStore;
  late final ReputationNetworkService reputationNetwork;

  /// M6 护照与信誉的种子：三段式互签互介记录 + §16 公开只追加日志。
  late final DbAttestationStore attestationStore;
  late final AttestationService attestations;
  late final IntroRelay introRelay;
  late final DbTransparencyLog transparency;

  /// M10 五件套：① 创始成员 ② 永久价格锁定 ③ 贡献声望 ⑤ 可验证贡献账本。
  ///
  /// 它同时是 §16 的**第二个业务写入方**（第一个是互介记录）——
  /// PRD §16.1 明确要求"同一棵树、同一个 monitor、同一期透明报告"
  /// 同时承载"身份与信誉记录"与"贡献账本"，所以这里**不另建一棵树**，
  /// 而是复用上面同一个 [transparency]。
  late final DbContributionStore contributionStore;
  late final ContributionService contributions;

  /// **App → Hub 上行通道**（§16 公示那条腿）。
  ///
  /// 在此之前，下面所有"本地那一半"都是齐的（各自带 SQLite 实现、各自可离线验签），
  /// 却**没有任何一行代码把它们推上 Hub** —— 于是"你不必相信我，你可以验我"
  /// 并没有数据流进那棵公开的树，属于**宣称大于事实**。
  /// 本对象就是补上的那条腿：所有上行都从这里走，暂时发不出去的自动入队
  /// （见 `hub_outbox.dart`），下次联网重放。
  late final HubWriteService hubWrites;

  /// **换机直迁**（`FENMIG1`）：身份与数据"随人不随设备"的**当面那条腿**。
  ///
  /// 它与恢复码路径的分工：恢复码那条路假设"**老设备已经不在了**"，
  /// 这里假设"**老设备还拿在手上**" —— 于是用户不必抄 177 个字符，
  /// 走"两机当面对一下短码"即可。**两条路并存**，谁也替代不了谁。
  ///
  /// ⚠️ 入站走独立的 `migrationRelay`（见 `agent_service` 的截获链），
  /// 出站复用上面同一条 [outbound]。
  late final DeviceMigrationService migrations;

  /// 出站通道（近场/局域网/云端全通道）。
  ///
  /// 由 `main.dart` 注入，**core 层之间不互相 import**：否则 agent_service（入站）
  /// 与 wold_runtime（装配）会形成环。未注入时委托只落本机，不会发出。
  DelegationSender? outbound;

  /// 圈子人数不足时的兜底来源（同城/同房间在线分身）。由宿主注入，
  /// 不注入则 M1 验收只能靠圈内真实人数。
  NeighborFallback? neighborFallback;

  Future<void> init() async {
    if (_ready) return;

    // ① 埋点先落盘：不 bind 的话 M1/M2 的验收指标全部静默丢弃。
    Telemetry.bind(DbTelemetryStore());

    // ② 真设备身份（Ed25519，私钥永不出设备）
    signer = AgentIdentitySigner(
      pub: () => AgentIdentity().publicKeyBase58(),
      sign: (m) => AgentIdentity().signBase64(m),
    );

    // ②′ 上行通道：与身份同时就位 —— 它每次发送都要现场用上面的私钥签信封，
    //     所以身份没就位之前它就不能工作（这也正是"信封不缓存"的原因）。
    hubWrites = HubWriteService();

    circleStore = DbCircleStore();
    delegationStore = DbDelegationStore();

    // ③ did:wold 身份签发（PRD §5.4 不可补录）：
    //    首次运行生成带时间戳的自签名签发记录，落库 append-only。
    //    审计必须从第一天连续，断档不可补 —— 所以放在 init 里，不等 UI。
    await _issueDidIfNeeded();

    circles = CircleService(
      store: circleStore,
      signer: signer,
      neighborFallback: (c, self) async {
        final f = neighborFallback;
        if (f == null) return <String>[];
        return f(c, self);
      },
      onEvent: _track,
    );
    delegations = DelegationService(
      store: delegationStore,
      signer: signer,
      onEvent: _track,
    );
    relay = DelegationRelay(
      store: delegationStore,
      send: (target, wire) async {
        final f = outbound;
        if (f == null) return false;
        return f(target, wire);
      },
      selfId: myAgentId,
      onEvent: _track,
    );

    // ④ 每日摘要数据源：委托走同一个 store；新入圈走 SQLite；统计走埋点。
    final telemetryDb = Telemetry.instance?.store;
    digest = DigestService(
      sources: DigestSources(
        delegationStore: delegationStore,
        recentJoins: circleStore.recentJoins,
        events: telemetryDb is DbTelemetryStore
            ? () async =>
                [for (final e in await telemetryDb.all()) e.toJson()]
            : null,
        chatStats: SqliteChatStatsSource(),
      ),
    );

    // ⑤ M3 互介卡：与委托共用同一条出站通道（outbound）。
    interCardStore = DbInterCardStore();
    intercards = InterCardService(
      store: interCardStore,
      signer: signer,
      onEvent: _track,
    );
    intercardRelay = InterCardRelay(
      store: interCardStore,
      service: intercards,
      send: (target, wire) async {
        final f = outbound;
        if (f == null) return false;
        return f(target, wire);
      },
      selfId: myAgentId,
      onEvent: _track,
    );

    // ⑥ M4 在场机制：路径判定在 UI 层采集证据、core 判定；
    //    一次性披露账本必须落库（否则"自报过谁"会丢，变成重复自报）。
    presenceStore = DbPresenceStore();
    selfIntroStore = DbSelfIntroStore();
    presenceRelay = PresenceRelay(
      store: presenceStore,
      signer: signer,
      selfId: myAgentId,
      send: (target, wire) async {
        final f = outbound;
        if (f == null) return false;
        return f(target, wire);
      },
      onEvent: _track,
    );
    selfIntros = SelfIntroService(store: selfIntroStore, onEvent: _track);

    // ⑦ M5 世界房间 = 圈的载体：跨圈边的唯一出处是"房间里看见过"，
    //    所以出现记录必须先落库；边账本幂等由主键 (self->peer) 保证。
    roomPresences = DbRoomPresenceStore();
    bridgeLinks = DbBridgeLinkStore();
    bridges = WorldBridgeService(store: bridgeLinks, onEvent: _track);

    // ⑦′ M10 房间角色：与 M5 房间同源 —— 房间是"活动"的载体，
    //     角色是活动内属性，因此和 room_presences 一样必须落库（v27）。
    roomRoleStore = DbRoomRoleStore();
    roomRoles = RoomRoleService(
        store: roomRoleStore, onEvent: _track, onCommit: _commitRoomRole);

    // ⑦″ M9 技能注册表：与插件总线并列的"生态层" —— 插件总线管**本机装载**，
    //     技能注册表管**跨端上架与分账**（清单由作者签名，平台改不动）。
    skillStore = DbSkillStore();
    skills = SkillRegistryService(
        store: skillStore, onEvent: _track, onCommit: _commitSkill);

    // ⑦‴ M8 代调网关：**默认关闭**（enabled = false）。
    //     这不是"还没配好"，而是刻意的合规地基 —— 不显式开启就没有敞口。
    //     allowedProviders 为空 = 一个服务商都不放行（双重 fail-closed）。
    trialStore = DbTrialStore();
    trialGateway = TrialGatewayService(
      store: trialStore,
      enabled: false,
      allowedProviders: const {},
      onEvent: _track,
    );

    // ⑦⁗ M6 网络级信誉：与本地主观信誉（reputation_service）**互补而不是替代** ——
    //     本地分是"我怎么看他"，网络背书是"别人怎么看他、且我能验证"。
    //     查询必须带调用方自己的锚点，查不到返回 unknown（绝不退化成 0 分）。
    reputationStore = DbReputationStore();
    reputationNetwork = ReputationNetworkService(
        store: reputationStore, onEvent: _track, onCommit: _commitEndorsement);

    // ⑧ M6 护照与信誉的种子 + §16 可验证性。
    //    顺序有讲究：**日志先于存证服务** —— 存证服务每推进一步都要往日志里
    //    追加一片叶子（onAdvance），日志还没就位就会空指针。
    transparency = DbTransparencyLog();
    attestationStore = DbAttestationStore();
    attestations = AttestationService(
      store: attestationStore,
      signer: signer,
      selfId: myAgentId,
      onEvent: _track,
      onAdvance: _appendToTransparencyLog,
    );
    introRelay = IntroRelay(
      store: attestationStore,
      send: (target, wire) async {
        final f = outbound;
        if (f == null) return false;
        return f(target, wire);
      },
      selfId: myAgentId,
      onEvent: _track,
      onAdvance: _appendToTransparencyLog,
    );

    // ⑨ M10 五件套：贡献账本与 §16 **共用同一棵树**（同一 monitor、同一期报告）。
    //    顺序同样有讲究：**日志先于服务** —— 服务每条记录都要往日志里追一片叶子。
    //    声望分刻意不落库（派生值），全部由 `ContributionLedger.tally` 从记录现算。
    contributionStore = DbContributionStore();
    contributions = ContributionService(
      store: contributionStore,
      onEvent: _track,
      onAppend: _appendContributionToLog,
    );

    // ⑩ 换机直迁：与上面几个 relay 并列，共用同一条出站通道。
    //    放在最后是因为它不产出任何"要与 §16 合流"的记录 —— 它的事件由
    //    Hub 的 `key_rotations` 与公开日志承担（那条腿走 `cloud_service`）。
    migrations = DeviceMigrationService(
      send: (target, wire) async {
        final f = outbound;
        if (f == null) return false;
        return f(target, wire);
      },
      selfId: myAgentId,
      onEvent: _track,
    );

    _ready = true;
    Telemetry.instance?.track('runtime_ready');
  }
  /// 我的分身 ID（沿用既有 my_agent_id，避免与通讯/路由层的 ID 分叉）。
  Future<String> myAgentId() async =>
      await DBHelper.getAmbassador('my_agent_id') ?? 'AG-000';

  /// did:wold 签发（幂等）：同一身份只签发一次；重装生成新身份 → 新增一行。
  ///
  /// ★ 落库用的 DID 是 [AgentIdentity.identityRootDid]（**身份根**），
  /// 不是按当前公钥现推的值 —— 换钥之后现推会得到 `did:wold:<新钥>`，
  /// 与 Hub 侧稳定不变的身份锚分叉，还会在本表里凭空多出一条"新身份"的签发记录。
  ///
  /// append-only：只 INSERT OR IGNORE，绝不更新/删除既有签发记录 ——
  /// 否则"身份固化"就是一句空话。
  Future<void> _issueDidIfNeeded() async {
    final pub = await signer.publicKeyBase58();
    final did = await AgentIdentity().identityRootDid();

    final db = await DBHelper.db;
    final existing = await db.query('did_issuance',
        where: 'did = ?', whereArgs: [did], limit: 1);
    if (existing.isNotEmpty) return; // 已签发，幂等返回

    final agentId = await myAgentId();
    final issuedAt = DateTime.now().millisecondsSinceEpoch;
    final sig = await signer.signBytes(utf8.encode(
        WoldDid.issuanceCanonical(did: did, pub: pub, issuedAtMs: issuedAt)));

    await db.insert(
      'did_issuance',
      {
        'did': did,
        'pub': pub,
        'agent_id': agentId,
        'issued_at': issuedAt,
        'sig': sig,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // 并发下只留第一条
    );
    Telemetry.instance?.track('did_issued', props: {
      'self': agentId,
      'did': did,
      'issued_at': issuedAt,
    });
  }

  void _track(String name, Map<String, Object?> props) =>
      Telemetry.instance?.track(name, props: props);

  // ------------------------------------------------------------------
  // §16 透明日志：互介记录每推进一步 → 追加一片叶子
  // ------------------------------------------------------------------

  /// 把一条互介记录映射成叶子哈希并追加进 §16 公开日志（幂等）。
  ///
  /// 叶子字节由 [IntroAttestation.logLeafBytes] 确定性给出（只含公开字段），
  /// 于是**任何第三方**都能凭记录独立算出同一个叶子哈希，
  /// 再用包含证明验证"它确实在第 N 期里"。这就是"你不必相信我，你可以验我"。
  ///
  /// 触发时机由 [AttestationService.onAdvance] / [IntroRelay.onAdvance] 决定，
  /// 二者都**在签名落库之后**触发 —— 记进公开账本的必须是"已签名的记录"，
  /// 而不是一句还没有签名的自称。
  Future<void> _appendToTransparencyLog(IntroAttestation a) async {
    String? leafHash;
    try {
      leafHash = await TransparencyLog.leafHashOf(a.logLeafBytes());
      await transparency.appendOnce(leafHash);
    } catch (e) {
      // 日志失败不能让存证本身失败：日志是"可验证性"的补位机制，
      // 不是主链路的必经环节。失败留痕，下次推进会自动补上（幂等）。
      Telemetry.instance?.track('transparency_append_failed',
          props: {'intro_id': a.id, 'error': '$e'});
      return;
    }
    // 本地叶子一落，就尝试**公示**（§16 的那条腿）。
    // 刻意另起一段而不并进上面的 try：上行失败与本地落库失败是两件事，
    // 共用一个 catch 会把"没公示出去"误记成"日志写失败"，
    // 而这两者的排查方向恰好相反（前者查网络/配置，后者查本机库）。
    await _pushLogLeaf(leafHash);
  }

  /// M10 ⑤ **可验证贡献账本**：一条贡献记录落库后 → 追加一片叶子进**同一棵**树。
  ///
  /// 与互介记录走完全相同的纪律：
  /// - 叶子字节由 [ContributionRecord.logLeafBytes] 确定性给出（只含公开字段，
  ///   不含自由文本附言），于是**任何第三方**都能凭记录独立算出同一个哈希；
  /// - 触发时机在**签名落库之后** —— 记进公开账本的必须是"已签名的记录"，
  ///   而不是一句还没有签名的自称。
  ///
  /// 这就是 PRD §16.1 说的"合流"：贡献账本不是第二套信任体系，
  /// 而是**同一棵树的第二类叶子**。第三方只需一个 monitor 就能同时监督两者。
  Future<void> _appendContributionToLog(ContributionRecord r) async {
    try {
      final leafHash = await TransparencyLog.leafHashOf(r.logLeafBytes());
      await transparency.appendOnce(leafHash);
    } catch (e) {
      // 同 `_appendToTransparencyLog`：日志失败不能阻断记账（幂等，下次会补）。
      Telemetry.instance?.track('contribution_log_append_failed',
          props: {'subject': r.subjectPub, 'ctype': r.kind, 'error': '$e'});
      return;
    }
    // 公示走**贡献端点**而不是裸 `log/append`：Hub 的 `/api/contributions/commit`
    // 自己也会把这片叶子并进同一棵树（§16.1 的"合流"），且额外记下
    // key → 叶子下标的映射 —— 第三方才有办法把"某条贡献"定位到树里某一叶。
    // 两条都发等于把同一片叶子送两遍，纯属浪费。
    await _commitContributionToHub(r);
  }

  // ------------------------------------------------------------------
  // App → Hub 上行（§16 公示那条腿）
  //
  // 纪律与上面两处一致：**本地先成功，上行是 best-effort**。
  // 但"best-effort"不等于"失败就算了"——失败会入队（`hub_outbox`），
  // 下次启动 / 网络恢复时重放。Hub 侧五个写端点**全部幂等**，故重放安全；
  // 这也正是可以放心重放、不需要在客户端再搞"已发送"标记的原因。
  // ------------------------------------------------------------------

  /// §16 叶子 → `POST /api/log/append`（用于**没有专属端点**的叶子，如互介记录）。
  Future<void> _pushLogLeaf(String leafHash) async {
    try {
      await hubWrites.pushLogAppend(leafHash);
    } catch (e) {
      AppLogger.w('hub.pushLog', e);
    }
  }

  /// M10 ⑤ 贡献 → `POST /api/contributions/commit`（Hub 复算 canonical / 叶子 / 幂等键）。
  Future<void> _commitContributionToHub(ContributionRecord r) async {
    try {
      await hubWrites.commitContribution(r);
    } catch (e) {
      AppLogger.w('hub.pushContribution', e);
    }
  }

  /// M9 上架 → `POST /api/skills/publish`（Hub 独立验签 + 幂等/防换手/版本单调）。
  Future<void> _commitSkill(SkillListing l) async {
    try {
      await hubWrites.publishSkill(l);
    } catch (e) {
      AppLogger.w('hub.pushSkill', e);
    }
  }

  /// M6 背书 → `POST /api/reputation/endorse`。
  Future<void> _commitEndorsement(Endorsement e) async {
    try {
      await hubWrites.endorse(e);
    } catch (e) {
      AppLogger.w('hub.pushEndorsement', e);
    }
  }

  // ------------------------------------------------------------------
  // M6 履历「随人走」—— 身份换钥之后，履历不能跟着旧钥一起退休
  // ------------------------------------------------------------------

  /// 我的**全部公钥**：当前钥 ∪ 本地退休记录 ∪ Hub 换钥链。
  ///
  /// ★ 这是履历"随人走"的取用点。M6 背书按 `subject_pub`（公钥）计而**不是**按
  ///   `agent_id` —— 这是刻意设计：名字由平台发放、可被重发，"换个名字就甩掉差评"。
  ///   代价是：换钥退休旧公钥之后，此前收到的背书**仍记在旧钥上**。只认当前钥，
  ///   用户换一次手机就会看到自己的履历归零 —— 与"随人走"正相反。
  ///
  /// 三路取并集，每一路都不可替代：
  /// - **当前钥**：没有它就什么都查不到；
  /// - **本地退休记录**（[AgentIdentity.retiredKeys]）：离线 / Hub 不可达时唯一还能用的一份；
  /// - **Hub 换钥链**：换机恢复后新机的本地库里**根本没有**旧钥（它是一块干净的盘），
  ///   只能问 Hub。链上的每条 ROTATE 由 `RotationChain.keysOf` **在本地逐条验签**，
  ///   Hub 的说法只作对照（与 v0.29.0 的换钥链读端点同一条纪律）。
  ///
  /// fail-closed：任何一路失败都不影响其余两路 —— "少给"是安全方向。
  /// 而"错给"（把别人的钥算作我）结构上不可能：写入本地历史只有 [AgentIdentity.adoptAgentId]
  /// 一个点，且必须发生在**服务端已确认改绑**之后。
  Future<Set<String>> myIdentityKeys() async {
    final keys = <String>{};
    if (!_ready) return keys;
    try {
      final agentId = await myAgentId();
      final current = (await signer.publicKeyBase58()).trim();
      if (current.isNotEmpty) keys.add(current);
      try {
        for (final k in await AgentIdentity().retiredKeys(agentId)) {
          final p = k.trim();
          if (p.isNotEmpty) keys.add(p);
        }
      } catch (e) {
        AppLogger.w('identity.keys.local', e);
      }
      try {
        final RotationChain? chain =
            await CloudService().fetchIdentityRotations(agentId: agentId);
        if (chain != null) {
          final resolved = await chain.keysOf(current);
          if (resolved.resolved) {
            for (final k in resolved.keys) {
              if (k.isNotEmpty) keys.add(k);
            }
          }
        }
      } catch (e) {
        AppLogger.w('identity.keys.hub', e);
      }
    } catch (e) {
      AppLogger.w('identity.keys', e);
    }
    return keys;
  }

  /// **把 Hub 上属于我的背书拉回本地** —— "随人走"缺的另一半。
  ///
  /// 为什么必须有这一步：换机恢复后新机的本地库是**空的**（收到的背书此前只落在
  /// 旧机上）。即使 Hub 已经按换钥链把旧钥名下的背书归并到当前钥，不拉回来，
  /// 护照页照样一片空白 —— 用户的感受仍然是"履历没了"。
  ///
  /// ★ 落库前**逐条本地验签**（[ReputationGraph.verifyEndorsement]，含吊销与过期判定）：
  ///   绝不因为"是 Hub 给的"就免检 —— 那会把这个模块的立身之本丢掉。
  ///   验不过的一律不落库，并留埋点（少一条必须看得见，不能静默）。
  ///
  /// ★★ 另加一道**归属闸**（外部审计 P2③ 修复）：验签只证明"这份签名是真的"，
  ///   **不证明"被背书的人是我"** —— 缺了它，一个被篡改的 / 有 bug 的 Hub 可以回
  ///   一批 `subject_pub = 别人` 的**签名完全合法**的记录，逐条验签全过、于是被
  ///   原样落进我的库。归属由本机自己算（[myIdentityKeys]），**不采信** Hub 的
  ///   `alias.keys`（那只是它的说法）。fail-closed：算不出我的钥 ⇒ 一条都不收。
  ///
  /// 刻意**不走** [ReputationNetworkService.endorse]：那条路带 `onCommit` 上行钩子，
  /// 会把刚从 Hub 拉下来的记录**原样再推回去**（幂等，但纯属白跑一趟网络）。
  ///
  /// 返回**新写入**的条数（本来就在库里的幂等重复不计）。
  Future<int> pullMyReputation() async {
    if (!_ready) return 0;
    try {
      final agentId = await myAgentId();
      final current = await signer.publicKeyBase58();
      final view = await CloudService()
          .fetchReputation(myAgentId: agentId, subjectPub: current);
      if (view == null) return 0;
      // ★★ 归属闸（外部审计 P2③ 修复）：**只有我自己的钥**名下的事件才允许落库。
      //   `mine` 由本机自己算（当前钥 ∪ 本地退休记录 ∪ 本地逐条验过签的换钥链），
      //   **不采信** Hub 回包里的 `alias.keys` —— 那只是 Hub 的说法，属"对照"。
      //   fail-closed：算不出来就一条都不收。
      final mine = await myIdentityKeys();
      if (mine.isEmpty) {
        Telemetry.instance?.track('reputation_pull_skipped',
            props: {'reason': 'no_identity_keys'});
        return 0;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final revokedKeys = await reputationStore.revokedKeys();
      var added = 0;
      for (final e in view.endorsements) {
        // ⚠️ 顺序有讲究：**先归属、再验签**。颠倒过来会浪费一次公钥运算，
        //    更要紧的是：验签通过会让人以为"这条是可信的"，而它可能根本不是我的。
        if (!ReputationGraph.subjectIsMine(e.subjectPub, mine)) {
          Telemetry.instance?.track(ReputationNetworkEvents.endorseRejected,
              props: {
                'subject': e.subjectPub,
                'reason': EndorseCode.notMine,
                'source': 'hub_pull_not_mine',
              });
          continue;
        }
        final v = await ReputationGraph.verifyEndorsement(e,
            nowMs: now, revokedKeys: revokedKeys);
        if (!v.accept) {
          Telemetry.instance?.track(ReputationNetworkEvents.endorseRejected,
              props: {
                'subject': e.subjectPub,
                'reason': v.code,
                'source': 'hub_pull',
              });
          continue;
        }
        final before =
            await reputationStore.endorsement(e.issuerPub, e.subjectPub);
        await reputationStore.upsertEndorsement(e);
        if (before == null) added++;
      }
      for (final r in view.revoked) {
        // 吊销同样要过归属闸：一条指向别人主体的吊销若是伪造得"合法"，
        // 落进我的库只会污染我看到的信誉（它同样不可能是"我"被吊销）。
        if (!ReputationGraph.subjectIsMine(r.subjectPub, mine)) continue;
        final v = await ReputationGraph.verifyRevocation(r);
        if (!v.accept) continue;
        await reputationStore.upsertRevocation(r);
      }
      if (added > 0) {
        Telemetry.instance?.track('reputation_pulled', props: {
          'added': added,
          'alias_status': view.aliasStatus,
          'alias_keys': view.aliasKeys.length,
        });
      }
      return added;
    } catch (e) {
      AppLogger.w('identity.reputation.pull', e);
      return 0;
    }
  }

  /// M10 房间角色 → `POST /api/rooms/roles/commit`。
  ///
  /// 这条比其余四条多两道**结构性**前置，缺一不可：
  /// ① Hub 要求"**授予人本人提交**"（`granter_pub` 必须等于请求发送者的公钥，
  ///    防"替别人授权"）⇒ 只有**我签发的**授予能上行；别人签的推上去
  ///    只会换来 `granter_pub_mismatch`；
  /// ② [RoomRoleService] 造出的 grant **不带公钥也不带签名**（本地判定用不上它们），
  ///    而 Hub 的 `roomRoleVerify` 两者都要 ⇒ 必须先用
  ///    [RoomRoleAuthority.signGrant] 升级；拿不到**被授予人**的公钥时**诚实跳过**
  ///    （用 Agent ID 冒充公钥，等于让"换个 ID 就甩掉历史"重新成立）。
  ///
  /// 跳过一律留埋点 —— 少一条必须能看见，不能静默。
  Future<void> _commitRoomRole(RoomRoleGrant g) async {
    try {
      final myId = await myAgentId();
      if (g.grantedBy != myId) {
        Telemetry.instance?.track(TelemetryEvents.hubPushRejected, props: {
          'endpoint': '/api/rooms/roles/commit',
          'error': 'not_granter',
        });
        return;
      }
      final signed = await RoomRoleAuthority.signGrant(
        g: g,
        agentPub: await _pubOf(g.agentId),
        granterPub: await signer.publicKeyBase58(),
        sign: signer.signBytes,
      );
      if (signed == null) {
        Telemetry.instance?.track(TelemetryEvents.hubPushRejected, props: {
          'endpoint': '/api/rooms/roles/commit',
          'error': 'unknown_agent_pub',
          'agent': g.agentId,
        });
        return;
      }
      await hubWrites.commitRoomRole(signed);
    } catch (e) {
      AppLogger.w('hub.pushRoomRole', e);
    }
  }

  /// 从 DB v31 的**接缝表** `agent_pubkeys` 取某身份的当前公钥。
  ///
  /// 拿不到就返回 `null`（**不猜、不用 ID 冒充**）—— "接不上网络就是接不上"，
  /// 而不是"随便给个值让它看起来接上了"。
  Future<String?> _pubOf(String agentId) async {
    final id = agentId.trim();
    if (id.isEmpty) return null;
    if (id == await myAgentId()) return signer.publicKeyBase58();
    final db = await DBHelper.db;
    final rows = await db.query('agent_pubkeys',
        columns: ['pubkey'], where: 'agent_id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final p = (rows.first['pubkey'] as String?) ?? '';
    return p.isEmpty ? null : p;
  }

  /// **重放待发队列**：把离线期间攒下的公示重发一遍，返回成功条数。
  ///
  /// 幂等由 Hub 侧保证，所以**多调几次是安全的**（启动后、回前台、周期表都调它）。
  ///
  /// ⚠️ 未就绪时返回 0 而**不是**去碰 `hubWrites`：那是个 `late final`，
  /// init 失败时读它会抛 `LateInitializationError` —— 一个"补发失败"不该
  /// 升级成一次崩溃。
  Future<int> flushOutbox({int limit = HubOutboxPolicy.drainBatch}) {
    if (!_ready) return Future.value(0);
    return hubWrites.flushOutbox(limit: limit);
  }

  Timer? _outboxDrainTimer;

  /// 出站队列重放的**唯一启动点**（宿主在 `init()` 成功后调用一次）。
  ///
  /// 在此之前 `flushOutbox` 是**零调用方**的：队列只进不出，攒到
  /// [HubOutboxPolicy.maxQueued] 就开始按设计丢最旧的 ——
  /// 换句话说，"失败自动入队、下次联网重放"这条承诺里，后半句没有实现。
  ///
  /// 三条触发路径（互为补充，任何一条单独都不够）：
  ///   ① 这里——启动即补一次 + 周期表（App 在前台时的主力）；
  ///   ② 回前台补一次（见 `main.dart` 的生命周期观察者）：Android 在后台会
  ///      冻结 Dart 定时器，只靠 ① 的话"切回来"这一刻补不上；
  ///   ③ 入队时即刻发一次（见 `HubWriteService._push`）：这是主路径，
  ///      ①② 只是给"当时真发不出去"兜底。
  Future<void> startOutboxDrainer({
    Duration interval = HubOutboxPolicy.drainInterval,
  }) async {
    if (!_ready) return;
    if (_outboxDrainTimer != null) return;
    // 先立刻补一次：离线期间攒下的记录不该再白等一个周期。
    await flushOutbox();
    _outboxDrainTimer = Timer.periodic(interval, (_) {
      unawaited(flushOutbox());
    });
  }

  /// 停表（退出/测试用）。`flushOutbox` 自身有 `_flushing` 互斥，重复启动不并发。
  void stopOutboxDrainer() {
    _outboxDrainTimer?.cancel();
    _outboxDrainTimer = null;
  }

  // ------------------------------------------------------------------
  // M6 护照：履历 + 漏斗（口径只在 core 定义，UI 不得自己算）
  // ------------------------------------------------------------------

  /// 我的互介履历（**逐条附离线验证结论**）。
  ///
  /// 返回的是 `(记录, 验证结论)` 对而不是原始记录：UI 若直接显示记录里的
  /// `outcome` 字段，等于信任"自称" —— 而 M6 的全部价值恰恰在于不信任自称。
  Future<List<(IntroAttestation, IntroVerifyResult)>> myIntros(
          {int? limit}) =>
      attestations.myVerifiedLedger(limit: limit);

  /// 我的互介漏斗（分子分母只统计**验过双方同意**的记录）。
  Future<IntroFunnel> myIntroFunnel() => attestations.myFunnel();

  // ------------------------------------------------------------------
  // M10 五件套：口径只在这里定义（UI 不得自己算声望分）
  // ------------------------------------------------------------------

  /// 我的身份根（Ed25519 公钥，base58）。
  ///
  /// ⚠️ 五件套一律以**公钥**为主体，而不是 Agent ID：ID 是平台发的名字，可被换绑。
  /// 用 ID 做主体的话，"换一次 ID"就能甩掉全部贡献记录与权益 ——
  /// 这正是 M6 拒绝用 ID 做背书主体的同一条理由。
  Future<String> myPub() => signer.publicKeyBase58();

  /// ③ 我的贡献声望（**派生值**：从已落库的已签名记录现算，不读任何缓存分）。
  ///
  /// UI **不得**自己累加：去重规则与按类型封顶只在 [ContributionLedger.tally]
  /// 定义，散落多处必然漂移 —— 而"我的分是多少"是不容许两种答案的问题。
  Future<ContributionScore> myContributionScore() async =>
      contributions.scoreOf(await myPub());

  /// ① 我是否创始成员（依据是**本人签过的那份承诺**，不是某个平台发的标记）。
  Future<bool> amIFoundingMember() async =>
      contributions.isFounding(await myPub());

  /// ② 我持有的全部定价权（按作用域各一份，**不可叠加**）。
  Future<List<PriceLockClaim>> myPriceLocks() async =>
      contributionStore.priceLocksOf(await myPub());

  /// ⑤ **自检**：我这本贡献账现在能不能被第三方验过（fail-closed）。
  ///
  /// 任一条验不过即整本判定为"不可出示"，并给出第一条出问题的下标 ——
  /// 宁可说"这本账现在不能出示"，也不能让 UI 静默少算。
  Future<({bool ok, int badIndex, String code})>
      verifyMyContributionLedger() async {
    final pub = await myPub();
    return ContributionLedger.verifyLedger(
        await contributionStore.recordsOf(pub));
  }

  /// ⑤ 我已经进过公开日志的**贡献叶子哈希**列表（第三方验包含证明的输入）。
  ///
  /// 它与 [TransparencyLog] 的叶子是**同一份**（合流，不是两份账）。
  Future<List<String>> myContributionLeafHashes() async {
    final rows = await contributionStore.recordsOf(await myPub());
    final out = <String>[];
    for (final r in rows) {
      out.add(await TransparencyLog.leafHashOf(r.logLeafBytes()));
    }
    return out;
  }

  // ------------------------------------------------------------------
  // M5 跨圈桥的两个口径（只在这里定义，散落多处必然漂移）
  // ------------------------------------------------------------------

  /// 我所有圈的成员（去重、**不含自己**）。
  Future<Set<String>> circlePeers(String selfId) async {
    final out = <String>{};
    for (final cid in await circleStore.myCircles(selfId)) {
      for (final m in await circleStore.membersOf(cid)) {
        if (m.memberId != selfId) out.add(m.memberId);
      }
    }
    return out;
  }

  /// 我已连接过的人 = 跨圈边 ∪ 互介收发 ∪ 通讯录。
  ///
  /// 这个集合决定"**原本不认识**"的判断：宁可判严（少建几条边），
  /// 也不能把熟人算成新边 —— 那会让 M5 验收的"原本不认识"变成假命题。
  /// 注意：世界房间的消息**不会**写 `agent_friends`（只有真实发现/握手才写），
  /// 所以房间里的陌生人不会被这张表误伤。
  Future<Set<String>> knownPeers(String selfId) async {
    final out = <String>{};
    for (final l in await bridgeLinks.linksOf(selfId)) {
      out.add(l.peerId);
    }
    for (final c in await interCardStore.inbox(selfId)) {
      out.add(c.ownerId);
    }
    for (final c in await interCardStore.mine(selfId)) {
      out.add(c.toId);
    }
    final db = await DBHelper.db;
    final friends =
        await db.query('agent_friends', columns: ['agent_id']);
    for (final r in friends) {
      final id = (r['agent_id'] as String?) ?? '';
      if (id.isNotEmpty) out.add(id);
    }
    out.remove(selfId);
    return out;
  }

  /// 我的"主圈"（互介卡的 circleId 出处）：我参与时间线里最新的一个圈。
  ///
  /// M5 之后互介卡**不再硬编码 'direct'** —— 每张卡都必须挂在"我的某个圈"上，
  /// 否则卡没有归属，撤回与追溯都失去锚点。没有圈时返回 null（调用方提示入场进圈）。
  Future<({String id, String name})?> primaryCircle(String selfId) async {
    final rows = await circleStore.circlesOf(selfId);
    if (rows.isEmpty) return null;
    final id = (rows.first['circle_id'] ?? '').toString();
    if (id.isEmpty) return null;
    return (id: id, name: (rows.first['name'] ?? id).toString());
  }

  /// 组装 M5 判定的完整输入。事实全部来自本地库，判定本身是纯函数
  /// （见 `world_bridge_service.dart`，可离线复算）。
  Future<WorldBridgeInput> bridgeInput(String selfId, {int? nowMs}) async {
    return WorldBridgeInput(
      selfId: selfId,
      presences: await roomPresences.presences(selfId),
      circleMembers: await circlePeers(selfId),
      linkedPeers: await knownPeers(selfId),
      links: await bridgeLinks.linksOf(selfId),
      nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
