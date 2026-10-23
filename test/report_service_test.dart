import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/report_service.dart';

/// 举报工单核心层的单元测试。
///
/// 与 `tool/verify_report_service.dart` / `tool/verify_report_hub.js` 的分工：
///   - `tool/verify_report_service.dart` 是**交付验收口径**（纯 `dart run`，可离线复算全部判定，
///     并留下跨语言探针）；
///   - `tool/verify_report_hub.js` 钉住 **Dart ↔ Node 逐字节一致**（单语言测试永远发现不了）；
///   - 这里把**最容易被后续改动打破的语义**固化成回归测试（改坏了 CI 会红）。
/// 三者都在，是刻意的重复：一个保证"离线可复算"，一个保证"跨语言不漂移"，一个保证"CI 会红"。
void main() {
  group('wire 值：枚举名不是 wire 值', () {
    test('★ 事由的 wire 值是 snake_case（曾写成 Dart 枚举名，5 个事由死了 2 个）', () {
      // ⚠️ 这条断言是本文件**最贵**的一条：它守的是一个**静默**缺陷 ——
      //   Dart 侧写 `illegalContent`、协议包写 `illegal_content` 时，
      //   客户端提交这一类事由会被服务端 400 拒收，而**界面只显示"提交失败"**，
      //   用户根本不知道是自己选的事由被拒。没有任何报错会浮上来。
      expect(ReportReason.spam.id, 'spam');
      expect(ReportReason.harassment.id, 'harassment');
      expect(ReportReason.illegalContent.id, 'illegal_content');
      expect(ReportReason.fakeIdentity.id, 'fake_identity');
      expect(ReportReason.other.id, 'other');
    });

    test('★ 状态的 wire 值是 snake_case（曾把 in_review 回落成 open）', () {
      expect(ReportStatus.open.id, 'open');
      expect(ReportStatus.triaged.id, 'triaged');
      expect(ReportStatus.inReview.id, 'in_review');
      expect(ReportStatus.actioned.id, 'actioned');
      expect(ReportStatus.rejected.id, 'rejected');
      expect(ReportStatus.appealed.id, 'appealed');
      expect(ReportStatus.closed.id, 'closed');
      expect(ReportStatus.withdrawn.id, 'withdrawn');
    });

    test('fromId 往返：wire 值 → 枚举 → wire 值（8 态全对）', () {
      for (final s in ReportStatus.values) {
        expect(ReportStatus.fromId(s.id), s, reason: '${s.id} 往返失败');
      }
      for (final r in ReportReason.values) {
        expect(ReportReason.fromId(r.id), r, reason: '${r.id} 往返失败');
      }
    });

    test('未知 wire 值 fail-safe 回落（不抛异常）', () {
      expect(ReportStatus.fromId('__nope__'), ReportStatus.open);
      expect(ReportStatus.fromId(null), ReportStatus.open);
      expect(ReportReason.fromId('__nope__'), ReportReason.other);
      expect(ReportReason.fromId(null), ReportReason.other);
    });

    test('★ 枚举名 ≠ wire 值（防止有人把 name 当 wire 用）', () {
      expect(ReportReason.illegalContent.name, 'illegalContent');
      expect(ReportReason.illegalContent.id, isNot(ReportReason.illegalContent.name));
      expect(ReportStatus.inReview.name, 'inReview');
      expect(ReportStatus.inReview.id, isNot(ReportStatus.inReview.name));
    });
  });

  group('四条硬规矩', () {
    test('★ 规矩 2：rejected 必须带理由（空理由 = 没有流程）', () {
      final noReason = ReportAuthority.transitionDecision(
        from: ReportStatus.inReview,
        to: ReportStatus.rejected,
        actor: ReportActor.admin,
      );
      expect(noReason.accept, isFalse);
      expect(noReason.code, ReportTransitionCode.reasonRequired);

      final withReason = ReportAuthority.transitionDecision(
        from: ReportStatus.inReview,
        to: ReportStatus.rejected,
        actor: ReportActor.admin,
        reason: '不属于本流程管辖',
      );
      expect(withReason.accept, isTrue);
      expect(withReason.code, ReportTransitionCode.accepted);
    });

    test('★ 规矩 2：只含空白的理由也算没给', () {
      final r = ReportAuthority.transitionDecision(
        from: ReportStatus.inReview,
        to: ReportStatus.rejected,
        actor: ReportActor.admin,
        reason: '   ',
      );
      expect(r.accept, isFalse);
      expect(r.code, ReportTransitionCode.reasonRequired);
    });

    test('★ 规矩 4：申诉只允许一轮', () {
      final first = ReportAuthority.transitionDecision(
        from: ReportStatus.rejected,
        to: ReportStatus.appealed,
        actor: ReportActor.reporter,
        appealCount: 0,
      );
      expect(first.accept, isTrue);

      final second = ReportAuthority.transitionDecision(
        from: ReportStatus.rejected,
        to: ReportStatus.appealed,
        actor: ReportActor.reporter,
        appealCount: 1,
      );
      expect(second.accept, isFalse);
      expect(second.code, ReportTransitionCode.appealExhausted);
    });

    test('★ 规矩 4：复核后也不能再申诉一轮（appealCount 已 =1）', () {
      final r = ReportAuthority.transitionDecision(
        from: ReportStatus.appealed,
        to: ReportStatus.inReview,
        actor: ReportActor.admin,
        appealCount: 1,
      );
      expect(r.accept, isTrue, reason: 'appealed → in_review 是复核边，允许');
      // 复核完回到 rejected 后再申诉 —— 计数已是 1 ⇒ 拒
      final again = ReportAuthority.transitionDecision(
        from: ReportStatus.rejected,
        to: ReportStatus.appealed,
        actor: ReportActor.reporter,
        appealCount: 1,
      );
      expect(again.accept, isFalse);
      expect(again.code, ReportTransitionCode.appealExhausted);
    });

    test('★ 规矩 3：被举报人视角**结构上**拿不到举报人身份与举报内容', () {
      final t = ReportTicket(
        ticketId: 'RPT-0123456789AB',
        reporterPub: 'REPORTER-PUB',
        targetId: 'bob',
        reason: ReportReason.harassment,
        contentHash: 'a' * 64,
        detail: '举报人写的私密附注',
        createdAtMs: 1700000000000,
        status: ReportStatus.actioned,
        action: 'restrict',
      );
      final pub = ReportAuthority.publicViewOf(t).toMap();
      expect(pub.containsKey('reporter_pub'), isFalse,
          reason: '公开视角不得含举报人公钥');
      expect(pub.containsKey('detail'), isFalse,
          reason: '公开视角不得含举报内容');
      expect(pub.containsKey('content_hash'), isFalse,
          reason: '公开视角不得含被举报内容哈希');
      expect(pub['status'], 'actioned');
      expect(pub['action'], 'restrict');

      // 举报人**自己**看得回自己写的东西
      final mine = t.toReporterView();
      expect(mine['detail'], '举报人写的私密附注');
      expect(mine['reason'], 'harassment');
    });

    test('★ 规矩 1：判定不通过 ⇒ **不写审计**（没发生的事不留痕）', () {
      final events = <ReportAuditRecord>[];
      final svc = ReportService(onEvent: events.add);

      final bad = svc.applyTransition(
        ticket: _ticket(),
        to: ReportStatus.actioned,
        actor: ReportActor.admin,
        atMs: 1,
        reason: '',
      );
      expect(bad, isNull, reason: 'open → actioned 不是合法边');
      expect(events, isEmpty, reason: '没发生的转移不许留痕');

      final good = svc.applyTransition(
        ticket: _ticket(),
        to: ReportStatus.triaged,
        actor: ReportActor.admin,
        atMs: 2,
        reason: '属本流程管辖',
      );
      expect(good, isNotNull);
      expect(events.length, 1);
      expect(events.single.from, 'open');
      expect(events.single.to, 'triaged');
      expect(events.single.actor, 'admin');
      expect(events.single.atMs, 2);
    });

    test('规矩 1：审计记录形状只有一份（toMap 键序固定）', () {
      final rec = ReportAuditRecord(
        ticketId: 'RPT-0123456789AB',
        from: 'open',
        to: 'triaged',
        atMs: 1700000000001,
        actor: 'admin',
        reason: 'in scope',
      );
      expect(rec.toMap().keys.toList(),
          ['ticket_id', 'from', 'to', 'at', 'actor', 'reason']);
      final back = ReportAuditRecord.fromMap(rec.toMap());
      expect(back.ticketId, rec.ticketId);
      expect(back.from, rec.from);
      expect(back.to, rec.to);
      expect(back.atMs, rec.atMs);
      expect(back.actor, rec.actor);
      expect(back.reason, rec.reason);
    });
  });

  group('状态机：边与发起方', () {
    test('合法边全通（open → triaged → in_review → actioned → closed）', () {
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.open,
                to: ReportStatus.triaged,
                actor: ReportActor.admin)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.triaged,
                to: ReportStatus.inReview,
                actor: ReportActor.admin)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.inReview,
                to: ReportStatus.actioned,
                actor: ReportActor.admin)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.actioned,
                to: ReportStatus.closed,
                actor: ReportActor.admin)
            .accept,
        isTrue,
      );
    });

    test('非法边一律 bad_transition（终局态没有出边）', () {
      final r = ReportAuthority.transitionDecision(
        from: ReportStatus.closed,
        to: ReportStatus.inReview,
        actor: ReportActor.admin,
      );
      expect(r.accept, isFalse);
      expect(r.code, ReportTransitionCode.badTransition);

      final w = ReportAuthority.transitionDecision(
        from: ReportStatus.withdrawn,
        to: ReportStatus.triaged,
        actor: ReportActor.admin,
      );
      expect(w.accept, isFalse);
      expect(w.code, ReportTransitionCode.badTransition);
    });

    test('withdrawn 只有举报人能发起', () {
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.open,
                to: ReportStatus.withdrawn,
                actor: ReportActor.reporter)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.open,
                to: ReportStatus.withdrawn,
                actor: ReportActor.admin)
            .accept,
        isFalse,
      );
    });

    test('被驳回后申诉的是**举报人**（不是被举报人）', () {
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.rejected,
                to: ReportStatus.appealed,
                actor: ReportActor.reporter)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.rejected,
                to: ReportStatus.appealed,
                actor: ReportActor.target)
            .accept,
        isFalse,
        reason: '被举报人对"驳回"没有申诉权（驳回不是对他的处置）');
    });

    test('已处置后申诉的是**被举报人**（不是举报人）', () {
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.actioned,
                to: ReportStatus.appealed,
                actor: ReportActor.target)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.actioned,
                to: ReportStatus.appealed,
                actor: ReportActor.reporter)
            .accept,
        isFalse,
        reason: '举报人对"已处置"没有申诉权');
    });

    test('复核（appealed → in_review）只有运营能发起', () {
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.appealed,
                to: ReportStatus.inReview,
                actor: ReportActor.admin)
            .accept,
        isTrue,
      );
      expect(
        ReportAuthority.transitionDecision(
                from: ReportStatus.appealed,
                to: ReportStatus.inReview,
                actor: ReportActor.reporter)
            .accept,
        isFalse,
      );
    });

    test('运营不能自己制造 appealed（那条边只属于当事人）', () {
      final r = ReportAuthority.transitionDecision(
        from: ReportStatus.actioned,
        to: ReportStatus.appealed,
        actor: ReportActor.admin,
      );
      expect(r.accept, isFalse);
      expect(r.code, ReportTransitionCode.wrongActor);
    });

    test('★ 检查顺序：边不存在 → 理由缺失 → 申诉用尽 → 发起方', () {
      // open → actioned 既没有这条边、也没理由、发起方也是错的
      // ⇒ 必须先报 bad_transition（否则两端码表对不上，"谁说了算"当场失效）。
      final r = ReportAuthority.transitionDecision(
        from: ReportStatus.open,
        to: ReportStatus.actioned,
        actor: ReportActor.admin,
        reason: '',
      );
      expect(r.code, ReportTransitionCode.badTransition);

      // in_review → rejected 边存在，但没理由 ⇒ reason_required（先于 wrong_actor）
      final r2 = ReportAuthority.transitionDecision(
        from: ReportStatus.inReview,
        to: ReportStatus.rejected,
        actor: ReportActor.reporter,
        reason: '',
      );
      expect(r2.code, ReportTransitionCode.reasonRequired);

      // in_review → appealed 边不存在（ appealed 的入口只有 actioned / rejected）
      final r3 = ReportAuthority.transitionDecision(
        from: ReportStatus.inReview,
        to: ReportStatus.appealed,
        actor: ReportActor.reporter,
        appealCount: 0,
      );
      expect(r3.code, ReportTransitionCode.badTransition);
    });
  });

  group('工单构造：fail-closed 与数据最小化', () {
    test('编号格式必须是 RPT- + 12 位大写十六进制', () {
      final svc = ReportService();
      expect(
        () => svc.buildTicket(
          ticketId: 'RPT-0123456789AB',
          reporterPub: 'p',
          targetId: 'bob',
          reason: ReportReason.spam,
          createdAtMs: 1,
        ),
        returnsNormally,
      );
      for (final bad in ['RPT-0123456789ab', 'RPT-0123456789A', 'XPT-0123456789AB', '']) {
        expect(
          () => svc.buildTicket(
            ticketId: bad,
            reporterPub: 'p',
            targetId: 'bob',
            reason: ReportReason.spam,
            createdAtMs: 1,
          ),
          throwsArgumentError,
          reason: '编号 "$bad" 应被拒',
        );
      }
    });

    test('附注超过 280 字 → ArgumentError（不是静默截断）', () {
      final svc = ReportService();
      expect(
        () => svc.buildTicket(
          ticketId: 'RPT-0123456789AB',
          reporterPub: 'p',
          targetId: 'bob',
          reason: ReportReason.spam,
          createdAtMs: 1,
          detail: 'x' * (kReportMaxDetailChars + 1),
        ),
        throwsArgumentError,
      );
      expect(
        svc.buildTicket(
          ticketId: 'RPT-0123456789AB',
          reporterPub: 'p',
          targetId: 'bob',
          reason: ReportReason.spam,
          createdAtMs: 1,
          detail: 'x' * kReportMaxDetailChars,
        ).detail.length,
        kReportMaxDetailChars,
      );
    });

    test('内容哈希必须是 64 位小写十六进制（非法就拒，不"清理后放行"）', () {
      final svc = ReportService();
      expect(
        () => svc.buildTicket(
          ticketId: 'RPT-0123456789AB',
          reporterPub: 'p',
          targetId: 'bob',
          reason: ReportReason.spam,
          createdAtMs: 1,
          contentHash: 'A' * 64,
        ),
        throwsArgumentError,
      );
    });

    test('★ 签名载荷**不含**状态/处置/申诉次数（运营侧字段不该由举报人担保）', () {
      final t = _ticket();
      final keys = (t.canonical().startsWith('{')
              ? RegExp(r'"([a-z_]+)":').allMatches(t.canonical())
              : const <RegExpMatch>[])
          .map((m) => m.group(1))
          .toList();
      expect(keys, isNot(contains('status')));
      expect(keys, isNot(contains('status_note')));
      expect(keys, isNot(contains('action')));
      expect(keys, isNot(contains('appeal_count')));
      expect(keys, contains('ticket_id'));
      expect(keys, contains('reporter_pub'));
      expect(keys, contains('reason'));
    });

    test('★ canonical 键序固定（插入序，不是排序序）', () {
      final t = _ticket();
      final keys = RegExp(r'"([a-z_]+)":')
          .allMatches(t.canonical())
          .map((m) => m.group(1))
          .toList();
      expect(keys, [
        'alg',
        'kind',
        'ticket_id',
        'reporter_pub',
        'target_id',
        'reason',
        'content_hash',
        'detail',
        'created_at',
      ]);
    });

    test('幂等键 = report|<ticket_id>（一张工单一个键）', () {
      expect(ReportAuthority.keyOf('RPT-0123456789AB'), 'report|RPT-0123456789AB');
      expect(ReportAuthority.keyOf('RPT-0123456789AB'),
          isNot(ReportAuthority.keyOf('RPT-0123456789AC')));
    });

    test('签不出签名 ⇒ 返回 null（不签一张不可验证的）', () async {
      final t = _ticket();
      final signed = await ReportService.signTicket(
        ticket: t,
        reporterPub: '',
        sign: (_) async => 'AAAA',
      );
      expect(signed, isNull);
    });

    test('★ 理由字段只允许白名单（自由文本会变成无法归类的投诉池）', () {
      expect(ReportReason.values.length, 5);
      expect(ReportReason.values.map((r) => r.id).toSet().length, 5);
      expect(ReportReason.values.map((r) => r.id),
          containsAll(<String>['spam', 'harassment', 'illegal_content', 'fake_identity', 'other']));
    });
  });

  group('终局与序列化往返', () {
    test('closed / withdrawn 是终局', () {
      expect(ReportStatus.closed.isTerminal, isTrue);
      expect(ReportStatus.withdrawn.isTerminal, isTrue);
      for (final s in ReportStatus.values) {
        if (s != ReportStatus.closed && s != ReportStatus.withdrawn) {
          expect(s.isTerminal, isFalse, reason: '${s.id} 不该是终局');
        }
      }
    });

    test('工单序列化往返（字段不丢）', () {
      final t = _ticket().copyWith(
        status: ReportStatus.actioned,
        statusNote: '已限制功能',
        action: 'restrict',
        appealCount: 1,
        updatedAtMs: 1700000009999,
        sig: 'AAAA',
      );
      final back = ReportTicket.fromMap(Map<String, dynamic>.from(t.toMap()));
      expect(back.ticketId, t.ticketId);
      expect(back.reporterPub, t.reporterPub);
      expect(back.targetId, t.targetId);
      expect(back.reason, t.reason);
      expect(back.contentHash, t.contentHash);
      expect(back.detail, t.detail);
      expect(back.createdAtMs, t.createdAtMs);
      expect(back.status, t.status);
      expect(back.statusNote, t.statusNote);
      expect(back.action, t.action);
      expect(back.appealCount, t.appealCount);
      expect(back.updatedAtMs, t.updatedAtMs);
      expect(back.sig, t.sig);
    });

    test('★ 往返后 canonical 仍逐字节相同（签名不会因往返而失效）', () {
      final t = _ticket();
      final back = ReportTicket.fromMap(Map<String, dynamic>.from(t.toMap()));
      expect(back.canonical(), t.canonical());
    });
  });
}

ReportTicket _ticket() => const ReportTicket(
      ticketId: 'RPT-0123456789AB',
      reporterPub: 'REPORTER-PUB',
      targetId: 'bob',
      reason: ReportReason.spam,
      contentHash: '',
      detail: '',
      createdAtMs: 1700000000000,
    );
