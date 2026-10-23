import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'setup_service.dart';

/// 更新检查的状态（**语言无关码** —— UI 负责翻译，与 `HubRotateResult` 同范式）。
///
/// 用一个码而不是一句中文，是因为这些码要能被日志、测试与五语种共用。
enum UpdateStatus {
  /// 已是最新。
  upToDate,

  /// 有新版本（[UpdateCheckResult.remote] 非空）。
  updateAvailable,

  /// 网络不可达 / 超时。
  networkError,

  /// 官网 version.json 缺失关键字段或类型不对（**不是**"没有更新"）。
  badResponse,

  /// 24h 节流期内，本次未真查（UI 不显示任何结果行）。
  throttled,
}

/// 本机版本（PackageInfo 的投影，测试可直构）。
class LocalVersion {
  final String version; // "0.112.0+1"
  final int versionCode; // 1

  const LocalVersion({required this.version, required this.versionCode});
}

/// 官网 `version.json` 的内容 —— 字段与 `landing/build.js` 生成的一一对应，
/// 每个数字都在构建时从真实 APK 现算（版本/字节/SHA-256/证书指纹同一事实源）。
class RemoteVersion {
  final String version; // "0.112.0+1"
  final int versionCode; // 1
  final String url; // https://wold.world/download/fen-0.112.0+1-arm64.apk
  final int bytes;
  final String sha256;
  final String certSha256;
  final String scheme;

  const RemoteVersion({
    required this.version,
    required this.versionCode,
    required this.url,
    required this.bytes,
    required this.sha256,
    required this.certSha256,
    required this.scheme,
  });
}

/// 一次检查的结论。
class UpdateCheckResult {
  final UpdateStatus status;

  /// 本机版本（拿不到时为 null）。
  final LocalVersion? local;

  /// 远端版本（仅 [UpdateStatus.updateAvailable] 时非空）。
  final RemoteVersion? remote;

  const UpdateCheckResult({required this.status, this.local, this.remote});

  bool get hasUpdate => status == UpdateStatus.updateAvailable;
}

/// 更新检查服务（0.113.0）。
///
/// 为什么需要它：侧载分发**没有应用商店**，版本公告只能来自官网。
/// `landing/build.js` 在构建时把 `version.json`（版本 / versionCode / 下载
/// 地址 / 字节 / SHA-256 / 证书指纹）现算写到官网根目录；本服务读它、比对、
/// 把结论交给设置页展示。
///
/// 三条纪律：
///   ① **地址唯一来源** `SetupService.defaultWebUrl`（换域名只改那一处，
///      不准在别处出现裸 `https://wold.world`）；
///   ② **比较用版本名逐段数值化**（本仓 versionCode 长期停在 +1，只比
///      versionCode 会把 0.112.0+1 → 0.113.0+1 判成"已最新"）；
///   ③ **失败给语言无关状态码**，UI 负责翻译；网络失败与"没有更新"
///      是两件事，不许混成一个"检查失败"。
class UpdateCheckService {
  static final UpdateCheckService _instance = UpdateCheckService._internal();
  factory UpdateCheckService() => _instance;
  UpdateCheckService._internal();

  /// version.json 在官网的路径（与 landing/build.js 的写出位置一致）。
  static const String versionJsonPath = '/version.json';

  /// 节流键：非强制检查 24 小时内只真查一次（手动点按钮不受限）。
  static const String lastCheckPrefKey = 'update_check_last_at';
  static const Duration throttle = Duration(hours: 24);

  /// 单次 HTTP 超时（version.json 是个几百字节的小文件，10s 足够）。
  static const Duration httpTimeout = Duration(seconds: 10);

  /// 版本名逐段数值比较：`a > b` 返正、`a < b` 返负、相等返 0。
  ///
  /// 只认 `major.minor.patch` 前三段（`+N` 构建号不参与 —— 它由
  /// [compareCodes] 在版本名相等时兜底）。非数字段按 0 计，
  /// 缺段按 0 计（`1.2` vs `1.2.0` 相等）。
  static int compareVersionNames(String a, String b) {
    List<int?> segs(String v) => v
        .split('+')[0]
        .split('.')
        .map((s) => int.tryParse(s.trim()))
        .toList();
    final pa = segs(a);
    final pb = segs(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? (pa[i] ?? 0) : 0;
      final y = i < pb.length ? (pb[i] ?? 0) : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  /// 纯判定：远端比本地新 ⇒ 有更新。
  ///
  /// 版本名不同 ⇒ 以版本名为准；版本名相同 ⇒ 比 versionCode
  /// （覆盖"同名重打包 / 构建号递增"这一种情形）。
  static bool isNewer({
    required String localVersion,
    required int localCode,
    required RemoteVersion remote,
  }) {
    final byName = compareVersionNames(remote.version, localVersion);
    if (byName != 0) return byName > 0;
    return remote.versionCode > localCode;
  }

  /// 纯解析：version.json 正文 → [RemoteVersion]。
  ///
  /// 缺字段 / 类型不对 / JSON 坏 ⇒ 抛 [FormatException]（调用方转
  /// [UpdateStatus.badResponse]）—— **不许**把坏数据当成"没有更新"。
  static RemoteVersion parseVersionJson(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const FormatException('version.json is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('version.json is not a JSON object');
    }
    // 提升后的类型落到 final 变量上，闭包里才能用（try 内赋值的变量
    // 类型提升不流进闭包 —— 这是 Dart 流分析的硬规则）。
    final Map<String, dynamic> map = decoded;
    String str(String k) {
      final v = map[k];
      if (v is! String || v.isEmpty) {
        throw FormatException('version.json missing string field "$k"');
      }
      return v;
    }

    int num(String k) {
      final v = map[k];
      if (v is! int) {
        throw FormatException('version.json missing int field "$k"');
      }
      return v;
    }

    final version = str('version');
    final url = str('url');
    if (!url.startsWith('https://')) {
      throw const FormatException('version.json url must be https');
    }
    return RemoteVersion(
      version: version,
      versionCode: num('versionCode'),
      url: url,
      bytes: num('bytes'),
      sha256: str('sha256'),
      certSha256: str('certSha256'),
      scheme: str('scheme'),
    );
  }

  /// 本机版本（PackageInfo）。测试环境 / 插件缺失时返回 null，
  /// 由调用方决定显示什么 —— **不猜**。
  Future<LocalVersion?> localVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return LocalVersion(
        version: '${info.version}+${info.buildNumber}',
        versionCode: int.tryParse(info.buildNumber) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 检查更新。
  ///
  /// [force] = true 时跳过 24h 节流（手动点按钮走这条）。
  /// 任何失败都返对应状态码，**不抛**——调用方（UI）只需要结论。
  Future<UpdateCheckResult> check({bool force = false}) async {
    final local = await localVersion();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force) {
      final last = prefs.getInt(lastCheckPrefKey) ?? 0;
      if (now - last < throttle.inMilliseconds) {
        return UpdateCheckResult(status: UpdateStatus.throttled, local: local);
      }
    }

    final uri = Uri.parse(SetupService.defaultWebUrl + versionJsonPath);
    String body;
    try {
      final client = HttpClient()..connectionTimeout = httpTimeout;
      try {
        final req = await client.getUrl(uri).timeout(httpTimeout);
        final resp = await req.close().timeout(httpTimeout);
        if (resp.statusCode != 200) {
          return UpdateCheckResult(status: UpdateStatus.badResponse, local: local);
        }
        body = await resp
            .transform(utf8.decoder)
            .join()
            .timeout(httpTimeout);
      } finally {
        client.close();
      }
    } catch (_) {
      // 网络不可达 / 超时 / TLS 失败 —— 与"没有更新"严格分开。
      return UpdateCheckResult(status: UpdateStatus.networkError, local: local);
    }

    await prefs.setInt(lastCheckPrefKey, now);

    final RemoteVersion remote;
    try {
      remote = parseVersionJson(body);
    } catch (_) {
      return UpdateCheckResult(status: UpdateStatus.badResponse, local: local);
    }

    // ★ 局部变量不能叫 localVersion —— 它会遮蔽同名方法 localVersion()，
    //   同一作用域里先调用后声明会被判「referenced before declaration」。
    final localVer = local?.version ?? '0.0.0';
    final localCode = local?.versionCode ?? 0;
    final newer = isNewer(
      localVersion: localVer,
      localCode: localCode,
      remote: remote,
    );
    return UpdateCheckResult(
      status: newer ? UpdateStatus.updateAvailable : UpdateStatus.upToDate,
      local: local,
      remote: newer ? remote : null,
    );
  }
}
