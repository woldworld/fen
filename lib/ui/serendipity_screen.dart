import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/agent_service.dart';
import '../core/serendipity_repo.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'help_dot.dart';
import 'zhouyi.dart'; // 确保 zhouyi.dart 与此文件同级，或修改相对路径

// ==================== 本地独立存储（已迁移到 sqflite） ====================
// 保留类名与接口，UI 无需改动；底层由 SerendipityRepository 提供
class SerendipityDB {
  static Map<String, dynamic> get cache => SerendipityRepository.instance.cache;

  static Future<void> init() => SerendipityRepository.instance.init();

  static Future<void> save() => SerendipityRepository.instance.save();
}

class SerendipityScreen extends StatefulWidget {
  const SerendipityScreen({Key? key}) : super(key: key);
  @override
  _SerendipityScreenState createState() => _SerendipityScreenState();
}

class _SerendipityScreenState extends State<SerendipityScreen> with SingleTickerProviderStateMixin {
  bool _isInit = false;
  late TabController _tabController;
  int energy = 0;

  // 各模块状态变量
  final morningEventCtrl = TextEditingController(), morningDetailCtrl = TextEditingController(), morningObstacleCtrl = TextEditingController(), morningOutcomeCtrl = TextEditingController();
  int timerSeconds = 120; Timer? morningTimer; bool timerActive = false, morningCompleted = false, morningLoading = false; String aiMorningFeedback = "";

  // 稳定 ID（不是显示文案）：本地化后仍要用于比对与落库，故与 UI 标签分离
  String challengeType = "blindbox";
  int blindBoxIndex = 0;
  final chCustomCtrl = TextEditingController(), chJourneyCtrl = TextEditingController(), chReflectCtrl = TextEditingController();
  bool chLoading = false; String aiChFeedback = "";

  final alBadCtrl = TextEditingController(), alReactCtrl = TextEditingController(), alResCtrl = TextEditingController();
  String selectedStrategy = "downward", aiAlFeedback = ""; bool alLoading = false;

  final nlIntCtrl = TextEditingController(), nlChoiceCtrl = TextEditingController(), nlReflectCtrl = TextEditingController();
  String aiNlFeedback = ""; bool nlLoading = false;

  final diaryCtrl = TextEditingController(); String aiDiaryFeedback = ""; bool diaryLoading = false;

  final oracleEvtCtrl = TextEditingController(), oracleChatCtrl = TextEditingController();
  String oracleGuaText = ""; List<Map<String, String>> oracleChatHistory = [];
  bool oracleActive = false, oracleLoading = false, oracleIsTapping = false; int oracleTapCount = 0; int? currentOracleId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initDB();
    _generateBlindBox();
  }

  Future<void> _initDB() async {
    await SerendipityDB.init();
    // 周易数据资产化后惰性加载，进入页面即预载，保证起卦体验流畅
    await Zhouyi.loadData();
    setState(() {
      energy = SerendipityDB.cache['luck_energy'] ?? 0;
      _isInit = true;
    });
  }

  @override
  void dispose() {
    morningTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _generateBlindBox() {
    // 只存下标，文案在展示时按当前语言取（切语言无需重建任务，也避开 initState 取不到 context）
    blindBoxIndex = Random().nextInt(6);
  }

  String _blindBoxText(AppLocalizations l10n) => [
        l10n.serendipityBlindBox1,
        l10n.serendipityBlindBox2,
        l10n.serendipityBlindBox3,
        l10n.serendipityBlindBox4,
        l10n.serendipityBlindBox5,
        l10n.serendipityBlindBox6,
      ][blindBoxIndex % 6];

  void addEnergy(int amount) async {
    HapticFeedback.mediumImpact(); 
    String today = DateTime.now().toIso8601String().substring(0, 10);
    SerendipityDB.cache['luck_energy'] = (SerendipityDB.cache['luck_energy'] ?? 0) + amount; 
    SerendipityDB.cache['daily_energy'] ??= {}; 
    SerendipityDB.cache['daily_energy'][today] = (SerendipityDB.cache['daily_energy'][today] ?? 0) + amount;
    await SerendipityDB.save();
    setState(() => energy = SerendipityDB.cache['luck_energy']);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).serendipityEnergyGained(amount))));
  }

  // 🚀 核心重构：直接调用口袋AI的 AgentService
  Future<String> callIntegratedAI(String sysPrompt, String msg) async {
    final l10n = AppLocalizations.of(context);
    final payloadText = "【心理导师指令】：$sysPrompt\n\n【用户倾诉内容】：$msg\n\n(请暂时抛弃管家身份，完全代入上述心理导师角色作答，无需生成多余的XML标签)";
    final res = await AgentService().sendMessage(payloadText);
    // 从 AgentResponse 中提取返回的字符串
    String reply = res.reply.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (reply.isEmpty) return l10n.serendipityNetworkError;
    return reply;
  }

  // 每个 tab 的标题都带一个「?」使用说明（集成前每个页面都有，集成时丢了）。
  // 六个 tab 同一时刻只显示一个 ⇒ 同屏最多 1 个问号，符合「同屏 ≤3」的纪律。
  Widget moduleHeader(String title, ThemeProvider theme, HelpTopic topic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: HelpTitle(
        text: title,
        topic: topic,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget letterPaperCard(List<Widget> children, ThemeProvider theme) {
    List<Widget> separated = [];
    for (int i = 0; i < children.length; i++) {
      separated.add(Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: children[i]));
      if (i != children.length - 1) separated.add(Divider(color: Colors.grey.withOpacity(0.2), height: 1));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.isDark ? Colors.black54 : Colors.white.withOpacity(0.9), 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: separated),
    );
  }

  // 重构策略：稳定 ID → 本地化标签（落库/提示词都取标签，保证日志自洽）
  String _strategyLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case "surplus":
        return l10n.serendipityStrategySurplus;
      case "dilate":
        return l10n.serendipityStrategyDilate;
      default:
        return l10n.serendipityStrategyDownward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    if (!_isInit) return Scaffold(backgroundColor: isDark ? Colors.black : Colors.white, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serendipityTitle),
        actions: [Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text(l10n.serendipityEnergyBadge(energy), style: TextStyle(fontWeight: FontWeight.bold, color: theme.accentColor))))],
        bottom: TabBar(
          controller: _tabController, isScrollable: true, indicatorColor: theme.accentColor, labelColor: theme.accentColor, unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: [Tab(text: l10n.serendipityTabMorning), Tab(text: l10n.serendipityTabChallenge), Tab(text: l10n.serendipityTabAlchemist), Tab(text: l10n.serendipityTabNight), Tab(text: l10n.serendipityTabDiary), Tab(text: l10n.serendipityTabOracle)],
        ),
      ),
      body: Container(
        decoration: theme.backgroundDecoration,
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMorningTab(theme), _buildChallengeTab(theme), _buildAlchemistTab(theme), 
              _buildNightTab(theme), _buildDiaryTab(theme), _buildOracleTab(theme)
            ],
          ),
        ),
      ),
    );
  }

  // ================= 各个 Tab 视图 (沿用原逻辑，UI适配口袋主题) =================
  Widget _buildMorningTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    var logs = (SerendipityDB.cache['morning_logs'] as List).reversed.take(5).toList();
    String getTimerPrompt(int s) { if (s > 90) return l10n.serendipityTimerPrompt1; if (s > 60) return l10n.serendipityTimerPrompt2; if (s > 30) return l10n.serendipityTimerPrompt3; return l10n.serendipityTimerPrompt4; }
    
    return ListView(padding: const EdgeInsets.all(16), children: [
      moduleHeader(l10n.serendipityMorningHeader, theme, HelpTopic.serendipityMorning),
      if (!morningCompleted) letterPaperCard([
        Text(l10n.serendipityIntentLock, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
        TextField(controller: morningEventCtrl, enabled: !timerActive, decoration: InputDecoration(labelText: l10n.serendipityEventHint)),
        if (timerActive) ...[
          Center(child: Text("${timerSeconds}s", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold))),
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(getTimerPrompt(timerSeconds), textAlign: TextAlign.center, style: TextStyle(color: theme.accentColor, fontStyle: FontStyle.italic)))),
          Center(child: TextButton(onPressed: () { morningTimer?.cancel(); setState(() { timerActive = false; timerSeconds = 120; }); }, child: Text(l10n.serendipityGiveUp, style: const TextStyle(color: Colors.redAccent)))),
        ] else ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, minimumSize: const Size(double.infinity, 45)),
          onPressed: () {
            if (morningEventCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.serendipityNeedEvent))); return; }
            setState(() => timerActive = true);
            morningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (timerSeconds > 1) setState(() => timerSeconds--); else { timer.cancel(); HapticFeedback.heavyImpact(); setState(() { timerActive = false; morningCompleted = true; }); }
            });
          }, child: Text(l10n.serendipityStartPreview, style: const TextStyle(color: Colors.white)),
        )
      ], theme),
      if (morningCompleted) letterPaperCard([
        Text(l10n.serendipityTargetEvent(morningEventCtrl.text), style: const TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: morningDetailCtrl, decoration: InputDecoration(labelText: l10n.serendipityDetailHint)),
        TextField(controller: morningObstacleCtrl, decoration: InputDecoration(labelText: l10n.serendipityObstacleHint)),
        TextField(controller: morningOutcomeCtrl, decoration: InputDecoration(labelText: l10n.serendipityOutcomeHint)),
        if (aiMorningFeedback.isNotEmpty) Text(l10n.serendipityAiBoost(aiMorningFeedback), style: TextStyle(color: theme.accentColor)),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: morningLoading ? null : () async {
              if (morningDetailCtrl.text.trim().isEmpty) return;
              setState(() { morningLoading = true; aiMorningFeedback = l10n.serendipityAiInjecting; });
              aiMorningFeedback = await callIntegratedAI("你是一位积极心理学教练。请运用'皮格马利翁效应'(期望效应)和'心智预演'理论，给用户极具能量的鼓励，彻底锁死好运预期。", "事件：${morningEventCtrl.text}\n细节：${morningDetailCtrl.text}\n结局：${morningOutcomeCtrl.text}");
              setState(() => morningLoading = false);
            }, child: morningLoading ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(color:Colors.white)) : Text(l10n.serendipityReinforce),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (morningDetailCtrl.text.trim().isEmpty) return;
              (SerendipityDB.cache['morning_logs'] as List).add({"event": morningEventCtrl.text, "detail": morningDetailCtrl.text, "obstacle": morningObstacleCtrl.text, "outcome": morningOutcomeCtrl.text, "ai": aiMorningFeedback, "time": DateTime.now().toIso8601String()});
              addEnergy(5); setState(() { morningEventCtrl.clear(); morningDetailCtrl.clear(); morningObstacleCtrl.clear(); morningOutcomeCtrl.clear(); aiMorningFeedback = ""; timerSeconds = 120; morningCompleted = false; });
            }, child: Text(l10n.serendipitySave5, style: const TextStyle(color: Colors.white)),
          )),
        ])
      ], theme),
      if (logs.isNotEmpty) Text(l10n.serendipityMorningArchive, style: const TextStyle(color: Colors.grey)),
      ...logs.map((l) => letterPaperCard([Text(l10n.serendipityLogTime(l['time'].toString().substring(0, 16)), style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(l10n.serendipityLogEvent(l['event'])), Text(l10n.serendipityLogDetail(l['detail'])), Text(l10n.serendipityLogOutcome(l['outcome'])), if (l['ai'] != null && l['ai'].toString().isNotEmpty) Text(l10n.serendipityLogAiBoost(l['ai']), style: TextStyle(color: theme.accentColor, fontSize: 13))], theme))
    ]);
  }

  Widget _buildChallengeTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    var logs = (SerendipityDB.cache['challenge_logs'] as List).reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      moduleHeader(l10n.serendipityChallengeHeader, theme, HelpTopic.serendipityChallenge),
      letterPaperCard([
        DropdownButtonFormField<String>(
          value: challengeType, decoration: InputDecoration(labelText: l10n.serendipityActionTypeLabel),
          items: [
            DropdownMenuItem(value: "blindbox", child: Text(l10n.serendipityChallengeTypeBlindBox)),
            DropdownMenuItem(value: "custom", child: Text(l10n.serendipityChallengeTypeCustom)),
          ],
          onChanged: (v) { setState(() { challengeType = v!; if (v == "blindbox") _generateBlindBox(); }); } 
        ),
        if (challengeType == "custom") TextField(controller: chCustomCtrl, decoration: InputDecoration(labelText: l10n.serendipityCustomChallengeHint))
        else Container(
          padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), border: Border.all(color: Colors.orange.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.serendipityBlindBoxDrawn, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 5),
            Text(_blindBoxText(l10n), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 5),
            InkWell(onTap: () { HapticFeedback.selectionClick(); setState(() => _generateBlindBox()); }, child: Text(l10n.serendipityRedraw, style: TextStyle(color: theme.accentColor, fontSize: 12, decoration: TextDecoration.underline)))
          ])
        ),
        TextField(controller: chJourneyCtrl, decoration: InputDecoration(labelText: l10n.serendipityJourneyHint)),
        TextField(controller: chReflectCtrl, decoration: InputDecoration(labelText: l10n.serendipityReflectHint)),
        if (aiChFeedback.isNotEmpty) Text(l10n.serendipityAiColon(aiChFeedback), style: TextStyle(color: theme.accentColor)),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: chLoading ? null : () async {
              if (chJourneyCtrl.text.trim().isEmpty) return;
              setState(() { chLoading = true; aiChFeedback = l10n.serendipityAiAnalyzing; });
              aiChFeedback = await callIntegratedAI("你是一位行为心理学导师，熟知理查德·怀斯曼教授的幸运科学理论。请从'机会感知力'的角度，评价用户的打破惯性行动。", "经过：${chJourneyCtrl.text}\n反思：${chReflectCtrl.text}");
              setState(() => chLoading = false);
            }, child: chLoading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white)) : Text(l10n.serendipityComment),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (chJourneyCtrl.text.trim().isEmpty) return;
              String title = challengeType == "custom" ? chCustomCtrl.text : _blindBoxText(l10n);
              (SerendipityDB.cache['challenge_logs'] as List).add({"title": title, "journey": chJourneyCtrl.text, "reflect": chReflectCtrl.text, "ai": aiChFeedback, "time": DateTime.now().toIso8601String()});
              addEnergy(15); setState(() { chJourneyCtrl.clear(); chReflectCtrl.clear(); aiChFeedback = ""; _generateBlindBox(); });
            }, child: Text(l10n.serendipitySave15, style: const TextStyle(color: Colors.white)),
          )),
        ])
      ], theme),
      if (logs.isNotEmpty) Text(l10n.serendipityChallengeArchive, style: const TextStyle(color: Colors.grey)),
      ...logs.map((l) => letterPaperCard([Text(l10n.serendipityLogGoal(l['title']), style: const TextStyle(fontWeight: FontWeight.bold)), Text(l10n.serendipityLogJourney(l['journey'])), Text(l10n.serendipityLogReflect(l['reflect'])), if (l['ai'] != "") Text(l10n.serendipityLogAiComment(l['ai']), style: TextStyle(color: theme.accentColor, fontSize: 13))], theme))
    ]);
  }

  Widget _buildAlchemistTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    var logs = (SerendipityDB.cache['reframed_events'] as List).reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      moduleHeader(l10n.serendipityAlchemistHeader, theme, HelpTopic.serendipityAlchemist),
      letterPaperCard([
        TextField(controller: alBadCtrl, decoration: InputDecoration(labelText: l10n.serendipitySetbackHint)), TextField(controller: alReactCtrl, decoration: InputDecoration(labelText: l10n.serendipityNegReactHint)),
        DropdownButtonFormField<String>(value: selectedStrategy, decoration: InputDecoration(labelText: l10n.serendipityStrategyLabel), items: [
          DropdownMenuItem(value: "downward", child: Text(l10n.serendipityStrategyDownward)),
          DropdownMenuItem(value: "surplus", child: Text(l10n.serendipityStrategySurplus)),
          DropdownMenuItem(value: "dilate", child: Text(l10n.serendipityStrategyDilate)),
        ], onChanged: (v) => setState(() => selectedStrategy = v!)),
        TextField(controller: alResCtrl, decoration: InputDecoration(labelText: l10n.serendipityNewCognitionHint)),
        if (aiAlFeedback.isNotEmpty) Text(l10n.serendipityAiColon(aiAlFeedback), style: TextStyle(color: theme.accentColor)),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: alLoading ? null : () async { if (alBadCtrl.text.trim().isEmpty) return; setState(() { alLoading = true; aiAlFeedback = l10n.serendipityAiAnalyzing; }); aiAlFeedback = await callIntegratedAI("你是CBT专家，熟知理查德·怀斯曼教授的幸运理论，从'坏运转化'角度分析，先给个评分。", "坏事：${alBadCtrl.text}\n策略：${_strategyLabel(l10n, selectedStrategy)}\n结果：${alResCtrl.text}"); setState(() => alLoading = false); }, child: alLoading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white)) : Text(l10n.serendipityScore))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: () { if (alBadCtrl.text.trim().isEmpty) return; (SerendipityDB.cache['reframed_events'] as List).add({"bad": alBadCtrl.text, "react": alReactCtrl.text, "strat": _strategyLabel(l10n, selectedStrategy), "res": alResCtrl.text, "ai": aiAlFeedback, "time": DateTime.now().toIso8601String()}); addEnergy(10); setState(() { alBadCtrl.clear(); alReactCtrl.clear(); alResCtrl.clear(); aiAlFeedback = ""; }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text(l10n.serendipitySave10, style: const TextStyle(color: Colors.white)))),
        ])
      ], theme),
      if (logs.isNotEmpty) Text(l10n.serendipityAlchemistArchive, style: const TextStyle(color: Colors.grey)),
      ...logs.map((l) => letterPaperCard([Text(l10n.serendipityLogSetback(l['bad']), style: const TextStyle(fontWeight: FontWeight.bold)), Text(l10n.serendipityLogReact(l['react'])), Text(l10n.serendipityLogStrategy(l['strat']), style: const TextStyle(color: Colors.orangeAccent)), Text(l10n.serendipityLogCognition(l['res'])), if (l['ai'] != "") Text(l10n.serendipityLogAiScore(l['ai']), style: TextStyle(color: theme.accentColor, fontSize: 13))], theme))
    ]);
  }

  Widget _buildNightTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    var logs = (SerendipityDB.cache['night_logs'] as List).reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      moduleHeader(l10n.serendipityNightHeader, theme, HelpTopic.serendipityNight),
      letterPaperCard([
        TextField(controller: nlIntCtrl, decoration: InputDecoration(labelText: l10n.serendipityIntuitionHint)), TextField(controller: nlChoiceCtrl, decoration: InputDecoration(labelText: l10n.serendipityChoiceHint)), TextField(controller: nlReflectCtrl, decoration: InputDecoration(labelText: l10n.serendipityReflectStrategyHint)),
        if (aiNlFeedback.isNotEmpty) Text(l10n.serendipityAiColon(aiNlFeedback), style: TextStyle(color: theme.accentColor)),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: nlLoading ? null : () async { if (nlIntCtrl.text.trim().isEmpty) return; setState(() { nlLoading = true; aiNlFeedback = l10n.serendipityAiAnalyzing; }); aiNlFeedback = await callIntegratedAI("你是深谙潜意识心理学的专家，熟知理查德·怀斯曼教授的幸运科学理论。从'幸运直觉力'解析。", "直觉：${nlIntCtrl.text}\n决策：${nlChoiceCtrl.text}"); setState(() => nlLoading = false); }, child: nlLoading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white)) : Text(l10n.serendipityParse))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: () { if (nlIntCtrl.text.trim().isEmpty) return; (SerendipityDB.cache['night_logs'] as List).add({"id": DateTime.now().millisecondsSinceEpoch, "int": nlIntCtrl.text, "choice": nlChoiceCtrl.text, "ref": nlReflectCtrl.text, "ai": aiNlFeedback, "val": 0, "time": DateTime.now().toIso8601String()}); addEnergy(10); setState(() { nlIntCtrl.clear(); nlChoiceCtrl.clear(); nlReflectCtrl.clear(); aiNlFeedback = ""; }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text(l10n.serendipitySave10, style: const TextStyle(color: Colors.white)))),
        ])
      ], theme),
      if (logs.isNotEmpty) Text(l10n.serendipityNightArchive, style: const TextStyle(color: Colors.grey)),
      ...logs.map((l) => letterPaperCard([Text(l10n.serendipityLogIntuition(l['int']), style: const TextStyle(fontWeight: FontWeight.bold)), Text(l10n.serendipityLogChoice(l['choice'])), Text(l10n.serendipityLogNightReflect(l['ref'])), if (l['ai'] != "") Text(l10n.serendipityLogAiParse(l['ai']), style: TextStyle(color: theme.accentColor, fontSize: 13)), l['val'] == 1 ? Text(l10n.serendipityIntuitionCameTrue, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : ElevatedButton(onPressed: () { l['val'] = 1; addEnergy(20); setState((){}); }, child: Text(l10n.serendipityVerifyTrue))], theme))
    ]);
  }

  Widget _buildDiaryTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    var logs = (SerendipityDB.cache['free_diary_logs'] as List).reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      moduleHeader(l10n.serendipityDiaryHeader, theme, HelpTopic.serendipityDiary),
      letterPaperCard([
        TextField(
          controller: diaryCtrl, maxLines: 5, 
          decoration: InputDecoration(
            labelText: l10n.serendipityDiaryHint, alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true, fillColor: theme.isDark ? Colors.black26 : Colors.black.withOpacity(0.05)
          )
        ),
        if (aiDiaryFeedback.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l10n.serendipityAiListen(aiDiaryFeedback), style: TextStyle(color: theme.accentColor))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: diaryLoading ? null : () async {
              if (diaryCtrl.text.trim().isEmpty) return;
              setState(() { diaryLoading = true; aiDiaryFeedback = l10n.serendipityAiReading; });
              aiDiaryFeedback = await callIntegratedAI("你是一位温暖专业的心理导师，请从情绪管理角度给与支持。", "今天日记：\n${diaryCtrl.text}");
              setState(() => diaryLoading = false);
            }, child: diaryLoading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white)) : Text(l10n.serendipityListen),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (diaryCtrl.text.trim().isEmpty) return;
              (SerendipityDB.cache['free_diary_logs'] as List).add({"content": diaryCtrl.text, "ai": aiDiaryFeedback, "time": DateTime.now().toIso8601String()});
              addEnergy(5); setState(() { diaryCtrl.clear(); aiDiaryFeedback = ""; });
            }, child: Text(l10n.serendipityKeep, style: const TextStyle(color: Colors.white)),
          )),
        ])
      ], theme),
      if (logs.isNotEmpty) Text(l10n.serendipityDiaryArchive, style: const TextStyle(color: Colors.grey)),
      ...logs.map((l) => letterPaperCard([
        Text(l10n.serendipityLogDiaryTime(l['time'].toString().substring(0, 16)), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Container(
          width: double.infinity, margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black12, border: Border(left: BorderSide(color: theme.accentColor, width: 3)), borderRadius: BorderRadius.circular(4)),
          child: Text("${l['content']}", style: const TextStyle(height: 1.5)),
        ),
        if (l['ai'] != "") Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.serendipityLogDiaryEcho(l['ai']), style: TextStyle(color: theme.accentColor, fontSize: 13, height: 1.4)))
      ], theme))
    ]);
  }

  Widget _buildOracleTab(ThemeProvider theme) {
    final l10n = AppLocalizations.of(context);
    var logs = (SerendipityDB.cache['oracle_logs'] as List).reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      moduleHeader(l10n.serendipityOracleHeader, theme, HelpTopic.serendipityOracle),
      letterPaperCard([
        TextField(controller: oracleEvtCtrl, enabled: !oracleIsTapping && !oracleActive, decoration: InputDecoration(labelText: l10n.serendipityOracleEventHint)),
        const SizedBox(height: 10),
        if (!oracleIsTapping && !oracleActive) ElevatedButton(onPressed: () { if (oracleEvtCtrl.text.trim().isEmpty) return; setState(() { oracleIsTapping = true; oracleTapCount = 0; }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, minimumSize: const Size(double.infinity, 45)), child: Text(l10n.serendipityEnterRitual, style: const TextStyle(color: Colors.white))),
        if (oracleIsTapping) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text(l10n.serendipityOracleTapPrompt, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent, fontSize: 15))),
          Center(child: InkWell(borderRadius: BorderRadius.circular(60), onTap: () async { 
            HapticFeedback.lightImpact(); 
            setState(() => oracleTapCount++); 
            if (oracleTapCount >= 6) { 
              setState(() { oracleIsTapping = false; }); 
              HapticFeedback.heavyImpact(); 
              List<String> guaResult = Zhouyi.getAgua(); 
              String guaName = guaResult[0], guaMeaning = guaResult[1]; 
              setState(() { oracleGuaText = l10n.serendipityOracleResultPrefix(guaName); oracleActive = true; oracleLoading = true; oracleChatHistory.clear(); }); 
              addEnergy(5); 
              String res = await callIntegratedAI("你是一位易经与心理学结合的导师。请结合事件、卦象及卦义，为用户提供建设性的解读，并建言献策！", "问事：${oracleEvtCtrl.text}\n得卦：$guaName\n卦义参考：$guaMeaning"); 
              
              setState(() { 
                oracleChatHistory.add({"role": "ai", "msg": res}); 
                oracleLoading = false; 
                currentOracleId = DateTime.now().millisecondsSinceEpoch; 
              }); 
              
              (SerendipityDB.cache['oracle_logs'] as List).add({
                "id": currentOracleId, "event": oracleEvtCtrl.text, "guaxiang": guaName,
                "chat_history": List.from(oracleChatHistory),
                "time": DateTime.now().toIso8601String()
              });
              await SerendipityDB.save();
            } 
          }, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.shade900, boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.change_circle_outlined, size: 45, color: Colors.white), Text("$oracleTapCount / 6", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])))),
        ],
        if (oracleActive) ...[
          Text(oracleGuaText, style: const TextStyle(fontSize: 15, color: Colors.orangeAccent, fontWeight: FontWeight.bold, height: 1.5)),
          const Divider(color: Colors.white24),
          ...oracleChatHistory.map((m) => Container(margin: const EdgeInsets.symmetric(vertical: 6), alignment: m['role'] == 'ai' ? Alignment.centerLeft : Alignment.centerRight, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: m['role'] == 'ai' ? theme.accentColor.withOpacity(0.3) : Colors.blueGrey.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: Text(m['msg']!, style: const TextStyle(height: 1.4))))),
          if (oracleLoading) Padding(padding: const EdgeInsets.all(8.0), child: Text(l10n.serendipityOracleThinking, style: TextStyle(color: theme.accentColor, fontStyle: FontStyle.italic))),
          Row(children: [ 
            Expanded(child: TextField(controller: oracleChatCtrl, decoration: InputDecoration(labelText: l10n.serendipityOracleAskHint))), 
            IconButton(icon: Icon(Icons.send, color: theme.accentColor), onPressed: () async { 
              if (oracleChatCtrl.text.trim().isEmpty) return; 
              String q = oracleChatCtrl.text; 
              setState(() { oracleChatHistory.add({"role": "user", "msg": q}); oracleChatCtrl.clear(); oracleLoading = true; }); 
              String res = await callIntegratedAI("你是一位易经与心理学结合的导师。", "用户追问：$q"); 
              
              setState(() { oracleChatHistory.add({"role": "ai", "msg": res}); oracleLoading = false; }); 
              
              var currentLog = (SerendipityDB.cache['oracle_logs'] as List).firstWhere((l) => l['id'] == currentOracleId, orElse: () => null);
              if (currentLog != null) {
                currentLog['chat_history'] = List.from(oracleChatHistory);
                await SerendipityDB.save();
              }
              HapticFeedback.lightImpact(); 
            }) 
          ]),
          TextButton(onPressed: () => setState(() { oracleActive = false; oracleEvtCtrl.clear(); }), child: Text(l10n.serendipityNewQuestion, style: const TextStyle(color: Colors.grey)))
        ]
      ], theme),
      if (logs.isNotEmpty) Text(l10n.serendipityOracleArchive, style: const TextStyle(color: Colors.grey)),
      ...logs.map((l) {
        List chatList = l['chat_history'] ?? [];
        String chatStr = chatList.map((m) => "${m['role'] == 'user' ? l10n.serendipitySpeakerMe : 'AI'}: ${m['msg']}").join("\n\n");
        return letterPaperCard([
          Text(l10n.serendipityLogTime(l['time'].toString().substring(0, 16)), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(l10n.serendipityOracleLogEvent(l['event']), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(l10n.serendipityOracleLogGua(l['guaxiang']), style: const TextStyle(color: Colors.orangeAccent)),
          const Divider(),
          Text(chatStr, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ], theme);
      })
    ]);
  }
}
