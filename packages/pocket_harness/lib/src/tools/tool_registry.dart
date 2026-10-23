import 'dart:async';

import 'skill_spec.dart';
import 'tool_spec.dart';

/// 注册表条目类别（工具 / 技能）
enum EntryKind { tool, skill }

/// 注册表变更事件：增/删（热插拔的失效信号）。
/// 宿主按 [kind] 分流：tool → 重建 Agent 工具表；skill → 刷新 prompt 缓存。
class ToolRegistryChange {
  final String name;
  final EntryKind kind;
  final bool added; // true=注册, false=卸载
  const ToolRegistryChange(this.name,
      {required this.kind, required this.added});
}

/// 一次注册的句柄：dispose 即卸载（Cordis 式可逆注册）。
class ToolRegistration {
  final String name;
  final void Function() _dispose;
  bool _disposed = false;
  ToolRegistration(this.name, this._dispose);

  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dispose();
  }
}

/// 统一插件注册表——"万物皆插件"的脊柱。
///
/// 工具与技能在这里归一：同一命名空间（跨类别重名即冲突）、同一可逆语义
///（register 返回句柄，dispose 即卸载）、同一变更事件流（宿主按 kind 分流）。
abstract class ToolRegistry {
  /// 注册一个【可调用工具】；重名（含与技能重名）抛 [ToolNameConflict]。
  ToolRegistration register(ToolSpec spec);

  /// 注册一个【技能】（prompt 注入物，非可调用）；重名抛 [ToolNameConflict]。
  ToolRegistration registerSkill(SkillSpec spec);

  /// 幂等卸载（工具或技能均可；未注册时静默返回）。
  void dispose(String name);

  ToolSpec? lookup(String name);
  SkillSpec? lookupSkill(String name);

  /// 当前全部工具（快照，注册顺序）
  List<ToolSpec> snapshot();

  /// 当前全部技能（快照，注册顺序）
  List<SkillSpec> snapshotSkills();

  /// 增/删事件流（含 kind，供宿主分流）
  Stream<ToolRegistryChange> get changes;
}

/// 默认实现：纯内存、零依赖。
class InMemoryToolRegistry implements ToolRegistry {
  final Map<String, ToolSpec> _tools = {};
  final Map<String, SkillSpec> _skills = {};
  final List<String> _order = []; // 注册顺序（工具+技能混排）
  final StreamController<ToolRegistryChange> _changes =
      StreamController<ToolRegistryChange>.broadcast();

  @override
  ToolRegistration register(ToolSpec spec) =>
      _add(spec.name, EntryKind.tool, () => _tools[spec.name] = spec);

  @override
  ToolRegistration registerSkill(SkillSpec spec) =>
      _add(spec.name, EntryKind.skill, () => _skills[spec.name] = spec);

  ToolRegistration _add(
      String name, EntryKind kind, void Function() install) {
    if (_tools.containsKey(name) || _skills.containsKey(name)) {
      throw ToolNameConflict(name);
    }
    install();
    _order.add(name);
    _changes.add(ToolRegistryChange(name, kind: kind, added: true));
    return ToolRegistration(name, () => dispose(name));
  }

  @override
  void dispose(String name) {
    final wasTool = _tools.remove(name) != null;
    final wasSkill = _skills.remove(name) != null;
    if (!wasTool && !wasSkill) return;
    _order.remove(name);
    _changes.add(ToolRegistryChange(name,
        kind: wasTool ? EntryKind.tool : EntryKind.skill, added: false));
  }

  @override
  ToolSpec? lookup(String name) => _tools[name];

  @override
  SkillSpec? lookupSkill(String name) => _skills[name];

  @override
  List<ToolSpec> snapshot() =>
      [for (final n in _order) if (_tools[n] != null) _tools[n]!];

  @override
  List<SkillSpec> snapshotSkills() =>
      [for (final n in _order) if (_skills[n] != null) _skills[n]!];

  @override
  Stream<ToolRegistryChange> get changes => _changes.stream;

  /// 包销毁时关闭控制器（测试用；宿主长生命周期可不调用）
  Future<void> close() => _changes.close();
}
