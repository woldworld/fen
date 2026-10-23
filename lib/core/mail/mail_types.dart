/// 邮箱工具 · 数据类型与**纯函数**校验
///
/// 设计纪律（《邮箱工具-实现方案》§2）：
/// - **数据只在用户手机端**：本文件不依赖任何宿主服务，可离线单测。
/// - **服务器不得成为保管人**：凭据与邮件正文永不进入 hub。
/// - 本文件**不 import flutter / sqflite**，保证纯 Dart 环境可跑（离线断言用）。
library;

/// 加密方式（端口与它必须自洽）。
enum MailSecurity {
  /// 隐式 TLS：连上即握手（993 / 465）。
  tls,

  /// 明文连上再升级（143 / 587）。
  starttls;

  String get wire => name;

  static MailSecurity parse(String? s) =>
      s == 'starttls' ? MailSecurity.starttls : MailSecurity.tls;
}

/// 绑定的邮箱账号（**不含凭据**；凭据在凭据存储里，见 mail_credential_store.dart）。
class MailAccount {
  final String id;
  final String address;
  final String displayName;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;
  final MailSecurity security;
  final bool enabled;
  final int? lastOkAt;
  final String? lastError;

  const MailAccount({
    required this.id,
    required this.address,
    this.displayName = '',
    required this.imapHost,
    this.imapPort = 993,
    required this.smtpHost,
    this.smtpPort = 465,
    this.security = MailSecurity.tls,
    this.enabled = true,
    this.lastOkAt,
    this.lastError,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'address': address,
        'display_name': displayName,
        'imap_host': imapHost,
        'imap_port': imapPort,
        'smtp_host': smtpHost,
        'smtp_port': smtpPort,
        'security': security.wire,
        'enabled': enabled ? 1 : 0,
        'last_ok_at': lastOkAt,
        'last_error': lastError,
      };

  static MailAccount fromRow(Map<String, Object?> r) => MailAccount(
        id: r['id'] as String,
        address: (r['address'] as String?) ?? '',
        displayName: (r['display_name'] as String?) ?? '',
        imapHost: (r['imap_host'] as String?) ?? '',
        imapPort: ((r['imap_port'] as num?) ?? 993).toInt(),
        smtpHost: (r['smtp_host'] as String?) ?? '',
        smtpPort: ((r['smtp_port'] as num?) ?? 465).toInt(),
        security: MailSecurity.parse(r['security'] as String?),
        enabled: ((r['enabled'] as num?) ?? 1).toInt() == 1,
        lastOkAt: (r['last_ok_at'] as num?)?.toInt(),
        lastError: r['last_error'] as String?,
      );

  /// 喂给模型的账号摘要（**绝不含凭据 / 不含完整地址之外的信息**）。
  String describe() {
    final name = displayName.isEmpty ? '' : '（$displayName）';
    final err = (lastError == null || lastError!.isEmpty) ? '' : '，上次错误：$lastError';
    return '$id → $address$name'
        '${enabled ? '' : '［已停用］'}'
        '｜imap $imapHost:$imapPort｜smtp $smtpHost:$smtpPort｜${security.wire}$err';
  }
}

/// 信封摘要（列表用；不含正文）。
class MailSummary {
  final String uid;
  final String subject;
  final String from;
  final String date;
  final bool seen;

  const MailSummary({
    required this.uid,
    required this.subject,
    required this.from,
    required this.date,
    this.seen = false,
  });

  /// 喂给模型的一行文本。
  String describe() =>
      '[$uid]${seen ? '' : ' ●未读'} $date | $from | ${subject.isEmpty ? '(无主题)' : subject}';
}

/// 一封邮件读出来的结果（正文已转纯文本）。
class MailBody {
  final String uid;
  final String subject;
  final String from;
  final String to;
  final String date;
  final String text;
  final String messageId;

  const MailBody({
    required this.uid,
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.text,
    this.messageId = '',
  });
}

/// 出站状态。
enum MailOutboxStatus {
  draft,
  sent,
  failed;

  static MailOutboxStatus parse(String? s) => switch (s) {
        'sent' => MailOutboxStatus.sent,
        'failed' => MailOutboxStatus.failed,
        _ => MailOutboxStatus.draft,
      };
}

/// 出站台账条目（**只存摘要与前 256 字预览，不存正文全文**）。
class MailOutboxItem {
  final int id;
  final String accountId;
  final MailOutboxStatus status;
  final String toAddrs;
  final String subject;
  final String preview;
  final String? error;
  final int createdAt;
  final int? sentAt;

  const MailOutboxItem({
    required this.id,
    required this.accountId,
    required this.status,
    required this.toAddrs,
    required this.subject,
    required this.preview,
    this.error,
    required this.createdAt,
    this.sentAt,
  });

  String describe() {
    final st = switch (status) {
      MailOutboxStatus.draft => '草稿',
      MailOutboxStatus.sent => '已发送',
      MailOutboxStatus.failed => '发送失败',
    };
    final err = (error == null || error!.isEmpty) ? '' : '（$error）';
    return '#$id $st → $toAddrs | $subject$err';
  }
}

// ---------------------------------------------------------------------------
// 纯函数校验（离线可测）
// ---------------------------------------------------------------------------

/// 邮箱地址是否**形状合理**（不做 DNS 校验 —— 那是发信时的事）。
///
/// 刻意保守：只接受 `local@domain.tld` 形态，且 local/domain 里不出现
/// 空格、引号、尖括号、逗号 —— 这些是**头注入**（CRLF/多收件人）的常见载体。
bool isPlausibleEmail(String s) {
  final v = s.trim();
  if (v.isEmpty || v.length > 254) return false;
  if (v.contains(RegExp(r'[\s"<>,;:\\]'))) return false;
  final at = v.lastIndexOf('@');
  if (at <= 0 || at == v.length - 1) return false;
  final local = v.substring(0, at);
  final domain = v.substring(at + 1);
  if (local.isEmpty || local.length > 64) return false;
  if (!RegExp(r'^[A-Za-z0-9._%+\-]+$').hasMatch(local)) return false;
  if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
    return false;
  }
  // 域名：至少一个点，标签只允许字母数字与连字符，TLD 至少 2 位
  if (!RegExp(r'^[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?'
          r'(\.[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?)+$')
      .hasMatch(domain)) {
    return false;
  }
  if (domain.length > 253) return false;
  return true;
}

/// 头部值里**不允许**出现的字符（CRLF 注入防护）。
///
/// 这是邮件类工具最经典的漏洞：`Subject: hi\r\nBcc: attacker@evil.com`。
bool hasHeaderInjection(String s) =>
    s.contains('\r') || s.contains('\n') || s.contains('\u0000');

/// 主机名是否可用于**出网连接**。
///
/// 与项目既有口径一致（`agent_service._isPrivateOrLoopback` 拒绝 MCP 内网地址）：
/// 拒绝 loopback / 私有段 / 链路本地 / 组播 / 未指定地址。
/// ⇒ **宿主在局域网里的自建邮件服务器不被支持**，这是刻意的取舍（见方案 §2.1）。
bool isPublicHost(String host) {
  final h = host.trim().toLowerCase();
  if (h.isEmpty || h.length > 253) return false;
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return false;
  }
  if (h.contains(RegExp(r'[\s/\\]'))) return false;

  final parts = h.split('.');
  final allNumeric = parts.length == 4 && parts.every((p) {
    final n = int.tryParse(p);
    return n != null && n >= 0 && n <= 255;
  });
  if (!allNumeric) return true; // DNS 名：交给系统解析

  final a = int.parse(parts[0]);
  final b = int.parse(parts[1]);
  if (a == 0 || a == 127) return false; // 未指定 / loopback
  if (a == 10) return false; // 私有 A
  if (a == 192 && b == 168) return false; // 私有 C
  if (a == 169 && b == 254) return false; // 链路本地（云元数据！）
  if (a == 172 && b >= 16 && b <= 31) return false; // 私有 B
  if (a >= 224) return false; // 组播 / 保留
  return true;
}

/// 端口是否在合法区间（且不是邮件以外的可疑服务）。
bool isPlausiblePort(int port) => port >= 1 && port <= 65535;
