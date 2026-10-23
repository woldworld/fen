// 纯 Dart 校验脚本：应用命令/事件总线与权限提示（lib/core/app_events.dart）。
// 运行：dart run tool/verify_app_events.dart
//
// 为什么验它：`AppEvents` 是**全应用的事件总线**（agent_service / cloud / lan /
// p2p / telemetry / world / main / chat 都订阅它），`PermissionPrompt` 是**两条
// 授权通道共用的唯一提示构造**。二者此前**零直接覆盖**。
// 事件总线坏掉是最难排查的一类缺陷：不报错、不白屏，只是"消息偶尔不到"。
// 本脚本把它的**语义契约**钉死：
//   · 它是 broadcast（多订阅者各收一份），且**不回放**（迟到订阅者丢历史）；
//   · 订阅前 emit 的事件必然丢失（不是 bug，是契约 —— 但必须写下来）；
//   · FIFO 顺序、取消订阅、按类型过滤互不干扰；
//   · `PermissionDisplay.ofGrantKey` 的每种键形态归类；
//   · `PermissionPrompt.forGrantKey` 的 displayArg 边界（`mcp:` → 空串而非 null）；
//   · ★ 方向约束：core 层**绝不反向 import UI / Flutter**（源码扫描）。

import 'dart:async';
import 'dart:io';

import 'package:dahuang_ai/core/app_events.dart';

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

Future<void> _tick() => Future<void>.delayed(Duration.zero);

Future<void> main() async {
  print('--- ① 授权键 → 展示名形态码（两条授权通道共用的唯一推导）---');
  check(PermissionDisplay.deviceControl == 'device-control',
      "deviceControl == 'device-control'（钉住与 UI 文案映射的键）");
  check(PermissionDisplay.mcp == 'mcp', "mcp == 'mcp'");
  check(PermissionDisplay.ofGrantKey('device_control') == PermissionDisplay.deviceControl,
      "'device_control' → device-control");
  check(PermissionDisplay.ofGrantKey('mcp:foo') == PermissionDisplay.mcp,
      "'mcp:foo' → mcp");
  check(PermissionDisplay.ofGrantKey('mcp:') == PermissionDisplay.mcp,
      "'mcp:'（空后缀）仍 → mcp");
  check(PermissionDisplay.ofGrantKey('mcp') == null, "'mcp'（无冒号）→ null");
  check(PermissionDisplay.ofGrantKey('MCp:foo') == null, '大小写敏感：MCp: → null');
  check(PermissionDisplay.ofGrantKey('') == null, '空串 → null');
  check(PermissionDisplay.ofGrantKey('device_control_extra') == null,
      "'device_control_extra' → null（不是前缀匹配）");
  check(PermissionDisplay.ofGrantKey('other') == null, '未知键 → null');

  print('--- ② PermissionPrompt.forGrantKey（展示名与参数推导）---');
  final mcpPrompt = PermissionPrompt.forGrantKey(
    grantKey: 'mcp:weather',
    declaredDescription: 'weather mcp',
    capabilities: const ['net'],
  );
  check(mcpPrompt.kind == PermissionPromptKind.pluginGrant,
      'kind == plugin-grant');
  check(mcpPrompt.subject == 'mcp:weather', 'subject 原样保留授权键');
  check(mcpPrompt.displayCode == PermissionDisplay.mcp, 'displayCode == mcp');
  check(mcpPrompt.displayArg == 'weather', "displayArg == 'weather'（去掉 mcp: 前缀）");
  check(mcpPrompt.actionCode == PermissionAction.generic,
      'actionCode == generic（授权流非具体工具）');
  check(mcpPrompt.actionArg == null, 'actionArg == null');
  check(mcpPrompt.declaredDescription == 'weather mcp', 'declaredDescription 透传');
  check(mcpPrompt.capabilities.length == 1 && mcpPrompt.capabilities.first == 'net',
      'capabilities 透传');

  final dcPrompt = PermissionPrompt.forGrantKey(
    grantKey: 'device_control',
    declaredDescription: 'dc',
    capabilities: const [],
  );
  check(dcPrompt.displayCode == PermissionDisplay.deviceControl,
      "'device_control' → displayCode device-control");
  check(dcPrompt.displayArg == null, '非 mcp 键 → displayArg == null');

  final emptySuffix = PermissionPrompt.forGrantKey(
    grantKey: 'mcp:',
    declaredDescription: 'd',
    capabilities: const [],
  );
  check(emptySuffix.displayArg == '', "★ 'mcp:' → displayArg == ''（空串，不是 null）");

  final unknown = PermissionPrompt.forGrantKey(
    grantKey: 'weird',
    declaredDescription: 'd',
    capabilities: const [],
  );
  check(unknown.displayCode == null && unknown.displayArg == null,
      '未知键 → displayCode/displayArg 均 null（UI 直接显示 subject）');

  print('--- ③ PermissionPrompt.toolCall（单次高危工具确认）---');
  final toolPrompt = PermissionPrompt.toolCall(
    subject: 'create_tool',
    declaredDescription: 'make a tool',
    actionCode: PermissionAction.createTool,
    actionArg: 'my_tool',
  );
  check(toolPrompt.kind == PermissionPromptKind.toolCall, 'kind == tool-call');
  check(toolPrompt.displayCode == null && toolPrompt.displayArg == null,
      '工具确认无插件展示名（displayCode/Arg 均 null）');
  check(toolPrompt.capabilities.isEmpty, '工具确认不携带插件能力表');
  check(toolPrompt.actionCode == PermissionAction.createTool, 'actionCode 透传');
  check(toolPrompt.actionArg == 'my_tool', 'actionArg 透传');
  final defaultAction = PermissionPrompt.toolCall(
    subject: 'x',
    declaredDescription: 'd',
  );
  check(defaultAction.actionCode == PermissionAction.generic,
      'actionCode 缺省 = generic');
  check(defaultAction.actionArg == null, 'actionArg 缺省 = null');

  print('--- ④ 事件类型与字段（sealed AppCommand 子类）---');
  final social = SocialMessageReceivedEvent(
    senderAgentId: 'ag1',
    message: 'hi',
    channel: 'p2p',
  );
  check(social.channel == 'p2p' && social.message == 'hi', '社交事件字段透传');
  check(social.sourceMsgId == null, 'sourceMsgId 可空（缺省 null）');
  final world = WorldRoomMessageEvent(
    roomId: 'lisbon',
    senderAgentId: 'ag2',
    nickname: 'Bob',
    message: 'yo',
    sourceMsgId: 'm1',
  );
  check(world.roomId == 'lisbon' && world.nickname == 'Bob' && world.sourceMsgId == 'm1',
      '世界房间事件字段透传');
  check(ChangeThemeCommand('dark').themeKey == 'dark', 'ChangeThemeCommand 带 themeKey');
  check(NodeOnlineEvent('n1').agentId == 'n1', 'NodeOnlineEvent 带 agentId');

  final completer = Completer<bool>();
  final req = ToolPermissionRequest(
    toolName: 'create_tool',
    prompt: toolPrompt,
    arguments: const {'a': 1},
    completer: completer,
  );
  check(!completer.isCompleted, '应答通道初始未完成');
  completer.complete(true);
  check(await completer.future, 'UI 应答后 future 得 true');

  // 子类关系用**运行时投递**证明（静态 is 会被优化掉；能进 bus 收到才算数）
  final allEvents = <AppCommand>[
    social,
    world,
    ClearChatCommand(),
    ChangeThemeCommand('dark'),
    NodeOnlineEvent('n1'),
    req,
  ];
  final delivered = <AppCommand>[];
  final subAll = AppEvents.stream.listen(delivered.add);
  for (final e in allEvents) {
    AppEvents.emit(e);
  }
  await _tick();
  check(delivered.length == allEvents.length,
      '★ 所有事件都能经总线投递（子类关系运行时成立）');
  check(
      delivered.map((e) => e.runtimeType).toList().toString() ==
          allEvents.map((e) => e.runtimeType).toList().toString(),
      '投递后类型保真（无降级 / 不打乱顺序）');
  await subAll.cancel();

  print('--- ⑤ 总线语义（broadcast：不回放 / 多订阅 / FIFO / 可取消）---');
  check(AppEvents.stream.isBroadcast, 'stream 是 broadcast（支持多订阅）');

  // ★ 订阅前 emit 的事件必然丢失（broadcast 无缓冲）—— 把契约写下来
  final a = <AppCommand>[];
  AppEvents.emit(ChangeThemeCommand('before'));
  final sub1 = AppEvents.stream.listen(a.add);
  await _tick();
  check(a.isEmpty, '★ 订阅前的 emit **不回放**（迟到订阅者丢历史 —— 契约，非缺陷）');

  AppEvents.emit(ChangeThemeCommand('dark'));
  AppEvents.emit(NodeOnlineEvent('n1'));
  await _tick();
  check(a.length == 2, '订阅后逐条收到（2 条）');
  check(a[0] is ChangeThemeCommand &&
          (a[0] as ChangeThemeCommand).themeKey == 'dark',
      '第 1 条字段正确（FIFO）');
  check(a[1] is NodeOnlineEvent && (a[1] as NodeOnlineEvent).agentId == 'n1',
      '第 2 条字段正确（FIFO）');

  final b = <AppCommand>[];
  final sub2 = AppEvents.stream.listen(b.add);
  AppEvents.emit(ClearChatCommand());
  await _tick();
  check(a.length == 3 && b.length == 1, '多订阅者各自收到一份（广播语义）');

  await sub2.cancel();
  AppEvents.emit(ClearChatCommand());
  await _tick();
  check(b.length == 1, '取消订阅后不再收到');
  check(a.length == 4, '其它订阅者不受影响（隔离）');

  final themes = <String>[];
  final sub3 = AppEvents.stream
      .where((e) => e is ChangeThemeCommand)
      .map((e) => (e as ChangeThemeCommand).themeKey)
      .listen(themes.add);
  AppEvents.emit(ChangeThemeCommand('light'));
  AppEvents.emit(NodeOnlineEvent('n2'));
  await _tick();
  check(themes.length == 1 && themes.first == 'light',
      '订阅侧可按类型过滤，互不干扰');

  // 全部退订后再 emit：任何订阅者都不应再增长（用基准值比较，避免脆弱的魔数）
  final beforeFinal = a.length;
  final beforeThemes = themes.length;
  await sub1.cancel();
  await sub3.cancel();
  AppEvents.emit(ClearChatCommand());
  await _tick();
  check(a.length == beforeFinal && themes.length == beforeThemes,
      '全部退订后无新投递（无残留监听）');

  print('--- ⑥ 方向约束（core 只发事件，绝不反向 import UI / Flutter）---');
  final f = File('lib/core/app_events.dart');
  check(f.existsSync(), '源码文件找得到（扫描前置）');
  final src = f.existsSync() ? f.readAsStringSync() : '';
  check(src.contains("import 'dart:async'"), '只用 dart:async');
  check(!src.contains("import '../ui/") && !src.contains('import "../../ui/'),
      '不 import UI 层（core → UI 反向依赖被禁）');
  check(!src.contains('package:flutter/'), '不 import Flutter（保持 core 纯净）');
  check(!src.contains('package:sqflite/'), '不 import sqflite（零平台依赖）');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  if (_fail > 0) throw StateError('verification failed');
}
