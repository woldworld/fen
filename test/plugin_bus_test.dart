import 'package:flutter_test/flutter_test.dart';
import 'package:dahuang_ai/core/plugin_bus.dart';

/// M3 安全不变量：授权等级绝不信任 tools.permissions 声明列。
/// PluginBus 从 type+content 现场推导能力与风险——攻击者篡改库里的
/// permissions/risk_level 声明字段必须被无视（防绕过授权）。
void main() {
  group('PluginBus 防篡改不变量（M3 钉住）', () {
    test('permissions 列的伪造声明被无视：按 type+content 推导', () {
      final row = {
        'type': 'local',
        'content': 'BUILTIN_TIME', // 真实能力：纯本地
        'permissions': '["settings","social"]', // 篡改：伪造高危能力声明
        'risk_level': 'high', // 篡改：伪造风险等级
      };
      final caps = PluginBus.capabilitiesOfRow(row);
      expect(caps, contains(PluginCapability.local));
      expect(caps, isNot(contains(PluginCapability.settings)));
      expect(caps, isNot(contains(PluginCapability.social)));
      expect(PluginBus.riskOfRow(row), PluginRisk.low);
    });

    test('能力声明列即使为空也按真实内容推导', () {
      final row = {
        'type': 'local',
        'content': 'BUILTIN_URL', // 真实能力：唤起应用（高危）
        'permissions': '', // 清空声明也逃不掉
        'risk_level': null,
      };
      final caps = PluginBus.capabilitiesOfRow(row);
      expect(caps, contains(PluginCapability.launchApp));
      expect(PluginBus.riskOfRow(row), PluginRisk.high);
    });

    test('风险推导规则：launchApp/settings/social→high，network→medium，其余→low', () {
      List<String> capsOf(String type, String content) =>
          PluginBus.capabilitiesOfRow({'type': type, 'content': content});
      expect(PluginBus.riskOfRow({
        'type': 'local',
        'content': 'BUILTIN_URL',
      }), PluginRisk.high);
      expect(PluginBus.riskOfRow({
        'type': 'mcp',
        'content': '',
      }), PluginRisk.medium);
      expect(PluginBus.riskOfRow({
        'type': 'local',
        'content': 'BUILTIN_TIME',
      }), PluginRisk.low);
      expect(capsOf('skill', '').first, PluginCapability.memory);
    });
  });
}
