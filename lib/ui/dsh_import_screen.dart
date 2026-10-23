import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/agent_service.dart';
import '../core/dsh_import_service.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'tool_list_screen.dart';

/// ============================================================
/// 从 DeepSeek Harness（dsh）生态导入插件
///
/// 三条通道（对应 dsh_import_service.dart）：
///   ① 技能（SKILL.md）—— 粘贴或选文件，一键直译成我们的技能；
///   ② MCP 服务 —— 粘配置或地址，直连；
///   ③ 插件包体检 —— 上传 package.json + cordis.patch.yml，
///      告诉用户哪些能搬、哪些搬不了。
///
/// 导入的东西一律**默认关闭**，要主人到工具页手动开启。
/// ============================================================
class DshImportScreen extends StatefulWidget {
  const DshImportScreen({Key? key}) : super(key: key);

  @override
  State<DshImportScreen> createState() => _DshImportScreenState();
}

class _DshImportScreenState extends State<DshImportScreen> {
  final _skillController = TextEditingController();
  final _mcpController = TextEditingController();
  final _packageJsonController = TextEditingController();
  final _patchController = TextEditingController();

  bool _busy = false;
  DshImportOutcome? _skillResult;
  DshImportOutcome? _mcpResult;
  DshInspectResult? _inspectResult;

  @override
  void dispose() {
    _skillController.dispose();
    _mcpController.dispose();
    _packageJsonController.dispose();
    _patchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // 操作
  // ------------------------------------------------------------------

  Future<void> _pasteInto(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      _toast(AppLocalizations.of(context).dshImportClipboardEmpty);
      return;
    }
    setState(() => controller.text = text);
  }

  Future<void> _pickSkillFiles() async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'markdown'],
      );
      if (picked == null || picked.files.isEmpty) return;

      final files = <String, String>{};
      for (final f in picked.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        files[f.name] = utf8.decode(bytes, allowMalformed: true);
      }
      if (files.isEmpty) {
        _toast(l10n.dshImportNoFileContent);
        return;
      }

      setState(() => _busy = true);
      final result = await DshImportService.importSkills(files);
      await AgentService().initAgent();
      if (!mounted) return;
      setState(() {
        _skillResult = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.dshImportPickFailed('$e'));
    }
  }

  Future<void> _importPastedSkill() async {
    final text = _skillController.text.trim();
    if (text.isEmpty) {
      _toast(AppLocalizations.of(context).dshImportPasteSkillFirst);
      return;
    }
    setState(() => _busy = true);
    // 粘贴内容按单个技能处理；文件名提示交给 frontmatter 里的 name 字段
    final result =
        await DshImportService.importSkills({'pasted-skill': text});
    await AgentService().initAgent();
    if (!mounted) return;
    setState(() {
      _skillResult = result;
      _busy = false;
    });
  }

  Future<void> _importMcp() async {
    setState(() => _busy = true);
    final result = await DshImportService.importMcpServers(_mcpController.text);
    await AgentService().initAgent();
    if (!mounted) return;
    setState(() {
      _mcpResult = result;
      _busy = false;
    });
  }

  void _inspect() {
    setState(() {
      // 只存结构化结果；文案在 build 里按当前语言渲染（语言切换后可重排）。
      _inspectResult = DshImportService.inspectPackage(
        packageJson: _packageJsonController.text,
        patchYaml: _patchController.text,
      );
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------------
  // 界面
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(title: Text(l10n.dshImportTitle)),
      body: Container(
        decoration: theme.backgroundDecoration,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _introCard(theme, isDark),
            const SizedBox(height: 16),
            _sectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.psychology_alt,
              title: l10n.dshImportSecSkillTitle,
              subtitle: l10n.dshImportSecSkillSub,
              children: [
                _textArea(
                  controller: _skillController,
                  hint: l10n.dshImportSkillHint,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _actionRow(
                  theme: theme,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pasteInto(_skillController),
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: Text(l10n.dshImportPaste),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickSkillFiles,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(l10n.dshImportPickFiles),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _importPastedSkill,
                      icon: const Icon(Icons.download_done, size: 18),
                      label: Text(l10n.dshImportImport),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_skillResult != null) _outcomeView(_skillResult!, isDark),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.hub_outlined,
              title: l10n.dshImportSecMcpTitle,
              subtitle: l10n.dshImportSecMcpSub,
              children: [
                _textArea(
                  controller: _mcpController,
                  hint: l10n.dshImportMcpHint(
                      '{"mcpServers": {"my-tool": {"url": "https://..."}}}'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _actionRow(
                  theme: theme,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pasteInto(_mcpController),
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: Text(l10n.dshImportPaste),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _importMcp,
                      icon: const Icon(Icons.link, size: 18),
                      label: Text(l10n.dshImportImport),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_mcpResult != null) _outcomeView(_mcpResult!, isDark),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.fact_check_outlined,
              title: l10n.dshImportSecInspectTitle,
              subtitle: l10n.dshImportSecInspectSub,
              children: [
                _textArea(
                  controller: _packageJsonController,
                  hint: l10n.dshImportPackageJsonHint,
                  isDark: isDark,
                  lines: 4,
                ),
                const SizedBox(height: 10),
                _textArea(
                  controller: _patchController,
                  hint: l10n.dshImportPatchHint,
                  isDark: isDark,
                  lines: 5,
                ),
                const SizedBox(height: 10),
                _actionRow(
                  theme: theme,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pasteInto(_packageJsonController),
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: Text(l10n.dshImportPastePackageJson),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _inspect,
                      icon: const Icon(Icons.search, size: 18),
                      label: Text(l10n.dshImportStartInspect),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_inspectResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _inspectReportText(l10n, _inspectResult!),
                      style: const TextStyle(
                          fontFamily: 'Courier', fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ToolListScreen()),
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(l10n.dshImportGoToolCenter),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _introCard(ThemeProvider theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: theme.accentColor, size: 26),
                const SizedBox(width: 10),
                Text(
                  l10n.dshImportIntroTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.dshImportIntroBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required ThemeProvider theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      color: isDark ? Colors.black54 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _textArea({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int lines = 6,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _actionRow({
    required ThemeProvider theme,
    required List<Widget> children,
  }) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }

  Widget _outcomeView(DshImportOutcome outcome, bool isDark) {
    if (outcome.isEmpty && outcome.notes.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final summary = l10n.dshImportSummaryImportedOk('${outcome.imported.length}') +
        (outcome.skipped.isNotEmpty
            ? l10n.dshImportSummarySkipped('${outcome.skipped.length}')
            : '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: outcome.imported.isEmpty
            ? Colors.orange.withOpacity(0.10)
            : Colors.green.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (outcome.imported.isEmpty ? Colors.orange : Colors.green)
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (outcome.imported.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l10n.dshImportImportedLine(outcome.imported.join(l10n.dshImportListSeparator)),
                style: const TextStyle(fontSize: 12.5)),
          ],
          if (outcome.skipped.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...outcome.skipped.map((s) => Text(
                  l10n.dshImportSkippedLine(
                      _skipSubjectLabel(l10n, s), _skipReasonLabel(l10n, s)),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                )),
          ],
          ...outcome.notes.map((n) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.dshImportNoteLine(_noteLabel(l10n, n)),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    )),
              )),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 码 → 文案（核心层只给码，翻译集中在这里）
  // ------------------------------------------------------------------

  String _skipSubjectLabel(AppLocalizations l10n, DshSkip skip) {
    final name = skip.name;
    if (name != null && name.isNotEmpty) return name;
    switch (skip.subject) {
      case DshSkipSubject.config:
        return l10n.dshSkipSubjectConfig;
      case DshSkipSubject.configParseFailed:
        return l10n.dshSkipSubjectConfigParseFailed;
      case DshSkipSubject.unnamedEntry:
        return l10n.dshSkipSubjectUnnamedEntry;
      default:
        return '';
    }
  }

  String _skipReasonLabel(AppLocalizations l10n, DshSkip skip) {
    switch (skip.code) {
      case DshSkipCode.duplicateSkill:
        return l10n.dshSkipDuplicateSkill;
      case DshSkipCode.duplicateMcp:
        return l10n.dshSkipDuplicateMcp;
      case DshSkipCode.invalidJson:
        return l10n.dshSkipInvalidJson;
      case DshSkipCode.commandLineMcp:
        return l10n.dshSkipCommandLineMcp;
      case DshSkipCode.noUrlField:
        return l10n.dshSkipNoUrlField;
      case DshSkipCode.missingNameUrl:
        return l10n.dshSkipMissingNameUrl;
      case DshSkipCode.unrecognizedJson:
        return l10n.dshSkipUnrecognizedJson;
      case DshSkipCode.invalidScheme:
        return l10n.dshSkipInvalidScheme;
      case DshSkipCode.upstream:
        // 上游原文（pocket_harness 产出，已是给用户看的说明）。
        return skip.detail ?? '';
      default:
        return skip.detail ?? skip.code;
    }
  }

  String _noteLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case DshNoteCode.skillDefaultsOff:
        return l10n.dshNoteSkillDefaultsOff;
      case DshNoteCode.mcpDefaultsOff:
        return l10n.dshNoteMcpDefaultsOff;
      case DshNoteCode.pasteMcpFirst:
        return l10n.dshNotePasteMcpFirst;
      default:
        return code;
    }
  }

  String _verdictLabel(AppLocalizations l10n, String verdict) {
    switch (verdict) {
      case DshInspectVerdict.directSkill:
        return l10n.dshInspectVerdictDirectSkill;
      case DshInspectVerdict.mcpServer:
        return l10n.dshInspectVerdictMcpServer;
      case DshInspectVerdict.configOnly:
        return l10n.dshInspectVerdictConfigOnly;
      case DshInspectVerdict.platformGated:
        return l10n.dshInspectVerdictPlatformGated;
      case DshInspectVerdict.needsDartTool:
        return l10n.dshInspectVerdictNeedsDart;
      default:
        return verdict;
    }
  }

  /// 把结构化体检结果渲染成等宽文本（原核心层的 StringBuffer 搬到这里）。
  String _inspectReportText(AppLocalizations l10n, DshInspectResult r) {
    if (r.isError) {
      final detail = r.errorDetail ?? '';
      switch (r.errorCode) {
        case DshInspectError.packageJsonFormat:
          return l10n.dshInspectErrPackageFormat(detail);
        case DshInspectError.packageJsonNotJson:
          return l10n.dshInspectErrPackageNotJson(detail);
        case DshInspectError.patchYamlFormat:
          return l10n.dshInspectErrPatchFormat(detail);
        default:
          return detail;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln(l10n.dshInspectPackageLine(r.packageName));
    final patchPath = r.bundlePatchPath;
    if (patchPath != null) {
      buffer.writeln(l10n.dshInspectBundleLine(patchPath));
    }
    if (r.profileBundles.isNotEmpty) {
      buffer.writeln(l10n.dshInspectProfileBundlesLine(
          r.profileBundles.join(l10n.dshImportListSeparator)));
    }

    if (!r.hasPatch) {
      buffer.writeln('');
      buffer.writeln(l10n.dshInspectNoPatchHint);
      return buffer.toString();
    }

    buffer.writeln('');
    buffer.writeln(l10n.dshInspectRowCountLine('${r.totalRows}'));
    buffer.writeln('');

    for (final group in r.groups) {
      buffer.writeln(l10n.dshInspectGroupLine(
          _verdictLabel(l10n, group.verdict), '${group.total}'));
      for (final row in group.rows) {
        buffer.writeln('  · ${row.id}  (${row.name})');
      }
      if (group.omitted > 0) {
        buffer.writeln(l10n.dshInspectMoreRowsLine('${group.omitted}'));
      }
      buffer.writeln('');
    }

    buffer.writeln(l10n.dshInspectConclusionLine(
        '${r.skillRows}', '${r.mcpRows}', '${r.heavyRows}'));

    return buffer.toString();
  }
}
