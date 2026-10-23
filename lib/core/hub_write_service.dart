import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_identity.dart';
import 'app_logger.dart';
import 'contribution_ledger.dart';
import 'db_helper.dart';
import 'hub_endpoint.dart';
import 'hub_outbox.dart';
import 'hub_outbox_store_db.dart';
import 'hub_push_outcome.dart';
import 'reputation_network.dart';
import 'room_role.dart';
import 'skill_registry.dart';
import 'telemetry.dart';

class _Raw {
  final int status;
  final String error;
  const _Raw(this.status, this.error);
}

/// **App → Hub 上行接线**：把"本机已经签好名的事"公示到 Hub。
///
/// ---------------------------------------------------------------------------
/// 这一层补的是哪条腿
/// ---------------------------------------------------------------------------
/// 在此之前，§16 透明日志 / M10 贡献账本 / M9 技能上架 / M6 网络背书 /
/// M10 房间角色的**本地那一半都是齐的**（各带 SQLite 实现、各自可离线验签），
/// 但**没有任何一行代码把它们推上 Hub** —— 于是
/// "你不必相信我，你可以验我"这句话**没有数据流进那棵公开的树**，
/// 属于**宣称大于事实**。
///
/// 本类只做一件事：把已签名的域对象按 Hub 的契约发出去。
/// 它**不做**判定（判定两端各自独立做，Hub 还会重算一遍）——
/// 这条纪律是刻意的：一旦客户端"替 Hub 下结论"，可验证性就没了。
///
/// ---------------------------------------------------------------------------
/// 三条不变量
/// ---------------------------------------------------------------------------
/// ① **信封现构**：`X-Agent-Sig` 只在**发送的这一刻**由本机身份签出。
///    协议包 `TS_WINDOW_SECONDS = 300`（±5 分钟防重放）—— 缓存信封等于
///    缓存一堆过期废纸。入队的是域对象，不是信封。
/// ② **只推记录，绝不推派生分**：上行载荷里**没有**"我的声望是多少"这种字段。
///    §9.1 红线要求权益不可转让/兑现/与利润挂钩，而"可写余额"是它长出来的方式；
///    所以这里连一个可以承载"分值"的字段都不提供（见 `toWireMap` 的字段清单）。
/// ③ **失败不阻断本地**：本地落库先成功，上行是 best-effort。
///    与 `wold_runtime` 既有注释同一纪律 —— 公示失败不能让记账失败。
class HubWriteService {
  final HubOutboxStore _store;
  bool _flushing = false;

  /// 建立连接超时：**只覆盖 TCP 握手**。
  static const Duration _connectTimeout = Duration(seconds: 8);

  /// 单次请求/响应的读写超时。
  ///
  /// ⚠️ 为什么不能只设 `connectionTimeout`：它**不覆盖"连上了但永不回应"**。
  /// 对端握手成功却不再返回响应（半开连接、网关把请求吃了、对端进程被挂起）时，
  /// `req.close()` 会**永不返回**；而 `_send` 是被 `_push` / `flushOutbox`
  /// 直接 await 的 —— 于是一条公示会把调用方**永久卡住**。
  /// 这比"发失败"更糟：失败至少还会入队重试，挂死是既不成功也不入队。
  ///
  /// 超时抛 `TimeoutException` → 被 `_send` 的 catch 归为 `network`
  /// → `classifyHubResponse` 判为 retryable → **入队等下次重放**。
  /// 也就是把"挂死"降级成"稍后重发"。
  static const Duration _ioTimeout = Duration(seconds: 15);

  HubWriteService({HubOutboxStore? store})
      : _store = store ?? DbHubOutboxStore();

  // ------------------------------------------------------------------
  // 五个端点
  // ------------------------------------------------------------------

  /// §16 透明日志：追加一片叶子（幂等）。
  Future<HubPushResult> pushLogAppend(String leafHash) =>
      _push('/api/log/append', {'leaf_hash': leafHash});

  /// M10 ⑤ 贡献账本：提交一条贡献。Hub 会自己重算 canonical + 验签 + 算叶子哈希。
  Future<HubPushResult> commitContribution(ContributionRecord r) =>
      _push('/api/contributions/commit', r.toWireMap());

  /// M9 技能注册表：上架（Hub 验签 + 幂等/防换手/版本单调）。
  Future<HubPushResult> publishSkill(SkillListing l) =>
      _push('/api/skills/publish', {'listing': l.toMap()});

  /// M6 网络级信誉：提交一份背书。⚠️ Hub **不做**聚合打分，只保管"这份背书是不是真的"。
  Future<HubPushResult> endorse(Endorsement e) =>
      _push('/api/reputation/endorse', {'endorsement': e.toMap()});

  /// M10 房间角色：提交一条**已签名**的授予。
  ///
  /// 未签名的 grant 不该走到这里 —— 调用方必须先用
  /// [RoomRoleAuthority.signGrant] 升级；这里只做一道 fail-closed 兜底
  /// （送一个空 `granter_pub` 上去只会换来一个无意义的 400）。
  Future<HubPushResult> commitRoomRole(RoomRoleGrant g) async {
    if (!g.isSigned) {
      Telemetry.instance?.track(TelemetryEvents.hubPushRejected,
          props: {'endpoint': '/api/rooms/roles/commit', 'error': 'unsigned_grant'});
      return const HubPushResult(HubPushOutcome.rejected, 0, 'unsigned_grant');
    }
    return _push('/api/rooms/roles/commit', {'grant': g.toSignedMap()});
  }

  // ------------------------------------------------------------------
  // 队列重放
  // ------------------------------------------------------------------

  /// 把到期的待发条目重放一遍，返回**成功发出**的条数。
  ///
  /// ⚠️ 顺序有意义：按入队顺序（`id ASC`）发。房间角色的权威名册是 Hub 侧
  /// **重放派生**的，乱序发送会让一条本该合法的授予被 `not_host` 拒掉。
  Future<int> flushOutbox({int limit = HubOutboxPolicy.drainBatch}) async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final items = await _store.due(nowMs: now, limit: limit);
      for (final it in items) {
        Map<String, dynamic> body;
        try {
          body = Map<String, dynamic>.from(jsonDecode(it.payloadJson) as Map);
        } catch (_) {
          // 载荷坏了（写库被打断等）—— 留着它只会永远失败，出队并留痕。
          await _store.remove(it.id);
          Telemetry.instance?.track(TelemetryEvents.hubPushRejected,
              props: {'endpoint': it.endpoint, 'error': 'corrupt_payload'});
          continue;
        }
        final r = await _send(it.endpoint, body);
        final outcome = _classify(r);
        if (outcome == HubPushOutcome.accepted ||
            outcome == HubPushOutcome.duplicate) {
          await _store.remove(it.id);
          sent++;
          Telemetry.instance?.track(TelemetryEvents.hubPushFlushed, props: {
            'endpoint': it.endpoint,
            'attempts': it.attempts,
            'lag_ms': DateTime.now().millisecondsSinceEpoch - it.createdAtMs,
          });
        } else if (outcome == HubPushOutcome.rejected) {
          await _store.remove(it.id);
          Telemetry.instance?.track(TelemetryEvents.hubPushRejected, props: {
            'endpoint': it.endpoint,
            'error': r.error,
            'http': r.status,
          });
        } else {
          await _store.markAttempt(
            it.id,
            r.error,
            DateTime.now().millisecondsSinceEpoch +
                HubOutboxPolicy.retryDelayMs(it.attempts + 1),
          );
        }
      }
    } catch (e) {
      AppLogger.w('hub.flush', e);
    } finally {
      _flushing = false;
    }
    return sent;
  }

  /// 队列积压条数（供"还没公示出去多少"的可观测性）。
  Future<int> pendingCount() async {
    try {
      return await _store.count();
    } catch (_) {
      return 0;
    }
  }

  // ------------------------------------------------------------------
  // 内部
  // ------------------------------------------------------------------

  /// 发一次；发不出去就入队。
  Future<HubPushResult> _push(String endpoint, Map<String, dynamic> body) async {
    final r = await _send(endpoint, body);
    final outcome = _classify(r);
    switch (outcome) {
      case HubPushOutcome.accepted:
      case HubPushOutcome.duplicate:
        Telemetry.instance?.track(TelemetryEvents.hubPushAccepted,
            props: {'endpoint': endpoint, 'result': outcome.name});
      case HubPushOutcome.retryable:
        await _enqueue(endpoint, body, r.error);
      case HubPushOutcome.rejected:
        Telemetry.instance?.track(TelemetryEvents.hubPushRejected,
            props: {'endpoint': endpoint, 'error': r.error, 'http': r.status});
    }
    return HubPushResult(outcome, r.status, r.error);
  }

  Future<void> _enqueue(
      String endpoint, Map<String, dynamic> body, String error) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _store.enqueue(HubOutboxItem(
        endpoint: endpoint,
        payloadJson: jsonEncode(body),
        nextAttemptAtMs: now + HubOutboxPolicy.retryDelayMs(1),
        createdAtMs: now,
        lastError: error,
      ));
      final dropped = await _trimIfOverCapacity();
      Telemetry.instance?.track(TelemetryEvents.hubPushEnqueued, props: {
        'endpoint': endpoint,
        'error': error,
        'pending': await _store.count(),
        'dropped': dropped,
      });
    } catch (e) {
      // 入队失败只能在本地留痕：此刻 Hub 不通、库也不通，没有更好的去处。
      AppLogger.w('hub.enqueue', e);
    }
  }

  /// 超容量则丢**最旧**的，返回丢弃条数（0 = 没丢）。
  Future<int> _trimIfOverCapacity() async {
    final s = _store;
    if (s is! DbHubOutboxStore) return 0;
    final n = await s.count();
    if (n <= HubOutboxPolicy.maxQueued) return 0;
    final dropped = await s.trimOldest();
    if (dropped > 0) {
      Telemetry.instance?.track(TelemetryEvents.hubOutboxTrimmed,
          props: {'dropped': dropped, 'cap': HubOutboxPolicy.maxQueued});
    }
    return dropped;
  }

  /// 真发一次 HTTP。**信封在这一刻现构**（理由见类注释不变量 ①）。
  Future<_Raw> _send(String endpoint, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final url = HubEndpoint.resolveFrom(prefs.getString(HubEndpoint.prefsKey));
    if (url.isEmpty) return const _Raw(0, 'hub_not_configured');

    final myId = await DBHelper.getAmbassador('my_agent_id') ?? 'AG-000';
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final env = await AgentIdentity().buildHubEnvelope(
        fromId: myId,
        toId: 'hub',
        payload: body,
      );
      final header = base64UrlEncode(utf8.encode(jsonEncode(env)));
      final req = await client.postUrl(Uri.parse('$url$endpoint'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Agent-Sig', header);
      req.write(jsonEncode(body));
      // 两段各自设限：① 到响应头 ② 到响应体读完。只设其中一段的话，
      // 另一段仍可被对端"吊住"（先给头不给体，或干脆不给头）。
      final res = await req.close().timeout(_ioTimeout);
      final text = await res.transform(utf8.decoder).join().timeout(_ioTimeout);
      String err = '';
      try {
        err = ((jsonDecode(text) as Map)['error'] ?? '').toString();
      } catch (_) {
        // 非 JSON 响应（网关错误页等）：状态码仍然是有效信息。
      }
      return _Raw(res.statusCode, err);
    } catch (e) {
      AppLogger.w('hub.send', e);
      return _Raw(0, 'network');
    } finally {
      // force：超时那条链路此刻**仍然是活的**，非强制关闭会把它留在连接池里
      // 直到 idleTimeout —— 每次超时攒一个，就是慢性 socket 泄漏。
      client.close(force: true);
    }
  }

  /// 状态码 → 结局。判据集中在 [classifyHubResponse]（纯函数，可离线断言）。
  HubPushOutcome _classify(_Raw r) => classifyHubResponse(r.status, r.error);
}
