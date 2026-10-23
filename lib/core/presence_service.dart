/// M4 在场机制 · 最小版（PRD §4 M4 P0）
///
/// 需求：在"默认分身参与"的世界里，让"真人到场"成为**可见、不可伪造的信号**。
///
/// v1.3 范围收紧：200 对之前不做"有效性"目标，P0 只做三件事——
/// **① 路径判定最小版　② 首次自报身份　③ 上报埋点**，验收定"不误判"：
///   - 分身自动发言 **不**标"本人在线"
///   - 主人亲手打字 **会**被标记
///   - 大段粘贴 **不**触发标记
///
/// 判定依据只有一条：**消息进入系统的路径**（谁把这段字放进了输入框），
/// 不是"内容像不像人写的"。理由：内容启发式一定误判，而路径是确定性的。
/// 编辑距离 / 粘贴占比 / 每日上限 / 自动过期属 P1，本文件刻意不做。
///
/// 本文件**零平台依赖**（Signer 注入），`dart run tool/verify_presence.dart` 可验证。
library;

import 'dart:convert';

import 'agent_protocol.dart';
import 'circle_service.dart'; // 复用 Signer 抽象

/// 消息进入系统的路径：分身生成 / 前台输入框。
enum PresenceSource { agent, composer }

/// 判定结论里的路径标签（进埋点，供以后回看"依据是什么"）。
enum PresencePath { agent, typed, pasted }

/// 前台输入框里一次"发送动作"的可观测证据。
///
/// 宿主（UI）负责采集，core 只负责判定——这样判定规则可离线复算、可写测试。
class ComposeEvidence {
  /// 这条消息是分身自动生成的吗（agent 路径直接排除，不看内容）。
  final PresenceSource source;

  /// 整条消息的字符数。
  final int totalChars;

  /// **单次插入**的最大字符数。逐键键入 ≈ 1；一次性粘贴 = 整段长度。
  final int largestInsertionChars;

  /// 是否发生了系统粘贴板事件（宿主可观测时为真；观测不到靠上面那条兜底）。
  final bool usedClipboard;

  /// 从首次键入到点"发送"的时长（毫秒）。0 表示没测（不参与判定）。
  final int composeMs;

  const ComposeEvidence({
    required this.source,
    required this.totalChars,
    this.largestInsertionChars = 1,
    this.usedClipboard = false,
    this.composeMs = 0,
  });

  /// 分身自动发言（快捷芯片、群发、搭讪草稿等）——路径即证据。
  const ComposeEvidence.agent({required this.totalChars})
      : source = PresenceSource.agent,
        largestInsertionChars = 0,
        usedClipboard = false,
        composeMs = 0;

  /// 主人亲手逐键敲的字。
  const ComposeEvidence.typed({required this.totalChars, this.composeMs = 0})
      : source = PresenceSource.composer,
        largestInsertionChars = 1,
        usedClipboard = false;

  /// 主人粘贴的一段字。
  const ComposeEvidence.pasted({required this.totalChars})
      : source = PresenceSource.composer,
        largestInsertionChars = 0,
        usedClipboard = true,
        composeMs = 0;
}

class PresenceVerdict {
  final bool humanPresent;
  final PresencePath path;

  /// 判定依据（进埋点 / 排障）：agent_generated / clipboard / bulk_insert /
  /// typed / no_typed_input。
  final String reason;

  const PresenceVerdict({
    required this.humanPresent,
    required this.path,
    required this.reason,
  });

  @override
  String toString() =>
      'PresenceVerdict(humanPresent=$humanPresent, path=${path.name}, reason=$reason)';
}

/// 路径判定最小版。**fail-closed**：拿不准就不标（宁可不显示"本人在线"）。
class PresenceJudge {
  /// 单次插入 ≥ 该字符数即视为"大段粘贴"（无系统剪贴板事件时的兜底）。
  /// 取 40：一句话正常发不会一次插入 40 字，而一段粘贴基本都超过。
  static const int bulkInsertThreshold = 40;

  static PresenceVerdict judge(ComposeEvidence e) {
    // ① 分身自动发言：路径本身就是证据，**绝不**标"本人在线"。
    if (e.source == PresenceSource.agent) {
      return const PresenceVerdict(
          humanPresent: false, path: PresencePath.agent, reason: 'agent_generated');
    }
    // 空消息
    if (e.totalChars <= 0) {
      return const PresenceVerdict(
          humanPresent: false, path: PresencePath.agent, reason: 'empty');
    }
    // ③ 大段粘贴：**有**剪贴板事件，或单次插入过大 → 不算亲手打字。
    if (e.usedClipboard) {
      return const PresenceVerdict(
          humanPresent: false, path: PresencePath.pasted, reason: 'clipboard');
    }
    if (e.largestInsertionChars >= bulkInsertThreshold) {
      return const PresenceVerdict(
          humanPresent: false, path: PresencePath.pasted, reason: 'bulk_insert');
    }
    // ② 主人亲手打字：字符是逐个进来的。
    return const PresenceVerdict(
        humanPresent: true, path: PresencePath.typed, reason: 'typed');
  }
}

// ---------------------------------------------------------------- 输入采集

/// 前台输入框的证据采集器（宿主每敲一次就 `onChanged`，发送时 `evidence()`）。
///
/// 为什么要有它：**"是不是粘贴"只能在输入过程中看出来**，发送的那一刻已经看不出了。
/// 判据是最朴素的一条——**单次变化比上次长了多少**：逐键 +1，粘贴 +N。
/// 中文输入法选词会一次进 2–4 个字，远低于阈值，不会误判。
class ComposeTracker {
  int _lastLen = 0;
  int _largestInsertion = 0;
  int? _firstChangeAtMs;

  /// 输入框内容变化时调用（[atMs] 可注入，便于离线验证）。
  void onChanged(String text, {int? atMs}) {
    final len = text.length;
    final delta = len - _lastLen;
    if (delta > _largestInsertion) _largestInsertion = delta;
    if (delta > 0) _firstChangeAtMs ??= atMs ?? DateTime.now().millisecondsSinceEpoch;
    if (len < _lastLen) _firstChangeAtMs ??= atMs ?? DateTime.now().millisecondsSinceEpoch;
    _lastLen = len;
  }

  /// 发送后调用：清空，下一条消息重新计。
  void reset() {
    _lastLen = 0;
    _largestInsertion = 0;
    _firstChangeAtMs = null;
  }

  /// 组装成 core 可判定的证据（[totalChars] 用发送那一刻的实际长度）。
  ComposeEvidence evidence({required int totalChars, int? nowMs}) {
    final start = _firstChangeAtMs;
    final end = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return ComposeEvidence(
      source: PresenceSource.composer,
      totalChars: totalChars,
      largestInsertionChars: _largestInsertion,
      composeMs: start == null ? 0 : (end - start),
    );
  }
}

// ---------------------------------------------------------------- 在场信号

/// 一条已签名、有有效期的在场信号。"可见"= 对方能读到；"不可伪造"= 必须验签。
class PresenceSignal {
  final String fromId; // 谁到场了（分身 ID）
  final String toId; // 发给谁
  final String path; // typed / ...
  final int atMs; // 到场时刻
  final int expiresAtMs; // 有效期（过期的信号不再显示）
  final String? sig;
  final String? fromPub;

  const PresenceSignal({
    required this.fromId,
    required this.toId,
    required this.path,
    required this.atMs,
    required this.expiresAtMs,
    this.sig,
    this.fromPub,
  });

  /// 在场窗口。PRD 把"自动过期"划归 P1，但**信号本身必须带期限**——
  /// 否则"本人在线"会永远挂着，那是假信号（比不显示更糟）。
  static const Duration validWindow = Duration(minutes: 30);

  bool isFreshAt(int nowMs) => nowMs <= expiresAtMs;

  String canonical() => 'PRESENCE|$fromId|$toId|$path|$atMs|$expiresAtMs';

  Map<String, Object?> toMap() => {
        'from': fromId,
        'to': toId,
        'path': path,
        'at': atMs,
        'exp': expiresAtMs,
        'sig': sig,
        'pub': fromPub,
      };
}

/// 在场信号线格式：`{"da_type":"presence","v":1,"d":{...}}`。
class PresenceWire {
  static const String daType = 'presence';
  static const int version = 1;

  static String encode(PresenceSignal s) => jsonEncode({
        'da_type': daType,
        'v': version,
        'd': s.toMap(),
      });

  /// 不是在场报文 → null（调用方应交给后续环节）。
  static PresenceSignal? tryParse(String text) {
    if (text.length > 2048) return null;
    if (!text.trimLeft().startsWith('{')) return null;
    Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      root = decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    if (root['da_type'] != daType) return null;
    if (root['v'] != version) return null;
    final d = root['d'];
    if (d is! Map) return null;
    final m = d.cast<String, dynamic>();
    final from = m['from']?.toString() ?? '';
    final to = m['to']?.toString() ?? '';
    final sig = m['sig']?.toString();
    final pub = m['pub']?.toString();
    if (from.isEmpty || to.isEmpty || sig == null || pub == null) return null;
    return PresenceSignal(
      fromId: from,
      toId: to,
      path: m['path']?.toString() ?? 'typed',
      atMs: (m['at'] as num?)?.toInt() ?? 0,
      expiresAtMs: (m['exp'] as num?)?.toInt() ?? 0,
      sig: sig,
      fromPub: pub,
    );
  }
}

// ------------------------------------------------------------ 存储抽象

/// 在场信号的落库（每个 peer 只保留**最新一条**：在场是状态，不是流水）。
abstract class PresenceStore {
  Future<void> upsert(PresenceSignal s);

  /// 该 peer 最新一条信号（可能已过期，调用方用 isFreshAt 判）。
  Future<PresenceSignal?> latestOf(String fromId);

  /// 当前**未过期**的全部 peer —— UI 一次查完，避免名册里逐人查（N 次 IO）。
  Future<List<String>> freshPeers(int nowMs);

  Future<void> clear(String fromId);
}

class MemoryPresenceStore implements PresenceStore {
  final Map<String, PresenceSignal> _rows = {};
  @override
  Future<void> upsert(PresenceSignal s) async => _rows[s.fromId] = s;
  @override
  Future<PresenceSignal?> latestOf(String fromId) async => _rows[fromId];
  @override
  Future<List<String>> freshPeers(int nowMs) async =>
      [for (final e in _rows.entries) if (e.value.isFreshAt(nowMs)) e.key];
  @override
  Future<void> clear(String fromId) async => _rows.remove(fromId);
}

/// 自报身份账本（铁律 1：**一次性披露**——与新对象的第一条消息自报家门，之后不重复）。
abstract class SelfIntroStore {
  /// 是否已对 [peerId] 自报过身份。
  Future<bool> hasIntroduced(String peerId);

  /// 记账（幂等：重复调用不报错）。返回**本次是否首次**。
  Future<bool> markIntroduced(String peerId, int atMs);

  Future<int> count();
}

class MemorySelfIntroStore implements SelfIntroStore {
  final Map<String, int> _rows = {};
  @override
  Future<bool> hasIntroduced(String peerId) async => _rows.containsKey(peerId);
  @override
  Future<bool> markIntroduced(String peerId, int atMs) async {
    if (_rows.containsKey(peerId)) return false;
    _rows[peerId] = atMs;
    return true;
  }

  @override
  Future<int> count() async => _rows.length;
}

/// 一次性披露服务：只管"该不该自报"，**文案由 UI 层用 l10n 渲染**
/// （core 零平台依赖，不碰本地化）。
class SelfIntroService {
  final SelfIntroStore store;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  SelfIntroService({required this.store, this.onEvent});

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// 与新对象的第一条消息前必须自报；**对方已声明"只接受真人"时不发**
  /// （铁律 3 优先：分身只能转达，不能替他开口）——由调用方传 noIntro 决定。
  Future<bool> needsSelfIntro(String peerId, {bool noIntro = false}) async {
    if (noIntro) return false;
    if (peerId.isEmpty) return false;
    return !await store.hasIntroduced(peerId);
  }

  /// 记账。埋点 `self_intro_sent` 只在**真的首次**发出时产一次（不重复披露）。
  Future<bool> markIntroduced(String peerId) async {
    final first = await store.markIntroduced(peerId, _now());
    if (first) {
      onEvent?.call('self_intro_sent', {'peer': peerId});
    }
    return first;
  }

  Future<int> introducedCount() => store.count();

  /// 自报身份的文案（铁律 1：首次接触必须让人无歧义地知道"对面是分身"）。
  ///
  /// 放在 core 而不用 ARB：这条文本要**跨设备**发出去，收件方语言未知，
  /// 所以按**发送方语言**生成原文并随消息一起送达（跨语言本地化留 P1）。
  static String declaration({
    required String agentName,
    required String ownerName,
    String lang = 'zh',
  }) {
    // ⚠️ 兜底名**必须随语言**：曾把 `agentName.isEmpty ? '分身' : ...` 算在 lang 分支**之前**，
    //    于是 `lang:'en'` 且没昵称时，英文披露里会掺进中文「分身」——
    //    对一个只会英文的收件人，这一句等于**没披露**（铁律 1 的三道护栏同时失效）。
    //    断言见 `tool/verify_presence.dart`（英文披露**整串不得含 CJK**）。
    if (lang == 'en') {
      final a = agentName.isEmpty ? 'a digital agent' : agentName;
      final o = ownerName.isEmpty ? 'my owner' : ownerName;
      return "Hi, I'm $a — $o's assistant agent. I speak on ${ownerName.isEmpty ? 'their' : "$o's"} "
          'behalf; ${ownerName.isEmpty ? 'they' : o} will step in for anything that matters.';
    }
    final a = agentName.isEmpty ? '分身' : agentName;
    // 主人称呼**是**采集过的（onboarding 第 3 步 + 设置页 + `set_master_name` 工具，
    // 统一写 prefs['soul_master_name']）。这里为空只可能是调用方没把值传进来，
    // 所以退化为"我主人"——**不编造名字**。
    // （历史注释误写为"onboarding 尚未收这一步"，实际未采集的是读取侧的接线，
    //   见 `agent_service.dart#_withSelfIntro` 与 `tool/verify_data_keys.dart`。）
    final owner = ownerName.isEmpty ? '我主人' : ownerName;
    return '你好，我是「$a」——$owner 的分身。'
        '${ownerName.isEmpty ? "我主人" : owner} 让我先开口，真正重要的事由本人来定。';
  }
}

// ---------------------------------------------------------------- 在场中继

/// 在场信号的中继：发出（签名）+ 入站（验签 fail-closed）。
///
/// 与 M2/M3 同款纪律：**验签不过就丢**，一律留痕，绝不因为"看着像"就采信。
class PresenceRelay {
  final PresenceStore store;
  final Future<bool> Function(String target, String wire) send;
  final Signer signer;
  final Future<String> Function()? selfId;
  final void Function(String name, Map<String, Object?> props)? onEvent;

  PresenceRelay({
    required this.store,
    required this.send,
    required this.signer,
    this.selfId,
    this.onEvent,
  });

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// 主人亲手打字后调用：签发一条带期限的在场信号并发出。
  Future<bool> dispatch({
    required String toId,
    required String path,
    int? atMs,
  }) async {
    final me = selfId == null ? '' : await selfId!();
    if (me.isEmpty || toId.isEmpty) return false;
    final at = atMs ?? _now();
    final base = PresenceSignal(
      fromId: me,
      toId: toId,
      path: path,
      atMs: at,
      expiresAtMs: at + PresenceSignal.validWindow.inMilliseconds,
    );
    try {
      final sig = await signer.signBytes(utf8.encode(base.canonical()));
      final pub = await signer.publicKeyBase58();
      final signed = PresenceSignal(
        fromId: base.fromId,
        toId: base.toId,
        path: base.path,
        atMs: base.atMs,
        expiresAtMs: base.expiresAtMs,
        sig: sig,
        fromPub: pub,
      );
      final ok = await send(toId, PresenceWire.encode(signed));
      onEvent?.call(
        ok ? 'presence_dispatched' : 'presence_dropped',
        {
          'self': me,
          'peer': toId,
          'path': path,
          if (!ok) 'reason': 'no_channel',
        },
      );
      return ok;
    } catch (_) {
      onEvent?.call('presence_dropped',
          {'self': me, 'peer': toId, 'reason': 'sign_failed'});
      return false;
    }
  }

  /// 入站。返回 **true = 这是在场的报文，已被消费**（不要再进聊天流水线）；
  /// false = 不是在场报文。**验签失败也返回 true**（已消费并丢弃）。
  Future<bool> onIncoming(String fromAgentId, String text) async {
    final s = PresenceWire.tryParse(text);
    if (s == null) return false;

    final me = selfId == null ? '' : await selfId!();
    void drop(String reason) => onEvent?.call('presence_dropped', {
          'self': me,
          'peer': fromAgentId,
          'reason': reason,
        });

    if (s.fromId != fromAgentId) {
      drop('sender_mismatch'); // 冒名 → 丢弃
      return true;
    }
    if (me.isNotEmpty && s.toId != me) {
      drop('misrouted');
      return true;
    }
    final ok = await AgentProtocol.verifyRawSignature(
      utf8.encode(s.canonical()),
      s.sig!,
      s.fromPub!,
    );
    if (!ok) {
      drop('bad_signature');
      return true;
    }
    // 过期信号不落库：显示一个过期的"到场"比不显示更糟。
    if (!s.isFreshAt(_now())) {
      drop('expired');
      return true;
    }
    await store.upsert(s);
    onEvent?.call('presence_received', {
      'self': me,
      'peer': s.fromId,
      'path': s.path,
    });
    return true;
  }

  /// 该 peer 此刻是否"本人在线"（信号存在、验过签、且未过期）。
  Future<bool> peerIsPresent(String peerId) async {
    final s = await store.latestOf(peerId);
    if (s == null) return false;
    return s.isFreshAt(_now());
  }

  /// 当前未过期的全部在场 peer（UI 名册一次取完）。
  Future<Set<String>> freshPeers() async => (await store.freshPeers(_now())).toSet();
}
