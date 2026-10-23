/// DeepSeek Harness（dsh）插件生态兼容层。
///
/// dsh（github.com/deepseek-ai/deepseek-harness）的插件是 TypeScript/Cordis
/// 服务，无法在 Dart 进程内直接执行；但其生态中**可静态提取的资产**可以
/// 低成本移植到 pocket_harness。本文件只做纯文本/纯数据转换，零 IO、零
/// 第三方依赖，宿主自行决定文件从哪读（npm tarball / 已下载目录 / 剪贴板）。
///
/// 三条移植通道（按适配成本排序）：
/// 1. **技能直译**（[DshSkillImporter]）：dsh skill = `<name>/SKILL.md` 或
///    `<name>.md`，frontmatter 键 name/description/disable-model-invocation/
///    user-invocable。纯 markdown，无代码，可 100% 自动转换（宿主把产出的
///    [DshSkill] 包成 SkillSpec 注册进 ToolRegistry）。
/// 2. **patch 资产盘点**（[DshBundleReader] / [DshCompatReport]）：dsh 插件
///    包 = npm 包 + package.json 的 `dsh.bundle` 字段指向 `cordis.patch.yml`
///   （insert 行）。解析后产出兼容报告：技能行直接导入；工具行标记"需
///    Dart 重实现"；`!!js` 门控行标记平台相关。工具的 execute 是 TS 代码，
///    无法自动移植——这是诚实边界，不做假兼容。
/// 3. **MCP 直连**：dsh 生态里的 MCP 服务器在移动端走 HTTP 传输即可由
///    McpConnectionManager 直接加载，命名互转见 [DshNames]。
library;

import 'dart:convert';

/// dsh 解析失败（格式超出本层支持的子集或内容非法）。
class DshFormatException implements Exception {
  final String message;
  DshFormatException(this.message);
  @override
  String toString() => 'DshFormatException: $message';
}

// ---------------------------------------------------------------------------
// 通道 1：技能直译
// ---------------------------------------------------------------------------

/// 一个从 dsh skill 文件解析出的技能定义。
class DshSkill {
  final String name;
  final String description;
  final String body;

  /// dsh 语义：disable-model-invocation 缺省为 false（模型可调用）。
  final bool modelInvocable;

  /// dsh 语义：user-invocable 缺省为 true（用户 /name 直调）。
  final bool userInvocable;

  /// 无法归类的 frontmatter 键（dsh 视为 opaque metadata，本层透传不解读）。
  final Map<String, String> extraMetadata;

  const DshSkill({
    required this.name,
    required this.description,
    required this.body,
    required this.modelInvocable,
    required this.userInvocable,
    required this.extraMetadata,
  });
}

/// dsh skill 文件解析器（frontmatter + 正文）。
///
/// dsh 本地提供方接受目录包（`<name>/SKILL.md`）与扁平文件（`<name>.md`），
/// 两者磁盘形态对本层无差别——调用方负责把文件名/目录名作为 [fileNameHint]
/// 传入，用于 frontmatter 缺 name 时回退。
abstract final class DshSkillFile {
  /// dsh 对 skill 名的硬约束。
  static final RegExp kebabCase = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  /// 解析一个 SKILL.md / `<name>.md` 的文本内容。
  ///
  /// [fileNameHint] 为文件名或目录名（不含路径），仅作 name 缺省回退；
  /// markdown 扩展名会被剥掉（dsh 扁平文件 `<name>.md` 的技能名取词干）。
  /// frontmatter 缺失时整个文本视为正文（description 置空）——dsh 要求
  /// description 存在，但本层容忍并交由宿主决定是否拒绝。
  static DshSkill parse(String text, {String? fileNameHint}) {
    final hint = fileNameHint
        ?.replaceFirst(RegExp(r'\.(md|markdown)$', caseSensitive: false), '');
    final normalized = text.replaceAll('\r\n', '\n');
    String frontmatter = '';
    String body = normalized;
    if (normalized.startsWith('---\n')) {
      final end = normalized.indexOf('\n---', 4);
      if (end != -1) {
        frontmatter = normalized.substring(4, end).trim();
        var rest = normalized.substring(end + 4);
        if (rest.startsWith('\n')) rest = rest.substring(1);
        body = rest;
      }
    }

    final meta = <String, String>{};
    for (final rawLine in frontmatter.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final colon = line.indexOf(':');
      if (colon <= 0) {
        throw DshFormatException('skill frontmatter 行非法: "$rawLine"');
      }
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      meta[key] = _unquote(value);
    }

    final name = (meta.remove('name') ?? hint ?? '').trim();
    final description = meta.remove('description') ?? '';
    final disableModel = meta.remove('disable-model-invocation');
    final userInvocableKey = meta.remove('user-invocable');

    return DshSkill(
      name: name,
      description: description,
      body: body.trim(),
      modelInvocable: disableModel?.toLowerCase() != 'true',
      userInvocable: userInvocableKey?.toLowerCase() != 'false',
      extraMetadata: meta,
    );
  }

  /// 把宽松名归一成 dsh kebab-case（大写→小写、空白/下划线→'-'、去非法字符、
  /// 折叠连续 '-'、去首尾 '-'）。归一后仍不合法（如全中文名）返回 null——
  /// 调用方应拒绝或自行提供合法名，本层不静默造名。
  static String? normalizeName(String raw) {
    final lowered = raw.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lowered.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[a-z0-9]').hasMatch(c)) {
        buffer.write(c);
      } else if (c == ' ' || c == '_' || c == '-') {
        buffer.write('-');
      }
      // 其余字符（中文、符号）丢弃
    }
    final folded = buffer.toString().replaceAll(RegExp('-+'), '-');
    final trimmed = folded.replaceAll(RegExp(r'^-+|-+$'), '');
    return kebabCase.hasMatch(trimmed) ? trimmed : null;
  }

  static String _unquote(String v) {
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }
}

/// 批量导入结果：成功 + 被拒清单（含原因），宿主据此落库或提示用户。
class DshSkillImport {
  final List<DshSkill> accepted;
  final Map<String, String> rejected; // 原始名/文件名 -> 拒绝原因
  const DshSkillImport({required this.accepted, required this.rejected});
}

/// 把一批 dsh skill 文件转为可注册的技能数据。
abstract final class DshSkillImporter {
  /// [files]：key = 文件名或目录名（提示名），value = 文件全文。
  ///
  /// 无 frontmatter name 时用 key 回退；回退名与显式名都做 kebab-case
  /// 归一（[DshSkillFile.normalizeName]），归一失败的进入 rejected——
  /// 与 dsh"不合法名即拒绝"一致，本层不静默改写。
  static DshSkillImport import(Map<String, String> files) {
    final accepted = <DshSkill>[];
    final rejected = <String, String>{};
    final seen = <String>{};
    files.forEach((hint, text) {
      try {
        final skill = DshSkillFile.parse(text, fileNameHint: hint);
        final rawName = skill.name.isNotEmpty ? skill.name : hint;
        final name = DshSkillFile.kebabCase.hasMatch(rawName)
            ? rawName
            : DshSkillFile.normalizeName(rawName);
        if (name == null) {
          rejected[hint] = '名称 "$rawName" 无法归一为 kebab-case';
          return;
        }
        if (!seen.add(name)) {
          rejected[hint] = '重名: $name（dsh 同名单层内后者胜出，'
              '本层选择拒绝以避免静默覆盖）';
          return;
        }
        accepted.add(DshSkill(
          name: name,
          description: skill.description,
          body: skill.body,
          modelInvocable: skill.modelInvocable,
          userInvocable: skill.userInvocable,
          extraMetadata: skill.extraMetadata,
        ));
      } on DshFormatException catch (e) {
        rejected[hint] = e.message;
      }
    });
    return DshSkillImport(accepted: accepted, rejected: rejected);
  }
}

// ---------------------------------------------------------------------------
// 通道 2：patch 资产盘点
// ---------------------------------------------------------------------------

/// cordis.patch.yml 中一行插件声明的解析结果。
class DshPatchRow {
  final String id;

  /// npm 包名（如 '@deepseek-ai/dsh-session'），插件身份所在。
  final String name;

  final Map<String, dynamic> config;

  /// 三种形态：null（未写，启用）、bool、[DshJsExpr]（`!!js` 运行时表达式，
  /// 通常是平台门控——本层不求值，标记为平台相关）。
  final Object? disabled;

  const DshPatchRow({
    required this.id,
    required this.name,
    required this.config,
    required this.disabled,
  });

  /// `!!js` 门控行：其启用与否取决于运行时表达式，静态盘点只能标记。
  bool get platformGated => disabled is DshJsExpr;
}

/// `!!js` 表达式占位（不求值——Dart 端没有 JS 运行时，语义交宿主）。
class DshJsExpr {
  final String expression;
  const DshJsExpr(this.expression);
  @override
  String toString() => expression;
  @override
  bool operator ==(Object other) =>
      other is DshJsExpr && other.expression == expression;
  @override
  int get hashCode => expression.hashCode;
}

/// 一份 cordis.patch.yml 的解析结果。
class DshPatch {
  final List<DshPatchRow> rows;
  const DshPatch(this.rows);

  /// 从 JSON 解析（宿主若已有 YAML→JSON 转换管道，直接喂 JSON 更稳）。
  /// 接受 patch 文档形态：`[{insert: [{id, name, config, disabled}, ...]}]`
  /// 或直接 `[{id, name, ...}, ...]`。
  static DshPatch fromJson(Object? json) {
    if (json is! List) {
      throw DshFormatException('patch JSON 应为数组: ${json.runtimeType}');
    }
    final rows = <DshPatchRow>[];
    for (final item in json) {
      if (item is Map && item['insert'] is List) {
        rows.addAll(_rowsFrom((item['insert'] as List).cast<Object?>()));
      } else if (item is Map) {
        rows.addAll(_rowsFrom([item]));
      } else {
        throw DshFormatException('patch 行应为对象: ${item.runtimeType}');
      }
    }
    return DshPatch(rows);
  }

  /// 受限 YAML 解析：只支持 dsh cordis.patch.yml 实际使用的子集——
  /// 顶层 `- insert:` 列表、每行 `- id: ...` 起始的对象、任意深度嵌套映射、
  /// 单行流式序列 `['a', 1]`、`|` 块标量（系统提示词片段的承载形态）、
  /// 标量（bool/int/double/引号字符串）、整行与引号外行内注释、`!!js`
  /// 表达式按原样捕获。
  ///
  /// 超出子集（锚点、折叠标量 `>`、流式映射、跨行表达式）抛
  /// [DshFormatException]——宁可失败，不静默解析错。
  static DshPatch parseYaml(String text) {
    final root = _LimitedYamlParser(text).parseDocument();
    return fromJson(root);
  }

  static List<DshPatchRow> _rowsFrom(List<Object?> items) {
    final rows = <DshPatchRow>[];
    for (final item in items) {
      if (item is! Map) {
        throw DshFormatException('insert 行应为对象: ${item.runtimeType}');
      }
      final id = item['id'];
      final name = item['name'];
      if (id is! String || name is! String) {
        throw DshFormatException('insert 行缺少字符串 id/name: $item');
      }
      final config = item['config'];
      rows.add(DshPatchRow(
        id: id,
        name: name,
        config: config is Map ? Map<String, dynamic>.from(config) : {},
        disabled: item['disabled'],
      ));
    }
    return rows;
  }
}

// ---------------------------------------------------------------------------
// 通道 3：MCP 命名互转
// ---------------------------------------------------------------------------

/// dsh 与 pocket_harness 的 MCP 工具命名互转。
///
/// dsh 公开 MCP 工具为 `mcp__<server>__<tool>`（双下划线分隔）；我们为
/// `mcp_<server>_<tool>`（与 McpConnectionManager.namespace 同规则）。
/// 两者语义同构，仅分隔符与清洗策略不同。
abstract final class DshNames {
  /// `mcp__srv__tool` -> 我们的命名空间名（清洗 + 64 截断，
  /// 与 McpConnectionManager.namespace 完全一致）。
  static String? dshMcpToolToOurs(String dshName) {
    final m = RegExp(r'^mcp__(.+?)__([a-zA-Z0-9_.\-]+)$').firstMatch(dshName);
    if (m == null) return null;
    return oursMcpTool(m.group(1)!, m.group(2)!);
  }

  /// 按我们的规则生成（供测试锚定与统一入口）。
  static String oursMcpTool(String server, String tool) {
    final raw = 'mcp_${server}_$tool'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return raw.length > 64 ? raw.substring(0, 64) : raw;
  }

  /// 尝试把我们的 mcp_ 前缀名还原成 dsh 名（尽力而为：我们的清洗会把
  /// 原始 `_` 折叠成同样形态，无法保证往返，失败返回 null）。
  static String? oursMcpToolToDsh(String oursName) {
    final m = RegExp(r'^mcp_([a-zA-Z0-9]+)_([a-zA-Z0-9_]+)$')
        .firstMatch(oursName);
    if (m == null) return null;
    return 'mcp__${m.group(1)}__${m.group(2)}';
  }
}

// ---------------------------------------------------------------------------
// 兼容报告
// ---------------------------------------------------------------------------

/// dsh 官方内置工具 -> pocket_harness/宿主的对应关系。
enum DshToolCoverage {
  /// 本包或宿主已有语义等价物。
  equivalent,

  /// 概念对应但能力面不同。
  partial,

  /// 无对应，适配该插件时需在 Dart 侧重实现或放弃。
  absent,
}

/// 单个工具的覆盖判定。
class DshToolEntry {
  final String dshTool;
  final DshToolCoverage coverage;
  final String note;
  const DshToolEntry(this.dshTool, this.coverage, this.note);
}

/// dsh 官方内置工具的覆盖对照表（依据 2026-09 主干 docs/tool-catalog
/// 与我们 M0-M5 实现盘点；`*` 结尾为族通配）。
abstract final class DshToolMap {
  static const List<DshToolEntry> entries = [
    DshToolEntry('skill', DshToolCoverage.equivalent,
        '我们的技能经 SkillSpec 注入 prompt（装配期），dsh 为按需加载工具——机制不同，能力等价'),
    DshToolEntry('ask_user_question', DshToolCoverage.partial,
        '宿主 GOD 控制台可承接交互提问，harness 包内无内置'),
    DshToolEntry('session_search', DshToolCoverage.equivalent,
        '已实现为包内置工具 buildSessionSearchTool（关键词检索会话历史）'),
    DshToolEntry('session_event_read', DshToolCoverage.equivalent,
        '已实现为包内置工具 buildSessionReadTool（按位置翻页读原文）'),
    DshToolEntry('session_event_search', DshToolCoverage.partial,
        '检索已有，trace/审计视图未实现'),
    DshToolEntry('session_event_trace', DshToolCoverage.partial, '同上'),
    DshToolEntry('session_trace', DshToolCoverage.partial, '同上'),
    DshToolEntry('read', DshToolCoverage.absent, '文件族：宿主按需自造'),
    DshToolEntry('write', DshToolCoverage.absent, '文件族：宿主按需自造'),
    DshToolEntry('edit', DshToolCoverage.absent, '文件族：宿主按需自造'),
    DshToolEntry('str_replace_editor', DshToolCoverage.absent, '文件族'),
    DshToolEntry('glob', DshToolCoverage.absent, '文件族'),
    DshToolEntry('grep', DshToolCoverage.absent, '文件族'),
    DshToolEntry('read_image', DshToolCoverage.absent, '文件族'),
    DshToolEntry('bash', DshToolCoverage.absent, '移动端无 shell；PC 宿主可自造'),
    DshToolEntry('pwsh', DshToolCoverage.absent, 'Windows shell 孪生'),
    DshToolEntry('terminal_*', DshToolCoverage.absent, '持久终端族'),
    DshToolEntry('lsp', DshToolCoverage.absent, 'LSP 桥'),
    DshToolEntry('run_code', DshToolCoverage.absent,
        'PTC（程序化工具调用）传输，dsh 高级特性'),
    DshToolEntry('subagent', DshToolCoverage.absent, '子代理族'),
    DshToolEntry('list_subagent_models', DshToolCoverage.absent, '子代理族'),
    DshToolEntry('interrupt_agent', DshToolCoverage.absent, '子代理族'),
    DshToolEntry('send_message', DshToolCoverage.absent, '父子代理双向消息'),
    DshToolEntry('list_agents', DshToolCoverage.absent, '多代理族'),
    DshToolEntry('wait_agent', DshToolCoverage.absent, '多代理族'),
    DshToolEntry('spawn_teammate', DshToolCoverage.absent, 'Agent Teams'),
    DshToolEntry('team_task_*', DshToolCoverage.absent, 'Agent Teams'),
    DshToolEntry('workflow', DshToolCoverage.absent, '工作流编排'),
    DshToolEntry('ralph', DshToolCoverage.absent, '实验性工具'),
    DshToolEntry('todo_write', DshToolCoverage.absent, '宿主可自造'),
    DshToolEntry('create_goal', DshToolCoverage.absent, '目标族'),
    DshToolEntry('get_goal', DshToolCoverage.absent, '目标族'),
    DshToolEntry('update_goal', DshToolCoverage.absent, '目标族'),
    DshToolEntry('schedule_*', DshToolCoverage.partial, '宿主定时任务可承接'),
    DshToolEntry('job_*', DshToolCoverage.absent, '后台任务族'),
    DshToolEntry('exit_plan_mode', DshToolCoverage.absent, '计划模式'),
    DshToolEntry('cordis_*', DshToolCoverage.absent,
        '动态包/运行时自省族（我们的对应概念是 DB 自造工具，已实现）'),
    DshToolEntry('web_fetch', DshToolCoverage.equivalent,
        '已实现为包内置工具 buildWebFetchTool（SSRF 防护 + 重定向逐跳校验 + HTML 转文本）'),
    DshToolEntry('web_search', DshToolCoverage.absent, '需搜索提供方'),
  ];

  /// 按工具名查找（精确匹配优先，其次族前缀匹配，未收录按 absent 处理）。
  static DshToolEntry classify(String dshToolName) {
    for (final e in entries) {
      if (e.dshTool == dshToolName) return e;
    }
    for (final e in entries) {
      if (e.dshTool.endsWith('*') &&
          dshToolName.startsWith(
              e.dshTool.substring(0, e.dshTool.length - 1))) {
        return e;
      }
    }
    return DshToolEntry(dshToolName, DshToolCoverage.absent,
        '未收录的 dsh 工具；若形如 mcp__srv__tool，请改走 MCP 直连通道');
  }
}

/// 一份 dsh 插件包的兼容性盘点结果。
class DshCompatReport {
  final String packageName;
  final List<DshPatchRow> rows;

  /// 每行的处置建议：direct-skill / needs-dart-tool / config-only /
  /// platform-gated / mcp-server。
  final Map<String, String> rowVerdicts;

  const DshCompatReport({
    required this.packageName,
    required this.rows,
    required this.rowVerdicts,
  });

  /// 从已解析的 patch 生成盘点（[packageName] 仅用于展示）。
  static DshCompatReport analyze(String packageName, DshPatch patch) {
    final verdicts = <String, String>{};
    for (final row in patch.rows) {
      if (row.platformGated) {
        verdicts[row.id] = 'platform-gated';
      } else if (RegExp(r'mcp', caseSensitive: false).hasMatch(row.name)) {
        verdicts[row.id] = 'mcp-server';
      } else if (row.config.isEmpty) {
        verdicts[row.id] = 'config-only';
      } else if (row.config.keys.any((k) => k.toLowerCase().contains('skill'))) {
        verdicts[row.id] = 'direct-skill';
      } else {
        verdicts[row.id] = 'needs-dart-tool';
      }
    }
    return DshCompatReport(
      packageName: packageName,
      rows: patch.rows,
      rowVerdicts: verdicts,
    );
  }

  Map<String, List<DshPatchRow>> get byVerdict {
    final map = <String, List<DshPatchRow>>{};
    for (final row in rows) {
      map
          .putIfAbsent(rowVerdicts[row.id] ?? 'needs-dart-tool', () => [])
          .add(row);
    }
    return map;
  }
}

/// dsh 插件包整体入口：package.json 的 `dsh` 字段。
class DshBundleReader {
  final String packageName;

  /// `dsh.bundle` 指向的 patch 文件相对路径（组合包形态），或 null。
  final String? bundlePatchPath;

  /// `dsh.profile.bundles` 列出的组合包（profile 形态），或空。
  final List<String> profileBundles;

  const DshBundleReader({
    required this.packageName,
    required this.bundlePatchPath,
    required this.profileBundles,
  });

  /// 解析 package.json 全文的 `dsh` 字段。
  static DshBundleReader fromPackageJson(String packageJsonText) {
    late final Map<String, dynamic> root;
    try {
      root = jsonDecode(packageJsonText) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw DshFormatException('package.json 非法: ${e.message}');
    }
    final dsh = root['dsh'];
    String? bundlePath;
    final bundles = <String>[];
    if (dsh is Map) {
      final b = dsh['bundle'];
      if (b is String) bundlePath = b;
      final p = dsh['profile'];
      if (p is Map && p['bundles'] is List) {
        bundles.addAll(
            (p['bundles'] as List).whereType<String>());
      }
    }
    return DshBundleReader(
      packageName: (root['name'] as String?) ?? '<unnamed>',
      bundlePatchPath: bundlePath,
      profileBundles: bundles,
    );
  }
}

// ---------------------------------------------------------------------------
// 受限 YAML 解析器（内部）
// ---------------------------------------------------------------------------

class _Line {
  final int indent;

  /// 去缩进、去行内注释后的内容（结构性解析用；空行/纯注释行为 ''）。
  final String content;

  /// 原始行文本（块标量内容用——块内 `#` 是内容不是注释，空白行有意义）。
  final String raw;
  const _Line(this.indent, this.content, this.raw);
}

class _LimitedYamlParser {
  final List<_Line> lines;
  int pos = 0;

  _LimitedYamlParser(String text)
      : lines = _preprocess(text);

  static List<_Line> _preprocess(String text) {
    final out = <_Line>[];
    for (final raw in text.replaceAll('\r\n', '\n').split('\n')) {
      var indent = 0;
      while (indent < raw.length && raw[indent] == ' ') {
        indent++;
      }
      if (indent < raw.length && raw[indent] == '\t') {
        throw DshFormatException('YAML 不允许 tab 缩进');
      }
      var content = raw.substring(indent);
      if (content.trim().isEmpty || content.startsWith('#')) {
        // 结构性空行/注释行：content 置空供 _skipBlank 跳过，raw 留给块标量
        out.add(_Line(indent, '', raw));
        continue;
      }
      content = stripInlineComment(content);
      out.add(_Line(indent, content, raw));
    }
    return out;
  }

  /// 解析整个文档，期望顶层是列表（`- insert:` …）。
  Object? parseDocument() {
    _skipBlank();
    if (pos >= lines.length) return [];
    final first = lines[pos];
    if (!first.content.startsWith('- ') && first.content != '-') {
      throw DshFormatException('patch 顶层应为列表，遇到: "${first.content}"');
    }
    return _parseList(first.indent);
  }

  void _skipBlank() {
    while (pos < lines.length && lines[pos].content.isEmpty) {
      pos++;
    }
  }

  /// 解析一个列表，所有 item 缩进应为 [indent]。
  List<Object?> _parseList(int indent) {
    final out = <Object?>[];
    while (true) {
      _skipBlank();
      if (pos >= lines.length) break;
      final line = lines[pos];
      if (line.indent < indent) break;
      if (line.indent > indent) {
        throw DshFormatException('意外的深层缩进: "${line.content}"');
      }
      if (!line.content.startsWith('- ') && line.content != '-') break;
      final rest =
          line.content == '-' ? '' : line.content.substring(2).trim();
      pos++; // 消费 dash 行
      if (rest.isEmpty) {
        _skipBlank();
        if (pos < lines.length && lines[pos].indent > indent) {
          out.add(_parseMap(lines[pos].indent));
        } else {
          out.add(null);
        }
      } else if (_keyColonIndex(rest) != -1) {
        // "- key: value" —— 对象 item 的第一键。dash 行本身就是键行：回退
        // 并改写成键列形态，再按"键行未消费"契约统一处理。
        lines[pos - 1] = _Line(line.indent + 2, rest, rest);
        pos--;
        final map = <String, Object?>{};
        _consumeMapEntry(rest, line.indent + 2, map);
        while (true) {
          _skipBlank();
          if (pos >= lines.length) break;
          final l = lines[pos];
          if (l.indent != line.indent + 2 || l.content.startsWith('- ')) break;
          _consumeMapEntry(l.content, l.indent, map);
        }
        out.add(map);
      } else {
        out.add(_parseScalar(rest));
      }
    }
    return out;
  }

  /// 解析一个映射，键行缩进为 [indent]。消费到缩进小于 [indent] 或遇到
  /// 列表项为止。
  Map<String, Object?> _parseMap(int indent) {
    final map = <String, Object?>{};
    while (true) {
      _skipBlank();
      if (pos >= lines.length) break;
      final line = lines[pos];
      if (line.indent < indent) break;
      if (line.indent > indent) {
        throw DshFormatException('意外的深层缩进: "${line.content}"');
      }
      if (line.content.startsWith('- ')) break;
      _consumeMapEntry(line.content, indent, map);
    }
    return map;
  }

  /// 处理 `key: value` / `key:`。约定：进入本函数前**键行尚未消费**，
  /// 返回后 pos 恒指向该条目（含嵌套块）之后的第一行。
  void _consumeMapEntry(String content, int indent, Map<String, Object?> map) {
    final colon = _keyColonIndex(content);
    if (colon == -1) {
      throw DshFormatException('期望 key: value，遇到: "$content"');
    }
    final key = _unquoteScalar(content.substring(0, colon).trim());
    final valueText = stripInlineComment(content.substring(colon + 1).trim());
    pos++; // 消费键行
    if (RegExp(r'^\|[+-]?$').hasMatch(valueText)) {
      // 块标量 `|` / `|-` / `|+`：dsh patch 用它承载系统提示词片段。
      map[key] = _readBlockScalar(indent, strip: valueText.endsWith('-'));
      return;
    }
    if (valueText.isNotEmpty) {
      map[key] = _parseScalar(valueText);
      return;
    }
    _skipBlank();
    if (pos >= lines.length) {
      map[key] = null;
      return;
    }
    final next = lines[pos];
    if (next.indent <= indent) {
      map[key] = null;
      return;
    }
    if (next.content.startsWith('- ') || next.content == '-') {
      map[key] = _parseList(next.indent);
    } else {
      map[key] = _parseMap(next.indent);
    }
  }

  /// 块标量内容读取：pos 指向 `key: |` 的下一行，读到缩进 <= 键缩进的
  /// 结构行为止。`#` 与空白行按内容保留（块内不是注释/结构）。
  /// clip 语义（默认与 `|+` 同近似）：单行尾随换行；`|-` 无尾随换行。
  String _readBlockScalar(int keyIndent, {required bool strip}) {
    int? blockIndent;
    final collected = <String>[];
    while (pos < lines.length) {
      final line = lines[pos];
      if (line.raw.trim().isEmpty) {
        collected.add('');
        pos++;
        continue;
      }
      if (line.indent <= keyIndent) break;
      blockIndent ??= line.indent;
      if (line.indent < blockIndent) {
        throw DshFormatException('块标量缩进不一致: "${line.raw}"');
      }
      collected.add(line.raw.substring(blockIndent));
      pos++;
    }
    while (collected.isNotEmpty && collected.last.isEmpty) {
      collected.removeLast();
    }
    final text = collected.join('\n');
    return text.isEmpty ? '' : (strip ? text : '$text\n');
  }

  Object? _parseScalar(String text) {
    if (text.startsWith('!!js')) {
      if (text == '!!js') throw DshFormatException('不支持跨行的 !!js 表达式');
      return DshJsExpr(text.substring(4).trim());
    }
    if (text.startsWith('[') && text.endsWith(']')) {
      return _parseFlowSeq(text);
    }
    if (text.startsWith('{')) {
      throw DshFormatException('不支持流式映射语法: "$text"');
    }
    if (text.startsWith('&') || text.startsWith('*')) {
      throw DshFormatException('不支持 YAML 锚点/引用: "$text"');
    }
    if (text.startsWith('|')) {
      throw DshFormatException('不支持的块标量形态（仅支持键后单行的 | / |- / |+）: "$text"');
    }
    if (text.startsWith('>')) {
      throw DshFormatException('不支持折叠标量语法: "$text"');
    }
    if (text == 'true') return true;
    if (text == 'false') return false;
    if (text == 'null' || text == '~' || text.isEmpty) return null;
    final intVal = int.tryParse(text);
    if (intVal != null) return intVal;
    final doubleVal = double.tryParse(text);
    if (doubleVal != null) return doubleVal;
    return _unquoteScalar(text);
  }

  /// 单行流式序列：`['a', 1, true]`（元素为标量，不支持嵌套）。
  List<Object?> _parseFlowSeq(String text) {
    final inner = text.substring(1, text.length - 1).trim();
    if (inner.isEmpty) return [];
    final out = <Object?>[];
    var inSingle = false;
    var inDouble = false;
    var start = 0;
    for (var i = 0; i <= inner.length; i++) {
      final atEnd = i == inner.length;
      if (!atEnd) {
        final c = inner[i];
        if (c == "'" && !inDouble) inSingle = !inSingle;
        if (c == '"' && !inSingle) inDouble = !inDouble;
        if (c != ',' || inSingle || inDouble) continue;
      }
      final part = inner.substring(start, i).trim();
      if (part.isNotEmpty) out.add(_parseScalar(part));
      start = i + 1;
    }
    return out;
  }

  /// 冒号后必须是行尾或空格（YAML 语义），排除 http:// 形态；引号内冒号不算。
  static int _keyColonIndex(String content) {
    var inSingle = false;
    var inDouble = false;
    for (var i = 0; i < content.length; i++) {
      final c = content[i];
      if (c == "'" && !inDouble) inSingle = !inSingle;
      if (c == '"' && !inSingle) inDouble = !inDouble;
      if (c == ':' && !inSingle && !inDouble) {
        if (i + 1 >= content.length || content[i + 1] == ' ') return i;
      }
    }
    return -1;
  }

  /// 去引号外行内注释（` #` 起算）。
  static String stripInlineComment(String text) {
    var inSingle = false;
    var inDouble = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == "'" && !inDouble) inSingle = !inSingle;
      if (c == '"' && !inSingle) inDouble = !inDouble;
      if (c == '#' && !inSingle && !inDouble) {
        if (i == 0 || text[i - 1] == ' ') return text.substring(0, i).trim();
      }
    }
    return text.trim();
  }

  static String _unquoteScalar(String v) {
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }
}
