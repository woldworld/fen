/// 语音服务（0.72.0 · W3/S4）：语音转文字（ASR）+ 语音播报（TTS）
///
/// ---------------------------------------------------------------------------
/// 设计口径（为什么这么做）
/// ---------------------------------------------------------------------------
/// * **ASR = 系统 `SpeechRecognizer`，自写 MethodChannel（`dahuang/voice`）**，
///   零新依赖（规划 §S4：免费、离线语言包、无模型体积）。原生侧在
///   `MainActivity.kt`；本层只做通道封装 + 状态机 + 失败原因翻译。
///   设备没有可用识别服务 ⇒ `start()` 返回原因、UI 明说（红线：不静默失败）。
/// * **TTS = `flutter_tts`（系统引擎）**，规划点名的插件。**默认关**
///   （不打扰原则：自说自话把回复念出来，是"系统主动打扰"）；
///   打开后每次回复朗读一份**洗过的纯口播文本**（`stripMarkdownForTts`），
///   超长截断；`speaking` 通知器供 UI 画"停止"按钮；新消息发出前自动停。
/// * 两者都是**本机能力**：语音不出设备、不经过我们（与隐私口径一致）。
/// * 测试缝：`TtsService.speakOverride`（生产不传）；纯函数 `stripMarkdownForTts`
///   单测直测。ASR 通道依赖原生环境，宿主测试只覆盖可达的门面逻辑。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// ASR：语音转文字（系统 SpeechRecognizer）
// ---------------------------------------------------------------------------

const MethodChannel _voiceChannel = MethodChannel('dahuang/voice');

/// 单次监听的失败原因（给 UI 显示的可读文案用）。
class SpeechStartFailure {
  static const String unavailable = 'unavailable';
  static const String permission = 'permission';
  static const String busy = 'busy';
}

class SpeechInputService {
  SpeechInputService._() {
    // 宿主测试环境没有 ServicesBinding，setMethodCallHandler 会抛——
    // 注册失败只意味着收不到原生回调（平台门面仍可用），不拦构造。
    try {
      _voiceChannel.setMethodCallHandler(_handle);
    } catch (_) {}
  }

  static final SpeechInputService i = SpeechInputService._();

  /// 部分识别结果（实时上屏用）。
  void Function(String partial)? onPartial;

  /// 最终结果（用户停止后一次给全）。
  void Function(String finalText)? onFinal;

  /// 识别错误（设备级：无语音服务 / 无匹配 / 忙）。
  void Function(String reason)? onError;

  bool _busy = false;
  bool _cancelled = false;

  bool get isListening => _busy;

  /// 设备是否有可用识别服务（非 Android / 通道未装 ⇒ false）。
  Future<bool> isAvailable() async {
    try {
      return await _voiceChannel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 启动监听。返回 null = 已开始；否则返回失败原因（英文短码，UI 翻译）。
  Future<String?> start() async {
    if (_busy) return null;
    _cancelled = false;
    try {
      final ok = await _voiceChannel.invokeMethod<bool>('start');
      if (ok == true) {
        _busy = true;
        return null;
      }
      return SpeechStartFailure.unavailable;
    } on PlatformException catch (e) {
      return e.code;
    } catch (e) {
      return '$e';
    }
  }

  /// 结束并取结果（原生侧会回调 [onFinal]）。
  Future<void> stop() async {
    if (!_busy) return;
    _busy = false;
    try {
      await _voiceChannel.invokeMethod('stop');
    } catch (_) {}
  }

  /// 取消本次监听（之后到的结果一律丢弃）。
  Future<void> cancel() async {
    if (!_busy) return;
    _busy = false;
    _cancelled = true;
    try {
      await _voiceChannel.invokeMethod('cancel');
    } catch (_) {}
  }

  Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'onPartial':
        if (!_cancelled) onPartial?.call(call.arguments as String? ?? '');
        break;
      case 'onFinal':
        if (!_cancelled) onFinal?.call(call.arguments as String? ?? '');
        break;
      case 'onError':
        if (!_cancelled) onError?.call(call.arguments as String? ?? 'error');
        break;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// TTS：语音播报（flutter_tts / 系统引擎，默认关）
// ---------------------------------------------------------------------------

/// 语音播报开关的存储键（键不存在 = 默认关；不打扰原则）。
const String kTtsEnabledKey = 'tts_enabled';

/// 单次朗读的最大字符数（长回复念到最后已经没人听了，白占音频焦点）。
const int kTtsSpeakMaxChars = 1200;

/// 把 Markdown 洗成纯口播文本（纯函数，单测直测）。
///
/// 原则：**念出来要像人话**——代码块整体略去（念代码是灾难），
/// 链接只念文字、图片丢弃、标记符号（# * > - | `）剥离、压缩空行。
String stripMarkdownForTts(String raw) {
  var t = raw;
  // ★ Dart 的 String.replaceAll **不展开 $1 分组引用**（那是 replaceAllMapped
  //   的能力）——用错会把字面 "$1" 留在文本里（单测抓住过）。
  t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '（代码略）');
  t = t.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ''); // 图片：整段丢弃
  t = t.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!); // 链接：只留文字
  t = t.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  t = t.replaceAllMapped(RegExp(r'\*\*([^*]*)\*\*'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\*([^*\n]*)\*'), (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*\|.*\|\s*$', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*[-=_]{3,}\s*$', multiLine: true), '');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return t.trim();
}

class TtsService {
  TtsService._();
  static final TtsService i = TtsService._();

  FlutterTts? _tts;
  bool _enabledLoaded = false;
  bool _enabled = false;

  /// 是否正在朗读（UI 据此显示"停止"按钮）。
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  /// 测试缝：生产不传；测试注入假合成函数（宿主没有 TTS 引擎）。
  Future<void> Function(String text)? speakOverride;

  Future<bool> _loadEnabled() async {
    if (!_enabledLoaded) {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(kTtsEnabledKey) ?? false;
      _enabledLoaded = true;
    }
    return _enabled;
  }

  /// 开关唯一写入方（设置卡拨一下立即生效；关 ⇒ 立刻停掉当前朗读）。
  Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTtsEnabledKey, v);
    _enabled = v;
    _enabledLoaded = true;
    if (!v) await stop();
  }

  /// 朗读当前缓存的开关状态（设置卡初始化用）。
  Future<bool> currentEnabled() => _loadEnabled();

  Future<void> _ensureInit() async {
    if (_tts != null) return;
    final tts = FlutterTts();
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(false);
    tts.setStartHandler(() => speaking.value = true);
    tts.setCompletionHandler(() => speaking.value = false);
    tts.setCancelHandler(() => speaking.value = false);
    tts.setErrorHandler((msg) => speaking.value = false);
    _tts = tts;
  }

  /// 朗读一段回复（开关关 / 空文本 ⇒ 直接返回；内部已洗 Markdown + 截断）。
  /// 绝不抛：TTS 挂了不能影响对话本身。
  Future<void> speak(String rawMarkdown) async {
    try {
      if (!await _loadEnabled()) return;
      final text = stripMarkdownForTts(rawMarkdown);
      if (text.isEmpty) return;
      final payload = text.length > kTtsSpeakMaxChars
          ? '${text.substring(0, kTtsSpeakMaxChars)}…'
          : text;
      final fn = speakOverride;
      if (fn != null) {
        await fn(payload);
        return;
      }
      await _ensureInit();
      await _tts!.stop(); // 新一轮打断上一轮（QUEUE_MODE 语义最稳的写法）
      await _tts!.speak(payload);
    } catch (_) {
      speaking.value = false;
    }
  }

  /// 停止朗读（UI"停止"按钮 / 用户发新消息时）。
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    speaking.value = false;
  }
}
