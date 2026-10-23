// 纯 Dart 校验脚本：验证 0.75.0 W6/G9「通知监听 + 短信（只读）」的结构级落地。
// 运行：dart run tool/verify_notify_sms.dart
//
// 盯六件事：
//   ① **渠道隔离**：受限权限（READ_SMS）与 NotificationListenerService **只**在
//      sideload 渠道声明；main 源集与 store 渠道零受限权限（"上架构建不受影响"
//      这条判据必须结构性成立，而不是靠自觉）。
//   ② **同身份**：两个 flavor 共用同一 applicationId（否则侧载包无法覆盖升级）。
//   ③ **只读红线**：绝不出现 SEND_SMS / WRITE_SMS / READ_CALL_LOG / WRITE_CALL_LOG，
//      也不出现任何短信发送 API 与任何写库调用。
//   ④ **不落库 / 不外网**：Dart 服务不碰数据库、不碰网络；Kotlin 缓冲纯内存。
//   ⑤ **跨端五件**：flavor 配置、sideload Manifest、Kotlin 服务、MainActivity 通道、
//      Dart 桥接 + 工具注册 —— 缺一即功能上线不了。
//   ⑥ **能力码联动**：PluginCapability.notification 三处同时登记（码会进签名载荷）。
//
// ★★ 两个反模式（本仓已实证踩过，这里刻意规避）：
//   (a) 扫源码前**必须剥注释** —— 本仓习惯把"绝不做 X"写进注释，不剥就会把
//       说明文字当成实现判红（skill §22.3）。
//   (b) 判据**不得写死版本号** —— 版本会前进，写死的锚点会变成恒真假判据。

import 'dart:convert';
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

const List<String> _arbFiles = [
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_en.arb',
  'lib/l10n/app_zh_Hant.arb',
  'lib/l10n/app_ja.arb',
  'lib/l10n/app_vi.arb',
];

/// 本波次新增的全部 36 个键（key 的**总量**与语种**齐备性**都要断言）
const List<String> _notifyKeys = [
  'capNotification',
  'settingsNotifySmsTitle',
  'settingsNotifySmsSubtitle',
  'notifySmsScreenTitle',
  'notifySmsRefreshStatus',
  'notifySmsUnsupported',
  'notifySmsListenerConnected',
  'notifySmsListenerCheckedNotConnected',
  'notifySmsListenerOff',
  'notifySmsStatusUnknown',
  'notifySmsGoSettings',
  'notifySmsGoSystemHint',
  'notifySmsRedetect',
  'notifySmsRedetectTip',
  'notifySmsAllowTitle',
  'notifySmsAllowSubReady',
  'notifySmsAllowSubNeedService',
  'notifySmsToastOn',
  'notifySmsToastOff',
  'notifySmsToastNeedService',
  'notifySmsSmsCardTitle',
  'notifySmsSmsGranted',
  'notifySmsSmsNotGranted',
  'notifySmsRequestSms',
  'notifySmsSmsUnavailable',
  'notifySmsToolsHeader',
  'notifySmsToolNotifyList',
  'notifySmsToolSmsList',
  'notifySmsToolSmsSearch',
  'notifySmsToolStatus',
  'notifySmsFooter',
  'notifySmsStatusUnsupportedFull',
  'notifySmsStatusReady',
  'notifySmsStatusPartial',
  'notifySmsStatusOff',
  'notifySmsStatusQueryFailed',
];

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) {
    stderr.writeln('FILE NOT FOUND: $p');
    return '';
  }
  return f.readAsStringSync();
}

bool _exists(String p) => File(p).existsSync();

/// 剥行注释与块注释（Dart / Kotlin / Gradle 通用）。
String _stripComments(String s) {
  final out = StringBuffer();
  var i = 0;
  final n = s.length;
  while (i < n) {
    final c = s[i];
    if (c == '/' && i + 1 < n && s[i + 1] == '/') {
      while (i < n && s[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && s[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(s[i] == '*' && s[i + 1] == '/')) {
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

/// 剥 XML 注释（Manifest 里的"绝不做 X"说明同样会误判）。
String _stripXml(String s) =>
    s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// 读源码并剥注释
String _code(String p) => _stripComments(_read(p));
String _xml(String p) => _stripXml(_read(p));

void main() {
  print('== verify_notify_sms (W6/G9 通知监听 + 短信·只读) ==');

  // ---------- ① 渠道隔离 + ② 同身份 ----------
  final gradle = _code('android/app/build.gradle.kts');
  check(gradle.contains('flavorDimensions'), 'build.gradle.kts 声明 flavorDimensions');
  check(gradle.contains('create("store")'), 'build.gradle.kts 定义 store flavor');
  check(gradle.contains('create("sideload")'), 'build.gradle.kts 定义 sideload flavor');
  final appIdCount =
      RegExp(r'applicationId\s*=\s*"world\.wold\.fen"').allMatches(gradle).length;
  check(appIdCount >= 3,
      '★ 两个 flavor 共用同一 applicationId（defaultConfig + store + sideload，实测 $appIdCount 处）'
      ' —— 否则侧载包无法覆盖升级既有安装');

  final mainManifestPath = 'android/app/src/main/AndroidManifest.xml';
  final sideloadManifestPath = 'android/app/src/sideload/AndroidManifest.xml';
  final mainXml = _xml(mainManifestPath);
  final sideloadXml = _xml(sideloadManifestPath);

  check(_exists(sideloadManifestPath), 'sideload 渠道专属 Manifest 存在');
  check(sideloadXml.contains('android.permission.READ_SMS'),
      'sideload Manifest 声明 READ_SMS');
  check(sideloadXml.contains('android.permission.RECEIVE_SMS'),
      'sideload Manifest 声明 RECEIVE_SMS');
  check(sideloadXml.contains('NotificationListenerService') ||
          sideloadXml.contains('DahuangNotificationListener'),
      'sideload Manifest 声明通知监听服务');
  check(
      sideloadXml.contains(
          'android.permission.BIND_NOTIFICATION_LISTENER_SERVICE'),
      '通知监听服务被 BIND_NOTIFICATION_LISTENER_SERVICE 钉死（仅系统可绑）');

  check(!mainXml.contains('android.permission.READ_SMS'),
      '★ main 源集**不**声明 READ_SMS（store 渠道零受限权限）');
  check(!mainXml.contains('android.permission.RECEIVE_SMS'),
      '★ main 源集**不**声明 RECEIVE_SMS');
  check(!mainXml.contains('NotificationListenerService'),
      '★ main 源集**不**声明通知监听服务');
  final storeManifest = File('android/app/src/store/AndroidManifest.xml');
  check(!storeManifest.existsSync() ||
          !_stripXml(storeManifest.readAsStringSync())
              .contains('android.permission.READ_SMS'),
      'store 渠道不含 READ_SMS（无专属 manifest 或专属 manifest 干净）');

  // ---------- ③ 只读红线 ----------
  const List<String> forbidden = [
    'android.permission.SEND_SMS',
    'android.permission.WRITE_SMS',
    'android.permission.READ_CALL_LOG',
    'android.permission.WRITE_CALL_LOG',
    'android.permission.CALL_PHONE',
  ];
  for (final p in forbidden) {
    check(!mainXml.contains(p) && !sideloadXml.contains(p),
        '★ 未声明 $p（只读红线）');
  }

  final kt = _code('android/app/src/main/kotlin/world/wold/fen/MainActivity.kt');
  for (final bad in ['SmsManager', 'sendTextMessage', 'sendMultipartTextMessage']) {
    check(!kt.contains(bad), '★ MainActivity 不出现短信发送 API：$bad');
  }
  check(!kt.contains('contentResolver.insert') && !kt.contains('.delete('),
      '★ MainActivity 不向 provider 写入/删除任何数据');

  // ---------- ④ 不落库 / 不外网 ----------
  final listener = _code(
      'android/app/src/main/kotlin/world/wold/fen/DahuangNotificationListener.kt');
  check(listener.contains('class DahuangNotificationListener') &&
          listener.contains('NotificationListenerService'),
      'DahuangNotificationListener 继承 NotificationListenerService');
  check(listener.contains('onNotificationPosted'),
      '通知经 onNotificationPosted 被动接收（无轮询、无历史回溯）');
  check(listener.contains('NotificationListenerService()'),
      '监听服务类已声明');
  for (final bad in [
    'SharedPreferences',
    'FileOutputStream',
    'openFileOutput',
    'getWritableDatabase',
    'contentResolver.insert',
  ]) {
    check(!listener.contains(bad), '★ 通知缓冲纯内存，不落库：不含 $bad');
  }

  final svc = _code('lib/core/notification_sms_service.dart');
  check(svc.contains('class NotificationSmsService'),
      'notification_sms_service 暴露 NotificationSmsService');
  check(svc.contains("MethodChannel('dahuang/notify_sms')"),
      'notification_sms_service 绑定 dahuang/notify_sms 通道');
  check(svc.contains('notifySmsEnabledPref'), '服务有总开关常量 notifySmsEnabledPref');
  check(svc.contains("notifySmsEnabledPref = 'notify_sms_enabled'"),
      '总开关键名固定为 notify_sms_enabled（读键者与写键者共用同一常量）');
  // ★ 常量名不得与 DeviceControlService.enabledPref 重名：两个类同名常量会让
  //   verify_data_keys 的"名字唯一才解析"规则失效 ⇒ 既有 device_control 的
  //   解析被打回盲区（等于悄悄削弱既有守卫）。这条防它复发。
  check(!svc.contains(RegExp(r"String\s+enabledPref\s*=")),
      '★ 本服务不得再声明名为 enabledPref 的常量（与 device_control 重名会让守卫退化）');
  check(svc.contains('notify_sms_enabled'),
      '总开关键为 notify_sms_enabled（默认关 = prefs 缺省 false）');
  check(!svc.contains("import 'db_helper.dart'"),
      '★ 服务层**不** import db_helper（不落库）');
  check(!svc.contains('cloud_service') && !svc.contains('package:http'),
      '★ 服务层**不**碰网络（零上传）');
  check(svc.contains('redactSensitive'), '服务层提供 redactSensitive 脱敏纯函数');
  check(svc.contains('PiiDetector.maskSensitive'),
      '脱敏复用全局 PiiDetector（口径唯一）');
  check(svc.contains('_otpLabeled'), '脱敏含验证码打码（标签+数字，不裸匹配）');
  check(_readCodeExists('lib/core/pii_detector.dart'), 'PiiDetector 存在于 core');

  // ---------- ⑤ 跨端五件 ----------
  check(kt.contains('dahuang/notify_sms'),
      'MainActivity 注册 dahuang/notify_sms 通道');
  check(kt.contains('"listNotifications"') && kt.contains('"listSms"'),
      'MainActivity 提供 listNotifications / listSms');
  check(kt.contains('querySms'), 'MainActivity 有 querySms 实现');
  check(kt.contains('Telephony.Sms.CONTENT_URI'),
      'MainActivity 经 Telephony.Sms provider 只读查询');
  check(kt.contains('Manifest.permission.READ_SMS') &&
          kt.contains('ActivityCompat.requestPermissions'),
      '短信授权在原生侧自持（requestPermissions 只带 READ_SMS）');
  check(kt.contains('ACTION_NOTIFICATION_LISTENER_SETTINGS'),
      'MainActivity 提供「通知使用权」系统设置跳转');
  check(kt.contains('onRequestPermissionsResult') &&
          kt.contains('smsPermissionRequest'),
      'MainActivity 回推短信授权结果（onRequestPermissionsResult）');
  check(kt.contains('isSmsDeclared') && kt.contains('supported'),
      'status 区分「渠道是否声明」与「用户是否授权」（不给假状态）');

  final agent = _code('lib/core/agent_service.dart');
  const List<String> toolNames = [
    'notify_list',
    'sms_list',
    'sms_search',
    'notify_sms_status',
  ];
  for (final t in toolNames) {
    check(agent.contains("'$t'"), 'agent_service 注册工具 $t');
  }
  check(agent.contains("_notifySmsGrantKey = 'notify_sms'"),
      '整组工具共享 grantKey = notify_sms（一次授权）');
  check(agent.contains("_syncNotifySmsTools"),
      'agent_service 有 _syncNotifySmsTools（可逆挂载）');
  check(
      agent.contains('await _syncNotifySmsTools();'),
      'initAgent / refreshDbTools 接线了 _syncNotifySmsTools（开关即时生效）');
  check(agent.contains('NotificationSmsService.redactSensitive'),
      '工具输出前经 redactSensitive 脱敏');
  check(agent.contains("actionType: 'notify_list'") &&
          agent.contains("actionType: 'sms_list'") &&
          agent.contains("actionType: 'sms_search'"),
      '三处读动作都写审计（只记条数，不记正文）');

  // 通知组工具窗口内必须出现 _wrapUntrusted，且档位为 sensitive
  final notifyIdx = agent.indexOf("name: 'notify_list'");
  if (notifyIdx >= 0) {
    final win = agent.substring(notifyIdx, (notifyIdx + 2600).clamp(0, agent.length));
    check(win.contains('_wrapUntrusted('),
        '通知输出按不可信输入包裹（_wrapUntrusted）');
    check(win.contains('PermissionLevel.sensitive'),
        '通知工具为 PermissionLevel.sensitive（非 normal 直行）');
  } else {
    check(false, 'notify_list 工具定义可定位');
  }

  // ---------- ⑥ 能力码三处联动 ----------
  final bus = _code('lib/core/plugin_bus.dart');
  check(bus.contains("notification = 'notification'"),
      'PluginCapability.notification 码已定义');
  check(bus.contains('PluginCapability.notification'),
      'riskForCapabilities 已纳入 notification（否则风险档位会失真）');
  final labels = _code('lib/ui/plugin_labels.dart');
  check(labels.contains('PluginCapability.notification') &&
          labels.contains('capNotification'),
      'plugin_labels 已登记 capabilityLabel(notification)');

  // UI 接线
  final screen = _read('lib/ui/notification_sms_screen.dart');
  check(screen.contains('class NotificationSmsScreen'),
      '新增 NotificationSmsScreen 设置页');
  check(screen.contains('NotificationSmsService.setUserEnabled'),
      '设置页总开关写回 notifySmsEnabledPref');
  check(screen.contains('AgentService().refreshDbTools()'),
      '设置页开关变化后即时重挂工具');
  // ★ 0.120.0：控制中心瘦身，「通知与短信」入口迁入管理页「系统与能力」区块
  //   （仅进阶模式显示）。判据随之改指 manage_screen，并**双向**钉：
  //   管理页必须收（入口 + ARB 文案），控制中心不得再留 ——
  //   单向只钉"在不在"会被「两处都有（双入口）」与「两处都没（功能消失）」
  //   同时糊弄（R50：判据强度也是查错对象）。
  //   本轮实证过判据是活的：迁移前本关 2 FAIL（红），迁移后转绿。
  final manage = _read('lib/ui/manage_screen.dart');
  check(manage.contains('NotificationSmsScreen'),
      '管理页「系统与能力」已挂通知与短信入口（0.120.0 迁入）');
  check(manage.contains('settingsNotifySmsTitle'),
      '入口用 ARB 文案（无硬编码）');
  final settings = _read('lib/ui/settings_screen.dart');
  check(!settings.contains('NotificationSmsScreen'),
      '★ 控制中心不再保留通知与短信入口（迁出即迁出，不许双入口）');

  // ---------- 七、五语种 ----------
  final Map<String, Map<String, dynamic>> arbs = {};
  for (final arb in _arbFiles) {
    try {
      arbs[arb] = jsonDecode(_read(arb)) as Map<String, dynamic>;
    } catch (e) {
      check(false, '$arb 可解析为 JSON ($e)');
    }
  }
  check(arbs.length == _arbFiles.length, '五个语种 ARB 全部可解析');
  for (final entry in arbs.entries) {
    final missing =
        _notifyKeys.where((k) => !entry.value.containsKey(k)).toList();
    check(missing.isEmpty,
        '${entry.key} 含全部本波键${missing.isEmpty ? '' : '，缺 $missing'}');
  }
  // 繁体文件名硬规矩（连字符会让整个语种静默失效）
  check(_exists('lib/l10n/app_zh_Hant.arb'),
      '★ 繁体文件名是 app_zh_Hant.arb（下划线，Flutter 的硬约束）');
  check(!_exists('lib/l10n/app_zh-Hant.arb'),
      '★ 不存在 app_zh-Hant.arb（连字符形态）');
  // 不许英文冒充译文：抽查 long 文案在四种非英文里都与英文不同
  final en = arbs['lib/l10n/app_en.arb'];
  if (en != null) {
    for (final f in [
      'lib/l10n/app_zh.arb',
      'lib/l10n/app_zh_Hant.arb',
      'lib/l10n/app_ja.arb',
      'lib/l10n/app_vi.arb',
    ]) {
      final other = arbs[f];
      final same = other != null &&
          (other['notifySmsFooter'] == en['notifySmsFooter'] ||
              other['notifySmsScreenTitle'] == en['notifySmsScreenTitle']);
      check(!same, '★ $f 未用英文冒充译文（抽查 long 文案）');
    }
  }

  // ★ 只读红线的**真正**判据：本功能的代码不得依赖通用权限插件。
  //   起因：`permission_handler` 的 `Permission.sms` 在 Android 上请求的是
  //   **短信权限组**（READ_SMS + RECEIVE_SMS + SEND_SMS 一起要），用它就等于
  //   连带把"发送短信"也申请了 —— 破坏只读红线。
  //   （pubspec 里 permission_handler 是因 nearby_connections 而存在，
  //     "pubspec 有没有它"是个**过宽**的判据：仓库有≠本功能用了。）
  check(!svc.contains('permission_handler'),
      '★ 服务层不依赖 permission_handler（其短信权限组会连带申请 SEND_SMS）');
  check(!screen.contains('permission_handler'),
      '★ 设置页不依赖 permission_handler');

  print('');
  print('PASS=$_pass FAIL=$_fail');
  exit(_fail == 0 ? 0 : 1);
}

bool _readCodeExists(String p) => File(p).existsSync();
