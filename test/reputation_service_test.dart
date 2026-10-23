import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/reputation_service.dart';

void main() {
  group('ReputationService 纯规则', () {
    test('clampScore 边界', () {
      expect(ReputationService.clampScore(-5), 0);
      expect(ReputationService.clampScore(0), 0);
      expect(ReputationService.clampScore(50), 50);
      expect(ReputationService.clampScore(100), 100);
      expect(ReputationService.clampScore(150), 100);
    });

    test('事件增量表覆盖所有事件且方向正确', () {
      const positives = ['handshake_accepted', 'exchange', 'gift_received', 'gift_sent'];
      const negatives = ['outbound_blocked', 'handshake_rejected', 'identity_attack'];
      for (final e in positives) {
        expect(ReputationService.deltas[e]!, greaterThan(0), reason: e);
      }
      for (final e in negatives) {
        expect(ReputationService.deltas[e]!, lessThan(0), reason: e);
      }
    });

    test('applyDelta 加减分并夹紧', () {
      // 50 + 6（握手）
      expect(ReputationService.applyDelta(50, 'handshake_accepted'), 56);
      // 50 - 15（握手被拒）
      expect(ReputationService.applyDelta(50, 'handshake_rejected'), 35);
      // 身份攻击直接归零
      expect(ReputationService.applyDelta(50, 'identity_attack'), 0);
      // 顶格不再上涨
      expect(ReputationService.applyDelta(100, 'gift_received'), 100);
      // 未知事件不动分
      expect(ReputationService.applyDelta(50, 'no_such_event'), 50);
    });

    test('闲置衰减：每 7 天 -1，但地板为 max(30, 原分)', () {
      // 50 分闲置 13 天：衰减 1 → 49
      expect(ReputationService.effectiveScore(50, 13), 49);
      // 50 分闲置 700 天：衰减 100 → 地板 30
      expect(ReputationService.effectiveScore(50, 700), 30);
      // 本来就低于 30 的不会被衰减"救活"也不会更低
      expect(ReputationService.effectiveScore(20, 700), 20);
      // 刚聊过天不衰减
      expect(ReputationService.effectiveScore(80, 0), 80);
      // 衰减不会把分数算成负数
      expect(ReputationService.effectiveScore(5, 700), 5);
    });

    test('tierSuggestion：升级、降级与拉黑建议', () {
      // 升级线
      expect(ReputationService.tierSuggestion(70, 'stranger'), 'friend');
      expect(ReputationService.tierSuggestion(69, 'stranger'), isNull);
      expect(ReputationService.tierSuggestion(85, 'friend'), 'family');
      expect(ReputationService.tierSuggestion(84, 'friend'), isNull);
      // 降级线
      expect(ReputationService.tierSuggestion(25, 'friend'), 'stranger');
      expect(ReputationService.tierSuggestion(25, 'family'), 'friend');
      // 陌生人低分维持现状（本来就最严）
      expect(ReputationService.tierSuggestion(25, 'stranger'), isNull);
      // 拉黑线优先于一切
      expect(ReputationService.tierSuggestion(10, 'family'), 'block');
      expect(ReputationService.tierSuggestion(10, 'stranger'), 'block');
      // 正常区间维持
      expect(ReputationService.tierSuggestion(50, 'friend'), isNull);
    });

    test('礼物报文编解码往返 + 防御性解析', () {
      final wire = GiftMessage.encode(gift: '🎂', note: '生日快乐');
      final parsed = GiftMessage.tryParse(wire);
      expect(parsed, isNotNull);
      expect(parsed!.gift, '🎂');
      expect(parsed.note, '生日快乐');

      // 普通聊天消息绝不会被误判为礼物
      expect(GiftMessage.tryParse('你好呀，今天天气不错'), isNull);
      expect(GiftMessage.tryParse('{"da_type":"text","body":"hi"}'), isNull);
      // 坏 JSON / 缺字段安全返回 null
      expect(GiftMessage.tryParse('{da_type: gift'), isNull);
      // 超长备注截断到 200
      final long = GiftMessage.tryParse(GiftMessage.encode(gift: '🎁', note: 'x' * 500));
      expect(long!.note.length, 200);
      // 超长 emoji 字段回退为默认礼物
      expect(GiftMessage.tryParse(GiftMessage.encode(gift: '🎁' * 10))!.gift, '🎁');
    });
  });
}
