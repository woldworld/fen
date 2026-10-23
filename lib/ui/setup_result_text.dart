import '../core/setup_service.dart';
import '../l10n/app_localizations.dart';

/// ============================================================
/// 引导页测试结果 / 模型预设的**文案解析层**（UI 侧）。
///
/// 为什么单独一个文件：`lib/core/setup_service.dart` 必须保持**零依赖**
/// （`tool/verify_setup_service.dart` 用纯 `dart run` import 它，起本地
/// HttpServer 离线复算整张错误映射表）⇒ 它只能返回**语言无关的结果码**
/// （`SetupResultCode`），文案在这里按调用方传入的 `AppLocalizations`
/// **渲染时**解析。
///
/// ★ 修的是用户实测 bug（2026-10-17，看演示视频发现）：
/// 「英语版引导页测试中转站连通性，弹出的是中文」—— 旧实现把结论拼成
/// 硬编码中文字面量存在 core 里。现在每条文案都走 ARB 五语种键
/// （`setupModel*` / `setupHub*` / `setupHttp*` / `setupPreset*`）。
///
/// ★ 为什么**每次调用都重新解析**（不缓存）：引导页第 1 步有语言切换器，
/// 用户可能「先测一轮 → 回第 1 步切英语 → 再前进看结果卡」。缓存会让那张卡
/// 留着旧语言 —— 与本次修的 bug 同族。入参就是当前帧的 l10n，永远一致。
/// ============================================================

/// 解析后的测试结果文案（对应 `SetupTestResult` 的三个展示字段）。
class SetupResultText {
  final String title;
  final String message;
  final String? suggestion;

  const SetupResultText(this.title, this.message, [this.suggestion]);
}

/// 把语言无关的 [SetupTestResult] 解析成当前语言的展示文案。
///
/// ⚠️ **新增 [SetupResultCode] 值时必须同步加 case** ——
/// `tool/verify_setup_service.dart` 用「case 数 == 枚举数」守着这件事
/// （漏一个 case 编译期就报 exhaustive switch 错，双重保险）。
SetupResultText setupResultText(SetupTestResult r, AppLocalizations l10n) {
  switch (r.code) {
    case SetupResultCode.modelEmptyUrl:
      return SetupResultText(l10n.setupModelEmptyUrlTitle,
          l10n.setupModelEmptyUrlBody, l10n.setupModelEmptyUrlSuggest);
    case SetupResultCode.modelBadUrl:
      return SetupResultText(l10n.setupModelBadUrlTitle,
          l10n.setupModelBadUrlBody, l10n.setupModelBadUrlSuggest);
    case SetupResultCode.modelEmptyKey:
      return SetupResultText(l10n.setupModelEmptyKeyTitle,
          l10n.setupModelEmptyKeyBody, l10n.setupModelEmptyKeySuggest);
    case SetupResultCode.modelEmptyName:
      return SetupResultText(l10n.setupModelEmptyNameTitle,
          l10n.setupModelEmptyNameBody, l10n.setupModelEmptyNameSuggest);
    case SetupResultCode.modelOk:
      return SetupResultText(l10n.setupModelOkTitle, l10n.setupModelOkBody);
    case SetupResultCode.modelTls:
      return SetupResultText(l10n.setupModelTlsTitle, l10n.setupModelTlsBody,
          l10n.setupModelTlsSuggest);
    case SetupResultCode.modelUnreachable:
      return SetupResultText(l10n.setupModelUnreachableTitle,
          l10n.setupModelUnreachableBody, l10n.setupModelUnreachableSuggest);
    case SetupResultCode.modelTimeout:
      return SetupResultText(l10n.setupModelTimeoutTitle,
          l10n.setupModelTimeoutBody, l10n.setupModelTimeoutSuggest);
    case SetupResultCode.modelFail:
      return SetupResultText(l10n.setupModelFailTitle,
          l10n.setupModelFailBody(r.detail ?? ''), l10n.setupModelFailSuggest);
    case SetupResultCode.hubEmpty:
      return SetupResultText(l10n.setupHubEmptyTitle, l10n.setupHubEmptyBody,
          l10n.setupHubEmptySuggest);
    case SetupResultCode.hubBadUrl:
      return SetupResultText(l10n.setupHubBadUrlTitle, l10n.setupHubBadUrlBody,
          l10n.setupHubBadUrlSuggest);
    case SetupResultCode.hubBadStatus:
      return SetupResultText(l10n.setupHubBadStatusTitle('${r.status ?? 0}'),
          l10n.setupHubBadStatusBody, l10n.setupHubBadStatusSuggest);
    case SetupResultCode.hubOk:
      return SetupResultText(l10n.setupHubOkTitle, l10n.setupHubOkBody);
    case SetupResultCode.hubNotOurs:
      return SetupResultText(l10n.setupHubNotOursTitle, l10n.setupHubNotOursBody,
          l10n.setupHubNotOursSuggest);
    case SetupResultCode.hubUnreachable:
      return SetupResultText(l10n.setupHubUnreachableTitle,
          l10n.setupHubUnreachableBody, l10n.setupHubUnreachableSuggest);
    case SetupResultCode.hubTimeout:
      return SetupResultText(l10n.setupHubTimeoutTitle, l10n.setupHubTimeoutBody,
          l10n.setupHubTimeoutSuggest);
    case SetupResultCode.hubFail:
      return SetupResultText(
          l10n.setupHubFailTitle, l10n.setupHubFailBody(r.detail ?? ''));
    case SetupResultCode.http400:
      return SetupResultText(l10n.setupHttp400Title,
          r.detail ?? l10n.setupHttp400BodyDefault, l10n.setupHttp400Suggest);
    case SetupResultCode.http401:
      return SetupResultText(l10n.setupHttp401Title,
          r.detail ?? l10n.setupHttp401BodyDefault, l10n.setupHttp401Suggest);
    case SetupResultCode.http402:
      return SetupResultText(l10n.setupHttp402Title,
          r.detail ?? l10n.setupHttp402BodyDefault, l10n.setupHttp402Suggest);
    case SetupResultCode.http404:
      return SetupResultText(l10n.setupHttp404Title,
          r.detail ?? l10n.setupHttp404BodyDefault, l10n.setupHttp404Suggest);
    case SetupResultCode.http429:
      return SetupResultText(l10n.setupHttp429Title,
          r.detail ?? l10n.setupHttp429BodyDefault, l10n.setupHttp429Suggest);
    case SetupResultCode.http5xx:
      return SetupResultText(l10n.setupHttp5xxTitle('${r.status ?? 0}'),
          r.detail ?? l10n.setupHttp5xxBodyDefault, l10n.setupHttp5xxSuggest);
    case SetupResultCode.httpOther:
      return SetupResultText(l10n.setupHttpOtherTitle('${r.status ?? 0}'),
          r.detail ?? l10n.setupHttpOtherBodyDefault,
          l10n.setupHttpOtherSuggest);
  }
}

/// 解析后的模型预设文案（引导页第 2 步卡片 / 第 3 步副标题 / 完成步摘要）。
class SetupPresetText {
  final String label;
  final String note;
  final String keyHint;

  const SetupPresetText(this.label, this.note, this.keyHint);
}

/// 把 [ModelPreset] 的展示文案解析成当前语言（按 `id` 走 ARB）。
SetupPresetText setupPresetText(ModelPreset p, AppLocalizations l10n) {
  switch (p.id) {
    case 'deepseek':
      return SetupPresetText(l10n.setupPresetDeepseekLabel,
          l10n.setupPresetDeepseekNote, l10n.setupPresetDeepseekKeyHint);
    case 'openai':
      return SetupPresetText(l10n.setupPresetOpenaiLabel,
          l10n.setupPresetOpenaiNote, l10n.setupPresetOpenaiKeyHint);
    case 'kimi':
      return SetupPresetText(l10n.setupPresetKimiLabel,
          l10n.setupPresetKimiNote, l10n.setupPresetKimiKeyHint);
    case 'glm':
      return SetupPresetText(l10n.setupPresetGlmLabel, l10n.setupPresetGlmNote,
          l10n.setupPresetGlmKeyHint);
    case 'qwen':
      return SetupPresetText(l10n.setupPresetQwenLabel,
          l10n.setupPresetQwenNote, l10n.setupPresetQwenKeyHint);
    case 'siliconflow':
      return SetupPresetText(l10n.setupPresetSiliconflowLabel,
          l10n.setupPresetSiliconflowNote, l10n.setupPresetSiliconflowKeyHint);
    case 'custom':
      return SetupPresetText(l10n.setupPresetCustomLabel,
          l10n.setupPresetCustomNote, l10n.setupPresetCustomKeyHint);
    default:
      // 未知 id 不该存在（`SetupService.presetById` 已回落到首个预设）；
      // 真出现时给首个预设的文案，与 presetById 的回落口径一致。
      return SetupPresetText(l10n.setupPresetDeepseekLabel,
          l10n.setupPresetDeepseekNote, l10n.setupPresetDeepseekKeyHint);
  }
}
