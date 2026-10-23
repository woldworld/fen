import 'package:flutter/material.dart';

import '../core/mail/imap_client.dart';
import '../core/mail/mail_credential_store.dart';
import '../core/mail/mail_errors.dart';
import '../core/mail/mail_store_db.dart';
import '../core/mail/mail_types.dart';
import '../l10n/app_localizations.dart';

/// 邮箱账号绑定页（管理 → 邮箱）
///
/// 形态照 `dsh_import_screen.dart`（填地址 → 测试 → 保存）：**只做一件事**，
/// 把"邮箱能不能用"当场验出来，不留到聊天里才发现。
///
/// 三条与方案一致的对外承诺（页面文案必须与它们一致，不得夸大）：
/// ① 口令只在本机（页面明说，且**不提供任何"同步到云端"的开关**）；
/// ② 只支持**公网**邮件服务器（`isPublicHost` 拒绝内网/回环，理由写在提示里）；
/// ③ 口令用**应用专用密码 / 授权码**（不是账号登录密码）。
///
/// ★ 0.66.0 改版（真机反馈："我用 163 邮箱，怎么填？没看明白"）：
///   - 预置补上**国内三家**（163 / 126 / QQ）—— 原来是 Gmail/Outlook/Yahoo/iCloud
///     四个海外预置，163 用户根本没有可点的项；
///   - **输入邮箱地址即自动匹配服务器**（`x@163.com` → imap.163.com），
///     且"自动 / 手动"两态**在页面上明说**，不再出现"地址是 163、服务器却还是
///     Office365"这种自相矛盾的组合（真机截图即此形态）；
///   - 口令提示**按服务商给**：网易/QQ 要"授权码"，不再只讲 Gmail 的应用密码。
///
/// ★ 自动匹配的**边界**（避免"我改了它又给我改回去"）：
///   只要用户**手动碰过任一服务器字段**，就停掉自动覆盖（`_serversTouched`），
///   页面上给一句"已手动填写"的说明；点回任一服务商 chip 才重新交回自动。
class MailAccountScreen extends StatefulWidget {
  const MailAccountScreen({Key? key}) : super(key: key);

  @override
  State<MailAccountScreen> createState() => _MailAccountScreenState();
}

/// 常见服务商预填（只填服务器，**不预填任何凭据**）。
///
/// `domains` 用于"输入地址即自动匹配"：命中后带出该服务商的服务器与加密方式。
/// 只列**主干域名**，子域用 `.endsWith` 覆盖（如 `mail.163.com`）。
class _Preset {
  final String id;
  final String label;
  final List<String> domains;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;
  final MailSecurity security;

  const _Preset(this.id, this.label, this.domains, this.imapHost, this.imapPort,
      this.smtpHost, this.smtpPort, this.security);

  /// 域名是否属于本服务商（精确或子域）。
  bool matchesDomain(String domain) =>
      domains.any((d) => domain == d || domain.endsWith('.$d'));

  /// 该服务商该填什么口令（文案在 ARB，五语种各一份）。
  String passwordHint(AppLocalizations l10n) => switch (id) {
        'gmail' => l10n.mailAppPasswordHintGmail,
        'netease' => l10n.mailAppPasswordHintNetease,
        'qq' => l10n.mailAppPasswordHintQQ,
        'outlook' => l10n.mailAppPasswordHintOutlook,
        _ => l10n.mailAppPasswordHint,
      };
}

const List<_Preset> _presets = [
  _Preset('netease', '163', ['163.com'], 'imap.163.com', 993, 'smtp.163.com',
      465, MailSecurity.tls),
  _Preset('netease', '126', ['126.com'], 'imap.126.com', 993, 'smtp.126.com',
      465, MailSecurity.tls),
  _Preset('qq', 'QQ', ['qq.com', 'foxmail.com'], 'imap.qq.com', 993,
      'smtp.qq.com', 465, MailSecurity.tls),
  _Preset('gmail', 'Gmail', ['gmail.com', 'googlemail.com'], 'imap.gmail.com',
      993, 'smtp.gmail.com', 465, MailSecurity.tls),
  _Preset('outlook', 'Outlook',
      ['outlook.com', 'hotmail.com', 'live.com', 'msn.com'],
      'outlook.office365.com', 993, 'smtp.office365.com', 587,
      MailSecurity.starttls),
  _Preset('yahoo', 'Yahoo', ['yahoo.com', 'ymail.com'], 'imap.mail.yahoo.com',
      993, 'smtp.mail.yahoo.com', 465, MailSecurity.tls),
  _Preset('icloud', 'iCloud', ['icloud.com', 'me.com', 'mac.com'],
      'imap.mail.me.com', 993, 'smtp.mail.me.com', 587, MailSecurity.starttls),
];

class _MailAccountScreenState extends State<MailAccountScreen> {
  final _address = TextEditingController();
  final _display = TextEditingController();
  final _password = TextEditingController();
  // 服务器**不再预填海外默认**：留空 + 地址自动匹配/手动填写，
  // 免得"没细看就保存"把一个连不上的组合存进去。
  final _imapHost = TextEditingController();
  final _imapPort = TextEditingController(text: '993');
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController(text: '465');

  MailSecurity _security = MailSecurity.tls;
  List<MailAccount> _accounts = const [];
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  /// 当前地址命中的服务商（用于"自动填入"说明与该服务商的口令提示）。
  _Preset? _matched;

  /// 用户是否**手动碰过**服务器字段；一旦为真，自动匹配不再覆盖。
  bool _serversTouched = false;

  @override
  void initState() {
    super.initState();
    _address.addListener(_onAddressChanged);
    _load();
  }

  @override
  void dispose() {
    _address.removeListener(_onAddressChanged);
    for (final c in [
      _address,
      _display,
      _password,
      _imapHost,
      _imapPort,
      _smtpHost,
      _smtpPort,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final all = await MailStoreDb.accounts();
    if (!mounted) return;
    setState(() => _accounts = all);
  }

  /// 取地址里的域名（小写，无 `@` 或空尾则空串）。
  static String _domainOf(String address) {
    final v = address.trim().toLowerCase();
    final at = v.lastIndexOf('@');
    if (at < 0 || at == v.length - 1) return '';
    return v.substring(at + 1);
  }

  static _Preset? _matchPreset(String address) {
    final d = _domainOf(address);
    if (d.isEmpty) return null;
    for (final p in _presets) {
      if (p.matchesDomain(d)) return p;
    }
    return null;
  }

  /// 地址变化 → 重新匹配；命中且用户没手动改过服务器，就带出该服务商的配置。
  ///
  /// ★ 这里**只写控制器、不调 l10n**（listener 里拿 context 容易在 dispose 边缘出事），
  ///   文案统一在 `build` 里按 `_matched` 组装。
  void _onAddressChanged() {
    if (!mounted) return;
    final p = _matchPreset(_address.text);
    setState(() {
      _matched = p;
      if (p != null && !_serversTouched) _fillServers(p);
    });
  }

  /// 把服务商的服务器/端口/加密写进控制器（**程序化赋值不会触发 `onChanged`**，
  /// 所以不会被误判成"手动填写"）。
  void _fillServers(_Preset p) {
    _imapHost.text = p.imapHost;
    _imapPort.text = '${p.imapPort}';
    _smtpHost.text = p.smtpHost;
    _smtpPort.text = '${p.smtpPort}';
    _security = p.security;
  }

  /// 点服务商 chip：显式意图 ⇒ 重新交回自动模式并填入。
  void _applyPreset(_Preset p) {
    setState(() {
      _matched = p;
      _serversTouched = false;
      _fillServers(p);
    });
  }

  /// 用户手动编辑了某个服务器字段 ⇒ 停掉自动覆盖。
  void _markServersTouched(String _) {
    if (_serversTouched) return;
    setState(() => _serversTouched = true);
  }

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _messageIsError = error;
    });
  }

  Future<void> _saveAndTest() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;

    final address = _address.text.trim().toLowerCase();
    final pw = _password.text.trim();
    final imapHost = _imapHost.text.trim();
    final smtpHost = _smtpHost.text.trim();
    final imapPort = int.tryParse(_imapPort.text.trim()) ?? 0;
    final smtpPort = int.tryParse(_smtpPort.text.trim()) ?? 0;

    // 全部**先校验再落库** —— 把一个连不上的账号存进去，只会让主人在聊天里
    // 收到一堆莫名其妙的失败。
    if (!isPlausibleEmail(address)) {
      _say(l10n.mailTestFail(l10n.mailAddress), error: true);
      return;
    }
    // 服务器留空 ⇒ 给一句"该怎么办"的话（而不是复用一条看不懂的报错）。
    if (imapHost.isEmpty || smtpHost.isEmpty) {
      _say(l10n.mailNeedServers, error: true);
      return;
    }
    if (pw.isEmpty) {
      _say(l10n.mailTestFail(l10n.mailAppPassword), error: true);
      return;
    }
    if (!isPublicHost(imapHost) || !isPublicHost(smtpHost)) {
      // 内网/回环被刻意拒绝（与 MCP 载入同一口径）：不给本机服务当跳板
      _say(l10n.mailTestFail('IMAP/SMTP'), error: true);
      return;
    }
    if (!isPlausiblePort(imapPort) || !isPlausiblePort(smtpPort)) {
      _say(l10n.mailTestFail('port'), error: true);
      return;
    }

    final account = MailAccount(
      id: address,
      address: address,
      displayName: _display.text.trim(),
      imapHost: imapHost,
      imapPort: imapPort,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      security: _security,
    );

    setState(() => _busy = true);
    _say(l10n.mailTesting);
    await MailStoreDb.upsertAccount(account);
    await MailCredentialStore.save(account.id, pw);

    final err = await _probe(account, pw);
    if (err == null) {
      await MailStoreDb.markResult(account.id, ok: true);
      _say(l10n.mailTestOk);
      _password.clear();
    } else {
      await MailStoreDb.markResult(account.id, ok: false, error: err);
      _say(l10n.mailTestFail(_reasonText(l10n, err)), error: true);
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _testExisting(MailAccount acc) async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    final pw = await MailCredentialStore.secretOf(acc.id);
    if (pw == null) {
      _say(l10n.mailTestFail(l10n.mailAppPassword), error: true);
      return;
    }
    setState(() => _busy = true);
    _say(l10n.mailTesting);
    final err = await _probe(acc, pw);
    if (err == null) {
      await MailStoreDb.markResult(acc.id, ok: true);
      _say(l10n.mailTestOk);
    } else {
      await MailStoreDb.markResult(acc.id, ok: false, error: err);
      _say(l10n.mailTestFail(_reasonText(l10n, err)), error: true);
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  /// 把探测失败码翻译成**能照做**的句子；不认识的码原样透出（服务端原文）。
  ///
  /// ★ 原来是直接把 `'auth'` 塞进 `mailTestFail` ⇒ 页面显示"连接失败：auth"，
  ///   等于没说（真机反馈"看不懂"的一部分）。码只留在数据层，展示层一律翻译。
  static String _reasonText(AppLocalizations l10n, String code) => switch (code) {
        'auth' => l10n.mailErrAuth,
        'unsafeLogin' => l10n.mailErrUnsafe,
        _ => code,
      };

  /// 真正的探测（IMAP 登录 + SELECT INBOX）。返回 null = 成功。
  Future<String?> _probe(MailAccount acc, String pw) async {
    final client = ImapClient(
      host: acc.imapHost,
      port: acc.imapPort,
      user: acc.address,
      password: pw,
    );
    try {
      await client.testConnection();
      return null;
    } catch (e) {
      // 分类收口在 `mail_errors.dart`（纯函数、离线可测）：认不出 ⇒ 原样透出。
      // ★ 0.81.0 起网易 163/126 的 `NO LOGIN ...` 也归到 'auth' —— 否则填错
      //   授权码的用户看到的是原始报文（0.80.0 真机截图实证）。
      final s = '$e';
      return classifyMailProbeError(s) ??
          (s.length > 200 ? '${s.substring(0, 200)}…' : s);
    }
  }

  Future<void> _unbind(MailAccount acc) async {
    final l10n = AppLocalizations.of(context);
    await MailStoreDb.deleteAccount(acc.id);
    await MailCredentialStore.forget(acc.id);
    _say(l10n.mailUnbound);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final matched = _matched;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n.mailIntro,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          if (_message != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: (_messageIsError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary)
                    .withOpacity(0.08),
              ),
              child: Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _messageIsError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),

          // ---------------- 已绑定账号 ----------------
          Text(l10n.mailTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_accounts.isEmpty)
            Text(l10n.mailNone, style: theme.textTheme.bodySmall)
          else
            ..._accounts.map((a) => _accountTile(a, theme)),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // ---------------- 新增账号 ----------------
          Text(l10n.mailAddSection, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(l10n.mailPresetLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, height: 1.4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in _presets)
                ActionChip(
                  label: Text(p.label),
                  onPressed: _busy ? null : () => _applyPreset(p),
                ),
            ],
          ),
          if (matched != null) ...[
            const SizedBox(height: 6),
            Text(
              _serversTouched
                  ? l10n.mailManualServers
                  : l10n.mailAutoFilled(matched.label),
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    _serversTouched ? theme.hintColor : theme.colorScheme.primary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _field(_address, l10n.mailAddress,
              keyboard: TextInputType.emailAddress),
          _field(_display, l10n.mailDisplayName),
          _field(_password, l10n.mailAppPassword, obscure: true, mono: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              matched?.passwordHint(l10n) ?? l10n.mailAppPasswordHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, height: 1.4),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _field(_imapHost, 'IMAP',
                    mono: true, onChanged: _markServersTouched),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: _field(_imapPort, '993',
                    mono: true, onChanged: _markServersTouched),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _field(_smtpHost, 'SMTP',
                    mono: true, onChanged: _markServersTouched),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: _field(_smtpPort, '465',
                    mono: true, onChanged: _markServersTouched),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<MailSecurity>(
            // ★ 换服务商时加密方式会变（Outlook/iCloud 是 STARTTLS）——
            //   FormField 只在首次 build 取 `initialValue`，故用 key 强制重建，
            //   否则下拉显示会与 `_security` 脱节。
            key: ValueKey('mail-sec-${_security.name}'),
            initialValue: _security,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: MailSecurity.tls,
                child: Text(l10n.mailSecurityTls,
                    style: theme.textTheme.bodySmall),
              ),
              DropdownMenuItem(
                value: MailSecurity.starttls,
                child: Text(l10n.mailSecurityStarttls,
                    style: theme.textTheme.bodySmall),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() => _security = v ?? MailSecurity.tls),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _saveAndTest,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt),
            label: Text(l10n.mailSaveAndTest),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _accountTile(MailAccount a, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.address, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${a.imapHost}:${a.imapPort} · ${a.smtpHost}:${a.smtpPort}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            if (a.lastError != null && a.lastError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.mailLastError(_reasonText(l10n, a.lastError!)),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _testExisting(a),
                  child: Text(l10n.mailTestConn),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _unbind(a),
                  child: Text(l10n.mailUnbind,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    bool mono = false,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        onChanged: onChanged,
        style: mono ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : null,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
