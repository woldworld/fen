import 'package:flutter_test/flutter_test.dart';

import 'package:dahuang_ai/core/language_controller.dart';
import 'package:dahuang_ai/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('语言控制器（0.55.0 语言选择）', () {
    test('① 可选项 = 跟随系统 + 五语种，语种与 ARB 一一对应', () {
      expect(LanguageController.selectableCodes,
          ['system', 'zh', 'zh_Hant', 'en', 'ja', 'vi']);
      // 非 system 的每一项都必须在 supportedLocales 里找得到，
      // 否则 MaterialApp.locale 会落到第一个受支持项（英文）——静默失效。
      final supported = AppLocalizations.supportedLocales
          .map(LanguageController.codeOf)
          .toSet();
      for (final code in LanguageController.selectableCodes) {
        if (code == LanguageController.followSystem) continue;
        expect(supported.contains(code), isTrue, reason: '$code 没有对应的 ARB');
      }
    });

    test('② 每个语种都有自称与回复语言指令（空一项 = 该语种用户看不到母语）', () {
      for (final code in LanguageController.selectableCodes) {
        if (code == LanguageController.followSystem) continue;
        expect(LanguageController.endonyms[code], isNotNull,
            reason: '$code 缺自称');
        final d = LanguageController.replyDirectives[code];
        expect(d, isNotNull, reason: '$code 缺回复语言指令');
        expect(d!.trim().isNotEmpty, isTrue);
      }
      // 繁体指令必须是繁体字（写成简体就说明是复制 zh 忘了改）
      expect(LanguageController.replyDirectives['zh_Hant'],
          isNot(equals(LanguageController.replyDirectives['zh'])));
      expect(LanguageController.replyDirectives['zh_Hant'], contains('繁體'));
    });

    test('③ 切语言后 locale 落在受支持列表里，且语言码对得上', () {
      for (final code in ['zh', 'zh_Hant', 'en', 'ja', 'vi']) {
        LanguageController.debugSetForTest(code);
        expect(LanguageController.i.effectiveCode, code);
        expect(LanguageController.codeOf(LanguageController.i.locale), code);
        expect(AppLocalizations.supportedLocales
            .contains(LanguageController.i.locale), isTrue);
      }
      LanguageController.debugSetForTest(LanguageController.followSystem);
    });

    test('④ 繁体是独立语种，不会被折成简体', () {
      LanguageController.debugSetForTest('zh_Hant');
      final l = LanguageController.i.locale;
      expect(l.languageCode, 'zh');
      expect(l.scriptCode, 'Hant');
      // 这正是 0.55.0 要修的病：旧实现只比 languageCode，zh-TW 会被匹成 zh（简体）
      expect(LanguageController.codeOf(l), 'zh_Hant');
    });

    test('⑤ llmSystem 把回复语言指令拼在**末尾**；machineSystem 一字不动', () {
      LanguageController.debugSetForTest('ja');
      const body = '你是总管。';
      final out = llmSystem(body);
      expect(out.startsWith(body), isTrue);
      expect(out.endsWith(LanguageController.replyDirectives['ja']!), isTrue);
      expect(out.length, greaterThan(body.length));

      // 面向机器的提示词**刻意不加**：加了会把 JSON / PASS|REJECT 解析搞坏
      expect(machineSystem(body), body);
    });

    test('⑥ 指令随语种切换而变（不是硬编码一句中文）', () {
      LanguageController.debugSetForTest('vi');
      final vi = llmSystem('X');
      LanguageController.debugSetForTest('en');
      final en = llmSystem('X');
      expect(vi, isNot(equals(en)));
      expect(en, contains('English'));
      expect(vi, contains('tiếng Việt'));
    });

    test('⑦ 未支持的语言码被拒绝（防拼写错误静默落回英文）', () {
      final before = LanguageController.i.code;
      // setCode 是异步的，这里只验证"非法码不会改内存值"这一点
      expect(() => LanguageController.debugSetForTest('zh_TW'), returnsNormally);
      expect(LanguageController.i.code, before,
          reason: 'zh_TW 不是可选项（正确写法是 zh_Hant）');
    });
  });
}
