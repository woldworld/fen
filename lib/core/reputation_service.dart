import 'dart:convert';

import 'agent_identity.dart';
import 'agent_protocol.dart';
import 'db_helper.dart';
import 'l10n_holder.dart';

/// 信誉体系（Step 5）：本地、单向、按关系的主观打分（0-100）。
///
/// 设计取舍：信誉是"我方对某个节点的局部观察"，**绝不上报 Hub / 写入 Agent Card**——
/// 自报的全局信誉分天然可刷分（注册一堆小号互送好评即可），只有本地主观信誉
/// 叠加 8 位指纹人工核验才可信。跨设备信任背书（签名推荐信）留待后续版本。
///
/// 计分规则：
/// - 默认 50；握手成功 +6，每轮正常往来 +1（每日封顶 5），收到礼物 +3，送出礼物 +1
/// - 出站草稿被网关拦截 -5，入站握手被网关拒绝 -15，本地通道身份攻击（TOFU 换绑）-100
/// - 闲置衰减：每闲置 7 天 -1，但衰减不把分数打到 30 以下（老朋友不会因没聊天变敌人）
/// - 等级建议只做"提示"，tier 变更仍由主人确认——自动升降级会绕过人工安全判断
class ReputationService {
  ReputationService._();
  static final ReputationService instance = ReputationService._();

  static const int defaultScore = 50;
  static const int exchangeDailyCap = 5;

  /// 推荐信签发门槛：只给本地信誉 ≥ 80（好友档上限）的节点签发
  static const int recoIssueThreshold = 80;

  /// 事件 -> 增量（纯数据，单测钉住）
  static const Map<String, int> deltas = {
    'handshake_accepted': 6,
    'exchange': 1,
    'gift_received': 3,
    'gift_sent': 1,
    'outbound_blocked': -5,
    'handshake_rejected': -15,
    'identity_attack': -100,
  };

  // 往来加分的每日计数（内存即可：重启清零只影响当日上限，不影响分数本身）
  final Map<String, _DailyCounter> _exchangeCounts = {};

  // ---------- 纯规则（可单测） ----------
  static int clampScore(int v) => v < 0 ? 0 : (v > 100 ? 100 : v);

  static int applyDelta(int current, String event) {
    final d = deltas[event] ?? 0;
    return clampScore(current + d);
  }

  /// 生效分 = 存储分 - 闲置衰减（每 7 天 -1，下限不低于 30，除非本来就低于 30）
  static int effectiveScore(int stored, int daysIdle) {
    final decayed = stored - (daysIdle ~/ 7);
    final floor = stored < 30 ? stored : 30;
    return clampScore(decayed < floor ? floor : decayed);
  }

  /// 等级建议：返回建议的新 tier，null = 维持现状；'block' = 建议拉黑
  static String? tierSuggestion(int score, String tier) {
    if (score <= 10) return 'block';
    if (score <= 25) {
      if (tier == 'family') return 'friend';
      if (tier == 'friend') return 'stranger';
      return null;
    }
    if (tier == 'stranger' && score >= 70) return 'friend';
    if (tier == 'friend' && score >= 85) return 'family';
    return null;
  }

  // ---------- DB 读写 ----------
  /// 节点不存在时返回 null（调用方跳过：陌生/已删节点不记分不留痕）
  Future<int?> _storedScoreOf(String agentId) async {
    final dbClient = await DBHelper.db;
    final rows = await dbClient.query('agent_friends',
        where: 'agent_id = ?', whereArgs: [agentId], limit: 1);
    if (rows.isEmpty) return null;
    return (rows.first['reputation'] as int?) ?? defaultScore;
  }

  /// 存储分（未知节点返回默认值，仅供展示类查询）
  Future<int> storedScoreOf(String agentId) async =>
      await _storedScoreOf(agentId) ?? defaultScore;

  /// 生效分（含闲置衰减）
  Future<int> scoreOf(String agentId) async {
    final stored = await _storedScoreOf(agentId);
    if (stored == null) return defaultScore;
    final dbClient = await DBHelper.db;
    final rows = await dbClient.query('agent_friends',
        columns: ['last_chat_time'],
        where: 'agent_id = ?', whereArgs: [agentId], limit: 1);
    if (rows.isEmpty) return stored;
    final last = (rows.first['last_chat_time'] as int?) ?? 0;
    final daysIdle = last <= 0
        ? 0
        : DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(last)).inDays;
    return effectiveScore(stored, daysIdle);
  }

  /// 记录一次信誉事件：改分 + 留痕（action_type='rep'，不进聊天上下文）。
  /// 未知节点（不在名册）直接跳过，不记分也不写日志。
  Future<int> recordEvent(String agentId, String event, {String? detail}) async {
    final current = await _storedScoreOf(agentId);
    if (current == null) return -1;
    final next = applyDelta(current, event);
    await DBHelper.updateAgentReputation(agentId, next);
    final delta = deltas[event] ?? 0;
    final deltaStr = '${delta >= 0 ? '+' : ''}$delta';
    final detailStr =
        detail == null ? '' : L10nHolder.l10n.repEventDetailSuffix(detail);
    await DBHelper.insertSocialLog(
        'rep', agentId, L10nHolder.l10n.repEventLog(deltaStr, event, detailStr));
    return next;
  }

  /// 每轮正常往来 +1，每日封顶 exchangeDailyCap（防刷分：疯狂发消息不再涨分）
  Future<void> recordExchange(String agentId) async {
    final day = DateTime.now().toString().substring(0, 10);
    final c = _exchangeCounts.putIfAbsent(
        agentId, () => _DailyCounter());
    if (c.day != day) {
      c.day = day;
      c.count = 0;
    }
    if (c.count >= exchangeDailyCap) return;
    c.count++;
    await recordEvent(agentId, 'exchange');
  }

  /// 礼物：改分 + 计数 + 聊天流水留痕（action_type='gift'，气泡可见）+ 记忆事件。
  /// 未知节点直接跳过。
  Future<void> recordGift(String agentId, {required bool incoming, String gift = '🎁', String note = ''}) async {
    final current = await _storedScoreOf(agentId);
    if (current == null) return;
    await recordEvent(agentId, incoming ? 'gift_received' : 'gift_sent');
    await DBHelper.bumpGiftCounters(agentId, sent: incoming ? 0 : 1, received: incoming ? 1 : 0);
    final noteLog = note.isEmpty ? '' : L10nHolder.l10n.repGiftNoteQuoted(note);
    await DBHelper.insertSocialLog(
        'gift',
        agentId,
        incoming
            ? L10nHolder.l10n.repGiftLogIncoming(gift, noteLog)
            : L10nHolder.l10n.repGiftLogOutgoing(gift, noteLog));
    final dbClient = await DBHelper.db;
    final rows = await dbClient.query('agent_friends',
        columns: ['agent_name'],
        where: 'agent_id = ?', whereArgs: [agentId], limit: 1);
    final name = rows.isEmpty ? agentId : (rows.first['agent_name']?.toString() ?? agentId);
    final noteMem = note.isEmpty ? '' : L10nHolder.l10n.repGiftMemoryNote(note);
    await DBHelper.insertMemoryEvent(
      eventType: 'social_gift',
      summary: incoming
          ? L10nHolder.l10n.repGiftMemoryIncoming(name, gift, noteMem)
          : L10nHolder.l10n.repGiftMemoryOutgoing(name, gift, noteMem),
      people: name,
    );
  }
}

class _DailyCounter {
  String day = '';
  int count = 0;
}

// ---------------------------------------------------------------------------
// 推荐信（跨设备信任背书 v1）：本地信誉 ≥ 80 的节点可索取一份 Ed25519 签名推荐信。
// 签名覆盖 RECO|<issuer>|<subject>|<score>|<issued_at>，任何持有签发方公钥的
// 第三方都可独立验证；报文必须由签发方本人通道递送，杜绝转手倒卖。
// Hub 级公开背书链路（把推荐信挂到 A2A Agent Card）留待服务端下个版本。
// ---------------------------------------------------------------------------
extension ReputationReco on ReputationService {
  static bool _isStructured(String text, String type) {
    final t = text.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) return false;
    try {
      final d = jsonDecode(t);
      return d is Map && d['da_type'] == type;
    } catch (_) {
      return false;
    }
  }

  /// 判断消息是否为推荐信索取请求（供 AgentService 截获）
  static bool isRecoRequest(String text) => _isStructured(text, 'reco_request');

  /// 判断消息是否为推荐信本体（供 AgentService 截获）
  static bool isReco(String text) => _isStructured(text, 'reco');

  /// 为信誉达标的节点签发推荐信；不达标返回 null（静默忽略，不暴露拒绝原因）
  Future<Map<String, dynamic>?> buildReco(String requesterId) async {
    final score = await scoreOf(requesterId);
    if (score < ReputationService.recoIssueThreshold) return null;
    final myId = await DBHelper.getAmbassador('my_agent_id') ?? '';
    if (myId.isEmpty || myId == requesterId) return null;
    final identity = AgentIdentity();
    final pub = await identity.publicKeyBase58();
    final issuedAt = DateTime.now().millisecondsSinceEpoch;
    final sig = await identity
        .signBase64(utf8.encode('RECO|$myId|$requesterId|$score|$issuedAt'));
    return {
      'da_type': 'reco',
      'issuer': myId,
      'subject': requesterId,
      'score': score,
      'issued_at': issuedAt,
      'pub': pub,
      'sig': sig,
    };
  }

  /// 收到推荐信：验签（签发方身份密钥）+ 主题是本机 + 必须由签发方本人递送，
  /// 通过才存档到社交流水与记忆事件流。存档不改分（防止互刷推荐信涨分）。
  Future<bool> archiveReco(String senderId, String rawJson,
      {required String myId}) async {
    try {
      final d = jsonDecode(rawJson);
      if (d is! Map || d['da_type'] != 'reco') return false;
      final issuer = d['issuer']?.toString() ?? '';
      final subject = d['subject']?.toString() ?? '';
      final score = (d['score'] as num?)?.toInt() ?? -1;
      final issuedAt = (d['issued_at'] as num?)?.toInt() ?? 0;
      final pub = d['pub']?.toString() ?? '';
      final sig = d['sig']?.toString() ?? '';
      if (issuer.isEmpty || issuer != senderId) return false;
      if (subject != myId) return false;
      if (score < 0 || score > 100 || issuedAt <= 0 || pub.isEmpty) return false;
      final ok = await AgentProtocol.verifyRawSignature(
          utf8.encode('RECO|$issuer|$subject|$score|$issuedAt'), sig, pub);
      if (!ok) return false;
      final date =
          DateTime.fromMillisecondsSinceEpoch(issuedAt).toString().substring(0, 10);
      await DBHelper.insertSocialLog(
          'reco', issuer, L10nHolder.l10n.repRecoLog(score, date));
      await DBHelper.insertMemoryEvent(
        eventType: 'social_reco',
        summary: L10nHolder.l10n.repRecoMemory(issuer, score, date),
        people: issuer,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 礼物报文的线上格式：普通消息通道里的一段 JSON。
/// 收方在进入社交决策流水线之前识别并截获，旧版客户端只会把它显示为一条奇怪的消息。
class GiftMessage {
  final String gift;
  final String note;
  const GiftMessage({required this.gift, required this.note});

  static const String _type = 'gift';

  static GiftMessage? tryParse(String text) {
    final t = text.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) return null;
    try {
      final d = jsonDecode(t);
      if (d is! Map || d['da_type'] != _type) return null;
      var g = (d['gift'] ?? '🎁').toString();
      if (g.isEmpty || g.length > 8) g = '🎁';
      var n = (d['note'] ?? '').toString();
      if (n.length > 200) n = n.substring(0, 200);
      return GiftMessage(gift: g, note: n);
    } catch (_) {
      return null;
    }
  }

  static String encode({required String gift, String note = ''}) =>
      jsonEncode({'da_type': _type, 'gift': gift, 'note': note});
}
