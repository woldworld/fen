import 'dart:async';

/// ============================================================
/// 网络层故障的**判据**与**处置**（零依赖：只 import dart:async）。
///
/// 为什么要有这个文件：同一个故障必须在两条路径上给出**同一句话** ——
///   · 「主人对话框」(`AgentService.sendMessage`) 早就有这套判据，写在 catch 里；
///   · 「社交入站私聊」(`AgentService._processBatchedMessages`) **没有** ⇒
///     它把「设备路由不到公网」报成「社交决策流水线异常」，
///     把**环境问题**说成**逻辑缺陷**，主人只能看着一条莫名的报错。
///
/// 判据来源（**保留既有行为，不做静默收紧**）：原 sendMessage 判断式是
///   `e is TimeoutException || t.contains('Timeout') || t.contains('SocketException')`
/// 本类保留这三条，并补齐 4 条**同一族的真实形态**：
/// package:http 会把 dart:io 的异常包成 `ClientException`，
/// 上面的 `SocketException` 仍能命中（`ClientException with SocketException: ...`），
/// 但**只**抛 `ClientException`（如 DNS 失败被包在外层）时会漏 ⇒ 补 `clientexception`。
/// ============================================================
class NetDiagnosis {
  NetDiagnosis._();

  /// 网络层故障的关键字（一律**小写**比较）。每一条都对应一个真实观测形态：
  /// - `socketexception`     dart:io 连接/解析失败（含 No route to host、Connection refused）
  /// - `clientexception`     package:http 对上述异常的包装
  /// - `timeout`             连接/读超时
  /// - `no route to host`    EHOSTUNREACH（errno 113）——「局域网无外网出口」的典型形态
  /// - `failed host lookup`  DNS 解析失败
  /// - `connection refused`  目标端口无人监听
  /// - `network is unreachable` ENETUNREACH（errno 101）
  static const List<String> _networkTokens = <String>[
    'socketexception',
    'clientexception',
    'timeout',
    'no route to host',
    'failed host lookup',
    'connection refused',
    'network is unreachable',
  ];

  /// 「到不了对端」的关键字 —— 比 [isNetworkError] **更窄**，
  /// 用于把"局域网劫持 / 无外网出口"从普通的连接失败里分出来。
  static const List<String> _unreachableTokens = <String>[
    'no route to host',
    'network is unreachable',
    'failed host lookup',
  ];

  /// 是否是**网络层**故障（而不是社交逻辑本身出错）。
  static bool isNetworkError(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    for (final token in _networkTokens) {
      if (text.contains(token)) return true;
    }
    return false;
  }

  /// 是否是「**到不了对端**」（无路由 / 解析不了）—— 局域网劫持的典型形态。
  static bool isUnreachable(Object error) {
    final text = error.toString().toLowerCase();
    for (final token in _unreachableTokens) {
      if (text.contains(token)) return true;
    }
    return false;
  }

  /// 重试上限：**每条路只重一次**（同路一次 / 换路一次，各算一次）。
  /// 最常见的可恢复形态是「网络切换的一瞬」（Wi-Fi → 蜂窝），800ms 足以跨过；
  /// 而「局域网真的没有外网出口」这类**稳定失败**，重试一百次也没用 ——
  /// 那种情况只能靠**可见的诊断**如实告知主人（见 ARB `netFaultSocialSkipped`）。
  static const int maxRetries = 1;

  /// 重试前的固定退避（非指数）。
  static const int retryBackoffMs = 800;

  /// 该异常是否值得重试；返回 `0` 表示**不重试**。
  /// ★ 与 [isNetworkError] **同向**：不重试的情况只有"不是网络层故障"。
  static int retryDelayMs(Object error) =>
      isNetworkError(error) ? retryBackoffMs : 0;

  /// **降级链**的三段（主人定的策略：先 Wi-Fi → 不通换蜂窝 → 再不通就如实提醒）。
  /// ★ 抽成纯函数的原因：这段策略必须**可离线断言** —— 它是"降级行为"的唯一口径，
  /// 若散在两处 `catch` 里各写一遍，必然漂移（本仓踩过同族的不对称）。
  static NetFallbackStep nextStep(Object error, {required int failuresSoFar}) {
    // ★ 非网络层（逻辑错 / 格式错 / 鉴权错）：**不进降级链**，立即抛。
    //   重试一个确定性错误只是把同一个错误延迟一次。
    //   与 [retryDelayMs] 共用同一个 [isNetworkError]，避免两处口径漂移。
    if (retryDelayMs(error) <= 0) return NetFallbackStep.notNetwork;
    // 第 1 段：系统默认路由**本来就是 Wi-Fi** ⇒ 首次失败后在 Wi-Fi 上再试一次。
    if (failuresSoFar <= 1) return NetFallbackStep.retrySameRoute;
    // 第 2 段：Wi-Fi 已经试过还出不去 ⇒ 该换一条路（蜂窝）。
    if (failuresSoFar == 2) return NetFallbackStep.retryOtherRoute;
    // 第 3 段：换过路仍不通 ⇒ 如实提醒主人。
    return NetFallbackStep.reportUnavailable;
  }
}

/// 降级链的每一步（见 [NetDiagnosis.nextStep]）。
enum NetFallbackStep {
  /// 首次失败：在**当前路**（Wi-Fi）上再试一次。
  retrySameRoute,

  /// 第二次失败：该**换路**（蜂窝）重试。
  /// ★ **P0 无此能力**（Dart 不能把连接绑到指定网络 ⇒ 需原生，见交付记录 §58），
  /// 故 0.39.0 的调用点**不传** `switchRoute` ⇒ 这一步如实降级为 [reportUnavailable] + 指引。
  retryOtherRoute,

  /// 换过路仍不通（或本版无换路能力）：**如实提醒主人网络不可用**。
  reportUnavailable,

  /// 非网络层故障：不进降级链，原样抛。
  notNetwork,
}

/// 跑一次 [action]；失败时按 [NetDiagnosis.nextStep] 的**降级链**决定下一步。
///
/// - 非网络层异常 ⇒ **立即抛**（不进降级链）；
/// - 首次网络失败 ⇒ 退避后在**同一条路**上再试（第 1 段）；
/// - 再失败 ⇒ 若调用方提供了 [switchRoute]（P1：把连接绑到蜂窝）则**换路再试**，
///   否则**如实抛出**（P0 现状：无换路能力时不假装成功）。
///
/// [switchRoute] 就是这条策略的**唯一插槽**：P0 传 `null`（零原生、零竞态），
/// P1 只需在调用点传入一个"绑蜂窝"的实现，**其余代码一行不用改**。
Future<T> withNetworkRetry<T>(
  Future<T> Function() action, {
  Future<void> Function()? switchRoute,
}) async {
  var failures = 0;
  while (true) {
    try {
      return await action();
    } catch (error) {
      failures++;
      switch (NetDiagnosis.nextStep(error, failuresSoFar: failures)) {
        case NetFallbackStep.notNetwork:
        case NetFallbackStep.reportUnavailable:
          rethrow;
        case NetFallbackStep.retrySameRoute:
          await Future<void>.delayed(
            const Duration(milliseconds: NetDiagnosis.retryBackoffMs),
          );
          continue;
        case NetFallbackStep.retryOtherRoute:
          // ★ 没有换路能力就**如实失败**（不重试第三次、不吞错）。
          if (switchRoute == null) rethrow;
          await switchRoute();
          await Future<void>.delayed(
            const Duration(milliseconds: NetDiagnosis.retryBackoffMs),
          );
          continue;
      }
    }
  }
}
