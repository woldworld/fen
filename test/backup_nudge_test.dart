import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/backup_nudge_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  final now = DateTime(2026, 10, 1, 12, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackupNudgePolicy（备份补课：谁该被提醒）', () {
    test('未备份 + 无免打扰记录 → 提醒', () async {
      prefs = await SharedPreferences.getInstance();
      expect(
          await BackupNudgePolicy.shouldShow(prefs,
              isBackedUpFn: () async => false, now: now),
          isTrue);
    });

    test('已备份（任何钥状态下恒真路径）→ 不提醒', () async {
      prefs = await SharedPreferences.getInstance();
      expect(
          await BackupNudgePolicy.shouldShow(prefs,
              isBackedUpFn: () async => true, now: now),
          isFalse);
    });

    test('"以后再说"3 天内 → 不提醒；过期 → 重新提醒', () async {
      prefs = await SharedPreferences.getInstance();
      await BackupNudgePolicy.snooze(prefs, now: now);
      expect(
          await BackupNudgePolicy.shouldShow(prefs,
              isBackedUpFn: () async => false, now: now),
          isFalse,
          reason: '刚点完"以后再说"不应立刻又弹');
      expect(
          await BackupNudgePolicy.shouldShow(prefs,
              isBackedUpFn: () async => false,
              now: now.add(const Duration(days: 2))),
          isFalse);
      expect(
          await BackupNudgePolicy.shouldShow(prefs,
              isBackedUpFn: () async => false,
              now: now.add(const Duration(days: 3, minutes: 1))),
          isTrue,
          reason: '免打扰过期后重新提醒——备份没有"永久不再提醒"出口');
    });

    test('备份完成后 clear：即使旧 snooze 记录残留也不影响（isBackedUp 恒真接管）', () async {
      prefs = await SharedPreferences.getInstance();
      await BackupNudgePolicy.snooze(prefs, now: now);
      await BackupNudgePolicy.clear(prefs);
      expect(prefs.getInt(BackupNudgePolicy.snoozeKey), isNull);
      expect(
          await BackupNudgePolicy.shouldShow(prefs,
              isBackedUpFn: () async => true, now: now),
          isFalse);
    });
  });
}
