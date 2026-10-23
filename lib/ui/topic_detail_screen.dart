import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../core/db_helper.dart';
import '../core/theme_provider.dart';

class TopicDetailScreen extends StatelessWidget {
  final String identifier;
  final String topicName;
  final bool isTimeline;

  TopicDetailScreen({required this.identifier, required this.topicName, required this.isTimeline});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;

    return Scaffold(
      appBar: AppBar(title: Text(topicName)),
      body: Container(
        decoration: theme.backgroundDecoration,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          // 🚀 动态判断是通过 Session ID 查还是通过 Topic 名字查
          future: isTimeline ? DBHelper.getSessionMessages(identifier) : DBHelper.getTopicMessages(identifier),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: theme.accentColor));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("空空如也"));

            final messages = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg['isUser'] == 1;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    padding: const EdgeInsets.all(14.0),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(color: isUser ? (isDark ? Colors.blue[900]?.withOpacity(0.8) : Colors.blue[100]?.withOpacity(0.9)) : (isDark ? Colors.grey[900]?.withOpacity(0.8) : Colors.white.withOpacity(0.9)), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]),
                    child: isUser ? Text(msg['text'] ?? "", style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)) : MarkdownBody(data: msg['text'] ?? "", selectable: true, styleSheet: MarkdownStyleSheet(p: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}