import 'package:dartantic_ai/dartantic_ai.dart' show Schema;

/// 主聊天单轮的结构化输出（M2）：替代宿主里"正则抓 XML"的老方案。
///
/// [outputSchema] 经 `sendFor` 注入模型（dartantic 归一化输出为 JSON），
/// [fromJson] 是解码器——字段缺失/为空都有兜底值，绝不让一轮对话因为
/// 模型少吐一个字段而失败。
class AgentReply {
  final String reply;
  final String topic;
  final String keywords;

  const AgentReply({
    required this.reply,
    required this.topic,
    required this.keywords,
  });

  factory AgentReply.fromJson(Map<String, dynamic> json) {
    final topic = json['topic']?.toString() ?? '';
    return AgentReply(
      reply: json['reply']?.toString() ?? '',
      topic: topic.isEmpty ? '日常交流' : topic,
      keywords: json['keywords']?.toString() ?? '',
    );
  }

  static Schema get outputSchema => Schema.object(
        properties: {
          'reply': Schema.string(description: '对主人的回复内容（支持 Markdown）'),
          'topic': Schema.string(description: '本次对话的核心主题，限 5 字内，只用动词和名词'),
          'keywords': Schema.string(description: '3 个相关关键字，用逗号分隔'),
        },
        required: ['reply', 'topic', 'keywords'],
      );
}
