/// 互介卡「可聊话题」输入解析：中英文逗号与顿号都算分隔符。
///
/// 为什么单独放一个文件：
/// - 世界页（跨圈互荐）与社交页（通讯录互介）是**同一个操作**的两个人入口，
///   分隔符口径必须只定义一次，否则两处会漂移（一处认顿号、一处不认）。
/// - 用 `\u` 转义而非字面全角标点：字面 CJK 会被 `tool/scan_hardcoded.dart`
///   计入「硬编码中文」，但这里只是一组**分隔符**，不是要给用户看的文案。
///   （同 `dsh_import_service.dart` 的 CJK 正则处理方式。）
library;

/// 话题分隔符：`,` `，` `、`
final RegExp kTopicSeparators = RegExp('[,,\\uFF0C\\u3001]');

/// 把一行输入切成若干个去空白的话题，丢弃空项。
List<String> parseTopics(String raw) => raw
    .split(kTopicSeparators)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
