import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/db_helper.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'topic_detail_screen.dart';

class TopicListScreen extends StatefulWidget {
  @override
  _TopicListScreenState createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  List<Map<String, dynamic>> _timelineSessions = [];
  List<Map<String, dynamic>> _topicGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final timeline = await DBHelper.getSessionList();
    final topics = await DBHelper.getTopicGroupList(); 
    setState(() {
      _timelineSessions = timeline;
      _topicGroups = topics;
      _isLoading = false;
    });
  }

  // 🚀 意见1解决：精准渲染时间流标题
  String _formatTimelineStr(int start, int end, AppLocalizations l10n) {
    final s = DateTime.fromMillisecondsSinceEpoch(start);
    final e = DateTime.fromMillisecondsSinceEpoch(end);
    final sStr = "${s.year}.${s.month.toString().padLeft(2,'0')}.${s.day.toString().padLeft(2,'0')}_${s.hour.toString().padLeft(2,'0')}:${s.minute.toString().padLeft(2,'0')}";
    final eStr = "${e.hour.toString().padLeft(2,'0')}:${e.minute.toString().padLeft(2,'0')}";
    return l10n.topicChatLogSuffix("$sStr~$eStr");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          title: Text(l10n.topicArchiveTitle),
          bottom: TabBar(
            indicatorColor: theme.accentColor, labelColor: theme.accentColor, unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            tabs: [
              Tab(icon: const Icon(Icons.access_time), text: l10n.topicTabTimeline),
              Tab(icon: const Icon(Icons.folder_special), text: l10n.topicTabTopics),
            ],
          ),
        ),
        body: Container(
          decoration: theme.backgroundDecoration,
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.accentColor))
              : TabBarView(
                  children: [
                    _buildListView(_timelineSessions, true, theme, isDark),
                    _buildListView(_topicGroups, false, theme, isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list, bool isTimeline, ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    if (list.isEmpty) return Center(child: Text(l10n.topicEmptyArchive, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final data = list[index];
        final keywords = data['keywords'] ?? l10n.topicNoTag;
        final count = isTimeline ? data['user_msg_count'] : data['total_msg'];
        final identifier = isTimeline ? data['session_id'] : data['topic'];
        
        // 🚀 动态判断：如果是时间轴，显示时间聚类名称；如果是主题树，显示主题名
        final topicName = isTimeline ? _formatTimelineStr(data['start_time'], data['end_time'], l10n) : (data['topic'] ?? l10n.topicDailyChat);

        return Card(
          color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(backgroundColor: theme.accentColor.withOpacity(0.2), child: Icon(isTimeline ? Icons.linear_scale : Icons.topic, color: theme.accentColor)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(topicName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87))),
                Text(l10n.topicCountLabel('$count'), style: TextStyle(fontSize: 12, color: theme.accentColor)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(l10n.topicKeywordLine('$keywords'), style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
            ),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TopicDetailScreen(identifier: identifier, topicName: topicName, isTimeline: isTimeline)));
            },
          ),
        );
      },
    );
  }
}