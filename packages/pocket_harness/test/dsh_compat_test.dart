import 'package:pocket_harness/pocket_harness.dart';
import 'package:test/test.dart';

void main() {
  group('DshSkillFile / DshSkillImporter', () {
    test('目录包 SKILL.md：frontmatter 全字段 + 正文', () {
      final s = DshSkillFile.parse(
        '''---
name: web-research
description: 多轮网页调研并产出带引用的摘要
user-invocable: false
# 注释行
custom-meta: opaque-value
---

# 步骤

1. 搜索
2. 交叉验证
''',
        fileNameHint: 'web-research',
      );
      expect(s.name, 'web-research');
      expect(s.description, '多轮网页调研并产出带引用的摘要');
      expect(s.modelInvocable, isTrue); // 未写 disable-model-invocation
      expect(s.userInvocable, isFalse); // 显式关闭
      expect(s.extraMetadata['custom-meta'], 'opaque-value');
      expect(s.body, contains('交叉验证'));
      expect(s.body, isNot(contains('---')));
    });

    test('扁平 md：缺 name 回退文件名，CRLF 归一', () {
      final s = DshSkillFile.parse(
          '---\r\nname: code-review\r\ndescription: 审代码\r\n---\r\n\r\n正文\r\n',
          fileNameHint: 'code-review.md');
      expect(s.name, 'code-review');
      expect(s.body, '正文');
    });

    test('无 frontmatter：全文视为正文', () {
      final s = DshSkillFile.parse('纯文本技能内容',
          fileNameHint: 'plain-skill');
      expect(s.name, 'plain-skill');
      expect(s.body, '纯文本技能内容');
      expect(s.description, isEmpty);
    });

    test('frontmatter 非法行抛 DshFormatException，import 收进 rejected', () {
      final r = DshSkillImporter.import({
        'bad': '---\n这不是键值对\n---\n正文',
      });
      expect(r.accepted, isEmpty);
      expect(r.rejected, contains('bad'));
    });

    test('kebab-case 归一：宽松名收编，全中文名拒绝', () {
      expect(DshSkillFile.normalizeName('My Cool Skill'), 'my-cool-skill');
      expect(DshSkillFile.normalizeName('foo_bar  baz'), 'foo-bar-baz');
      expect(DshSkillFile.normalizeName('代码审查'), isNull);
      expect(DshSkillFile.normalizeName('--weird--name--'), 'weird-name');
    });

    test('批量导入：成功/重名/坏名分流', () {
      final r = DshSkillImporter.import({
        'a.md': '---\nname: alpha\ndescription: 第一个\n---\nA',
        'b.md': '---\nname: Alpha\ndescription: 撞名\n---\nB', // 归一后与 a 重名
        '中文技能.md': '没有frontmatter的中文名技能',
        'c.md': '---\nname: charlie\ndescription: 第三个\n---\nC',
      });
      expect(r.accepted.map((s) => s.name), ['alpha', 'charlie']);
      expect(r.rejected.keys, containsAll(['b.md', '中文技能.md']));
    });
  });

  group('DshPatch.parseYaml（受限 YAML 子集）', () {
    // 摘自官方 dsh-base cordis.patch.yml 的代表性难点片段：
    // 行内注释、引号包名、!!js 平台门控、嵌套 config、流式序列、数字/布尔标量。
    const sample = '''
# The dsh-base bundle patch: the shared core（整行注释）
- insert:
    - id: timer
      name: '@deepseek-ai/cordis-plugin-timer'

    - id: hmr
      name: '@deepseek-ai/cordis-plugin-hmr'
      disabled: true
      config:
        root: ['.']

    - id: shell-bash
      name: '@deepseek-ai/dsh-tool-bash'
      disabled: !!js process.platform === 'win32'

    - id: shell-pwsh
      name: '@deepseek-ai/dsh-tool-pwsh'
      disabled: !!js process.platform !== 'win32'

    - id: session-title
      name: '@deepseek-ai/dsh-session-title'
      config:
        fallbackMaxWords: 5
        fallbackMaxBytes: 40
        maxTitleBytes: 80

    - id: workspace-fs
      name: '@deepseek-ai/dsh-fs-workspace'
      config:
        extraRoots: ['/tmp/a', '/tmp/b', 'C:\\\\repo']
        sandboxed: true
        ratio: 0.75

    - id: system-prompt-base
      name: '@deepseek-ai/dsh-system-prompt-base'
      config:
        section: |
          你是一个诚实的助手。# 这行井号是内容不是注释

          第二段，前面有空行。
''';

    test('解析行数与基本字段', () {
      final patch = DshPatch.parseYaml(sample);
      expect(patch.rows, hasLength(7));
      final timer = patch.rows.first;
      expect(timer.id, 'timer');
      expect(timer.name, '@deepseek-ai/cordis-plugin-timer');
      expect(timer.disabled, isNull);
      expect(timer.config, isEmpty);
    });

    test('disabled: true 布尔行', () {
      final patch = DshPatch.parseYaml(sample);
      final hmr = patch.rows[1];
      expect(hmr.disabled, isTrue);
      expect(hmr.platformGated, isFalse);
      expect(hmr.config['root'], ['.']);
    });

    test('!!js 平台门控行捕获表达式原文，不求值', () {
      final patch = DshPatch.parseYaml(sample);
      final bash = patch.rows[2];
      expect(bash.disabled, isA<DshJsExpr>());
      expect((bash.disabled as DshJsExpr).expression,
          "process.platform === 'win32'");
      expect(bash.platformGated, isTrue);
      expect(patch.rows[3].platformGated, isTrue);
    });

    test('嵌套 config：数字标量、引号流式序列、浮点、布尔', () {
      final patch = DshPatch.parseYaml(sample);
      final title = patch.rows[4].config;
      expect(title['fallbackMaxWords'], 5);
      expect(title['maxTitleBytes'], 80);
      final fs = patch.rows[5].config;
      expect(fs['extraRoots'], ['/tmp/a', '/tmp/b', 'C:\\\\repo']);
      expect(fs['sandboxed'], isTrue);
      expect(fs['ratio'], 0.75);
    });

    test('块标量：保留井号与空行，clip 尾随换行', () {
      final patch = DshPatch.parseYaml(sample);
      final section = patch.rows[6].config['section'] as String;
      expect(section, '''你是一个诚实的助手。# 这行井号是内容不是注释

第二段，前面有空行。
''');
    });

    test('超出子集立即失败（锚点/流式映射/tab）', () {
      expect(() => DshPatch.parseYaml('- insert:\n    - id: &a x\n      name: y'),
          throwsA(isA<DshFormatException>()));
      expect(() => DshPatch.parseYaml('- insert:\n    - id: x\n      name: y\n      config: {a: 1}'),
          throwsA(isA<DshFormatException>()));
      expect(() => DshPatch.parseYaml('- insert:\n  \t- id: x'),
          throwsA(isA<DshFormatException>()));
    });

    test('fromJson 与 parseYaml 产物一致', () {
      final yaml = DshPatch.parseYaml(sample);
      final json = DshPatch.fromJson([
        {
          'insert': [
            {'id': 'timer', 'name': '@deepseek-ai/cordis-plugin-timer'},
            {
              'id': 'hmr',
              'name': '@deepseek-ai/cordis-plugin-hmr',
              'disabled': true,
              'config': {'root': ['.']},
            },
          ],
        }
      ]);
      expect(json.rows, hasLength(2));
      expect(json.rows[0].id, yaml.rows[0].id);
      expect(json.rows[0].name, yaml.rows[0].name);
      expect(json.rows[1].config, yaml.rows[1].config);
      expect(json.rows[1].disabled, yaml.rows[1].disabled);
    });
  });

  group('DshBundleReader（package.json dsh 字段）', () {
    test('组合包形态', () {
      final r = DshBundleReader.fromPackageJson('''
{
  "name": "my-profile",
  "private": true,
  "dsh": {"profile": {"bundles": ["@deepseek-ai/dsh-base"]}}
}
''');
      expect(r.packageName, 'my-profile');
      expect(r.bundlePatchPath, isNull);
      expect(r.profileBundles, ['@deepseek-ai/dsh-base']);
    });

    test('bundle 形态 + 无 dsh 字段容忍', () {
      final r = DshBundleReader.fromPackageJson(
          '{"name": "some-plugin", "dsh": {"bundle": "./cordis.patch.yml"}}');
      expect(r.bundlePatchPath, './cordis.patch.yml');
      expect(r.profileBundles, isEmpty);
      final plain = DshBundleReader.fromPackageJson('{"name": "plain"}');
      expect(plain.bundlePatchPath, isNull);
    });
  });

  group('DshNames（MCP 命名互转）', () {
    test('dsh 双下划线名 -> 我们的命名空间名', () {
      expect(DshNames.dshMcpToolToOurs('mcp__memorix__search'),
          'mcp_memorix_search');
      // 含点/横线的工具名会被我们的清洗规则替换
      expect(DshNames.dshMcpToolToOurs('mcp__memory__read-file.v2'),
          'mcp_memory_read_file_v2');
      expect(DshNames.dshMcpToolToOurs('not-mcp'), isNull);
    });

    test('64 截断与 McpConnectionManager.namespace 同规则', () {
      final long = DshNames.dshMcpToolToOurs(
          'mcp__very-long-server-name__very-long-tool-name-that-exceeds-limit');
      expect(long!.length, lessThanOrEqualTo(64));
    });

    test('反向还原尽力而为', () {
      expect(DshNames.oursMcpToolToDsh('mcp_memorix_search'),
          'mcp__memorix__search');
      expect(DshNames.oursMcpToolToDsh('send_gift'), isNull);
    });
  });

  group('DshCompatReport / DshToolMap', () {
    test('patch 行归类：门控/MCP/技能/工具', () {
      final patch = DshPatch.fromJson([
        {
          'insert': [
            {'id': 'mcp-client', 'name': '@deepseek-ai/dsh-mcp-client'},
            {
              'id': 'skill-fs',
              'name': '@deepseek-ai/dsh-skill-filesystem',
              'config': {'skillDirs': ['.dsh/skills']}
            },
            {
              'id': 'win-shell',
              'name': '@deepseek-ai/dsh-tool-pwsh',
              'disabled': const DshJsExpr("process.platform !== 'win32'")
            },
            {'id': 'bare', 'name': '@deepseek-ai/dsh-something'},
          ],
        }
      ]);
      final report = DshCompatReport.analyze('some-dsh-plugin', patch);
      expect(report.rowVerdicts['mcp-client'], 'mcp-server');
      expect(report.rowVerdicts['skill-fs'], 'direct-skill');
      expect(report.rowVerdicts['win-shell'], 'platform-gated');
      expect(report.rowVerdicts['bare'], 'config-only');
      expect(report.byVerdict['mcp-server'], hasLength(1));
    });

    test('官方工具覆盖表：等价/部分/缺席三类都有', () {
      expect(DshToolMap.classify('skill').coverage, DshToolCoverage.equivalent);
      expect(
          DshToolMap.classify('web_fetch').coverage, DshToolCoverage.equivalent);
      expect(DshToolMap.classify('session_search').coverage,
          DshToolCoverage.equivalent);
      expect(DshToolMap.classify('bash').coverage, DshToolCoverage.absent);
      // 族通配命中
      expect(
          DshToolMap.classify('terminal_send').coverage, DshToolCoverage.absent);
      expect(DshToolMap.classify('schedule_create').coverage,
          DshToolCoverage.partial);
      // 未收录
      expect(DshToolMap.classify('mystery_tool').coverage,
          DshToolCoverage.absent);
    });
  });
}
