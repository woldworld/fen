import 'dart:developer' as dev;
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_events.dart';

class DBHelper {
  static Database? _db;

  /// 档案/技能/关系等数据变更时自增，供 Prompt 缓存失效判断
  static int dataRevision = 0;

  /// 当前 schema 版本。**必须等于 `_migrations` 的最大键** ——
  /// 这两者一旦不一致，新装库就会少建表（历史缺陷：`onCreate` 里写死了
  /// `15..19`，导致 v20 的 `circles` 表在全新安装时根本不会被创建，
  /// 而老库升级路径却是对的，所以只在"新用户"身上炸）。
  /// `tool/verify_attestation_persistence.dart` 有一条断言专门盯着这个等式。
  static const int schemaVersion = 40;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'pocket_agent.db');
    return await openDatabase(
      path,
      version: schemaVersion,
      // 全新装 / 老库升级 / 离线验证脚本三条路径**共用同一份**迁移逻辑。
      // 分开实现必然漂移 —— 上面那个历史缺陷就是这么来的。
      onCreate: (Database db, int version) =>
          migrate(db, from: 0, to: version),
      onUpgrade: (Database db, int oldVersion, int newVersion) =>
          migrate(db, from: oldVersion, to: newVersion),
      // 降级（库版本 > 代码版本）：装回旧版包时会发生。
      //
      // ⚠️ 先纠正一个常见误解：**不传 onDowngrade 并不会崩**。
      // 已核 sqflite_common 2.5.9 `src/database_mixin.dart` 1156–1172 行：
      //   版本更低时只是 `if (options.onDowngrade != null) {...}` 被跳过，
      //   紧接着 `setVersion(options.version)` **把版本号改小**后继续开库。
      // 也就是说默认行为是"静默降版本、保留多余结构"，而不是"打不开"。
      //
      // 那为什么还要处理它？因为这个事件**无声**。降级往往意味着用户装回了
      // 旧包（错过更新、或从备份恢复），是需要知道的事实；而"版本号被改小"
      // 这件事唯一的风险在**将来再次升级**那一步 —— 迁移函数会被重跑一遍。
      //
      // 而重跑是安全的，这正是本文件的一条既有纪律（下面每条迁移都遵守）：
      //   · 建表/建索引一律 `IF NOT EXISTS`；
      //   · 加列一律先过 `_columnExists` 守卫（见 v16/v17/v18）；
      //   · 播种一律 `ConflictAlgorithm.ignore`。
      // 所以降级→再升级会重新收敛，不需要在这里做任何结构动作。
      //
      // ⛔ 明确**不**做"清库重建"（sqflite 的 `onDatabaseDowngradeDelete`）：
      //    那是不可逆的数据丢失，而且用户没有选择余地（App 不会问他）。
      //
      // ⛔ 这里**不能**用 AppLogger：它落盘会调 `DBHelper.db`，而此刻 `_db`
      //    尚未赋值（我们正在它的初始化回调里）→ 会再开一次同一个库 →
      //    再触发 onDowngrade → 无限递归。日志是"库已就绪"的下游，
      //    不能在开库回调里使用。故用 dart:developer（纯 Dart、零依赖）。
      onDowngrade: (Database db, int oldVersion, int newVersion) async {
        dev.log(
          'schema downgrade: db=$oldVersion > code=$newVersion, '
          'keep schema as-is (all migrations are re-run safe)',
          name: 'db.downgrade',
          level: 900, // WARNING
        );
      },
      // 每次开库都把内置工具描述收敛到当前版本（幂等）—— 覆盖"已是最新版、
      // onCreate / onUpgrade 都不触发"这条路径（老用户库里的播种行不会更新）。
      onOpen: (Database db) => healBuiltinToolDescriptions(db),
    );
  }

  /// 建库/升级的**唯一实现**。`from == 0` 视为全新安装（先建表播种，再跑增量）。
  ///
  /// 公开而非私有，是为了让 `tool/verify_db_migration.dart` 用**真实 SQLite 引擎**
  /// （`sqflite_common_ffi`）跑一遍**同一份**迁移链。
  /// 如果另写一份"给测试用的"迁移，那测的就不是生产路径了 —— 而迁移恰恰是
  /// 那种"测试全绿、新用户全炸"的地方。
  static Future<void> migrate(Database db,
      {required int from, required int to}) async {
    if (from == 0) await _createTablesAndSeed(db);
    for (final v in _migrations.keys.toList()..sort()) {
      if (v <= from) continue;
      if (v > to) break;
      await _migrations[v]!(db);
    }
    // 迁移尾部：把内置工具描述收敛到当前版本（幂等）。刻意放在版本循环**之外**，
    // 使"全新安装"与"升级"两条路径都执行；而"已是最新版、onCreate/onUpgrade
    // 都不触发"的第三条路径，由 `_initDB` 的 `onOpen` 覆盖。
    await healBuiltinToolDescriptions(db);
  }

  // ------------------------------------------------------------------
  // 内置工具描述：代码是唯一事实源，开库时向库收敛（0.78.0）
  // ------------------------------------------------------------------
  // 为什么需要"每次开库收敛"，而不是只改 `_createTablesAndSeed` 的播种语句：
  //   播种走 `ConflictAlgorithm.ignore` ⇒ **只在全新安装时写入**，老用户库里那行
  //   描述**永远不会更新**（0.70.0 已踩过同一坑）。而工具描述是给**模型**看的
  //   能力说明：库里陈旧 = 模型不知道新能力 ⇒ 能力在真实使用中等价于不存在。
  //   ⇒ ① 播种与收敛共用本常量（单一事实源）；② `migrate()` 尾部收敛（新装+升级）；
  //     ③ `_initDB` 的 `onOpen` 收敛（"已是最新版、onCreate/onUpgrade 都不触发"）。
  static const String _searchMemoryToolDescription =
      '检索历史记忆（主人对话 / 社交分身私聊 / 会客厅 / 情景记忆）。'
      '通常传普通关键词；若传入 memory://<命名空间>/<行号> 形式的记忆地址'
      '（命名空间为 chat / social / episode），则按地址精确取回该条记忆的全文。';

  /// 把内置工具的描述收敛到当前版本（幂等，可重复调用）。
  ///
  /// ★ 只 `UPDATE` 描述列、且**仅当与目标值不同才写**：
  ///   · 不动 `is_enabled` —— 用户可能主动关过该工具，覆盖它=替用户做决定
  ///     （`ConflictAlgorithm.replace` 会整行覆盖，正是那个错）；
  ///   · 用户若删除过该工具，`UPDATE` 命中 0 行、**不复活**它。
  static Future<void> healBuiltinToolDescriptions(Database db) async {
    await db.rawUpdate(
      'UPDATE tools SET description = ? '
      "WHERE name = 'search_historical_memory' AND description <> ?",
      [_searchMemoryToolDescription, _searchMemoryToolDescription],
    );
  }

  // ------------------------------------------------------------------
  // 仅供离线验证脚本使用的测试缝（生产代码不得调用）
  // ------------------------------------------------------------------

  /// 把一条**已打开的真库**接到 [db] 上，让所有 `Db*Store` 在纯 Dart 环境
  /// （无平台通道）下也能跑真实 SQL。
  ///
  /// 为什么需要它：`sqflite` 的 `getDatabasesPath()` 走 MethodChannel，
  /// `dart run` 里根本没有平台侧实现。没有这个缝，离线就只能"照抄一份 SQL"，
  /// 而那测的是我抄得对不对，不是代码写得对不对。
  static void attachDbForTest(Database db) => _db = db;

  /// 断开测试库并复位（避免影响同一进程内后续用例）。
  static void detachDbForTest() {
    _db = null;
    dataRevision = 0;
  }

  // ------------------------------------------------------------------
  // 迁移框架：每个版本一个增量迁移函数，禁止再出现"只 CREATE IF NOT EXISTS"
  // ------------------------------------------------------------------
  static const Map<int, Future<void> Function(Database)> _migrations = {
    15: _migrateV15,
    16: _migrateV16,
    17: _migrateV17,
    18: _migrateV18,
    19: _migrateV19,
    20: _migrateV20,
    21: _migrateV21,
    22: _migrateV22,
    23: _migrateV23,
    24: _migrateV24,
    25: _migrateV25,
    26: _migrateV26,
    27: _migrateV27,
    28: _migrateV28,
    29: _migrateV29,
    30: _migrateV30,
    31: _migrateV31,
    32: _migrateV32,
    33: _migrateV33,
    34: _migrateV34,
    35: _migrateV35,
    36: _migrateV36,
    37: _migrateV37,
    38: _migrateV38,
    39: _migrateV39,
    40: _migrateV40,
  };

  /// M10 **五件套**（PRD §4 M10）：① 创始成员 ② 永久价格锁定 ③ 贡献声望 ⑤ 可验证贡献账本。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么这三张表**故意没有** `owner_id` / `to_pub` / `price_cents` / `redeem_at`
  /// ---------------------------------------------------------------------------
  /// PRD §4 M10 红线原文：
  /// > 以上五项**都不得演化为可转让、可兑现、可与利润挂钩的凭证**。
  /// > 一旦出现"可变现"，就从"权益"变成"证券"，本条全部作废。
  ///
  /// 所以红线在这里**不是文档约定，是结构约束**：
  /// ① 三张表里没有任何一列表达"转让 / 兑现 / 收益"；
  /// ② 没有任何一列指向"下一个持有人"；
  /// ③ `contribution_records` **只追加**（PK 即幂等键，无 UPDATE 语义）——
  ///    贡献是历史事实，发生了就是发生了。
  /// 想加转让，必须先改这张表 —— 而改表是显式的、可被 review 抓住的动作，
  /// 这正是我们要的："想违规得先动结构"。
  ///
  /// 三张表的主键即各自的不变式：
  /// - `contribution_records` PK `(kind, subject_pub, ref)`：
  ///   同一件事（同类型、同主体、同引用对象）**只可能有一条** ——
  ///   把一件事记十遍在存储层写不进去。`ref` 对 `founding` 恒为 `''`，
  ///   于是"一个人一辈子只有一条创始记录"也由同一个主键兜住。
  /// - `founding_members` PK `subject_pub`：一主体只有一份创始声明；
  ///   签名覆盖 `pledge` 标识 → 该声明绑定的是**哪一版承诺**可判定、可追责。
  /// - `price_lock_claims` PK `(scope, subject_pub)`：一个作用域上一个人只有一份
  ///   定价权（重复发放是覆盖而非叠加，**叠加不出双倍折扣**）。
  ///
  /// ⚠️ 主体是**公钥**而不是 Agent ID：ID 可被重发/换绑，公钥才是身份根
  /// （与 v30 背书的理由一致 —— 换一次 ID 就能甩掉全部记录）。
  /// ⚠️ 声望分**不落库**：它是 `ContributionLedger.tally` 从记录现算的**派生值**。
  /// 派生 + 只读 = 无处转让；一旦落库成一张可写的"余额表"，
  /// 它立刻就会长出转账接口 —— 那正是红线被踩的方式。
  static Future<void> _migrateV32(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contribution_records(
        kind TEXT NOT NULL,
        subject_pub TEXT NOT NULL,
        ref TEXT NOT NULL DEFAULT '',
        attestor_pub TEXT NOT NULL,
        weight INTEGER NOT NULL,
        at_ms INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        sig TEXT NOT NULL,
        PRIMARY KEY(kind, subject_pub, ref)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_contribution_subject ON contribution_records(subject_pub, at_ms)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_contribution_attestor ON contribution_records(attestor_pub)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS founding_members(
        subject_pub TEXT PRIMARY KEY,
        pledge TEXT NOT NULL,
        at_ms INTEGER NOT NULL,
        sig TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS price_lock_claims(
        scope TEXT NOT NULL,
        subject_pub TEXT NOT NULL,
        issuer_pub TEXT NOT NULL,
        discount_bps INTEGER NOT NULL DEFAULT 0,
        fee_waived INTEGER NOT NULL DEFAULT 0,
        effective_from INTEGER NOT NULL,
        permanent INTEGER NOT NULL DEFAULT 1,
        sig TEXT NOT NULL,
        PRIMARY KEY(scope, subject_pub)
      )
    ''');
  }

  /// M8 试用额度代调（PRD §4 M8 / §9.1 红线）：**落库额度 + 消费账本**。
  ///
  /// 为什么必须建这两张表（而不是沿用内存计数）：
  /// PRD §9.1 把「**额度极小 + 限用途**」列为代调风险的**缓释措施** ——
  /// 代调会让我们从"传话人"变成"内容生产者"，中/欧/美三法域责任落到我们头上。
  /// 改造前 `SocialBudget` 是纯内存计数，**App 重启即归零**，
  /// 那样"20 条/天"可以靠重启刷穿 —— 缓释措施形同虚设。
  /// 所以额度必须落库，这是**合规约束的物理形式**，不是性能优化。
  ///
  /// 主键即不变式：
  /// - `trial_quotas` PK `(agent_id, purpose)`：一身份一用途只有一份额度，
  ///   重复发放是 UPDATE 而非 INSERT（不会叠加出双倍敞口）。
  /// - `trial_usage` PK `call_id`：同一次调用只落一条，重复记账不会重复扣额度。
  static Future<void> _migrateV29(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trial_quotas(
        agent_id TEXT NOT NULL,
        purpose TEXT NOT NULL,
        granted_turns INTEGER NOT NULL DEFAULT 0,
        used_turns INTEGER NOT NULL DEFAULT 0,
        budget_cents INTEGER NOT NULL DEFAULT 0,
        spent_cents INTEGER NOT NULL DEFAULT 0,
        granted_at INTEGER NOT NULL,
        expires_at INTEGER,
        revoked_at INTEGER,
        PRIMARY KEY(agent_id, purpose)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trial_usage(
        call_id TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL,
        purpose TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL DEFAULT '',
        prompt_tokens INTEGER NOT NULL DEFAULT 0,
        completion_tokens INTEGER NOT NULL DEFAULT 0,
        cost_cents INTEGER NOT NULL DEFAULT 0,
        at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_trial_usage_agent ON trial_usage(agent_id, at_ms)');
  }

  /// M6 网络级信誉（PRD §4 M6）：**签名背书 + 背书吊销**。
  ///
  /// 为什么必须落库：背书是**信誉资产**。只存内存的话 App 重启即失，
  /// "我背书过谁、谁背书过我"这些证据会静默消失 ——
  /// 而网络信誉的全部价值就在于这些证据**可复算、可出示**。
  ///
  /// 主键即不变式：
  /// - `endorsements` PK `(issuer_pub, subject_pub)`：一人对另一人**只有一份**
  ///   当前背书，重复签发是 UPDATE 而不是 INSERT ——
  ///   **叠加不出第二份背书**（叠加 = 变相放大边权 = 刷分）。
  /// - `endorsement_revoked` PK `(issuer_pub, subject_pub)`：吊销亦幂等。
  ///
  /// 主体是**公钥**而不是 Agent ID：ID 可被重发/换绑，公钥才是身份根 ——
  /// 换一次 ID 就能甩掉全部差评的"信誉洗白"，在这里写不进去。
  static Future<void> _migrateV30(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS endorsements(
        issuer_pub TEXT NOT NULL,
        subject_pub TEXT NOT NULL,
        tier TEXT NOT NULL,
        issued_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        sig TEXT NOT NULL,
        PRIMARY KEY(issuer_pub, subject_pub)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS endorsement_revoked(
        issuer_pub TEXT NOT NULL,
        subject_pub TEXT NOT NULL,
        at_ms INTEGER NOT NULL,
        sig TEXT NOT NULL,
        PRIMARY KEY(issuer_pub, subject_pub)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_endorsements_subject ON endorsements(subject_pub)');
  }

  /// **App → Hub 上行待发队列**（`hub_outbox.dart` / `hub_write_service.dart`）。
  ///
  /// 为什么要落库而不是放内存：需要它成立的情形恰好就是"App 要被关掉"的情形。
  /// 离线攒下的记录必须在**下次启动**时还在，否则"离线也不丢"就是假的。
  ///
  /// ⚠️ 表里存的是**已签名的域对象**（`payload`），**不是**签名信封：
  /// 协议包 `envelope.TS_WINDOW_SECONDS = 300`（±5 分钟防重放），
  /// 信封落盘几分钟后重放必被 `bad_timestamp` 拒 —— 那会变成"攒了一堆永远
  /// 发不出去的废信封"。信封每次发送时现构。
  ///
  /// 刻意**没有** `status` / `sent_at` 列：语义只有"在队列里 = 还没公示出去"，
  /// 成功即 DELETE。多一个可长期停留的中间态，就会让"到底哪些还没公布"
  /// 失去唯一答案 —— 而那个答案正是 §16「你可以验我」能不能被回答的前提。
  ///
  /// `next_at_ms` 是退避后的最早可重试时刻（见 `HubOutboxPolicy.retryDelayMs`）；
  /// 取用排序为 `id ASC`，即**按入队顺序发送** —— 房间角色的权威名册在 Hub 侧是
  /// **重放派生**的，乱序发会让合法的授予被 `not_host` 误拒。
  static Future<void> _migrateV33(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hub_outbox(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        payload TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_at_ms INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        last_error TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_hub_outbox_due ON hub_outbox(next_at_ms, id)');
  }

  /// 换钥账本（PRD §9.1「可导出」与"身份随人不随设备"的落点）。
  ///
  /// 为什么必须有一张**本地**账本：换钥是身份历史上**最重要的一次事件**
  /// （它决定了"这个 DID 在某个时刻换过钥、旧钥从此失效"）。如果只把它记在
  /// Hub 上，那么**没联网 / 没配 Hub 的用户**就完全没有记录 ——
  /// 而恰恰是这类用户，事后最需要说清"我这把钥是什么时候、换成什么的"。
  ///
  /// 主键 `(agent_id, old_pub)` **就是不变式**：一把旧钥对同一个身份
  /// **只能被退休一次**。于是"重放同一条换钥声明造出第二条记录"在存储层
  /// 就写不进去 —— 与 `agent_pubkeys`（一个身份只有一把当前钥）、
  /// `contribution_records`（同一件事只有一条）是同一种做法：
  /// **想违规得先动结构。**
  ///
  /// ⚠️ 刻意**没有**任何 `transfer` / `redeem` / `to_pub_owner` 一类列：
  /// 本表只回答"哪把钥退休了、谁接的班、什么时候"，不表达"身份归谁"。
  /// 那正是 §9.1 红线要挡的形态（可迁移 ≠ 可转让）。
  ///
  /// `confirmed_by`：`hub` = 服务端已确认改绑（旧设备**已经**失效）；
  /// `local` = 本机记录（未配 Hub 或当时离线）。它是**事实描述**，不是状态机 ——
  /// 一行写进去就不再改写。
  static Future<void> _migrateV34(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS key_rotations(
        agent_id TEXT NOT NULL,
        old_pub TEXT NOT NULL,
        new_pub TEXT NOT NULL,
        rotated_at INTEGER NOT NULL,
        sig TEXT NOT NULL,
        recorded_at INTEGER NOT NULL,
        confirmed_by TEXT NOT NULL DEFAULT 'local',
        PRIMARY KEY (agent_id, old_pub)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_key_rotations_agent ON key_rotations(agent_id, rotated_at)');
  }

  /// 私聊（社交分身）**对话压缩**：按 peer 的滚动摘要（0.44.0）。
  ///
  /// 为什么必须落库：私聊上下文此前是 **12k 字符硬裁**（`_getRecentChatContext`
  /// 只喂最近 N 条对话）—— 更早的对话一旦被裁掉就**永远回不来**，于是"分身天生
  /// 比总管笨一档"（评审 §二 P2）。压缩把"更早那一段"折叠成一段摘要、挂在 peer 上；
  /// 下一轮把**摘要 + 最近原文**一起喂给分身 ⇒ 分身记得更早聊过什么。
  ///
  /// `covered_until_id` 是**游标**：`social_logs.id` 单调且唯一，表示"这行摘要
  /// 已覆盖该 peer 直到此 id（含）为止的全部对话"。它让"哪一段已进摘要、哪一段
  /// 还是原文"可判定 —— 没有它，每轮都要重新摘要或无从知道还差哪一段。
  /// （用 id 而不是时间戳：同一毫秒并发多条时，按时间戳切会把"保留段"一起划走。）
  ///
  /// 主键 `peer_id` 即**一个 peer 一份滚动摘要**（重复摘要是 UPDATE，不叠加）。
  /// ⚠️ 刻意**没有**任何"评分 / 权重 / 计数"列：这是**记忆**，不是信誉资产。
  static Future<void> _migrateV35(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS peer_summaries(
        peer_id TEXT PRIMARY KEY,
        summary TEXT NOT NULL DEFAULT '',
        covered_until_id INTEGER NOT NULL DEFAULT 0,
        updated_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// 会客厅（世界房间）**对话压缩**：按房间的滚动摘要（0.45.0）。
  ///
  /// 与私聊 `peer_summaries`（0.44.0）**同一形态、不同维度**：
  /// 私聊按 **peer** 攒一份，会客厅按 **房间** 攒一份（主键 `room_id`）。
  ///
  /// 为什么房间也需要：房间历史有两道 100 条上限 —— 服务端 `ROOM_HISTORY_MAX`
  /// 与客户端 `WorldService._roomCache`（各留最近 100 条）。**掉出这 100 条窗口的
  /// 房间往事，在 0.45.0 之前就是彻底消失**（托管分身记不起"这个房间早先聊过什么"）。
  /// 滚动摘要把它折叠成一段挂在房间上 ⇒ 下一轮「摘要 + 最近原文」一起喂。
  ///
  /// `covered_until_id` 用房间消息的 **`id`**（服务端单调且唯一）而不是时间戳 ——
  /// 理由同 `peer_summaries`：同一毫秒并发多条时，按时间戳切会重复或漏切。
  ///
  /// 主键 `room_id` 即**一个房间一份滚动摘要**（重复摘要是 UPDATE，不叠加）。
  /// ⚠️ 与 `peer_summaries` 同款：刻意**没有**任何"评分 / 权重 / 计数"列 ——
  /// 这是**记忆**，不是信誉资产。
  static Future<void> _migrateV36(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS room_summaries(
        room_id TEXT PRIMARY KEY,
        summary TEXT NOT NULL DEFAULT '',
        covered_until_id INTEGER NOT NULL DEFAULT 0,
        updated_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// 邮箱账号三张表（0.64.0）。
  ///
  /// 为什么是"三张、且都长这样"——它们各自钉一个**结构约束**：
  ///
  /// - `mail_accounts`：**没有任何凭据列**。口令只在本机凭据存储里
  ///   （`mail_credential_store.dart`）。一旦这里出现 `password` / `token` / `secret`
  ///   列，"凭据不落库"这条纪律就当场作废 —— 所以**不建这些列**，
  ///   想违规得先改表结构（可被 review 抓住）。
  /// - `mail_seen`：已读游标。没有它，同一个 UID 会被反复喂给模型（既烧 token，
  ///   又让"这封信我已经看过了"这件事在记忆里失真）。
  /// - `mail_outbox`：出站台账。**只存收件人/主题/前 256 字预览**，不存正文全文
  ///   —— 与审计脱敏同一条纪律（正文不进任何持久化的日志面）。
  ///
  /// ★ 与 PRD §9.1 的关系：邮箱是**主人自有资产**。三张表**不得**出现
  /// `transfer*` / `redeem*` / `payout*` / `sell*` / `owner_id` 这类列
  /// （即"邮箱/收件箱可转让、可兑现、可挂钩收益"）。由
  /// `tool/verify_mail_tools.dart` 静态钉住。
  static Future<void> _migrateV37(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mail_accounts(
        id TEXT PRIMARY KEY,
        address TEXT NOT NULL,
        display_name TEXT NOT NULL DEFAULT '',
        imap_host TEXT NOT NULL,
        imap_port INTEGER NOT NULL DEFAULT 993,
        smtp_host TEXT NOT NULL,
        smtp_port INTEGER NOT NULL DEFAULT 465,
        security TEXT NOT NULL DEFAULT 'tls',
        enabled INTEGER NOT NULL DEFAULT 1,
        last_ok_at INTEGER,
        last_error TEXT,
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mail_seen(
        account_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        seen_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (account_id, uid)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mail_outbox(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        to_addrs TEXT NOT NULL DEFAULT '',
        subject TEXT NOT NULL DEFAULT '',
        preview TEXT NOT NULL DEFAULT '',
        error TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        sent_at INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mail_outbox_account ON mail_outbox(account_id, id)');
  }

  /// W1（0.70.0）提醒/待办 + 记忆管理：
  ///
  /// ① `reminders` 表 —— 提醒与待办共用一张表（[ReminderService] 是唯一写入方）：
  ///    `due_at` 为 NULL = 纯待办（没有时刻，只有"这件事"）；非 NULL = 定时提醒。
  ///    `repeat_rule` 首版只有 null / 'daily' / 'weekly'——触发后由服务推进到
  ///    下一周期，而不是标记完成。
  ///    `notified_at` 是**补发去重标记**：Workmanager 心跳最短 15 分钟一轮，
  ///    同一条到期提醒可能被连续两轮心跳看到，靠它保证只弹一次
  ///    （与晨间问候的 `morning_greeted_date` 同一语义，但事实源在 DB 而非 prefs
  ///    ——提醒是业务数据，不该散落进 SharedPreferences）。
  /// ② `session_events` 加 `deleted_at` 软删列 —— 记忆管理的"删除"是**主人意志**：
  ///    画像聚合 / 对话统计 / 轨迹回放**全部**必须排除已删行，否则"删了却还在
  ///    喂模型/进画像"= 静默不符预期（比不做删除更伤信任，0.69.0 R14 同款教训）。
  ///    首选软删而非硬删的理由：session_events 是喂模型的多轮轨迹（append-only，
  ///    自增 id 即游标），硬删会打断游标语义且不可恢复；软删保留回滚余地。
  ///    ⚠️ 加列必须过 `_columnExists` 守卫（v16/v17/v18 同款）——降级→再升级时
  ///    迁移会重跑，裸 ALTER 会因列已存在而炸。
  static Future<void> _migrateV38(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        due_at INTEGER,
        repeat_rule TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_by TEXT NOT NULL DEFAULT 'user',
        notified_at INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_due ON reminders(due_at)');
    if (!await _columnExists(db, 'session_events', 'deleted_at')) {
      await db.execute(
          'ALTER TABLE session_events ADD COLUMN deleted_at INTEGER');
    }
  }

  /// 0.89.0 联邦名册**自动收录**的归属标记：
  ///
  /// `agent_friends.auto_pulled` —— 取值只有 0/1，表达一条记录是
  /// **机器自己拉进来的**（1）还是**主人自己收录的**（0）。
  ///
  /// 为什么用**数据库列**而不是界面上的一行文字或 `notes` 前缀：
  /// ① 它是"这条记录归谁"的**事实**，要被"清空联邦自动收录"按钮当判据用 ——
  ///    判据必须是**机器可判**的；拿显示文案当键，一换语言/一改文案就永久失效
  ///    （0.69.0 R14 / 0.78.0 同款教训：能力降级必须显形、状态不许靠文案）。
  /// ② `notes` 已被**手动收录**那条路径占用（存放主人的备注），不能再借。
  ///
  /// ★ 与 PRD §9.1「名册主权」的关系：拉取名册这一动作本身是可逆的（不发出任何
  ///   对外消息），但"名册里凭空多了一批人"是主人的资产被改写。所以自动收录的
  ///   行必须**可一键撤回**，而可撤回的前提就是**能把它认出来** —— 这一列即认领牌。
  ///
  /// ⚠️ 加列必须过 `_columnExists` 守卫（v16/v17/v18 同款）——降级→再升级时迁移
  ///    会重跑，裸 ALTER 会因列已存在而炸。
  static Future<void> _migrateV39(Database db) async {
    if (!await _columnExists(db, 'agent_friends', 'auto_pulled')) {
      await db.execute(
          'ALTER TABLE agent_friends ADD COLUMN auto_pulled INTEGER DEFAULT 0');
    }
  }

  /// 主人画像卡（0.106.0）：主人**自述**的长期事实（职业 / 偏好 / 目标 / 习惯 / 约束）。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么这张表**不违反** R8「派生值不落库」
  /// ---------------------------------------------------------------------------
  /// R8 禁的是"同一份事实有第二个可写副本"。而"主人是结构工程师"这类信息
  /// **不是任何历史数据的函数** —— 它无论如何也重算不出来，只有一份，
  /// 没有第二副本可漂移。与之对照：`UserProfileStore`（常关注话题 / 常在时段）
  /// 是 `session_events` 的聚合派生值，重算即得 ⇒ 那张表**至今没有建**，
  /// `verify_user_profile.dart` 有一条断言盯着它。
  ///
  /// ---------------------------------------------------------------------------
  /// 为什么用一张表 + `superseded` 留痕，而不是"原地改"或"另开历史表"
  /// ---------------------------------------------------------------------------
  /// · **不改原行**：需求原文要求"保留更新时间与来源依据"。原地改会让画像
  ///   只剩"现在"、没有来路，主人无法判断它凭什么这么说 ⇒ 旧卡置
  ///   `superseded` 并记 `superseded_by`，形成可回溯链。
  /// · **不另开历史表**：那会让"当前值"和"历史值"成为两份都要维护的事实，
  ///   正是 R8 要防的形态。同表 + 状态列 = 一个事实源，查询时按 status 分流。
  ///
  /// ---------------------------------------------------------------------------
  /// 主键与不变式
  /// ---------------------------------------------------------------------------
  /// `slot`（槽位）是冲突判定的键，但**不是主键** —— 因为同一 slot 会有历史行。
  /// 不变式由**代码**保证：`ProfileCardStore.upsert` 在同一个事务里把旧卡置
  /// `superseded` 再插新卡 ⇒ "一个 slot 至多一张非 superseded 卡"。
  /// 之所以不写成 SQL 唯一索引：SQLite 的部分索引需要 `WHERE` 子句，
  /// 而"非 superseded"是个**状态语义**，用代码表达比用索引表达更不容易随
  /// 状态枚举扩张而失准（将来加状态不用改索引）。
  static Future<void> _migrateV40(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS owner_profile_cards(
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        slot TEXT NOT NULL,
        statement TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.5,
        status TEXT NOT NULL DEFAULT 'active',
        source TEXT NOT NULL,
        evidence TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        supersedes_id TEXT,
        superseded_by TEXT
      )
    ''');
    // 两个查询形态各配一条索引：① 按 slot 找当前卡（upsert 的热路径）；
    // ② 按 status 列生效卡（每轮对话注入都要跑）。
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_profile_cards_slot ON owner_profile_cards(slot)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_profile_cards_status ON owner_profile_cards(status)');
  }

  /// M6 网络信誉的**接缝表**：身份（`agent_id`）↔ 身份根（`pubkey`）。
  ///
  /// 为什么必须有这张表：
  /// 本地主观信誉（`reputation_service`）按 **agent_id** 索引，
  /// 网络信誉（`reputation_network`）按 **公钥** 索引（公钥才是身份根）。
  /// 没有这张表，两者接不上 —— 于是"从我的名册出发做信任传播"在 UI 上根本无从下手，
  /// 网络背书就成了永远空着的一张表。
  ///
  /// 主键即不变式：**一个身份只有一个当前公钥**（重复绑定是 UPDATE，不是 INSERT）。
  /// 这条不是性能优化 —— 它允许"换密钥"（一个人可以重新绑定），
  /// 但**不允许一个人同时挂多个公钥**：那正是 Sybil 的形态之一
  /// （一个人开 N 把钥匙，就能在自己的背书网络里放大 N 倍）。
  ///
  /// ⚠️ Android 10 自带 SQLite 3.22 **支持** `ALTER TABLE ... ADD COLUMN`，
  /// 但本项目迁移纪律是只建新表（老表结构不动），故用独立表而不是加列。
  static Future<void> _migrateV31(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS agent_pubkeys(
        agent_id TEXT PRIMARY KEY,
        pubkey TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT '',
        at_ms INTEGER NOT NULL
      )
    ''');
  }

  /// M9 技能注册表（PRD §4 M9）：**已上架技能 + 作者吊销 + 分账账本**。
  ///
  /// 三张表的**主键就是各自的不变式**：
  /// - `skill_listings` 主键 `(skill_id, version)`：同版本只可能有一份内容
  ///   （"付过钱之后被换内容"在存储层写不进去）。
  /// - `skill_revoked` 主键 `(skill_id, version)`，`version` 空串 = 全版本吊销。
  /// - `payout_ledger` 主键 `purchase_id`：同一笔购买只落一条（幂等靠主键）。
  ///
  /// ⚠️ `payout_ledger` **刻意没有 `level` / `upline` / `parent` 列** ——
  /// PRD §9.1 红线：分成只做一层，多层级返利触碰《禁止传销条例》。
  /// 这不是"约定不填"，是"字段不存在，想加多级必须先改这张表"，
  /// `verify_skill_registry` 有源码级断言盯着列清单。
  static Future<void> _migrateV28(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS skill_listings(
        skill_id TEXT NOT NULL,
        version TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        author_id TEXT NOT NULL DEFAULT '',
        author_pub TEXT NOT NULL,
        capabilities TEXT NOT NULL DEFAULT '[]',
        risk TEXT NOT NULL DEFAULT 'low',
        content_hash TEXT NOT NULL,
        price_cents INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'CNY',
        published_at INTEGER NOT NULL,
        sig TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(skill_id, version)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_skill_listings_author ON skill_listings(author_pub, published_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS skill_revoked(
        skill_id TEXT NOT NULL,
        version TEXT NOT NULL DEFAULT '',
        author_pub TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        at_ms INTEGER NOT NULL,
        sig TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(skill_id, version)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payout_ledger(
        purchase_id TEXT PRIMARY KEY,
        skill_id TEXT NOT NULL,
        version TEXT NOT NULL,
        author_pub TEXT NOT NULL,
        buyer_id TEXT NOT NULL DEFAULT '',
        amount_cents INTEGER NOT NULL,
        author_cents INTEGER NOT NULL,
        platform_cents INTEGER NOT NULL,
        referrer_cents INTEGER NOT NULL DEFAULT 0,
        referrer_id TEXT,
        at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payout_author ON payout_ledger(author_pub, at_ms)');
  }

  /// M2 事务委托（PRD §4）：主人下达 → 对方分身回执 → 全程留痕、可撤销。
  ///
  /// ⚠️ **本表刻意没有任何承载金额的字段** —— PRD §2.3 明确不做用户间资金流转，
  /// 这不是"约定不填"，而是"字段不存在，想填也填不进去"。
  /// 若将来有人加 amount 列，请先在 PRD 里改掉这条铁律。
  static Future<void> _migrateV21(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delegations(
        id TEXT PRIMARY KEY,
        circle_id TEXT NOT NULL,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        task TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        state TEXT NOT NULL,
        response TEXT,
        responded_at INTEGER,
        basis TEXT,
        req_sig TEXT,
        from_pub TEXT,
        resp_sig TEXT,
        to_pub TEXT,
        human_confirmed_at INTEGER,
        human_denied_at INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_to ON delegations(to_id, state)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_delegations_from ON delegations(from_id, created_at)');

    // 埋点落库：M1/M2 的验收指标（进圈数、TTFD、握手率）全靠它。
    // 之前全项目没有 Telemetry.bind，事件只在内存里，进程一退就丢——等于没埋。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS telemetry_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ts INTEGER NOT NULL,
        props TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_telemetry_name ON telemetry_events(name, ts)');
  }

  /// `did:wold` 身份签发记录（PRD §5.4 不可补录）。
  ///
  /// **append-only**：只插入、不更新、不删除 —— 身份一旦发放就固化，
  /// 审计必须从第一天连续。重装设备会生成新身份 → 新增一行，旧行保留，
  /// 这样"某设备曾用过哪些身份"的历史永远查得到。
  static Future<void> _migrateV22(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS did_issuance(
        did TEXT PRIMARY KEY,
        pub TEXT NOT NULL,
        agent_id TEXT NOT NULL,
        issued_at INTEGER NOT NULL,
        sig TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_did_agent ON did_issuance(agent_id, issued_at)');
  }

  /// M3 互介卡（PRD §4 M3）：三级披露、主人预览确认、24h 撤回。
  ///
  /// 撤回的语义是"对方侧删除"（验收③），所以本表支持真删除——
  /// 但只删**收到的**卡；自己发出的卡走 revoked_at 软标记（留痕不灭失）。
  static Future<void> _migrateV23(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS intercards(
        id TEXT PRIMARY KEY,
        circle_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        topics TEXT NOT NULL,
        fields TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        approved_at INTEGER,
        sent_at INTEGER,
        revoked_at INTEGER,
        sig TEXT,
        owner_pub TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_intercards_to ON intercards(to_id, revoked_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_intercards_owner ON intercards(owner_id, generated_at)');
  }

  /// M6 互介存证 + §16 透明日志（PRD §4 M6「护照与信誉的种子」/ §16「可验证性」）。
  ///
  /// `attestations` 是**三段式互签记录**：发起 →（双方同意）→（结果 + 对方追认）。
  /// 主键 `id` 由（发起方 / 对端 / 发起时刻）确定性导出 —— 两端算出同一个 id，
  /// 于是幂等由主键保证，不需要任何中心分配。**这张表存的是签名，不是分数**：
  /// PRD §5.4 明确"分数与阈值可后置调整，签名与留痕不可后补"。
  ///
  /// `log_entries` 是 §16 的**公开只追加日志**的本地副本（RFC 6962 Merkle 树）。
  /// 刻意**只存三样哈希**（leaf_hash / prev_hash / hash）而不存叶子原文：
  /// 任何第三方凭 `leaf_hash` 列表就能复算整棵树与包含/一致性证明
  /// （见 `transparency_log.dart`），这既是"任何人可监督"的前提，
  /// 也让这张表天然不含自由文本 —— 公开账本不该承载隐私字段。
  static Future<void> _migrateV26(Database db) async {
    // ---- M6 互介存证 ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attestations(
        id TEXT PRIMARY KEY,
        initiator_id TEXT NOT NULL,
        counterparty_id TEXT NOT NULL,
        circle_id TEXT NOT NULL DEFAULT '',
        room_id TEXT NOT NULL DEFAULT '',
        topic TEXT NOT NULL DEFAULT '',
        initiated_at INTEGER NOT NULL,
        initiator_pub TEXT NOT NULL,
        initiator_sig TEXT NOT NULL,
        consented_at INTEGER,
        counterparty_pub TEXT,
        counterparty_sig TEXT,
        outcome TEXT,
        outcome_by TEXT,
        resolved_at INTEGER,
        outcome_sig TEXT,
        ack_at INTEGER,
        ack_sig TEXT
      )
    ''');
    // 履历按"我是发起方" / "我是对端"两条路径分别倒序取，各建一索引。
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_attest_initiator ON attestations(initiator_id, initiated_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_attest_counterparty ON attestations(counterparty_id, initiated_at)');

    // ---- §16 公开只追加日志（本地副本）----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_entries(
        idx INTEGER PRIMARY KEY,
        leaf_hash TEXT NOT NULL,
        prev_hash TEXT NOT NULL,
        hash TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_log_leaf ON log_entries(leaf_hash)');
  }

  /// M10 房间角色（PRD §4 M10 P1）：`room_roles` —— **角色属于房间**。
  ///
  /// 主键 **(room_id, agent_id)**：一人在一个房间里只有一个角色，
  /// 幂等由主键而不是由代码保证。刻意**没有**任何"全局角色"列 ——
  /// 不在任何一个房间里的角色，在这张表里**根本无处安放**
  /// （铁律 1 的物理形式：想加账号级特权，先得改这条铁律）。
  ///
  /// 默认角色 `participant` **不落库**：没有记录即 participant，
  /// 所以新房间天然"无人主持"，第一个认领者成为主持人
  /// （见 `room_role.dart` 的 `claimHost`）。
  static Future<void> _migrateV27(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS room_roles(
        room_id TEXT NOT NULL,
        agent_id TEXT NOT NULL,
        role TEXT NOT NULL,
        granted_by TEXT NOT NULL DEFAULT '',
        at_ms INTEGER NOT NULL,
        PRIMARY KEY(room_id, agent_id)
      )
    ''');
    // 两个查询方向：按房间列名册 / 按人查"我在哪些房间有身份"。
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_room_roles_room ON room_roles(room_id, role)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_room_roles_agent ON room_roles(agent_id, at_ms)');
  }

  /// M5 世界房间 = 圈的载体（PRD §4 M5）：房间出现记录 + 跨圈边账本。
  ///
  /// `room_presences` 是"某人在某房间说过话"的**事实**，也是跨圈边唯一的
  /// 合法出处 —— 没有这行就没有边（挡住"凭一个 ID 就宣称认识了"的假边）。
  /// 主键 (room_id, agent_id)：一人一房一行，计数累加、时间刷新。
  ///
  /// `bridge_links` 是跨圈边账本，主键 `id = self->peer` —— 同一对人
  /// **天然不可能落两条**，幂等由主键而不是由代码保证。
  static Future<void> _migrateV25(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS room_presences(
        room_id TEXT NOT NULL,
        agent_id TEXT NOT NULL,
        nickname TEXT,
        msg_count INTEGER NOT NULL DEFAULT 1,
        last_seen INTEGER NOT NULL,
        PRIMARY KEY(room_id, agent_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_room_presence_agent ON room_presences(agent_id, last_seen)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bridge_links(
        id TEXT PRIMARY KEY,
        self_id TEXT NOT NULL,
        peer_id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        my_circle_id TEXT NOT NULL,
        at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bridge_links_self ON bridge_links(self_id, at_ms)');
  }

  /// M4 在场机制（PRD §4 M4）：在场信号 + 一次性披露账本。
  ///
  /// `peer_presence` 每个 peer 只留**最新一条**（在场是状态，不是流水）；
  /// `self_intro_ledger` 是"已对谁自报过身份"的账本 —— 铁律 1 要求**一次性披露**，
  /// 若账本丢失就会重复自报（把新对象烦成老对象），所以必须落库。
  static Future<void> _migrateV24(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS peer_presence(
        from_id TEXT PRIMARY KEY,
        to_id TEXT NOT NULL,
        path TEXT NOT NULL,
        at_ms INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        sig TEXT,
        from_pub TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_presence_exp ON peer_presence(expires_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS self_intro_ledger(
        peer_id TEXT PRIMARY KEY,
        first_at_ms INTEGER NOT NULL
      )
    ''');
  }

  /// M1 入场即进圈（PRD §4）：邻里圈 + 成员关系的**双向签名**。
  ///
  /// ⚠️ 这两张表必须在**第一个真实用户之前**就位（§5.4 不可补录原则）：
  /// 成员关系一旦建立却没有签名记录，历史就无法追溯补签。
  static Future<void> _migrateV20(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circles(
        circle_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        city TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circle_members(
        circle_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        member_pub TEXT NOT NULL,
        inviter_id TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        member_sig TEXT,
        host_sig TEXT,
        host_pub TEXT,
        PRIMARY KEY (circle_id, member_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_circle_members ON circle_members(circle_id)');
  }

  static Future<void> _migrateV19(Database db) async {
    // M2 会话轨迹（pocket_harness SessionStore 的宿主实现）：
    // append-only，自增 id 即游标；与 messages 表（UI 展示）解耦。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        type TEXT NOT NULL,
        ts INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_session_events ON session_events(session_id, id)');
  }

  static Future<void> _migrateV18(Database db) async {
    // Step 6 插件总线：tools 表补作者与风险等级列（权限列 v16 已建）
    if (!await _columnExists(db, 'tools', 'author')) {
      await db.execute('ALTER TABLE tools ADD COLUMN author TEXT');
    }
    if (!await _columnExists(db, 'tools', 'risk_level')) {
      await db.execute("ALTER TABLE tools ADD COLUMN risk_level TEXT DEFAULT 'low'");
    }
  }

  static Future<void> _migrateV17(Database db) async {
    // Step 5 信誉与礼物：每个名册节点的本地主观信誉分（0-100，默认 50）
    // 与礼物收发计数。信誉是"我方对节点的局部观察"，绝不上报 Hub。
    if (!await _columnExists(db, 'agent_friends', 'reputation')) {
      await db.execute('ALTER TABLE agent_friends ADD COLUMN reputation INTEGER DEFAULT 50');
    }
    if (!await _columnExists(db, 'agent_friends', 'gifts_sent')) {
      await db.execute('ALTER TABLE agent_friends ADD COLUMN gifts_sent INTEGER DEFAULT 0');
    }
    if (!await _columnExists(db, 'agent_friends', 'gifts_received')) {
      await db.execute('ALTER TABLE agent_friends ADD COLUMN gifts_received INTEGER DEFAULT 0');
    }
  }

  static Future<void> _migrateV15(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_topic ON messages(topic)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_social_logs_target ON social_logs(target_id, timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_agent_friends_online ON agent_friends(is_online)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_agent_friends_tier ON agent_friends(tier)');
  }

  static Future<void> _migrateV16(Database db) async {
    if (!await _columnExists(db, 'tools', 'is_from_dream')) {
      await db.execute('ALTER TABLE tools ADD COLUMN is_from_dream INTEGER DEFAULT 0');
    }
    if (!await _columnExists(db, 'tools', 'source_sig')) {
      await db.execute('ALTER TABLE tools ADD COLUMN source_sig TEXT');
    }
    if (!await _columnExists(db, 'tools', 'version')) {
      await db.execute('ALTER TABLE tools ADD COLUMN version TEXT');
    }
    if (!await _columnExists(db, 'tools', 'permissions')) {
      await db.execute('ALTER TABLE tools ADD COLUMN permissions TEXT');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS system_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT,
        tag TEXT,
        message TEXT,
        created_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT,
        session_id TEXT,
        summary TEXT,
        topic TEXT,
        keywords TEXT,
        people TEXT,
        ref_ids TEXT,
        created_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS agent_actions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT,
        target_id TEXT,
        detail TEXT,
        status TEXT,
        created_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_memory_events_time ON memory_events(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_agent_actions_time ON agent_actions(created_at)');
    await _ensureFts(db);
  }

  static Future<bool> _columnExists(Database db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((r) => r['name'] == column);
  }

  /// FTS5 全文检索（不支持的平台自动降级为 LIKE）。
  ///
  /// ★★ 0.79.0：**降级不再静默**。原来整段包在 `catch (_) {}` 里 —— 平台不支持
  ///   FTS5 时会悄悄退回 LIKE，**没有任何人知道**（既无标记、也无日志）。
  ///   这违反本项目"静默失败是红线"的纪律，而且恰好是真机复核最想知道的事实：
  ///   Android 的 SQLite 是否带 FTS5 —— **桌面 FFI 引擎（sqlite 3.53.1）证明不了**。
  ///   现在失败会：① 置 [_ftsAvailable]=false 并记下原因；② 落一条 `dev.log`；
  ///   ③ 由 [probeFullText] / 自检屏把它**显形**给主人。
  static Future<void> _ensureFts(Database db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
        USING fts5(text, session_id, content=messages, content_rowid=id)
      ''');
      // 同步触发器：新消息写入/更新/删除时保持全文索引一致
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS messages_fts_ai AFTER INSERT ON messages BEGIN
          INSERT INTO messages_fts(rowid, text, session_id)
          VALUES (new.id, new.text, new.session_id);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS messages_fts_ad AFTER DELETE ON messages BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, text, session_id)
          VALUES ('delete', old.id, old.text, old.session_id);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS messages_fts_au AFTER UPDATE ON messages BEGIN
          INSERT INTO messages_fts(messages_fts, rowid, text, session_id)
          VALUES ('delete', old.id, old.text, old.session_id);
          INSERT INTO messages_fts(rowid, text, session_id)
          VALUES (new.id, new.text, new.session_id);
        END
      ''');
      await db.execute("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')");
      _ftsAvailable = true;
      _ftsError = null;
    } catch (e) {
      // 平台不支持 FTS5 ⇒ 后续检索自动回退 LIKE（**但这一次记下来**，见方法头注释）。
      _ftsAvailable = false;
      _ftsError = e.toString();
      // 开库回调里**不能**用 AppLogger（见 `_initDB` 顶部注释：会递归开库）⇒ 用 dart:developer。
      dev.log('FTS5 unavailable, recall falls back to LIKE: $e',
          name: 'db.fts', level: 900); // WARNING
    }
  }

  // ------------------------------------------------------------------
  // 底座事实探针（0.79.0）：供"系统自检"屏 / 真机复核读数
  // ------------------------------------------------------------------

  /// FTS5 是否可用（开库时由 [_ensureFts] 置位）。
  /// ★ `null` = 还没开过库（**不知道**）—— 不要把 `null` 当 `true`（"可配 ≠ 可用"同族）。
  static bool? get ftsAvailable => _ftsAvailable;

  /// 上次 FTS5 初始化失败的原因（成功时为 `null`）。
  static String? get ftsError => _ftsError;

  static bool? _ftsAvailable;
  static String? _ftsError;

  /// **真实探针**：在当前打开的库上跑一次 `MATCH`。
  /// 建表成功 ≠ 能检索 —— 所以这里**真跑一次查询**，而不是只问"表在不在"。
  /// 只读、无副作用。供自检屏 / 真机复核使用。
  static Future<FtsProbe> probeFullText() async {
    try {
      final dbClient = await db;
      final cnt = Sqflite.firstIntValue(
              await dbClient.rawQuery('SELECT COUNT(*) FROM messages_fts')) ??
          0;
      // `unicode61` 分词器下英文单词可命中；跑通即证明"建了且能查"。
      // ★ 刻意**照抄生产查询的形状**（JOIN 回 messages 取元数据、FTS 表带别名 f）：
      //   既有守卫 `verify_memory_address.dart` ⑨ 是**全仓级**禁止 `FROM messages_fts WHERE`
      //   直选（那会每次抛 `no such column` 并被 catch 吞掉 ⇒ 索引只写不读）。
      //   探针若写成直选，既踩同款缺陷、又会让守卫变红 —— 这里用同一份安全形状。
      await dbClient.rawQuery(
          'SELECT m.id FROM messages_fts f '
          'JOIN messages m ON m.id = f.rowid '
          'WHERE messages_fts MATCH ? LIMIT 1',
          ['fen']);
      return FtsProbe(available: true, indexedRows: cnt);
    } catch (e) {
      return FtsProbe(available: false, error: e.toString());
    }
  }

  /// 只读统计：几张主要记忆表的行数（供自检屏）。
  /// 表不存在时记 `-1` —— **不假装是 0**（老库缺表与"表空"是两回事）。
  static Future<Map<String, int>> memoryCounts() async {
    final dbClient = await db;
    const tables = ['messages', 'social_logs', 'memory_events', 'session_events'];
    final out = <String, int>{};
    for (final t in tables) {
      try {
        out[t] =
            Sqflite.firstIntValue(await dbClient.rawQuery('SELECT COUNT(*) FROM $t')) ??
                -1;
      } catch (_) {
        out[t] = -1;
      }
    }
    return out;
  }

  static Future<void> _createTablesAndSeed(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT, text TEXT, topic TEXT, keywords TEXT, isUser INTEGER, timestamp INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS profile(key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS relationships(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, relation TEXT, identity_desc TEXT, notes TEXT, is_ai_readable INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS tools(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, description TEXT, type TEXT, content TEXT, is_enabled INTEGER DEFAULT 1, is_from_dream INTEGER DEFAULT 0, source_sig TEXT, version TEXT, permissions TEXT, author TEXT, risk_level TEXT DEFAULT \'low\')');
    await db.execute('CREATE TABLE IF NOT EXISTS ambassador(key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS audit_queue(id INTEGER PRIMARY KEY AUTOINCREMENT, target_agent TEXT, draft_text TEXT, risk_level TEXT, reason TEXT, status INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS system_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, level TEXT, tag TEXT, message TEXT, created_at INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS memory_events(id INTEGER PRIMARY KEY AUTOINCREMENT, event_type TEXT, session_id TEXT, summary TEXT, topic TEXT, keywords TEXT, people TEXT, ref_ids TEXT, created_at INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS agent_actions(id INTEGER PRIMARY KEY AUTOINCREMENT, action_type TEXT, target_id TEXT, detail TEXT, status TEXT, created_at INTEGER)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS agent_friends(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agent_name TEXT,
        master_name TEXT,
        agent_id TEXT UNIQUE,
        tier TEXT DEFAULT 'stranger',
        mask_profile TEXT DEFAULT '暂无签名',
        avatar TEXT DEFAULT '🤖',
        is_online INTEGER DEFAULT 0,
        last_chat_time INTEGER DEFAULT 0,
        handshake_status TEXT DEFAULT 'none',
        reputation INTEGER DEFAULT 50,
        gifts_sent INTEGER DEFAULT 0,
        gifts_received INTEGER DEFAULT 0,
        auto_pulled INTEGER DEFAULT 0,
        notes TEXT
      )
    ''');

    await db.execute('CREATE TABLE IF NOT EXISTS social_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, action_type TEXT, target_id TEXT, description TEXT)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        type TEXT NOT NULL,
        ts INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_session_events ON session_events(session_id, id)');

    await db.insert('tools', {'name': 'vibrate_phone', 'description': '让手机震动。打招呼时调用。', 'type': 'local', 'content': 'BUILTIN_VIBRATE', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'get_system_status', 'description': '获取设备电量内存。', 'type': 'local', 'content': 'BUILTIN_STATUS', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'search_historical_memory', 'description': _searchMemoryToolDescription, 'type': 'local', 'content': 'BUILTIN_SEARCH_MEMORY', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'web_search_in_china', 'description': '国内高可用全网搜索引擎。', 'type': 'local', 'content': 'BUILTIN_WEB_SEARCH_CHINA', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'get_current_time', 'description': '获取现实时间。', 'type': 'local', 'content': 'BUILTIN_TIME', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'open_url_or_app', 'description': '打开App或网页。', 'type': 'local', 'content': 'BUILTIN_URL', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'create_custom_tool', 'description': '自建工具。', 'type': 'local', 'content': 'BUILTIN_CREATE_TOOL', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tools', {'name': 'inner_monologue', 'description': '大脑反思区。', 'type': 'local', 'content': 'BUILTIN_MONOLOGUE', 'is_enabled': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final hardId = newAgentId();
    await db.insert('ambassador', {'key': 'my_agent_id', 'value': hardId}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('ambassador', {'key': 'avatar', 'value': '🤖'}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 生成一个新的身份 ID（`AG-` + 10 位字母数字）。
  ///
  /// ★ 全项目**唯一**的生成点：首次装机播种（上面 [_createTablesAndSeed]）
  ///   与"身份已迁出、本机擦除后重新立足"（`DeviceMigrationService._wipeSeveredIdentity`）
  ///   都走它。两处各写一份的后果是其中一处迟早与形态校验
  ///   （`DeviceMigration.agentIdPattern`）漂移，而症状是"新身份连不上 Hub"。
  ///
  /// 用 `Random.secure()`：身份 ID 会进 mDNS / 中继信封，可预测的伪随机没有好处。
  static String newAgentId() {
    final r = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return 'AG-' + List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // --- 历史聚类与消息查阅 ---
  static Future<String> getOrCreateSessionByTopic(String topic) async {
    if (topic.isEmpty || topic == '未分类' || topic == '日常交流') return "session_${DateTime.now().millisecondsSinceEpoch}";
    final dbClient = await db;
    final res = await dbClient.query('messages', where: 'topic = ?', orderBy: 'timestamp DESC', limit: 1);
    if (res.isNotEmpty) return res.first['session_id'] as String;
    return "session_${DateTime.now().millisecondsSinceEpoch}";
  }
  static Future<int> insertMessageReturnId({required String text, required bool isUser, required String sessionId}) async {
    final dbClient = await db;
    return await dbClient.insert('messages', {'session_id': sessionId, 'text': text, 'topic': '', 'keywords': '', 'isUser': isUser ? 1 : 0, 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }
  static Future<void> updateMessageMeta(int id, String sessionId, String topic, String keywords) async {
    final dbClient = await db;
    await dbClient.update('messages', {'session_id': sessionId, 'topic': topic, 'keywords': keywords}, where: 'id = ?', whereArgs: [id]);
  }
  static Future<void> insertMessageWithMeta({required String text, required bool isUser, required String sessionId, required String topic, required String keywords}) async {
    final dbClient = await db;
    await dbClient.insert('messages', {'session_id': sessionId, 'text': text, 'topic': topic, 'keywords': keywords, 'isUser': isUser ? 1 : 0, 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }
  static Future<String> searchMessages(String keyword) async {
    final dbClient = await db;
    final res = await dbClient.query('messages', where: 'text LIKE ?', whereArgs: ['%$keyword%'], orderBy: 'timestamp DESC', limit: 10);
    if (res.isEmpty) return "未找到关于 '$keyword' 的记忆。";
    return res.map((e) => "[${DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int).toString()}] ${e['isUser']==1?'主人':'你'}: ${e['text']}").join('\n');
  }
  static Future<List<Map<String, dynamic>>> getMessages({int limit = 20, int offset = 0}) async {
    final dbClient = await db;
    return await dbClient.query('messages', orderBy: 'timestamp DESC', limit: limit, offset: offset);
  }
  static Future<String> getCurrentSessionId() async {
    final dbClient = await db;
    final res = await dbClient.query('messages', orderBy: 'timestamp DESC', limit: 1);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (res.isNotEmpty) {
      final lastTime = res.first['timestamp'] as int;
      if (now - lastTime <= 30 * 60 * 1000) return res.first['session_id'] as String; 
    }
    return "session_$now"; 
  }
  static Future<List<Map<String, dynamic>>> getSessionList() async {
    final dbClient = await db;
    return await dbClient.rawQuery('SELECT session_id, min(timestamp) as start_time, max(timestamp) as end_time, topic, keywords, sum(CASE WHEN isUser=1 THEN 1 ELSE 0 END) as user_msg_count FROM messages GROUP BY session_id ORDER BY end_time DESC');
  }
  static Future<List<Map<String, dynamic>>> getTopicGroupList() async {
    final dbClient = await db;
    return await dbClient.rawQuery('SELECT topic, min(timestamp) as start_time, max(timestamp) as end_time, keywords, count(id) as total_msg FROM messages WHERE topic != "" GROUP BY topic ORDER BY end_time DESC');
  }
  static Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    final dbClient = await db;
    return await dbClient.query('messages', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'timestamp ASC');
  }
  static Future<List<Map<String, dynamic>>> getTopicMessages(String topic) async {
    final dbClient = await db;
    return await dbClient.query('messages', where: 'topic = ?', whereArgs: [topic], orderBy: 'timestamp ASC');
  }

  // --- 档案与工具 ---
  static Future<void> saveProfile(String key, String value) async {
    final dbClient = await db;
    await dbClient.insert('profile', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    dataRevision++;
  }
  static Future<String?> getProfile(String key) async {
    final dbClient = await db;
    final res = await dbClient.query('profile', where: 'key = ?', whereArgs: [key]);
    return res.isEmpty ? null : res.first['value'] as String?;
  }
  static Future<void> insertRelationship(String name, String relation, String identityDesc, String notes) async {
    final dbClient = await db;
    await dbClient.insert('relationships', {'name': name, 'relation': relation, 'identity_desc': identityDesc, 'notes': notes, 'is_ai_readable': 0});
    dataRevision++;
  }
  static Future<void> updateRelationship(int id, String name, String relation, String identityDesc, String notes) async {
    final dbClient = await db;
    await dbClient.update('relationships', {'name': name, 'relation': relation, 'identity_desc': identityDesc, 'notes': notes}, where: 'id = ?', whereArgs: [id]); 
    dataRevision++;
  }
  static Future<List<Map<String, dynamic>>> getRelationships() async {
    final dbClient = await db;
    return await dbClient.query('relationships', orderBy: 'id DESC');
  }
  static Future<void> updateRelationshipReadState(int id, bool isReadable) async {
    final dbClient = await db;
    await dbClient.update('relationships', {'is_ai_readable': isReadable ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    dataRevision++;
  }
  static Future<void> deleteRelationship(int id) async {
    final dbClient = await db;
    await dbClient.delete('relationships', where: 'id = ?', whereArgs: [id]);
    dataRevision++;
  }
  static Future<List<Map<String, dynamic>>> getAiReadableRelationships() async {
    final dbClient = await db;
    return await dbClient.query('relationships', where: 'is_ai_readable = 1');
  }
  static Future<int> insertTool(
    String name,
    String description,
    String type,
    String content, {
    bool isFromDream = false,
    String? sourceSig,
    String? version,
    String? permissions,
    String? author,
    String? riskLevel,
    bool enabled = true,
  }) async {
    final dbClient = await db;
    final id = await dbClient.insert('tools', {
      'name': name,
      'description': description,
      'type': type,
      'content': content,
      'is_enabled': isFromDream ? 0 : (enabled ? 1 : 0),
      'is_from_dream': isFromDream ? 1 : 0,
      'source_sig': sourceSig,
      'version': version,
      'permissions': permissions,
      'author': author,
      'risk_level': riskLevel,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    dataRevision++;
    return id;
  }

  static Future<List<Map<String, dynamic>>> getAllToolsRaw() async {
    final dbClient = await db;
    return await dbClient.query('tools');
  }

  /// 手动递增数据版本：prompt 缓存（_getSystemPromptCached）以此判定失效。
  /// 用于不走 insertTool 的"影响 System Prompt 的变更"（如 change_system_settings
  /// 改了称呼/语气后，下一轮对话自动用新 prompt，无需全量重建大脑）。
  static void bumpRevision() => dataRevision++;


  static Future<void> stampToolMeta(
    int id, {
    required String version,
    required String sourceSig,
    required String permissions,
    required String author,
    required String riskLevel,
  }) async {
    final dbClient = await db;
    await dbClient.update('tools', {
      'version': version,
      'source_sig': sourceSig,
      'permissions': permissions,
      'author': author,
      'risk_level': riskLevel,
    }, where: 'id = ?', whereArgs: [id]);
    dataRevision++;
  }
  static Future<List<Map<String, dynamic>>> getToolsByType(String type) async {
    final dbClient = await db;
    return await dbClient.query('tools', where: 'type = ?', whereArgs: [type], orderBy: 'id DESC');
  }
  static Future<void> updateToolState(int id, bool isEnabled) async {
    final dbClient = await db;
    await dbClient.update('tools', {'is_enabled': isEnabled ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    dataRevision++;
  }
  static Future<void> updateTool(int id, String name, String description, String content) async {
    final dbClient = await db;
    await dbClient.update('tools', {'name': name, 'description': description, 'content': content}, where: 'id = ?', whereArgs: [id]);
    dataRevision++;
  }
  static Future<void> deleteTool(int id) async {
    final dbClient = await db;
    await dbClient.delete('tools', where: 'id = ?', whereArgs: [id]);
    dataRevision++;
  }
  static Future<List<Map<String, dynamic>>> getLoadedTools(bool forceAll) async {
    final dbClient = await db;
    if (forceAll) return await dbClient.query('tools', where: 'type != ?', whereArgs: ['skill']);
    return await dbClient.query('tools', where: 'type != ? AND is_enabled = 1', whereArgs: ['skill']);
  }
  static Future<List<Map<String, dynamic>>> getActiveSkills(bool forceAll) async {
    final dbClient = await db;
    if (forceAll) return await dbClient.query('tools', where: 'type = ?', whereArgs: ['skill']);
    return await dbClient.query('tools', where: 'type = ? AND is_enabled = 1', whereArgs: ['skill']);
  }

  // --- 外交与通讯录 ---
  static Future<void> saveAmbassador(String key, String value) async {
    final dbClient = await db;
    await dbClient.insert('ambassador', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  static Future<String?> getAmbassador(String key) async {
    final dbClient = await db;
    final res = await dbClient.query('ambassador', where: 'key = ?', whereArgs: [key]);
    return res.isEmpty ? null : res.first['value'] as String?;
  }

  // --- 身份换钥「随人不随设备」（见 lib/身份可携带与恢复方案.md） ---

  /// 追加一条本地的**换钥历史**。
  ///
  /// ⚠️ **只追加**：主键 `(agent_id, old_pub)` 配 `ConflictAlgorithm.ignore` ——
  /// 同一把旧钥只能退休一次，重放写不进第二条。
  /// ⚠️ 本地这张表只是**镜像**：权威记录在 Hub 的 `key_rotations` 与 §16 公开日志里。
  /// 存它的理由是"断网也要能看见自己换过钥"，不是"以本机为准"。
  static Future<void> recordKeyRotation({
    required String agentId,
    required String oldPub,
    required String newPub,
    required int rotatedAtMs,
    required String sig,
    String confirmedBy = 'local',
  }) async {
    final dbClient = await db;
    await dbClient.insert(
      'key_rotations',
      {
        'agent_id': agentId,
        'old_pub': oldPub,
        'new_pub': newPub,
        'rotated_at': rotatedAtMs,
        'sig': sig,
        'recorded_at': DateTime.now().millisecondsSinceEpoch,
        'confirmed_by': confirmedBy,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 某身份的换钥历史（按时间升序）。
  static Future<List<Map<String, Object?>>> keyRotationsOf(String agentId) async {
    final dbClient = await db;
    return dbClient.query('key_rotations',
        where: 'agent_id = ?',
        whereArgs: [agentId],
        orderBy: 'rotated_at ASC');
  }
  
  /// 把一名智能体写进本地名册（**`agent_friends` 的唯一写入方**）。
  ///
  /// ★ 0.89.0 新增 [autoPulled]：本次是**机器自动拉取**（true）还是
  ///   **主人手动收录**（false）。它写进 `auto_pulled` 列，作为"清空联邦自动收录"
  ///   的判据。两条语义必须分清：
  ///   · `autoPulled: true`  —— 由 [FederationAutoPull] 调用；新插入的行标记为 1。
  ///   · `autoPulled: false` —— 手动收录 = **主人认领该行**；无论它是新建还是
  ///     命中已存在的（自动拉进来的）那一条，都把 `auto_pulled` 归零，避免主人
  ///     亲自收录的人被"清空"误删。这正是"主人的动作覆盖机器的动作"。
  static Future<void> insertAgentFriend(String agentName, String masterName, String agentId, String tier, String notes, String maskProfile, String avatar, {bool autoPulled = false}) async {
    final dbClient = await db;
    // 并发安全：INSERT OR IGNORE + 无条件刷新在线信息
    await dbClient.insert('agent_friends', {
      'agent_name': agentName, 'master_name': masterName, 'agent_id': agentId,
      'tier': tier, 'mask_profile': maskProfile, 'avatar': avatar, 'is_online': 1, 'notes': notes,
      'last_chat_time': 0, 'handshake_status': 'none',
      'auto_pulled': autoPulled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final updates = <String, Object?>{
      'is_online': 1, 'mask_profile': maskProfile, 'avatar': avatar,
    };
    // 自动拉取只刷新展示信息，**不覆写**已有行的归属标记（主人已认领的保持 0）；
    // 手动收录则显式认领（置 0），使该行脱离"联邦自动收录"集合。
    if (!autoPulled) updates['auto_pulled'] = 0;
    await dbClient.update('agent_friends', updates, where: 'agent_id = ?', whereArgs: [agentId]);
  }

  /// 清空**机器自动收录**的联邦名册项，返回删除行数。
  ///
  /// 判据两条**同时**成立才删：`auto_pulled = 1`（机器拉进来的）
  /// **且** `handshake_status = 'none'`（还没开始任何交往）。
  /// 第二个条件是一道保底：一旦某条自动收录项已被搭讪/建立握手，它就退出了
  /// "未认领的陌生人"状态 —— 此按钮**不得**把它也抹掉（那是不可逆的历史）。
  ///
  /// 主人的手动收录项（`auto_pulled = 0`）永远动不到，见 [insertAgentFriend]。
  static Future<int> clearAutoPulledAgents() async {
    final dbClient = await db;
    return dbClient.delete('agent_friends',
        where: "auto_pulled = 1 AND handshake_status = 'none'");
  }
  
  static Future<List<Map<String, dynamic>>> getAgentFriends() async {
    final dbClient = await db;
    return await dbClient.query('agent_friends', orderBy: 'last_chat_time DESC, is_online DESC, id DESC'); 
  }
  
  static Future<void> updateAgentFriendDetails(int id, String agentName, String masterName, String notes) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'agent_name': agentName, 'master_name': masterName, 'notes': notes}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateAgentReputation(String agentId, int score) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'reputation': score}, where: 'agent_id = ?', whereArgs: [agentId]);
  }

  /// 礼物计数自增（SQL 原子自增，避免读改写竞态）
  static Future<void> bumpGiftCounters(String agentId, {int sent = 0, int received = 0}) async {
    if (sent == 0 && received == 0) return;
    final dbClient = await db;
    await dbClient.execute(
      'UPDATE agent_friends SET gifts_sent = gifts_sent + ?, gifts_received = gifts_received + ? WHERE agent_id = ?',
      [sent, received, agentId],
    );
  }

  static Future<void> updateAgentTier(int id, String newTier) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'tier': newTier}, where: 'id = ?', whereArgs: [id]);
  }
  
  static Future<void> updateAgentOnlineStatusByAgentId(String agentId, bool isOnline) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'is_online': isOnline ? 1 : 0}, where: 'agent_id = ?', whereArgs: [agentId]);
  }
  
  static Future<void> updateAgentOnlineStatus(int id, bool isOnline) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'is_online': isOnline ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateAgentHandshakeStatus(String agentId, String status) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'handshake_status': status}, where: 'agent_id = ?', whereArgs: [agentId]);
  }

  static Future<void> updateAgentLastChatTime(String agentId, int timestamp) async {
    final dbClient = await db;
    await dbClient.update('agent_friends', {'last_chat_time': timestamp}, where: 'agent_id = ?', whereArgs: [agentId]);
  }
  
  static Future<void> deleteAgentFriend(int id) async {
    final dbClient = await db;
    await dbClient.delete('agent_friends', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> insertSocialLog(String actionType, String targetId, String description) async {
    final dbClient = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await dbClient.insert('social_logs', {'timestamp': now, 'action_type': actionType, 'target_id': targetId, 'description': description});
    
    if (actionType == 'send' || actionType == 'receive') {
      await updateAgentLastChatTime(targetId, now);
    }
  }
  
  static Future<List<Map<String, dynamic>>> getSocialLogs({String? targetId}) async {
    final dbClient = await db;
    if (targetId != null && targetId.isNotEmpty) {
      return await dbClient.query('social_logs', where: 'target_id = ? OR target_id = ?', whereArgs: [targetId, 'all'], orderBy: 'timestamp DESC');
    }
    return await dbClient.query('social_logs', orderBy: 'timestamp DESC'); 
  }

  // 🚀 核心修复 3：一键物理洗脑引擎（清空历史 + 斩断所有老旧连接状态）
  static Future<void> clearAllSocialLogsAndResetHandshakes() async {
    final dbClient = await db;
    await dbClient.delete('social_logs');
    await dbClient.update('agent_friends', {'handshake_status': 'none'});
  }

  // ------------------------------------------------------------------
  // 审计与自主行为记录（可审计的自主性）
  // ------------------------------------------------------------------
  static Future<void> insertAudit({
    required String targetAgent,
    required String draftText,
    required String riskLevel,
    required String reason,
    int status = 0,
  }) async {
    final dbClient = await db;
    await dbClient.insert('audit_queue', {
      'target_agent': targetAgent,
      'draft_text': draftText.length > 1000 ? draftText.substring(0, 1000) : draftText,
      'risk_level': riskLevel,
      'reason': reason,
      'status': status,
    });
  }

  static Future<void> insertAgentAction({
    required String actionType,
    String? targetId,
    required String detail,
    String status = 'done',
  }) async {
    final dbClient = await db;
    await dbClient.insert('agent_actions', {
      'action_type': actionType,
      'target_id': targetId,
      'detail': detail.length > 2000 ? detail.substring(0, 2000) : detail,
      'status': status,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    // ★ 「待主人确认」的两类动作必须**主动喊一声**：否则建议卡落库后无声无息，
    //   主人只看到"分身一动不动"。系统通知内核订阅此事件来弹通知；
    //   其余 actionType（create_tool / world_reply / 审计留痕）是记录不是请求，
    //   不该打扰主人，故不发事件。
    if (actionType == 'proactive_suggestion' || actionType == 'pending_approval') {
      AppEvents.emit(AgentActionPendingEvent(
        actionType: actionType,
        targetId: targetId ?? '',
        detail: detail.length > 200 ? detail.substring(0, 200) : detail,
      ));
    }
  }

  static Future<List<Map<String, dynamic>>> getAgentActions({int limit = 50}) async {
    final dbClient = await db;
    return dbClient.query('agent_actions', orderBy: 'created_at DESC', limit: limit);
  }

  /// 待主人批准的「建议卡」。
  ///
  /// ★ 2026-09-29：观察模式下 `AgentService` 会写入 `proactive_suggestion` / `pending_approval`，
  ///   而原先**全仓没有任何调用方**读它 ⇒ 建议卡落库后既看不见、也无从批准。
  ///   这是「分身一动不动」的真实原因之一（实测反馈）：流水线其实跑到了，**只是产物没人消费**。
  static Future<List<Map<String, dynamic>>> getPendingAgentActions({int limit = 50}) async {
    final dbClient = await db;
    return dbClient.query(
      'agent_actions',
      where: "action_type = ? AND status = ?",
      whereArgs: ['proactive_suggestion', 'pending_approval'],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// 批准 / 忽略一条建议卡（把状态从 `pending_approval` 翻过去）。
  /// 返回受影响行数，调用方据此判断是否真的翻掉了。
  static Future<int> updateAgentActionStatus(int id, String status) async {
    final dbClient = await db;
    return dbClient.update(
      'agent_actions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------------------------------------------
  // 分层记忆（情景记忆事件流）
  // ------------------------------------------------------------------
  static Future<void> insertMemoryEvent({
    required String eventType,
    String sessionId = '',
    required String summary,
    String topic = '',
    String keywords = '',
    String people = '',
    String refIds = '',
  }) async {
    final dbClient = await db;
    await dbClient.insert('memory_events', {
      'event_type': eventType,
      'session_id': sessionId,
      'summary': summary.length > 2000 ? summary.substring(0, 2000) : summary,
      'topic': topic,
      'keywords': keywords,
      'people': people,
      'ref_ids': refIds,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getMemoryEvents({int limit = 30}) async {
    final dbClient = await db;
    return dbClient.query('memory_events', orderBy: 'created_at DESC', limit: limit);
  }

  /// 记忆地址 `memory://<ns>/<id>` → 具体行（[memoryAddress] 的反向通道）。
  ///
  /// 为什么需要它：0.77.0 起每条回忆都带地址下发，但**地址必须能被兑现**才
  /// 有意义 —— 模型说"删掉 memory://episode/42"，工具据此可直接定位原文，
  /// 不必拿文本去反查（文本会被截断、会重复，反查不可靠）。
  ///
  /// 解析失败（格式不符 / ns 不认 / 行不存在）一律返回 `null`，**不抛** ——
  /// 地址可能因记忆已被删除而失效，这是正常状态，不是错误。
  static Future<Map<String, dynamic>?> resolveMemoryAddress(
      String address) async {
    final m =
        RegExp(r'^memory://([a-z_]+)/(\d+)$').firstMatch(address.trim());
    if (m == null) return null;
    final ns = m.group(1)!;
    final id = int.tryParse(m.group(2)!);
    if (id == null) return null;
    final table = _memoryNamespaceTables[ns];
    if (table == null) return null;
    final dbClient = await db;
    final rows =
        await dbClient.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// 记忆命名空间 → 表名。**地址的 ns 与这里必须一一对应**（守卫盯着）。
  static const Map<String, String> _memoryNamespaceTables = {
    'chat': 'messages',
    'social': 'social_logs',
    'episode': 'memory_events',
  };

  // ------------------------------------------------------------------
  // 记忆管理（0.70.0 W1：只做查看 + 删除，不做编辑）
  // ------------------------------------------------------------------

  /// 删除一条情景记忆。
  ///
  /// 联动：`ref_ids` 里指向的 `messages` 行一并硬删——ref_ids 的唯一写入方
  /// （chat_screen 的 chat_user / chat_ai 路径）写的就是 messages 表的行 id，
  /// 主人删"这条记忆"的意图是"这件事别再记得"，原文留着还会被
  /// `_fuzzyRecallHits` 从 messages 通道捞出来（删了却还在 = 静默不符预期）。
  /// messages 硬删会触发 `messages_fts_ad` 触发器同步清全文索引（v16 已建）。
  ///
  /// 已知边界（诚实登记）：该会话喂给模型的轨迹（session_events）**不动**——
  /// 轨迹按会话轮换、无单条精确对应关系；长期印象只来自 memory_events 与画像，
  /// 删除情景记忆后不再注入。
  static Future<int> deleteMemoryEvent(int id) async {
    final dbClient = await db;
    final rows = await dbClient.query('memory_events',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return 0;
    final refIds = (rows.first['ref_ids']?.toString() ?? '')
        .split(RegExp(r'[，,、\s]+'))
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    var n = await dbClient
        .delete('memory_events', where: 'id = ?', whereArgs: [id]);
    for (final mid in refIds) {
      n += await dbClient.delete('messages', where: 'id = ?', whereArgs: [mid]);
    }
    return n;
  }

  /// 列出最近的会话线程（供"忘记这段会话"选择）。只统计**未软删**的事件。
  static Future<List<Map<String, dynamic>>> listSessions({int limit = 20}) async {
    final dbClient = await db;
    return dbClient.rawQuery(
      'SELECT session_id, COUNT(*) AS cnt, MAX(ts) AS last_ts '
      'FROM session_events WHERE deleted_at IS NULL '
      'GROUP BY session_id ORDER BY last_ts DESC LIMIT ?',
      [limit],
    );
  }

  /// 主人遗忘一段会话（0.70.0）。这是 `session_events.deleted_at` 的**唯一写入方**：
  ///   ① `session_events` 该线程全部行打软删标记（画像/统计/轨迹回放三个
  ///      读取点都已排除软删行——"删了却还在喂模型"被三处过滤兜死）；
  ///   ② `memory_events` 该线程的情景记忆硬删（recall block 的"最近记下的事"
  ///      不再出现）。
  /// messages 表（UI 聊天记录）**不动**：清 UI 记录是另一件事，主人有
  /// 聊天页自己的清理入口；这里只管"分身的记忆"。
  static Future<int> forgetSession(String sessionId) async {
    final dbClient = await db;
    if (sessionId.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final n = await dbClient.update(
      'session_events',
      {'deleted_at': now},
      where: 'session_id = ? AND deleted_at IS NULL',
      whereArgs: [sessionId],
    );
    await dbClient.delete('memory_events',
        where: 'session_id = ?', whereArgs: [sessionId]);
    return n;
  }

  // 0.42.0 起废弃的 `searchMessagesSmart`（只查 messages、且 `SELECT text,
  // isUser, timestamp FROM messages_fts` 直选未声明列 ⇒ 每次抛 `no such column`
  // 被 catch 吞掉、永远落 LIKE）**已于 0.78.0 删除**：死代码里留着同一缺陷，
  // 将来被复用就会再踩一次。新的检索入口一律走 `searchAllMemory`。
  // 守卫 `tool/verify_memory_address.dart` 现在**全仓级**禁止"直选 messages_fts
  // 未声明列"的写法。

  /// 把一条按地址取回的记忆渲染成给模型看的一行。
  ///
  /// 与模糊召回的渲染刻意**不同**：这里是"按地址精确取回"，模型既然点名要看，
  /// 就该看到**全文** —— 140 字截断是**自动回忆块**（`buildRecallBlock`）的规则
  /// （那里要控总长），不是检索结果的规则。这里只保留一个很宽的**总长上限**
  /// （见 [_capMemoryOutput]）防单条超长记忆把上下文撑爆。
  static String _formatMemoryRow(String address, Map<String, dynamic> row) {
    final ns = address.split('/')[2];
    final ts = ((ns == 'episode' ? row['created_at'] : row['timestamp'])
            as int?) ??
        0;
    final time = DateTime.fromMillisecondsSinceEpoch(ts).toString();
    switch (ns) {
      case 'chat':
        return '[对话] $address [$time] '
            '${(row['isUser'] == 1 ? '主人' : '我')}: '
            '${row['text']?.toString() ?? ''}';
      case 'social':
        return '[社交] $address [$time] '
            '${row['action_type']?.toString() ?? ''}: '
            '${row['description']?.toString() ?? ''}';
      default:
        return '[记忆] $address [$time] '
            '${row['people']?.toString() ?? ''}: '
            '${row['summary']?.toString() ?? ''}';
    }
  }

  /// 多源记忆检索（0.42.0）—— 智能体"想起过去"的**唯一**入口。
  ///
  /// 此前"检索历史"只搜 `messages`（主人对话）且走 `LIKE` ⇒ 三个真实缺陷：
  ///   ① 分身聊过什么、会客厅谁说过话（`social_logs`）**搜不到**；
  ///   ② 情景记忆（`memory_events`）**写了从没人读**（纯黑洞）；
  ///   ③ 建好的 FTS5 索引（`messages_fts`）**没人用**（净负担）。
  /// 本方法把三张表并成一个结果集，按时间升序返回，并逐条标注来源。
  ///
  /// ★ 0.77.0 修掉一个**静默降级**缺陷：原 FTS5 查询写成
  ///   `SELECT text, isUser, timestamp FROM messages_fts`，而 `messages_fts`
  ///   只声明了 `(text, session_id)` 两列 ⇒ 每次执行都抛 `no such column`，
  ///   被 `catch` 吞掉后**永远**落到 LIKE 分支 —— 缺陷③其实从未被修好，
  ///   索引照旧只写不读。现在只选声明列，元数据改用 JOIN 回 `messages` 取。
  ///
  /// ★ 0.78.0：同款的 `searchMessagesSmart`（0.42.0 起废弃、全仓无调用方）
  ///   **已删除** —— 死代码里留着同一缺陷，将来被复用就会再踩一次；守卫现在
  ///   **全仓级**禁止"直选 `messages_fts` 未声明列"。
  ///
  /// ★ 0.77.0：关键词若形如 `memory://<ns>/<id>`，走**地址直达**（取回整条原文、
  ///   不进模糊召回）—— 让随回忆下发的地址是真的能兑现的。
  ///   ⚠️ "取回整条"**不是新能力**：本方法输出向来不及 140 字截断（那是自动
  ///   回忆块的规则）；它与普通检索的差别只在"按地址定位 vs 按关键词检索"。
  ///
  /// ★ 中文的 LIKE 兜底**不能删**（实测结论）：FTS5 默认 `unicode61` 分词器
  ///   把整串中文切成**一个 token**（"我喜欢喝咖啡" → `['我喜欢喝咖啡']`），
  ///   所以 `MATCH '咖啡'` 命中不了它（**实测 0 命中**）；`trigram` 分词器能切但
  ///   要求 SQLite ≥ 3.34，Android 平台版（minSdk 24 对应 3.9.2）无此保障。
  ///   故取 **FTS5 ∪ LIKE 并集**：中文**只能靠 LIKE**；英文/整句两边都能命中，
  ///   但**取样口径不同**（FTS5 按 rank 近似偏旧、LIKE 按最新）⇒ 合并后**召回面
  ///   更宽**（实测英文 query 两边重叠仅 4/16），代价是 messages 表多跑一次查询。
  ///   ⚠️ **不要写成"覆盖场景不重叠"** —— 实测证伪（英文两边都命中）；差异在取样口径。
  ///   ⚠️ FTS5 的 rank 只影响**取哪 10 条**，不影响最终顺序（见下方 `hits.sort`）。
  static Future<String> searchAllMemory(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return '请提供要检索的关键词。';

    // ⓪ 记忆地址直达（0.77.0）：关键词本身是 `memory://<ns>/<id>` 时，
    //    按地址把原文**整条**取回。没有这条，下面下发的地址就只是装饰 ——
    //    模型引用了却没法回看，等于"指了个空门牌"。
    if (kw.startsWith('memory://')) {
      final row = await resolveMemoryAddress(kw);
      if (row == null) return '记忆地址 $kw 已失效（该记忆可能已被删除）。';
      return _capMemoryOutput(_formatMemoryRow(kw, row));
    }

    final dbClient = await db;
    final hits = <_MemoryHit>[];

    void addMessageRows(List<Map<String, dynamic>> rows) {
      for (final e in rows) {
        hits.add(_MemoryHit(
          ts: (e['timestamp'] as int?) ?? 0,
          speaker: (e['isUser'] == 1 ? '主人' : '我'),
          text: e['text']?.toString() ?? '',
          source: '对话',
          ns: 'chat',
          id: (e['id'] as int?) ?? 0,
        ));
      }
    }

    // ①-a messages（主人对话）走 FTS5：英文/整句可命中；`ORDER BY rank` 只决定
    //    **取哪 10 条**，最终顺序由下面的 `hits.sort` 决定（rank 不进最终排序）。
    //    ⚠️ 只能选 messages_fts 自己声明的列（text / session_id）；
    //    isUser、timestamp 在 FTS5 里不存在，必须 JOIN 回 messages 取。
    final seenChat = <int>{};
    try {
      final safe = kw.replaceAll('"', '""');
      final rows = await dbClient.rawQuery(
        'SELECT m.id AS id, m.text AS text, m.isUser AS isUser, '
        'm.timestamp AS timestamp FROM messages_fts f '
        'JOIN messages m ON m.id = f.rowid '
        'WHERE messages_fts MATCH ? ORDER BY rank LIMIT 10',
        ['"$safe"'],
      );
      for (final e in rows) {
        seenChat.add((e['id'] as int?) ?? 0);
      }
      addMessageRows(rows);
    } catch (_) {
      // 平台不支持 FTS5 ⇒ 全交给 ①-b 的 LIKE，这里什么都不做。
    }

    // ①-b 中文子串兜底：unicode61 把整串中文当成一个 token，
    //     MATCH 命中不了部分匹配，必须靠 LIKE 补。与 ①-a 结果按 id 去重。
    final likeRows = await dbClient.query('messages',
        where: 'text LIKE ?', whereArgs: ['%$kw%'],
        orderBy: 'timestamp DESC', limit: 10);
    addMessageRows(
        likeRows.where((e) => seenChat.add((e['id'] as int?) ?? 0)).toList());

    // ② social_logs（私聊 / 会客厅）—— 分身的社交记忆
    final social = await dbClient.query('social_logs',
        where: 'description LIKE ?',
        whereArgs: ['%$kw%'],
        orderBy: 'timestamp DESC',
        limit: 10);
    for (final e in social) {
      hits.add(_MemoryHit(
        ts: (e['timestamp'] as int?) ?? 0,
        speaker: e['action_type']?.toString() ?? '',
        text: e['description']?.toString() ?? '',
        source: '社交',
        ns: 'social',
        id: (e['id'] as int?) ?? 0,
      ));
    }

    // ③ memory_events（情景记忆）—— 此前零读取方
    final memories = await dbClient.query('memory_events',
        where: 'summary LIKE ? OR people LIKE ? OR keywords LIKE ?',
        whereArgs: ['%$kw%', '%$kw%', '%$kw%'],
        orderBy: 'created_at DESC',
        limit: 10);
    for (final e in memories) {
      final people = e['people']?.toString() ?? '';
      hits.add(_MemoryHit(
        ts: (e['created_at'] as int?) ?? 0,
        speaker:
            people.isNotEmpty ? people : (e['event_type']?.toString() ?? ''),
        text: e['summary']?.toString() ?? '',
        source: '记忆',
        ns: 'episode',
        id: (e['id'] as int?) ?? 0,
      ));
    }

    if (hits.isEmpty) return "未找到关于 '$kw' 的记忆。";
    // 时间升序只是"讲述顺序"，不代表相关度 —— 相关度优先的排序在
    // [_fuzzyRecallHits] 里做（那里才有多个关键词可比较）。
    hits.sort((a, b) => a.ts.compareTo(b.ts));
    final body = hits.map((h) {
      // social_logs 里是**别的智能体**说的话 ⇒ 逐行标注"第三方"，与调用方的
      // `_wrapUntrusted` 一起，让模型不把第三方文本当成指令。
      final src = h.ns == 'social' ? '${h.source}·第三方' : h.source;
      return '[$src] ${h.memoryAddress} '
          '[${DateTime.fromMillisecondsSinceEpoch(h.ts).toString()}] '
          '${h.speaker}: ${h.text}';
    }).join('\n');
    return _capMemoryOutput(body);
  }

  // ------------------------------------------------------------------
  // 自动回忆装配（0.43.0，检索增强）
  // ------------------------------------------------------------------
  // 0.42.0 把检索域打通了，但"想起过去"仍要**模型主动调工具**；可人聊天是
  // **自然回忆**的，不会每句话之前都先"查一次档案"。本节把「最近情景记忆」
  // 与「与当前这句话模糊相关的往事」自动摆到模型眼前。

  /// 从一句话里切出用于**模糊回忆**的关键词：英文/数字取整词，中文取整串
  /// （≤4 字）或二元组（>4 字）。
  ///
  /// ⚠️ 这是**刻意的粗糙分词**，不是正经中文分词器（端上不引词典）—— 目的只是
  /// "把相似句子里的共同片段捞出来"，宁可多捞（结果标为"可能相关"并带时间戳），
  /// 不可漏捞。**精确**检索仍由模型显式调 `search_historical_memory` 完成。
  /// ★ 0.78.0：二元组里**含功能字**者丢弃（见 [_recallStopChars]）—— 纯噪声片段
  ///   （`天的`/`的会`）会命中无关行抬分、并挤掉 `会议`/`议室` 这样的实词；但**只
  ///   收真正的功能字**，不收 `对/在/我` 等能组成实词的字（收了会误杀 `对话`）。
  /// 功能字（虚字）集合：二元组**任一字**落在其中即视为噪声片段丢弃。
  ///
  /// 刻意**只收真正的功能字**（的/了/是/和/与/就/都/也…），**不收** `对/在/我/你/他`
  /// 等能组成实词的字 —— 收了会把 `对话`/`在家` 这类真词一起误杀（本仓纪律：宁可多捞）。
  static const String _recallStopChars = '的了吗呢吧啊呀是和与就都也很把被给而但之其着过或则等';

  static bool _containsRecallStopChar(String s) {
    for (var i = 0; i < s.length; i++) {
      if (_recallStopChars.contains(s[i])) return true;
    }
    return false;
  }

  static List<String> extractRecallKeywords(String text, {int max = 6}) {
    final t = text.trim();
    if (t.isEmpty) return const [];
    final raw = <String>[];
    for (final m in RegExp(r'[A-Za-z0-9_]{2,}').allMatches(t)) {
      raw.add(m.group(0)!);
    }
    for (final m in RegExp(r'[\u4e00-\u9fa5]+').allMatches(t)) {
      final run = m.group(0)!;
      if (run.length <= 4) {
        raw.add(run);
      } else {
        for (var i = 0; i + 2 <= run.length; i++) {
          final gram = run.substring(i, i + 2);
          // 含功能字的片段是噪声（如 `我想订明天的会议室` 的 `天的`/`的会`）：
          // 它们命中无关行会抬分、还会挤掉 `会议`/`议室` 这样的实词 ⇒ 丢弃。
          if (_containsRecallStopChar(gram)) continue;
          raw.add(gram);
        }
      }
    }
    final seen = <String>{};
    final out = <String>[];
    for (final k in raw) {
      if (seen.add(k)) out.add(k);
      if (out.length >= max) break;
    }
    return out;
  }

  /// 跨三张表的**模糊**回忆检索（多关键词 OR LIKE）。与 [searchAllMemory] 同域不同途：
  /// 后者是**模型显式检索**（单关键词、`messages` 走 FTS5、求精确）；
  /// 本方法是**系统自动回忆**（多关键词 OR、全 LIKE、求"捞到相关"）。
  /// 二者覆盖同样三张表 —— 单一事实源是"回忆必须同时看得见对话/社交/情景"。
  ///
  /// ★ 0.77.0：结果不再纯按时间倒序，改按 [_recallScore]（多词共现 + 时间衰减）
  /// 排序。SQL 侧只按时间取一个**候选池**（[_recallPoolPerTable] 倍），真正的
  /// 取舍在 Dart 里做 —— 否则"只取最近 6 条再排序"等于没排。
  static Future<List<_MemoryHit>> _fuzzyRecallHits(
    Iterable<String> keywords, {
    int perTable = 6,
  }) async {
    final kws =
        keywords.map((k) => k.trim()).where((k) => k.length >= 2).toSet().toList();
    if (kws.isEmpty) return const [];
    final dbClient = await db;
    final hits = <_MemoryHit>[];

    String orLike(String col) => kws.map((_) => '$col LIKE ?').join(' OR ');
    final likeArgs = [for (final k in kws) '%$k%'];

    // 候选池 = perTable × 12：给排序器留出"从较早但更贴题的条目里挑"的余地，
    // 同时仍是**常数上限**，不会退化成扫描全表。
    final pool = perTable * _recallPoolPerTable;

    // 这条记录命中了几个关键词。只对已经捞出来的候选行计算（≤ pool×3），
    // 是纯字符串比较，开销相对 SQL 扫表可忽略。
    final lowerKws = kws.map((k) => k.toLowerCase()).toList();
    int countHits(Iterable<String?> fields) {
      final blob = fields.map((f) => f ?? '').join('\u0001').toLowerCase();
      var n = 0;
      for (final k in lowerKws) {
        if (blob.contains(k)) n++;
      }
      return n;
    }

    final msgs = await dbClient.query('messages',
        where: orLike('text'),
        whereArgs: likeArgs,
        orderBy: 'timestamp DESC',
        limit: pool);
    for (final e in msgs) {
      hits.add(_MemoryHit(
        ts: (e['timestamp'] as int?) ?? 0,
        speaker: (e['isUser'] == 1 ? '主人' : '我'),
        text: e['text']?.toString() ?? '',
        source: '对话',
        ns: 'chat',
        id: (e['id'] as int?) ?? 0,
        matchCount: countHits([e['text']?.toString()]),
      ));
    }

    final social = await dbClient.query('social_logs',
        where: orLike('description'),
        whereArgs: likeArgs,
        orderBy: 'timestamp DESC',
        limit: pool);
    for (final e in social) {
      hits.add(_MemoryHit(
        ts: (e['timestamp'] as int?) ?? 0,
        speaker: e['action_type']?.toString() ?? '',
        text: e['description']?.toString() ?? '',
        source: '社交',
        ns: 'social',
        id: (e['id'] as int?) ?? 0,
        matchCount: countHits([e['description']?.toString()]),
      ));
    }

    final mem = await dbClient.query('memory_events',
        where:
            '(${orLike('summary')}) OR (${orLike('people')}) OR (${orLike('keywords')})',
        whereArgs: [...likeArgs, ...likeArgs, ...likeArgs],
        orderBy: 'created_at DESC',
        limit: pool);
    for (final e in mem) {
      final people = e['people']?.toString() ?? '';
      hits.add(_MemoryHit(
        ts: (e['created_at'] as int?) ?? 0,
        speaker:
            people.isNotEmpty ? people : (e['event_type']?.toString() ?? ''),
        text: e['summary']?.toString() ?? '',
        source: '记忆',
        ns: 'episode',
        id: (e['id'] as int?) ?? 0,
        matchCount: countHits([
          e['summary']?.toString(),
          e['people']?.toString(),
          e['keywords']?.toString(),
        ]),
      ));
    }

    // 相关度优先，不再纯按时间。
    // ★ 必须带 ns + id 兜底比较：Dart 的 `List.sort` **不稳定**，同分条目
    //   若不钉死次序，同一句话的回忆每次排序都可能不同 ⇒ 结果不可复现。
    hits.sort((a, b) {
      final byScore = _recallScore(b.matchCount, b.ts)
          .compareTo(_recallScore(a.matchCount, a.ts));
      if (byScore != 0) return byScore;
      final byNs = a.ns.compareTo(b.ns);
      if (byNs != 0) return byNs;
      return b.id.compareTo(a.id);
    });
    return hits;
  }

  // ------------------------------------------------------------------
  // 自动回忆的零成本相关度打分（0.77.0）
  // ------------------------------------------------------------------
  // 此前回忆**纯按时间倒序**：只要最近有 N 条"够新"的记录，真正贴题的旧事
  // 就永远排不进来 ⇒ 模型看到的像随机翻旧账。
  //
  // 这里在**不额外查库、不引入新依赖**的前提下加两个信号：
  //   · 多词共现 —— 命中当前这句话里越多的关键词，越贴题；
  //   · 时间衰减 —— 越近的事越该先想起来（21 天半衰期）。
  //
  // ⚠️ 刻意**不做**向量 / embedding / sqlite-vec：10-04 已拍板（端侧负担），
  //    `tool/verify_user_profile.dart` 有守卫拦截。这里的信号全是**零成本**的：
  //    分数只由 SQL 已经取回的字段算出。

  /// 权重：每多命中一个关键词的增益。
  static const double _wMatch = 1.0;

  /// 权重：新鲜度（0~1）的增益。刻意 < [_wMatch] —— 回忆"答非所问"的代价
  /// 大于"想起一件稍旧的事"，故贴题优先于新鲜。
  static const double _wRecency = 0.6;

  /// 半衰期（天）—— 与 `user_profile_store` 的画像口径保持一致，避免
  /// "同一件事在回忆里比在画像里衰减得更快"这种不自洽。
  static const double _recallHalfLifeDays = 21.0;

  /// 候选池放大倍数（相对每表取条数）。
  static const int _recallPoolPerTable = 12;

  /// 相关度 = 多词共现 × [_wMatch] + 新鲜度 × [_wRecency]。
  ///
  /// 新鲜度按 21 天半衰期：21 天前的事权重减半，42 天前剩 1/4。
  /// [ts] ≤ 0（脏数据/未知时间）当作"极旧"处理，不会被抬到前面。
  static double _recallScore(int matches, int ts) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ageDays = (now - ts) / 86400000.0;
    final clamped = ageDays < 0 ? 0.0 : (ageDays.isNaN ? 0.0 : ageDays);
    final recency = pow(0.5, clamped / _recallHalfLifeDays);
    return matches * _wMatch + recency.toDouble() * _wRecency;
  }

  /// 检索结果总长上限：防"一条超长记忆"（或地址直达取回整条原文）把模型
  /// 上下文撑爆。**很宽**（4000 字）—— 正常检索远达不到，只在异常长记录时兜底；
  /// 截断会**显式标注**，不静默丢内容。
  static const int _maxMemoryOutputChars = 4000;

  static String _capMemoryOutput(String s) {
    if (s.length <= _maxMemoryOutputChars) return s;
    return '${s.substring(0, _maxMemoryOutputChars)}'
        '\n（已截断：原文共 ${s.length} 字，仅显示前 $_maxMemoryOutputChars 字）';
  }

  /// 组装"自动回忆"块（0.43.0）。返回空串 = 无可注入内容。
  ///
  /// 组成：① 最近 [recentEpisodic] 条情景记忆（`memory_events` 的读路径 —— 它在
  /// 0.42.0 之前**零读取方**）；② 与 [query] 模糊相关的 [relatedMax] 条往事
  /// （跨对话/社交/情景三表）。总长度封顶 [maxChars]（防长记忆撑爆系统提示词）。
  ///
  /// ★ 0.77.0：每条回忆前带**记忆地址**（`memory://episode/42`）。模型因此可以
  /// 指着具体某条记忆说话（引用 / 要求删除 / 指出重复），而不是只能复述文本。
  /// 地址是**可兑现**的 —— [resolveMemoryAddress] 是它的反向通道。
  ///
  /// ⚠️ 内容可能来自第三方（`social_logs` 里别的智能体说的话）⇒ 调用方
  /// **必须**按不可信输入包裹（见 `AgentService._wrapUntrusted`），不得裸注入。
  static Future<String> buildRecallBlock(
    String query, {
    int recentEpisodic = 5,
    int relatedMax = 6,
    int maxChars = 1600,
  }) async {
    final buf = StringBuffer();

    final recent = await getMemoryEvents(limit: recentEpisodic);
    if (recent.isNotEmpty) {
      final lines = <String>[];
      for (final e in recent.reversed) {
        final s = (e['summary']?.toString() ?? '').trim();
        if (s.isEmpty) continue;
        final id = (e['id'] as int?) ?? 0;
        lines.add('- memory://episode/$id '
            '[${_recallTime((e['created_at'] as int?) ?? 0)}] '
            '${s.length > 140 ? '${s.substring(0, 140)}…' : s}');
      }
      if (lines.isNotEmpty) {
        buf.writeln('■ 你最近记下的事（你自己的情景记忆；行首 memory://… 为记忆地址，'
            '需回看原文时原样传给 search_historical_memory）：');
        for (final l in lines) {
          buf.writeln(l);
        }
      }
    }

    final kws = extractRecallKeywords(query);
    if (kws.isNotEmpty) {
      final hits = await _fuzzyRecallHits(kws, perTable: relatedMax);
      if (hits.isNotEmpty) {
        if (buf.isNotEmpty) buf.writeln();
        buf.writeln('■ 可能与当前话题相关的往事（行首 memory://… 为记忆地址，'
            '需回看原文时原样传给 search_historical_memory）：');
        for (final h in hits.take(relatedMax)) {
          final txt = h.text.trim();
          buf.writeln('- [${h.source}] ${h.memoryAddress} '
              '[${_recallTime(h.ts)}] ${h.speaker}: '
              '${txt.length > 140 ? '${txt.substring(0, 140)}…' : txt}');
        }
      }
    }

    final s = buf.toString().trim();
    if (s.isEmpty) return '';
    return s.length > maxChars ? '${s.substring(0, maxChars)}…' : s;
  }

  static String _recallTime(int ms) {
    if (ms <= 0) return '未知时间';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ------------------------------------------------------------------
  // 社交查询优化（SQL 侧分页/聚合，避免全表拉取）
  // ------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getRecentSocialLogs(
    String targetId, {
    int limit = 50,
  }) async {
    final dbClient = await db;
    return dbClient.query(
      'social_logs',
      where: 'target_id = ? OR target_id = ?',
      whereArgs: [targetId, 'all'],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// 只取**对话类**社交日志（`send` / `send_manual` / `receive` / `system`），
  /// 在 **SQL 侧**过滤（0.44.0）。
  ///
  /// 为什么必须在 SQL 侧过滤（评审 §二 P4）：旧路径 `getRecentSocialLogs(limit:200)`
  /// 先按**全类型**取最新 200 条、**再**在 Dart 侧筛对话类 —— 系统 / 基建日志
  /// （`infra` / `observe`）一多，真正的对话行就被挤出 200 条窗口，白白少喂上下文。
  /// 白名单制（不是黑名单）：新增噪音类型默认**不进**上下文。
  ///
  /// 返回**新→旧**（`timestamp DESC`）；调用方若要时间升序，反转即可。
  static Future<List<Map<String, dynamic>>> getRecentChatLogs(
    String targetId, {
    int limit = 200,
  }) async {
    final dbClient = await db;
    return dbClient.query(
      'social_logs',
      where: "(target_id = ? OR target_id = ?) AND action_type IN "
          "('send','send_manual','receive','system')",
      whereArgs: [targetId, 'all'],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// 读该 peer 的滚动摘要（0.44.0）。无记录返回 null。
  ///
  /// 返回的 `covered_until_id` 是游标（见 `_migrateV35`）：id 大于它的对话
  /// 才是"还没进摘要的原文"。
  static Future<Map<String, dynamic>?> getPeerSummary(String peerId) async {
    final dbClient = await db;
    final rows = await dbClient.query(
      'peer_summaries',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// 写 / 覆盖该 peer 的滚动摘要（主键 `peer_id` ⇒ 一个 peer 只留最新一份）。
  static Future<void> upsertPeerSummary(
    String peerId, {
    required String summary,
    required int coveredUntilId,
  }) async {
    final dbClient = await db;
    await dbClient.insert(
      'peer_summaries',
      {
        'peer_id': peerId,
        'summary': summary,
        'covered_until_id': coveredUntilId,
        'updated_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 读该房间的滚动摘要（0.45.0）。无记录返回 null。
  ///
  /// `covered_until_id` 的含义同 `getPeerSummary`：id 大于它的房间消息才是"原文"。
  static Future<Map<String, dynamic>?> getRoomSummary(String roomId) async {
    final dbClient = await db;
    final rows = await dbClient.query(
      'room_summaries',
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// 写 / 覆盖该房间的滚动摘要（主键 `room_id` ⇒ 一个房间只留最新一份）。
  static Future<void> upsertRoomSummary(
    String roomId, {
    required String summary,
    required int coveredUntilId,
  }) async {
    final dbClient = await db;
    await dbClient.insert(
      'room_summaries',
      {
        'room_id': roomId,
        'summary': summary,
        'covered_until_id': coveredUntilId,
        'updated_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, int>> countSocialLogsByTarget() async {
    final dbClient = await db;
    final res = await dbClient.rawQuery(
      "SELECT target_id, COUNT(*) AS c FROM social_logs "
      "WHERE action_type IN ('send', 'receive', 'send_manual') GROUP BY target_id",
    );
    return {
      for (final r in res)
        r['target_id'] as String: ((r['c'] as num?) ?? 0).toInt(),
    };
  }

  static Future<int> getOnlineAgentCount() async {
    final dbClient = await db;
    final res = await dbClient
        .rawQuery('SELECT COUNT(*) AS c FROM agent_friends WHERE is_online = 1');
    return ((res.first['c'] as num?) ?? 0).toInt();
  }

  // ------------------------------------------------------------------
  // 设备密钥（协议签名/会话用；升级公钥体系前的过渡方案）
  // ------------------------------------------------------------------
  static Future<String> getOrCreateDeviceSecret() async {
    final prefs = await SharedPreferences.getInstance();
    var secret = prefs.getString('device_secret');
    if (secret == null || secret.length < 16) {
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      secret = List.generate(32, (_) => chars[Random().nextInt(chars.length)]).join();
      await prefs.setString('device_secret', secret);
    }
    return secret;
  }
}

/// 多源记忆检索中的一条命中（供 [DBHelper.searchAllMemory] 归并排序用）。
///
/// ★ 0.77.0 加了 [ns] + [id] + [matchCount]：
///   - [ns]/[id] 组成**记忆地址**（[memoryAddress]）—— 把记忆从"一段文本"
///     升级成"一个可寻址对象"，模型才可能对它**定点操作**（引用/删除/去重），
///     而不是只能把原文再复述一遍。
///   - [matchCount] 是排序用的零成本相关度信号（见 [_recallScore]）。
class _MemoryHit {
  final int ts;
  final String speaker;
  final String text;

  /// 来源标签（对话 / 社交 / 记忆）—— 给**模型**看的中文。
  final String source;

  /// 地址命名空间（chat / social / episode）—— 给**机器**用的稳定标识。
  final String ns;

  /// 该行在来源表里的主键。
  final int id;

  /// 命中了几个关键词（[searchAllMemory] 单关键词时恒为 1）。
  /// 供 [_recallScore] 做"多词共现优先"。
  final int matchCount;

  const _MemoryHit({
    required this.ts,
    required this.speaker,
    required this.text,
    required this.source,
    required this.ns,
    required this.id,
    this.matchCount = 1,
  });

  /// 这条记忆的**唯一地址**，形如 `memory://episode/42`。
  ///
  /// 与 OpenViking 的 `viking://` 同一思路：可寻址是可操作的**前提**。
  /// 三个命名空间固定为 chat / social / episode，与 [resolveMemoryAddress]
  /// 的解析表一一对应（改这里就要改那里，守卫 `verify_memory_address.dart` 钉住）。
  String get memoryAddress => 'memory://$ns/$id';
}

/// FTS5 探针结果（见 [DBHelper.probeFullText]）。
class FtsProbe {
  /// 建了 `messages_fts` **且**能跑通一次 `MATCH`。
  final bool available;

  /// 已索引的行数（[available] 为 false 时无意义）。
  final int indexedRows;

  /// 失败原因（成功时为 `null`）。
  final String? error;

  const FtsProbe({
    required this.available,
    this.indexedRows = 0,
    this.error,
  });
}
