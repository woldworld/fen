import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dahuang_ai/core/background_duty_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('值班锁（跨 isolate 互斥的地基）', () {
    test('空闲时能抢到；持有期间别人抢不到', () async {
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isTrue);
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isFalse);
    });

    test('释放后可再抢', () async {
      await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2));
      await BackgroundDuty.releaseLock();
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isTrue);
    });

    test('TTL 过期后旧持有者不算数（进程被杀的兜底）', () async {
      // 直接落一个"已过期"的时间戳模拟上一位持有者死亡
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('duty_heartbeat_lock_until_ms',
          DateTime.now().millisecondsSinceEpoch - 1000);
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isTrue);
    });

    test('迟到的释放不放掉别人的锁（属主令牌）', () async {
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isTrue);
      // 模拟：锁超时被别人抢走（对方写了自己的令牌）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('duty_heartbeat_lock_token', 'someone-else');
      // 我方此刻才放锁——属主校验必须拒绝这次释放
      await BackgroundDuty.releaseLock();
      expect(
          await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isFalse,
          reason: '别人的锁还在持有期内，我方迟到释放不得清掉它');
    });
  });

  group('心跳编排（全桩注入）', () {
    test('抢不到锁 → 整场放弃，一个桩都不该跑', () async {
      await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2));
      var ran = false;
      final r = await BackgroundDuty.runHeartbeat(
        initAgentFn: () async => ran = true,
        flushOutboxFn: () async {
          ran = true;
          return 1;
        },
        pullMailboxFn: (_) async => ran = true,
      );
      expect(r.lockSkipped, isTrue);
      expect(ran, isFalse);
    });

    test('无 API Key：跳过 initAgent 与邮箱（防光标被推走吞信），outbox 照常', () async {
      var initAgentRan = false;
      var mailboxPulled = false;
      var flushed = 0;
      final r = await BackgroundDuty.runHeartbeat(
        hasApiKeyFn: () async => false,
        initAgentFn: () async => initAgentRan = true,
        initRuntimeFn: () async {},
        flushOutboxFn: () async => flushed = 7,
        pullMailboxFn: (_) async => mailboxPulled = true,
        agentIdFn: () async => 'AG-TEST',
      );
      expect(initAgentRan, isFalse);
      expect(mailboxPulled, isFalse);
      expect(r.outboxSent, 7);
      expect(flushed, 7);
      // 锁必须被释放（finally 纪律）
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isTrue);
    });

    test('有 Key：initAgent → outbox → 邮箱 全链路跑通', () async {
      final order = <String>[];
      final r = await BackgroundDuty.runHeartbeat(
        hasApiKeyFn: () async => true,
        initAgentFn: () async => order.add('agent'),
        initRuntimeFn: () async => order.add('runtime'),
        flushOutboxFn: () async {
          order.add('flush');
          return 3;
        },
        pullMailboxFn: (_) async => order.add('mailbox'),
        agentIdFn: () async => 'AG-TEST',
        cloudChannelOnFn: () async => true,
        drainRepliesFn: () async => order.add('drain'),
      );
      expect(order, ['agent', 'runtime', 'flush', 'mailbox', 'drain'],
          reason: '★ 排空必须在邮箱拉取之后——Workmanager 引擎在 future 返回后立即销毁');
      expect(r.agentReady, isTrue);
      expect(r.runtimeReady, isTrue);
      expect(r.outboxSent, 3);
      expect(r.mailboxPulled, isTrue);
    });

    test('用户意志闸：云端通道关闭 → 不拉邮箱（outbox 是公示承诺，照常）', () async {
      var mailboxPulled = false;
      var flushed = 0;
      final r = await BackgroundDuty.runHeartbeat(
        hasApiKeyFn: () async => true,
        initAgentFn: () async {},
        initRuntimeFn: () async {},
        flushOutboxFn: () async => flushed = 2,
        pullMailboxFn: (_) async => mailboxPulled = true,
        agentIdFn: () async => 'AG-TEST',
        cloudChannelOnFn: () async => false,
        drainRepliesFn: () async {},
      );
      expect(mailboxPulled, isFalse,
          reason: '用户关掉云端通道后拉邮箱 = 回复发不出去还吞信 + 绕过隐私选择');
      expect(r.mailboxPulled, isFalse);
      expect(r.outboxSent, 2);
      expect(flushed, 2, reason: 'outbox 是公示承诺：云端通道关掉也照常发送');
    });

    test('任一步抛异常不带走整场：runtime 崩了只牺牲 outbox；agent 崩了邮箱也不拉（防吞信）', () async {
      final r = await BackgroundDuty.runHeartbeat(
        hasApiKeyFn: () async => true,
        initAgentFn: () async => throw StateError('boom'),
        initRuntimeFn: () async => throw StateError('boom'),
        flushOutboxFn: () async => 0,
        pullMailboxFn: (_) async {},
        agentIdFn: () async => 'AG-TEST',
      );
      expect(r.agentReady, isFalse);
      expect(r.runtimeReady, isFalse);
      // runtime init 失败 ⇒ outbox 未尝试（-1）；回复管线没起来 ⇒ 邮箱不拉
      //（拉了只会把光标推走、消息被吞）——这正是无 Key 跳过的同一条纪律。
      expect(r.outboxSent, -1);
      expect(r.mailboxPulled, isFalse);
      expect(await BackgroundDuty.acquireLock(ttl: const Duration(minutes: 2)),
          isTrue);
    });

    test('agentId 为空：不拉邮箱也不崩', () async {
      var pulled = false;
      final r = await BackgroundDuty.runHeartbeat(
        hasApiKeyFn: () async => true,
        initAgentFn: () async {},
        initRuntimeFn: () async {},
        flushOutboxFn: () async => 0,
        pullMailboxFn: (_) async => pulled = true,
        agentIdFn: () async => '',
      );
      expect(pulled, isFalse);
      expect(r.mailboxPulled, isFalse);
    });
  });
}
