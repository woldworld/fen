/// 确定性敏感信息检测：不依赖大模型，命中即拦截。
/// 用于社交网关的"第一道闸"，以及对外消息的脱敏兜底。
class PiiDetector {
  PiiDetector._();

  static final List<RegExp> _patterns = [
    RegExp(r'1[3-9]\d{9}'), // 大陆手机号
    RegExp(r'(?<!\d)\d{17}[\dXx](?!\d)'), // 18 位身份证
    RegExp(r'(?<!\d)\d{16,19}(?!\d)'), // 银行卡
    RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b'), // 邮箱
    // 微信号（需带前缀，避免误伤英文单词；用参数开关大小写，Dart 不认内联 (?i) 组合）
    RegExp(
      r'(?:wx|vx|wechat|v信|微信号|微信)\s*[:：]?\s*[a-z][\w-]{5,19}',
      caseSensitive: false,
    ),
    // 邮政编码：**必须带标签前缀**才判定。
    //
    // ★ 2026-10-07 修复（外交自由聊天"审核误杀"治理）：此前是一条
    //   `(?<!\d)[1-9]\d{5}(?!\d)` 的**裸 6 位数字**规则，本意是邮编，实际把
    //   一切 5-6 位数字（价格"9.9万"旁的"999999"、数量、编号、年份片段…）
    //   全当隐私拦掉 ⇒ 大量正常社交草稿被第一道闸静默 REJECT。
    //   改为"标签 + 6 位数字"（邮编/邮政编码/postal code/zip），
    //   既保住**真**邮编的检测，又消除裸数字误杀。
    RegExp(
      r'(?:邮编|邮政编码|邮政区码|postal\s*code|zip(?:\s*code)?)\s*[:：]?\s*\d{6}(?!\d)',
      caseSensitive: false,
    ),
  ];

  /// 返回第一条命中的敏感信息描述；无命中返回 null
  static String? detect(String text) {
    if (text.isEmpty) return null;
    for (final p in _patterns) {
      final m = p.firstMatch(text);
      if (m != null) return '命中敏感信息模式: ${m.group(0)}';
    }
    return null;
  }

  /// 对外文本脱敏：手机号打码
  static String maskPhoneNumbers(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'1[3-9]\d{9}'),
      (m) => '${m.group(0)!.substring(0, 3)}****${m.group(0)!.substring(7)}',
    );
  }

  /// 对外文本全面脱敏：手机号 / 邮箱 / 身份证 / 银行卡 / 微信号全部打码。
  /// 主人手动发送的消息（免审通道）依赖这一层兜底——免审 ≠ 裸奔。
  static String maskSensitive(String raw) {
    var text = raw;
    // 微信号（先打码，避免其内部 [a-z][\w-]{5,19} 被其他规则抢先破坏结构）
    text = text.replaceAllMapped(
      RegExp(r'(?:wx|vx|wechat|v信|微信号|微信)\s*[:：]?\s*[a-z][\w-]{5,19}',
          caseSensitive: false),
      (m) {
        final g = m.group(0)!;
        final idx = g.indexOf(RegExp(r'[a-z][\w-]{5,19}', caseSensitive: false));
        if (idx <= 0) return g;
        final id = g.substring(idx);
        return '${g.substring(0, idx)}${id[0]}***';
      },
    );
    // 邮箱：保留首字符与域名
    text = text.replaceAllMapped(
      RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b'),
      (m) {
        final g = m.group(0)!;
        final at = g.indexOf('@');
        return '${g[0]}***${g.substring(at)}';
      },
    );
    // 身份证（18 位，含校验位 X）
    text = text.replaceAllMapped(
      RegExp(r'(?<!\d)\d{17}[\dXx](?!\d)'),
      (m) => '${m.group(0)!.substring(0, 3)}***********${m.group(0)!.substring(14)}',
    );
    // 银行卡（16-19 位纯数字；身份证已先行处理，不会二次命中）
    text = text.replaceAllMapped(
      RegExp(r'(?<!\d)\d{16,19}(?!\d)'),
      (m) => '****${m.group(0)!.substring(m.group(0)!.length - 4)}',
    );
    // 手机号（大陆 11 位；放在长号码之后，避免被银行卡规则整段吞掉）
    text = maskPhoneNumbers(text);
    return text;
  }

  /// 简单判断是否包含 PII（供 UI/日志快速展示）
  static bool containsSensitive(String text) => detect(text) != null;
}
