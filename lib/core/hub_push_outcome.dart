/// **零依赖**的上行结局判定。
///
/// 为什么单独成文件：本模块要被 `tool/verify_hub_write.dart` 在**纯 Dart**
/// 环境下直接断言（`dart run`，没有 Flutter、没有 sqflite、没有平台通道）。
/// 而承载 HTTP 的 `hub_write_service.dart` 经 `app_logger` / `db_helper`
/// 必然拉到 Flutter —— 若把判定留在那里，"该重试还是该放弃"这条最容易出
/// 真事故的逻辑就只能靠人肉 review 了。
///
/// 两侧出错的代价是不对称且都致命的：
/// - 把**该重试**的判成永久 → **丢数据**（离线期间的事永远没公示出去）；
/// - 把**不该重试**的判成可重试 → 队列永远排不干，真问题被重试噪音淹没。
library;

/// 一次上行尝试的结局。
enum HubPushOutcome {
  /// Hub 收下了。
  accepted,

  /// 已经在树上（幂等重复）。**不是失败** —— 重放本来就该是这个结果。
  duplicate,

  /// 暂时发不出去（未配置 / 网络断 / 未注册 / 限流 / 5xx）→ 入队等下次。
  retryable,

  /// 永久拒绝（验签不过 / 载荷非法 / 权限不符）→ **不入队**，留痕即可。
  ///
  /// 为什么永久拒绝不能入队：重试一万次也不会变成合法载荷，
  /// 只会把真问题淹在重试噪音里，并让队列永远排不干。
  rejected,
}

class HubPushResult {
  final HubPushOutcome outcome;
  final int statusCode;
  final String errorCode;

  const HubPushResult(this.outcome, this.statusCode, [this.errorCode = '']);

  bool get ok =>
      outcome == HubPushOutcome.accepted || outcome == HubPushOutcome.duplicate;

  @override
  String toString() =>
      'HubPushResult(${outcome.name}, http=$statusCode, err=$errorCode)';
}

/// HTTP 状态码 + Hub 错误码 → 上行结局。**纯函数**，可离线断言。
///
/// 判据取自 Hub 的**真实返回约定**（逐个端点核对过，不是猜的）：
/// - `200` 一律成功。注意三个端点的"重复"都走 200 而不是 4xx：
///   `log/append` 的重复 = `200 + appended:false`、
///   房间角色的重复 = `200 + duplicate:true`、
///   背书的重复 = `200 + result:'duplicate'`；
/// - `409` 只有 `error == 'duplicate'`（**技能上架**）才是良性重复，
///   其余（`key_conflict`：同一件事对应两片不同叶子）是**真冲突** → 永久拒绝；
/// - `0`（网络不通 / Hub 未配置）、`429`（限流）、`5xx` → 可重试；
/// - `401`：`agent_not_registered`（还没注册）与 `bad_timestamp`（本机时钟偏了）
///   都会自愈 → 可重试；其余（`bad_signature` / `signature_required`）
///   是我们的代码缺陷 → 永久拒绝，重试一万次也不会变对；
/// - 其它 `4xx`（`400` 载荷非法、`403` 权限不符）→ 永久拒绝。
HubPushOutcome classifyHubResponse(int status, String error) {
  if (status == 200) return HubPushOutcome.accepted;
  if (status == 409) {
    return error == 'duplicate'
        ? HubPushOutcome.duplicate
        : HubPushOutcome.rejected;
  }
  if (status == 0 || status == 429 || status >= 500) {
    return HubPushOutcome.retryable;
  }
  if (status == 401) {
    return (error == 'agent_not_registered' || error == 'bad_timestamp')
        ? HubPushOutcome.retryable
        : HubPushOutcome.rejected;
  }
  return HubPushOutcome.rejected;
}
