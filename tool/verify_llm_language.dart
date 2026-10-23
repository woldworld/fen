// 纯 Dart 校验脚本：**每一条**送给 LLM 的 system prompt 都必须显式声明
// 「要不要带回复语言指令」。
// 运行：dart run tool/verify_llm_language.dart
//
// 存在的理由（0.55.0）：用户选了日语，模型却用中文回答——因为提示词骨架、
// 记忆片段、工具回执全是中文，模型本能地跟着上文走。所以每条 system prompt
// 末尾必须拼一句「无论上文用什么语言写成，最终必须用 X 回答」。
//
// 为什么是"二选一"而不是"统一加"：有一类提示词的产出**不是给人看的**
// （安全网关的 PASS/REJECT、摘要器、结构化 JSON），给它们加"用日语回答"
// 只会把机器解析搞坏。于是：
//   llmSystem(...)     = 面向用户，加语言指令
//   machineSystem(...) = 面向机器，刻意不加
// 本脚本钉住：**裸传的一律报错** —— 新增调用时忘了选，这里立刻红。
//
// ⚠️ 只扫 `lib/`，且不剥字符串内容：注释会被剥掉（注释里写示例不算引用）。

import 'dart:io';

int _pass = 0;
int _fail = 0;

void check(bool ok, String label) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label');
  }
}

/// 剥注释（与 verify_i18n.dart 同款实现，避免把注释里的示例当真引用）
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// 取匹配点之后的实参开头（**跨行**）。
///
/// ⚠️ 为什么要跨行：Dart 格式化会把
///   `ChatMessage.system(machineSystem('...'))`
/// 折成两行，只扫本行会把合规代码误判成裸传（本轮就误判过一次）。
String _after(String src, int end) {
  final stop = end + 80 > src.length ? src.length : end + 80;
  return src.substring(end, stop).trimLeft();
}

/// 匹配点所在行号（报错要能定位）
int _lineOf(String src, int index) =>
    '\n'.allMatches(src.substring(0, index)).length + 1;

List<File> _dartFiles(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Windows 下 `File.path` 是反斜杠，统一成正斜杠再当 map 键，
/// 否则 `sources['lib/core/x.dart']` 永远取不到（踩过）。
String _norm(String path) => path.replaceAll('\\', '/');

void main() {
  final root = Directory('lib');
  final files = _dartFiles(root);
  final sources = <String, String>{
    for (final f in files) _norm(f.path): _stripComments(f.readAsStringSync()),
  };

  print('--- 助手函数存在性与语种覆盖 ---');
  final ctrlPath = 'lib/core/language_controller.dart';
  final ctrl = sources[ctrlPath];
  check(ctrl != null, '存在 lib/core/language_controller.dart');
  if (ctrl == null) return;
  check(ctrl.contains('String llmSystem(String body)'), '定义 llmSystem()');
  check(ctrl.contains('String machineSystem(String body)'), '定义 machineSystem()');
  for (final code in ['zh', 'zh_Hant', 'en', 'ja', 'vi']) {
    check(ctrl.contains("'$code':"), '回复语言指令覆盖 $code');
  }
  // 指令必须强调"上文语言 ≠ 输出语言"，否则模型会跟着中文上下文走
  check(ctrl.contains('无论上文用什么语言写成'),
      '简体指令挑明「上下文语言 ≠ 输出语言」');
  check(ctrl.contains('No matter what language the context above'),
      '英文指令挑明「上下文语言 ≠ 输出语言」');

  print('--- 每一处 ChatMessage.system( 都必须二选一 ---');
  final bare = <String>[];
  var sysCount = 0;
  for (final e in sources.entries) {
    for (final m in RegExp(r'ChatMessage\.system\(\s*').allMatches(e.value)) {
      sysCount++;
      final rest = _after(e.value, m.end);
      if (!(rest.startsWith('llmSystem(') || rest.startsWith('machineSystem('))) {
        bare.add('${e.key}:${_lineOf(e.value, m.start)}: ${rest.split('\n').first}');
      }
    }
  }
  check(bare.isEmpty,
      '无裸传的 system prompt（共 $sysCount 处）${bare.isEmpty ? '' : ' → $bare'}');
  check(sysCount >= 15, 'system prompt 站点数 $sysCount ≥ 15（防脚本被绕过）');

  print('--- _runtime.turn 的 systemPrompt 必须过 llmSystem ---');
  final turnBad = <String>[];
  var turnCount = 0;
  for (final e in sources.entries) {
    for (final m in RegExp(r'systemPrompt:\s*').allMatches(e.value)) {
      turnCount++;
      final rest = _after(e.value, m.end);
      if (!rest.startsWith('llmSystem(')) {
        turnBad.add('${e.key}:${_lineOf(e.value, m.start)}: ${rest.split('\n').first}');
      }
    }
  }
  check(turnBad.isEmpty,
      'systemPrompt 传参全部过 llmSystem（$turnCount 处）${turnBad.isEmpty ? '' : ' → $turnBad'}');

  print('--- 本地模型兜底通道同样带指令 ---');
  final lm = sources['lib/core/local_model_service.dart'] ?? '';
  check(lm.contains('static Future<String?> chat('),
      'LocalModelService.chat 存在（离线兜底通道）');
  final agent = sources['lib/core/agent_service.dart'] ?? '';
  check(agent.contains('LocalModelService.chat(llmSystem(dynamicSystemPrompt), text)'),
      '离线兜底调用点也包了 llmSystem');
  // 已被包装过的成品提示词在 fallback 闭包里转发，**不得二次包装**
  check(agent.contains('LocalModelService.chat(systemPrompt, message)'),
      'fallback 闭包只转发成品提示词（防重复拼接）');

  print('--- 后台 isolate 也要恢复语言选择 ---');
  final mainSrc = sources['lib/main.dart'] ?? '';
  check(mainSrc.contains('await LanguageController.i.load();'),
      '后台 isolate 入口装了一遍 LanguageController（内存态不跨 isolate）');
  check(mainSrc.contains('await LanguageController.i.load();') &&
      mainSrc.indexOf('await LanguageController.i.load();') <
          mainSrc.indexOf('runApp('),
      '主 isolate 在 runApp 之前恢复语言（首帧不闪系统语言）');

  print('--- 周易解读走的是带指令的通道 ---');
  final ser = sources['lib/ui/serendipity_screen.dart'] ?? '';
  check(ser.contains('AgentService().sendMessage(payloadText)'),
      '起卦解读复用主对话通道（自动带上回复语言指令）');

  print('--- 反向对照：故意漏包必须被抓出来 ---');
  // 正对照：把一段"裸传"喂给同一套判定，确认它**会**被判违规（否则脚本形同虚设）
  const fake = 'final x = ChatMessage.system(enhancedSubPrompt);';
  final fakeRest =
      fake.substring(fake.indexOf('ChatMessage.system(') + 19).trimLeft();
  check(!(fakeRest.startsWith('llmSystem(') || fakeRest.startsWith('machineSystem(')),
      '裸传样本被判定为违规（脚本没睡着）');
  const good = 'final x = ChatMessage.system(llmSystem(enhancedSubPrompt));';
  final goodRest =
      good.substring(good.indexOf('ChatMessage.system(') + 19).trimLeft();
  check(goodRest.startsWith('llmSystem('), '包装过的样本被判为合规（脚本没误杀）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
