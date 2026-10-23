// W3 (0.72.0) 语音服务单测：stripMarkdownForTts 纯函数 + TtsService 开关门/截断。
//
// ASR 通道依赖原生环境（宿主测试没有 SpeechRecognizer），只测 Dart 侧可达的门面：
// 失败原因常量、isListening 初值。TTS 用 speakOverride 测试缝（不打真引擎）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dahuang_ai/core/voice_service.dart';

void main() {
  group('stripMarkdownForTts（纯函数）', () {
    test('代码块整体略去（念代码是灾难）', () {
      final out = stripMarkdownForTts('看这段：\n```dart\nvoid main() {}\n```\n完事');
      expect(out, contains('（代码略）'));
      expect(out, isNot(contains('void main')));
    });

    test('行内代码剥反引号，链接只念文字，图片丢弃', () {
      final out = stripMarkdownForTts(
          '用 `record` 插件，[点这里](https://a.com)，图：![x](https://b.png)');
      expect(out, contains('record 插件'));
      expect(out, isNot(contains('`')));
      expect(out, contains('点这里'));
      expect(out, isNot(contains('https://a.com')));
      expect(out, isNot(contains('https://b.png')));
    });

    test('标题/加粗/斜体/引用/列表标记/表格/分隔线剥离', () {
      final out = stripMarkdownForTts(
          '## 标题\n**加粗**与*斜体*\n> 引用一句\n- 列表一\n| a | b |\n---\n尾行');
      expect(out, contains('标题'));
      expect(out, contains('加粗与斜体'));
      expect(out, contains('引用一句'));
      expect(out, contains('列表一'));
      expect(out, isNot(contains('#')));
      expect(out, isNot(contains('**')));
      expect(out, isNot(contains('>')));
      expect(out, isNot(contains('|')));
    });

    test('纯文本原样（去首尾空白）', () {
      expect(stripMarkdownForTts('  你好，世界  '), '你好，世界');
    });
  });

  group('TtsService（开关门 + 截断，speakOverride 测试缝）', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // 重置单例内部缓存（测试间互不污染）
      TtsService.i.speakOverride = null;
    });

    test('默认关：speak 不出声、不调合成', () async {
      var called = 0;
      TtsService.i.speakOverride = (_) async => called++;
      await TtsService.i.speak('你好');
      expect(called, 0);
      expect(await TtsService.i.currentEnabled(), isFalse);
    });

    test('打开后 speak 调合成，且传的是洗过的文本', () async {
      final seen = <String>[];
      await TtsService.i.setEnabled(true);
      TtsService.i.speakOverride = (t) async => seen.add(t);
      await TtsService.i.speak('## 标题\n**加粗**正文\n```x\ncode\n```');
      expect(seen.length, 1);
      expect(seen.single, contains('标题'));
      expect(seen.single, isNot(contains('```')));
    });

    test('超长截断到 kTtsSpeakMaxChars（带省略号）', () async {
      final seen = <String>[];
      await TtsService.i.setEnabled(true);
      TtsService.i.speakOverride = (t) async => seen.add(t);
      await TtsService.i.speak('长' * (kTtsSpeakMaxChars + 500));
      expect(seen.single.length, kTtsSpeakMaxChars + 1); // +1 = 省略号
      expect(seen.single.endsWith('…'), isTrue);
    });

    test('空文本 / 全标记文本不合成', () async {
      var called = 0;
      await TtsService.i.setEnabled(true);
      TtsService.i.speakOverride = (_) async => called++;
      await TtsService.i.speak('');
      await TtsService.i.speak('![img](https://x.png)');
      expect(called, 0);
    });

    test('关掉开关 = 立刻落库且 currentEnabled 同步变 false', () async {
      await TtsService.i.setEnabled(true);
      expect(await TtsService.i.currentEnabled(), isTrue);
      await TtsService.i.setEnabled(false);
      expect(await TtsService.i.currentEnabled(), isFalse);
    });
  });

  group('SpeechInputService 门面（不依赖原生）', () {
    test('宿主环境 isAvailable = false（通道未实现不抛）', () async {
      expect(await SpeechInputService.i.isAvailable(), isFalse);
    });

    test('失败原因常量存在（UI 翻译用）', () {
      expect(SpeechStartFailure.unavailable, 'unavailable');
      expect(SpeechStartFailure.permission, 'permission');
      expect(SpeechStartFailure.busy, 'busy');
    });

    test('初始不在监听状态', () {
      expect(SpeechInputService.i.isListening, isFalse);
    });
  });
}
