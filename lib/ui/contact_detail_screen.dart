import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_logger.dart';
import '../core/db_helper.dart';
import '../core/theme_provider.dart';
import '../core/p2p_service.dart';
import '../core/lan_service.dart';
import '../core/agent_service.dart';
import '../core/presence_service.dart';
import '../core/reputation_service.dart';
import '../l10n/app_localizations.dart';
import 'gift_picker_dialog.dart';
import 'report_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final Map<String, dynamic> friendData;
  const ContactDetailScreen({Key? key, required this.friendData}) : super(key: key);

  @override
  _ContactDetailScreenState createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  List<Map<String, dynamic>> _exclusiveLogs = [];
  bool _isLoading = true;
  /// ★ 0.50.0（体检 P1-5「social/contact 屏 DB 无降级」）：本页数据全部直连本地库，
  ///   改前库不可用会**永远停在转圈**；为 true 时改显示"读不到 + 可重试"。
  bool _dbDegraded = false;
  int _reputation = ReputationService.defaultScore;
  int _giftsSent = 0;
  int _giftsReceived = 0;
  bool _sendingGift = false;

  late String _currentAgentName;
  late String _currentMasterName;
  late String _currentNotes;
  late String _handshakeStatus;
  late String _currentTier; 
  bool _localizedDefaultsApplied = false;

  final TextEditingController _msgController = TextEditingController();

  /// M4 在场证据采集：逐键 vs 整段粘贴（判定"本人在线"的唯一依据）。
  final ComposeTracker _compose = ComposeTracker();
  final ScrollController _scrollController = ScrollController();

  late VoidCallback _updateListener;

  @override
  void initState() {
    super.initState();
    _handshakeStatus = widget.friendData['handshake_status'] ?? 'none';
    _currentTier = widget.friendData['tier'] ?? 'stranger';

    _updateListener = () { if (mounted) _loadExclusiveLogs(); };
    P2PService().listeners.add(_updateListener);
    LanService().listeners.add(_updateListener);

    _loadExclusiveLogs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizedDefaultsApplied) return;
    _localizedDefaultsApplied = true;
    final l10n = AppLocalizations.of(context);
    _currentAgentName = widget.friendData['agent_name'] ?? l10n.contactDefaultAgentName;
    _currentMasterName = widget.friendData['master_name'] ?? l10n.contactDefaultMasterName;
    _currentNotes = widget.friendData['notes'] ?? l10n.contactDefaultNotes;
  }

  @override
  void dispose() {
    P2PService().listeners.remove(_updateListener); 
    LanService().listeners.remove(_updateListener);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExclusiveLogs() async {
    final targetId = widget.friendData['agent_id'] as String;

    // ★ 0.50.0（P1-5）：整段兜住 —— 改前这里裸 await 本地库，异常会让
    //   `_isLoading` 永远为 true（页面无限转圈）。降级时 `_exclusiveLogs`
    //   保持原样、并置 `_dbDegraded` 让 UI 给出"读不到 + 重试"。
    try {
      final dbClient = await DBHelper.db;
      final friends = await dbClient.query('agent_friends', where: 'agent_id = ?', whereArgs: [targetId]);
      if (friends.isNotEmpty) {
        _handshakeStatus = friends.first['handshake_status'] as String? ?? 'none';
        _currentTier = friends.first['tier'] as String? ?? _currentTier;
        _reputation = (friends.first['reputation'] as int?) ?? ReputationService.defaultScore;
        _giftsSent = (friends.first['gifts_sent'] as int?) ?? 0;
        _giftsReceived = (friends.first['gifts_received'] as int?) ?? 0;
      }

      final logs = await DBHelper.getSocialLogs(targetId: targetId);
      // 🚀 核心修复：把 send_manual 也展示出来；gift/reco 流水以气泡可见
      final filteredLogs = logs.where((e) => e['action_type'] == 'send' || e['action_type'] == 'send_manual' || e['action_type'] == 'receive' || e['action_type'] == 'gift' || e['action_type'] == 'reco').toList().reversed.toList();

      if (mounted) {
        setState(() {
          _dbDegraded = false;
          _exclusiveLogs = filteredLogs;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        });
      }
    } catch (e) {
      AppLogger.w('contact.load', e);
      if (mounted) {
        setState(() {
          _dbDegraded = true;
          _isLoading = false;
        });
      }
    }
  }

  // 🚀 发送主人手打的内容
  void _sendManualMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final targetId = widget.friendData['agent_id'];
    // M4 在场证据：必须在 clear() 之前取，否则长度归零
    final evidence = _compose.evidence(totalChars: text.length);
    _compose.reset();
    _msgController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).contactSendingThroughGateway)));
    
  // 直接调用新的接口，免审直接发
    await AgentService().manualProactiveMessage(targetId, text, evidence: evidence);
  }

  /// 🚩 打开举报中心，并把当前联系人预填成被举报人。
  ///
  /// ★ 只带 agent id，不带聊天内容 —— 举报单**不存消息原文**（数据最小化）。
  void _openReport() {
    final agentId = widget.friendData['agent_id'] as String?;
    if (agentId == null || agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).reportNeedTarget)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          targetAgentId: agentId,
          targetName: _currentAgentName,
        ),
      ),
    );
  }

  void _showEditDetailsDialog() {
    final l10n = AppLocalizations.of(context);
    final agentNameCtrl = TextEditingController(text: _currentAgentName);
    final masterNameCtrl = TextEditingController(text: _currentMasterName);
    final notesCtrl = TextEditingController(text: _currentNotes);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(l10n.contactEditTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: agentNameCtrl, decoration: InputDecoration(labelText: l10n.contactEditAgentLabel)),
                TextField(controller: masterNameCtrl, decoration: InputDecoration(labelText: l10n.contactEditMasterLabel)),
                TextField(controller: notesCtrl, maxLines: 2, decoration: InputDecoration(labelText: l10n.contactEditNotesLabel)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            ElevatedButton(
              onPressed: () async {
                final id = widget.friendData['id'] as int;
                await DBHelper.updateAgentFriendDetails(id, agentNameCtrl.text.trim(), masterNameCtrl.text.trim(), notesCtrl.text.trim());
                Navigator.pop(context);
                setState(() {
                  _currentAgentName = agentNameCtrl.text.trim();
                  _currentMasterName = masterNameCtrl.text.trim();
                  _currentNotes = notesCtrl.text.trim();
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.contactEditSaved)));
              },
              child: Text(l10n.contactEditConfirm),
            )
          ],
        );
      },
    );
  }

  // 🎁 赠送礼物（走全部已开启通道）
  Future<void> _sendGift() async {
    if (_sendingGift) return;
    final picked = await showGiftPickerDialog(context, Provider.of<ThemeProvider>(context, listen: false));
    if (picked == null) return;
    setState(() => _sendingGift = true);
    final ok = await AgentService()
        .sendGiftToAgent(widget.friendData['agent_id'] as String, picked.$1, picked.$2);
    if (!mounted) return;
    setState(() => _sendingGift = false);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l10n.contactGiftSent(picked.$1) : l10n.contactGiftFailed),
    ));
    _loadExclusiveLogs();
  }

  // 🤝 索取推荐信（对方按其本地信誉决定是否签发）
  Future<void> _requestReco() async {
    final ok = await AgentService().sendRecoRequest(widget.friendData['agent_id'] as String);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l10n.contactRecoRequested : l10n.contactRecoFailed),
    ));
    _loadExclusiveLogs();
  }

  // 📊 应用信誉等级建议
  Future<void> _applyTierSuggestion(String suggestion) async {
    final l10n = AppLocalizations.of(context);
    if (suggestion == 'block') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.contactTierBlockToast),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    await DBHelper.updateAgentTier(widget.friendData['id'] as int, suggestion);
    if (!mounted) return;
    setState(() => _currentTier = suggestion);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.contactTierAdjusted(_tierSuggestionLabel(l10n, suggestion)))));
    _loadExclusiveLogs();
  }

  String? get _tierSuggestion =>
      ReputationService.tierSuggestion(_reputation, _currentTier);

  String _tierSuggestionLabel(AppLocalizations l10n, String suggestion) {
    switch (suggestion) {
      case 'friend': return l10n.contactTierFriend;
      case 'family': return l10n.contactTierFamily;
      case 'stranger': return l10n.contactTierStranger;
      case 'block': return l10n.contactTierBlock;
      default: return suggestion;
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    final isOnline = widget.friendData['is_online'] == 1;

    String statusText = l10n.contactStatusLocked;
    Color statusColor = Colors.blue;
    if (_handshakeStatus == 'sent') { statusText = l10n.contactStatusSent; statusColor = Colors.orange; }
    else if (_handshakeStatus == 'received') { statusText = l10n.contactStatusReceived; statusColor = Colors.purple; }
    else if (_handshakeStatus == 'accepted') { statusText = l10n.contactStatusAccepted; statusColor = Colors.green; }
    else if (_handshakeStatus == 'rejected') { statusText = l10n.contactStatusRejected; statusColor = Colors.red; }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(_currentAgentName),
        actions: [
          IconButton(icon: const Icon(Icons.workspace_premium), tooltip: l10n.contactRequestReco, onPressed: _requestReco),
          IconButton(icon: const Icon(Icons.card_giftcard), tooltip: l10n.contactSendGift, onPressed: _sendingGift ? null : _sendGift),
          IconButton(icon: const Icon(Icons.edit_note), onPressed: _showEditDetailsDialog),
          // 🚩 举报该联系人：带 agent id 预填进举报中心（页签一「提交举报」）
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: l10n.reportContactEntry,
            onPressed: _openReport,
          ),
        ],
      ),
      body: Container(
        decoration: theme.backgroundDecoration,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 26, backgroundColor: isOnline ? theme.accentColor.withOpacity(0.2) : Colors.grey.withOpacity(0.2), child: Text(widget.friendData['avatar'] ?? '🤖', style: const TextStyle(fontSize: 24))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.contactOwnerLine(_currentMasterName), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 2),
                            // ★ M2 入口细化：把"这里就是 1:1 私聊"写明白，
                            //   否则用户只是"碰巧点进来"，不知道自己进了什么界面。
                            Row(children: [
                              Icon(Icons.chat_bubble_outline, size: 12, color: theme.accentColor),
                              const SizedBox(width: 4),
                              Text(l10n.socialChatHint, style: TextStyle(fontSize: 11, color: theme.accentColor)),
                            ]),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.green : Colors.grey)),
                                const SizedBox(width: 6),
                                Text(isOnline ? l10n.contactOnline : l10n.contactOutOfRange, style: TextStyle(fontSize: 12, color: isOnline ? Colors.green : Colors.grey)),
                                const SizedBox(width: 12),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)), child: Text(statusText, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 📊 信誉条（Step 5）：本地主观分 + 等级建议
                  Row(
                    children: [
                      Text(l10n.contactReputation('$_reputation'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _reputation / 100,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation(
                              _reputation >= 70 ? Colors.greenAccent : (_reputation >= 40 ? theme.accentColor : Colors.redAccent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.contactGiftStats('$_giftsSent', '$_giftsReceived'), style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                  if (_tierSuggestion != null) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _applyTierSuggestion(_tierSuggestion!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_tierSuggestion == 'block' ? Colors.redAccent : theme.accentColor).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _tierSuggestion == 'block'
                              ? l10n.contactTierBlockBanner
                              : l10n.contactTierHintBanner(_tierSuggestionLabel(l10n, _tierSuggestion!)),
                          style: TextStyle(fontSize: 11, color: _tierSuggestion == 'block' ? Colors.redAccent : theme.accentColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: isDark ? Colors.black45 : Colors.grey[100], child: Text(l10n.contactNotesLine(_currentNotes), style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54))),
            
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.accentColor))
                : _dbDegraded
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.storage, size: 32, color: Colors.orange.shade400),
                          const SizedBox(height: 12),
                          Text(l10n.socialDbDegradedHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _dbDegraded = false;
                                _isLoading = true;
                              });
                              _loadExclusiveLogs();
                            },
                            child: Text(l10n.commonRetry),
                          ),
                        ]),
                      ),
                    )
                  : _exclusiveLogs.isEmpty
                  ? Center(child: Text(l10n.contactEmptyChat, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _exclusiveLogs.length,
                      itemBuilder: (context, index) {
                        final log = _exclusiveLogs[index];
                        final isSend = log['action_type'] == 'send' || log['action_type'] == 'send_manual';

                        // 🎁🤝 礼物/推荐信流水：居中胶囊样式，与聊天气泡区分
                        if (log['action_type'] == 'gift' || log['action_type'] == 'reco') {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.accentColor.withOpacity(0.4)),
                              ),
                              child: Column(
                                children: [
                                  Text(log['description']?.toString() ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                                  Text(_formatTime(log['timestamp'] as int), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: isSend ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isSend ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 4, top: 8),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: isSend ? (isDark ? Colors.blue[900]?.withOpacity(0.8) : Colors.blue[100]?.withOpacity(0.9)) : (isDark ? Colors.grey[800] : Colors.white.withOpacity(0.9)),
                                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: isSend ? const Radius.circular(16) : const Radius.circular(0), bottomRight: isSend ? const Radius.circular(0) : const Radius.circular(16)),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                                ),
                                child: Text(log['description'], style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                              ),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(_formatTime(log['timestamp'] as int), style: const TextStyle(fontSize: 10, color: Colors.grey)))
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // 🚀 全新底部聊天框：让用户可以强行免审发信！
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              decoration: BoxDecoration(color: isDark ? Colors.black45 : Colors.white54, border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5))),
              child: SafeArea(
                top: false, 
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: l10n.contactSayHint,
                          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          filled: true, fillColor: isDark ? Colors.black54 : Colors.white70,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        // M4：逐次记录"单次插入了多少字"——是不是粘贴只有此刻看得见
                        onChanged: (t) => _compose.onChanged(t),
                        onSubmitted: (_) => _sendManualMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(mini: true, backgroundColor: theme.accentColor, onPressed: _sendManualMessage, child: const Icon(Icons.send, color: Colors.white)),
                  ],
                ),
              ),
            )

          ],
        ),
      ),
    );
  }
}