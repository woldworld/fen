/// 邮箱工具 · 凭据存储（**唯一接触口令的地方**）
///
/// ---------------------------------------------------------------------------
/// ⚠️ 存储位置：与**身份种子同一个仓库**（`SharedPreferences`，App 私有目录）
/// ---------------------------------------------------------------------------
/// 方案 §3.2 原计划引入 `flutter_secure_storage`（Android Keystore / iOS Keychain）。
/// 施工时核实：**本项目的身份种子（Ed25519 seed）本身就明文存于 SharedPreferences**
/// （`lib/core/agent_identity.dart:79-86`：`prefs.setString(_seedKey, _hexEncode(seed))`）。
///
/// 于是只有两条路：
/// - (a) 只给邮箱口令上 Keystore ⇒ **造出一个荒谬的安全姿态**：邮箱口令比用户身份
///   更受保护，而身份才是被偷走就没法挽回的那个。且新增原生插件、多一套存储方案，
///   违反"复用同一套、不新增第二套"的既有纪律。
/// - (b) **沿用同一仓库**（本文件的选择），并把"统一加固"作为**一次单独的安全改动**
///   提出来（身份 + 口令 + 令牌一起迁 Keystore，届时只改一处）。
///
/// 选 (b)。**已登记为缺口**（方案 §5 风险表 + 交付记录），不是疏忽。
///
/// 另有三条不变量（无论存在哪都必须守）：
/// ① 明文**绝不**进 SQLite、**绝不**进审计表、**绝不**进日志；
/// ② 口令只在本机读写，**不上行到任何服务器**（方案 §2.1 第 1 条）；
/// ③ 删除账号 = 同时删除口令（[forget]）。
library;

import 'package:shared_preferences/shared_preferences.dart';

class MailCredentialStore {
  /// 存储方案标记：将来迁 Keystore 时靠它识别旧数据并就地迁移。
  static const String schemeKey = 'mail_credential_scheme';
  static const String schemeValue = 'prefs-v1';

  static String _key(String accountId) => 'mail_secret_$accountId';

  /// 写入口令。会同时打上方案标记（供将来迁移识别）。
  static Future<void> save(String accountId, String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(accountId), secret);
    await prefs.setString(schemeKey, schemeValue);
  }

  /// 读取口令；不存在返回 null。
  static Future<String?> secretOf(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key(accountId));
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// 是否已配置口令（**不取值**，供 UI 显示"已设置/未设置"）。
  static Future<bool> has(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key(accountId));
    return v != null && v.isNotEmpty;
  }

  /// 删除口令（账号解绑时必须调用）。
  static Future<void> forget(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(accountId));
  }

  /// **脱敏展示**（日志 / 审计 / 给模型看的摘要都只允许用这个）。
  static String masked(String? secret) {
    if (secret == null || secret.isEmpty) return '（未设置）';
    if (secret.length <= 4) return '****';
    return '${secret.substring(0, 2)}****${secret.substring(secret.length - 2)}';
  }
}
