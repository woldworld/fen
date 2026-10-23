/// 邮箱工具 · 传输层（可注入 ⇒ 离线可测）
///
/// 为什么单独一层：IMAP / SMTP 是**行 + 长度前缀字面量（literal）**的协议，
/// 直接对 `Socket` 写会让人无法离线测试（真实服务器不可控）。
/// 把"读一行 / 读 n 字节 / 写"抽出来之后，单测可以喂预置字节流驱动完整会话。
///
/// ★ 本项目**不新增邮件协议依赖**：`dart:io` 的 `Socket` 足够。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 连接失败（含 DNS / TLS / 超时）。所有对外失败都归到这里，
/// 便于工具层给出**可见**的原因（红线：不得静默失败）。
class MailConnectException implements Exception {
  final String reason;
  const MailConnectException(this.reason);
  @override
  String toString() => 'MailConnectException: $reason';
}

/// 协议层失败（服务端返回 NO/BAD、或格式不符预期）。
class MailProtocolException implements Exception {
  final String reason;
  const MailProtocolException(this.reason);
  @override
  String toString() => 'MailProtocolException: $reason';
}

/// 一条入站响应行，可能挂着若干**字面量**（`{n}` 后面紧跟的 n 字节）。
class MailLine {
  final String text;
  final List<List<int>> literals;

  const MailLine(this.text, this.literals);
}

/// 行/字节双模读取器 + 写入端。
///
/// 构造来源有二：① 真 `Socket`（见 [MailTransport.connectTls]）；
/// ② 测试用的任意 `Stream<List<int>>`。
class MailTransport {
  final void Function(List<int> bytes) _out;
  final List<int> _buf = [];
  StreamSubscription<List<int>>? _sub;
  final Socket? _raw;
  bool _eof = false;
  Completer<void>? _wake;

  /// 单条命令的整体超时（IMAP/SMTP 都不该长时间无响应）。
  final Duration timeout;

  MailTransport.fromStream(
    Stream<List<int>> incoming, {
    required void Function(List<int> bytes) outgoing,
    Socket? rawSocket,
    this.timeout = const Duration(seconds: 30),
  })  : _out = outgoing,
        _raw = rawSocket {
    _sub = incoming.listen(
      (d) {
        _buf.addAll(d);
        _signal();
      },
      onError: (Object _) {
        _eof = true;
        _signal();
      },
      onDone: () {
        _eof = true;
        _signal();
      },
      cancelOnError: false,
    );
  }

  /// 隐式 TLS 连接（IMAP 993 / SMTP 465）。
  static Future<MailTransport> connectTls(
    String host,
    int port, {
    Duration connectTimeout = const Duration(seconds: 15),
  }) async {
    try {
      final s = await SecureSocket.connect(host, port, timeout: connectTimeout);
      return MailTransport.fromStream(s, outgoing: s.add, rawSocket: s);
    } on SocketException catch (e) {
      throw MailConnectException('连接 $host:$port 失败：${e.message}');
    } on HandshakeException catch (e) {
      throw MailConnectException('TLS 握手失败 $host:$port：${e.message}');
    } on TimeoutException {
      throw MailConnectException('连接 $host:$port 超时');
    }
  }

  /// 明文连接（仅用于 **STARTTLS** 升级路径）。
  static Future<MailTransport> connectPlain(
    String host,
    int port, {
    Duration connectTimeout = const Duration(seconds: 15),
  }) async {
    try {
      final s = await Socket.connect(host, port, timeout: connectTimeout);
      return MailTransport.fromStream(s, outgoing: s.add, rawSocket: s);
    } on SocketException catch (e) {
      throw MailConnectException('连接 $host:$port 失败：${e.message}');
    } on TimeoutException {
      throw MailConnectException('连接 $host:$port 超时');
    }
  }

  /// 升级为 TLS（STARTTLS）。
  ///
  /// ★ 安全前提：**升级前缓冲区必须为空**。若服务端在 `220 Ready to start TLS`
  /// 之后还发了别的东西，说明我们的读取节奏与它不一致 —— 此时**拒绝升级并报错**，
  /// 绝不"带着残留字节继续"，因为那会让解密起点错位、把后续数据解成垃圾。
  Future<MailTransport> upgradeToTls(String host) async {
    if (_buf.isNotEmpty) {
      throw const MailProtocolException(
          'STARTTLS 前收到预期外数据，已中止（避免解密起点错位）');
    }
    final raw = _raw;
    if (raw == null) {
      throw const MailProtocolException('STARTTLS 只支持真实 socket 连接');
    }
    await _sub?.cancel();
    _sub = null;
    try {
      final secured = await SecureSocket.secure(raw, host: host);
      return MailTransport.fromStream(secured,
          outgoing: secured.add, rawSocket: secured, timeout: timeout);
    } on HandshakeException catch (e) {
      throw MailConnectException('STARTTLS 握手失败：${e.message}');
    }
  }

  void _signal() {
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<bool> _ensureBuffered() async {
    if (_buf.isNotEmpty) return true;
    if (_eof) return false;
    _wake = Completer<void>();
    await _wake!.future.timeout(timeout, onTimeout: () {
      _eof = true;
      return null;
    });
    return _buf.isNotEmpty;
  }

  /// 读一行（剥掉 CRLF / LF）。连接结束且无残留时返回 null。
  Future<String?> readLine() async {
    final acc = <int>[];
    while (true) {
      if (!await _ensureBuffered()) {
        return acc.isEmpty ? null : _decode(acc);
      }
      final b = _buf.removeAt(0);
      if (b == 0x0A) break;
      acc.add(b);
    }
    if (acc.isNotEmpty && acc.last == 0x0D) acc.removeLast();
    return _decode(acc);
  }

  /// 读**精确 n 字节**（IMAP literal）。
  Future<List<int>> readExact(int n) async {
    final out = <int>[];
    while (out.length < n) {
      if (!await _ensureBuffered()) {
        throw MailProtocolException('字面量读取中断：期望 $n 字节，只拿到 ${out.length}');
      }
      final take = (n - out.length) < _buf.length ? (n - out.length) : _buf.length;
      out.addAll(_buf.sublist(0, take));
      _buf.removeRange(0, take);
    }
    return out;
  }

  /// 读取直到出现 `tag ` 开头的完成行，收集沿途所有行与字面量。
  Future<List<MailLine>> readUntilTagged(String tag) async {
    final lines = <MailLine>[];
    while (true) {
      final line = await readLine();
      if (line == null) {
        throw MailProtocolException('连接在收到 $tag 完成行之前关闭');
      }
      // 行尾字面量提示 `{123}` / `{123+}`
      final m = RegExp(r'\{(\d+)\+?\}$').firstMatch(line);
      final lits = <List<int>>[];
      if (m != null) {
        lits.add(await readExact(int.parse(m.group(1)!)));
      }
      lines.add(MailLine(line, lits));
      if (line.startsWith('$tag ')) break;
    }
    return lines;
  }

  void write(String s) => _out(utf8.encode(s));

  void writeRaw(List<int> bytes) => _out(bytes);

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    try {
      _raw?.destroy();
    } catch (_) {
      // 关闭失败不影响结论
    }
  }

  static String _decode(List<int> b) => utf8.decode(b, allowMalformed: true);
}
