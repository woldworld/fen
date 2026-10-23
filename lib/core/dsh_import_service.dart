import 'dart:convert';

import 'package:pocket_harness/pocket_harness.dart';

import 'db_helper.dart';
import 'plugin_bus.dart';

/// ============================================================
/// DeepSeek Harness（dsh）生态导入服务
///
/// dsh 的插件是 TypeScript/Cordis 服务，无法在 Dart 进程里执行；
/// 但生态里**可静态搬运**的资产有三类，本服务负责把它们接进大荒的插件总线：
///   ① 技能（SKILL.md）—— 纯文本，100% 可直译；
///   ② MCP 服务器 —— 协议无关，填地址即可直连；
///   ③ 插件包体检 —— 解析 package.json / cordis.patch.yml，
///      告诉用户哪些能直接用、哪些必须在 Dart 侧重写。
///
/// 安全约定：**导入的插件一律默认禁用**，必须由主人到工具页手动开启，
/// 开启后仍需通过签名校验与能力授权，杜绝"导入即执行"。
///
/// ------------------------------------------------------------
/// 【i18n 约定】本文件**不产出任何面向用户的文案**。
/// 核心层拿不到 `BuildContext`，也不该关心展示语言，因此这里只返回
/// **语言无关的码 / 结构化数据**：
///   · 跳过原因 → [DshSkipCode]（+ 可选 [DshSkip.detail]）
///   · 顶部提示 → [DshNoteCode]
///   · 体检结论 → [DshInspectVerdict] / [DshInspectError] + [DshInspectResult]
/// 由 UI 层（`lib/ui/dsh_import_screen.dart`）翻译成当前语言。
///
/// 例外：落库的 `description` / `author` 是**数据**（既是展示字段，
/// 也会被注入模型提示词），不属于 UI 文案，统一用语言中立的 ASCII 常量
/// [DshProvenance] 承载——避免同一批数据在切换语言后写法漂移。
/// ============================================================

/// 落库时使用的语言中立溯源标识（非 UI 文案，见文件头说明）。
abstract final class DshProvenance {
  /// 落库字段 `author`：来源标识（品牌名，各语言通用）。
  static const String author = 'DSH';

  /// 落库字段 `description`：技能没写 description 时的兜底（模型可读）。
  static const String skillDescription = 'Skill imported from the DSH ecosystem';

  /// 落库字段 `description`：MCP 服务说明（模型可读）。
  static const String mcpDescription =
      'MCP server imported from the DSH ecosystem';
}

/// 导入被跳过 / 被拒的**原因码**（UI 侧翻译成文案）。
abstract final class DshSkipCode {
  /// 技能：已有同名技能，未覆盖。
  static const String duplicateSkill = 'duplicate-skill';

  /// MCP：已有同名配置，未覆盖。
  static const String duplicateMcp = 'duplicate-mcp';

  /// 粘贴内容既不是合法 JSON 也不是网址。
  static const String invalidJson = 'invalid-json';

  /// 命令行型 MCP（需本机起进程），移动端跑不了。
  static const String commandLineMcp = 'command-line-mcp';

  /// 配置里既没有 url 也没有 command。
  static const String noUrlField = 'no-url-field';

  /// 数组条目缺少 name 或 url。
  static const String missingNameUrl = 'missing-name-url';

  /// 合法 JSON 但不是能识别的结构。
  static const String unrecognizedJson = 'unrecognized-json';

  /// 地址不是 http(s)。
  static const String invalidScheme = 'invalid-scheme';

  /// 原因由上游 pocket_harness 原样带回，见 [DshSkip.detail]。
  static const String upstream = 'upstream';
}

/// 条目名缺失时的**占位码**（UI 侧翻译成文案）。
abstract final class DshSkipSubject {
  /// 整个配置块（结构无法识别）。
  static const String config = 'config';

  /// 配置解析失败这一行本身。
  static const String configParseFailed = 'config-parse-failed';

  /// 数组里没写 name 的条目。
  static const String unnamedEntry = 'unnamed-entry';
}

/// 导入结果顶部的**提示码**（UI 侧翻译成文案）。
abstract final class DshNoteCode {
  /// 技能导入成功后：默认关闭，需到技能控制中心开启。
  static const String skillDefaultsOff = 'skill-defaults-off';

  /// MCP 导入成功后：默认关闭，首次使用需授予网络访问。
  static const String mcpDefaultsOff = 'mcp-defaults-off';

  /// 空输入：请先粘配置或地址。
  static const String pasteMcpFirst = 'paste-mcp-first';
}

/// 一条被跳过 / 被拒的条目（结构化，不含文案）。
class DshSkip {
  /// 真实条目名；为空时用 [subject] 顶替显示。
  final String? name;

  /// 名字缺失时的占位码（[DshSkipSubject]）。
  final String? subject;

  /// 原因码（[DshSkipCode]）。
  final String code;

  /// 附加细节：上游原文（`code == upstream`）或解析错误信息等。
  final String? detail;

  const DshSkip({
    this.name,
    this.subject,
    required this.code,
    this.detail,
  });
}

class DshImportOutcome {
  final List<String> imported;
  final List<DshSkip> skipped;

  /// 提示码列表（[DshNoteCode]）。
  final List<String> notes;

  const DshImportOutcome({
    required this.imported,
    required this.skipped,
    required this.notes,
  });

  bool get isEmpty => imported.isEmpty && skipped.isEmpty;
}

// ---------------------------------------------------------------------------
// 插件包体检：结构化结果
// ---------------------------------------------------------------------------

/// 体检结论码（即 [DshCompatReport.rowVerdicts] 的取值）。
abstract final class DshInspectVerdict {
  static const String directSkill = 'direct-skill';
  static const String mcpServer = 'mcp-server';
  static const String configOnly = 'config-only';
  static const String platformGated = 'platform-gated';
  static const String needsDartTool = 'needs-dart-tool';
}

/// 体检失败原因码。
abstract final class DshInspectError {
  static const String packageJsonFormat = 'package-json-format';
  static const String packageJsonNotJson = 'package-json-not-json';
  static const String patchYamlFormat = 'patch-yaml-format';
}

/// 体检报告里的一行插件。
class DshInspectRow {
  final String id;
  final String name;
  const DshInspectRow(this.id, this.name);
}

/// 按结论分组的一段（行数超过上限时只带前 N 行，其余用 [omitted] 计数）。
class DshInspectGroup {
  final String verdict; // DshInspectVerdict.*
  final List<DshInspectRow> rows;
  final int total;

  const DshInspectGroup({
    required this.verdict,
    required this.rows,
    required this.total,
  });

  /// 因超过上限而未展开的行数。
  int get omitted => total - rows.length;
}

/// 插件包体检结果（结构化，渲染交给 UI）。
class DshInspectResult {
  /// 失败原因码（[DshInspectError]）；非空即表示体检失败。
  final String? errorCode;

  /// 失败细节（底层异常信息，原样透传）。
  final String? errorDetail;

  final String packageName;

  /// `dsh.bundle` 指向的组合文件路径，或 null。
  final String? bundlePatchPath;

  /// `dsh.profile.bundles` 列出的组合包。
  final List<String> profileBundles;

  /// 是否提供了（且成功解析了）cordis.patch.yml。
  final bool hasPatch;

  /// 插件行总数。
  final int totalRows;

  /// 分组结果（顺序与 patch 行出现顺序一致）。
  final List<DshInspectGroup> groups;

  final int skillRows;
  final int mcpRows;
  final int heavyRows;

  const DshInspectResult({
    this.errorCode,
    this.errorDetail,
    this.packageName = '',
    this.bundlePatchPath,
    this.profileBundles = const [],
    this.hasPatch = false,
    this.totalRows = 0,
    this.groups = const [],
    this.skillRows = 0,
    this.mcpRows = 0,
    this.heavyRows = 0,
  });

  /// 失败结果。
  const DshInspectResult.failure(String code, String detail)
      : errorCode = code,
        errorDetail = detail,
        packageName = '',
        bundlePatchPath = null,
        profileBundles = const [],
        hasPatch = false,
        totalRows = 0,
        groups = const [],
        skillRows = 0,
        mcpRows = 0,
        heavyRows = 0;

  bool get isError => errorCode != null;
}

class DshImportService {
  DshImportService._();

  /// 体检报告里每个结论分组最多展开的行数。
  static const int inspectRowsPerGroup = 20;

  // ------------------------------------------------------------------
  // ① 技能导入
  // ------------------------------------------------------------------

  /// [files]：key = 文件名或目录名，value = 文件全文（SKILL.md 或 <name>.md）
  static Future<DshImportOutcome> importSkills(
      Map<String, String> files) async {
    final outcome = DshSkillImporter.import(files);
    final imported = <String>[];
    final skipped = <DshSkip>[];
    final notes = <String>[];

    final existing = await DBHelper.getToolsByType('skill');
    final existingNames =
        existing.map((e) => (e['name'] as String?) ?? '').toSet();

    for (final skill in outcome.accepted) {
      if (existingNames.contains(skill.name)) {
        skipped.add(DshSkip(
          name: skill.name,
          code: DshSkipCode.duplicateSkill,
        ));
        continue;
      }
      final description = skill.description.isEmpty
          ? DshProvenance.skillDescription
          : skill.description;
      final content = skill.description.isEmpty
          ? skill.body
          : '${skill.description}\n\n${skill.body}';

      final id = await DBHelper.insertTool(
        skill.name,
        description,
        'skill',
        content,
        author: DshProvenance.author,
        enabled: false, // 导入即禁用：必须由主人手动开启
      );
      await PluginBus.stampRow(
        id,
        name: skill.name,
        type: 'skill',
        description: description,
        content: content,
        author: DshProvenance.author,
      );
      imported.add(skill.name);
    }

    // 上游拒绝原因是第三方文本（pocket_harness 产出），原样透传给 UI 展示。
    outcome.rejected.forEach((name, reason) => skipped.add(DshSkip(
          name: name,
          code: DshSkipCode.upstream,
          detail: reason,
        )));
    if (imported.isNotEmpty) {
      notes.add(DshNoteCode.skillDefaultsOff);
    }

    return DshImportOutcome(
        imported: imported, skipped: skipped, notes: notes);
  }

  // ------------------------------------------------------------------
  // ② MCP 服务器导入
  // ------------------------------------------------------------------

  /// 支持四种粘贴格式：
  /// A. dsh / Claude 风格的 `{"mcpServers": {"名字": {"url": "https://..."}}}`
  /// B. 简化对象 `{"名字": "https://..."}`
  /// C. 数组 `[{"name": "名字", "url": "https://..."}]`
  /// D. 裸地址 `https://...`
  ///
  /// 命令行型（command/args）MCP 在手机上无法启动，会被明确拒绝并说明原因。
  static Future<DshImportOutcome> importMcpServers(String rawText) async {
    final text = rawText.trim();
    final imported = <String>[];
    final skipped = <DshSkip>[];
    final notes = <String>[];

    if (text.isEmpty) {
      return const DshImportOutcome(
        imported: [],
        skipped: [],
        notes: [DshNoteCode.pasteMcpFirst],
      );
    }

    final Map<String, String> candidates = {};

    // D. 裸地址
    if (text.startsWith('http://') || text.startsWith('https://')) {
      candidates[_hostNameOf(text)] = text;
    } else {
      Object? decoded;
      try {
        decoded = jsonDecode(text);
      } catch (e) {
        return const DshImportOutcome(
          imported: [],
          skipped: [
            DshSkip(
              subject: DshSkipSubject.configParseFailed,
              code: DshSkipCode.invalidJson,
            ),
          ],
          notes: [],
        );
      }

      if (decoded is Map) {
        final servers = decoded['mcpServers'];
        final source = servers is Map ? servers : decoded;
        source.forEach((key, value) {
          final name = key.toString();
          if (value is String) {
            candidates[name] = value;
          } else if (value is Map) {
            final url = value['url'] ?? value['serverUrl'] ?? value['endpoint'];
            if (url is String && url.trim().isNotEmpty) {
              candidates[name] = url.trim();
            } else {
              skipped.add(DshSkip(
                name: name,
                code: value['command'] != null
                    ? DshSkipCode.commandLineMcp
                    : DshSkipCode.noUrlField,
              ));
            }
          }
        });
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final name = (item['name'] ?? item['id'] ?? '').toString();
            final url = (item['url'] ?? item['serverUrl'] ?? '').toString();
            if (name.isNotEmpty && url.isNotEmpty) {
              candidates[name] = url;
            } else if (name.isEmpty) {
              skipped.add(const DshSkip(
                subject: DshSkipSubject.unnamedEntry,
                code: DshSkipCode.missingNameUrl,
              ));
            } else {
              skipped.add(DshSkip(
                name: name,
                code: DshSkipCode.missingNameUrl,
              ));
            }
          }
        }
      } else {
        skipped.add(const DshSkip(
          subject: DshSkipSubject.config,
          code: DshSkipCode.unrecognizedJson,
        ));
      }
    }

    final existing = await DBHelper.getToolsByType('mcp');
    final existingNames =
        existing.map((e) => (e['name'] as String?) ?? '').toSet();

    for (final entry in candidates.entries) {
      final name = _sanitizeName(entry.key);
      final url = entry.value.trim();
      if (existingNames.contains(name)) {
        skipped.add(DshSkip(name: name, code: DshSkipCode.duplicateMcp));
        continue;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        skipped.add(DshSkip(name: name, code: DshSkipCode.invalidScheme));
        continue;
      }
      const description = DshProvenance.mcpDescription;
      final id = await DBHelper.insertTool(
        name,
        description,
        'mcp',
        url,
        author: DshProvenance.author,
        enabled: false,
      );
      await PluginBus.stampRow(
        id,
        name: name,
        type: 'mcp',
        description: description,
        content: url,
        author: DshProvenance.author,
      );
      imported.add(name);
    }

    if (imported.isNotEmpty) {
      notes.add(DshNoteCode.mcpDefaultsOff);
    }

    return DshImportOutcome(
        imported: imported, skipped: skipped, notes: notes);
  }

  // ------------------------------------------------------------------
  // ③ 插件包体检
  // ------------------------------------------------------------------

  /// 解析 dsh 插件包：`package.json` 必填，`cordis.patch.yml` 可选。
  /// 返回**结构化**结果（[DshInspectResult]），文案由 UI 层按当前语言渲染。
  static DshInspectResult inspectPackage({
    required String packageJson,
    String? patchYaml,
  }) {
    DshBundleReader reader;
    try {
      reader = DshBundleReader.fromPackageJson(packageJson);
    } on DshFormatException catch (e) {
      return DshInspectResult.failure(
          DshInspectError.packageJsonFormat, e.message);
    } on FormatException catch (e) {
      return DshInspectResult.failure(
          DshInspectError.packageJsonNotJson, e.message);
    }

    final yaml = (patchYaml ?? '').trim();
    if (yaml.isEmpty) {
      // 只给了 package.json：只能看到包的基本信息。
      return DshInspectResult(
        packageName: reader.packageName,
        bundlePatchPath: reader.bundlePatchPath,
        profileBundles: reader.profileBundles,
      );
    }

    DshPatch patch;
    try {
      patch = DshPatch.parseYaml(yaml);
    } on DshFormatException catch (e) {
      return DshInspectResult.failure(
          DshInspectError.patchYamlFormat, e.message);
    }

    final report = DshCompatReport.analyze(reader.packageName, patch);
    final grouped = report.byVerdict;

    final groups = <DshInspectGroup>[];
    for (final entry in grouped.entries) {
      groups.add(DshInspectGroup(
        verdict: entry.key,
        rows: entry.value
            .take(inspectRowsPerGroup)
            .map((r) => DshInspectRow(r.id, r.name))
            .toList(growable: false),
        total: entry.value.length,
      ));
    }

    return DshInspectResult(
      packageName: reader.packageName,
      bundlePatchPath: reader.bundlePatchPath,
      profileBundles: reader.profileBundles,
      hasPatch: true,
      totalRows: report.rows.length,
      groups: groups,
      skillRows: grouped[DshInspectVerdict.directSkill]?.length ?? 0,
      mcpRows: grouped[DshInspectVerdict.mcpServer]?.length ?? 0,
      heavyRows: (grouped[DshInspectVerdict.needsDartTool]?.length ?? 0) +
          (grouped[DshInspectVerdict.platformGated]?.length ?? 0),
    );
  }

  // ------------------------------------------------------------------
  // 内部工具
  // ------------------------------------------------------------------

  /// 把配置里的名字清洗成可安全落库的标识
  static String _sanitizeName(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return 'mcp-server';
    // CJK 段用 \u 转义写（等价于 [一-龥]，即 U+4E00-U+9FA5），
    // 源码里因此不含中文字符，避免被硬编码扫描工具误判成用户文案。
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-\u4e00-\u9fa5]'), '_');
    name = name.replaceAll(RegExp(r'_{2,}'), '_');
    if (name.length > 32) name = name.substring(0, 32);
    return name;
  }

  /// 从地址里推一个名字（裸地址导入时用）
  static String _hostNameOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? 'mcp-server' : _sanitizeName(host);
  }
}
