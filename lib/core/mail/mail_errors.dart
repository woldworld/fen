/// 邮箱探测失败的**错误分类**（纯函数，零依赖、离线可测）。
///
/// 为什么单独一层：服务商的拒绝文案五花八门、且随版本变 —— 分类认不出时只能
/// "原样透出"，而原始报文用户看不懂。0.80.0 真机实证：163 填错凭证回的是
/// `a1 NO LOGIN Login error or password error`，**不带** `AUTHENTICATIONFAILED`，
/// 旧映射（只认 Gmail/QQ 形态）认不出 ⇒ 用户看到原始报文，且其中带着
/// LOGIN 命令形态（0.81.0 起 `imap_client` 已脱敏，但提示仍应是人话）。
///
/// ★ 判据按**各家原文**收口，认不出的返回 `null` ⇒ 调用方原样透出（不编造）。
library;

/// 把探测异常文案分类成稳定错误码；`null` = 不认识（调用方原样透出）。
String? classifyMailProbeError(String s) {
  // 凭证被拒：Gmail/QQ 的 `NO [AUTHENTICATIONFAILED] ...`、部分服务端的
  // `Invalid credentials`、SMTP 侧中文包装（`SMTP 认证失败（535）…`——注意
  // ★ 判据只写 `认证失败`，旧写法 `AUTH 认证失败` 是**死判据**，从匹配不上）、
  // 以及网易 163/126 的 `NO LOGIN ...`。
  if (s.contains('AUTHENTICATIONFAILED') ||
      s.contains('Invalid credentials') ||
      s.contains('认证失败') ||
      s.contains('NO LOGIN') ||
      s.contains('Login error or password error')) {
    return 'auth';
  }
  // 网易的 "Unsafe Login" 是**身份声明**问题（IMAP `ID` 命令已修，见
  // `imap_client.dart` 头注释），但若服务端仍以此拒信，给一句可照做的指引
  // 而不是抛原始报文。
  if (s.contains('Unsafe Login') || s.contains('UNAVAILABLE')) {
    return 'unsafeLogin';
  }
  return null;
}
