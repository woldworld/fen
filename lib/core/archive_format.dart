/// 归档（`.dahuang`）的**格式与纯函数**部分 —— 零平台依赖，可离线复算。
///
/// 与 `local_archive.dart` 的分工（照抄 `identity_rotation` / `identity_recovery`
/// 那一对的做法）：**能离线复算的算法放这里**，**要落库的编排放那边**。
/// 这样 `dart run tool/verify_local_archive.dart` 才能在独立 Dart VM 里跑
/// —— 而 `local_archive.dart` 经 `DBHelper` 依赖 Flutter，在 CLI 里根本编不出来。
///
/// 本文件**不 import Flutter / sqflite / shared_preferences**，只用 `dart:convert`。
library;

import 'dart:convert';

/// 归档相关的失败码（语言无关的稳定码，UI 负责翻译）。
abstract final class ArchiveFault {
  /// blob 不是合法的归档文本（段数/前缀/base64 任一不合法）。
  static const String badFormat = 'bad_format';

  /// 口令错，或 blob 被改动过（GCM 认证标签不区分这两者，也不需要区分）。
  static const String badPassword = 'bad_password';

  /// 解开之后不是我们认识的归档结构。
  static const String notArchive = 'not_archive';

  /// 归档版本高于本机，看不懂 —— **拒绝**而不是"尽力而为"。
  static const String futureVersion = 'future_version';

  /// ★ §16 日志接不上（本机日志不是归档日志的前缀）—— **拒绝导入**。
  static const String logMismatch = 'log_mismatch';
}

/// 归档格式常量与纯函数。
abstract final class ArchiveFormat {
  /// 归档格式版本。**改结构必须加版本**，且**旧版必须仍能读**。
  static const int version = 1;

  /// 归档 kind 标记（挡住"把别的 JSON 当成归档"）。
  static const String kind = 'dahuang_archive';

  /// ★ **不进归档**的表（诊断 / 瞬态）—— 每条都写清理由。
  ///
  /// 判据是「**是不是用户资产**」，不是「有没有用」：
  /// 这些表要么是运营侧诊断数据、要么是只对"当下这次发送"有意义的队列。
  /// 把它们塞进用户手里的归档，只会扩大泄露面而没有任何价值。
  static const Set<String> excludedTables = {
    'telemetry_events', // 我们自己的埋点，属于运营数据
    'system_logs', // 运行诊断日志
    'session_events', // 会话内的瞬时事件
    'hub_outbox', // 待发送队列（重发目标；导入旧队列 = 重放旧操作）
    'audit_queue', // 待审草稿（瞬时）
  };

  /// 把载荷编码成归档 JSON 文本（键序 = 插入序 ⇒ 可逐字节复算）。
  static String encode(Map<String, Object?> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);

  /// 解析归档文本。返回 `Map`，或 [ArchiveFault] 的码（字符串）。
  static Object decode(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return ArchiveFault.notArchive;
    }
    if (decoded is! Map) return ArchiveFault.notArchive;
    final map = Map<String, Object?>.from(decoded);
    if (map['kind'] != kind) return ArchiveFault.notArchive;
    final v = (map['version'] as num?)?.toInt() ?? 0;
    if (v <= 0) return ArchiveFault.notArchive;
    if (v > version) return ArchiveFault.futureVersion;
    if (map['tables'] is! Map) return ArchiveFault.notArchive;
    return map;
  }

  /// ★ §16 日志能否**接续** —— 返回 `null` = 可以，否则 [ArchiveFault.logMismatch]。
  ///
  /// 语义：本机日志必须是归档日志的**前缀**（逐条、逐字段一致）。
  /// 本机为空 ⇒ 首次接管，直接采用归档（返回 null）。
  /// 本机有内容而归档里找不到对应条目、或同样 idx 的内容不一致 ⇒ 断档，拒绝。
  ///
  /// 为什么这条**必须是硬约束**：断档恰恰是哈希链**原理上查不出来**的那类失效
  /// —— 断了一节，后面的每一节仍然自洽。所以只能在**导入前**拦。
  static String? logContinuity(
    List<Map<String, Object?>> local,
    List<Map<String, Object?>> archive,
  ) {
    if (local.isEmpty) return null;
    if (archive.isEmpty) return ArchiveFault.logMismatch;
    final byIdx = <int, Map<String, Object?>>{};
    for (final row in archive) {
      final idx = (row['idx'] as num?)?.toInt();
      if (idx != null) byIdx[idx] = row;
    }
    for (final row in local) {
      final idx = (row['idx'] as num?)?.toInt();
      final other = idx == null ? null : byIdx[idx];
      if (other == null) return ArchiveFault.logMismatch;
      if (other['hash'] != row['hash'] ||
          other['leaf_hash'] != row['leaf_hash'] ||
          other['prev_hash'] != row['prev_hash']) {
        return ArchiveFault.logMismatch;
      }
    }
    return null;
  }
}

/// 导入前给用户看的**检查结果**（本机不落任何改动）。
class ArchiveInspection {
  final int version;
  final int exportedAt;

  /// 各表待写入行数（`表名 -> 行数`）。
  final Map<String, int> counts;

  /// §16 日志锚点（归档侧）。
  final int logSize;
  final String logRoot;

  /// 本机日志是否为空（为空 = 首次接管，可直接采用归档日志）。
  final bool localLogEmpty;

  /// 非空 = 接不上（值是 [ArchiveFault.logMismatch]）。
  final String? logFault;

  const ArchiveInspection({
    required this.version,
    required this.exportedAt,
    required this.counts,
    required this.logSize,
    required this.logRoot,
    required this.localLogEmpty,
    required this.logFault,
  });

  int get totalRows => counts.values.fold(0, (a, b) => a + b);

  /// 能不能导入（日志能接续是硬前提）。
  bool get importable => logFault == null;
}
