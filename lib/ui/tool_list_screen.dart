import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/db_helper.dart';
import '../core/agent_service.dart';
import '../core/plugin_bus.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'dsh_import_screen.dart';
import 'help_dot.dart';
import 'plugin_labels.dart';

class ToolListScreen extends StatefulWidget {
  @override
  _ToolListScreenState createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  bool _aiAutoSelect = true; 
  bool _isLoading = true;
  int _totalPlugins = 0;
  int _signedPlugins = 0;
  int _tamperedPlugins = 0;

  @override
  void initState() {
    super.initState();
    _loadAutoSelectState();
    _loadPluginSummary();
  }

  Future<void> _loadPluginSummary() async {
    final rows = await DBHelper.getAllToolsRaw();
    final secret = await DBHelper.getOrCreateDeviceSecret();
    var signed = 0;
    var tampered = 0;
    for (final r in rows) {
      final st = PluginBus.statusOfRow(r, secret);
      if (st == 'tampered') {
        tampered++;
      } else if (st == 'ok' || st == 'builtin') {
        signed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _totalPlugins = rows.length;
      _signedPlugins = signed;
      _tamperedPlugins = tampered;
    });
  }

  Future<void> _loadAutoSelectState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _aiAutoSelect = prefs.getBool('ai_auto_select_tools') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleAutoSelect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_auto_select_tools', value);
    setState(() {
      _aiAutoSelect = value;
    });
    // M1：轻量刷新（注册表 diff + 重组工具参数），不再全量重建大脑
    await AgentService().refreshDbTools();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(title: Text(l10n.mcpCenterTitle)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : Container(
              decoration: theme.backgroundDecoration,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: isDark ? Colors.black87 : Colors.white.withOpacity(0.95),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: theme.accentColor, size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.mcpAutoTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                const SizedBox(height: 4),
                                Text(l10n.mcpAutoSubtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _aiAutoSelect,
                            activeColor: theme.accentColor,
                            onChanged: _toggleAutoSelect,
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Card(
                    color: isDark
                        ? Colors.black.withOpacity(0.6)
                        : Colors.amber.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _tamperedPlugins > 0 ? Icons.gpp_bad : Icons.verified_user,
                            color: _tamperedPlugins > 0 ? Colors.redAccent : Colors.green,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(
                                      _tamperedPlugins > 0
                                          ? l10n.mcpBusSummaryTampered(_totalPlugins, _signedPlugins, _tamperedPlugins)
                                          : l10n.mcpBusSummaryClean(_totalPlugins, _signedPlugins),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // 0.51.0：工具总线说明（签名/能力声明/永不加载篡改件）搬进 `?`
                                  const HelpDot(topic: HelpTopic.toolBus),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Card(
                    color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DshImportScreen()),
                        );
                        _loadPluginSummary();
                      },
                      leading: CircleAvatar(
                        backgroundColor: theme.accentColor.withOpacity(0.15),
                        child: Icon(Icons.extension, color: theme.accentColor),
                      ),
                      title: Text(l10n.mcpImportTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(l10n.mcpImportSubtitle,
                          style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.mcpCategoryHeader, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 12),

                  _buildCategoryCard(
                    title: l10n.mcpCatLocalTitle,
                    subtitle: l10n.mcpCatLocalSubtitle,
                    icon: Icons.settings_ethernet,
                    type: "local",
                    theme: theme,
                  ),

                  _buildCategoryCard(
                    title: l10n.mcpCatMcpTitle,
                    subtitle: l10n.mcpCatMcpSubtitle,
                    icon: Icons.language,
                    type: "mcp",
                    theme: theme,
                  ),

                  _buildCategoryCard(
                    title: l10n.mcpCatSkillTitle,
                    subtitle: l10n.mcpCatSkillSubtitle,
                    icon: Icons.psychology,
                    type: "skill",
                    theme: theme,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    required ThemeProvider theme,
  }) {
    final isDark = theme.isDark;
    return Card(
      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CategoryToolsScreen(type: type, aiAutoSelect: _aiAutoSelect)),
          );
          _loadPluginSummary();
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: theme.accentColor.withOpacity(0.15), child: Icon(icon, color: theme.accentColor)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryToolsScreen extends StatefulWidget {
  final String type;
  final bool aiAutoSelect; 

  CategoryToolsScreen({required this.type, required this.aiAutoSelect});

  @override
  _CategoryToolsScreenState createState() => _CategoryToolsScreenState();
}

class _CategoryToolsScreenState extends State<CategoryToolsScreen> {
  List<Map<String, dynamic>> _tools = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    final list = await DBHelper.getToolsByType(widget.type);
    final secret = await DBHelper.getOrCreateDeviceSecret();
    for (final t in list) {
      t['__sigStatus'] = PluginBus.statusOfRow(t, secret);
      t['__caps'] = PluginBus.capabilitiesOfRow(t);
      t['__risk'] = PluginBus.riskOfRow(t);
    }
    setState(() {
      _tools = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleTool(int id, bool val) async {
    if (widget.aiAutoSelect) return; 
    String? name;
    for (final t in _tools) {
      if (t['id'] == id) {
        name = t['name'] as String?;
        break;
      }
    }
    await DBHelper.updateToolState(id, val);
    if (!val && name != null) {
      // 关闭即吊销：授权必须随插件一起失效
      await PluginBus.revoke(name);
    }
    _loadTools();
    // M1：开关即时生效（注册表 diff），不再全量重建大脑
    await AgentService().refreshDbTools();
  }

  void _showAddToolDialog({Map<String, dynamic>? editTool}) {
    final nameController = TextEditingController(text: editTool?['name'] ?? '');
    final descController = TextEditingController(text: editTool?['description'] ?? '');
    final contentController = TextEditingController(text: editTool?['content'] ?? '');
    final isEdit = editTool != null;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        String contentLabel = l10n.mcpContent;
        String contentHint = l10n.mcpContentHint;
        if (widget.type == 'local') {
          contentLabel = l10n.mcpWebhookLabel;
          contentHint = l10n.mcpWebhookHint;
        } else if (widget.type == 'mcp') {
          contentLabel = l10n.mcpServerLabel;
          contentHint = l10n.mcpServerHint;
        } else {
          contentLabel = l10n.mcpPromptLabel;
          contentHint = l10n.mcpPromptHint;
        }

        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(isEdit ? l10n.mcpEditToolTitle : l10n.mcpAddToolTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController, 
                  enabled: !isEdit, 
                  decoration: InputDecoration(labelText: l10n.mcpToolNameLabel),
                ),
                TextField(controller: descController, decoration: InputDecoration(labelText: l10n.mcpToolDescLabel)),
                TextField(controller: contentController, maxLines: 3, decoration: InputDecoration(labelText: contentLabel, hintText: contentHint)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.mcpCancel)),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                final content = contentController.text.trim();
                if (name.isNotEmpty && desc.isNotEmpty && content.isNotEmpty) {
                  if (isEdit) {
                    final id = editTool['id'] as int;
                    await DBHelper.updateTool(id, name, desc, content);
                    await PluginBus.stampRow(
                      id,
                      name: name,
                      type: widget.type,
                      description: desc,
                      content: content,
                      version: (editTool['version'] as String?) ??
                          PluginBus.defaultVersion,
                    );
                  } else {
                    final id =
                        await DBHelper.insertTool(name, desc, widget.type, content);
                    await PluginBus.stampRow(
                      id,
                      name: name,
                      type: widget.type,
                      description: desc,
                      content: content,
                    );
                  }
                  Navigator.pop(context);
                  _loadTools();
                  // M1：编辑后注册表重注册，即时生效
                  await AgentService().refreshDbTools();
                }
              },
              child: Text(l10n.mcpSaveRegister),
            )
          ],
        );
      },
    );
  }

  Future<void> _deleteTool(int id) async {
    String? name;
    for (final t in _tools) {
      if (t['id'] == id) {
        name = t['name'] as String?;
        break;
      }
    }
    await DBHelper.deleteTool(id);
    if (name != null) await PluginBus.revoke(name);
    _loadTools();
    // M1：删除后注册表即时卸载
    await AgentService().refreshDbTools();
  }

  Widget _metaChip({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: isDark ? Colors.white : color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    String typeTitle = l10n.mcpManageTools;
    if (widget.type == 'local') typeTitle = l10n.mcpTypeLocal;
    if (widget.type == 'mcp') typeTitle = l10n.mcpTypeMcp;
    if (widget.type == 'skill') typeTitle = l10n.mcpTypeSkill;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(typeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddToolDialog(),
          )
        ],
      ),
      body: Container(
        decoration: theme.backgroundDecoration,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.accentColor))
            : _tools.isEmpty
                ? Center(child: Text(l10n.mcpEmpty, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tools.length,
                    itemBuilder: (context, index) {
                      final tool = _tools[index];
                      final id = tool['id'] as int;
                      final name = tool['name'] ?? '';
                      final desc = tool['description'] ?? '';
                      final content = tool['content'] ?? '';
                      final isEnabled = tool['is_enabled'] == 1;
                      final isFromDream = tool['is_from_dream'] == 1;
                      final sigStatus = tool['__sigStatus'] ?? 'unsigned';
                      final isTampered = sigStatus == 'tampered';
                      final caps = (tool['__caps'] as List?)?.cast<String>() ??
                          const <String>[];
                      final risk = (tool['__risk'] as String?) ?? PluginRisk.low;

                      final bool switchValue =
                          widget.aiAutoSelect ? true : (isEnabled && !isTampered);
                      final bool isSwitchClickable =
                          !widget.aiAutoSelect && !isTampered; 

                      return Card(
                        color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: switchValue ? theme.accentColor.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            child: Icon(Icons.code, color: switchValue ? theme.accentColor : Colors.grey),
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                              ),
                              if (isFromDream) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(l10n.mcpTagDream, style: const TextStyle(fontSize: 10, color: Colors.deepPurple)),
                                ),
                              ],
                              if (isTampered) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(l10n.mcpTagSigInvalid, style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            isTampered
                                ? l10n.mcpSubTampered(desc)
                                : (isFromDream && !isEnabled
                                    ? l10n.mcpSubDreamPending(desc)
                                    : desc),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: switchValue,
                                activeColor: theme.accentColor,
                                onChanged: isSwitchClickable 
                                    ? (val) => _toggleTool(id, val) 
                                    : null, 
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteTool(id),
                              )
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🚀 核心修复：Colors.black10 修改为内置的 Colors.black12 🌟
                                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _metaChip(
                                        label: sigStatus == 'builtin'
                                            ? l10n.mcpSigBuiltin
                                            : sigStatus == 'ok'
                                                ? l10n.mcpSigOk
                                                : sigStatus == 'unsigned'
                                                    ? l10n.mcpSigUnsigned
                                                    : l10n.mcpSigInvalid,
                                        color: isTampered
                                            ? Colors.redAccent
                                            : Colors.green,
                                        isDark: isDark,
                                      ),
                                      _metaChip(
                                        label: 'v${tool['version'] ?? PluginBus.defaultVersion}',
                                        color: theme.accentColor,
                                        isDark: isDark,
                                      ),
                                      _metaChip(
                                        label: (tool['author'] as String?) ??
                                            PluginBus.defaultAuthor,
                                        color: Colors.blueGrey,
                                        isDark: isDark,
                                      ),
                                      _metaChip(
                                        label: riskLabel(l10n, risk),
                                        color: risk == PluginRisk.high
                                            ? Colors.orange
                                            : risk == PluginRisk.medium
                                                ? Colors.amber
                                                : Colors.green,
                                        isDark: isDark,
                                      ),
                                      for (final cap in caps)
                                        _metaChip(
                                          label: capabilityLabel(l10n, cap),
                                          color: Colors.indigo,
                                          isDark: isDark,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(l10n.mcpToolDescHeader, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text(desc, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.type == 'skill' ? l10n.mcpInjectionDetail : l10n.mcpPhysicalUrl, 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black12, borderRadius: BorderRadius.circular(8)),
                                    child: Text(content, style: const TextStyle(fontFamily: 'Courier', fontSize: 13)),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                      label: Text(l10n.mcpEditParams, style: const TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor),
                                      onPressed: () => _showAddToolDialog(editTool: tool),
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
