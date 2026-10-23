import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart'; 
import 'package:path_provider/path_provider.dart'; 
import '../core/trial_client.dart';
import 'package:provider/provider.dart'; 
import 'package:dartantic_ai/dartantic_ai.dart' hide Provider; 
import 'package:shared_preferences/shared_preferences.dart'; 

import '../core/agent_service.dart';
import '../core/app_events.dart';
import '../core/app_logger.dart';
import '../core/theme_provider.dart';
import '../core/db_helper.dart';
import '../core/profile_card_store.dart';
import '../core/doc_extract/doc_extract.dart';
import '../core/voice_service.dart';
import '../l10n/app_localizations.dart';
import 'chat_sprite.dart';

class ChatMessageData {
  final String text;
  final bool isUser;
  final List<XFile> attachments;
  final int timestamp; 
  ChatMessageData({required this.text, required this.isUser, required this.timestamp, this.attachments = const []});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState();
}

// 🚀 核心修复 2：状态类名去掉下划线，变为公开类
class ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; 

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageData> _messages = [];
  final List<XFile> _selectedAttachments = [];
  // ★ 0.73.0（W4）：文档理解 —— 选取时**立即本地解析**（早失败早提示），
  //   文本按 path 缓存；发送时对 doc 类附件注入 TextPart（不再走 DataPart 二进制）。
  final Map<String, ExtractedDoc> _docTexts = {};
  /// ★ 0.83.0：试用下"文档会经官方服务器转发"这件事**本会话是否已确认过**。
  ///   刻意只放内存（不落 prefs）—— 见 `_ensureDocTrialAcked`。
  bool _docTrialAcked = false;
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // ★ 0.72.0（W3）：语音转文字（长按麦克风）。partial 实时上屏；
  //   监听期间用户点「完成」= stop（等 onFinal），点「取消」= cancel（丢弃）。
  bool _listening = false;
  String _partial = '';

  int _currentOffset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingHistory = false; 

  String? _bgImagePath;
  StreamSubscription<AppCommand>? _appSub;

  // ── 常驻悬浮小精灵（替代原来的转圈 loading） ──────────────────────────
  //
  // 阶段**只由真实信号驱动**：本页自己知道两件事（"刚发出去" / "抛异常了"），
  // 其余（检索中 / 工具中 / 完成 / 失败）来自 `AgentActivityEvent`
  // —— 由 `AgentService` 在真的跨过里程碑时发出。绝不按秒数轮换假装忙碌（R14）。
  SpritePhase _spritePhase = SpritePhase.idle;

  /// 终态（成功 / 失败 / 打断）显示一小会儿就回待机，避免小精灵一直卡在"完成"。
  Timer? _phaseSettleTimer;

  void _applyActivity(String code) {
    final next = switch (code) {
      AgentActivity.thinking => SpritePhase.thinking,
      AgentActivity.searching => SpritePhase.searching,
      AgentActivity.writing => SpritePhase.writing,
      AgentActivity.tooling => SpritePhase.tooling,
      AgentActivity.success => SpritePhase.success,
      AgentActivity.error => SpritePhase.error,
      AgentActivity.interrupted => SpritePhase.interrupted,
      // idle 与**任何尚未登记的码**都落回待机 —— 未知码不该让 UI 僵在一个
      // 不认识的姿态上（守卫另有一条断言钉住"每个码都有映射"）。
      _ => SpritePhase.idle,
    };
    final settle = next == SpritePhase.success ||
        next == SpritePhase.error ||
        next == SpritePhase.interrupted;
    _setSpritePhase(next, settleAfter: settle);
  }

  void _setSpritePhase(SpritePhase p, {bool settleAfter = false}) {
    if (!mounted) return;
    _phaseSettleTimer?.cancel();
    setState(() => _spritePhase = p);
    if (settleAfter) {
      _phaseSettleTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _spritePhase = SpritePhase.idle);
      });
    }
  }

  // 试用余量横幅（首批用户方案 §一）：仅试用模式有值，非试用/拉取失败不显示
  int? _trialRemaining;

  void _refreshTrialRemaining() {
    TrialClient.fetchRemainingTurns().then((n) {
      if (mounted && n != null) setState(() => _trialRemaining = n);
    });
  }

  @override
  void initState() {
    super.initState();
    _appSub = AppEvents.stream.listen((cmd) {
      if (cmd is ClearChatCommand) clearChatContext();
      // ★ 小精灵的语义阶段：由 AgentService 在**真实里程碑**处发出。
      if (cmd is AgentActivityEvent) _applyActivity(cmd.phase);
    });
    _refreshTrialRemaining();
    _loadHistory();
    _loadBackground(); 
    _scrollController.addListener(_scrollListener);
    // 分身自动聊天（心跳收信/房间托管/主动搭讪）也消耗试用额度，但不经过
    // 本页的发送链路——每 30 秒刷新一次，横幅才不会"永远停在进页时的读数"。
    _trialTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshTrialRemaining();
    });
  }

  Timer? _trialTimer;

  Future<void> _loadBackground() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bgImagePath = prefs.getString('chat_bg_path');
    });
  }

  @override
  void dispose() {
    // ⚠️ 语义说明（不夸大）：这里的 `interrupted` 表示**本页对那一轮的观察被中断**
    //   （人离开页面 ⇒ 小精灵随之消失），**不表示**后端那一轮被取消了 ——
    //   本页目前**没有**"取消本轮"的入口，`AgentService.sendMessage` 是
    //   一次性 await，发出后就会跑完（`if (!mounted) return` 只跳过写 UI）。
    //   写清楚是因为：把"界面走了"讲成"任务停了"就是假状态（R14）。
    if (_isLoading) {
      AppEvents.emit(AgentActivityEvent(
        phase: AgentActivity.interrupted,
        source: 'chat.dispose',
      ));
    }
    _phaseSettleTimer?.cancel();
    _appSub?.cancel();
    _audioRecorder.dispose();
    _scrollController.dispose();
    _trialTimer?.cancel();
    _textController.dispose();
    // ★ 0.72.0：页面走人 = 停听停念（不能留着一个还在收音的识别器）
    unawaited(SpeechInputService.i.cancel());
    unawaited(TtsService.i.stop());
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (_hasMore && !_isLoadingHistory) _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    if (_isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);

    final records = await DBHelper.getMessages(limit: _limit, offset: _currentOffset);
    if (!mounted) return;

    if (records.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoadingHistory = false;
      });
      return;
    }

    List<ChatMessageData> history = records.map((record) => ChatMessageData(
      text: record['text'], 
      isUser: record['isUser'] == 1,
      timestamp: record['timestamp'] as int 
    )).toList();
    
    setState(() {
      _messages.addAll(history);
      _currentOffset += records.length;
      _isLoadingHistory = false;
    });
  }

  // 🚀 公开此方法
  void clearChatContext() async {
    await AgentService().resetAgent(); 
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _currentOffset = 0;
      _hasMore = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).chatCleared)));
    _loadHistory(); 
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "${dt.month}-${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _showModernOptions({required String title, required List<Widget> options}) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: options),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1.5)), child: Icon(icon, color: color, size: 32)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showImageOptions() {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context);
    // ★ 0.73.0（W4）：菜单扩成「添加内容」——图片 + 文档；录音走麦克风菜单不动
    _showModernOptions(title: l10n.chatAttachOptionsTitle, options: [
      _buildOptionCard(icon: Icons.camera_alt_rounded, label: l10n.chatTakePhoto, color: Colors.blue, onTap: () async {
        Navigator.pop(context);
        await _pickImage(ImageSource.camera);
      }),
      _buildOptionCard(icon: Icons.photo_library_rounded, label: l10n.chatPickFromAlbum, color: Colors.purple, onTap: () async {
        Navigator.pop(context);
        await _pickImage(ImageSource.gallery);
      }),
      _buildOptionCard(icon: Icons.description_rounded, label: l10n.chatPickDocument, color: Colors.brown, onTap: () async {
        Navigator.pop(context);
        await _pickDocument();
      }),
    ]);
  }

  /// ★ 0.73.0（W4）选文档：**本地解析、零上传**（解析本身不出本机）。
  ///
  /// ★★ 0.83.0 改判（隐私审计 P0-2 · 与邮箱**同一口径**）：
  ///   0.73.0 起这里是**硬拒收**（`chatDocTrialBlocked`），理由与邮箱当年一样 ——
  ///   试用链路把模型调用经我们服务器转发 ⇒ 文档内容事实上过服务器。
  ///   但 0.82.0 主人真机反馈「试用期不让操作邮箱不合理」⇒ 邮箱已改为
  ///   **放行 + 每轮可见告知**。文档若仍硬拒，就变成一个自相矛盾的产品：
  ///   "邮件能读，文档不能发"，而两者的暴露面其实是同一回事。
  ///   ⇒ 这里同样改为**放行 + 显式确认**（会话内确认一次，不落库 ⇒ 每次
  ///   进聊天页重新问一次，避免"点过一次即永久默许"）。
  /// 解析在选取时立刻做（早失败早提示），文本缓存在 [_docTexts]。
  Future<void> _pickDocument() async {
    final l10n = AppLocalizations.of(context);
    if (!await _ensureDocTrialAcked()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'txt', 'md', 'csv'],
      );
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      // 重复选取同一文件：跳过重复解析
      if (!_docTexts.containsKey(path)) {
        _toast(l10n.chatDocParsing);
        try {
          final doc = await extractDocumentText(path);
          if (!mounted) return;
          _docTexts[path] = doc;
          _toast(doc.truncated
              ? l10n.chatDocParsedTruncated(doc.text.length)
              : l10n.chatDocParsed(doc.text.length));
        } on DocumentParseException catch (e) {
          AppLogger.w('chat.doc_parse', e);
          if (!mounted) return;
          _toast(l10n.chatDocParseFailed(e.error.name));
          return;
        } catch (e) {
          AppLogger.w('chat.doc_parse', e);
          if (!mounted) return;
          _toast(l10n.chatDocParseFailed('$e'));
          return;
        }
      }
      setState(() => _selectedAttachments.add(XFile(path)));
    } catch (e) {
      AppLogger.w('chat.pick_doc', e);
      _toast(l10n.chatDocParseFailed('$e'));
    }
  }

  void _showAudioOptions() {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context);
    _showModernOptions(title: l10n.chatAudioOptionsTitle, options: [
      _buildOptionCard(icon: Icons.mic_rounded, label: l10n.chatStartRecording, color: Colors.redAccent, onTap: () async {
        Navigator.pop(context);
        _startRecording();
      }),
      // ★ 0.72.0（W3）：语音转文字——说完变成输入框里的文字（不是音频附件）
      _buildOptionCard(icon: Icons.graphic_eq, label: l10n.chatVoiceInputTitle, color: Colors.teal, onTap: () async {
        Navigator.pop(context);
        _startVoiceInput();
      }),
      _buildOptionCard(icon: Icons.folder_rounded, label: l10n.chatLocalAudio, color: Colors.orange, onTap: () async {
        Navigator.pop(context);
        await _pickAudioFile();
      }),
    ]);
  }

  /// 选图（相机/相册）：失败必须让用户看见，绝不静默吞掉
  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1024,
      );
      if (image != null && mounted) {
        setState(() => _selectedAttachments.add(image));
      }
    } catch (e) {
      AppLogger.w('chat.pick_image', e);
      _toast(source == ImageSource.camera
          ? l10n.chatOpenCameraFailed('$e')
          : l10n.chatOpenAlbumFailed('$e'));
    }
  }

  /// 选本地音频文件
  Future<void> _pickAudioFile() async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
      );
      final path = result?.files.single.path;
      if (path != null && mounted) {
        setState(() => _selectedAttachments.add(XFile(path)));
      }
    } catch (e) {
      AppLogger.w('chat.pick_audio', e);
      _toast(l10n.chatPickAudioFailed('$e'));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// ★ 0.83.0：试用下发送文档的**放行确认**（与邮箱 `trialNotice` 同一口径）。
  ///
  /// 为什么不是"硬拒"也不是"静默放行"：
  ///   · 硬拒 ⇒ 与 0.82.0 放开的邮箱自相矛盾（"邮件能读、文档不能发"）；
  ///   · 静默放行 ⇒ 违反本仓对外承诺（试用下内容会经官方服务器转发，必须说出来）。
  /// ⇒ 折中：**弹一次确认**，把"会经官方服务器转发、我们不留存副本"摆到眼前。
  ///
  /// ★ 只记在**内存**里（`_docTrialAcked`）：不落 prefs。
  ///   落库就变成"点过一次即永久默许"，而每次重进聊天页重新问一次的成本极低。
  ///
  /// ★ 两处调用点共用这一个实现：选文档时（`_pickDocument`）+ 发送前
  ///   （`_sendMessage`，防"选完文档才切到试用"的时序边角）。
  Future<bool> _ensureDocTrialAcked() async {
    if (_docTrialAcked) return true;
    if (!await TrialClient.isTrialMode()) return true;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.description_outlined),
        title: Text(l10n.chatDocTrialTitle),
        content: Text(l10n.chatDocTrialNotice),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.chatDocTrialContinue)),
        ],
      ),
    );
    if (go != true) return false;
    _docTrialAcked = true;
    return true;
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    try {
      final granted = await _audioRecorder.hasPermission();
      if (!granted) {
        _toast(l10n.chatNoMicPermission);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      AppLogger.w('chat.start_recording', e);
      _toast(l10n.chatStartRecordingFailed('$e'));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path != null) setState(() => _selectedAttachments.add(XFile(path)));
    } catch (e) {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  // ==========================================================================
  // ★ 0.72.0（W3）语音转文字：系统 SpeechRecognizer（长按麦克风 = 直接开口）
  //
  // 结果落在**输入框**里而不是对话里——主人开口说的话，最后一遍确认/改写
  // 的权利要留在自己手上（直接发送 = 把识别错误也发出去了）。
  // 设备没有识别服务 ⇒ 明说（红线：不静默失败）。
  // ==========================================================================
  Future<void> _startVoiceInput() async {
    final l10n = AppLocalizations.of(context);
    if (!(await SpeechInputService.i.isAvailable())) {
      _toast(l10n.chatVoiceNoRecognizer);
      return;
    }
    setState(() {
      _listening = true;
      _partial = '';
    });
    SpeechInputService.i
      ..onPartial = (p) {
        if (mounted) setState(() => _partial = p);
      }
      ..onFinal = (t) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _partial = '';
        });
        final clean = t.trim();
        if (clean.isNotEmpty) {
          final cur = _textController.text.trim();
          _textController.text = cur.isEmpty ? clean : '$cur $clean';
        }
      }
      ..onError = (reason) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _partial = '';
        });
        _toast(l10n.chatVoiceFailed(reason));
      };
    final err = await SpeechInputService.i.start();
    if (err != null && mounted) {
      setState(() {
        _listening = false;
        _partial = '';
      });
      _toast(err == SpeechStartFailure.permission || err == 'permission'
          ? l10n.chatNoMicPermission
          : l10n.chatVoiceFailed(err));
    }
  }

  Future<void> _finishVoiceInput() async => SpeechInputService.i.stop();

  Future<void> _cancelVoiceInput() async {
    await SpeechInputService.i.cancel();
    if (mounted) {
      setState(() {
        _listening = false;
        _partial = '';
      });
    }
  }

  void _sendMessage() async {
    if (_isLoading) return;
    // ★ 语音播报进行中 ⇒ 新消息发出前自动停（规划 §S4：播放中可打断）
    unawaited(TtsService.i.stop());
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedAttachments.isEmpty) return;

    // ★ 自有 Key 用户的误操作护栏：超 1 万字符的输入（大段粘贴/整篇文章）
    //   会按量烧 Token——弹窗确认，用户放行才发送。试用模式在
    //   AgentService 里有更严的 5000 字符硬限（见 sendMessage）。
    if (text.length > TrialClient.ownKeyWarnChars && mounted) {
      final l10n = AppLocalizations.of(context);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.local_fire_department_outlined),
          title: Text(l10n.bigInputWarnTitle),
          content: Text(l10n.bigInputWarnBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.bigInputConfirm)),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    final attachmentsToSend = List<XFile>.from(_selectedAttachments);
    // ★ 0.73.0（W4）：先快照随本条发送的解析文本（setState 里会清缓存）
    final docsForSend = <String, ExtractedDoc>{
      for (final f in attachmentsToSend)
        if (_docTexts.containsKey(f.path)) f.path: _docTexts[f.path]!,
    };

    // ★ 0.83.0：发送前的第二道门改成**与选取时同一个确认**（`_ensureDocTrialAcked`）
    //   —— 防"选完文档才切到试用模式"的时序边角；不再是硬拒收（口径对齐邮箱）。
    //   放在消息入库**之前**：早退时 UI/DB 都不残留半截状态。
    if (docsForSend.isNotEmpty && !await _ensureDocTrialAcked()) return;

    final msgText = text.isEmpty ? "[多模态内容]" : text;
    final nowTime = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _messages.insert(0, ChatMessageData(text: msgText, isUser: true, timestamp: nowTime, attachments: attachmentsToSend));
      _isLoading = true;
      // ★ 任务开始 = 真实事实（请求确实发出去了）⇒ 小精灵立刻进入"思考"，
      //   不等 AgentService 的第一个事件，避免按下发送后有一小段"没反应"的空窗。
      _spritePhase = SpritePhase.thinking;
      _phaseSettleTimer?.cancel();
      _selectedAttachments.clear();
      for (final f in attachmentsToSend) {
        _docTexts.remove(f.path);
      }
    });
    _textController.clear();

    final currentSessionId = await DBHelper.getCurrentSessionId();
    final int userMsgId = await DBHelper.insertMessageReturnId(text: msgText, isUser: true, sessionId: currentSessionId);
    await DBHelper.insertMemoryEvent(
      eventType: 'chat_user',
      sessionId: currentSessionId,
      summary: msgText,
      refIds: userMsgId.toString(),
    );

    final List<Part> dataParts = [];
    for (var file in attachmentsToSend) {
      final doc = docsForSend[file.path];
      if (doc != null) {
        // 文档附件：注入本地解析出的**文本**（不可信包裹），不传二进制
        dataParts.add(TextPart(wrapDocumentForModel(
          file.name,
          doc.truncated
              ? '${doc.text}\n…（原文 ${doc.originalChars} 字符，已截断）'
              : doc.text,
        )));
      } else {
        dataParts.add(await DataPart.fromFile(file));
      }
    }

    // ★ 安全网（本次一并补上）：原实现里这一段**没有 try/catch**，
    //   而它包含 3 次落库调用。任何一次抛异常（磁盘满 / 库被占用 / 迁移异常）
    //   都会让 `_isLoading` **永久停在 true** —— 表现就是"转圈永远不停"，
    //   主人只能杀进程。换成小精灵后同样的坑会变成"小精灵一直在忙"，
    //   性质一样坏，所以在这里收口：出错必须显形，并且**必须能恢复**。
    final AgentResponse aiResponse;
    try {
      aiResponse = await AgentService().sendMessage(text, attachments: dataParts);

      await DBHelper.updateMessageMeta(userMsgId, currentSessionId, aiResponse.topic, aiResponse.keywords);
      await DBHelper.insertMessageWithMeta(text: aiResponse.reply, isUser: false, sessionId: currentSessionId, topic: aiResponse.topic, keywords: aiResponse.keywords);
      await DBHelper.insertMemoryEvent(
        eventType: 'chat_ai',
        sessionId: currentSessionId,
        summary: aiResponse.reply,
        topic: aiResponse.topic,
        keywords: aiResponse.keywords,
      );
    } catch (e) {
      AppLogger.w('chat.send', e);
      if (mounted) {
        setState(() => _isLoading = false);
        _setSpritePhase(SpritePhase.error, settleAfter: true);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _messages.insert(0, ChatMessageData(text: aiResponse.reply, isUser: false, timestamp: DateTime.now().millisecondsSinceEpoch));
      _isLoading = false;
    });

    // ★ 0.72.0（W3）：语音播报（默认关；开关打开才念）。speak 内部自洗
    //   Markdown + 截断 + 吞异常——TTS 挂了绝不能影响对话本身。
    unawaited(TtsService.i.speak(aiResponse.reply));

    // ★ 画像观察（本轮主人的原话 → 画像候选 → 合并入库）。
    //
    // 三条纪律：
    // ① 只吃**主人的原话** `text`，不吃 AI 回复 —— 回复里"你是个很有条理的人"
    //    被当成主人自述会记出完全相反的东西。
    // ② **不 await**：画像是增强，让主人多等一帧都不值。`observeTurn` 自己吞异常。
    // ③ 放在**回复已上屏之后**：即使它在后台把库写坏了，主人这一轮对话已经拿到。
    unawaited(ProfileCardStore.i.observeTurn(text));

    // ★ 每轮之后重取余量：此前只在 initState 拉一次 ⇒ 横幅整场都是"进页面那一刻"
    //   的读数，用户聊了 15 轮还看到"剩余 20 轮"，直到重进页面才跳变 —— 这正是
    //   "20 轮硬顶"被误当成计数出错的原因（失败分类给的是**结果**，这里给的是**趋势**）。
    _refreshTrialRemaining();

    await _cleanupSentAttachments(attachmentsToSend);
  }

  /// 只清理 App 自己创建的临时副本；用户原文件（FilePicker 等）只读不删
  Future<void> _cleanupSentAttachments(List<XFile> files) async {
    try {
      final tmp = await getTemporaryDirectory();
      for (final file in files) {
        try {
          final f = File(file.path);
          final isAppTemp = file.path.startsWith(tmp.path);
          if (isAppTemp && await f.exists()) await f.delete();
        } catch (_) {
          // 清理失败不影响发送流程
        }
      }
    } catch (_) {
      // 获取临时目录失败时跳过清理
    }
  }

  Widget _buildEmptyState(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 48, color: theme.accentColor.withOpacity(0.8)),
          const SizedBox(height: 16),
          Text(
            l10n.chatWelcomeBack,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatAgentReady,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickChip(l10n.chatQuickTechTitle, () { _textController.text = l10n.chatQuickTechPrompt; }),
              _buildQuickChip(l10n.chatQuickRadarTitle, () { _textController.text = l10n.chatQuickRadarPrompt; }),
              _buildQuickChip(l10n.chatQuickProfileTitle, () { _textController.text = l10n.chatQuickProfilePrompt; }),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);
    bool hasCustomBg = _bgImagePath != null && File(_bgImagePath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 🚀 核心修复 3：完全砍掉这里的 AppBar，节约了极其宝贵的屏幕顶端空间！
      body: Container(
        decoration: hasCustomBg
            ? BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(_bgImagePath!)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.4), 
                    BlendMode.darken
                  ),
                ),
              )
            : null,
        child: Column(
          children: [
            if (_trialRemaining != null)
              Material(
                color: theme.accentColor.withOpacity(0.12),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    child: Text(
                      '⏳ ${AppLocalizations.of(context).trialRemainingTurns(_trialRemaining!)}',
                      style: TextStyle(fontSize: 11, color: theme.accentColor),
                    ),
                  ),
                ),
              ),
            // ★ 历史分页本身也是"在取东西"。没有别的任务在跑时，让**小精灵**
            //   承担这个反馈 ⇒ 全页只剩**一个**忙碌指示器，不再同时出现两个转圈
            //   （R21：同一件事不给两个入口/两套指示）。
            //   有任务在跑时以任务阶段为准（不抢）。
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _messages.isEmpty && !_isLoading
                  ? _buildEmptyState(theme, isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true, 
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          // 这一行原来是个转圈；现在"取更早的消息"由小精灵的
                          // 检索姿态承担（见下方 ChatSpriteOverlay 的 phase 计算），
                          // 所以这里只留一个零高占位，不再出现第二个转圈。
                          return const SizedBox.shrink();
                        }
                        final msg = _messages[index];
                        final l10n = AppLocalizations.of(context);
                        return Align(
                          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(_formatTime(msg.timestamp), style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
                              ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                padding: const EdgeInsets.all(14.0),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                                decoration: BoxDecoration(
                                  // 🚀 核心修复 4：大幅度降低气泡不透明度，0.4（暗黑）和 0.65（明亮），让背景图绝美透出！
                                  color: msg.isUser 
                                      ? (isDark ? Colors.blue[900]?.withOpacity(0.4) : Colors.blue[100]?.withOpacity(0.65)) 
                                      : (isDark ? Colors.grey[900]?.withOpacity(0.4) : Colors.white.withOpacity(0.65)),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (msg.attachments.isNotEmpty) ...[
                                      Wrap(
                                        spacing: 8, runSpacing: 8,
                                        children: msg.attachments.map((file) {
                                          final isImage = file.path.endsWith('.png') || file.path.endsWith('.jpg') || file.path.endsWith('.jpeg');
                                          if (isImage) {
                                            return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(file.path), width: 150, height: 150, fit: BoxFit.cover));
                                          } else {
                                            return Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [const Icon(Icons.audiotrack, size: 20, color: Colors.orange), const SizedBox(width: 8), Text(l10n.chatAudioFile, style: TextStyle(fontSize: 13, color: isDark?Colors.white:Colors.black87))],
                                              ),
                                            );
                                          }
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    msg.isUser ? Text(msg.text, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)) : MarkdownBody(data: msg.text, selectable: true, styleSheet: MarkdownStyleSheet(p: TextStyle(color: isDark ? Colors.white : Colors.black87))), 
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // ── 常驻悬浮小精灵（替代此前的转圈 loading） ──────────
                  // 传进来的 bounds **就是消息区**（不含输入框、不含附件条）
                  // ⇒ 它怎么拖都进不到输入框上方，天然"不遮挡输入框"。
                  // 待机时整棵子树 IgnorePointer ⇒ 不挡消息的滚动与点击。
                  Positioned.fill(
                    child: ChatSpriteOverlay(
                      phase: _spritePhase == SpritePhase.idle && _isLoadingHistory
                          ? SpritePhase.searching
                          : _spritePhase,
                      size: 64,
                      accent: theme.accentColor,
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedAttachments.isNotEmpty && !_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? Colors.black54 : Colors.white54,
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedAttachments.length,
                  itemBuilder: (context, index) {
                    final file = _selectedAttachments[index];
                    final isImage = file.path.endsWith('.png') || file.path.endsWith('.jpg') || file.path.endsWith('.jpeg');
                    final isDoc = docKindOf(file.path) != null;
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 12), width: 60, height: 60,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                          child: isImage
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(file.path), fit: BoxFit.cover))
                              : Icon(isDoc ? Icons.description : Icons.audiotrack, size: 30, color: isDoc ? Colors.brown : Colors.orange),
                        ),
                        Positioned(
                          right: 4, top: 0,
                          child: GestureDetector(
                            // 文档附件：连同解析缓存一起移除（重选时会重新解析）
                            onTap: () => setState(() {
                              _docTexts.remove(_selectedAttachments[index].path);
                              _selectedAttachments.removeAt(index);
                            }),
                            child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.black87 : Colors.white.withOpacity(0.9), 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5)),
              ),
              child: SafeArea(
                top: false, 
                child: _listening
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Icon(Icons.graphic_eq, color: Colors.teal, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _partial.isEmpty ? l10n.chatVoiceListening : _partial,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 15),
                          ),
                        ),
                        TextButton(
                          onPressed: _cancelVoiceInput,
                          child: Text(l10n.commonCancel),
                        ),
                        FloatingActionButton(mini: true, backgroundColor: Colors.teal, onPressed: _finishVoiceInput, child: const Icon(Icons.done, color: Colors.white, size: 26)),
                      ],
                    )
                  : _isRecording
                  ? Row(
                      children: [
                        Expanded(child: Container(alignment: Alignment.center, child: Text(l10n.chatRecording, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)))),
                        FloatingActionButton(mini: true, backgroundColor: Colors.redAccent, onPressed: _stopRecording, child: const Icon(Icons.stop, color: Colors.white, size: 28))
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(icon: Icon(Icons.add_photo_alternate, color: theme.accentColor), onPressed: _showImageOptions),
                        // 点按 = 录音/音频文件菜单；长按 = 直接开口转文字（0.72.0）
                        GestureDetector(
                          onLongPress: _startVoiceInput,
                          child: IconButton(icon: Icon(Icons.mic, color: theme.accentColor), onPressed: _showAudioOptions),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: l10n.chatInputHint,
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        // ★ 语音播报进行中 ⇒ 显示"停止"按钮（可打断，规划 §S4）
                        ValueListenableBuilder<bool>(
                          valueListenable: TtsService.i.speaking,
                          builder: (_, speaking, __) => speaking
                              ? IconButton(
                                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.teal),
                                  tooltip: l10n.settingsTtsStop,
                                  onPressed: () => unawaited(TtsService.i.stop()),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(mini: true, backgroundColor: theme.accentColor, onPressed: _isLoading ? null : _sendMessage, child: const Icon(Icons.send, color: Colors.white)),
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
