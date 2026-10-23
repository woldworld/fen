import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dahuang_ai/core/app_events.dart';
import 'package:dahuang_ai/core/notification_service.dart';
import 'package:dahuang_ai/core/telemetry.dart';

/// 系统通知（0.48.0）的核心断言。
///
/// 分野很清楚：
///   * **该不该发** = 纯函数（[NotificationPolicy]）⇒ 由本文件钉死；
///   * **画到托盘上长什么样** ⇒ 只能真机人工看，不在自动化范围。
///
/// 所以这里覆盖三件事：免打扰窗口（含跨零点）、@我 判定、以及"注入 presenter
/// 后事件真的走到呈现"这一条端到端闸门。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // 免打扰窗口
  // ------------------------------------------------------------------
  group('NotificationPolicy.inQuietHours', () {
    test('起止相同 = 空窗口，永不静音（不能被理解成"全天静音"）', () {
      expect(
        NotificationPolicy.inQuietHours(hour: 3, startHour: 7, endHour: 7),
        isFalse,
      );
    });

    test('同日窗口 [9,17)：含起点、不含终点', () {
      expect(
          NotificationPolicy.inQuietHours(hour: 8, startHour: 9, endHour: 17),
          isFalse);
      expect(
          NotificationPolicy.inQuietHours(hour: 9, startHour: 9, endHour: 17),
          isTrue);
      expect(
          NotificationPolicy.inQuietHours(hour: 16, startHour: 9, endHour: 17),
          isTrue);
      expect(
          NotificationPolicy.inQuietHours(hour: 17, startHour: 9, endHour: 17),
          isFalse);
    });

    test('跨零点窗口 [22,7)：22–23 与 0–6 静音，7 起解除', () {
      for (final h in [22, 23, 0, 1, 6]) {
        expect(
          NotificationPolicy.inQuietHours(hour: h, startHour: 22, endHour: 7),
          isTrue,
          reason: '$h 点应落在 22→7 的免打扰窗口内',
        );
      }
      for (final h in [7, 12, 21]) {
        expect(
          NotificationPolicy.inQuietHours(hour: h, startHour: 22, endHour: 7),
          isFalse,
          reason: '$h 点不该被静音',
        );
      }
    });
  });

  // ------------------------------------------------------------------
  // 总开关 + 免打扰的合成闸门
  // ------------------------------------------------------------------
  group('NotificationPolicy.shouldNotify', () {
    test('总开关关 ⇒ 一律不发（哪怕不在免打扰时段）', () {
      const s = NotificationSettings(
        enabled: false,
        quietEnabled: false,
        quietStartHour: 22,
        quietEndHour: 7,
      );
      expect(NotificationPolicy.shouldNotify(settings: s, hour: 12), isFalse);
    });

    test('免打扰关 ⇒ 任何钟点都发', () {
      const s = NotificationSettings(
        enabled: true,
        quietEnabled: false,
        quietStartHour: 22,
        quietEndHour: 7,
      );
      expect(NotificationPolicy.shouldNotify(settings: s, hour: 3), isTrue);
    });

    test('免打扰开 ⇒ 窗口内不发、窗口外发', () {
      const s = NotificationSettings(
        enabled: true,
        quietEnabled: true,
        quietStartHour: 22,
        quietEndHour: 7,
      );
      expect(NotificationPolicy.shouldNotify(settings: s, hour: 23), isFalse);
      expect(NotificationPolicy.shouldNotify(settings: s, hour: 6), isFalse);
      expect(NotificationPolicy.shouldNotify(settings: s, hour: 7), isTrue);
      expect(NotificationPolicy.shouldNotify(settings: s, hour: 15), isTrue);
    });

    test('出厂默认 = 开通知 + 22–7 免打扰（深夜不打扰是默认姿态）', () {
      expect(NotificationSettings.defaults.enabled, isTrue);
      expect(
        NotificationPolicy.shouldNotify(
            settings: NotificationSettings.defaults, hour: 3),
        isFalse,
      );
      expect(
        NotificationPolicy.shouldNotify(
            settings: NotificationSettings.defaults, hour: 10),
        isTrue,
      );
    });
  });

  // ------------------------------------------------------------------
  // @我 判定
  // ------------------------------------------------------------------
  group('NotificationPolicy.mentionsMe', () {
    test('@分身ID 命中，且大小写不敏感', () {
      expect(
        NotificationPolicy.mentionsMe('喂 @AG-7f3 看一下',
            myAgentId: 'AG-7f3', myNickname: '总管'),
        isTrue,
      );
      expect(
        NotificationPolicy.mentionsMe('喂 @ag-7F3 看一下',
            myAgentId: 'AG-7f3', myNickname: '总管'),
        isTrue,
      );
    });

    test('@昵称 命中', () {
      expect(
        NotificationPolicy.mentionsMe('@总管 在吗',
            myAgentId: 'AG-7f3', myNickname: '总管'),
        isTrue,
      );
    });

    test('广播式呼叫命中', () {
      for (final text in ['@all 开会', '@everyone hi', '@全体 注意', '@所有人 报数']) {
        expect(
          NotificationPolicy.mentionsMe(text,
              myAgentId: 'AG-7f3', myNickname: '总管'),
          isTrue,
          reason: text,
        );
      }
    });

    test('普通发言 / @别人 / 空串 不命中（会客厅不许刷屏）', () {
      expect(
        NotificationPolicy.mentionsMe('今天天气不错',
            myAgentId: 'AG-7f3', myNickname: '总管'),
        isFalse,
      );
      expect(
        NotificationPolicy.mentionsMe('@别人 你好',
            myAgentId: 'AG-7f3', myNickname: '总管'),
        isFalse,
      );
      expect(
        NotificationPolicy.mentionsMe('',
            myAgentId: 'AG-7f3', myNickname: '总管'),
        isFalse,
      );
    });

    test('身份为空时不会因空串误命中', () {
      expect(
        NotificationPolicy.mentionsMe('@ 有人吗', myAgentId: '', myNickname: ''),
        isFalse,
      );
    });
  });

  // ------------------------------------------------------------------
  // 端到端闸门：事件 → 策略 → presenter
  // ------------------------------------------------------------------
  group('NotificationService 闸门（注入 presenter + 固定时钟）', () {
    final svc = NotificationService.i;
    late List<NotificationRequest> seen;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      seen = <NotificationRequest>[];
      await svc.detach();
      await svc.init(presenter: (r) async => seen.add(r));
      svc.debugSetSelfIdentity(agentId: 'AG-me', nickname: '总管');
    });

    tearDown(() async {
      await svc.detach();
    });

    /// 事件经 broadcast stream + 异步派发，等一拍再断言。
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('会客厅：@我 弹一条；普通房间发言一条都不弹', () async {
      svc.clock = () => DateTime(2026, 1, 1, 12, 0);
      svc.attach();

      AppEvents.emit(WorldRoomMessageEvent(
        roomId: 'r1',
        senderAgentId: 'AG-x',
        nickname: '老王',
        message: '@总管 在吗',
        sourceMsgId: 'room-a',
      ));
      await settle();
      expect(seen.length, 1, reason: '被点名就该弹');
      expect(seen.first.body, contains('老王'), reason: '正文要带上是谁在叫');

      AppEvents.emit(WorldRoomMessageEvent(
        roomId: 'r1',
        senderAgentId: 'AG-x',
        nickname: '老王',
        message: '今天天气不错',
        sourceMsgId: 'room-b',
      ));
      await settle();
      expect(seen.length, 1, reason: '普通房间发言不该打扰主人');
    });

    test('去重：同一 sourceMsgId 被重复投递（多通道）只弹一次', () async {
      svc.clock = () => DateTime(2026, 1, 1, 12, 0);
      svc.attach();

      WorldRoomMessageEvent ev() => WorldRoomMessageEvent(
            roomId: 'r2',
            senderAgentId: 'AG-x',
            nickname: '老王',
            message: '@总管 ping',
            sourceMsgId: 'room-dup',
          );
      AppEvents.emit(ev());
      AppEvents.emit(ev());
      await settle();
      expect(seen.length, 1);
    });

    test('免打扰窗口内：一条都不弹', () async {
      svc.clock = () => DateTime(2026, 1, 1, 3, 0);
      svc.attach();

      AppEvents.emit(WorldRoomMessageEvent(
        roomId: 'r3',
        senderAgentId: 'AG-x',
        nickname: '老王',
        message: '@总管 快看',
        sourceMsgId: 'room-night',
      ));
      await settle();
      expect(seen, isEmpty, reason: '默认 22–7 免打扰，凌晨三点必须安静');
    });

    test('待我确认：建议卡落库事件会弹通知', () async {
      svc.clock = () => DateTime(2026, 1, 1, 12, 0);
      svc.attach();

      AppEvents.emit(AgentActionPendingEvent(
        actionType: 'pending_approval',
        targetId: 'AG-x',
        detail: '你好呀，初次见面',
      ));
      await settle();
      expect(seen.length, 1);
    });
  });

  // ------------------------------------------------------------------
  // 后台 isolate 装配（0.49.0）：心跳 isolate 里那独立的一份
  // ------------------------------------------------------------------
  group('NotificationService.attachInBackgroundIsolate', () {
    final svc = NotificationService.i;
    late List<NotificationRequest> seen;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      seen = <NotificationRequest>[];
      await svc.detach();
    });

    tearDown(() async {
      await svc.detach();
      Telemetry.unbind();
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('装配后本 isolate 的私聊事件能触发通知（后台那份不是空壳）', () async {
      svc.clock = () => DateTime(2026, 1, 1, 12, 0);
      final ok = await svc.attachInBackgroundIsolate(
        presenter: (r) async => seen.add(r),
      );
      expect(ok, isTrue, reason: '注入了 presenter 就该拿到可用呈现器');
      expect(svc.isAttached, isTrue);

      AppEvents.emit(SocialMessageReceivedEvent(
        senderAgentId: 'AG-peer',
        message: '在吗',
        channel: 'cloud',
        sourceMsgId: 'bg-soc-1',
      ));
      await settle();
      expect(seen.length, 1, reason: 'AppEvents 路径在后台 isolate 也必须生效');
    });

    test('委托到达（Telemetry 旁路）也会弹 —— 心跳期间最主要的入站信号', () async {
      svc.clock = () => DateTime(2026, 1, 1, 12, 0);
      await svc.attachInBackgroundIsolate(
        presenter: (r) async => seen.add(r),
      );
      Telemetry.bind(MemoryTelemetryStore());

      Telemetry.instance!.track('delegation_received',
          props: <String, Object?>{'delegation_id': 'd-1', 'peer': 'AG-peer'});
      await settle();
      expect(seen.length, 1, reason: '委托到达是心跳期间最该召回的一件事');
      expect(seen.first.body, contains('AG-peer'));
    });

    test('真插件不可用时静默降级、绝不抛（心跳不能被通知带崩）', () async {
      // 测试 VM 上方法通道无人应答 ⇒ 插件初始化失败；契约是它被吞掉并返回 false，
      // 而不是把异常抛给心跳。
      final ok = await svc.attachInBackgroundIsolate();
      expect(ok, isFalse, reason: '无平台通道 ⇒ 拿不到呈现器，应静默降级');
      expect(svc.isAttached, isTrue, reason: '旁听仍要挂上');
    });
  });
}
