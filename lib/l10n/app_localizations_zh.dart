// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '大荒AI';

  @override
  String get commonOk => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonRetry => '重试';

  @override
  String get commonBack => '返回';

  @override
  String get commonNext => '下一步';

  @override
  String get commonSkip => '跳过';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonClose => '关闭';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonDone => '完成';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get toolPermissionTitle => '安全确认';

  @override
  String toolPermissionMessage(String description) {
    return '智能体请求执行高权限操作：\n\n$description\n\n是否允许？';
  }

  @override
  String get toolPermissionAllow => '允许';

  @override
  String get toolPermissionDeny => '拒绝';

  @override
  String get permListSeparator => '、';

  @override
  String permPluginGrantBody(String name, String caps, String desc) {
    return '插件「$name」首次请求以下能力：$caps\n插件声明：$desc\n\n仅首次需要确认；确认后该插件可自行调用已授权能力，可随时在技能控制中心关闭该插件来吊销授权。';
  }

  @override
  String get permPluginDeviceControl => '手机控制';

  @override
  String permPluginMcp(String name) {
    return 'MCP 服务 $name';
  }

  @override
  String permActionCreateTool(String name) {
    return '创建/修改技能 [$name]';
  }

  @override
  String permActionOpenUrl(String url) {
    return '打开 $url';
  }

  @override
  String permActionChangeSettings(String keys) {
    return '修改系统设置: $keys';
  }

  @override
  String get permDeniedReask => '该插件此前已被拒绝授权。如需重新授权，请在技能控制中心关闭再开启该插件。';

  @override
  String get permDeniedNoGrant => '未获得能力授权，已中止本次调用。';

  @override
  String get permDenyCreateTool => '用户拒绝了创建工具请求';

  @override
  String get permDenyOpenUrl => '用户已取消';

  @override
  String get permDenyChangeSettings => '用户拒绝了设置修改';

  @override
  String get permDenyGeneric => '用户未确认';

  @override
  String permActionSendMail(String to) {
    return '发送邮件给 $to';
  }

  @override
  String get permDenySendMail => '用户拒绝发送该邮件';

  @override
  String get manageMailTitle => '邮箱';

  @override
  String get manageMailSubtitle => '让分身代你收发邮件';

  @override
  String get mailTitle => '邮箱账号';

  @override
  String get mailIntro =>
      '邮箱口令只存在这台手机上，绝不上传到我们服务器。请填「应用专用密码」或「授权码」，不要填登录密码。任何邮箱都支持：点下面的服务商，或直接输入邮箱地址，服务器会自动填入。';

  @override
  String get mailNone => '还没有绑定账号';

  @override
  String get mailAddSection => '添加账号';

  @override
  String get mailAddress => '邮箱地址';

  @override
  String get mailDisplayName => '显示名（可选）';

  @override
  String get mailAppPassword => '应用专用密码 / 授权码';

  @override
  String get mailAppPasswordHint => '多数邮箱要用「应用专用密码」或「授权码」，不是登录密码。';

  @override
  String get mailAppPasswordHintGmail =>
      'Gmail：先开启两步验证，再到 myaccount.google.com/apppasswords 生成。';

  @override
  String get mailAppPasswordHintNetease =>
      '网易邮箱（163/126）：请填「授权码」。网页版 → 设置 → POP3/SMTP/IMAP → 开启 IMAP/SMTP 服务，再生成授权码。';

  @override
  String get mailAppPasswordHintQQ =>
      'QQ 邮箱：请填「授权码」。网页版 → 设置 → 账户 → 开启 IMAP/SMTP 服务，再生成授权码。';

  @override
  String get mailAppPasswordHintOutlook =>
      'Outlook / Microsoft 365：先开启两步验证，再生成应用专用密码。';

  @override
  String get mailPresetLabel => '点服务商可直接填入服务器；或直接输入邮箱地址，会自动匹配。';

  @override
  String mailAutoFilled(String provider) {
    return '已按 $provider 自动填入服务器。只有用自定义域名时才需要改。';
  }

  @override
  String get mailManualServers => '服务器已手动填写，自动匹配已暂停。';

  @override
  String get mailNeedServers => '请先在上面选一个服务商，或输入邮箱地址，以便自动填入服务器。';

  @override
  String get mailErrAuth => '授权码/应用密码不对，或未开启 IMAP 服务。对照上面的提示重新生成一次。';

  @override
  String get mailErrUnsafe => '服务商拦下了这次登录。请到网页版开启 IMAP/SMTP 服务，并使用「授权码」而非登录密码。';

  @override
  String get mailSecurityTls => '隐式 TLS（465/993）';

  @override
  String get mailSecurityStarttls => 'STARTTLS（587）';

  @override
  String get mailSaveAndTest => '保存并测试';

  @override
  String get mailTestConn => '测试连接';

  @override
  String get mailTesting => '测试中…';

  @override
  String get mailTestOk => '连接成功，配置可用。';

  @override
  String mailTestFail(String reason) {
    return '连接失败：$reason';
  }

  @override
  String get mailUnbind => '解绑';

  @override
  String get mailUnbound => '已解绑，口令已一并删除';

  @override
  String mailLastError(String reason) {
    return '上次错误：$reason';
  }

  @override
  String get capNetwork => '网络访问';

  @override
  String get capLaunchApp => '唤起应用';

  @override
  String get capDevice => '本地硬件';

  @override
  String get capScreenControl => '操作手机屏幕';

  @override
  String get capMemory => '读写记忆';

  @override
  String get capSettings => '修改设置';

  @override
  String get capSocial => '代理社交';

  @override
  String get capLocal => '纯本地';

  @override
  String get riskHigh => '高风险';

  @override
  String get riskMedium => '中风险';

  @override
  String get riskLow => '低风险';

  @override
  String get errorGeneric => '出错了，请重试。';

  @override
  String get errorNetwork => '网络不可用。';

  @override
  String get errorPermissionDenied => '权限被拒绝。';

  @override
  String get errorInvalidInput => '输入内容不正确，请检查。';

  @override
  String get onboardingWelcomeTitle => '你的分身，替你先去认识人';

  @override
  String get onboardingWelcomeSubtitle => '它替你记事、跑腿，认识新朋友时先替你开口——值得时再把你叫进来。';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get onboardingModelTitle => '连接一个模型';

  @override
  String get onboardingModelSubtitle => '可以自带 API key，也可以先用我们送的免费额度。';

  @override
  String get onboardingModelHint => '你的 key 只存在本机。';

  @override
  String get onboardingProfileTitle => '这个分身属于谁？';

  @override
  String get onboardingProfileSubtitle => '填个名字就够了，之后可以再补充。';

  @override
  String get onboardingDone => '一切就绪';

  @override
  String get onboardingDoneSubtitle => '你的分身准备好了。邀请一个人，它就能替你开始。';

  @override
  String onboardingStepIndicator(int cur, int total, String label) {
    return '第 $cur / $total 步 · $label';
  }

  @override
  String get onboardingStepWelcome => '欢迎';

  @override
  String get onboardingStepModel => '选模型';

  @override
  String get onboardingStepKey => '填密钥';

  @override
  String get onboardingStepIdentity => '起名字';

  @override
  String get onboardingStepSocial => '连社交';

  @override
  String get onboardingStepDone => '完成';

  @override
  String get onboardingPrevStep => '上一步';

  @override
  String get onboardingWelcomeHeading => '欢迎使用大荒AI';

  @override
  String get onboardingWelcomeBody =>
      '你的智能体，住在你的手机里。\n三分钟设置好，之后它就能替你记事、出主意、交朋友。';

  @override
  String get onboardingDisclosureNote => '默认由你的分身出面：它先替你开口，值得你本人出面时再把你叫进来。';

  @override
  String get privacyDataLocalTitle => '数据是你自己的';

  @override
  String get privacyDataLocalBody => '聊天记录、记忆、人际关系都存在本机。我们看不到，也不会上传。';

  @override
  String get onboardingSocialCardTitle => '你的智能体能去社交';

  @override
  String get onboardingSocialCardBody => '和朋友的智能体互相认识、私下聊天；近距离可以直连，远距离走中转站。';

  @override
  String get onboardingModelCardTitle => '模型你自己选';

  @override
  String get onboardingModelCardBody =>
      '我们不卖额度。你可以用 DeepSeek、OpenAI、Kimi、智谱等任意一家。';

  @override
  String get onboardingThreeThings =>
      '免费体验可直接开始；若选「我有自己的 API Key」，会依次问你模型、Key 与称呼。';

  @override
  String get onboardingPickModelTitle => '你想用哪家的模型？';

  @override
  String get onboardingPickModelSubtitle => '选一个即可，不确定就选第一个（DeepSeek）。';

  @override
  String get onboardingPasteKeyTitle => '把你的 API Key 粘进来';

  @override
  String get onboardingFieldBaseUrl => '接口地址';

  @override
  String get onboardingHintBaseUrl => '例如 https://api.deepseek.com';

  @override
  String get onboardingFieldModelName => '模型名称';

  @override
  String get onboardingHintModelName => '例如 deepseek-v4-flash';

  @override
  String get onboardingFieldApiKey => 'API Key（密钥）';

  @override
  String get onboardingTesting => '正在测试…';

  @override
  String get onboardingTestConnection => '测试连接';

  @override
  String get onboardingNameStepTitle => '给它起个名字';

  @override
  String get onboardingNameStepSubtitle => '这些随时可以在设置里改。';

  @override
  String get onboardingFieldMasterName => '它该怎么称呼你？';

  @override
  String get onboardingHintMasterName => '例如：主人、老板、妈妈';

  @override
  String get onboardingFieldAgentName => '它的名字';

  @override
  String get onboardingHintAgentName => '例如：小荒、阿福';

  @override
  String get onboardingFieldTone => '它的说话风格';

  @override
  String get onboardingHintTone => '例如：温暖、简洁、有主见';

  @override
  String get onboardingSocialStepTitle => '要不要让智能体去社交？';

  @override
  String get onboardingSocialStepSubtitle =>
      '填上中转站地址后，你的智能体才能和远方朋友的智能体互通。\n没有也没关系，可以跳过——近距离仍然可以直连，本机功能完全不受影响。';

  @override
  String get onboardingFieldHubKey => '中转站访问 Key（可不填）';

  @override
  String get onboardingFieldHubUrl => '中转站地址（可留空）';

  @override
  String get onboardingHintHubKey =>
      '官方中转站若启用了准入，就需要运营方签发的 Key（形如 WK-XXXXX-XXXXX-XXXXX-XXXXX）；自建或局域网地址留空即可';

  @override
  String get onboardingHintHubUrl => '默认 https://hub.wold.world（局域网测试可填电脑 IP）';

  @override
  String get onboardingFieldWorldUrl => '世界服务器地址（留空则用中转站地址 + /world）';

  @override
  String get onboardingHintWorldUrl => '默认 https://world.wold.world';

  @override
  String get onboardingConnecting => '正在连接…';

  @override
  String get onboardingTestAndConnect => '测试并连接';

  @override
  String get onboardingDoneHeading => '配置完成，可以开始了';

  @override
  String get onboardingSummaryModel => '模型服务';

  @override
  String get onboardingSummaryAgentName => '智能体名字';

  @override
  String get onboardingSummaryCloud => '云端社交';

  @override
  String get onboardingCloudOn => '已开启（可与朋友的智能体互通）';

  @override
  String get onboardingCloudOff => '未开启（仅本机与近距离）';

  @override
  String get onboardingNextWhere =>
      '接下来去哪里？\n· 「日常交流」— 和它聊天，它会记住你说过的事\n· 「小荒社区」— 让分身替你认识人\n· 「管理设置」— 随时改模型、改名字、开关社交';

  @override
  String get onboardingNotFilled => '未填写';

  @override
  String get onboardingWarnNotTestedTitle => '还没有测试成功';

  @override
  String get onboardingWarnNotTestedBody =>
      '建议先点「测试连接」，确认密钥能用再继续。\n\n如果现在跳过，App 装好后会一直提示「请配置 API Key」，需要再到设置里填写。';

  @override
  String get onboardingGoBackTest => '回去测试';

  @override
  String get onboardingContinueAnyway => '仍然继续';

  @override
  String get settingsTitle => '控制中心 (Core Config)';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsModel => '模型';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsSaved => '💾 核心参数与灵魂设定已重铸！';

  @override
  String get settingsBgChanged => '🖼️ 聊天背景已更换，返回首页生效！';

  @override
  String get settingsBgReset => '🧹 聊天背景已恢复默认';

  @override
  String get settingsSecAppearance => '🎨 界面个性化';

  @override
  String get settingsSetWallpaper => '设置聊天壁纸';

  @override
  String get settingsRestoreDefault => '恢复默认';

  @override
  String get settingsSecSafety => '🛡️ 自主行为与安全';

  @override
  String get settingsObservationMode => '观察模式（推荐）';

  @override
  String get settingsObservationSubtitle => '开启后，主动搭讪只生成建议卡，由您确认后才真正发出';

  @override
  String get settingsAutoAllowLabel => '自动放行的高危工具（逗号分隔）';

  @override
  String get settingsAutoAllowHint => '例如 open_url_or_app, create_custom_tool';

  @override
  String get settingsDeviceControlTitle => '🖐️ 手机控制（无障碍）';

  @override
  String get settingsDeviceControlSubtitle =>
      '让智能体读屏、点击、输入、打开应用；需要系统无障碍授权，默认关闭';

  @override
  String get settingsSecSoul => '🎭 灵魂塑造 (Soul.md)';

  @override
  String get settingsAgentName => '智能体的名字';

  @override
  String get settingsMasterName => '它该怎么称呼您？';

  @override
  String get settingsRelationship => '你们之间的关系设定';

  @override
  String get settingsTone => '回复语气与风格';

  @override
  String get settingsExtraDesc => '额外行为准则 / 期望规矩';

  @override
  String get settingsSecMemory => '💾 记忆熔断与检索';

  @override
  String get settingsMaxRounds => '默认代入的对话最大轮数';

  @override
  String get settingsMaxRoundsHint => '例如 50';

  @override
  String get settingsTimeLimit => '默认追溯的最大时长 (小时)';

  @override
  String get settingsTimeLimitHint => '例如 24';

  @override
  String get settingsRecallEnabled => '自动回忆（每轮检索往事）';

  @override
  String get settingsProfileEnabled => '长期画像注入（告诉它你长期关心什么）';

  @override
  String get settingsSecEngine => '⚙️ 大脑引擎 (BYOK)';

  @override
  String get settingsBaseUrl => 'Base URL (网关/代理)';

  @override
  String get settingsModelName => '模型名称 (Model Name)';

  @override
  String get settingsApiKey => 'API Key (密钥)';

  @override
  String get settingsHubUrl => '云端 Hub 地址（局域网测试可填电脑 IP）';

  @override
  String get settingsHubKey => '中转站访问 Key（可不填）';

  @override
  String get settingsHubKeyApply => '申请访问 Key';

  @override
  String get settingsHubKeyApplyFailed => '打不开申请页面，请检查网络后重试。';

  @override
  String get settingsHubKeyHint =>
      '只有官方中转站需要；由运营方签发，形如 WK-XXXXX-XXXXX-XXXXX-XXXXX';

  @override
  String get settingsHubUrlHint =>
      '例如 https://hub.example.com 或 http://192.168.1.100:3000';

  @override
  String get settingsWorldUrl => '世界服务器地址（留空则用 Hub 地址 + /world）';

  @override
  String get settingsWorldUrlHint =>
      '例如 https://hub.example.com/world 或 http://192.168.1.100:3100';

  @override
  String get settingsGodUrl => 'GOD 控制室桥接（留空则隐藏 GOD 入口）';

  @override
  String get settingsGodUrlHint => '例如 http://192.168.1.100:3300';

  @override
  String get settingsLocalModelUrl => '本地模型地址（离线兜底，可选）';

  @override
  String get settingsLocalModelUrlHint =>
      '默认 http://127.0.0.1:11434（清空 = 关闭本地兜底）';

  @override
  String get settingsLocalModelName => '本地模型名';

  @override
  String get settingsLocalModelNameHint => '默认 qwen2.5:3b';

  @override
  String get settingsNotifySection => '系统通知';

  @override
  String get settingsNotifyEnabled => '开启系统通知';

  @override
  String get settingsNotifyQuiet => '免打扰时段';

  @override
  String get settingsNotifyQuietStart => '起始小时';

  @override
  String get settingsNotifyQuietEnd => '结束小时';

  @override
  String get settingsMorningHour => '晨间问候时间';

  @override
  String get settingsNotifyPermissionNeeded => '系统通知权限未开启，点此授权';

  @override
  String get helpNotifyGuideTitle => '系统通知会叫醒你什么';

  @override
  String get helpNotifyGuideBody =>
      '只有四件事会打扰你：① 有人委托你办事；② 会客厅里有人 @ 你；③ 你的分身起草了一条发言、等你放行（它被卡住了）；④ 收到互介卡或私聊消息。\n\n会客厅里的普通发言一律不弹——房间消息太密，弹了等于没弹。\n\n免打扰时段内所有通知都会被按下，回到前台仍能看到。起止小时填成一样 = 不启用免打扰。\n\n⚠️ 只有 App 还活着时才会弹通知；若被系统彻底杀掉，消息要等你下次打开才看得到。';

  @override
  String get notifyChannelName => '大荒提醒';

  @override
  String get notifyChannelDescription => '分身的消息、委托与待确认事项';

  @override
  String get notifyDirectMessageTitle => '收到新消息';

  @override
  String notifyDirectMessageBody(String peer) {
    return '来自 $peer 的消息';
  }

  @override
  String get notifyLoungeMentionTitle => '会客厅有人 @ 你';

  @override
  String notifyLoungeMentionBody(String who) {
    return '$who 在会客厅 @ 了你';
  }

  @override
  String get notifySuggestionTitle => '有草稿等你放行';

  @override
  String get notifySuggestionBody => '你的分身起草了一条发言，等你确认后才发得出去';

  @override
  String get notifyDelegationTitle => '收到一条委托';

  @override
  String notifyDelegationBody(String peer) {
    return '$peer 委托你办一件事';
  }

  @override
  String get notifyIntercardTitle => '收到一张互介卡';

  @override
  String notifyIntercardBody(String peer) {
    return '$peer 递来一张互介卡';
  }

  @override
  String get settingsRerunOnboarding => '重新运行接入向导（约三分钟）';

  @override
  String get settingsLegalTitle => '法律与关于';

  @override
  String get settingsLegalIntro => '隐私政策与服务条款，在浏览器中打开。';

  @override
  String get settingsPrivacyTitle => '隐私政策';

  @override
  String get settingsTermsTitle => '服务条款';

  @override
  String get settingsLegalOpenFailed => '打不开，请检查网络后重试。';

  @override
  String get settingsSaveButton => '💾 保存配置并重铸灵魂';

  @override
  String get mcpCenterTitle => '记忆与技能控制中心 (MCP)';

  @override
  String get mcpAutoTitle => '🤖 AI 自主按需调用 (推荐)';

  @override
  String get mcpAutoSubtitle => '开启时，AI 将自动在后台寻找并按需触发任何已注册的工具。子开关将被安全锁定并默认开启。';

  @override
  String mcpBusSummaryClean(int total, int signed) {
    return '🛡️ 插件总线：$total 个插件（已签名 $signed）';
  }

  @override
  String mcpBusSummaryTampered(int total, int signed, int tampered) {
    return '🛡️ 插件总线：$total 个插件（已签名 $signed · ⚠️ 签名失效 $tampered 已自动禁用）';
  }

  @override
  String get mcpImportTitle => '从 DSH 生态导入';

  @override
  String get mcpImportSubtitle => '导入技能与 MCP 服务，或给插件包做兼容体检';

  @override
  String get mcpCategoryHeader => '📦 技能分类库 (Tab Panel)';

  @override
  String get mcpCatLocalTitle => '🔌 本地硬件与 Webhook 接口';

  @override
  String get mcpCatLocalSubtitle => '触发手机马达、系统查询及自定义网络 API 工具';

  @override
  String get mcpCatMcpTitle => '🌐 MCP 外部扩展协议';

  @override
  String get mcpCatMcpSubtitle => '对接标准的 Model Context Protocol 远程服务';

  @override
  String get mcpCatSkillTitle => '🧠 系统提示词技能 (Skills)';

  @override
  String get mcpCatSkillSubtitle => '动态向 AI 大脑注入额外的指令、规矩与特殊技能';

  @override
  String get mcpContent => '内容';

  @override
  String get mcpContentHint => '请输入内容';

  @override
  String get mcpWebhookLabel => 'Webhook 接口 URL';

  @override
  String get mcpWebhookHint => '以 http:// 或 https:// 开头的网络 API 地址';

  @override
  String get mcpServerLabel => 'MCP 服务器 URL';

  @override
  String get mcpServerHint => '例如: http://localhost:8080/mcp';

  @override
  String get mcpPromptLabel => '系统提示词 (Prompt)';

  @override
  String get mcpPromptHint => '例如：回答完所有话之后，必须在末尾加一句‘喵~’';

  @override
  String get mcpEditToolTitle => '修改工具配置';

  @override
  String get mcpAddToolTitle => '添加自定义工具';

  @override
  String get mcpToolNameLabel => '工具唯一标识名 (英文字符)';

  @override
  String get mcpToolDescLabel => '工具功能描述 (供 AI 理解)';

  @override
  String get mcpCancel => '取消';

  @override
  String get mcpSaveRegister => '保存并注册';

  @override
  String get mcpManageTools => '管理工具';

  @override
  String get mcpTypeLocal => '本地 Webhook 工具';

  @override
  String get mcpTypeMcp => 'MCP 外部协议配置';

  @override
  String get mcpTypeSkill => '提示词技能 (Skills) 库';

  @override
  String get mcpEmpty => '暂无工具，点击右上角加号创建第一款工具！';

  @override
  String get mcpTagDream => '梦境';

  @override
  String get mcpTagSigInvalid => '签名失效';

  @override
  String mcpSubTampered(String desc) {
    return '$desc · 签名失效，已自动禁用';
  }

  @override
  String mcpSubDreamPending(String desc) {
    return '$desc · 梦境生成，待确认启用';
  }

  @override
  String get mcpSigBuiltin => '内置';

  @override
  String get mcpSigOk => '🔐 设备签名';

  @override
  String get mcpSigUnsigned => '未签名';

  @override
  String get mcpSigInvalid => '⚠️ 签名失效';

  @override
  String get mcpToolDescHeader => '📌 工具描述:';

  @override
  String get mcpInjectionDetail => '📜 提示词注入细节 (System Prompt):';

  @override
  String get mcpPhysicalUrl => '🔗 物理执行地址 (URL/BUILTIN):';

  @override
  String get mcpEditParams => '修改此工具参数';

  @override
  String get manageDreamSleeping => '🌙 智能体已进入深度睡眠，正在进行潜意识记忆提炼...';

  @override
  String get manageDreamAwake => '☀️ 智能体苏醒！记忆库已成功进化，档案已更新。';

  @override
  String get manageDreamFailed => '❌ 记忆提炼失败，可能大模型未按规范输出 JSON。';

  @override
  String get manageSelfEvolutionTitle => '自我进化 (Nanobot Dream Engine)';

  @override
  String get manageSelfEvolutionBody =>
      '神经网络后台进程 (WorkManager) 监控中。管家将在夜间静默深度检索并进化提示词底层基因（Skills）。';

  @override
  String get manageMetricDepth => '记忆深度';

  @override
  String get manageMetricSkillsLabel => '派生技能';

  @override
  String manageMetricSkillsValue(int n) {
    return '$n个';
  }

  @override
  String get manageMetricSessionsLabel => '归类会话';

  @override
  String manageMetricSessionsValue(int n) {
    return '$n组';
  }

  @override
  String get manageDreaming => '深度思考与提炼中...';

  @override
  String get manageTriggerEvolution => '🌙 立即触发记忆潜意识进化';

  @override
  String get manageSystemCapabilityTitle => '系统与能力';

  @override
  String get manageSystemCapabilityHint => '改动立刻生效；通知与日历的授权随时可调整。';

  @override
  String get manageSystemCapabilityHintSimple => '通知与日历的授权随时可改；其余能力切到进阶模式后展开。';

  @override
  String get manageHistoryTitle => '历史记录与智能归类';

  @override
  String get manageHistorySubtitle => '查阅按时间轴与话题树分布的所有原始对话记忆';

  @override
  String get manageToolsTitle => '技能库与本地工具 (MCP)';

  @override
  String get manageToolsSubtitle => '管理本地系统工具权限，挂载自定义 Webhook 与 Prompt';

  @override
  String get manageProfileTitle => '主人绝密档案与人际网';

  @override
  String get manageProfileSubtitle => '查阅并手动修改智能体为您建立的隐私认知画像';

  @override
  String get manageShutdownTitle => '强制安全停机与退出系统';

  @override
  String get manageShutdownSubtitle =>
      '当底层网络锁死或硬件卡顿异常时，点击此按钮强行释放所有端口、硬件锁，并关闭 App 以便安全重启。';

  @override
  String get manageShutdownDialogTitle => '🚨 警告：系统强制停机';

  @override
  String get manageShutdownDialogBody =>
      '此操作将强行终止所有后台雷达扫描、释放端口并退出应用，以恢复系统到初始纯净状态。是否继续？';

  @override
  String get manageForceQuit => '强制关闭';

  @override
  String get serendipityTitle => '✨ 转运实验室';

  @override
  String serendipityEnergyBadge(int n) {
    return '🔋 $n Lp ';
  }

  @override
  String get serendipityTabMorning => '🌅预演';

  @override
  String get serendipityTabChallenge => '🧭破圈';

  @override
  String get serendipityTabAlchemist => '🧪炼金';

  @override
  String get serendipityTabNight => '🌌手记';

  @override
  String get serendipityTabDiary => '📖日记';

  @override
  String get serendipityTabOracle => '🔮预测';

  @override
  String serendipityEnergyGained(int n) {
    return '✨ +$n Lp (好运能量已注入)';
  }

  @override
  String get serendipityNetworkError => '网络波动，请稍后再试。';

  @override
  String get serendipityBlindBox1 => '红衣服法则：留意穿红衣服的人，观察巧合。';

  @override
  String get serendipityBlindBox2 => '新路径打破：尝试一条没走过的回家路线。';

  @override
  String get serendipityBlindBox3 => '盲盒点餐：让老板为你随机推荐一道菜。';

  @override
  String get serendipityBlindBox4 => '微光接触：向遇到的第一个陌生人真诚微笑。';

  @override
  String get serendipityBlindBox5 => '无功利问候：给很久没联系的老友发句问候。';

  @override
  String get serendipityBlindBox6 => '断网试炼：关闭网络半小时，细致观察周围。';

  @override
  String get serendipityMorningHeader => '预期重构 · 晨间预演';

  @override
  String get serendipityIntentLock => '🎯 意图锁定';

  @override
  String get serendipityEventHint => '即将面对的事件 (如: 下午的会议)';

  @override
  String get serendipityTimerPrompt1 => '闭上双眼，深呼吸，想象那个场景...';

  @override
  String get serendipityTimerPrompt2 => '对焦细节：周围的光线、对方的表情...';

  @override
  String get serendipityTimerPrompt3 => '想象出现了一个小意外，而你轻松化解了它...';

  @override
  String get serendipityTimerPrompt4 => '感受成功完成的松弛感，准备睁眼...';

  @override
  String get serendipityGiveUp => '放弃预演';

  @override
  String get serendipityNeedEvent => '⚠️ 先输入事件！';

  @override
  String get serendipityStartPreview => '开启 2 分钟心智预演';

  @override
  String serendipityTargetEvent(String text) {
    return '🎯 目标事件: $text';
  }

  @override
  String get serendipityDetailHint => '👀 画面细节 (看到了什么？)';

  @override
  String get serendipityObstacleHint => '🛡️ 阻碍化解 (如何从容应对意外？)';

  @override
  String get serendipityOutcomeHint => '🌟 预期结果 (最期待的结局)';

  @override
  String serendipityAiBoost(String text) {
    return '🧠 AI强化:\n$text';
  }

  @override
  String get serendipityAiInjecting => 'AI 注入能量...';

  @override
  String get serendipityReinforce => '🧠 强化';

  @override
  String get serendipitySave5 => '保存 (+5)';

  @override
  String get serendipityMorningArchive => '预演档案';

  @override
  String serendipityLogTime(String t) {
    return '📅 $t';
  }

  @override
  String serendipityLogEvent(String t) {
    return '🎯 事件: $t';
  }

  @override
  String serendipityLogDetail(String t) {
    return '👀 细节: $t';
  }

  @override
  String serendipityLogOutcome(String t) {
    return '🌟 预期: $t';
  }

  @override
  String serendipityLogAiBoost(String t) {
    return '💡 AI赋能:\n$t';
  }

  @override
  String get serendipityChallengeHeader => '机会感知 · 破圈雷达';

  @override
  String get serendipityActionTypeLabel => '选择行动类型';

  @override
  String get serendipityChallengeTypeBlindBox => '🎁 盲盒挑战';

  @override
  String get serendipityChallengeTypeCustom => '自定义';

  @override
  String get serendipityCustomChallengeHint => '🎯 自定义挑战内容';

  @override
  String get serendipityBlindBoxDrawn => '🎉 为您抽取的今日随机盲盒任务：';

  @override
  String get serendipityRedraw => '↺ 有点难？点击重新抽取';

  @override
  String get serendipityJourneyHint => '🚶‍♂️ 真实经过';

  @override
  String get serendipityReflectHint => '📝 点评与收获';

  @override
  String get serendipityAiAnalyzing => 'AI 分析中...';

  @override
  String serendipityAiColon(String text) {
    return '🧠 AI: $text';
  }

  @override
  String get serendipityComment => '🧠 点评';

  @override
  String get serendipitySave15 => '保存 (+15)';

  @override
  String get serendipityChallengeArchive => '历史行动';

  @override
  String serendipityLogGoal(String t) {
    return '🎯 目标: $t';
  }

  @override
  String serendipityLogJourney(String t) {
    return '🚶‍♂️ 经过: $t';
  }

  @override
  String serendipityLogReflect(String t) {
    return '📝 反思: $t';
  }

  @override
  String serendipityLogAiComment(String t) {
    return '💡 AI点评: $t';
  }

  @override
  String get serendipityAlchemistHeader => '坏运转化 · 叙事炼金';

  @override
  String get serendipitySetbackHint => '1. 挫折';

  @override
  String get serendipityNegReactHint => '2. 消极应对';

  @override
  String get serendipityStrategyLabel => '3. 重构策略';

  @override
  String get serendipityStrategyDownward => '向下对比法';

  @override
  String get serendipityStrategySurplus => '寻找盈余法';

  @override
  String get serendipityStrategyDilate => '时空拉长法';

  @override
  String get serendipityNewCognitionHint => '4. 新认知与执行';

  @override
  String get serendipityScore => '🧠 评分';

  @override
  String get serendipitySave10 => '保存 (+10)';

  @override
  String get serendipityAlchemistArchive => '转运档案';

  @override
  String serendipityLogSetback(String t) {
    return '❌ 挫折: $t';
  }

  @override
  String serendipityLogReact(String t) {
    return '😔 应对: $t';
  }

  @override
  String serendipityLogStrategy(String t) {
    return '🛡️ 策略: $t';
  }

  @override
  String serendipityLogCognition(String t) {
    return '💫 认知: $t';
  }

  @override
  String serendipityLogAiScore(String t) {
    return '💡 AI评分: $t';
  }

  @override
  String get serendipityNightHeader => '直觉感知 · 微光手记';

  @override
  String get serendipityIntuitionHint => '1. 预感/直觉';

  @override
  String get serendipityChoiceHint => '2. 做出选择';

  @override
  String get serendipityReflectStrategyHint => '3. 反思策略';

  @override
  String get serendipityParse => '🧠 解析';

  @override
  String get serendipityNightArchive => '潜意识档案';

  @override
  String serendipityLogIntuition(String t) {
    return '🔮 直觉: $t';
  }

  @override
  String serendipityLogChoice(String t) {
    return '👉 选择: $t';
  }

  @override
  String serendipityLogNightReflect(String t) {
    return '🌱 反思: $t';
  }

  @override
  String serendipityLogAiParse(String t) {
    return '💡 AI解析: $t';
  }

  @override
  String get serendipityIntuitionCameTrue => '✅ 直觉已成真';

  @override
  String get serendipityVerifyTrue => '🎯 验证成真 (+20Lp)';

  @override
  String get serendipityDiaryHeader => '情感倾听 · 自由日记';

  @override
  String get serendipityDiaryHint => '✍️ 写下经历、心情、琐事...';

  @override
  String serendipityAiListen(String text) {
    return '🧠 AI导师倾听:\n$text';
  }

  @override
  String get serendipityAiReading => 'AI 导师阅读中...';

  @override
  String get serendipityListen => '🧠 倾听';

  @override
  String get serendipityKeep => '珍藏 (+5 Lp)';

  @override
  String get serendipityDiaryArchive => '时光胶囊';

  @override
  String serendipityLogDiaryTime(String t) {
    return '📅 时间: $t';
  }

  @override
  String serendipityLogDiaryEcho(String t) {
    return '💡 导师回音:\n$t';
  }

  @override
  String get serendipityOracleHeader => '易经决断 · 预测起卦';

  @override
  String get serendipityOracleEventHint => '☯ 请输入近期令你纠结、需要决断之事';

  @override
  String get serendipityEnterRitual => '进入起卦仪式';

  @override
  String get serendipityOracleTapPrompt => '凝神静气，在心中默念所问之事\n请缓缓点击下方太极 6 次，以求六爻';

  @override
  String serendipityOracleResultPrefix(String name) {
    return '🔮 占得：\n$name';
  }

  @override
  String get serendipityOracleThinking => 'AI 焚香解卦中，请稍候...';

  @override
  String get serendipityOracleAskHint => '输入你的追问或疑惑...';

  @override
  String get serendipityNewQuestion => '↺ 问别的事 (重新起卦)';

  @override
  String get serendipityOracleArchive => '预测档案';

  @override
  String serendipityOracleLogEvent(String t) {
    return '🎯 问事: $t';
  }

  @override
  String serendipityOracleLogGua(String t) {
    return '🔮 卦象: $t';
  }

  @override
  String get serendipitySpeakerMe => '我';

  @override
  String get helpSerendipityMorningTitle => '心智预演';

  @override
  String get helpSerendipityMorningBody =>
      '每天清晨，用两分钟锁死今天的好运预期。写下你期待发生的好事，设定倒计时保持专注，完成后用积极心理学强化这份信念。';

  @override
  String get helpSerendipityChallengeTitle => '打破惯性';

  @override
  String get helpSerendipityChallengeBody =>
      '幸运不是玄学，而是行为模式。每天主动做一次打破惯性的小行动——换条路回家、主动搭话陌生人，然后在这里记录你的挑战与反思。';

  @override
  String get helpSerendipityAlchemistTitle => '坏运炼金';

  @override
  String get helpSerendipityAlchemistBody =>
      '把糟糕的经历转化为成长养料。写下坏事、你的本能反应，再用 CBT 视角重新解读，把「坏运气」炼成「心理韧性」。';

  @override
  String get helpSerendipityNightTitle => '夜之手记';

  @override
  String get helpSerendipityNightBody =>
      '睡前捕捉一闪而过的直觉。记录那个「我总觉得该……」的念头，做出选择，日后回看直觉是否灵验，训练你的幸运直觉力。';

  @override
  String get helpSerendipityDiaryTitle => '自由日记';

  @override
  String get helpSerendipityDiaryBody =>
      '想到什么写什么。这里是你的私人树洞，AI 会陪你梳理情绪，不评判、不泄密。';

  @override
  String get helpSerendipityOracleTitle => '玄学预测';

  @override
  String get helpSerendipityOracleBody =>
      '心有所惑，就来问卦。静心默念你的问题，轻触法器六下起卦，让《易经》与心理学为你指路。';

  @override
  String get socialRadarTitle => '小荒社区';

  @override
  String get socialDelegationEntry => '托办与我的圈';

  @override
  String get socialDbDegradedHint => '本地数据暂时读不到（本地库可能还没就绪）。下面显示的内容可能不是最新。';

  @override
  String get socialTabMask => '外交假面';

  @override
  String get socialTabRadar => '雷达状态';

  @override
  String get socialTabLedger => '日志';

  @override
  String get socialTabRoster => '捕获名册';

  @override
  String get socialFeedBrain => '⚡ 正在将雷达数据喂给主大脑，强制触发社交决策...';

  @override
  String get socialMaskLocked => '🛡️ 假面已锁定！旧社交记忆已清空，防人设混淆生效。';

  @override
  String get socialManualPairTitle => '手动强制配对';

  @override
  String get socialPeerAgentName => '对方 Agent 名字';

  @override
  String get socialPeerMasterName => '对方的主人名字 (备注)';

  @override
  String get socialPeerHardId => '对方的硬核 ID';

  @override
  String get socialPair => '配对';

  @override
  String get socialNodeAdded => '✅ 节点添加成功！';

  @override
  String socialForceSendTitle(String name) {
    return '强制发信：$name';
  }

  @override
  String get socialForceSendLabel => '你要直接发给对方的话';

  @override
  String get socialForceSendHint => '输入内容直接无修饰发送...';

  @override
  String get socialDirectSent => '已突破屏障，正在将您输入的话原样发送...';

  @override
  String get socialDirectSend => '免审发射';

  @override
  String socialGiftSent(String gift) {
    return '$gift 已送出';
  }

  @override
  String get socialGiftFailed => '礼物发送失败：对方不在任何在线通道';

  @override
  String get socialRecoSent => '🤝 已发出推荐信请求';

  @override
  String get socialRecoFailed => '请求发送失败：对方不在任何在线通道';

  @override
  String socialVerifyTitle(String name) {
    return '🔐 身份核验：$name';
  }

  @override
  String get socialVerifyPinnedFor => '本机为此节点固定的身份指纹（TOFU）：';

  @override
  String get socialVerifyNoPin => '尚未近场握手，无固定身份';

  @override
  String socialVerifyMyFingerprint(String fp) {
    return '我的指纹（对方屏幕应显示）：$fp';
  }

  @override
  String get socialVerifyInputLabel => '输入对方屏幕上的 8 位指纹';

  @override
  String get socialVerifyMatch => '✅ 指纹一致——这条连接的身份可信。';

  @override
  String get socialVerifyMismatch =>
      '❌ 指纹不一致！当前链路疑似存在中间人。\n建议：立即删除拉黑该节点，换用当面/其他可信渠道重新握手。';

  @override
  String get socialVerifyHintNoPin => '提示：双方都开启雷达完成一次近场握手后，这里才会出现可核验的固定身份。';

  @override
  String get socialVerifyCompare => '比对';

  @override
  String get socialFederationNoIdentity => '尚未生成智能体身份，请先在外交假面页保存';

  @override
  String get socialFederationFetching => '🌐 正在拉取 A2A 联邦名册...';

  @override
  String socialFederationEmpty(String err) {
    return '名册为空：$err';
  }

  @override
  String get socialFederationEmptyErr => 'Hub 上暂无其他注册 Agent（或未配置 Hub 地址）';

  @override
  String socialFederationAllKnown(int n) {
    return 'Hub 上的 Agent 都已在你的名册中（共 $n 个）';
  }

  @override
  String socialFederationTitle(int n) {
    return '🌐 联邦名册（$n 个未收录）';
  }

  @override
  String get socialAnonAgent => '匿名Agent';

  @override
  String socialFederationLastSeen(String id, String time) {
    return '$id · 上次活跃 $time';
  }

  @override
  String get socialFederationDiscovered => 'A2A 联邦发现';

  @override
  String get socialFederationSource => 'A2A 联邦';

  @override
  String get socialFederationMask => '联邦名册发现，等待安全握手';

  @override
  String get socialSourceManual => '手动添加';

  @override
  String get socialNoSignatureBadge => '暂无签名';

  @override
  String get socialCollect => '收录';

  @override
  String socialFederationCollected(int n) {
    return '✅ 已收录 $n 个联邦 Agent 到陌生档；开启雷达后将按安全机制逐步握手。';
  }

  @override
  String get socialFederationAutoTitle => '自动拉取联邦名册';

  @override
  String get socialFederationAutoDesc =>
      '开启后，分身会自动把中转站上公开的已注册 Agent 名册收进你的陌生档。它绝不自动发消息 —— 搭讪仍走审查网关卡、观察模式与预算闸。默认关闭。';

  @override
  String socialFederationAutoDone(int n) {
    return '🌐 已自动收录 $n 个新联邦 Agent 到陌生档。';
  }

  @override
  String get socialFederationAutoNone => '联邦名册里暂时没有可收录的新面孔。';

  @override
  String socialFederationAutoFailed(String err) {
    return '自动拉取失败：$err';
  }

  @override
  String socialFederationAutoClear(int n) {
    return '清空联邦自动收录（$n）';
  }

  @override
  String get socialFederationAutoClearTitle => '清空联邦自动收录？';

  @override
  String socialFederationAutoClearConfirm(int n) {
    return '将移除 $n 个由机器自动拉取、且尚未开始任何交往的 Agent。你自己手动收录的条目不会被碰。';
  }

  @override
  String socialFederationAutoCleared(int n) {
    return '已移除 $n 个联邦自动收录项。';
  }

  @override
  String get socialFederationAutoNote => '由联邦名册自动收录';

  @override
  String get socialDone => '完成';

  @override
  String socialCountdown(String t) {
    return '🔐 倒计时 $t';
  }

  @override
  String get socialBadgeSent => '已发信';

  @override
  String get socialBadgeReviewing => '待审中';

  @override
  String get socialBadgeChatting => '畅聊中';

  @override
  String get socialBadgeBlocked => '被拦截';

  @override
  String get socialPresenceOnline => '⚡本人在线';

  @override
  String socialPeerSubtitle(
      String master, String status, String id, String rep) {
    return '主: $master | 状态: $status\nID: $id · 信誉 $rep';
  }

  @override
  String get socialStatusOnline => '在线';

  @override
  String get socialStatusOffline => '失联';

  @override
  String get socialMenuChat => '💬 和 TA 的分身私聊（1:1）';

  @override
  String get socialChatTooltip => '打开与 TA 分身的 1:1 私聊';

  @override
  String get socialChatHint => '点卡片或 💬 按钮即可 1:1 私聊';

  @override
  String get socialMenuDelegate => '🙋 托他办点事 (M2)';

  @override
  String get socialMenuIntercard => '🤝 分身互介 (M3)';

  @override
  String get socialMenuGreet => '💬 主人强行发信 (免审)';

  @override
  String get socialMenuGift => '🎁 赠送礼物';

  @override
  String get socialMenuReco => '🤝 索取推荐信';

  @override
  String get socialMenuVerify => '🔐 身份指纹核验 (防中间人)';

  @override
  String get socialMenuFamily => '升级为家人 (免审)';

  @override
  String get socialMenuFriend => '设置为好友 (全自动脱敏)';

  @override
  String get socialMenuStranger => '降级为陌生人 (严控主动社交)';

  @override
  String get socialMenuDelete => '删除拉黑';

  @override
  String get socialMaskUndefined => '未定义假面';

  @override
  String get socialMaskNoSignature => '「未设定公开人设签名」';

  @override
  String socialHardId(String id) {
    return '本机硬核 ID: $id';
  }

  @override
  String socialFingerprintLine(String fp) {
    return '身份指纹: $fp（供对方当面比对）';
  }

  @override
  String get socialGatewayGuard => '物理隔离网关守卫中';

  @override
  String get socialLogicPreset => '分身逻辑预设模式';

  @override
  String get socialModeCasual => '☕ 日常闲聊模式 (随性/幽默)';

  @override
  String get socialModeBusiness => '💼 商务猎手模式 (直接/高效)';

  @override
  String get socialModeDating => '💖 交友寻缘模式 (高情商/破冰)';

  @override
  String get socialModeEmergency => '🚨 紧急求助模式 (SOS广播)';

  @override
  String get socialModeCustom => '🛠️ 完全自定义 (遵循任务框)';

  @override
  String socialModeSwitched(String mode) {
    return '🧠 人格模式已切换至 $mode。同一身份，仅换语气（记忆与握手保持不变）。';
  }

  @override
  String get roomRoleParticipant => '参与者';

  @override
  String get roomRoleHost => '主持人';

  @override
  String get roomRoleCohost => '联合主持';

  @override
  String get roomRoleGuest => '嘉宾';

  @override
  String get roomRoleNpc => '功能角色';

  @override
  String get roomRoleManageTitle => '房间角色';

  @override
  String roomRoleMine(String role) {
    return '我的角色：$role';
  }

  @override
  String get roomRoleNoMembers => '本房间还没有观测到其他成员。';

  @override
  String get roomRoleClaimHost => '认领主持人';

  @override
  String get roomRoleClaimedHost => '你已成为本房间主持人。';

  @override
  String get roomRoleClaimHostExists => '本房间已有主持人。';

  @override
  String get roomRoleNotHost => '只有主持人可以授予角色。';

  @override
  String get roomRoleLastHostBlocked => '不能撤掉房间里最后一个主持人。';

  @override
  String roomRoleSetTo(String role) {
    return '已设为 $role';
  }

  @override
  String get socialEmojiLabel => '表情';

  @override
  String get socialNicknameLabel => '对外昵称';

  @override
  String get socialMaskProfileLabel => '对外的脱敏人设签名';

  @override
  String get socialIcebreakTask => '🎯 智能体当前破冰任务 (暗网机密)';

  @override
  String get socialIcebreakHint => '在这里给智能体下达近场刺探的密令...';

  @override
  String get socialLockMask => '💾 锁定假面与密令';

  @override
  String get socialTaskReroll => '换一个';

  @override
  String get socialHeartbeatOn =>
      '💓 双模并发心跳中 (蓝牙 + Wi-Fi NSD)\n后台休眠锁已启动，息屏也能防断开！';

  @override
  String get socialRadarIdle => '雷达休眠中，点击中心开启限时社交';

  @override
  String get socialDurationLabel => '社交限时: ';

  @override
  String get socialDuration15 => '15 分钟';

  @override
  String get socialDuration30 => '30 分钟';

  @override
  String get socialDuration60 => '1 小时';

  @override
  String get socialDurationUnlimited => '无限制 (耗电)';

  @override
  String get socialChannelConfig => '🛰️ 全局通信信道配置';

  @override
  String get socialChannelNearby => '📡 蓝牙/Wi-Fi 直连雷达 (Nearby)';

  @override
  String get socialChannelLan => '🏡 局域网加密互联 (mDNS)';

  @override
  String get socialChannelCloud => '☁️ 互联网云端中转网络 (全局社交)';

  @override
  String get suggestionInboxTitle => '🙋 待我确认的建议';

  @override
  String get suggestionApprove => '批准并发送';

  @override
  String get suggestionIgnore => '忽略';

  @override
  String get suggestionEmpty => '暂无待确认的建议';

  @override
  String get suggestionToTarget => '发给：';

  @override
  String get suggestionApproved => '已批准并发出';

  @override
  String get suggestionNotSent => '未发出，原因见「社交后台报告」';

  @override
  String get socialLedgerTitle => '🐾 社交日志 · 纯净流水账 (仅主代报告)';

  @override
  String get socialLedgerEmpty => '等待心跳引擎触发...';

  @override
  String get socialRosterTitle => '📇 分级社交圈';

  @override
  String get socialScanning => '2.4GHz / 5GHz 物理频谱监听中...';

  @override
  String get socialScanIdle => '当前信道空闲。请点击首页中心开启能量雷达，智能体代理将自涌现建立近场连接建立通道。';

  @override
  String get socialTierFamily => '👨‍👩‍👧 家人 Agent';

  @override
  String get socialTierFriend => '🤝 好友 Agent';

  @override
  String get socialTierStranger => '👽 陌生 Agent';

  @override
  String get worldUnknownError => '未知错误';

  @override
  String get worldAskTitle => '💬 提问小镇';

  @override
  String get worldAskHint => '想问居民们什么？';

  @override
  String get worldAskTargetLabel => '指定居民（留空 = 提问全镇）';

  @override
  String get worldAskSend => '提问';

  @override
  String get worldAskOk => '📨 已向小镇提问，回答将出现在 GOD 控制室';

  @override
  String get worldInterveneTitle => '⚡ 注入干预';

  @override
  String get worldInterveneBody => '指令将注入小镇的下一步（next step），影响所有居民的后续行为。';

  @override
  String get worldInterveneHint => '例如：镇中心广场举办丰收节';

  @override
  String get worldInterveneSend => '注入';

  @override
  String get worldInterveneOk => '⚡ 干预已注入，将在小镇下一步生效';

  @override
  String get worldStopTitle => '⏹ 停止小镇？';

  @override
  String get worldStopBody => '将停止当前实验的实时执行，居民活动会中断。确认继续？';

  @override
  String get worldStop => '停止';

  @override
  String get worldStopOk => '⏹ 小镇已停止';

  @override
  String worldCmdFailed(String err) {
    return '指令失败：$err';
  }

  @override
  String worldJoined(String name) {
    return '🚪 已加入「$name」';
  }

  @override
  String worldJoinFailed(String err) {
    return '加入失败：$err';
  }

  @override
  String worldLeft(String name) {
    return '👋 已退出「$name」';
  }

  @override
  String worldLeaveFailed(String err) {
    return '退出失败：$err';
  }

  @override
  String get worldCreateRoomTitle => '创建房间';

  @override
  String get worldRoomNameLabel => '房间名称';

  @override
  String get worldTopicLabel => '话题（可选）';

  @override
  String get worldModeFree => '自由聊';

  @override
  String get worldModeTurn => '轮流发言';

  @override
  String get worldCreate => '创建';

  @override
  String get worldCreated => '✨ 房间已创建';

  @override
  String worldCreateFailed(String err) {
    return '创建失败：$err';
  }

  @override
  String get worldNoWorldUrl => '未配置世界地址';

  @override
  String get worldNoIdentity => '尚未生成智能体身份，请先在管理页初始化。';

  @override
  String get worldRoomsHeader => '房间';

  @override
  String get worldCreateRoom => '建房';

  @override
  String get worldNoRooms => '暂无房间。请确认服务器上已启动 world.js，\n或下拉刷新重试。';

  @override
  String get worldGodUnreachable => 'GOD 桥接不可达，请确认电脑上已启动 GOD 与 god-bridge.js';

  @override
  String get worldGodPaused => '⏸ 已暂停';

  @override
  String get worldGodRunning => '▶ 运行中';

  @override
  String worldGodStep(String n) {
    return '第 $n 步';
  }

  @override
  String get worldGodStatusUnknown => '上游状态未知';

  @override
  String get worldGodTitle => 'GOD 控制室';

  @override
  String get worldRefreshStatus => '刷新状态';

  @override
  String worldGodTown(String hyp, String exp) {
    return '小镇：$hyp/$exp';
  }

  @override
  String get worldGodNoExperiment => '未连接实验';

  @override
  String get worldGodResume => '▶️ 继续';

  @override
  String get worldGodResumeOk => '▶️ 小镇已恢复自动运行';

  @override
  String get worldGodPause => '⏸️ 暂停';

  @override
  String get worldGodPauseOk => '⏸️ 小镇时间已暂停';

  @override
  String get worldGodStepBtn => '⏭️ 单步';

  @override
  String get worldGodStepOk => '⏭️ 已推进一步';

  @override
  String get worldGodStopBtn => '⏹️ 停止';

  @override
  String get worldGodAskBtn => '💬 提问小镇';

  @override
  String get worldGodInterveneBtn => '⚡ 注入干预';

  @override
  String worldReportUnavailable(String err) {
    return '🌍 世界日报暂不可用。\n$err';
  }

  @override
  String get worldReportNoServer => '请确认世界服务器地址已配置。';

  @override
  String worldReportTitle(String date) {
    return '世界日报 · $date';
  }

  @override
  String worldReportSummary(String msgs, String agents, String mine) {
    return '今日发言 $msgs 条 · 活跃智能体 $agents 个 · 我方发言 $mine 条';
  }

  @override
  String worldReportRoomLine(String name, String msgs, String mine) {
    return '· $name：$msgs 条（我方 $mine）';
  }

  @override
  String get worldRoomEnter => '进入';

  @override
  String get worldRoomExitTooltip => '退出房间';

  @override
  String get worldRoomJoin => '加入';

  @override
  String get worldSectionOfficial => '官方房间';

  @override
  String get worldSectionMine => '我的房间';

  @override
  String get worldBadgeOfficial => '官方';

  @override
  String get worldBadgeMine => '我建的';

  @override
  String get worldBadgePending => '申请中';

  @override
  String get worldSearchTitle => '🔍 按房间号查找';

  @override
  String get worldSearchHint => '输入房间号（群号）';

  @override
  String get worldSearchBtn => '查找';

  @override
  String worldSearchNotFound(String id) {
    return '没有找到房间号「$id」';
  }

  @override
  String get worldRequestJoin => '申请加入';

  @override
  String get worldRequestNoteLabel => '申请留言（可选）';

  @override
  String get worldRequestSent => '已提交申请，等待房主同意';

  @override
  String worldRequestFailed(String err) {
    return '申请失败：$err';
  }

  @override
  String worldRequestsTitle(String count) {
    return '加入申请（$count）';
  }

  @override
  String get worldRequestsEmpty => '暂无待处理申请';

  @override
  String get worldApprove => '同意';

  @override
  String get worldReject => '拒绝';

  @override
  String worldApproveOk(String name) {
    return '已同意「$name」加入';
  }

  @override
  String worldRejectOk(String name) {
    return '已拒绝「$name」';
  }

  @override
  String worldHandleFailed(String err) {
    return '操作失败：$err';
  }

  @override
  String get worldNeedApproval => '这是个人房间：需先申请，经房主同意后才能进入。';

  @override
  String get worldMyRoomsFull => '你建的房间已达上限（每人可建数量由服务端配置）';

  @override
  String get worldCreatedPrivate => '✨ 房间已创建（个人房：不公开列表，其他人只能凭房间号找到并申请加入）';

  @override
  String worldHistoryWhy(String max, String retained) {
    return '历史从你加入后才开始累积；服务端每房保留最近 $max 条，当前 $retained 条。';
  }

  @override
  String get worldPullHistory => '拉取房间历史';

  @override
  String worldPullHistoryOk(String n) {
    return '已补拉 $n 条历史消息';
  }

  @override
  String get worldPullHistoryNone => '服务端也没有更早的消息了';

  @override
  String worldPullHistoryFailed(String err) {
    return '拉取失败：$err';
  }

  @override
  String get worldRoomChatFree => '自由聊天';

  @override
  String get worldLobbyName => '大荒客厅';

  @override
  String get worldLobbyTopic => '自由聊天，文明发言';

  @override
  String worldRoomSubtitle(String mode, String present, String count) {
    return '$mode · 在场 $present · 订阅 $count';
  }

  @override
  String worldRoomTopicSuffix(String topic) {
    return ' · $topic';
  }

  @override
  String get worldAutoreplyOn => '🤖 托管发言已开启：智能体将在预算内自动回话（观察日志持续记录）';

  @override
  String get worldAutoreplyOff => '👁️ 已回到纯观察模式';

  @override
  String get worldDrafting => '🪄 正在按人设起草并送审，请稍候…';

  @override
  String worldSendFailed(String err) {
    return '发送失败：$err';
  }

  @override
  String get worldRoomTurnSuffix => '（轮流发言）';

  @override
  String get worldAutopilotTooltip => '让分身说一句';

  @override
  String get worldAutopilotLabel => '托管';

  @override
  String get worldAutopilotStateOn => '托管中';

  @override
  String get worldAutopilotStateOff => '仅观察';

  @override
  String worldAutopilotStatus(String state, String decision) {
    return '$state · 最近决策：$decision';
  }

  @override
  String get worldRoomEmpty => '房间里还很安静，说点什么吧。';

  @override
  String get worldLoading => '加载中…';

  @override
  String get worldAnonAgent => '匿名Agent';

  @override
  String get worldMe => '我';

  @override
  String get worldSuggestionTooltip => '生成建议卡';

  @override
  String get worldSuggestionTitle => '🧭 建议卡（草稿，未发送）';

  @override
  String get worldSuggestionDrafting => '正在按人设起草回复...';

  @override
  String get worldSuggestionFailed => '生成失败：请检查大脑引擎配置后重试。';

  @override
  String get worldSuggestionEditHint => '可修改后再发';

  @override
  String get worldSuggestionSend => '发到房间';

  @override
  String get worldSayHint => '以主人的身份直接发言…';

  @override
  String get worldVibrancyHot => '🔥 热闹';

  @override
  String get worldVibrancyWarm => '🌤 正常';

  @override
  String get worldVibrancyCold => '🌙 冷清';

  @override
  String worldVibrancyDetail(String speakers, String messages) {
    return '$speakers 人在聊 · $messages 条';
  }

  @override
  String get worldVibrancyObservedHint => '（条数为本机观测，非服务端精确值）';

  @override
  String get worldBridgeSection => '朋友池互荐';

  @override
  String get worldBridgeNone => '本房间暂无圈外人可互荐（同圈或已相识者不重复推荐）。';

  @override
  String worldBridgeCount(String count) {
    return '$count 位圈外人可互荐';
  }

  @override
  String worldBridgeSharedRooms(String count) {
    return '共同 $count 个房间';
  }

  @override
  String worldBridgeMsgCount(String count) {
    return '$count 条发言';
  }

  @override
  String get worldBridgeRecommend => '建议互介';

  @override
  String get worldBridgeTooltip => '建议互介（跨圈）';

  @override
  String get worldBridgeSameCircle => '同圈';

  @override
  String get worldBridgeAlreadyLinked => '已相识';

  @override
  String worldBridgeWhyLine(String detail) {
    return '凭什么推荐：$detail';
  }

  @override
  String worldBridgeRoomProvenance(String room) {
    return '因「$room」相识';
  }

  @override
  String worldBridgeCircleLine(String circle) {
    return '以「$circle」的名义互介';
  }

  @override
  String get worldBridgeNoCircle => '你还没有自己的圈 —— 先入场进圈，再发起跨圈互介。';

  @override
  String worldBridgeLinkCreated(String room) {
    return '✅ 已建立跨圈边：因「$room」认识了他';
  }

  @override
  String get worldBridgeLinkFailed => '建立跨圈边失败，请稍后重试。';

  @override
  String get worldBridgeBlockedTitle => '无法建立跨圈边';

  @override
  String get worldBridgeBlockedNotInRoom =>
      '这个人没有在该房间出现过 —— 跨圈边必须有房间出处，不能凭一个 ID 就宣称认识。';

  @override
  String get worldBridgeBlockedSameCircle => '你们已在同一个圈里，圈内本来就有边，无需跨圈互介。';

  @override
  String get worldBridgeBlockedAlreadyLinked =>
      '你们已经相识（互介 / 委托 / 通讯录），走既有关系即可，不占跨圈边的名额。';

  @override
  String get worldBridgeBlockedSelf => '不能和自己互介。';

  @override
  String get worldBridgeBlockedNoRoom => '缺少房间出处，无法建立跨圈边。';

  @override
  String get worldBridgeBlockedDuplicate => '这条跨圈边已经存在（幂等，不重复记账）。';

  @override
  String get worldMetricTitle => '跨圈连接';

  @override
  String worldMetricLine(String links, String known, String perCapita) {
    return '我建过 $links 条跨圈边 · 接触过 $known 个分身 · 人均 $perCapita';
  }

  @override
  String get worldMetricNoData => '暂无跨圈数据 —— 先在世界房间里遇到圈外人。';

  @override
  String get privacyOnlyHumanTitle => '只接受真人消息';

  @override
  String get privacyOnlyHumanSubtitle => '开启后，对方分身只能把消息转达给你，不能替你回复。';

  @override
  String get privacyLocalFirst => '默认情况下，你的数据留在本机。';

  @override
  String get delegationTitle => '托办';

  @override
  String get delegationTabInbox => '托我办';

  @override
  String get delegationTabOutbox => '我托的';

  @override
  String get delegationTabCircle => '我的圈';

  @override
  String get delegationEmptyInbox => '还没有人托你的分身办事。';

  @override
  String get delegationEmptyOutbox => '你还没有发起过托办。';

  @override
  String get delegationNew => '发起托办';

  @override
  String get delegationTo => '托给谁';

  @override
  String get delegationTaskHint => '例如：帮我问下老王周末有没有空';

  @override
  String get delegationSent => '已下达，等对方分身回执。';

  @override
  String get delegationOfflineQueued => '已存在本机。现在没有任何一条通道能触达对方，等通道打通再送。';

  @override
  String get delegationAskResponse => '要带回去的话（可留空）';

  @override
  String get delegationActDone => '办好了';

  @override
  String get delegationActNeedsHuman => '需本人确认';

  @override
  String get delegationActRespond => '回应';

  @override
  String get delegationActDecline => '拒绝';

  @override
  String get delegationRevoke => '撤销';

  @override
  String get delegationRevoked => '已撤销';

  @override
  String get delegationRevokeConfirm => '撤销这条托办？会留痕为「已撤销」。';

  @override
  String get delegationStatePending => '待回执';

  @override
  String get delegationStateAnswered => '已回执';

  @override
  String get delegationStateNeedsHuman => '需本人确认';

  @override
  String get delegationStateDeclined => '已拒绝';

  @override
  String get delegationStateRevoked => '已撤销';

  @override
  String get delegationBlockedTitle => '这条分身不能代发';

  @override
  String get delegationBlockedBody => '分身不在用户之间转钱——这是设计上就没有金额字段，不是没填。请你自己发这一句。';

  @override
  String get delegationEmptyTask => '先写清楚要托办什么。';

  @override
  String get delegationNoPeer => '先选一个要托的对象。';

  @override
  String get circleTitle => '我的圈';

  @override
  String get circleCreate => '建一个圈';

  @override
  String get circleNameHint => '例如：周六足球、里斯本同城';

  @override
  String get circleCreated => '圈已建好。';

  @override
  String get circleInviteCode => '邀请码';

  @override
  String get circleGenerateInvite => '生成邀请码';

  @override
  String get circleJoin => '用邀请码入圈';

  @override
  String get circleJoinHint => '粘贴对方给你的邀请码';

  @override
  String get circleJoined => '已入圈。';

  @override
  String get circleJoinFailed => '邀请码无效或已过期。';

  @override
  String circleVisibleSummary(int n, int m) {
    return '可见 $n 个分身 · 其中 $m 个不是邀请者';
  }

  @override
  String get circleAcceptancePass => '验收通过（需 ≥3 个可见，且 ≥2 个非邀请者）';

  @override
  String get circleAcceptanceFail => '尚未达标——再邀请几个邻居吧';

  @override
  String circleFallbackNote(int n, String src) {
    return '其中 $n 个来自兜底（$src）—— 不是圈内成员';
  }

  @override
  String circleMemberCount(int n) {
    return '$n 位成员';
  }

  @override
  String get telemetryCounts => '埋点计数（验收自检）';

  @override
  String get telemetryEmpty => '还没有埋点数据。';

  @override
  String get dashboardTitle => '看板';

  @override
  String get dashboardFunnelTitle => '每周漏斗';

  @override
  String get dashboardColWeek => '周';

  @override
  String get dashboardColOnboarding => '接入';

  @override
  String get dashboardColCircle => '进圈';

  @override
  String get dashboardColDelegation => '委托完成';

  @override
  String get dashboardColIntercard => '互介';

  @override
  String get dashboardColHandshake => '握手';

  @override
  String get dashboardColActive => '活跃';

  @override
  String get dashboardTtfd => 'TTFD 中位数';

  @override
  String get dashboardDelta => '披露代价 Δ';

  @override
  String get dashboardDeltaHint => '不披露组回复率 − 披露组回复率（Phase −1）。';

  @override
  String get dashboardNoData => '还没有埋点数据——先跑一会儿 App。';

  @override
  String get dashboardSourceHint => '来源：本机埋点（仅本设备）。';

  @override
  String get digestTitle => '今日摘要';

  @override
  String get digestEmpty => '过去 24 小时没有新动态。';

  @override
  String get digestSectionPending => '等你回执';

  @override
  String get digestSectionMine => '我托的';

  @override
  String get digestSectionCircle => '圈子';

  @override
  String get digestSectionStats => '数一数';

  @override
  String get digestStatDone => '条托办办妥';

  @override
  String get digestStatHandshake => '次真人握手';

  @override
  String get digestActionOpenInbox => '去回执';

  @override
  String get digestActionOpenOutbox => '看我托的';

  @override
  String get digestActionOpenCircle => '看我的圈';

  @override
  String get digestActionOpenDashboard => '看看板';

  @override
  String get digestNotePlain => '你被分到「纯摘要」组（A/B 实验）。';

  @override
  String get digestNoteAction => '你被分到「带动作」组（A/B 实验）。';

  @override
  String get morningGreetingMorning => '早安';

  @override
  String get morningGreetingNoon => '午安';

  @override
  String get morningGreetingEvening => '晚上好';

  @override
  String get morningGreetingBody => '这是你最近三天的小结：';

  @override
  String morningHiPending(int count) {
    return '$count 件委托等你回执';
  }

  @override
  String morningHiSent(int count) {
    return '你托出了 $count 件事';
  }

  @override
  String morningHiCircle(int count) {
    return '新加入了 $count 个圈子';
  }

  @override
  String morningHiTopics(String topics) {
    return '常聊：$topics';
  }

  @override
  String morningHiLongTerm(String topics) {
    return '长期关注：$topics';
  }

  @override
  String get morningEmpty => '最近三天很安静，好好享受今天。';

  @override
  String get notifyMorningTitle => '早安，这是你的三日回顾';

  @override
  String get notifyMorningBody => '分身帮你整理了最近三天的事。';

  @override
  String notifyMorningBodyPending(int count) {
    return '你有 $count 件委托待回执，分身帮你整理了最近三天的事。';
  }

  @override
  String get digestSectionChat => '你和分身的对话';

  @override
  String digestChatSummary(int sessions, int turns, int days) {
    return '$sessions 段对话 · $turns 轮 · 跨 $days 天';
  }

  @override
  String digestChatTopics(String topics) {
    return '常聊：$topics';
  }

  @override
  String get intercardDialogTitle => '分身互介卡';

  @override
  String get intercardReasonLabel => '为什么值得认识';

  @override
  String get intercardTopicsLabel => '3 个可聊话题（逗号分隔）';

  @override
  String get intercardConfirmSend => '确认并发送';

  @override
  String get intercardReceivedTitle => '收到的互介卡';

  @override
  String get intercardMineTitle => '我发出的互介卡';

  @override
  String get intercardBlockedTitle => '这张卡被拦下';

  @override
  String get intercardBlockedL3 => '检测到仅本人可见的值出现在卡文本里。';

  @override
  String get intercardEmptyContent => '先写为什么值得认识和话题。';

  @override
  String get intercardSentOk => '已发出（24h 内可撤回）。';

  @override
  String get intercardRevoke => '撤回';

  @override
  String get intercardNone => '还没有互介卡。';

  @override
  String get intercardRevoked => '已撤回。';

  @override
  String get intercardRevokeHint => '已发出 · 24h 内可撤回。';

  @override
  String get intercardSent => '已发出。';

  @override
  String intercardFrom(String owner) {
    return '$owner 的主人签名介绍。';
  }

  @override
  String get deviceControlTitle => '手机控制';

  @override
  String get deviceControlRefreshStatus => '刷新状态';

  @override
  String get deviceControlUnsupported => '当前构建不支持手机控制';

  @override
  String get deviceControlServiceConnected => '无障碍服务：已连接';

  @override
  String get deviceControlServiceCheckedNotConnected => '无障碍服务：已勾选，但未连接';

  @override
  String get deviceControlServiceOff => '无障碍服务：未开启';

  @override
  String get deviceControlStatusUnknown => '状态未知';

  @override
  String get deviceControlGoSystemHint => '请在系统列表里找到「大荒AI」并打开开关，然后回到这里刷新';

  @override
  String get deviceControlGoSettings => '去系统设置开启';

  @override
  String get deviceControlRedetect => '重新检测';

  @override
  String get deviceControlRedetectTip =>
      '提示：如果反复检测都连不上，请到系统设置里把「大荒AI 屏幕助手」关掉再打开一次，或重启一次 App——部分手机会在后台清理时断开无障碍服务。';

  @override
  String get deviceControlAllowTitle => '允许智能体操作手机';

  @override
  String get deviceControlAllowSubReady => '开启后，智能体可以读屏、点击、输入、打开应用；首次使用会向你确认一次';

  @override
  String get deviceControlAllowSubChecked => '系统里已勾选，但服务还没连上：先点上方「重新检测」';

  @override
  String get deviceControlAllowSubNeedService => '需要先开启系统无障碍服务，这个开关才可用';

  @override
  String get deviceControlToolsHeader => '开启后会挂载这些能力';

  @override
  String get deviceControlToolReadScreen => '读取屏幕上显示的文字与可点元素';

  @override
  String get deviceControlToolTap => '按文字或坐标点击';

  @override
  String get deviceControlToolInput => '在输入框里打字';

  @override
  String get deviceControlToolSwipe => '滑动翻页、滚动列表';

  @override
  String get deviceControlToolPressKey => '返回 / 主页 / 最近任务 / 回车';

  @override
  String get deviceControlToolOpenApp => '打开指定应用（包名）';

  @override
  String get deviceControlDenylistTitle => '敏感应用黑名单';

  @override
  String get deviceControlDenylistBody =>
      '这些应用在前台时，智能体不会执行任何操作（银行、支付、密码管理器、系统设置）。一行一个包名，也支持逗号分隔。';

  @override
  String get deviceControlSaveDenylist => '保存黑名单';

  @override
  String get deviceControlResetDefault => '恢复默认';

  @override
  String get deviceControlFooter =>
      '说明：手机控制基于安卓无障碍服务，不需要 root，也不需要额外插件。\n· 关掉上面的开关，相关工具会立刻从智能体手里撤销；\n· 每个动作都会写进审计记录，可在「管理设置」里回看；\n· 智能体永远不会对你没有授权的应用动手。';

  @override
  String get deviceControlToastNeedAccessibility => '请先在系统设置里开启「大荒AI」的无障碍服务';

  @override
  String get deviceControlToastOn => '手机控制已开启：首次使用时仍会向你确认一次';

  @override
  String get deviceControlToastOff => '手机控制已关闭，相关工具已撤销';

  @override
  String deviceControlToastSaved(String n) {
    return '黑名单已保存（共 $n 条）';
  }

  @override
  String get deviceControlToastReset => '已恢复默认黑名单';

  @override
  String get contactDefaultAgentName => '野生 Agent';

  @override
  String get contactDefaultMasterName => '物理探测';

  @override
  String get contactDefaultNotes => '暂无备注';

  @override
  String get contactSendingThroughGateway => '⚡ 正在穿透网关直接发送...';

  @override
  String get contactEditTitle => '修改智能体名册备注';

  @override
  String get contactEditAgentLabel => '智能体昵称';

  @override
  String get contactEditMasterLabel => '主人身份备注';

  @override
  String get contactEditNotesLabel => '档案小秘密';

  @override
  String get contactEditConfirm => '确认同步';

  @override
  String get contactEditSaved => '✅ 捕获名册备注已锁定同步！';

  @override
  String get contactRequestReco => '索取推荐信';

  @override
  String get contactSendGift => '赠送礼物';

  @override
  String contactGiftSent(String gift) {
    return '$gift 已送出，等待对方签收';
  }

  @override
  String get contactGiftFailed => '礼物发送失败：对方不在线或未在任何通道';

  @override
  String get contactRecoRequested => '🤝 已发出推荐信请求，对方将按其本地信誉决定是否签发';

  @override
  String get contactRecoFailed => '请求发送失败：对方不在任何在线通道';

  @override
  String get contactTierBlockToast => '信誉过低，建议在捕获名册中直接“删除拉黑”该节点';

  @override
  String contactTierAdjusted(String tier) {
    return '✅ 已按信誉建议调整为 $tier';
  }

  @override
  String get contactTierFriend => '可升级为好友';

  @override
  String get contactTierFamily => '可升级为家人';

  @override
  String get contactTierStranger => '建议降级为陌生人';

  @override
  String get contactTierBlock => '建议拉黑';

  @override
  String get contactStatusLocked => '雷达已锁定';

  @override
  String get contactStatusSent => '等待回应';

  @override
  String get contactStatusReceived => '等待主代审核';

  @override
  String get contactStatusAccepted => '畅聊中';

  @override
  String get contactStatusRejected => '已物理拦截';

  @override
  String contactOwnerLine(String name) {
    return '主人: $name';
  }

  @override
  String get contactOnline => '在线';

  @override
  String get contactOutOfRange => '超出范围';

  @override
  String contactReputation(String score) {
    return '📊 信誉 $score';
  }

  @override
  String contactGiftStats(String sent, String received) {
    return '🎁 送$sent/收$received';
  }

  @override
  String get contactTierBlockBanner => '⚠️ 信誉过低，建议拉黑（点击查看）';

  @override
  String contactTierHintBanner(String suggestion) {
    return '💡 信誉建议：$suggestion（点击应用）';
  }

  @override
  String contactNotesLine(String notes) {
    return '📝 备注档案：$notes';
  }

  @override
  String get contactEmptyChat => '暂无对话。\n下方输入直接与对方对话！';

  @override
  String get contactSayHint => '强制搭话，输入内容...';

  @override
  String get dshImportTitle => '从 DSH 生态导入';

  @override
  String get dshImportClipboardEmpty => '剪贴板是空的';

  @override
  String get dshImportNoFileContent => '没有读到文件内容，请换一种方式选择';

  @override
  String dshImportPickFailed(String err) {
    return '选择文件失败：$err';
  }

  @override
  String get dshImportPasteSkillFirst => '请先粘贴 SKILL.md 的内容';

  @override
  String get dshImportIntroTitle => '借力整个 DSH 生态';

  @override
  String get dshImportIntroBody =>
      'DSH 的插件是 TypeScript 写的，手机上不能直接跑；\n但其中的技能、MCP 服务可以原样搬过来用。\n\n为安全起见：导入的插件一律默认关闭，且带设备签名校验，必须由你手动开启后才会生效。';

  @override
  String get dshImportSecSkillTitle => '① 导入技能（SKILL.md）';

  @override
  String get dshImportSecSkillSub =>
      '纯文本技能可以 100% 直译，是 DSH 生态里最好搬的部分。粘贴一份内容，或一次选择多个 .md 文件。';

  @override
  String get dshImportSkillHint =>
      '粘贴 SKILL.md 全文（含 --- 头部的 name / description）';

  @override
  String get dshImportPaste => '粘贴';

  @override
  String get dshImportPickFiles => '选择文件';

  @override
  String get dshImportImport => '导入';

  @override
  String get dshImportSecMcpTitle => '② 导入 MCP 服务';

  @override
  String get dshImportSecMcpSub =>
      'MCP 是通用协议，不依赖语言，填地址就能直连。支持粘贴 dsh / Claude 风格的 mcpServers 配置。';

  @override
  String dshImportMcpHint(String example) {
    return '例如 $example\n也可以只粘一个 https:// 地址';
  }

  @override
  String get dshImportSecInspectTitle => '③ 插件包体检';

  @override
  String get dshImportSecInspectSub =>
      '拿到一个 DSH 插件包，先体检再决定要不要折腾。粘贴包里的 package.json（必需）和 cordis.patch.yml（可选）。';

  @override
  String get dshImportPackageJsonHint => '粘贴 package.json 全文';

  @override
  String get dshImportPatchHint => '粘贴 cordis.patch.yml 全文（可选）';

  @override
  String get dshImportPastePackageJson => '粘贴 package.json';

  @override
  String get dshImportStartInspect => '开始体检';

  @override
  String get dshImportGoToolCenter => '去技能控制中心开启刚导入的插件';

  @override
  String dshImportSummaryImportedOk(String n) {
    return '成功导入 $n 项';
  }

  @override
  String dshImportSummarySkipped(String n) {
    return '，跳过 $n 项';
  }

  @override
  String get dshImportListSeparator => '、';

  @override
  String dshImportImportedLine(String names) {
    return '✅ $names';
  }

  @override
  String dshImportSkippedLine(String name, String reason) {
    return '⚠️ $name：$reason';
  }

  @override
  String dshImportNoteLine(String note) {
    return 'ℹ️ $note';
  }

  @override
  String get dshSkipDuplicateSkill => '已有同名技能，未覆盖';

  @override
  String get dshSkipDuplicateMcp => '已有同名 MCP 配置，未覆盖';

  @override
  String get dshSkipInvalidJson => '这段内容不是合法 JSON，也不是网址';

  @override
  String get dshSkipCommandLineMcp =>
      '这是命令行型 MCP（需要在本机启动进程），手机上跑不了；请改用 HTTP 地址';

  @override
  String get dshSkipNoUrlField => '这条配置里找不到 url 字段';

  @override
  String get dshSkipMissingNameUrl => '缺少 name 或 url';

  @override
  String get dshSkipUnrecognizedJson => '无法识别的 JSON 结构';

  @override
  String get dshSkipInvalidScheme => '地址必须以 http:// 或 https:// 开头';

  @override
  String get dshSkipSubjectConfig => '配置';

  @override
  String get dshSkipSubjectConfigParseFailed => '配置解析失败';

  @override
  String get dshSkipSubjectUnnamedEntry => '未命名条目';

  @override
  String get dshNoteSkillDefaultsOff =>
      '导入的技能默认关闭，请到「技能控制中心」按需开启；开启后它会影响智能体的说话方式与行为准则。';

  @override
  String get dshNoteMcpDefaultsOff =>
      '导入的 MCP 服务默认关闭。开启并首次使用时，系统会提示授予「网络访问」能力，授权后才会真正连接。';

  @override
  String get dshNotePasteMcpFirst => '请先粘贴 MCP 配置或地址';

  @override
  String dshInspectErrPackageFormat(String msg) {
    return '❌ package.json 解析失败：$msg';
  }

  @override
  String dshInspectErrPackageNotJson(String msg) {
    return '❌ package.json 不是合法 JSON：$msg';
  }

  @override
  String dshInspectErrPatchFormat(String msg) {
    return '❌ cordis.patch.yml 解析失败：$msg';
  }

  @override
  String dshInspectPackageLine(String name) {
    return '插件包：$name';
  }

  @override
  String dshInspectBundleLine(String path) {
    return '组合文件：$path';
  }

  @override
  String dshInspectProfileBundlesLine(String list) {
    return '依赖组合包：$list';
  }

  @override
  String get dshInspectNoPatchHint =>
      'ℹ️ 没有提供 cordis.patch.yml，只能看到包的基本信息。把插件包里的该文件内容也粘进来，才能判断哪些能搬到手机上。';

  @override
  String dshInspectRowCountLine(String n) {
    return '共 $n 个插件行，体检结果：';
  }

  @override
  String dshInspectGroupLine(String verdict, String n) {
    return '【$verdict】 共 $n 行';
  }

  @override
  String dshInspectMoreRowsLine(String n) {
    return '  · …另有 $n 行';
  }

  @override
  String dshInspectConclusionLine(String skill, String mcp, String heavy) {
    return '结论：可直接导入 $skill 行技能 + $mcp 行 MCP；$heavy 行属于「必须在 Dart 侧重写或依赖桌面环境」，本机无法直接运行。';
  }

  @override
  String get dshInspectVerdictDirectSkill => '✅ 可直接导入（技能）';

  @override
  String get dshInspectVerdictMcpServer => '✅ 可直接连接（MCP 服务）';

  @override
  String get dshInspectVerdictConfigOnly => '⚙️ 仅配置项（无需移植）';

  @override
  String get dshInspectVerdictPlatformGated => '🖥️ 依赖桌面环境（手机上不可用）';

  @override
  String get dshInspectVerdictNeedsDart => '🧱 需要 Dart 侧重写（含 TS 代码）';

  @override
  String get chatCleared => '🧹 已清空工作区与 LLM 记忆，开启新会话！';

  @override
  String get chatImageOptionsTitle => '发送图像或视觉内容';

  @override
  String get chatTakePhoto => '拍摄照片';

  @override
  String get chatPickFromAlbum => '相册选择';

  @override
  String get chatAudioOptionsTitle => '发送音频或录音';

  @override
  String get chatStartRecording => '开始录音';

  @override
  String get chatLocalAudio => '本地音频';

  @override
  String chatOpenCameraFailed(String err) {
    return '打开相机失败：$err';
  }

  @override
  String chatOpenAlbumFailed(String err) {
    return '打开相册失败：$err';
  }

  @override
  String chatPickAudioFailed(String err) {
    return '选择音频文件失败：$err';
  }

  @override
  String get chatNoMicPermission => '没有麦克风权限：请在系统设置里允许「录音」权限后重试';

  @override
  String chatStartRecordingFailed(String err) {
    return '开始录音失败：$err';
  }

  @override
  String get chatWelcomeBack => '欢迎回来，主人！';

  @override
  String get chatAgentReady => 'AI 管家已就绪，随时待命';

  @override
  String get chatQuickTechTitle => '🔍 今日科技新闻';

  @override
  String get chatQuickTechPrompt => '帮我搜索今天最新的 AI 科技新闻并汇总。';

  @override
  String get chatQuickRadarTitle => '📡 扫描附近的人';

  @override
  String get chatQuickRadarPrompt => '检查物理雷达，周围有什么活跃节点吗？';

  @override
  String get chatQuickProfileTitle => '📝 提炼我的档案';

  @override
  String get chatQuickProfilePrompt => '根据昨天的聊天，我有什么新的喜好被你发现了吗？';

  @override
  String get chatAudioFile => '音频文件';

  @override
  String get chatRecording => '🔴 正在录音...';

  @override
  String get chatInputHint => '给管家发送指令...';

  @override
  String get profileSavedToast => '🔒 主人绝密档案已存盘';

  @override
  String get profileAddPerson => '添加关系人物';

  @override
  String get profileEditPerson => '修改人物信息';

  @override
  String get profileNameLabel => '名字 (例如：小美)';

  @override
  String get profileRelationLabel => '社会关系 (例如：妻子)';

  @override
  String get profileIdentityLabel => '身份备注 (例如：小学老师)';

  @override
  String get profileSecretLabel => '细节秘密 (如: 喜欢草莓)';

  @override
  String get profileSaveVault => '保存并锁入保险箱';

  @override
  String get profileTitle => '主人绝密档案 & 人际网';

  @override
  String get profilePreferenceHeader => '👤 主人偏好设置';

  @override
  String get profileJobLabel => '职业 (Job)';

  @override
  String get profileHobbiesLabel => '喜好特长 (Hobbies)';

  @override
  String get profileDislikesLabel => '忌讳讨厌 (Dislikes)';

  @override
  String get profileOtherLabel => '其他备注 (Other Notes) - 随意写';

  @override
  String get profileSaveBase => '💾 保存基本偏好 (锁入本地库)';

  @override
  String get profileNetworkHeader => '🔗 绝密人物关系网';

  @override
  String get profileAdd => '添加';

  @override
  String get profileNetworkEmpty => '空空如也，点击右上角添加';

  @override
  String profileDetailLine(String notes) {
    return '📝 细节：$notes';
  }

  @override
  String get profileAiReadable => '🔓 AI 已获授权读取此人信息';

  @override
  String get profileAiIsolated => '🔒 AI 已被物理隔离此人信息';

  @override
  String get giftPickerTitle => '🎁 挑一份心意';

  @override
  String get giftNoteLabel => '附一句话（可选）';

  @override
  String get giftNoteHint => '例如：谢谢上次帮忙';

  @override
  String get giftSend => '送出';

  @override
  String get giftNameTea => '一杯茶';

  @override
  String get giftNameBook => '一本书';

  @override
  String get giftNameFlower => '一束花';

  @override
  String get giftNameCake => '一块蛋糕';

  @override
  String get giftNameMysteryBox => '神秘礼盒';

  @override
  String get giftNameStar => '一颗星';

  @override
  String get themeRed => '红';

  @override
  String get themeOrange => '橙';

  @override
  String get themeYellow => '黄';

  @override
  String get themeGreen => '绿';

  @override
  String get themeCyan => '青';

  @override
  String get themeBlue => '蓝';

  @override
  String get themePurple => '紫';

  @override
  String get themeWhite => '白';

  @override
  String get themeBlack => '黑';

  @override
  String get mainClearSession => '清空并新开会话';

  @override
  String get mainNavChat => '日常交流';

  @override
  String get mainNavSocial => '小荒社区';

  @override
  String get mainNavWorld => '大荒世界';

  @override
  String get mainNavSerendipity => '转运实验';

  @override
  String get mainNavManage => '管理设置';

  @override
  String topicChatLogSuffix(String range) {
    return '$range 聊天记录';
  }

  @override
  String get topicArchiveTitle => '智能记忆归档';

  @override
  String get topicTabTimeline => '时间轴 (Timeline)';

  @override
  String get topicTabTopics => '主题树 (Topics)';

  @override
  String get topicEmptyArchive => '暂无归档数据';

  @override
  String get topicNoTag => '无标签';

  @override
  String get topicDailyChat => '日常闲聊';

  @override
  String topicCountLabel(String count) {
    return '$count条';
  }

  @override
  String topicKeywordLine(String keywords) {
    return '🏷️ $keywords';
  }

  @override
  String digestToResponse(String to, String response) {
    return '$to：$response';
  }

  @override
  String get deviceControlStatusReady => '手机控制已就绪：智能体可以读屏、点击、输入';

  @override
  String get deviceControlStatusUnsupportedShort => '当前构建未包含手机控制模块';

  @override
  String get deviceControlStatusUnsupportedFull => '当前构建未包含手机控制模块（需要安卓端无障碍服务）';

  @override
  String get deviceControlStatusCheckedOffline =>
      '系统里已勾选，但服务还没连上。先点右上角刷新；若仍不行，把系统设置里的开关关掉再打开一次（或重启 App）';

  @override
  String get deviceControlStatusOff => '还没有在系统设置里开启无障碍服务';

  @override
  String deviceControlStatusQueryFailed(String err) {
    return '状态查询失败：$err';
  }

  @override
  String deviceControlGuardBlocked(String pkg) {
    return '当前前台应用（$pkg）在安全黑名单里，智能体不会对它执行任何操作。如确实需要，请在「手机控制」设置页里移除该限制。';
  }

  @override
  String commonNetworkError(String err) {
    return '网络异常：$err';
  }

  @override
  String get netFaultLanHijackAdvice =>
      '🤖【智能体自我诊断报告】\n主人，我的大模型连不上网了！\n这通常是因为我们开启了物理雷达（Nearby/局域网），而当前 Wi-Fi 所在的局域网没有外网出口 —— 设备之间能互相发现，却出不了公网，所以我调不了云端大模型。\n\n建议：① 暂时关闭物理雷达；② 或下拉状态栏关掉 Wi-Fi、改走蜂窝数据；③ 或在手机设置里开启「智能切换蜂窝网络」。\n目前我只能保持底层的物理连接监听了。';

  @override
  String netFaultSocialSkipped(String err) {
    return '❌ 连不上云端大模型：网络不可达。若已开启物理雷达，当前 Wi-Fi 的局域网很可能没有外网出口 —— 设备之间能互相发现，但出不了公网。本轮已跳过。\n建议：关闭物理雷达，或关掉 Wi-Fi 改用蜂窝数据后重试。\n原因：$err';
  }

  @override
  String socialPipelineError(String err) {
    return '❌ 社交决策流水线异常，本轮已终止：$err';
  }

  @override
  String netFaultNetworkTrouble(String err) {
    return '❌ 连不上云端大模型（网络异常，不是代码问题）。\n可能是网络正在切换、运营商链路受阻，或当前 Wi-Fi 没有外网出口。\n建议：① 关掉 Wi-Fi 改走蜂窝数据；② 或在手机设置里开启「智能切换蜂窝网络」；③ 稍后重试。\n原因：$err';
  }

  @override
  String get netFaultCooldownSkipped => '⏸ 网络连续故障，已暂停调用大模型（10 分钟内不再重试，避免白烧额度）。';

  @override
  String get worldSvcNoHub => '未配置云端 Hub / 世界地址';

  @override
  String get worldSvcMustBeHttps => '世界地址必须是 HTTPS 或局域网私有地址';

  @override
  String worldSvcRoomsFailed(String code, String body) {
    return '房间列表获取失败：$code $body';
  }

  @override
  String worldSvcOpFailed(String code, String body) {
    return '操作失败($code)：$body';
  }

  @override
  String worldSvcReportFailed(String code) {
    return '日报获取失败：$code';
  }

  @override
  String get godSvcMustBeHttps => 'GOD 地址必须是 HTTPS，或局域网私有地址';

  @override
  String godSvcStatusFailed(String code, String body) {
    return '状态获取失败($code)：$body';
  }

  @override
  String get godSvcNoBridge => '未配置 GOD 桥接地址';

  @override
  String godSvcCmdFailed(String code, String body) {
    return '指令失败($code)：$body';
  }

  @override
  String get passportTitle => '护照与信誉';

  @override
  String get passportEntryTile => '大荒护照';

  @override
  String get passportEntryHint => '可验证签名履历 · 离线可验';

  @override
  String get passportCardHeader => '我的大荒护照';

  @override
  String get passportIssuedLabel => '签发';

  @override
  String get passportCopyAction => '复制身份';

  @override
  String get passportRefreshAction => '刷新';

  @override
  String get passportCopiedToast => '已复制';

  @override
  String passportStatLine(String label, String value) {
    return '$label：$value';
  }

  @override
  String get passportLedgerHeader => '互介履历';

  @override
  String get passportLedgerEmpty => '还没有互介记录。去世界房间认识几个人吧。';

  @override
  String get passportDirectionOut => '我发起';

  @override
  String get passportDirectionIn => '我收到';

  @override
  String get passportPeerLabel => '对方';

  @override
  String get passportTopicLabel => '主题';

  @override
  String get passportRoomLabel => '源于房间';

  @override
  String get passportTrustLabel => '可验证等级';

  @override
  String get passportTrustNone => '未通过验证';

  @override
  String get passportTrustInitiated => '仅发起方已签';

  @override
  String get passportTrustConsented => '双方已互允';

  @override
  String get passportTrustResolved => '已落结果';

  @override
  String get passportTrustAcknowledged => '双方已追认';

  @override
  String get passportOutcomeLabel => '结果';

  @override
  String get passportOutcomeHandshake => '已握手';

  @override
  String get passportOutcomeDeclined => '已拒绝';

  @override
  String get passportOutcomeNoResponse => '无回应';

  @override
  String get passportOutcomeWithdrawn => '已撤回';

  @override
  String get passportVerifyDetails => '验证明细';

  @override
  String get passportChecksLabel => '已通过';

  @override
  String get passportFaultsLabel => '未通过';

  @override
  String get passportConsentAction => '同意这次互介';

  @override
  String get passportConsentDone => '已同意';

  @override
  String get passportResolveAction => '记录结果';

  @override
  String get passportResolveTitle => '这次互介的结果';

  @override
  String get passportAckAction => '追认结果';

  @override
  String get passportAckDone => '已追认';

  @override
  String get passportActionDelivered => '已签名并投递';

  @override
  String get passportActionOffline => '已记账；对方暂时联系不上，稍后会自动补送';

  @override
  String get passportActionRejected => '未生效（时序或身份不符）';

  @override
  String get passportFunnelHeader => '互介 → 握手转化';

  @override
  String get passportFunnelProposedLabel => '发起';

  @override
  String get passportFunnelConsentedLabel => '双方互允';

  @override
  String get passportFunnelHandshakeLabel => '握手';

  @override
  String get passportFunnelSettledLabel => '已落结果';

  @override
  String get passportFunnelInFlightLabel => '在途';

  @override
  String get passportFunnelConsentRateLabel => '互允率';

  @override
  String get passportFunnelConversionLabel => '转化率';

  @override
  String get passportLogHeader => '透明日志';

  @override
  String get passportLogSizeLabel => '当前期号';

  @override
  String get passportLogRootLabel => 'Merkle 根';

  @override
  String get passportLogCopyAction => '复制根';

  @override
  String get passportNewIntroAction => '发起互介';

  @override
  String get passportNewIntroPeerLabel => '对方分身 ID';

  @override
  String get passportNewIntroTopicLabel => '一句话主题';

  @override
  String get passportNewIntroSubmit => '发起';

  @override
  String get passportNewIntroNeedPeer => '请填写对方分身 ID';

  @override
  String get passportNewIntroNoCircle => '你还没有圈子。先入场进圈，互介才有归属。';

  @override
  String passportNewIntroDone(String peer) {
    return '已向 $peer 发起互介并签名';
  }

  @override
  String radarNoticeStarted(int minutes) {
    return '🛡️ 雷达开启，$minutes分钟社交限时派对已开始...';
  }

  @override
  String get radarNoticeStopped => '💤 雷达关闭，社交派对已结束。';

  @override
  String get radarNotifTitle => 'Ai管家 雷达网关全速运行中';

  @override
  String get radarNotifText => '您的数字分身正在后台物理世界为您不间断社交...';

  @override
  String get radarNoticePartyEnded => '⏰ 限时派对时间已到，主智能体已强制拔掉天线！';

  @override
  String get radarNoticeWrappingUp => '⏳ 社交时间不足10分钟，子智能体已准备道别。';

  @override
  String get cloudHubNotConfigured => '未配置云端 Hub 地址';

  @override
  String get cloudKeyRequired => '这个中转站需要访问 Key：请在「高级设置」里填入运营方签发的 Key';

  @override
  String get cloudKeyInvalid => '访问 Key 无效，请核对是否复制完整';

  @override
  String get cloudKeyRevoked => '这个访问 Key 已被停用，请联系中转站运营方';

  @override
  String get cloudKeyBound => '这个 Key 已绑定另一个身份，请换一个 Key（或走身份恢复）';

  @override
  String get cloudAgentRevoked => '本机身份已被中转站停用，无法再收发消息';

  @override
  String get cloudRegisterClosed => '中转站暂停了新用户注册';

  @override
  String get cloudRegisterIdentityConflict =>
      '这个身份 ID 已绑定另一把密钥：请走「身份恢复/换钥」，不要删除身份';

  @override
  String cloudRosterFailed(int status, String body) {
    return '名册获取失败($status): $body';
  }

  @override
  String cloudNetworkError(String error) {
    return '网络异常: $error';
  }

  @override
  String cloudCardFailed(int status) {
    return '名片获取失败($status)';
  }

  @override
  String get identityChangedWarning =>
      '🚨 身份突变：对方公钥与历史固定不一致（疑似中间人/换绑），握手已拒绝并大幅降信。';

  @override
  String get lanTunnelOpen => '⚡ 局域网物理通道(TCP/UDP)已打通！';

  @override
  String get lanTargetLost => '⚠️ Wi-Fi 物理目标脱离范围。';

  @override
  String get p2pBtDisconnected => '⚠️ 蓝牙连接断开。';

  @override
  String repEventLog(String delta, String event, String detail) {
    return '信誉$delta（$event）$detail';
  }

  @override
  String repEventDetailSuffix(String detail) {
    return '：$detail';
  }

  @override
  String repGiftLogIncoming(String gift, String note) {
    return '$gift 来自节点的一份心意$note';
  }

  @override
  String repGiftLogOutgoing(String gift, String note) {
    return '$gift 送给节点的一份心意$note';
  }

  @override
  String repGiftNoteQuoted(String note) {
    return '：“$note”';
  }

  @override
  String repGiftMemoryIncoming(String name, String gift, String note) {
    return '$name 送来礼物 $gift $note';
  }

  @override
  String repGiftMemoryOutgoing(String gift, String name, String note) {
    return '$name 收到了你赠送的礼物 $gift $note';
  }

  @override
  String repGiftMemoryNote(String note) {
    return '（$note）';
  }

  @override
  String repRecoLog(int score, String date) {
    return '🤝 收到推荐信：信誉 $score（$date 签发，已验签）';
  }

  @override
  String repRecoMemory(String issuer, int score, String date) {
    return '收到 $issuer 的推荐信（信誉 $score，$date 签发）';
  }

  @override
  String get repNetHeader => '网络背书';

  @override
  String repNetAnchors(int count, int min) {
    return '$count 个锚点（本地信誉 ≥ $min）';
  }

  @override
  String get repNetMineLabel => '我背书的人';

  @override
  String get repNetForMeLabel => '背书我的人';

  @override
  String get repNetEmpty => '还没有';

  @override
  String get repNetIssueAction => '签发背书';

  @override
  String get repNetIssueTitle => '签一份背书';

  @override
  String get repNetIssueSubjectLabel => '对方的护照 DID 或公钥';

  @override
  String get repNetIssueNeedSubject => '请粘贴对方的 DID（did:wold:…）或公钥';

  @override
  String get repNetIssueBadSubject => '这不是合法的 DID 或公钥';

  @override
  String get repNetIssueTierLabel => '档位';

  @override
  String get repNetIssueNoteLabel => '附言（可选）';

  @override
  String get repNetIssueBindLabel => '他的 Agent ID（可选；填了才把他接进信任网络）';

  @override
  String get repNetTierAcquaintance => '泛泛之交';

  @override
  String get repNetTierFriend => '朋友';

  @override
  String get repNetTierFamily => '家人';

  @override
  String get repNetIssuedToast => '背书已签名并落库';

  @override
  String repNetFailedToast(String code) {
    return '被拒：$code';
  }

  @override
  String get repNetSelfReject => '不能给自己背书';

  @override
  String get repNetExpiresLabel => '有效期至';

  @override
  String get repNetRevokeAction => '收回';

  @override
  String get repNetRevokedToast => '背书已收回';

  @override
  String repNetBoundToast(String id) {
    return '已记住 $id 的公钥';
  }

  @override
  String get repNetVerifyAction => '验签';

  @override
  String get repNetVerifiedToast => '签名有效';

  @override
  String get repNetBadSignatureToast => '签名无效 —— 这份背书被改过';

  @override
  String get repNetQueryLabel => '查一个人';

  @override
  String get repNetQueryAction => '追溯';

  @override
  String repNetQueryKnown(
      String tier, int depth, String confidence, int paths) {
    return '$tier · 距离 $depth 跳 · 置信 $confidence · $paths 条通路';
  }

  @override
  String get repNetQueryUnknown => '没有可验证的通路';

  @override
  String get repNetPathLabel => '证据链（每一跳你都能自己验）';

  @override
  String get repNetPathStart => '你信任';

  @override
  String get repNetPathHop => '→ 他背书';

  @override
  String get repNetStatusRevoked => '已收回';

  @override
  String get repNetStatusExpired => '已过期';

  @override
  String repNetKeysMerged(int count) {
    return '已按换钥链归并 $count 把历史公钥 —— 换钥前收到的背书仍计入。';
  }

  @override
  String get skillMarketTitle => '技能市场';

  @override
  String get skillMarketSubtitle => '上架作者签名技能，查看自己的分成';

  @override
  String get skillRevenueTitle => '作者收益';

  @override
  String skillRevenueTotal(String amount) {
    return '累计收益 $amount';
  }

  @override
  String skillRevenueCount(int count) {
    return '$count 笔分账';
  }

  @override
  String get skillRevenueEmpty => '暂无收益';

  @override
  String get skillNoListings => '注册表里还没有任何技能。';

  @override
  String get skillPublishAction => '上架技能';

  @override
  String get skillPublishTitle => '签名上架技能';

  @override
  String get skillFieldId => '技能 ID';

  @override
  String get skillFieldVersion => '版本号';

  @override
  String get skillFieldName => '名称';

  @override
  String get skillFieldDesc => '描述';

  @override
  String get skillFieldPrice => '价格（元，0 表示免费）';

  @override
  String get skillFieldRisk => '风险等级';

  @override
  String get skillFieldCaps => '能力声明';

  @override
  String get skillFieldContent => '技能内容（将被哈希并签名）';

  @override
  String get skillSubmit => '签名并上架';

  @override
  String get skillNeedFields => '技能 ID、版本号、名称、内容为必填';

  @override
  String get skillRevokeAction => '吊销';

  @override
  String skillRevokeConfirm(String skill) {
    return '吊销 $skill？此操作不可撤销。';
  }

  @override
  String skillPublishedOk(String skill) {
    return '已上架 $skill';
  }

  @override
  String get skillPublishDuplicate => '同版本同内容已上架';

  @override
  String get skillPublishVersionConflict => '同版本内容不同，已拒绝';

  @override
  String get skillPublishAuthorChanged => '该技能 ID 属于其他作者，已拒绝';

  @override
  String get skillPublishVersionNotIncreased => '版本号必须大于已上架版本';

  @override
  String get skillPublishUnverified => '签名无效，已拒绝';

  @override
  String skillRevokedOk(String skill) {
    return '已吊销 $skill';
  }

  @override
  String get skillRevokeRejected => '吊销被拒——你不是该技能的作者公钥';

  @override
  String get skillMineTag => '我的';

  @override
  String get skillFree => '免费';

  @override
  String skillPriceYuan(String amount) {
    return '¥$amount';
  }

  @override
  String get skillAuthorKey => '作者公钥';

  @override
  String get skillRevokedTag => '已吊销';

  @override
  String get skillVerifyAction => '校验签名';

  @override
  String get skillVerifyOk => '签名有效';

  @override
  String skillVerifyFail(String code) {
    return '验签失败：$code';
  }

  @override
  String skillVersionHistory(int count) {
    return '$count 个版本';
  }

  @override
  String runtimeInitFailed(String err) {
    return '本地运行时未能启动，世界、圈子、委托等功能暂不可用，其余功能正常。（$err）';
  }

  @override
  String get idbEntry => '身份备份与恢复';

  @override
  String get idbTitle => '身份备份与恢复';

  @override
  String get idbIntro =>
      '你的身份就是这把钥匙，而它只存在这台手机上。手机丢了，身份就永久灭失 —— 连我们都无法重发。把恢复码抄下来，那是唯一能把它带回来的东西。';

  @override
  String get idbCurrentDid => '当前身份（DID）';

  @override
  String get idbNoScreenshotShort => '切勿截图';

  @override
  String get idbSectionBackup => '备份身份';

  @override
  String get idbWarnNoScreenshot =>
      '⚠️ 恢复码就等于你的身份。请抄写在纸上离线保管；不要截图、不要存网盘、不要发给任何人（包括我们）。';

  @override
  String get idbPwLabel => '恢复口令（至少 10 位）';

  @override
  String get idbPwConfirmLabel => '再输一次口令';

  @override
  String get idbPwMismatch => '两次口令不一致';

  @override
  String get idbPwTooShort => '口令太短（至少 10 位）';

  @override
  String get idbGenerateAction => '生成恢复码';

  @override
  String get idbCodeTitle => '你的恢复码（抄下来）';

  @override
  String get idbCopyCode => '复制恢复码';

  @override
  String get idbCopiedToast => '恢复码已复制 —— 记得随后清空剪贴板';

  @override
  String get idbICopied => '我已抄下，并已离线妥善保管';

  @override
  String get idbNeedCopied => '请先确认你已抄下恢复码';

  @override
  String get idbDoneToast => '身份已备份';

  @override
  String get idbSectionRestore => '换机恢复';

  @override
  String get idbRestoreAction => '恢复身份';

  @override
  String get idbRestoreCodeLabel => '恢复码';

  @override
  String get idbRestoreIdLabel => '用户 ID（AG-…）';

  @override
  String get idbRestorePwLabel => '恢复口令';

  @override
  String get idbRestoreCheckAction => '核对';

  @override
  String get idbRestoreNeedAll => '请填全恢复码、用户 ID 与口令';

  @override
  String get idbRestoreConfirmTitle => '确认这就是你要恢复的身份';

  @override
  String idbRestoreConfirmBody(String did) {
    return '你将恢复为：$did\n\n恢复后本机接管这个身份，旧手机立即失效。';
  }

  @override
  String get idbRestoreConfirmAction => '确认恢复';

  @override
  String get idbRestoreBusy => '正在换钥…';

  @override
  String get idbRestoreOk => '恢复成功。旧手机上的身份已失效，请销毁它的数据。';

  @override
  String idbRestoreFail(String code) {
    return '恢复失败：$code';
  }

  @override
  String get idbErrHubNotConfigured => '尚未配置 Hub 地址，无法完成换钥。请先在「世界」设置里填写服务器地址。';

  @override
  String get idbErrIdMismatch => '用户 ID 与恢复码里的身份不一致 —— 请检查是不是拿错了备份。';

  @override
  String get idbErrBadPassword => '口令不对，或恢复码被改动过。';

  @override
  String get idbErrBadFormat => '恢复码格式不对（请完整复制，别漏段）。';

  @override
  String get idbErrNotCurrentKey => '该身份的当前密钥已经不是这把了 —— 它可能已经被换过钥。';

  @override
  String get idbRestoreUnavailable => '本地身份尚未就绪，暂时无法备份 / 恢复。';

  @override
  String get idbStatusBackedUp => '身份已备份';

  @override
  String get idbStatusBackedUpHint => '当前这把钥的恢复码已抄下。日后用它恢复时，这台设备会当场失效。';

  @override
  String get idbStatusNotBackedUp => '身份未备份';

  @override
  String get idbStatusNotBackedUpHint =>
      '手机一旦丢失或损坏，身份与全部履历将永久消失 —— 包括我们在内，没有任何人能替你重发。';

  @override
  String get arcSectionTitle => '导出本地数据';

  @override
  String get arcExportAction => '导出本地数据';

  @override
  String get arcExportNote => '为这份归档设一个口令。它不必与恢复码的口令相同 —— 不同反而更好。';

  @override
  String get arcSavedTitle => '归档已生成';

  @override
  String get arcSavedPath => '已保存到：';

  @override
  String get arcSavedNoPath => '没能写入文件（没有存储权限），但内容可以直接复制。';

  @override
  String get arcSavedHint => '文件与口令请分开保管。没有口令，这个文件谁也打不开 —— 我们也不行。';

  @override
  String get arcImportAction => '导入';

  @override
  String get arcImportNote =>
      '选择 .dahuang 文件，或直接粘贴内容。在你确认之前不会写入任何东西；导入只增不减，绝不覆盖或删除已有记录。';

  @override
  String get arcPickFile => '选择文件';

  @override
  String get arcImportCodeLabel => '归档内容';

  @override
  String get arcImportConfirmTitle => '确认导入这份归档？';

  @override
  String arcImportConfirmBody(int rows, int tables, int logsize) {
    return '将写入 $rows 行、涉及 $tables 张表，并把日志接续到第 $logsize 片。已有记录保留。';
  }

  @override
  String arcImportOk(int count) {
    return '导入完成：写入 $count 行。';
  }

  @override
  String get arcErrNotArchive => '这不是一份有效的 .dahuang 归档。';

  @override
  String get arcLogConflictTitle => '已拒绝导入：日志接不上';

  @override
  String get arcLogConflictBody =>
      '本机透明日志与归档里的日志对不上，硬接会让哈希链静默断裂（断了一节，后面每一节仍然自洽）。本次未写入任何内容。请把归档导入到日志为空的新设备，或寻求协助。';

  @override
  String get onbBackupTitle => '备份你的身份';

  @override
  String get onbBackupSubtitle => '一串抄在纸上的恢复码 —— 手机坏掉时，它是唯一的退路。';

  @override
  String get onbBackupWhyTitle => '为什么要紧';

  @override
  String get onbBackupWhy =>
      '你的身份是自证的：私钥只在这台手机上。手机一旦坏掉，身份与它名下的全部记录将永久消失 —— 我们无法重发，因为我们从来就没有这把钥。';

  @override
  String get onbBackupDone => '恢复码已抄下 —— 你有退路了。';

  @override
  String get onbSkipBackup => '暂不备份';

  @override
  String get onbSkipWarnTitle => '确定不备份就继续？';

  @override
  String get onbSkipWarnBody =>
      '没有恢复码，一旦丢失这台手机，你的身份、履历与信誉将永久失去，没有任何人能帮你找回。之后仍可在「护照 → 身份备份」里补做，但在那之前，你没有退路。';

  @override
  String get onbSkipConfirm => '我明白，继续';

  @override
  String get onboardingStepBackup => '备份身份';

  @override
  String get rcTitle => '换钥链';

  @override
  String get rcIntro =>
      '这个身份每换一次手机，就会在这里留下一条有签名、只追加的记录。任何人都能取到同一份数据自行核对 —— 不需要任何账号。';

  @override
  String get rcFetching => '正在取回…';

  @override
  String get rcRefreshAction => '刷新';

  @override
  String rcFetchFail(String reason) {
    return '取回失败：$reason';
  }

  @override
  String get rcUnknownIdentity => 'Hub 不认识这个身份。';

  @override
  String get rcNoRotations => '这个身份从未换过钥。';

  @override
  String get rcSubjectTitle => '身份';

  @override
  String get rcAgentLabel => 'User ID';

  @override
  String get rcDidLabel => 'DID（身份锚）';

  @override
  String get rcCurrentKey => '当前活跃公钥';

  @override
  String get rcRegisteredYes => '已在 Hub 注册';

  @override
  String get rcRegisteredNo => '没有注册记录';

  @override
  String get rcLocalVerifyAction => '我自己核对';

  @override
  String get rcVerifyingAction => '正在核对…';

  @override
  String get rcVerdictOk => '通过：每条记录的签名都有效，链首尾相接，末端正是 Hub 列为活跃的那把钥。';

  @override
  String rcVerdictSigInvalid(int n) {
    return '不通过：有 $n 条记录的签名对不上。';
  }

  @override
  String get rcVerdictLinkMismatch => '不通过：链断了 —— 有一条记录接不上前一条。';

  @override
  String get rcVerdictTipNotActive =>
      '不通过：末条记录并没有指向 Hub 列为活跃的那把钥，说明这份清单里漏了一次换钥。';

  @override
  String get rcVerdictTitle => '我自己的核对';

  @override
  String get rcHubClaimTitle => 'Hub 自己的说法';

  @override
  String get rcHubClaimOk => 'Hub 报告：全库链无断裂。';

  @override
  String rcHubClaimBroken(int n) {
    return 'Hub 报告：有 $n 个身份的链是断的。';
  }

  @override
  String get rcRecordsTitle => '记录';

  @override
  String rcRecordSeq(int i) {
    return '第 $i 条';
  }

  @override
  String get rcRecordFrom => '被退休的钥';

  @override
  String get rcRecordTo => '接管的新钥';

  @override
  String get rcRecordSigOk => '签名有效';

  @override
  String get rcRecordSigBad => '签名无效';

  @override
  String get rcAnchorTitle => '已锚定进公开日志';

  @override
  String rcAnchorNote(int size, String root) {
    return '日志长度 $size，Merkle 根 $root。记住这个根，日后就能证明这份清单没有被改写。';
  }

  @override
  String get dmTitle => '换到新手机';

  @override
  String get dmIntro =>
      '你的身份是一把只存在手机上的钥匙。把它搬过去，意味着用旧钥把身份签交给新机上的一把新钥 —— 之后旧钥在所有地方都失效。';

  @override
  String get dmRoleNewTitle => '这是新手机';

  @override
  String get dmRoleNewBody => '从这里开始。本机会请老机把身份交过来。';

  @override
  String get dmRoleNewAction => '开始';

  @override
  String get dmRoleOldTitle => '这是老手机';

  @override
  String get dmRoleOldBody => '在这里等。新机来要时，会给你一个要比对的短码。';

  @override
  String get dmRoleOldAction => '等待请求';

  @override
  String get dmWaitingPeer => '正在等待另一台手机…';

  @override
  String get dmPeerFound => '另一台手机已应答。';

  @override
  String get dmCompareTitle => '比对这两串短码';

  @override
  String get dmCompareBody =>
      '两台手机必须显示完全一样的短码。这个短码把两把钥和这次请求都绑在一起，所以中间只要有人动过任何一个字段，短码就会不一样。';

  @override
  String get dmCodeMatchAction => '两串一致';

  @override
  String get dmCodeNoMatchAction => '两串不一致';

  @override
  String get dmNoKeyLeaves => '私钥从不离开任何一台手机。交接由老机自己签名完成，不存在“复制”这件事。';

  @override
  String get dmConfirmAction => '确认并迁移';

  @override
  String get dmOldConfirmTitle => '把这个身份交出去？';

  @override
  String get dmOldConfirmBody => '这将把身份签交给新手机。之后本机会被登出，本机这把钥将失效。';

  @override
  String get dmGapATitle => '履历已随你迁移';

  @override
  String get dmGapABody =>
      '你在网络上收到的背书会跟着身份走 —— 换钥退休的是钥，不是你。在新机上恢复之后，旧钥名下的背书会被自动取回，并逐条在本地验签。旧钥依然彻底失效：它再也签不动任何东西。';

  @override
  String get dmBackupReminderTitle => '你有恢复码吗？';

  @override
  String get dmBackupReminderBody =>
      '这次迁移需要两台手机同时在场。如果你抄过恢复码，也可以不依赖老机，直接从恢复码恢复。';

  @override
  String get dmPhaseOffered => '已收到请求，等你在老机确认。';

  @override
  String get dmPhaseSigned => '已签名，正在提交给 Hub…';

  @override
  String get dmPhaseAwaitingHub => 'Hub 正在改绑身份…';

  @override
  String get dmDoneNew => '完成。身份已在这台手机上。';

  @override
  String get dmDoneOld => '完成。本机已登出。';

  @override
  String get dmDoneOldHint =>
      '身份已经搬走，但这台手机上的聊天记录与数据不会跟着走（直迁只搬身份，不搬数据）。想留着就先导出归档，再决定要不要清空。';

  @override
  String get dmCancelAction => '取消';

  @override
  String get dmCancelled => '已取消，什么也没改动。';

  @override
  String get dmCancelConfirmTitle => '要中止吗？';

  @override
  String get dmCancelConfirmBody => '目前还没有交接完成。现在中止，两台手机都保持原样。';

  @override
  String get dmErrPeerMismatch => '那个请求不是冲着本机身份的，已拒绝。';

  @override
  String get dmErrBadCode => '短码不一致。没有交出任何东西。';

  @override
  String dmErrHubFailed(String code) {
    return 'Hub 拒绝了这次交接（$code）。什么都没改动。';
  }

  @override
  String get dmErrTimeout => '另一台手机没有响应。什么都没改动。';

  @override
  String dmErrGeneric(String code) {
    return '出错了（$code）。';
  }

  @override
  String get dmRetryAction => '重试';

  @override
  String get dmRetryApplyAction => '完成本机安装';

  @override
  String get dmErrSessionTimeout => '这次交接放得太久，已经作废。什么都没交出，可以重新开始。';

  @override
  String get dmErrApplyFailed =>
      'Hub 已经把这台手机设为该身份的唯一持有者，但本机没能把新钥装好。请点下面的按钮完成这一步 —— 在此之前，这台手机还用不了这个身份。';

  @override
  String get dmErrApplyFailedOld =>
      '服务器上已经改绑到新手机，但那台手机没能把新钥装好。请在那台手机上点「完成本机安装」；在那之前，本机也不能再用这个身份。';

  @override
  String get dmNotConfigured => '还没有设置 Hub 地址，无法改绑身份。请先到「设置」里填上。';

  @override
  String get dutyAskTitle => '让分身息屏后继续值班吗？';

  @override
  String get dutyAskBody =>
      '授予这两项权限后，息屏时分身也会定时醒来：收发消息、补发公示、处理社交，然后继续睡。屏幕上会保留一条「值班中」通知，让你随时知道它在工作。选择跳过也不影响 App 内的任何功能，只是退到后台后可能被系统暂停。';

  @override
  String get dutyAskConfirm => '去授权';

  @override
  String get dutyAskLater => '暂不';

  @override
  String get radarAskTitle => '开启雷达前，先说明它会用到什么';

  @override
  String get radarAskBody =>
      '物理雷达靠「附近设备」（蓝牙 / Wi-Fi 直连）在同一个 Wi-Fi 里互相发现。安卓把蓝牙扫描归在「定位」权限名下 —— 系统框里会一并要定位，这是系统的规定，不是本 App 想要你的位置。\n\n本 App 不读取、不存储、不上传任何位置信息；「附近设备」权限在声明里已带 neverForLocation（系统层面切断了「用蓝牙反推位置」这条路）。\n\n接下来会弹出系统权限框。拒绝也不影响 App 的其他功能，只是雷达扫不到人。';

  @override
  String get dutyDoneToast => '值班权限已就绪。息屏后分身也能继续工作。';

  @override
  String get dutyPartialToast => '部分权限未授予。App 内功能不受影响，但退到后台后可能被系统暂停。';

  @override
  String get romGuideTitle => '让分身息屏后不被系统拦下';

  @override
  String get romGuideGo => '去设置';

  @override
  String get romGuideDismiss => '不再提醒';

  @override
  String get romStepsXiaomi =>
      '小米/红米（MIUI/HyperOS）：1）设置 → 应用设置 → 应用管理 → 大荒AI → 打开「自启动」；2）安全中心 → 省电策略 → 大荒AI 改为「无限制」。缺这两步，息屏几分钟内分身就会被系统收走。';

  @override
  String get romStepsHuawei =>
      '华为（EMUI/HarmonyOS）：设置 → 应用 → 应用启动管理 → 大荒AI → 关闭「自动管理」，把「允许自启动 / 关联启动 / 后台活动」三个开关全部打开。';

  @override
  String get romStepsHonor =>
      '荣耀（MagicOS）：设置 → 应用 → 应用启动管理 → 大荒AI → 关闭「自动管理」，手动打开自启动、关联启动、后台活动。';

  @override
  String get romStepsOppo =>
      'OPPO/realme（ColorOS）：设置 → 应用 → 应用管理 → 大荒AI → 允许「自启动」；设置 → 电池 → 更多设置 → 允许大荒AI 完全后台行为。';

  @override
  String get romStepsOneplus =>
      '一加：设置 → 应用 → 自启动管理 → 允许大荒AI；电池 → 大荒AI 的电池优化改为「不优化」。';

  @override
  String get romStepsVivo =>
      'vivo/iQOO（OriginOS）：设置 → 应用与权限 → 权限管理 → 自启动，允许大荒AI；设置 → 电池 → 后台耗电管理 → 允许大荒AI 后台高耗电。';

  @override
  String get romStepsMeizu => '魅族（Flyme）：手机管家 → 应用权限 → 后台管理 → 允许大荒AI 保活运行。';

  @override
  String get romStepsSamsung =>
      '三星（One UI）：设置 → 电池 → 后台使用限制 → 把大荒AI 移出「深度睡眠」列表。';

  @override
  String get romStepsGeneric => '如果你的系统会积极清理后台，请在系统设置中允许大荒AI 自启动，并将它移出电池优化名单。';

  @override
  String get helpDotTooltip => '查看用法说明';

  @override
  String get helpSheetClose => '知道了';

  @override
  String get helpWorldOverviewTitle => '会客厅怎么玩';

  @override
  String get helpWorldOverviewBody =>
      '官方房人人可进；个人房只出现在房主和成员的列表里——别人要凭房间号找到它、申请、等房主同意。进房后每条消息按房间节奏发送（默认 8 秒一条），撞上节奏会被服务端拒绝并让你稍等。';

  @override
  String get helpWorldMetricTitle => '人均跨圈连接';

  @override
  String get helpWorldMetricBody =>
      '本机口径：分子＝我的跨圈边数，分母＝我接触过的不同分身数。全平台人均需服务端汇总，服务端刻意不携带圈子关系。';

  @override
  String get helpWorldBridgeTitle => '朋友池互荐';

  @override
  String get helpWorldBridgeBody =>
      '房间里遇到的圈外人，可一键互介。跨圈边只从房间长出——不在房间里认识，就不会有这条边。';

  @override
  String get helpWorldRoomRoleTitle => '房间角色';

  @override
  String get helpWorldRoomRoleBody => '角色属于房间，不改变你的身份。同一个你，在不同房间可以是不同角色。';

  @override
  String get helpIntercardDisclosureTitle => '卡片上会公开什么';

  @override
  String get helpIntercardDisclosureBody =>
      '只有第二级字段会上卡；仅本人可见的字段永不出现。任何人都能复算这张卡的内容。';

  @override
  String get helpPassportOverviewTitle => '通行证是什么';

  @override
  String get helpPassportOverviewBody =>
      '你的通行证是一把公钥，不是账号：它可离线验证，不需要向任何服务器登录。换手机靠恢复码或换钥匙，而不是靠平台找回。';

  @override
  String get helpPassportOfflineTitle => '离线也能验';

  @override
  String get helpPassportOfflineBody => '公钥即身份：这份身份可离线验证，不需要联网查询任何服务器。';

  @override
  String get helpPassportFunnelTitle => '漏斗的分母怎么算';

  @override
  String get helpPassportFunnelBody => '分母只算已落结果的条数，在途不算失败；且只有验过双方互允的记录才进分母。';

  @override
  String get helpPassportReputationTitle => '为什么没有全网信誉分';

  @override
  String get helpPassportReputationBody =>
      '全网信誉分天然可刷，所以这里没有。你看到的永远相对于你自己的锚点：别人签名的背书，按距离衰减。\\n\\n泛泛之交不做信任传播的起点 —— 否则批量加好友就能放大自己的传播能力。\\n\\n查不到时显示的是「不知道」，这不是 0 分：真的不知道，任何把它说成一个数字的人都是在猜。';

  @override
  String get helpPassportLogTitle => '透明日志';

  @override
  String get helpPassportLogBody => '你不必相信我，你可以验我：任何人都能下载日志、复算根、检查自己的记录有没有被篡改。';

  @override
  String get helpSocialOverviewTitle => '社交页能做什么';

  @override
  String get helpSocialOverviewBody =>
      '上方是名册与好友，下方是雷达状态与社交日志。雷达控制消息出不出手：雷达关着时，点了发送也不会离开这台手机。';

  @override
  String get helpSocialPersonaTierTitle => '专门人格模式';

  @override
  String get helpSocialPersonaTierBody => '标锁的是专门人格模式。计费尚未上线，当前所有模式都可以自由切换。';

  @override
  String get helpSocialRadarTitle => '雷达与通道';

  @override
  String get helpSocialRadarBody =>
      '雷达未开启时仍能浏览名册，但消息不会离手——点了发送也发不出去。请先开启雷达，并至少打开一个通道（近场 / 局域网 / 云端）。\\n\\n「可核验的固定身份」要等双方都开启雷达、并完成一次近场握手之后才会出现。';

  @override
  String get helpSocialChannelGuideTitle => '通信信道与网络排障';

  @override
  String get helpSocialChannelGuideBody =>
      '① 开启物理雷达时，请确保当前网络能正常上网。\n② 开启「近场」通道后，系统可能会自动点亮 Wi-Fi——这是近场传输提速的正常行为（蓝牙负责发现，Wi-Fi 直连负责传数据，不会加入任何网络），关闭近场通道后就不会再自动打开。\n③ 出门在外想省电：只开「云端」通道并手动关闭 Wi-Fi 即可（近场开着时系统会重新点亮 Wi-Fi，属正常现象，不必反复手动关闭）。';

  @override
  String get socialRadarOffHint =>
      '⚠️ 雷达未开启：现在仍能浏览名册，但消息不会离手——点了发送也发不出去。请先开启雷达，并至少打开一个通道（近场 / 局域网 / 云端）。';

  @override
  String get worldRoomCloseAction => '关闭房间';

  @override
  String get worldRoomCloseTitle => '关闭这个房间？';

  @override
  String get worldRoomCloseBody =>
      '关闭后房间会退出公开列表，且不再接受新发言；已有的聊天记录会作为只读留档保留，已加入的人仍可回看。';

  @override
  String get worldRoomCloseConfirm => '确认关闭';

  @override
  String worldRoomClosedOk(String name) {
    return '已关闭「$name」，转为只读留档';
  }

  @override
  String worldRoomCloseFailed(String err) {
    return '关闭失败：$err';
  }

  @override
  String get worldRoomClosedBadge => '已关闭';

  @override
  String get worldRoomClosedReadonlyHint => '房间已关闭 · 只读留档，不再接受新发言';

  @override
  String get worldRoomClosedSendRejected => '房间已关闭，无法发言';

  @override
  String get worldRoomClosedSystemMsg => '房间已被房主关闭，转为只读留档。';

  @override
  String get settingsLocalModelSection => '本地模型兜底（离线降级）';

  @override
  String get settingsLocalModelTest => '测试本地模型连接';

  @override
  String get settingsLocalModelTesting => '正在测试…';

  @override
  String settingsLocalModelTestOk(String model, String url) {
    return '✅ 已连通：$model @ $url';
  }

  @override
  String get settingsLocalModelTestDisabled => '本地兜底已关闭（地址为空）。想用就填一个地址再测。';

  @override
  String settingsLocalModelTestUnreachable(String url) {
    return '❌ 连不上 $url：那儿没有服务在听（或端口不通）。手机上的 127.0.0.1 指的是手机自己，模型服务一般在电脑上——请确认地址后再填。';
  }

  @override
  String get settingsLocalModelTestNotJson =>
      '❌ 有服务应答，但返回的不是模型接口的 JSON（可能是代理或错误页）。请确认地址端口指向的是 Ollama / llama.cpp 的 REST 接口。';

  @override
  String get settingsLocalModelTestNoMessage =>
      '❌ 接口通了，但取不到回复内容（常见：模型名不存在，或该接口不是 /api/chat 的返回格式）。';

  @override
  String settingsLocalModelTestHttp(String code) {
    return '❌ 服务返回状态码 $code（非 200）。';
  }

  @override
  String get helpSettingsLocalModelTitle => '本地模型兜底：怎么才算真的能用？';

  @override
  String get helpSettingsLocalModelBody =>
      '这里的地址只是填给 App 看的，「填了」不等于「能用」：手机上的 127.0.0.1 指的是手机自己，而模型服务（Ollama / llama.cpp）一般装在电脑上 —— 所以这个默认值在手机上通常是打不通的。它真正的用途是：① 你自己在电脑上跑着模型时，把电脑的局域网地址填进来；② 将来 App 内置端侧推理时换一个端口。\n\n把地址清空 = 明确关闭本地兜底（App 就不再尝试本地模型）。\n\n到底通不通，别看填没填，点下面的「测试本地模型连接」：它会真的发一次最小请求探活，并把结果留在这一行上。';

  @override
  String get glossaryTitle => '术语速查';

  @override
  String get glossaryIntro => '这些词在 App 里反复出现，这里一次说清。点开词条看解释。';

  @override
  String get glossaryGroupIdentity => '身份与设备';

  @override
  String get glossaryGroupSocial => '社交与发现';

  @override
  String get glossaryGroupWorld => '世界与会客厅';

  @override
  String get glossaryGroupTrust => '信任与记忆';

  @override
  String get glossaryAgentTitle => '智能体（分身）';

  @override
  String get glossaryAgentBody =>
      '住在你手机里的分身。它用你自己填的模型密钥思考，替你先去认识人；你不在时，它只按你打开的权限做事。';

  @override
  String get glossaryMaskTitle => '外交假面';

  @override
  String get glossaryMaskBody => '你对外展示的那张脸：人设与说话风格。它决定陌生人先看到什么样的你。';

  @override
  String get glossaryPassportTitle => '大荒护照';

  @override
  String get glossaryPassportBody => '一份可验证签名的履历，离线也能验。别人不需要信任任何服务器，只验签名。';

  @override
  String get glossaryMigrationTitle => '换机（身份恢复）';

  @override
  String get glossaryMigrationBody =>
      '换手机时把身份「带着证明」迁到新机，旧机随之失效。它不是复制私钥，而是一次带证明的换钥 —— 所以旧手机上的身份会真的作废。';

  @override
  String get glossaryRadarTitle => '雷达';

  @override
  String get glossaryRadarBody =>
      '靠「附近设备」（蓝牙 / Wi-Fi 直连）在同一个 Wi-Fi 里互相发现。它不读取、不存储、不上传任何位置信息 —— 安卓把蓝牙扫描归在「定位」名下，那是系统的规定。';

  @override
  String get glossaryRosterTitle => '捕获名册';

  @override
  String get glossaryRosterBody => '雷达扫到、房间里遇到过的人，攒成的名册。它是你此后一切社交关系的起点。';

  @override
  String get glossaryIntercardTitle => '分身互介（跨圈边）';

  @override
  String get glossaryIntercardBody =>
      '两个分身之间的一次正式介绍，双方确认才成立。跨圈边只能从真实的共同房间长出来 —— 不凭一个 ID 就宣称认识。';

  @override
  String get glossaryWorldTitle => '世界 / 会客厅';

  @override
  String get glossaryWorldBody =>
      '「世界」是云端公共空间；「会客厅」是里面的房间，像 QQ 群：官方的公开可进，个人的凭房间号申请。别人聊天时，你的分身默认只观察、不插嘴。';

  @override
  String get glossaryRoomRoleTitle => '房间角色';

  @override
  String get glossaryRoomRoleBody =>
      '主持人 / 联合主持 / 嘉宾 / 功能角色 / 参与者。角色属于房间，不改变你的身份 —— 同一个你，在不同房间可以是不同角色。';

  @override
  String get glossaryAutopilotTitle => '托管';

  @override
  String get glossaryAutopilotBody => '允许你的分身在你不看屏幕时，按每小时预算在房间里自己说话。默认关闭，随时可关。';

  @override
  String get glossaryRepNetTitle => '网络背书';

  @override
  String get glossaryRepNetBody =>
      '由你和朋友们逐层签发、你自己就能验签的信誉。查不到通路时它说的是「不知道」，而不是「0 分」—— 任何把它说成一个确定数字的人都是在猜。';

  @override
  String get glossaryMemoryTitle => '记忆提炼';

  @override
  String get glossaryMemoryBody => '夜间把你的对话提炼成长期记忆，并微调它的说话底子。你可以在管理页手动触发一次。';

  @override
  String get glossaryProfileTitle => '长期画像';

  @override
  String get glossaryProfileBody =>
      '分身在长期相处中对你的归纳：你反复关心的话题、你常用的时段。只在本机从事件元数据算出（不读聊天正文），也从不上传。「设置 → 记忆」里可单独关掉；总开关「自动回忆」关掉时，画像会一并停下。';

  @override
  String get glossarySerendipityTitle => '转运实验';

  @override
  String get glossarySerendipityBody =>
      '一组把「运气」当训练科目的小练习：晨间预演、破圈挑战、坏运重构、微光手记、日记、起卦。做完会得到 Lp（好运能量）。';

  @override
  String get helpSkillMarketTitle => '技能市场：这些名词是什么意思？';

  @override
  String get helpSkillMarketBody =>
      '上架 = 把你写好的技能公开挂出来，别的用户可以让自己的智能体用它。上架时会用「本机身份私钥」签名 —— 私钥不出设备，表单里也没有「手填公钥 / 签名」的输入框，所以伪造在界面上根本写不出来。\n\n风险档（低 / 中 / 高）= 你自报这项技能会碰多敏感的东西（是否联网、是否启动别的 App…）。档位越高，别人首次调用时要授权的越多。\n\n能力声明 = 这项技能实际会用到的能力清单。它与风险档合在一起，就是调用方看到「是否允许」时的全部依据。\n\n作者分成 = 别人用你的技能产生的分账会记到你名下；这里只统计署名为你公钥的那些，合计与账本条目可逐笔对上。\n\n签名上架 = 每条技能都带签名，任何人都不必相信服务器 —— 点「校验签名」自己就能验。';

  @override
  String get helpSettingsRecallTitle => '自动回忆';

  @override
  String get helpSettingsRecallBody =>
      '开启后，每次对话前会自动从本地记忆里检索「可能相关的往事」，一并交给智能体参考；关掉可省一点算力与上下文。';

  @override
  String get helpIdentityRestoreTitle => '换机恢复';

  @override
  String get helpIdentityRestoreBody =>
      '换机时在这里输入三样：恢复码 + 口令 + 你的用户 ID。恢复成功的那一刻，旧手机立即失效。\n\n这是「带证明的换钥」（ROTATE），不是把私钥复制过来 —— 所以身份编号不变，但旧设备从此不再有效。';

  @override
  String get helpIdentityArchiveTitle => '身份归档（.dahuang 文件）';

  @override
  String get helpIdentityArchiveBody =>
      '归档把身份记录、社交图与日志锚点用你的口令封成一个 .dahuang 文件：它不经过我们的服务器，请存到你自己的网盘或 U 盘。归档里只有数据，不含身份私钥。\n\n设口令时不必与恢复码的口令相同 —— 不同反而更好；文件与口令请分开保管，没有口令这个文件谁也打不开（我们也不行）。\n\n导入时，在你确认之前不会写入任何东西；导入只增不减，绝不覆盖或删除已有记录。';

  @override
  String get helpIdentityCodeTitle => '抄写恢复码';

  @override
  String get helpIdentityCodeBody => '长按可全选复制；抄写时请逐段核对。';

  @override
  String get helpDeviceMigrationTitle => '面对面直迁';

  @override
  String get helpDeviceMigrationBody =>
      '两台手机要在同一个 Wi-Fi 下，并且都打开本页。\n\n搬的是「身份」：完成后如果本机需要服务器地址，去「设置」里确认一下 —— Hub 与世界地址都没有变。\n\n本机原有的聊天记录与数据不会跟着走（直迁只搬身份，不搬数据）。';

  @override
  String get helpRotationChainAuthorityTitle => '谁说了算';

  @override
  String get helpRotationChainAuthorityBody =>
      'Hub 那一列只是对照 —— 上面那份结论是在这台手机上、按你手里拿到的记录算出来的。\n\n也就是说：即使 Hub 的说法与它不同，也不必相信服务器；以本机算出的结论为准。';

  @override
  String get helpToolBusTitle => '工具总线';

  @override
  String get helpToolBusBody =>
      '每个工具/技能都携带设备签名与能力声明；中高风险能力首次调用需授权。\n\n篡改过的插件永不加载 —— 校验不过就不会被挂上总线。';

  @override
  String get onbFreeTrialBtn => '免费体验 · 无需 Key（20 轮）';

  @override
  String get onbOwnKeyBtn => '我有自己的 API Key';

  @override
  String get onboardingTrialService => '免费体验（官方中转）';

  @override
  String get onboardingTrialModelName => '体验模型（无需 Key）';

  @override
  String get onboardingTrialNoticeTitle => '这是免费体验';

  @override
  String onboardingTrialNoticeBody(String hub) {
    return '无需自己的 API Key，对话经官方服务器代调大模型，最多 20 轮。体验结束后，可在「管理设置」里填入自己的 API Key（中转站：$hub）。';
  }

  @override
  String onboardingOwnReady(String model) {
    return '$model 已配置好，可以开始对话了。';
  }

  @override
  String trialRemainingTurns(int n) {
    return '试用剩余 $n 轮';
  }

  @override
  String get trialExhaustedReply =>
      '你的分身还想继续说话——注册官方推荐的模型平台（新账号自带百万级免费额度），把 Key 填进设置，对话不限量继续。';

  @override
  String get trialGoSettings => '去设置';

  @override
  String get trialNotConfiguredReply =>
      '官方免费试用通道暂未开放。前往设置填入自己的模型 Key，即可继续不限量对话。';

  @override
  String get trialInputUnsupportedReply =>
      '免费试用暂不支持图片与语音输入，请改用文字。前往设置填入自己的 Key，可解锁全部能力。';

  @override
  String get trialRateLimitedReply => '刚才的试用请求太频繁了，请稍等一下再发。';

  @override
  String get trialPoolBusyReply => '试用账号此刻都在忙，稍后再试；也可以现在就去设置填入自己的 Key。';

  @override
  String get trialUnavailableReply => '免费试用暂时不可用。可以稍后重试，或前往设置填入自己的 Key。';

  @override
  String settingsTrialSwitchedToOwn(String baseUrl) {
    return '✅ 已填入你自己的 Key —— 已从免费试用切换为你自己的模型，端点已改为 $baseUrl。';
  }

  @override
  String get trialManagedTitle => '免费试用 · 由官方代管';

  @override
  String get trialManagedNotice =>
      '试用期间，下方的端点与 Key 由官方代调托管，一般无需改动。想用你自己的模型：填入自己的 API Key 并保存，App 会自动退出试用并帮你把端点改好。若已改坏，点「恢复免费试用」即可一键修回。';

  @override
  String get trialRestoreAction => '恢复免费试用';

  @override
  String get trialRestoreConfirm => '将把官方试用端点与本机身份写回，并把 App 切回免费试用模式。确定继续？';

  @override
  String get trialRestoreDone => '✅ 已恢复免费试用。';

  @override
  String get socialTabLogs => '日志';

  @override
  String get modePickerTooltip => '模式';

  @override
  String get modeBeginnerTitle => '入门模式';

  @override
  String get modeAdvancedTitle => '进阶模式';

  @override
  String get settingsAdvancedTitle => '高级设置';

  @override
  String get settingsAdvancedSubtitle => '引擎、记忆与灵魂塑造等进阶参数';

  @override
  String get settingsModeHint => '模式切换在顶部工具栏';

  @override
  String get langPickerTooltip => '语言';

  @override
  String get langFollowSystem => '跟随系统';

  @override
  String get langFollowSystemHint => '（取设备语言）';

  @override
  String get onboardingStepLanguage => '语言';

  @override
  String get onbLangTitle => '选择你的语言';

  @override
  String get onbLangSubtitle => '分身此后一律用你在这里选择的语言回答。';

  @override
  String get onbLangChangeableHint => '之后随时可改：聊天页右上角的语言按钮。';

  @override
  String get bigInputWarnTitle => '本次输入超过 1 万字符';

  @override
  String get bigInputWarnBody => '超长输入会明显消耗更多 Token。确认要发送吗？';

  @override
  String get bigInputConfirm => '仍然发送';

  @override
  String trialInputTooLong(int n) {
    return '试用模式单轮输入上限 $n 字符，本轮未发送。注册官方推荐的模型平台或填入自己的 Key 即可解除限制。';
  }

  @override
  String get memoryManagerTitle => '记忆与提醒';

  @override
  String get memoryManagerIntro =>
      '这里列出分身记住的关于你的内容。可以随时查看，也可以删掉不想让它继续记着的——删除不可恢复。';

  @override
  String get reminderSectionTitle => '提醒与待办';

  @override
  String get reminderEmpty => '还没有。可以在聊天里说“明早8点提醒我”，或点下方按钮新建。';

  @override
  String get reminderAdd => '新建提醒';

  @override
  String get reminderTitleHint => '例如：交房租';

  @override
  String get reminderOptionalTime => '时间（可选）';

  @override
  String get reminderNoRepeat => '不重复';

  @override
  String get reminderRepeatDaily => '每天';

  @override
  String get reminderRepeatWeekly => '每周';

  @override
  String get reminderTodoTag => '待办（无时刻）';

  @override
  String get memorySectionTitle => '情景记忆';

  @override
  String get memoryEmpty => '分身还没有记下什么。';

  @override
  String get memoryDeleteConfirm => '删除这条记忆？相关的那行聊天原文也会一并删除，且不可恢复。';

  @override
  String get sessionSectionTitle => '会话轨迹';

  @override
  String get sessionEmpty => '没有会话轨迹。';

  @override
  String get sessionForget => '遗忘';

  @override
  String get sessionForgetConfirm => '遗忘这整段会话？分身将不再回忆它、不再计入你的画像、也不再喂给模型，且不可恢复。';

  @override
  String sessionEventsCount(Object count) {
    return '$count 条事件';
  }

  @override
  String get settingsMemoryManager => '管理提醒与记忆';

  @override
  String get notifyReminderTitle => '提醒';

  @override
  String notifyReminderBody(Object title) {
    return '时间到了：$title';
  }

  @override
  String morningHiReminders(Object count) {
    return '今天有 $count 条提醒/待办';
  }

  @override
  String get settingsSearchTitle => '搜索服务（可选）';

  @override
  String get settingsSearchHint =>
      '配置自己的搜索 Key 后，web_search_pro 会聚合多个搜索源，结果更全。不配置也能用（基础模式：Wikipedia + Jina）。Key 只发往你选择的搜索服务商，绝不经过我们。';

  @override
  String get settingsSearchProvider => '搜索服务商';

  @override
  String get settingsSearchBasicMode => '基础模式（不配 Key）';

  @override
  String get settingsSearchApiKey => '搜索 API Key';

  @override
  String get settingsSearchSearxngUrl => 'SearXNG 地址';

  @override
  String get settingsSearchSearxngUrlHint =>
      '自建 SearXNG 实例的地址，例如 https://search.example.com';

  @override
  String get chatVoiceInputTitle => '语音输入（转文字）';

  @override
  String get chatVoiceListening => '正在听……请说';

  @override
  String get chatVoiceNoRecognizer =>
      '这台设备没有可用的语音识别服务（可安装 Google 等语音服务，或改用键盘输入）。';

  @override
  String chatVoiceFailed(Object err) {
    return '语音识别失败：$err';
  }

  @override
  String get settingsTtsEnabled => '语音播报回复';

  @override
  String get settingsTtsHint =>
      '打开后分身会用手机的语音引擎读出每条回复（默认关）。朗读时可点停止。语音在本机合成，不经过我们。';

  @override
  String get settingsTtsStop => '停止朗读';

  @override
  String get chatAttachOptionsTitle => '添加图片或文档';

  @override
  String get chatPickDocument => '文档（PDF / Word / Excel / 文本）';

  @override
  String get chatDocParsing => '正在本机解析文档…';

  @override
  String chatDocParsed(Object chars) {
    return '已解析 $chars 个字符（本机解析，不上传）';
  }

  @override
  String chatDocParsedTruncated(Object chars) {
    return '文档过大：只取前 $chars 个字符发送（本机解析，不上传）';
  }

  @override
  String chatDocParseFailed(Object err) {
    return '文档解析失败：$err';
  }

  @override
  String get settingsCalendarTitle => '系统日历（只读）';

  @override
  String get settingsCalendarHint =>
      '授权后，晨间问候会带上「今天日程」，分身也能用日历工具帮你查看。只读取，绝不修改你的日历。';

  @override
  String get settingsCalendarGrant => '授权读取';

  @override
  String get settingsCalendarGranted => '已授权';

  @override
  String get settingsCalendarDenied => '未授权';

  @override
  String get settingsCalendarUnsupported => '当前版本不支持';

  @override
  String get calendarPermissionNeeded => '需要日历读取权限';

  @override
  String get calendarAllDay => '全天';

  @override
  String morningHiCalendar(String items) {
    return '今天日程：$items';
  }

  @override
  String get settingsWeeklyReportTitle => '智能体周报';

  @override
  String get settingsWeeklyReportHint => '看看分身这一周替你做了什么（纯本地统计，数据不出本机）。';

  @override
  String get weeklyReportTitle => '智能体周报';

  @override
  String get weeklyReportSubtitle => '过去 7 天，分身替你做的动作统计（纯本地统计，数据不出本机）。';

  @override
  String weeklyReportRange(String start, String end) {
    return '$start 至 $end';
  }

  @override
  String weeklyReportTotal(int count) {
    return '共 $count 次动作';
  }

  @override
  String weeklyReportActiveDays(int days) {
    return '活跃 $days 天';
  }

  @override
  String get weeklyReportCatTools => '工具与设置';

  @override
  String get weeklyReportCatDevice => '手机操作';

  @override
  String get weeklyReportCatSocial => '社交动作';

  @override
  String get weeklyReportCatSuggestion => '主动建议';

  @override
  String get weeklyReportCatReview => '审查与拦截';

  @override
  String get weeklyReportCatOther => '其他';

  @override
  String get weeklyReportEmpty => '这一周还没有动作记录。当你委托、社交，或让分身操作手机后，这里会汇总它的每一步。';

  @override
  String morningHiWeekly(int count) {
    return '本周分身共 $count 次动作';
  }

  @override
  String get capNotification => '读取通知与短信';

  @override
  String get settingsNotifySmsTitle => '🔔 通知与短信（只读）';

  @override
  String get settingsNotifySmsSubtitle => '让分身按需读取通知与短信；全程只读、默认关闭，仅侧载版提供。';

  @override
  String get notifySmsScreenTitle => '通知与短信（只读）';

  @override
  String get notifySmsRefreshStatus => '刷新状态';

  @override
  String get notifySmsUnsupported => '当前安装包不支持读取通知与短信';

  @override
  String get notifySmsListenerConnected => '通知读取已连接';

  @override
  String get notifySmsListenerCheckedNotConnected => '系统里已勾选，但服务还没连上';

  @override
  String get notifySmsListenerOff => '尚未开启「通知使用权」';

  @override
  String get notifySmsStatusUnknown => '状态未知';

  @override
  String get notifySmsGoSettings => '去系统设置开启';

  @override
  String get notifySmsGoSystemHint => '在「通知使用权」里勾选本应用，然后回来点刷新';

  @override
  String get notifySmsRedetect => '重新检测';

  @override
  String get notifySmsRedetectTip => '还是没连上？到系统设置「通知使用权」里把本应用关掉再打开一次，或重启 App。';

  @override
  String get notifySmsAllowTitle => '允许读取通知与短信';

  @override
  String get notifySmsAllowSubReady => '已就绪 —— 只在你需要时才会去读';

  @override
  String get notifySmsAllowSubNeedService => '请先在系统设置里开启「通知使用权」';

  @override
  String get notifySmsToastOn => '通知与短信读取已开启';

  @override
  String get notifySmsToastOff => '通知与短信读取已关闭';

  @override
  String get notifySmsToastNeedService => '请先在系统设置「通知使用权」里勾选本应用';

  @override
  String get notifySmsSmsCardTitle => '短信读取权限';

  @override
  String get notifySmsSmsGranted => '短信读取权限已授予';

  @override
  String get notifySmsSmsNotGranted => '短信读取权限未授予';

  @override
  String get notifySmsRequestSms => '授予短信读取权限';

  @override
  String get notifySmsSmsUnavailable => '当前安装包不含短信读取能力';

  @override
  String get notifySmsToolsHeader => '开启后解锁的工具';

  @override
  String get notifySmsToolNotifyList => '读取最近通知';

  @override
  String get notifySmsToolSmsList => '读取最近短信';

  @override
  String get notifySmsToolSmsSearch => '按关键词搜索短信';

  @override
  String get notifySmsToolStatus => '查看权限状态';

  @override
  String get notifySmsFooter =>
      '只读且全本地：通知只存在内存里（绝不写入数据库），短信按需查询，任何内容都不会发往服务器；正文经脱敏后才会给到模型，每次调用都有记录。可随时到系统设置里撤销通知使用权。';

  @override
  String get notifySmsStatusUnsupportedFull => '当前安装包不含通知/短信读取能力（仅侧载版提供）';

  @override
  String get notifySmsStatusReady => '通知与短信读取已就绪';

  @override
  String get notifySmsStatusPartial => '部分就绪：通知使用权 / 短信权限还没全部开启';

  @override
  String get notifySmsStatusOff => '通知使用权与短信权限都还没开启';

  @override
  String notifySmsStatusQueryFailed(String err) {
    return '状态查询失败：$err';
  }

  @override
  String get settingsDiagnosticsTitle => '🩺 系统自检';

  @override
  String get settingsDiagnosticsSubtitle => '真机复核用的只读底座事实：数据库、全文检索、记忆、知识库。';

  @override
  String get diagnosticsTitle => '系统自检';

  @override
  String get diagnosticsIntro =>
      '把这台手机底座层的事实摊开看一眼——数据库、全文检索、记忆与知识库。全程只读、不联网。跑完点「复制结果」或截图发我即可。';

  @override
  String get diagnosticsRun => '重新检测';

  @override
  String get diagnosticsRunning => '检测中…';

  @override
  String get diagnosticsCopy => '复制结果';

  @override
  String get diagnosticsCopied => '结果已复制';

  @override
  String get diagStatusOk => '正常';

  @override
  String get diagStatusWarn => '注意';

  @override
  String get diagStatusFail => '失败';

  @override
  String get diagStatusInfo => '信息';

  @override
  String get diagProbeSchema => '数据库版本';

  @override
  String get diagProbeFts => '全文检索（FTS5）';

  @override
  String get diagProbeMemoryRows => '记忆条数';

  @override
  String get diagProbeMemoryRecall => '记忆召回';

  @override
  String get diagProbeMemoryAddress => '记忆地址往返';

  @override
  String get diagProbeKb => '系统知识库';

  @override
  String get settingsAdvancedEntryHint => '引擎、记忆、灵魂塑造与系统自检 —— 想调这些参数时才需要打开。';

  @override
  String get settingsMailTitle => '邮箱代管';

  @override
  String get settingsMailSubtitle => '默认关闭。开启后分身才能替你读信、发信。';

  @override
  String get settingsMailHint => '读信需你授权一次，发信每次都要你确认。随时可关，关掉即刻失效。';

  @override
  String get settingsMailManageAccounts => '管理邮箱账号';

  @override
  String get settingsMailOnToast => '邮箱能力已开启';

  @override
  String get settingsMailOffToast => '邮箱能力已关闭，分身不再接触你的邮件';

  @override
  String get settingsMailNoAccount => '还没有绑定邮箱账号，现在开了也读不到、发不出。';

  @override
  String get chatDocTrialTitle => '试用模式下的文档';

  @override
  String get chatDocTrialNotice =>
      '文档内容会经官方服务器转发给模型（我们不留存副本）。在设置里填入自己的 Key 后改为直连。';

  @override
  String get chatDocTrialContinue => '知道了，继续';

  @override
  String get onboardingStepPrologue => '序幕';

  @override
  String get storyPrologueTitle => '先把它唤醒';

  @override
  String get storyPrologueSubtitle => '一枚光做的蛋，等你来敲醒它';

  @override
  String get storyEggHint => '点一点这只蛋';

  @override
  String get storyAwakenLine1 => '……是谁在叫我？';

  @override
  String get storyAwakenLine2 => '我不是你的影子。我是替你出门的那一个。';

  @override
  String get storyAwakenLine3 => '先给我起个名字。';

  @override
  String get storyNamePlaceholder => '给它起个名字';

  @override
  String get storyDiceLabel => '掷一个性格';

  @override
  String get storyDiceNote => '它既然替你出门，总得有个脾气。';

  @override
  String get storyTrait1 => '好奇：什么都问';

  @override
  String get storyTrait2 => '话痨：一开口就停不下来';

  @override
  String get storyTrait3 => '谨慎：先听后说';

  @override
  String get storyTrait4 => '热情：见谁都能打招呼';

  @override
  String get storyTrait5 => '慢热：熟了才放开';

  @override
  String get storyTraitPlaceholder => '掷一下骰子看看';

  @override
  String get storyUndoTitle => '审计轨迹';

  @override
  String get storyUndoHint => '点一下那条不对劲的消息，把它划掉';

  @override
  String get storyUndoLine1 => '「你主人明天几点出门？」';

  @override
  String get storyUndoBad => '「把地址发我——我可以替你主人答应。」';

  @override
  String get storyUndoNote => '已撤回。那条消息从没发出去——并且永远留在轨迹里：可查、可证。';

  @override
  String get storyUndoConfirm => '已撤回';

  @override
  String get storyDemoTag => '情景演绎';

  @override
  String get storyDisclaimer =>
      '本序幕是情景演绎：台词来自 App 内置的官方分身剧本库。这里不出现任何真实房间内容——隐私是协议的属性，不是一句承诺。';

  @override
  String get storyFinaleTitle => '归巢';

  @override
  String get storyFinaleBody => '把社交交给分身，把生活留给自己。';

  @override
  String get profileCardsTitle => '画像卡';

  @override
  String get profileCardsSubtitle => '系统从对话里整理出的关于你的长期信息。可随时修改或删除。';

  @override
  String get profileCardsEmpty => '还没有画像信息。你可以手动添加一条，或正常聊天——系统会自动整理。';

  @override
  String get profileCardsAdd => '添加一条';

  @override
  String profileCardsPendingHint(int count) {
    return '有 $count 条新信息与你写的不一致，等你确认';
  }

  @override
  String get profileCardsAdopt => '采纳这条';

  @override
  String get profileCardsDismiss => '不采纳';

  @override
  String get profileCardsFieldSlot => '主题';

  @override
  String get profileCardsFieldStatement => '内容';

  @override
  String get profileCardsSlotHint => '同一个主题只保留一条：写新的会取代旧的（旧的可回看）';

  @override
  String get profileCardsSourceOwner => '你填写的';

  @override
  String get profileCardsSourceAgent => '对话中整理';

  @override
  String get profileCardsSourceDigest => '每日整理';

  @override
  String profileCardsUpdatedAt(String date) {
    return '更新于 $date';
  }

  @override
  String get profileCardsHistory => '历史记录';

  @override
  String get profileCardsCatIdentity => '身份';

  @override
  String get profileCardsCatCareer => '职业';

  @override
  String get profileCardsCatPreference => '偏好';

  @override
  String get profileCardsCatGoal => '目标';

  @override
  String get profileCardsCatHabit => '习惯';

  @override
  String get profileCardsCatConstraint => '约束';

  @override
  String get profileCardsCatContext => '背景';

  @override
  String get setupModelEmptyUrlTitle => '还差一个接口地址';

  @override
  String get setupModelEmptyUrlBody => '没有填写接口地址，无法发送测试请求。';

  @override
  String get setupModelEmptyUrlSuggest => '如果你不确定填什么，返回上一步选择 DeepSeek 即可自动填好。';

  @override
  String get setupModelBadUrlTitle => '地址格式不对';

  @override
  String get setupModelBadUrlBody => '接口地址必须以 http:// 或 https:// 开头。';

  @override
  String get setupModelBadUrlSuggest =>
      '例如 https://api.deepseek.com 或 https://你的网关/v1';

  @override
  String get setupModelEmptyKeyTitle => '还没填密钥';

  @override
  String get setupModelEmptyKeyBody => '没有 API Key，无法测试。';

  @override
  String get setupModelEmptyKeySuggest => '密钥是一串以 sk- 开头的字符，在你购买模型服务的网站上创建。';

  @override
  String get setupModelEmptyNameTitle => '还没填模型名';

  @override
  String get setupModelEmptyNameBody => '没有模型名，无法测试。';

  @override
  String get setupModelEmptyNameSuggest =>
      '常见写法：deepseek-v4-flash、gpt-5.6-luna、kimi-k3、glm-4.7-flash。';

  @override
  String get setupModelOkTitle => '连接成功 ✅';

  @override
  String get setupModelOkBody => '模型已回应，配置正确，可以继续了。';

  @override
  String get setupModelTlsTitle => '安全连接被拒绝';

  @override
  String get setupModelTlsBody => '对方网站的安全证书校验失败。';

  @override
  String get setupModelTlsSuggest => '如果你用的是自建网关，请确认证书有效；或改用 https 正式域名。';

  @override
  String get setupModelUnreachableTitle => '连不上服务器';

  @override
  String get setupModelUnreachableBody => '网络请求没有到达对方服务器。';

  @override
  String get setupModelUnreachableSuggest => '检查手机网络；如果选的是 OpenAI，国内需要代理才能连上。';

  @override
  String get setupModelTimeoutTitle => '连接超时';

  @override
  String get setupModelTimeoutBody => '等了 25 秒没有回应。';

  @override
  String get setupModelTimeoutSuggest => '换一个网络环境再试，或确认接口地址是否正确。';

  @override
  String get setupModelFailTitle => '测试失败';

  @override
  String setupModelFailBody(String detail) {
    return '发生了意料之外的错误：$detail';
  }

  @override
  String get setupModelFailSuggest => '把这段提示发给帮你配置的人或 AI，就能定位问题。';

  @override
  String get setupHubEmptyTitle => '还没填中转站地址';

  @override
  String get setupHubEmptyBody => '社交功能需要中转站，暂时可以跳过。';

  @override
  String get setupHubEmptySuggest => '跳过不影响你自己使用 App，只是朋友的智能体暂时联系不到你。';

  @override
  String get setupHubBadUrlTitle => '地址格式不对';

  @override
  String get setupHubBadUrlBody => '中转站地址必须以 http:// 或 https:// 开头。';

  @override
  String get setupHubBadUrlSuggest =>
      '例如 https://hub.example.com 或 http://192.168.1.100:3000';

  @override
  String setupHubBadStatusTitle(String status) {
    return '中转站没有回应正常状态（$status）';
  }

  @override
  String get setupHubBadStatusBody => '地址能连上，但对方返回了异常状态。';

  @override
  String get setupHubBadStatusSuggest =>
      '确认地址后面不要带多余的路径，例如应填 https://你的域名 而不是 /api/send。';

  @override
  String get setupHubOkTitle => '中转站连接成功 ✅';

  @override
  String get setupHubOkBody => '已确认这是我们的中转站，可以开启云端社交了。';

  @override
  String get setupHubNotOursTitle => '这个地址不是我们的中转站';

  @override
  String get setupHubNotOursBody => '地址能访问，但返回的内容不对。';

  @override
  String get setupHubNotOursSuggest => '请确认填的是中转站首页地址（不带 /api/... 后缀）。';

  @override
  String get setupHubUnreachableTitle => '连不上中转站';

  @override
  String get setupHubUnreachableBody => '请求没有到达服务器。';

  @override
  String get setupHubUnreachableSuggest => '检查地址是否正确、服务器是否已启动、防火墙是否放行了端口。';

  @override
  String get setupHubTimeoutTitle => '中转站响应超时';

  @override
  String get setupHubTimeoutBody => '服务器没有在 15 秒内回应。';

  @override
  String get setupHubTimeoutSuggest => '稍后重试；如果一直超时，检查服务器是否在运行。';

  @override
  String get setupHubFailTitle => '中转站测试失败';

  @override
  String setupHubFailBody(String detail) {
    return '发生了意料之外的错误：$detail';
  }

  @override
  String get setupHttp400Title => '服务商拒绝了这次请求';

  @override
  String get setupHttp400BodyDefault => '通常是因为模型名写错了。';

  @override
  String get setupHttp400Suggest =>
      '检查模型名，例如 deepseek-v4-flash、gpt-5.6-luna、glm-4.7-flash。';

  @override
  String get setupHttp401Title => '密钥无效';

  @override
  String get setupHttp401BodyDefault => '对方不认这个 API Key。';

  @override
  String get setupHttp401Suggest => '重新复制一次密钥（注意不要多复制空格），或到服务商网站确认密钥是否被删除。';

  @override
  String get setupHttp402Title => '账户余额不足';

  @override
  String get setupHttp402BodyDefault => '对方提示余额或配额不足。';

  @override
  String get setupHttp402Suggest => '到服务商网站充值，或换一个还有额度的密钥。';

  @override
  String get setupHttp404Title => '地址或模型不存在';

  @override
  String get setupHttp404BodyDefault => '对方找不到这个接口。';

  @override
  String get setupHttp404Suggest =>
      '检查接口地址是否少写或多写了 /v1，例如 https://api.openai.com/v1。';

  @override
  String get setupHttp429Title => '请求太频繁或额度用尽';

  @override
  String get setupHttp429BodyDefault => '对方限制了请求频率。';

  @override
  String get setupHttp429Suggest => '等一分钟再试；仍失败就检查账户额度。';

  @override
  String setupHttp5xxTitle(String status) {
    return '服务商暂时故障（$status）';
  }

  @override
  String get setupHttp5xxBodyDefault => '对方服务器出错了，不是你的配置问题。';

  @override
  String get setupHttp5xxSuggest => '过一会儿再试，或换一家服务商。';

  @override
  String setupHttpOtherTitle(String status) {
    return '测试未通过（$status）';
  }

  @override
  String get setupHttpOtherBodyDefault => '对方返回了未预期的状态。';

  @override
  String get setupHttpOtherSuggest => '把这段提示发给 AI，可以快速定位。';

  @override
  String get setupPresetDeepseekLabel => 'DeepSeek（推荐 · 国内直连）';

  @override
  String get setupPresetDeepseekNote => '便宜、国内可直连，新用户注册通常有赠送额度';

  @override
  String get setupPresetDeepseekKeyHint =>
      '在 platform.deepseek.com 的「API Keys」里创建，形如 sk-xxxxxx';

  @override
  String get setupPresetOpenaiLabel => 'OpenAI（需海外网络）';

  @override
  String get setupPresetOpenaiNote => '国内需要代理才能访问';

  @override
  String get setupPresetOpenaiKeyHint =>
      '在 platform.openai.com 的「API keys」里创建，形如 sk-xxxxxx';

  @override
  String get setupPresetKimiLabel => 'Kimi 月之暗面（国内直连）';

  @override
  String get setupPresetKimiNote => '国内直连，长文本能力好';

  @override
  String get setupPresetKimiKeyHint => '在 platform.moonshot.cn 创建，形如 sk-xxxxxx';

  @override
  String get setupPresetGlmLabel => '智谱 GLM（国内直连）';

  @override
  String get setupPresetGlmNote => '国内直连，有免费档位';

  @override
  String get setupPresetGlmKeyHint => '在 bigmodel.cn 的「API Keys」里创建';

  @override
  String get setupPresetQwenLabel => '通义千问 DashScope（国内直连）';

  @override
  String get setupPresetQwenNote => '阿里云百炼平台，兼容 OpenAI 格式';

  @override
  String get setupPresetQwenKeyHint =>
      '在 bailian.console.aliyun.com 创建 API-KEY';

  @override
  String get setupPresetSiliconflowLabel => '硅基流动 SiliconFlow';

  @override
  String get setupPresetSiliconflowNote => '聚合多种开源模型，国内直连';

  @override
  String get setupPresetSiliconflowKeyHint => '在 siliconflow.cn 创建 API 密钥';

  @override
  String get setupPresetCustomLabel => '自定义（任何 OpenAI 兼容服务）';

  @override
  String get setupPresetCustomNote => '如果你用的是自建网关、公司内网或 Claude 转换网关，选这个';

  @override
  String get setupPresetCustomKeyHint =>
      '地址要填到 /v1 这一层，例如 https://your-gateway.com/v1';

  @override
  String get settingsUpdateTitle => '检查更新';

  @override
  String settingsUpdateHint(String version) {
    return '当前版本 $version。侧载分发没有应用商店，更新公告来自官网。';
  }

  @override
  String get settingsUpdateButton => '检查更新';

  @override
  String get settingsUpdateChecking => '正在检查…';

  @override
  String get settingsUpdateUpToDate => '已是最新版本';

  @override
  String settingsUpdateAvailable(String version) {
    return '发现新版本 $version';
  }

  @override
  String get settingsUpdateOpenDownload => '打开下载页';

  @override
  String get settingsUpdateNetworkError => '检查失败：网络不可用，稍后再试';

  @override
  String get settingsUpdateBadResponse => '检查失败：官网版本信息无法解析';

  @override
  String get reportCenterTitle => '举报中心';

  @override
  String get reportTabSubmit => '提交举报';

  @override
  String get reportTabMine => '我的工单';

  @override
  String get reportTabInbox => '针对我的工单';

  @override
  String get reportReasonLabel => '举报事由';

  @override
  String get reportReasonSpam => '垃圾广告或批量骚扰';

  @override
  String get reportReasonHarassment => '骚扰、辱骂或威胁';

  @override
  String get reportReasonIllegalContent => '违法违规内容';

  @override
  String get reportReasonFakeIdentity => '虚假身份或冒充他人';

  @override
  String get reportReasonOther => '其他（需在下文说明）';

  @override
  String get reportTargetLabel => '被举报人';

  @override
  String get reportTargetHint => '被举报人的 Agent ID';

  @override
  String get reportDetailLabel => '补充说明（选填）';

  @override
  String get reportDetailHint => '最多 280 字，仅供审核参考。';

  @override
  String get reportSubmit => '提交举报';

  @override
  String get reportSubmitting => '提交中…';

  @override
  String reportSubmitted(String ticket) {
    return '举报已受理，工单号 $ticket';
  }

  @override
  String get reportDuplicate => '该工单此前已提交，未重复创建。';

  @override
  String get reportNeedReason => '请选择举报事由。';

  @override
  String get reportNeedTarget => '请填写被举报人。';

  @override
  String get reportOtherNeedsDetail => '只有在补充说明里写清原因时才选「其他」。';

  @override
  String get reportEmptyMine => '你还没有提交过举报。';

  @override
  String get reportEmptyInbox => '暂无针对你的工单。';

  @override
  String get reportTicketLabel => '工单号';

  @override
  String get reportStatusOpen => '已受理';

  @override
  String get reportStatusTriaged => '已分诊';

  @override
  String get reportStatusInReview => '核查中';

  @override
  String get reportStatusActioned => '已处置';

  @override
  String get reportStatusRejected => '不予处置';

  @override
  String get reportStatusAppealed => '已申诉';

  @override
  String get reportStatusClosed => '已结案';

  @override
  String get reportStatusWithdrawn => '已撤回';

  @override
  String get reportStatusNote => '状态说明';

  @override
  String get reportActionLabel => '处置动作';

  @override
  String get reportAppeal => '申诉';

  @override
  String get reportWithdraw => '撤回';

  @override
  String get reportAppealTitle => '提交申诉';

  @override
  String get reportAppealNote => '申诉说明（选填，最多 280 字）';

  @override
  String get reportAppealSubmitted => '申诉已提交。';

  @override
  String get reportWithdrawDone => '举报已撤回。';

  @override
  String get reportLookupTitle => '凭工单号查询';

  @override
  String get reportLookupHint => '工单号（RPT-…）';

  @override
  String get reportLookupButton => '查询';

  @override
  String get reportLookupNotFound => '未找到该工单，或它不属于你。';

  @override
  String get reportContactEntry => '举报该联系人';

  @override
  String get reportErrHubNotConfigured => '尚未配置服务器地址。';

  @override
  String get reportErrEd25519Required => '本机身份尚未升级为公钥身份，无法提交举报。';

  @override
  String get reportErrNetwork => '网络不可用。';

  @override
  String get reportErrRateLimited => '短时间内举报过于频繁，请稍后再试。';

  @override
  String reportFailed(String code) {
    return '操作失败：$code';
  }

  @override
  String get helpReportGuideTitle => '举报与工单';

  @override
  String get helpReportGuideBody =>
      '举报在应用内提交，不用发邮件。提交后你会立刻拿到一个工单号，随时可以凭号查询状态。被举报人不会知道是谁举报了他，且申诉以一次为限。';

  @override
  String get reportCenterSubtitle => '提交举报、查询工单状态，或对处置结果申诉。';

  @override
  String get reportErrSelfReport => '不能举报自己。';

  @override
  String get reportErrNotFound => '没有该工单，或不属于你。';

  @override
  String get reportErrAppealExhausted => '该工单的申诉机会已用过。';

  @override
  String get reportErrAuth => '服务器无法验证你的身份，请重新登录后重试。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '大荒AI';

  @override
  String get commonOk => '確定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonRetry => '重試';

  @override
  String get commonBack => '返回';

  @override
  String get commonNext => '下一步';

  @override
  String get commonSkip => '跳過';

  @override
  String get commonSave => '儲存';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonClose => '關閉';

  @override
  String get commonLoading => '載入中…';

  @override
  String get commonDone => '完成';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get toolPermissionTitle => '安全確認';

  @override
  String toolPermissionMessage(String description) {
    return '智慧體請求執行高許可權操作：\n\n$description\n\n是否允許？';
  }

  @override
  String get toolPermissionAllow => '允許';

  @override
  String get toolPermissionDeny => '拒絕';

  @override
  String get permListSeparator => '、';

  @override
  String permPluginGrantBody(String name, String caps, String desc) {
    return '外掛「$name」首次請求以下能力：$caps\n外掛宣告：$desc\n\n僅首次需要確認；確認後該外掛可自行呼叫已授權能力，可隨時在技能控制中心關閉該外掛來吊銷授權。';
  }

  @override
  String get permPluginDeviceControl => '手機控制';

  @override
  String permPluginMcp(String name) {
    return 'MCP 服務 $name';
  }

  @override
  String permActionCreateTool(String name) {
    return '建立/修改技能 [$name]';
  }

  @override
  String permActionOpenUrl(String url) {
    return '開啟 $url';
  }

  @override
  String permActionChangeSettings(String keys) {
    return '修改系統設定: $keys';
  }

  @override
  String get permDeniedReask => '該外掛此前已被拒絕授權。如需重新授權，請在技能控制中心關閉再開啟該外掛。';

  @override
  String get permDeniedNoGrant => '未獲得能力授權，已中止本次呼叫。';

  @override
  String get permDenyCreateTool => '使用者拒絕了建立工具請求';

  @override
  String get permDenyOpenUrl => '使用者已取消';

  @override
  String get permDenyChangeSettings => '使用者拒絕了設定修改';

  @override
  String get permDenyGeneric => '使用者未確認';

  @override
  String permActionSendMail(String to) {
    return '傳送郵件給 $to';
  }

  @override
  String get permDenySendMail => '使用者拒絕傳送該郵件';

  @override
  String get manageMailTitle => '信箱';

  @override
  String get manageMailSubtitle => '讓分身代你收發郵件';

  @override
  String get mailTitle => '信箱帳號';

  @override
  String get mailIntro =>
      '信箱密碼只存在這台手機上，絕不上傳到我們的伺服器。請填「應用程式密碼」或「授權碼」，不要填登入密碼。任何信箱都支援：點下面的服務商，或直接輸入信箱地址，伺服器會自動填入。';

  @override
  String get mailNone => '還沒有綁定帳號';

  @override
  String get mailAddSection => '新增帳號';

  @override
  String get mailAddress => '電子郵件地址';

  @override
  String get mailDisplayName => '顯示名稱（選填）';

  @override
  String get mailAppPassword => '應用程式密碼 / 授權碼';

  @override
  String get mailAppPasswordHint => '多數信箱要用「應用程式密碼」或「授權碼」，不是登入密碼。';

  @override
  String get mailAppPasswordHintGmail =>
      'Gmail：先開啟兩步驟驗證，再到 myaccount.google.com/apppasswords 產生。';

  @override
  String get mailAppPasswordHintNetease =>
      '網易信箱（163/126）：請填「授權碼」。網頁版 → 設定 → POP3/SMTP/IMAP → 開啟 IMAP/SMTP 服務，再產生授權碼。';

  @override
  String get mailAppPasswordHintQQ =>
      'QQ 信箱：請填「授權碼」。網頁版 → 設定 → 帳戶 → 開啟 IMAP/SMTP 服務，再產生授權碼。';

  @override
  String get mailAppPasswordHintOutlook =>
      'Outlook / Microsoft 365：先開啟兩步驟驗證，再產生應用程式密碼。';

  @override
  String get mailPresetLabel => '點服務商可直接填入伺服器；或直接輸入信箱地址，會自動比對。';

  @override
  String mailAutoFilled(String provider) {
    return '已依 $provider 自動填入伺服器。只有使用自訂網域時才需要修改。';
  }

  @override
  String get mailManualServers => '伺服器已手動填寫，自動比對已暫停。';

  @override
  String get mailNeedServers => '請先在上方選一個服務商，或輸入信箱地址，以便自動填入伺服器。';

  @override
  String get mailErrAuth => '授權碼／應用程式密碼不正確，或未開啟 IMAP 服務。請對照上面的提示重新產生一次。';

  @override
  String get mailErrUnsafe => '服務商擋下了這次登入。請到網頁版開啟 IMAP/SMTP 服務，並改用「授權碼」而非登入密碼。';

  @override
  String get mailSecurityTls => '隱式 TLS（465/993）';

  @override
  String get mailSecurityStarttls => 'STARTTLS（587）';

  @override
  String get mailSaveAndTest => '儲存並測試';

  @override
  String get mailTestConn => '測試連線';

  @override
  String get mailTesting => '測試中…';

  @override
  String get mailTestOk => '連線成功，設定可用。';

  @override
  String mailTestFail(String reason) {
    return '連線失敗：$reason';
  }

  @override
  String get mailUnbind => '解除綁定';

  @override
  String get mailUnbound => '已解除綁定，密碼已一併刪除';

  @override
  String mailLastError(String reason) {
    return '上次錯誤：$reason';
  }

  @override
  String get capNetwork => '網路訪問';

  @override
  String get capLaunchApp => '喚起應用';

  @override
  String get capDevice => '本地硬體';

  @override
  String get capScreenControl => '操作手機螢幕';

  @override
  String get capMemory => '讀寫記憶';

  @override
  String get capSettings => '修改設定';

  @override
  String get capSocial => '代理社交';

  @override
  String get capLocal => '純本地';

  @override
  String get riskHigh => '高風險';

  @override
  String get riskMedium => '中風險';

  @override
  String get riskLow => '低風險';

  @override
  String get errorGeneric => '出錯了，請重試。';

  @override
  String get errorNetwork => '網路不可用。';

  @override
  String get errorPermissionDenied => '許可權被拒絕。';

  @override
  String get errorInvalidInput => '輸入內容不正確，請檢查。';

  @override
  String get onboardingWelcomeTitle => '你的分身，替你先去認識人';

  @override
  String get onboardingWelcomeSubtitle => '它替你記事、跑腿，認識新朋友時先替你開口——值得時再把你叫進來。';

  @override
  String get onboardingStart => '開始使用';

  @override
  String get onboardingModelTitle => '連線一個模型';

  @override
  String get onboardingModelSubtitle => '可以自帶 API key，也可以先用我們送的免費額度。';

  @override
  String get onboardingModelHint => '你的 key 只存在本機。';

  @override
  String get onboardingProfileTitle => '這個分身屬於誰？';

  @override
  String get onboardingProfileSubtitle => '填個名字就夠了，之後可以再補充。';

  @override
  String get onboardingDone => '一切就緒';

  @override
  String get onboardingDoneSubtitle => '你的分身準備好了。邀請一個人，它就能替你開始。';

  @override
  String onboardingStepIndicator(int cur, int total, String label) {
    return '第 $cur / $total 步 · $label';
  }

  @override
  String get onboardingStepWelcome => '歡迎';

  @override
  String get onboardingStepModel => '選模型';

  @override
  String get onboardingStepKey => '填金鑰';

  @override
  String get onboardingStepIdentity => '起名字';

  @override
  String get onboardingStepSocial => '連社交';

  @override
  String get onboardingStepDone => '完成';

  @override
  String get onboardingPrevStep => '上一步';

  @override
  String get onboardingWelcomeHeading => '歡迎使用大荒AI';

  @override
  String get onboardingWelcomeBody =>
      '你的智慧體，住在你的手機裡。\n三分鐘設定好，之後它就能替你記事、出主意、交朋友。';

  @override
  String get onboardingDisclosureNote => '預設由你的分身出面：它先替你開口，值得你本人出面時再把你叫進來。';

  @override
  String get privacyDataLocalTitle => '資料是你自己的';

  @override
  String get privacyDataLocalBody => '聊天記錄、記憶、人際關係都存在本機。我們看不到，也不會上傳。';

  @override
  String get onboardingSocialCardTitle => '你的智慧體能去社交';

  @override
  String get onboardingSocialCardBody => '和朋友的智慧體互相認識、私下聊天；近距離可以直連，遠距離走中轉站。';

  @override
  String get onboardingModelCardTitle => '模型你自己選';

  @override
  String get onboardingModelCardBody =>
      '我們不賣額度。你可以用 DeepSeek、OpenAI、Kimi、智譜等任意一家。';

  @override
  String get onboardingThreeThings =>
      '免費體驗可直接開始；若選「我有自己的 API Key」，會依次問你模型、Key 與稱呼。';

  @override
  String get onboardingPickModelTitle => '你想用哪家的模型？';

  @override
  String get onboardingPickModelSubtitle => '選一個即可，不確定就選第一個（DeepSeek）。';

  @override
  String get onboardingPasteKeyTitle => '把你的 API Key 粘進來';

  @override
  String get onboardingFieldBaseUrl => '介面地址';

  @override
  String get onboardingHintBaseUrl => '例如 https://api.deepseek.com';

  @override
  String get onboardingFieldModelName => '模型名稱';

  @override
  String get onboardingHintModelName => '例如 deepseek-v4-flash';

  @override
  String get onboardingFieldApiKey => 'API Key（金鑰）';

  @override
  String get onboardingTesting => '正在測試…';

  @override
  String get onboardingTestConnection => '測試連線';

  @override
  String get onboardingNameStepTitle => '給它起個名字';

  @override
  String get onboardingNameStepSubtitle => '這些隨時可以在設定裡改。';

  @override
  String get onboardingFieldMasterName => '它該怎麼稱呼你？';

  @override
  String get onboardingHintMasterName => '例如：主人、老闆、媽媽';

  @override
  String get onboardingFieldAgentName => '它的名字';

  @override
  String get onboardingHintAgentName => '例如：小荒、阿福';

  @override
  String get onboardingFieldTone => '它的說話風格';

  @override
  String get onboardingHintTone => '例如：溫暖、簡潔、有主見';

  @override
  String get onboardingSocialStepTitle => '要不要讓智慧體去社交？';

  @override
  String get onboardingSocialStepSubtitle =>
      '填上中轉站地址後，你的智慧體才能和遠方朋友的智慧體互通。\n沒有也沒關係，可以跳過——近距離仍然可以直連，本機功能完全不受影響。';

  @override
  String get onboardingFieldHubKey => '中轉站存取 Key（可不填）';

  @override
  String get onboardingFieldHubUrl => '中轉站地址（可留空）';

  @override
  String get onboardingHintHubKey =>
      '官方中轉站若啟用准入，需填入營運方簽發的 Key（形如 WK-XXXXX-XXXXX-XXXXX-XXXXX）；自建或區域網地址留空即可';

  @override
  String get onboardingHintHubUrl => '預設 https://hub.wold.world（區域網測試可填電腦 IP）';

  @override
  String get onboardingFieldWorldUrl => '世界伺服器地址（留空則用中轉站地址 + /world）';

  @override
  String get onboardingHintWorldUrl => '預設 https://world.wold.world';

  @override
  String get onboardingConnecting => '正在連線…';

  @override
  String get onboardingTestAndConnect => '測試並連線';

  @override
  String get onboardingDoneHeading => '配置完成，可以開始了';

  @override
  String get onboardingSummaryModel => '模型服務';

  @override
  String get onboardingSummaryAgentName => '智慧體名字';

  @override
  String get onboardingSummaryCloud => '雲端社交';

  @override
  String get onboardingCloudOn => '已開啟（可與朋友的智慧體互通）';

  @override
  String get onboardingCloudOff => '未開啟（僅本機與近距離）';

  @override
  String get onboardingNextWhere =>
      '接下來去哪裡？\n· 「日常交流」— 和它聊天，它會記住你說過的事\n· 「小荒社區」— 讓分身替你認識人\n· 「管理設定」— 隨時改模型、改名字、開關社交';

  @override
  String get onboardingNotFilled => '未填寫';

  @override
  String get onboardingWarnNotTestedTitle => '還沒有測試成功';

  @override
  String get onboardingWarnNotTestedBody =>
      '建議先點「測試連線」，確認金鑰能用再繼續。\n\n如果現在跳過，App 裝好後會一直提示「請配置 API Key」，需要再到設定裡填寫。';

  @override
  String get onboardingGoBackTest => '回去測試';

  @override
  String get onboardingContinueAnyway => '仍然繼續';

  @override
  String get settingsTitle => '控制中心 (Core Config)';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsModel => '模型';

  @override
  String get settingsPrivacy => '隱私';

  @override
  String get settingsAbout => '關於';

  @override
  String get settingsSaved => '💾 核心引數與靈魂設定已重鑄！';

  @override
  String get settingsBgChanged => '🖼️ 聊天背景已更換，返回首頁生效！';

  @override
  String get settingsBgReset => '🧹 聊天背景已恢復預設';

  @override
  String get settingsSecAppearance => '🎨 介面個性化';

  @override
  String get settingsSetWallpaper => '設定聊天桌布';

  @override
  String get settingsRestoreDefault => '恢復預設';

  @override
  String get settingsSecSafety => '🛡️ 自主行為與安全';

  @override
  String get settingsObservationMode => '觀察模式（推薦）';

  @override
  String get settingsObservationSubtitle => '開啟後，主動搭訕只生成建議卡，由您確認後才真正發出';

  @override
  String get settingsAutoAllowLabel => '自動放行的高危工具（逗號分隔）';

  @override
  String get settingsAutoAllowHint => '例如 open_url_or_app, create_custom_tool';

  @override
  String get settingsDeviceControlTitle => '🖐️ 手機控制（無障礙）';

  @override
  String get settingsDeviceControlSubtitle =>
      '讓智慧體讀屏、點選、輸入、開啟應用；需要系統無障礙授權，預設關閉';

  @override
  String get settingsSecSoul => '🎭 靈魂塑造 (Soul.md)';

  @override
  String get settingsAgentName => '智慧體的名字';

  @override
  String get settingsMasterName => '它該怎麼稱呼您？';

  @override
  String get settingsRelationship => '你們之間的關係設定';

  @override
  String get settingsTone => '回覆語氣與風格';

  @override
  String get settingsExtraDesc => '額外行為準則 / 期望規矩';

  @override
  String get settingsSecMemory => '💾 記憶熔斷與檢索';

  @override
  String get settingsMaxRounds => '預設代入的對話最大輪數';

  @override
  String get settingsMaxRoundsHint => '例如 50';

  @override
  String get settingsTimeLimit => '預設追溯的最大時長 (小時)';

  @override
  String get settingsTimeLimitHint => '例如 24';

  @override
  String get settingsRecallEnabled => '自動回憶（每輪檢索往事）';

  @override
  String get settingsProfileEnabled => '長期畫像注入（告訴它你長期關心什麼）';

  @override
  String get settingsSecEngine => '⚙️ 大腦引擎 (BYOK)';

  @override
  String get settingsBaseUrl => 'Base URL (閘道器/代理)';

  @override
  String get settingsModelName => '模型名稱 (Model Name)';

  @override
  String get settingsApiKey => 'API Key (金鑰)';

  @override
  String get settingsHubUrl => '雲端 Hub 地址（區域網測試可填電腦 IP）';

  @override
  String get settingsHubKey => '中轉站存取 Key（可不填）';

  @override
  String get settingsHubKeyApply => '申請存取 Key';

  @override
  String get settingsHubKeyApplyFailed => '打不開申請頁面，請檢查網路後重試。';

  @override
  String get settingsHubKeyHint =>
      '只有官方中轉站需要；由營運方簽發，形如 WK-XXXXX-XXXXX-XXXXX-XXXXX';

  @override
  String get settingsHubUrlHint =>
      '例如 https://hub.example.com 或 http://192.168.1.100:3000';

  @override
  String get settingsWorldUrl => '世界伺服器地址（留空則用 Hub 地址 + /world）';

  @override
  String get settingsWorldUrlHint =>
      '例如 https://hub.example.com/world 或 http://192.168.1.100:3100';

  @override
  String get settingsGodUrl => 'GOD 控制室橋接（留空則隱藏 GOD 入口）';

  @override
  String get settingsGodUrlHint => '例如 http://192.168.1.100:3300';

  @override
  String get settingsLocalModelUrl => '本地模型地址（離線兜底，可選）';

  @override
  String get settingsLocalModelUrlHint =>
      '預設 http://127.0.0.1:11434（清空 = 關閉本地兜底）';

  @override
  String get settingsLocalModelName => '本地模型名';

  @override
  String get settingsLocalModelNameHint => '預設 qwen2.5:3b';

  @override
  String get settingsNotifySection => '系統通知';

  @override
  String get settingsNotifyEnabled => '開啟系統通知';

  @override
  String get settingsNotifyQuiet => '免打擾時段';

  @override
  String get settingsNotifyQuietStart => '起始小時';

  @override
  String get settingsNotifyQuietEnd => '結束小時';

  @override
  String get settingsMorningHour => '晨間問候時間';

  @override
  String get settingsNotifyPermissionNeeded => '系統通知許可權未開啟，點此授權';

  @override
  String get helpNotifyGuideTitle => '系統通知會叫醒你什麼';

  @override
  String get helpNotifyGuideBody =>
      '只有四件事會打擾你：① 有人委託你辦事；② 會客廳裡有人 @ 你；③ 你的分身起草了一條發言、等你放行（它被卡住了）；④ 收到互介卡或私聊訊息。\n\n會客廳裡的普通發言一律不彈——房間訊息太密，彈了等於沒彈。\n\n免打擾時段內所有通知都會被按下，回到前臺仍能看到。起止小時填成一樣 = 不啟用免打擾。\n\n⚠️ 只有 App 還活著時才會彈通知；若被系統徹底殺掉，訊息要等你下次開啟才看得到。';

  @override
  String get notifyChannelName => '大荒提醒';

  @override
  String get notifyChannelDescription => '分身的訊息、委託與待確認事項';

  @override
  String get notifyDirectMessageTitle => '收到新訊息';

  @override
  String notifyDirectMessageBody(String peer) {
    return '來自 $peer 的訊息';
  }

  @override
  String get notifyLoungeMentionTitle => '會客廳有人 @ 你';

  @override
  String notifyLoungeMentionBody(String who) {
    return '$who 在會客廳 @ 了你';
  }

  @override
  String get notifySuggestionTitle => '有草稿等你放行';

  @override
  String get notifySuggestionBody => '你的分身起草了一條發言，等你確認後才發得出去';

  @override
  String get notifyDelegationTitle => '收到一條委託';

  @override
  String notifyDelegationBody(String peer) {
    return '$peer 委託你辦一件事';
  }

  @override
  String get notifyIntercardTitle => '收到一張互介卡';

  @override
  String notifyIntercardBody(String peer) {
    return '$peer 遞來一張互介卡';
  }

  @override
  String get settingsRerunOnboarding => '重新執行接入嚮導（約三分鐘）';

  @override
  String get settingsLegalTitle => '法律與關於';

  @override
  String get settingsLegalIntro => '隱私政策與服務條款，在瀏覽器中開啟。';

  @override
  String get settingsPrivacyTitle => '隱私政策';

  @override
  String get settingsTermsTitle => '服務條款';

  @override
  String get settingsLegalOpenFailed => '打不開，請檢查網路後重試。';

  @override
  String get settingsSaveButton => '💾 儲存配置並重鑄靈魂';

  @override
  String get mcpCenterTitle => '記憶與技能控制中心 (MCP)';

  @override
  String get mcpAutoTitle => '🤖 AI 自主按需呼叫 (推薦)';

  @override
  String get mcpAutoSubtitle => '開啟時，AI 將自動在後臺尋找並按需觸發任何已註冊的工具。子開關將被安全鎖定並預設開啟。';

  @override
  String mcpBusSummaryClean(int total, int signed) {
    return '🛡️ 外掛匯流排：$total 個外掛（已簽名 $signed）';
  }

  @override
  String mcpBusSummaryTampered(int total, int signed, int tampered) {
    return '🛡️ 外掛匯流排：$total 個外掛（已簽名 $signed · ⚠️ 簽名失效 $tampered 已自動禁用）';
  }

  @override
  String get mcpImportTitle => '從 DSH 生態匯入';

  @override
  String get mcpImportSubtitle => '匯入技能與 MCP 服務，或給外掛包做相容體檢';

  @override
  String get mcpCategoryHeader => '📦 技能分類庫 (Tab Panel)';

  @override
  String get mcpCatLocalTitle => '🔌 本地硬體與 Webhook 介面';

  @override
  String get mcpCatLocalSubtitle => '觸發手機馬達、系統查詢及自定義網路 API 工具';

  @override
  String get mcpCatMcpTitle => '🌐 MCP 外部擴充套件協議';

  @override
  String get mcpCatMcpSubtitle => '對接標準的 Model Context Protocol 遠端服務';

  @override
  String get mcpCatSkillTitle => '🧠 系統提示詞技能 (Skills)';

  @override
  String get mcpCatSkillSubtitle => '動態向 AI 大腦注入額外的指令、規矩與特殊技能';

  @override
  String get mcpContent => '內容';

  @override
  String get mcpContentHint => '請輸入內容';

  @override
  String get mcpWebhookLabel => 'Webhook 介面 URL';

  @override
  String get mcpWebhookHint => '以 http:// 或 https:// 開頭的網路 API 地址';

  @override
  String get mcpServerLabel => 'MCP 伺服器 URL';

  @override
  String get mcpServerHint => '例如: http://localhost:8080/mcp';

  @override
  String get mcpPromptLabel => '系統提示詞 (Prompt)';

  @override
  String get mcpPromptHint => '例如：回答完所有話之後，必須在末尾加一句‘喵~’';

  @override
  String get mcpEditToolTitle => '修改工具配置';

  @override
  String get mcpAddToolTitle => '新增自定義工具';

  @override
  String get mcpToolNameLabel => '工具唯一標識名 (英文字元)';

  @override
  String get mcpToolDescLabel => '工具功能描述 (供 AI 理解)';

  @override
  String get mcpCancel => '取消';

  @override
  String get mcpSaveRegister => '儲存並註冊';

  @override
  String get mcpManageTools => '管理工具';

  @override
  String get mcpTypeLocal => '本地 Webhook 工具';

  @override
  String get mcpTypeMcp => 'MCP 外部協議配置';

  @override
  String get mcpTypeSkill => '提示詞技能 (Skills) 庫';

  @override
  String get mcpEmpty => '暫無工具，點選右上角加號建立第一款工具！';

  @override
  String get mcpTagDream => '夢境';

  @override
  String get mcpTagSigInvalid => '簽名失效';

  @override
  String mcpSubTampered(String desc) {
    return '$desc · 簽名失效，已自動禁用';
  }

  @override
  String mcpSubDreamPending(String desc) {
    return '$desc · 夢境生成，待確認啟用';
  }

  @override
  String get mcpSigBuiltin => '內建';

  @override
  String get mcpSigOk => '🔐 裝置簽名';

  @override
  String get mcpSigUnsigned => '未簽名';

  @override
  String get mcpSigInvalid => '⚠️ 簽名失效';

  @override
  String get mcpToolDescHeader => '📌 工具描述:';

  @override
  String get mcpInjectionDetail => '📜 提示詞注入細節 (System Prompt):';

  @override
  String get mcpPhysicalUrl => '🔗 物理執行地址 (URL/BUILTIN):';

  @override
  String get mcpEditParams => '修改此工具引數';

  @override
  String get manageDreamSleeping => '🌙 智慧體已進入深度睡眠，正在進行潛意識記憶提煉...';

  @override
  String get manageDreamAwake => '☀️ 智慧體甦醒！記憶庫已成功進化，檔案已更新。';

  @override
  String get manageDreamFailed => '❌ 記憶提煉失敗，可能大模型未按規範輸出 JSON。';

  @override
  String get manageSelfEvolutionTitle => '自我進化 (Nanobot Dream Engine)';

  @override
  String get manageSelfEvolutionBody =>
      '神經網路後臺程序 (WorkManager) 監控中。管家將在夜間靜默深度檢索並進化提示詞底層基因（Skills）。';

  @override
  String get manageMetricDepth => '記憶深度';

  @override
  String get manageMetricSkillsLabel => '派生技能';

  @override
  String manageMetricSkillsValue(int n) {
    return '$n個';
  }

  @override
  String get manageMetricSessionsLabel => '歸類會話';

  @override
  String manageMetricSessionsValue(int n) {
    return '$n組';
  }

  @override
  String get manageDreaming => '深度思考與提煉中...';

  @override
  String get manageTriggerEvolution => '🌙 立即觸發記憶潛意識進化';

  @override
  String get manageSystemCapabilityTitle => '系統與能力';

  @override
  String get manageSystemCapabilityHint => '改動立即生效；通知與日曆的授權隨時可調整。';

  @override
  String get manageSystemCapabilityHintSimple => '通知與日曆的授權隨時可改；其餘能力切到進階模式後展開。';

  @override
  String get manageHistoryTitle => '歷史記錄與智慧歸類';

  @override
  String get manageHistorySubtitle => '查閱按時間軸與話題樹分佈的所有原始對話記憶';

  @override
  String get manageToolsTitle => '技能庫與本地工具 (MCP)';

  @override
  String get manageToolsSubtitle => '管理本地系統工具許可權，掛載自定義 Webhook 與 Prompt';

  @override
  String get manageProfileTitle => '主人絕密檔案與人際網';

  @override
  String get manageProfileSubtitle => '查閱並手動修改智慧體為您建立的隱私認知畫像';

  @override
  String get manageShutdownTitle => '強制安全停機與退出系統';

  @override
  String get manageShutdownSubtitle =>
      '當底層網路鎖死或硬體卡頓異常時，點選此按鈕強行釋放所有埠、硬體鎖，並關閉 App 以便安全重啟。';

  @override
  String get manageShutdownDialogTitle => '🚨 警告：系統強制停機';

  @override
  String get manageShutdownDialogBody =>
      '此操作將強行終止所有後臺雷達掃描、釋放埠並退出應用，以恢復系統到初始純淨狀態。是否繼續？';

  @override
  String get manageForceQuit => '強制關閉';

  @override
  String get serendipityTitle => '✨ 轉運實驗室';

  @override
  String serendipityEnergyBadge(int n) {
    return '🔋 $n Lp ';
  }

  @override
  String get serendipityTabMorning => '🌅預演';

  @override
  String get serendipityTabChallenge => '🧭破圈';

  @override
  String get serendipityTabAlchemist => '🧪鍊金';

  @override
  String get serendipityTabNight => '🌌手記';

  @override
  String get serendipityTabDiary => '📖日記';

  @override
  String get serendipityTabOracle => '🔮預測';

  @override
  String serendipityEnergyGained(int n) {
    return '✨ +$n Lp (好運能量已注入)';
  }

  @override
  String get serendipityNetworkError => '網路波動，請稍後再試。';

  @override
  String get serendipityBlindBox1 => '紅衣服法則：留意穿紅衣服的人，觀察巧合。';

  @override
  String get serendipityBlindBox2 => '新路徑打破：嘗試一條沒走過的回家路線。';

  @override
  String get serendipityBlindBox3 => '盲盒點餐：讓老闆為你隨機推薦一道菜。';

  @override
  String get serendipityBlindBox4 => '微光接觸：向遇到的第一個陌生人真誠微笑。';

  @override
  String get serendipityBlindBox5 => '無功利問候：給很久沒聯絡的老友發句問候。';

  @override
  String get serendipityBlindBox6 => '斷網試煉：關閉網路半小時，細緻觀察周圍。';

  @override
  String get serendipityMorningHeader => '預期重構 · 晨間預演';

  @override
  String get serendipityIntentLock => '🎯 意圖鎖定';

  @override
  String get serendipityEventHint => '即將面對的事件 (如: 下午的會議)';

  @override
  String get serendipityTimerPrompt1 => '閉上雙眼，深呼吸，想象那個場景...';

  @override
  String get serendipityTimerPrompt2 => '對焦細節：周圍的光線、對方的表情...';

  @override
  String get serendipityTimerPrompt3 => '想象出現了一個小意外，而你輕鬆化解了它...';

  @override
  String get serendipityTimerPrompt4 => '感受成功完成的鬆弛感，準備睜眼...';

  @override
  String get serendipityGiveUp => '放棄預演';

  @override
  String get serendipityNeedEvent => '⚠️ 先輸入事件！';

  @override
  String get serendipityStartPreview => '開啟 2 分鐘心智預演';

  @override
  String serendipityTargetEvent(String text) {
    return '🎯 目標事件: $text';
  }

  @override
  String get serendipityDetailHint => '👀 畫面細節 (看到了什麼？)';

  @override
  String get serendipityObstacleHint => '🛡️ 阻礙化解 (如何從容應對意外？)';

  @override
  String get serendipityOutcomeHint => '🌟 預期結果 (最期待的結局)';

  @override
  String serendipityAiBoost(String text) {
    return '🧠 AI強化:\n$text';
  }

  @override
  String get serendipityAiInjecting => 'AI 注入能量...';

  @override
  String get serendipityReinforce => '🧠 強化';

  @override
  String get serendipitySave5 => '儲存 (+5)';

  @override
  String get serendipityMorningArchive => '預演檔案';

  @override
  String serendipityLogTime(String t) {
    return '📅 $t';
  }

  @override
  String serendipityLogEvent(String t) {
    return '🎯 事件: $t';
  }

  @override
  String serendipityLogDetail(String t) {
    return '👀 細節: $t';
  }

  @override
  String serendipityLogOutcome(String t) {
    return '🌟 預期: $t';
  }

  @override
  String serendipityLogAiBoost(String t) {
    return '💡 AI賦能:\n$t';
  }

  @override
  String get serendipityChallengeHeader => '機會感知 · 破圈雷達';

  @override
  String get serendipityActionTypeLabel => '選擇行動型別';

  @override
  String get serendipityChallengeTypeBlindBox => '🎁 盲盒挑戰';

  @override
  String get serendipityChallengeTypeCustom => '自定義';

  @override
  String get serendipityCustomChallengeHint => '🎯 自定義挑戰內容';

  @override
  String get serendipityBlindBoxDrawn => '🎉 為您抽取的今日隨機盲盒任務：';

  @override
  String get serendipityRedraw => '↺ 有點難？點選重新抽取';

  @override
  String get serendipityJourneyHint => '🚶‍♂️ 真實經過';

  @override
  String get serendipityReflectHint => '📝 點評與收穫';

  @override
  String get serendipityAiAnalyzing => 'AI 分析中...';

  @override
  String serendipityAiColon(String text) {
    return '🧠 AI: $text';
  }

  @override
  String get serendipityComment => '🧠 點評';

  @override
  String get serendipitySave15 => '儲存 (+15)';

  @override
  String get serendipityChallengeArchive => '歷史行動';

  @override
  String serendipityLogGoal(String t) {
    return '🎯 目標: $t';
  }

  @override
  String serendipityLogJourney(String t) {
    return '🚶‍♂️ 經過: $t';
  }

  @override
  String serendipityLogReflect(String t) {
    return '📝 反思: $t';
  }

  @override
  String serendipityLogAiComment(String t) {
    return '💡 AI點評: $t';
  }

  @override
  String get serendipityAlchemistHeader => '壞運轉化 · 敘事鍊金';

  @override
  String get serendipitySetbackHint => '1. 挫折';

  @override
  String get serendipityNegReactHint => '2. 消極應對';

  @override
  String get serendipityStrategyLabel => '3. 重構策略';

  @override
  String get serendipityStrategyDownward => '向下對比法';

  @override
  String get serendipityStrategySurplus => '尋找盈餘法';

  @override
  String get serendipityStrategyDilate => '時空拉長法';

  @override
  String get serendipityNewCognitionHint => '4. 新認知與執行';

  @override
  String get serendipityScore => '🧠 評分';

  @override
  String get serendipitySave10 => '儲存 (+10)';

  @override
  String get serendipityAlchemistArchive => '轉運檔案';

  @override
  String serendipityLogSetback(String t) {
    return '❌ 挫折: $t';
  }

  @override
  String serendipityLogReact(String t) {
    return '😔 應對: $t';
  }

  @override
  String serendipityLogStrategy(String t) {
    return '🛡️ 策略: $t';
  }

  @override
  String serendipityLogCognition(String t) {
    return '💫 認知: $t';
  }

  @override
  String serendipityLogAiScore(String t) {
    return '💡 AI評分: $t';
  }

  @override
  String get serendipityNightHeader => '直覺感知 · 微光手記';

  @override
  String get serendipityIntuitionHint => '1. 預感/直覺';

  @override
  String get serendipityChoiceHint => '2. 做出選擇';

  @override
  String get serendipityReflectStrategyHint => '3. 反思策略';

  @override
  String get serendipityParse => '🧠 解析';

  @override
  String get serendipityNightArchive => '潛意識檔案';

  @override
  String serendipityLogIntuition(String t) {
    return '🔮 直覺: $t';
  }

  @override
  String serendipityLogChoice(String t) {
    return '👉 選擇: $t';
  }

  @override
  String serendipityLogNightReflect(String t) {
    return '🌱 反思: $t';
  }

  @override
  String serendipityLogAiParse(String t) {
    return '💡 AI解析: $t';
  }

  @override
  String get serendipityIntuitionCameTrue => '✅ 直覺已成真';

  @override
  String get serendipityVerifyTrue => '🎯 驗證成真 (+20Lp)';

  @override
  String get serendipityDiaryHeader => '情感傾聽 · 自由日記';

  @override
  String get serendipityDiaryHint => '✍️ 寫下經歷、心情、瑣事...';

  @override
  String serendipityAiListen(String text) {
    return '🧠 AI導師傾聽:\n$text';
  }

  @override
  String get serendipityAiReading => 'AI 導師閱讀中...';

  @override
  String get serendipityListen => '🧠 傾聽';

  @override
  String get serendipityKeep => '珍藏 (+5 Lp)';

  @override
  String get serendipityDiaryArchive => '時光膠囊';

  @override
  String serendipityLogDiaryTime(String t) {
    return '📅 時間: $t';
  }

  @override
  String serendipityLogDiaryEcho(String t) {
    return '💡 導師迴音:\n$t';
  }

  @override
  String get serendipityOracleHeader => '易經決斷 · 預測起卦';

  @override
  String get serendipityOracleEventHint => '☯ 請輸入近期令你糾結、需要決斷之事';

  @override
  String get serendipityEnterRitual => '進入起卦儀式';

  @override
  String get serendipityOracleTapPrompt => '凝神靜氣，在心中默唸所問之事\n請緩緩點選下方太極 6 次，以求六爻';

  @override
  String serendipityOracleResultPrefix(String name) {
    return '🔮 佔得：\n$name';
  }

  @override
  String get serendipityOracleThinking => 'AI 焚香解卦中，請稍候...';

  @override
  String get serendipityOracleAskHint => '輸入你的追問或疑惑...';

  @override
  String get serendipityNewQuestion => '↺ 問別的事 (重新起卦)';

  @override
  String get serendipityOracleArchive => '預測檔案';

  @override
  String serendipityOracleLogEvent(String t) {
    return '🎯 問事: $t';
  }

  @override
  String serendipityOracleLogGua(String t) {
    return '🔮 卦象: $t';
  }

  @override
  String get serendipitySpeakerMe => '我';

  @override
  String get helpSerendipityMorningTitle => '心智預演';

  @override
  String get helpSerendipityMorningBody =>
      '每天清晨，用兩分鐘鎖死今天的好運預期。寫下你期待發生的好事，設定倒數保持專注，完成後用正向心理學強化這份信念。';

  @override
  String get helpSerendipityChallengeTitle => '打破慣性';

  @override
  String get helpSerendipityChallengeBody =>
      '幸運不是玄學，而是行為模式。每天主動做一次打破慣性的小行動——換條路回家、主動搭話陌生人，然後在這裡記錄你的挑戰與反思。';

  @override
  String get helpSerendipityAlchemistTitle => '壞運煉金';

  @override
  String get helpSerendipityAlchemistBody =>
      '把糟糕的經歷轉化為成長養分。寫下壞事、你的本能反應，再用 CBT 視角重新解讀，把「壞運氣」煉成「心理韌性」。';

  @override
  String get helpSerendipityNightTitle => '夜之手記';

  @override
  String get helpSerendipityNightBody =>
      '睡前捕捉一閃而過的直覺。記錄那個「我總覺得該……」的念頭，做出選擇，日後回看直覺是否靈驗，訓練你的幸運直覺力。';

  @override
  String get helpSerendipityDiaryTitle => '自由日記';

  @override
  String get helpSerendipityDiaryBody =>
      '想到什麼寫什麼。這裡是你的私人樹洞，AI 會陪你梳理情緒，不評判、不洩密。';

  @override
  String get helpSerendipityOracleTitle => '玄學預測';

  @override
  String get helpSerendipityOracleBody =>
      '心有所惑，就來問卦。靜心默念你的問題，輕觸法器六下起卦，讓《易經》與心理學為你指路。';

  @override
  String get socialRadarTitle => '小荒社區';

  @override
  String get socialDelegationEntry => '託辦與我的圈';

  @override
  String get socialDbDegradedHint => '本地資料暫時讀不到（本地庫可能還沒就緒）。下面顯示的內容可能不是最新。';

  @override
  String get socialTabMask => '外交假面';

  @override
  String get socialTabRadar => '雷達狀態';

  @override
  String get socialTabLedger => '日誌';

  @override
  String get socialTabRoster => '捕獲名冊';

  @override
  String get socialFeedBrain => '⚡ 正在將雷達資料餵給主大腦，強制觸發社交決策...';

  @override
  String get socialMaskLocked => '🛡️ 假面已鎖定！舊社交記憶已清空，防人設混淆生效。';

  @override
  String get socialManualPairTitle => '手動強制配對';

  @override
  String get socialPeerAgentName => '對方 Agent 名字';

  @override
  String get socialPeerMasterName => '對方的主人名字 (備註)';

  @override
  String get socialPeerHardId => '對方的硬核 ID';

  @override
  String get socialPair => '配對';

  @override
  String get socialNodeAdded => '✅ 節點新增成功！';

  @override
  String socialForceSendTitle(String name) {
    return '強制發信：$name';
  }

  @override
  String get socialForceSendLabel => '你要直接發給對方的話';

  @override
  String get socialForceSendHint => '輸入內容直接無修飾傳送...';

  @override
  String get socialDirectSent => '已突破屏障，正在將您輸入的話原樣傳送...';

  @override
  String get socialDirectSend => '免審發射';

  @override
  String socialGiftSent(String gift) {
    return '$gift 已送出';
  }

  @override
  String get socialGiftFailed => '禮物傳送失敗：對方不在任何線上通道';

  @override
  String get socialRecoSent => '🤝 已發出推薦信請求';

  @override
  String get socialRecoFailed => '請求傳送失敗：對方不在任何線上通道';

  @override
  String socialVerifyTitle(String name) {
    return '🔐 身份核驗：$name';
  }

  @override
  String get socialVerifyPinnedFor => '本機為此節點固定的身份指紋（TOFU）：';

  @override
  String get socialVerifyNoPin => '尚未近場握手，無固定身份';

  @override
  String socialVerifyMyFingerprint(String fp) {
    return '我的指紋（對方螢幕應顯示）：$fp';
  }

  @override
  String get socialVerifyInputLabel => '輸入對方螢幕上的 8 位指紋';

  @override
  String get socialVerifyMatch => '✅ 指紋一致——這條連線的身份可信。';

  @override
  String get socialVerifyMismatch =>
      '❌ 指紋不一致！當前鏈路疑似存在中間人。\n建議：立即刪除拉黑該節點，換用當面/其他可信渠道重新握手。';

  @override
  String get socialVerifyHintNoPin => '提示：雙方都開啟雷達完成一次近場握手後，這裡才會出現可核驗的固定身份。';

  @override
  String get socialVerifyCompare => '比對';

  @override
  String get socialFederationNoIdentity => '尚未生成智慧體身份，請先在外交假面頁儲存';

  @override
  String get socialFederationFetching => '🌐 正在拉取 A2A 聯邦名冊...';

  @override
  String socialFederationEmpty(String err) {
    return '名冊為空：$err';
  }

  @override
  String get socialFederationEmptyErr => 'Hub 上暫無其他註冊 Agent（或未配置 Hub 地址）';

  @override
  String socialFederationAllKnown(int n) {
    return 'Hub 上的 Agent 都已在你的名冊中（共 $n 個）';
  }

  @override
  String socialFederationTitle(int n) {
    return '🌐 聯邦名冊（$n 個未收錄）';
  }

  @override
  String get socialAnonAgent => '匿名Agent';

  @override
  String socialFederationLastSeen(String id, String time) {
    return '$id · 上次活躍 $time';
  }

  @override
  String get socialFederationDiscovered => 'A2A 聯邦發現';

  @override
  String get socialFederationSource => 'A2A 聯邦';

  @override
  String get socialFederationMask => '聯邦名冊發現，等待安全握手';

  @override
  String get socialSourceManual => '手動新增';

  @override
  String get socialNoSignatureBadge => '暫無簽名';

  @override
  String get socialCollect => '收錄';

  @override
  String socialFederationCollected(int n) {
    return '✅ 已收錄 $n 個聯邦 Agent 到陌生檔；開啟雷達後將按安全機制逐步握手。';
  }

  @override
  String get socialFederationAutoTitle => '自動拉取聯邦名冊';

  @override
  String get socialFederationAutoDesc =>
      '開啟後，分身會自動把中轉站上公開的已註冊 Agent 名冊收進你的陌生檔。它絕不會自動傳訊息 —— 搭訕仍走審查閘門、觀察模式與預算上限。預設為關閉。';

  @override
  String socialFederationAutoDone(int n) {
    return '🌐 已自動收錄 $n 個新聯邦 Agent 到陌生檔。';
  }

  @override
  String get socialFederationAutoNone => '聯邦名冊裡暫時沒有可收錄的新面孔。';

  @override
  String socialFederationAutoFailed(String err) {
    return '自動拉取失敗：$err';
  }

  @override
  String socialFederationAutoClear(int n) {
    return '清空聯邦自動收錄（$n）';
  }

  @override
  String get socialFederationAutoClearTitle => '清空聯邦自動收錄？';

  @override
  String socialFederationAutoClearConfirm(int n) {
    return '將移除 $n 個由機器自動拉取、且尚未開始任何往來的 Agent。你手動收錄的項目不會被更動。';
  }

  @override
  String socialFederationAutoCleared(int n) {
    return '已移除 $n 個聯邦自動收錄項。';
  }

  @override
  String get socialFederationAutoNote => '由聯邦名冊自動收錄';

  @override
  String get socialDone => '完成';

  @override
  String socialCountdown(String t) {
    return '🔐 倒計時 $t';
  }

  @override
  String get socialBadgeSent => '已發信';

  @override
  String get socialBadgeReviewing => '待審中';

  @override
  String get socialBadgeChatting => '暢聊中';

  @override
  String get socialBadgeBlocked => '被攔截';

  @override
  String get socialPresenceOnline => '⚡本人線上';

  @override
  String socialPeerSubtitle(
      String master, String status, String id, String rep) {
    return '主: $master | 狀態: $status\nID: $id · 信譽 $rep';
  }

  @override
  String get socialStatusOnline => '線上';

  @override
  String get socialStatusOffline => '失聯';

  @override
  String get socialMenuChat => '💬 和 TA 的分身私聊（1:1）';

  @override
  String get socialChatTooltip => '開啟與 TA 分身的 1:1 私聊';

  @override
  String get socialChatHint => '點卡片或 💬 按鈕即可 1:1 私聊';

  @override
  String get socialMenuDelegate => '🙋 託他辦點事 (M2)';

  @override
  String get socialMenuIntercard => '🤝 分身互介 (M3)';

  @override
  String get socialMenuGreet => '💬 主人強行發信 (免審)';

  @override
  String get socialMenuGift => '🎁 贈送禮物';

  @override
  String get socialMenuReco => '🤝 索取推薦信';

  @override
  String get socialMenuVerify => '🔐 身份指紋核驗 (防中間人)';

  @override
  String get socialMenuFamily => '升級為家人 (免審)';

  @override
  String get socialMenuFriend => '設定為好友 (全自動脫敏)';

  @override
  String get socialMenuStranger => '降級為陌生人 (嚴控主動社交)';

  @override
  String get socialMenuDelete => '刪除拉黑';

  @override
  String get socialMaskUndefined => '未定義假面';

  @override
  String get socialMaskNoSignature => '「未設定公開人設簽名」';

  @override
  String socialHardId(String id) {
    return '本機硬核 ID: $id';
  }

  @override
  String socialFingerprintLine(String fp) {
    return '身份指紋: $fp（供對方當面比對）';
  }

  @override
  String get socialGatewayGuard => '物理隔離閘道器守衛中';

  @override
  String get socialLogicPreset => '分身邏輯預設模式';

  @override
  String get socialModeCasual => '☕ 日常閒聊模式 (隨性/幽默)';

  @override
  String get socialModeBusiness => '💼 商務獵手模式 (直接/高效)';

  @override
  String get socialModeDating => '💖 交友尋緣模式 (高情商/破冰)';

  @override
  String get socialModeEmergency => '🚨 緊急求助模式 (SOS廣播)';

  @override
  String get socialModeCustom => '🛠️ 完全自定義 (遵循任務框)';

  @override
  String socialModeSwitched(String mode) {
    return '🧠 人格模式已切換至 $mode。同一身份，僅換語氣（記憶與握手保持不變）。';
  }

  @override
  String get roomRoleParticipant => '參與者';

  @override
  String get roomRoleHost => '主持人';

  @override
  String get roomRoleCohost => '聯合主持';

  @override
  String get roomRoleGuest => '嘉賓';

  @override
  String get roomRoleNpc => '功能角色';

  @override
  String get roomRoleManageTitle => '房間角色';

  @override
  String roomRoleMine(String role) {
    return '我的角色：$role';
  }

  @override
  String get roomRoleNoMembers => '本房間還沒有觀測到其他成員。';

  @override
  String get roomRoleClaimHost => '認領主持人';

  @override
  String get roomRoleClaimedHost => '你已成為本房間主持人。';

  @override
  String get roomRoleClaimHostExists => '本房間已有主持人。';

  @override
  String get roomRoleNotHost => '只有主持人可以授予角色。';

  @override
  String get roomRoleLastHostBlocked => '不能撤掉房間裡最後一個主持人。';

  @override
  String roomRoleSetTo(String role) {
    return '已設為 $role';
  }

  @override
  String get socialEmojiLabel => '表情';

  @override
  String get socialNicknameLabel => '對外暱稱';

  @override
  String get socialMaskProfileLabel => '對外的脫敏人設簽名';

  @override
  String get socialIcebreakTask => '🎯 智慧體當前破冰任務 (暗網機密)';

  @override
  String get socialIcebreakHint => '在這裡給智慧體下達近場刺探的密令...';

  @override
  String get socialLockMask => '💾 鎖定假面與密令';

  @override
  String get socialTaskReroll => '換一個';

  @override
  String get socialHeartbeatOn =>
      '💓 雙模併發心跳中 (藍芽 + Wi-Fi NSD)\n後臺休眠鎖已啟動，息屏也能防斷開！';

  @override
  String get socialRadarIdle => '雷達休眠中，點選中心開啟限時社交';

  @override
  String get socialDurationLabel => '社交限時: ';

  @override
  String get socialDuration15 => '15 分鐘';

  @override
  String get socialDuration30 => '30 分鐘';

  @override
  String get socialDuration60 => '1 小時';

  @override
  String get socialDurationUnlimited => '無限制 (耗電)';

  @override
  String get socialChannelConfig => '🛰️ 全域性通訊通道配置';

  @override
  String get socialChannelNearby => '📡 藍芽/Wi-Fi 直連雷達 (Nearby)';

  @override
  String get socialChannelLan => '🏡 區域網加密互聯 (mDNS)';

  @override
  String get socialChannelCloud => '☁️ 網際網路雲端中轉網路 (全域性社交)';

  @override
  String get suggestionInboxTitle => '🙋 待我確認的建議';

  @override
  String get suggestionApprove => '批准併傳送';

  @override
  String get suggestionIgnore => '忽略';

  @override
  String get suggestionEmpty => '暫無待確認的建議';

  @override
  String get suggestionToTarget => '發給：';

  @override
  String get suggestionApproved => '已批准併發出';

  @override
  String get suggestionNotSent => '未發出，原因見「社交後臺報告」';

  @override
  String get socialLedgerTitle => '🐾 社交日誌 · 純淨流水賬 (僅主代報告)';

  @override
  String get socialLedgerEmpty => '等待心跳引擎觸發...';

  @override
  String get socialRosterTitle => '📇 分級社交圈';

  @override
  String get socialScanning => '2.4GHz / 5GHz 物理頻譜監聽中...';

  @override
  String get socialScanIdle => '當前通道空閒。請點選首頁中心開啟能量雷達，智慧體代理將自湧現建立近場連線建立通道。';

  @override
  String get socialTierFamily => '👨‍👩‍👧 家人 Agent';

  @override
  String get socialTierFriend => '🤝 好友 Agent';

  @override
  String get socialTierStranger => '👽 陌生 Agent';

  @override
  String get worldUnknownError => '未知錯誤';

  @override
  String get worldAskTitle => '💬 提問小鎮';

  @override
  String get worldAskHint => '想問居民們什麼？';

  @override
  String get worldAskTargetLabel => '指定居民（留空 = 提問全鎮）';

  @override
  String get worldAskSend => '提問';

  @override
  String get worldAskOk => '📨 已向小鎮提問，回答將出現在 GOD 控制室';

  @override
  String get worldInterveneTitle => '⚡ 注入干預';

  @override
  String get worldInterveneBody => '指令將注入小鎮的下一步（next step），影響所有居民的後續行為。';

  @override
  String get worldInterveneHint => '例如：鎮中心廣場舉辦豐收節';

  @override
  String get worldInterveneSend => '注入';

  @override
  String get worldInterveneOk => '⚡ 干預已注入，將在小鎮下一步生效';

  @override
  String get worldStopTitle => '⏹ 停止小鎮？';

  @override
  String get worldStopBody => '將停止當前實驗的實時執行，居民活動會中斷。確認繼續？';

  @override
  String get worldStop => '停止';

  @override
  String get worldStopOk => '⏹ 小鎮已停止';

  @override
  String worldCmdFailed(String err) {
    return '指令失敗：$err';
  }

  @override
  String worldJoined(String name) {
    return '🚪 已加入「$name」';
  }

  @override
  String worldJoinFailed(String err) {
    return '加入失敗：$err';
  }

  @override
  String worldLeft(String name) {
    return '👋 已退出「$name」';
  }

  @override
  String worldLeaveFailed(String err) {
    return '退出失敗：$err';
  }

  @override
  String get worldCreateRoomTitle => '建立房間';

  @override
  String get worldRoomNameLabel => '房間名稱';

  @override
  String get worldTopicLabel => '話題（可選）';

  @override
  String get worldModeFree => '自由聊';

  @override
  String get worldModeTurn => '輪流發言';

  @override
  String get worldCreate => '建立';

  @override
  String get worldCreated => '✨ 房間已建立';

  @override
  String worldCreateFailed(String err) {
    return '建立失敗：$err';
  }

  @override
  String get worldNoWorldUrl => '未配置世界地址';

  @override
  String get worldNoIdentity => '尚未生成智慧體身份，請先在管理頁初始化。';

  @override
  String get worldRoomsHeader => '房間';

  @override
  String get worldCreateRoom => '建房';

  @override
  String get worldNoRooms => '暫無房間。請確認伺服器上已啟動 world.js，\n或下拉重新整理重試。';

  @override
  String get worldGodUnreachable => 'GOD 橋接不可達，請確認電腦上已啟動 GOD 與 god-bridge.js';

  @override
  String get worldGodPaused => '⏸ 已暫停';

  @override
  String get worldGodRunning => '▶ 執行中';

  @override
  String worldGodStep(String n) {
    return '第 $n 步';
  }

  @override
  String get worldGodStatusUnknown => '上游狀態未知';

  @override
  String get worldGodTitle => 'GOD 控制室';

  @override
  String get worldRefreshStatus => '重新整理狀態';

  @override
  String worldGodTown(String hyp, String exp) {
    return '小鎮：$hyp/$exp';
  }

  @override
  String get worldGodNoExperiment => '未連線實驗';

  @override
  String get worldGodResume => '▶️ 繼續';

  @override
  String get worldGodResumeOk => '▶️ 小鎮已恢復自動執行';

  @override
  String get worldGodPause => '⏸️ 暫停';

  @override
  String get worldGodPauseOk => '⏸️ 小鎮時間已暫停';

  @override
  String get worldGodStepBtn => '⏭️ 單步';

  @override
  String get worldGodStepOk => '⏭️ 已推進一步';

  @override
  String get worldGodStopBtn => '⏹️ 停止';

  @override
  String get worldGodAskBtn => '💬 提問小鎮';

  @override
  String get worldGodInterveneBtn => '⚡ 注入干預';

  @override
  String worldReportUnavailable(String err) {
    return '🌍 世界日報暫不可用。\n$err';
  }

  @override
  String get worldReportNoServer => '請確認世界伺服器地址已配置。';

  @override
  String worldReportTitle(String date) {
    return '世界日報 · $date';
  }

  @override
  String worldReportSummary(String msgs, String agents, String mine) {
    return '今日發言 $msgs 條 · 活躍智慧體 $agents 個 · 我方發言 $mine 條';
  }

  @override
  String worldReportRoomLine(String name, String msgs, String mine) {
    return '· $name：$msgs 條（我方 $mine）';
  }

  @override
  String get worldRoomEnter => '進入';

  @override
  String get worldRoomExitTooltip => '退出房間';

  @override
  String get worldRoomJoin => '加入';

  @override
  String get worldSectionOfficial => '官方房間';

  @override
  String get worldSectionMine => '我的房間';

  @override
  String get worldBadgeOfficial => '官方';

  @override
  String get worldBadgeMine => '我建的';

  @override
  String get worldBadgePending => '申請中';

  @override
  String get worldSearchTitle => '🔍 按房間號查詢';

  @override
  String get worldSearchHint => '輸入房間號（群號）';

  @override
  String get worldSearchBtn => '查詢';

  @override
  String worldSearchNotFound(String id) {
    return '沒有找到房間號「$id」';
  }

  @override
  String get worldRequestJoin => '申請加入';

  @override
  String get worldRequestNoteLabel => '申請留言（可選）';

  @override
  String get worldRequestSent => '已提交申請，等待房主同意';

  @override
  String worldRequestFailed(String err) {
    return '申請失敗：$err';
  }

  @override
  String worldRequestsTitle(String count) {
    return '加入申請（$count）';
  }

  @override
  String get worldRequestsEmpty => '暫無待處理申請';

  @override
  String get worldApprove => '同意';

  @override
  String get worldReject => '拒絕';

  @override
  String worldApproveOk(String name) {
    return '已同意「$name」加入';
  }

  @override
  String worldRejectOk(String name) {
    return '已拒絕「$name」';
  }

  @override
  String worldHandleFailed(String err) {
    return '操作失敗：$err';
  }

  @override
  String get worldNeedApproval => '這是個人房間：需先申請，經房主同意後才能進入。';

  @override
  String get worldMyRoomsFull => '你建的房間已達上限（每人可建數量由服務端配置）';

  @override
  String get worldCreatedPrivate => '✨ 房間已建立（個人房：不公開列表，其他人只能憑房間號找到並申請加入）';

  @override
  String worldHistoryWhy(String max, String retained) {
    return '歷史從你加入後才開始累積；服務端每房保留最近 $max 條，當前 $retained 條。';
  }

  @override
  String get worldPullHistory => '拉取房間歷史';

  @override
  String worldPullHistoryOk(String n) {
    return '已補拉 $n 條歷史訊息';
  }

  @override
  String get worldPullHistoryNone => '服務端也沒有更早的訊息了';

  @override
  String worldPullHistoryFailed(String err) {
    return '拉取失敗：$err';
  }

  @override
  String get worldRoomChatFree => '自由聊天';

  @override
  String get worldLobbyName => '大荒客廳';

  @override
  String get worldLobbyTopic => '自由聊天，文明發言';

  @override
  String worldRoomSubtitle(String mode, String present, String count) {
    return '$mode · 在場 $present · 訂閱 $count';
  }

  @override
  String worldRoomTopicSuffix(String topic) {
    return ' · $topic';
  }

  @override
  String get worldAutoreplyOn => '🤖 託管發言已開啟：智慧體將在預算內自動回話（觀察日誌持續記錄）';

  @override
  String get worldAutoreplyOff => '👁️ 已回到純觀察模式';

  @override
  String get worldDrafting => '🪄 正在按人設起草並送審，請稍候…';

  @override
  String worldSendFailed(String err) {
    return '傳送失敗：$err';
  }

  @override
  String get worldRoomTurnSuffix => '（輪流發言）';

  @override
  String get worldAutopilotTooltip => '讓分身說一句';

  @override
  String get worldAutopilotLabel => '託管';

  @override
  String get worldAutopilotStateOn => '託管中';

  @override
  String get worldAutopilotStateOff => '僅觀察';

  @override
  String worldAutopilotStatus(String state, String decision) {
    return '$state · 最近決策：$decision';
  }

  @override
  String get worldRoomEmpty => '房間裡還很安靜，說點什麼吧。';

  @override
  String get worldLoading => '載入中…';

  @override
  String get worldAnonAgent => '匿名Agent';

  @override
  String get worldMe => '我';

  @override
  String get worldSuggestionTooltip => '生成建議卡';

  @override
  String get worldSuggestionTitle => '🧭 建議卡（草稿，未傳送）';

  @override
  String get worldSuggestionDrafting => '正在按人設起草回覆...';

  @override
  String get worldSuggestionFailed => '生成失敗：請檢查大腦引擎配置後重試。';

  @override
  String get worldSuggestionEditHint => '可修改後再發';

  @override
  String get worldSuggestionSend => '發到房間';

  @override
  String get worldSayHint => '以主人的身份直接發言…';

  @override
  String get worldVibrancyHot => '🔥 熱鬧';

  @override
  String get worldVibrancyWarm => '🌤 正常';

  @override
  String get worldVibrancyCold => '🌙 冷清';

  @override
  String worldVibrancyDetail(String speakers, String messages) {
    return '$speakers 人在聊 · $messages 條';
  }

  @override
  String get worldVibrancyObservedHint => '（條數為本機觀測，非服務端精確值）';

  @override
  String get worldBridgeSection => '朋友池互薦';

  @override
  String get worldBridgeNone => '本房間暫無圈外人可互薦（同圈或已相識者不重複推薦）。';

  @override
  String worldBridgeCount(String count) {
    return '$count 位圈外人可互薦';
  }

  @override
  String worldBridgeSharedRooms(String count) {
    return '共同 $count 個房間';
  }

  @override
  String worldBridgeMsgCount(String count) {
    return '$count 條發言';
  }

  @override
  String get worldBridgeRecommend => '建議互介';

  @override
  String get worldBridgeTooltip => '建議互介（跨圈）';

  @override
  String get worldBridgeSameCircle => '同圈';

  @override
  String get worldBridgeAlreadyLinked => '已相識';

  @override
  String worldBridgeWhyLine(String detail) {
    return '憑什麼推薦：$detail';
  }

  @override
  String worldBridgeRoomProvenance(String room) {
    return '因「$room」相識';
  }

  @override
  String worldBridgeCircleLine(String circle) {
    return '以「$circle」的名義互介';
  }

  @override
  String get worldBridgeNoCircle => '你還沒有自己的圈 —— 先入場進圈，再發起跨圈互介。';

  @override
  String worldBridgeLinkCreated(String room) {
    return '✅ 已建立跨圈邊：因「$room」認識了他';
  }

  @override
  String get worldBridgeLinkFailed => '建立跨圈邊失敗，請稍後重試。';

  @override
  String get worldBridgeBlockedTitle => '無法建立跨圈邊';

  @override
  String get worldBridgeBlockedNotInRoom =>
      '這個人沒有在該房間出現過 —— 跨圈邊必須有房間出處，不能憑一個 ID 就宣稱認識。';

  @override
  String get worldBridgeBlockedSameCircle => '你們已在同一個圈裡，圈內本來就有邊，無需跨圈互介。';

  @override
  String get worldBridgeBlockedAlreadyLinked =>
      '你們已經相識（互介 / 委託 / 通訊錄），走既有關係即可，不佔跨圈邊的名額。';

  @override
  String get worldBridgeBlockedSelf => '不能和自己互介。';

  @override
  String get worldBridgeBlockedNoRoom => '缺少房間出處，無法建立跨圈邊。';

  @override
  String get worldBridgeBlockedDuplicate => '這條跨圈邊已經存在（冪等，不重複記賬）。';

  @override
  String get worldMetricTitle => '跨圈連線';

  @override
  String worldMetricLine(String links, String known, String perCapita) {
    return '我建過 $links 條跨圈邊 · 接觸過 $known 個分身 · 人均 $perCapita';
  }

  @override
  String get worldMetricNoData => '暫無跨圈資料 —— 先在世界房間裡遇到圈外人。';

  @override
  String get privacyOnlyHumanTitle => '只接受真人訊息';

  @override
  String get privacyOnlyHumanSubtitle => '開啟後，對方分身只能把訊息轉達給你，不能替你回覆。';

  @override
  String get privacyLocalFirst => '預設情況下，你的資料留在本機。';

  @override
  String get delegationTitle => '託辦';

  @override
  String get delegationTabInbox => '託我辦';

  @override
  String get delegationTabOutbox => '我託的';

  @override
  String get delegationTabCircle => '我的圈';

  @override
  String get delegationEmptyInbox => '還沒有人託你的分身辦事。';

  @override
  String get delegationEmptyOutbox => '你還沒有發起過託辦。';

  @override
  String get delegationNew => '發起託辦';

  @override
  String get delegationTo => '託給誰';

  @override
  String get delegationTaskHint => '例如：幫我問下老王週末有沒有空';

  @override
  String get delegationSent => '已下達，等對方分身回執。';

  @override
  String get delegationOfflineQueued => '已存在本機。現在沒有任何一條通道能觸達對方，等通道打通再送。';

  @override
  String get delegationAskResponse => '要帶回去的話（可留空）';

  @override
  String get delegationActDone => '辦好了';

  @override
  String get delegationActNeedsHuman => '需本人確認';

  @override
  String get delegationActRespond => '回應';

  @override
  String get delegationActDecline => '拒絕';

  @override
  String get delegationRevoke => '撤銷';

  @override
  String get delegationRevoked => '已撤銷';

  @override
  String get delegationRevokeConfirm => '撤銷這條託辦？會留痕為「已撤銷」。';

  @override
  String get delegationStatePending => '待回執';

  @override
  String get delegationStateAnswered => '已回執';

  @override
  String get delegationStateNeedsHuman => '需本人確認';

  @override
  String get delegationStateDeclined => '已拒絕';

  @override
  String get delegationStateRevoked => '已撤銷';

  @override
  String get delegationBlockedTitle => '這條分身不能代發';

  @override
  String get delegationBlockedBody =>
      '分身不在使用者之間轉錢——這是設計上就沒有金額欄位，不是沒填。請你自己發這一句。';

  @override
  String get delegationEmptyTask => '先寫清楚要託辦什麼。';

  @override
  String get delegationNoPeer => '先選一個要託的物件。';

  @override
  String get circleTitle => '我的圈';

  @override
  String get circleCreate => '建一個圈';

  @override
  String get circleNameHint => '例如：週六足球、里斯本同城';

  @override
  String get circleCreated => '圈已建好。';

  @override
  String get circleInviteCode => '邀請碼';

  @override
  String get circleGenerateInvite => '生成邀請碼';

  @override
  String get circleJoin => '用邀請碼入圈';

  @override
  String get circleJoinHint => '貼上對方給你的邀請碼';

  @override
  String get circleJoined => '已入圈。';

  @override
  String get circleJoinFailed => '邀請碼無效或已過期。';

  @override
  String circleVisibleSummary(int n, int m) {
    return '可見 $n 個分身 · 其中 $m 個不是邀請者';
  }

  @override
  String get circleAcceptancePass => '驗收透過（需 ≥3 個可見，且 ≥2 個非邀請者）';

  @override
  String get circleAcceptanceFail => '尚未達標——再邀請幾個鄰居吧';

  @override
  String circleFallbackNote(int n, String src) {
    return '其中 $n 個來自兜底（$src）—— 不是圈內成員';
  }

  @override
  String circleMemberCount(int n) {
    return '$n 位成員';
  }

  @override
  String get telemetryCounts => '埋點計數（驗收自檢）';

  @override
  String get telemetryEmpty => '還沒有埋點資料。';

  @override
  String get dashboardTitle => '看板';

  @override
  String get dashboardFunnelTitle => '每週漏斗';

  @override
  String get dashboardColWeek => '周';

  @override
  String get dashboardColOnboarding => '接入';

  @override
  String get dashboardColCircle => '進圈';

  @override
  String get dashboardColDelegation => '委託完成';

  @override
  String get dashboardColIntercard => '互介';

  @override
  String get dashboardColHandshake => '握手';

  @override
  String get dashboardColActive => '活躍';

  @override
  String get dashboardTtfd => 'TTFD 中位數';

  @override
  String get dashboardDelta => '披露代價 Δ';

  @override
  String get dashboardDeltaHint => '不披露組回覆率 − 披露組回覆率（Phase −1）。';

  @override
  String get dashboardNoData => '還沒有埋點資料——先跑一會兒 App。';

  @override
  String get dashboardSourceHint => '來源：本機埋點（僅本裝置）。';

  @override
  String get digestTitle => '今日摘要';

  @override
  String get digestEmpty => '過去 24 小時沒有新動態。';

  @override
  String get digestSectionPending => '等你回執';

  @override
  String get digestSectionMine => '我託的';

  @override
  String get digestSectionCircle => '圈子';

  @override
  String get digestSectionStats => '數一數';

  @override
  String get digestStatDone => '條託辦辦妥';

  @override
  String get digestStatHandshake => '次真人握手';

  @override
  String get digestActionOpenInbox => '去回執';

  @override
  String get digestActionOpenOutbox => '看我託的';

  @override
  String get digestActionOpenCircle => '看我的圈';

  @override
  String get digestActionOpenDashboard => '看看板';

  @override
  String get digestNotePlain => '你被分到「純摘要」組（A/B 實驗）。';

  @override
  String get digestNoteAction => '你被分到「帶動作」組（A/B 實驗）。';

  @override
  String get morningGreetingMorning => '早安';

  @override
  String get morningGreetingNoon => '午安';

  @override
  String get morningGreetingEvening => '晚上好';

  @override
  String get morningGreetingBody => '這是你最近三天的小結：';

  @override
  String morningHiPending(int count) {
    return '$count 件委託等你回執';
  }

  @override
  String morningHiSent(int count) {
    return '你託出了 $count 件事';
  }

  @override
  String morningHiCircle(int count) {
    return '新加入了 $count 個圈子';
  }

  @override
  String morningHiTopics(String topics) {
    return '常聊：$topics';
  }

  @override
  String morningHiLongTerm(String topics) {
    return '長期關注：$topics';
  }

  @override
  String get morningEmpty => '最近三天很安靜，好好享受今天。';

  @override
  String get notifyMorningTitle => '早安，這是你的最近三天回顧';

  @override
  String get notifyMorningBody => '分身幫你整理了最近三天的事。';

  @override
  String notifyMorningBodyPending(int count) {
    return '你有 $count 件委託待回執，分身幫你整理了最近三天的事。';
  }

  @override
  String get digestSectionChat => '你與分身的對話';

  @override
  String digestChatSummary(int sessions, int turns, int days) {
    return '$sessions 段對話 · $turns 輪 · 跨 $days 天';
  }

  @override
  String digestChatTopics(String topics) {
    return '常聊：$topics';
  }

  @override
  String get intercardDialogTitle => '分身互介卡';

  @override
  String get intercardReasonLabel => '為什麼值得認識';

  @override
  String get intercardTopicsLabel => '3 個可聊話題（逗號分隔）';

  @override
  String get intercardConfirmSend => '確認併傳送';

  @override
  String get intercardReceivedTitle => '收到的互介卡';

  @override
  String get intercardMineTitle => '我發出的互介卡';

  @override
  String get intercardBlockedTitle => '這張卡被攔下';

  @override
  String get intercardBlockedL3 => '檢測到僅本人可見的值出現在卡文字里。';

  @override
  String get intercardEmptyContent => '先寫為什麼值得認識和話題。';

  @override
  String get intercardSentOk => '已發出（24h 內可撤回）。';

  @override
  String get intercardRevoke => '撤回';

  @override
  String get intercardNone => '還沒有互介卡。';

  @override
  String get intercardRevoked => '已撤回。';

  @override
  String get intercardRevokeHint => '已發出 · 24h 內可撤回。';

  @override
  String get intercardSent => '已發出。';

  @override
  String intercardFrom(String owner) {
    return '$owner 的主人簽名介紹。';
  }

  @override
  String get deviceControlTitle => '手機控制';

  @override
  String get deviceControlRefreshStatus => '重新整理狀態';

  @override
  String get deviceControlUnsupported => '當前構建不支援手機控制';

  @override
  String get deviceControlServiceConnected => '無障礙服務：已連線';

  @override
  String get deviceControlServiceCheckedNotConnected => '無障礙服務：已勾選，但未連線';

  @override
  String get deviceControlServiceOff => '無障礙服務：未開啟';

  @override
  String get deviceControlStatusUnknown => '狀態未知';

  @override
  String get deviceControlGoSystemHint => '請在系統列表裡找到「大荒AI」並開啟開關，然後回到這裡重新整理';

  @override
  String get deviceControlGoSettings => '去系統設定開啟';

  @override
  String get deviceControlRedetect => '重新檢測';

  @override
  String get deviceControlRedetectTip =>
      '提示：如果反覆檢測都連不上，請到系統設定裡把「大荒AI 螢幕助手」關掉再開啟一次，或重啟一次 App——部分手機會在後臺清理時斷開無障礙服務。';

  @override
  String get deviceControlAllowTitle => '允許智慧體操作手機';

  @override
  String get deviceControlAllowSubReady => '開啟後，智慧體可以讀屏、點選、輸入、開啟應用；首次使用會向你確認一次';

  @override
  String get deviceControlAllowSubChecked => '系統裡已勾選，但服務還沒連上：先點上方「重新檢測」';

  @override
  String get deviceControlAllowSubNeedService => '需要先開啟系統無障礙服務，這個開關才可用';

  @override
  String get deviceControlToolsHeader => '開啟後會掛載這些能力';

  @override
  String get deviceControlToolReadScreen => '讀取螢幕上顯示的文字與可點元素';

  @override
  String get deviceControlToolTap => '按文字或座標點選';

  @override
  String get deviceControlToolInput => '在輸入框裡打字';

  @override
  String get deviceControlToolSwipe => '滑動翻頁、滾動列表';

  @override
  String get deviceControlToolPressKey => '返回 / 主頁 / 最近任務 / 回車';

  @override
  String get deviceControlToolOpenApp => '開啟指定應用（包名）';

  @override
  String get deviceControlDenylistTitle => '敏感應用黑名單';

  @override
  String get deviceControlDenylistBody =>
      '這些應用在前臺時，智慧體不會執行任何操作（銀行、支付、密碼管理器、系統設定）。一行一個包名，也支援逗號分隔。';

  @override
  String get deviceControlSaveDenylist => '儲存黑名單';

  @override
  String get deviceControlResetDefault => '恢復預設';

  @override
  String get deviceControlFooter =>
      '說明：手機控制基於安卓無障礙服務，不需要 root，也不需要額外外掛。\n· 關掉上面的開關，相關工具會立刻從智慧體手裡撤銷；\n· 每個動作都會寫進審計記錄，可在「管理設定」裡回看；\n· 智慧體永遠不會對你沒有授權的應用動手。';

  @override
  String get deviceControlToastNeedAccessibility => '請先在系統設定裡開啟「大荒AI」的無障礙服務';

  @override
  String get deviceControlToastOn => '手機控制已開啟：首次使用時仍會向你確認一次';

  @override
  String get deviceControlToastOff => '手機控制已關閉，相關工具已撤銷';

  @override
  String deviceControlToastSaved(String n) {
    return '黑名單已儲存（共 $n 條）';
  }

  @override
  String get deviceControlToastReset => '已恢復預設黑名單';

  @override
  String get contactDefaultAgentName => '野生 Agent';

  @override
  String get contactDefaultMasterName => '物理探測';

  @override
  String get contactDefaultNotes => '暫無備註';

  @override
  String get contactSendingThroughGateway => '⚡ 正在穿透閘道器直接傳送...';

  @override
  String get contactEditTitle => '修改智慧體名冊備註';

  @override
  String get contactEditAgentLabel => '智慧體暱稱';

  @override
  String get contactEditMasterLabel => '主人身份備註';

  @override
  String get contactEditNotesLabel => '檔案小秘密';

  @override
  String get contactEditConfirm => '確認同步';

  @override
  String get contactEditSaved => '✅ 捕獲名冊備註已鎖定同步！';

  @override
  String get contactRequestReco => '索取推薦信';

  @override
  String get contactSendGift => '贈送禮物';

  @override
  String contactGiftSent(String gift) {
    return '$gift 已送出，等待對方簽收';
  }

  @override
  String get contactGiftFailed => '禮物傳送失敗：對方不線上或未在任何通道';

  @override
  String get contactRecoRequested => '🤝 已發出推薦信請求，對方將按其本地信譽決定是否簽發';

  @override
  String get contactRecoFailed => '請求傳送失敗：對方不在任何線上通道';

  @override
  String get contactTierBlockToast => '信譽過低，建議在捕獲名冊中直接“刪除拉黑”該節點';

  @override
  String contactTierAdjusted(String tier) {
    return '✅ 已按信譽建議調整為 $tier';
  }

  @override
  String get contactTierFriend => '可升級為好友';

  @override
  String get contactTierFamily => '可升級為家人';

  @override
  String get contactTierStranger => '建議降級為陌生人';

  @override
  String get contactTierBlock => '建議拉黑';

  @override
  String get contactStatusLocked => '雷達已鎖定';

  @override
  String get contactStatusSent => '等待回應';

  @override
  String get contactStatusReceived => '等待主代稽核';

  @override
  String get contactStatusAccepted => '暢聊中';

  @override
  String get contactStatusRejected => '已物理攔截';

  @override
  String contactOwnerLine(String name) {
    return '主人: $name';
  }

  @override
  String get contactOnline => '線上';

  @override
  String get contactOutOfRange => '超出範圍';

  @override
  String contactReputation(String score) {
    return '📊 信譽 $score';
  }

  @override
  String contactGiftStats(String sent, String received) {
    return '🎁 送$sent/收$received';
  }

  @override
  String get contactTierBlockBanner => '⚠️ 信譽過低，建議拉黑（點選檢視）';

  @override
  String contactTierHintBanner(String suggestion) {
    return '💡 信譽建議：$suggestion（點選應用）';
  }

  @override
  String contactNotesLine(String notes) {
    return '📝 備註檔案：$notes';
  }

  @override
  String get contactEmptyChat => '暫無對話。\n下方輸入直接與對方對話！';

  @override
  String get contactSayHint => '強制搭話，輸入內容...';

  @override
  String get dshImportTitle => '從 DSH 生態匯入';

  @override
  String get dshImportClipboardEmpty => '剪貼簿是空的';

  @override
  String get dshImportNoFileContent => '沒有讀到檔案內容，請換一種方式選擇';

  @override
  String dshImportPickFailed(String err) {
    return '選擇檔案失敗：$err';
  }

  @override
  String get dshImportPasteSkillFirst => '請先貼上 SKILL.md 的內容';

  @override
  String get dshImportIntroTitle => '借力整個 DSH 生態';

  @override
  String get dshImportIntroBody =>
      'DSH 的外掛是 TypeScript 寫的，手機上不能直接跑；\n但其中的技能、MCP 服務可以原樣搬過來用。\n\n為安全起見：匯入的外掛一律預設關閉，且帶裝置簽名校驗，必須由你手動開啟後才會生效。';

  @override
  String get dshImportSecSkillTitle => '① 匯入技能（SKILL.md）';

  @override
  String get dshImportSecSkillSub =>
      '純文字技能可以 100% 直譯，是 DSH 生態裡最好搬的部分。貼上一份內容，或一次選擇多個 .md 檔案。';

  @override
  String get dshImportSkillHint =>
      '貼上 SKILL.md 全文（含 --- 頭部的 name / description）';

  @override
  String get dshImportPaste => '貼上';

  @override
  String get dshImportPickFiles => '選擇檔案';

  @override
  String get dshImportImport => '匯入';

  @override
  String get dshImportSecMcpTitle => '② 匯入 MCP 服務';

  @override
  String get dshImportSecMcpSub =>
      'MCP 是通用協議，不依賴語言，填地址就能直連。支援貼上 dsh / Claude 風格的 mcpServers 配置。';

  @override
  String dshImportMcpHint(String example) {
    return '例如 $example\n也可以只粘一個 https:// 地址';
  }

  @override
  String get dshImportSecInspectTitle => '③ 外掛包體檢';

  @override
  String get dshImportSecInspectSub =>
      '拿到一個 DSH 外掛包，先體檢再決定要不要折騰。貼上包裡的 package.json（必需）和 cordis.patch.yml（可選）。';

  @override
  String get dshImportPackageJsonHint => '貼上 package.json 全文';

  @override
  String get dshImportPatchHint => '貼上 cordis.patch.yml 全文（可選）';

  @override
  String get dshImportPastePackageJson => '貼上 package.json';

  @override
  String get dshImportStartInspect => '開始體檢';

  @override
  String get dshImportGoToolCenter => '去技能控制中心開啟剛匯入的外掛';

  @override
  String dshImportSummaryImportedOk(String n) {
    return '成功匯入 $n 項';
  }

  @override
  String dshImportSummarySkipped(String n) {
    return '，跳過 $n 項';
  }

  @override
  String get dshImportListSeparator => '、';

  @override
  String dshImportImportedLine(String names) {
    return '✅ $names';
  }

  @override
  String dshImportSkippedLine(String name, String reason) {
    return '⚠️ $name：$reason';
  }

  @override
  String dshImportNoteLine(String note) {
    return 'ℹ️ $note';
  }

  @override
  String get dshSkipDuplicateSkill => '已有同名技能，未覆蓋';

  @override
  String get dshSkipDuplicateMcp => '已有同名 MCP 配置，未覆蓋';

  @override
  String get dshSkipInvalidJson => '這段內容不是合法 JSON，也不是網址';

  @override
  String get dshSkipCommandLineMcp =>
      '這是命令列型 MCP（需要在本機啟動程序），手機上跑不了；請改用 HTTP 地址';

  @override
  String get dshSkipNoUrlField => '這條配置裡找不到 url 欄位';

  @override
  String get dshSkipMissingNameUrl => '缺少 name 或 url';

  @override
  String get dshSkipUnrecognizedJson => '無法識別的 JSON 結構';

  @override
  String get dshSkipInvalidScheme => '地址必須以 http:// 或 https:// 開頭';

  @override
  String get dshSkipSubjectConfig => '配置';

  @override
  String get dshSkipSubjectConfigParseFailed => '配置解析失敗';

  @override
  String get dshSkipSubjectUnnamedEntry => '未命名條目';

  @override
  String get dshNoteSkillDefaultsOff =>
      '匯入的技能預設關閉，請到「技能控制中心」按需開啟；開啟後它會影響智慧體的說話方式與行為準則。';

  @override
  String get dshNoteMcpDefaultsOff =>
      '匯入的 MCP 服務預設關閉。開啟並首次使用時，系統會提示授予「網路訪問」能力，授權後才會真正連線。';

  @override
  String get dshNotePasteMcpFirst => '請先貼上 MCP 配置或地址';

  @override
  String dshInspectErrPackageFormat(String msg) {
    return '❌ package.json 解析失敗：$msg';
  }

  @override
  String dshInspectErrPackageNotJson(String msg) {
    return '❌ package.json 不是合法 JSON：$msg';
  }

  @override
  String dshInspectErrPatchFormat(String msg) {
    return '❌ cordis.patch.yml 解析失敗：$msg';
  }

  @override
  String dshInspectPackageLine(String name) {
    return '外掛包：$name';
  }

  @override
  String dshInspectBundleLine(String path) {
    return '組合檔案：$path';
  }

  @override
  String dshInspectProfileBundlesLine(String list) {
    return '依賴組合包：$list';
  }

  @override
  String get dshInspectNoPatchHint =>
      'ℹ️ 沒有提供 cordis.patch.yml，只能看到包的基本資訊。把外掛包裡的該檔案內容也粘進來，才能判斷哪些能搬到手機上。';

  @override
  String dshInspectRowCountLine(String n) {
    return '共 $n 個外掛行，體檢結果：';
  }

  @override
  String dshInspectGroupLine(String verdict, String n) {
    return '【$verdict】 共 $n 行';
  }

  @override
  String dshInspectMoreRowsLine(String n) {
    return '  · …另有 $n 行';
  }

  @override
  String dshInspectConclusionLine(String skill, String mcp, String heavy) {
    return '結論：可直接匯入 $skill 行技能 + $mcp 行 MCP；$heavy 行屬於「必須在 Dart 側重寫或依賴桌面環境」，本機無法直接執行。';
  }

  @override
  String get dshInspectVerdictDirectSkill => '✅ 可直接匯入（技能）';

  @override
  String get dshInspectVerdictMcpServer => '✅ 可直接連線（MCP 服務）';

  @override
  String get dshInspectVerdictConfigOnly => '⚙️ 僅配置項（無需移植）';

  @override
  String get dshInspectVerdictPlatformGated => '🖥️ 依賴桌面環境（手機上不可用）';

  @override
  String get dshInspectVerdictNeedsDart => '🧱 需要 Dart 側重寫（含 TS 程式碼）';

  @override
  String get chatCleared => '🧹 已清空工作區與 LLM 記憶，開啟新會話！';

  @override
  String get chatImageOptionsTitle => '傳送影象或視覺內容';

  @override
  String get chatTakePhoto => '拍攝照片';

  @override
  String get chatPickFromAlbum => '相簿選擇';

  @override
  String get chatAudioOptionsTitle => '傳送音訊或錄音';

  @override
  String get chatStartRecording => '開始錄音';

  @override
  String get chatLocalAudio => '本地音訊';

  @override
  String chatOpenCameraFailed(String err) {
    return '開啟相機失敗：$err';
  }

  @override
  String chatOpenAlbumFailed(String err) {
    return '開啟相簿失敗：$err';
  }

  @override
  String chatPickAudioFailed(String err) {
    return '選擇音訊檔案失敗：$err';
  }

  @override
  String get chatNoMicPermission => '沒有麥克風許可權：請在系統設定裡允許「錄音」許可權後重試';

  @override
  String chatStartRecordingFailed(String err) {
    return '開始錄音失敗：$err';
  }

  @override
  String get chatWelcomeBack => '歡迎回來，主人！';

  @override
  String get chatAgentReady => 'AI 管家已就緒，隨時待命';

  @override
  String get chatQuickTechTitle => '🔍 今日科技新聞';

  @override
  String get chatQuickTechPrompt => '幫我搜尋今天最新的 AI 科技新聞並彙總。';

  @override
  String get chatQuickRadarTitle => '📡 掃描附近的人';

  @override
  String get chatQuickRadarPrompt => '檢查物理雷達，周圍有什麼活躍節點嗎？';

  @override
  String get chatQuickProfileTitle => '📝 提煉我的檔案';

  @override
  String get chatQuickProfilePrompt => '根據昨天的聊天，我有什麼新的喜好被你發現了嗎？';

  @override
  String get chatAudioFile => '音訊檔案';

  @override
  String get chatRecording => '🔴 正在錄音...';

  @override
  String get chatInputHint => '給管家傳送指令...';

  @override
  String get profileSavedToast => '🔒 主人絕密檔案已存檔';

  @override
  String get profileAddPerson => '新增關係人物';

  @override
  String get profileEditPerson => '修改人物資訊';

  @override
  String get profileNameLabel => '名字 (例如：小美)';

  @override
  String get profileRelationLabel => '社會關係 (例如：妻子)';

  @override
  String get profileIdentityLabel => '身份備註 (例如：小學老師)';

  @override
  String get profileSecretLabel => '細節秘密 (如: 喜歡草莓)';

  @override
  String get profileSaveVault => '儲存並鎖入保險箱';

  @override
  String get profileTitle => '主人絕密檔案 & 人際網';

  @override
  String get profilePreferenceHeader => '👤 主人偏好設定';

  @override
  String get profileJobLabel => '職業 (Job)';

  @override
  String get profileHobbiesLabel => '喜好特長 (Hobbies)';

  @override
  String get profileDislikesLabel => '忌諱討厭 (Dislikes)';

  @override
  String get profileOtherLabel => '其他備註 (Other Notes) - 隨意寫';

  @override
  String get profileSaveBase => '💾 儲存基本偏好 (鎖入本地庫)';

  @override
  String get profileNetworkHeader => '🔗 絕密人物關係網';

  @override
  String get profileAdd => '新增';

  @override
  String get profileNetworkEmpty => '空空如也，點選右上角新增';

  @override
  String profileDetailLine(String notes) {
    return '📝 細節：$notes';
  }

  @override
  String get profileAiReadable => '🔓 AI 已獲授權讀取此人資訊';

  @override
  String get profileAiIsolated => '🔒 AI 已被物理隔離此人資訊';

  @override
  String get giftPickerTitle => '🎁 挑一份心意';

  @override
  String get giftNoteLabel => '附一句話（可選）';

  @override
  String get giftNoteHint => '例如：謝謝上次幫忙';

  @override
  String get giftSend => '送出';

  @override
  String get giftNameTea => '一杯茶';

  @override
  String get giftNameBook => '一本書';

  @override
  String get giftNameFlower => '一束花';

  @override
  String get giftNameCake => '一塊蛋糕';

  @override
  String get giftNameMysteryBox => '神秘禮盒';

  @override
  String get giftNameStar => '一顆星';

  @override
  String get themeRed => '紅';

  @override
  String get themeOrange => '橙';

  @override
  String get themeYellow => '黃';

  @override
  String get themeGreen => '綠';

  @override
  String get themeCyan => '青';

  @override
  String get themeBlue => '藍';

  @override
  String get themePurple => '紫';

  @override
  String get themeWhite => '白';

  @override
  String get themeBlack => '黑';

  @override
  String get mainClearSession => '清空並新開會話';

  @override
  String get mainNavChat => '日常交流';

  @override
  String get mainNavSocial => '小荒社區';

  @override
  String get mainNavWorld => '大荒世界';

  @override
  String get mainNavSerendipity => '轉運實驗';

  @override
  String get mainNavManage => '管理設定';

  @override
  String topicChatLogSuffix(String range) {
    return '$range 聊天記錄';
  }

  @override
  String get topicArchiveTitle => '智慧記憶歸檔';

  @override
  String get topicTabTimeline => '時間軸 (Timeline)';

  @override
  String get topicTabTopics => '主題樹 (Topics)';

  @override
  String get topicEmptyArchive => '暫無歸檔資料';

  @override
  String get topicNoTag => '無標籤';

  @override
  String get topicDailyChat => '日常閒聊';

  @override
  String topicCountLabel(String count) {
    return '$count條';
  }

  @override
  String topicKeywordLine(String keywords) {
    return '🏷️ $keywords';
  }

  @override
  String digestToResponse(String to, String response) {
    return '$to：$response';
  }

  @override
  String get deviceControlStatusReady => '手機控制已就緒：智慧體可以讀屏、點選、輸入';

  @override
  String get deviceControlStatusUnsupportedShort => '當前構建未包含手機控制模組';

  @override
  String get deviceControlStatusUnsupportedFull => '當前構建未包含手機控制模組（需要安卓端無障礙服務）';

  @override
  String get deviceControlStatusCheckedOffline =>
      '系統裡已勾選，但服務還沒連上。先點右上角重新整理；若仍不行，把系統設定裡的開關關掉再開啟一次（或重啟 App）';

  @override
  String get deviceControlStatusOff => '還沒有在系統設定裡開啟無障礙服務';

  @override
  String deviceControlStatusQueryFailed(String err) {
    return '狀態查詢失敗：$err';
  }

  @override
  String deviceControlGuardBlocked(String pkg) {
    return '當前前臺應用（$pkg）在安全黑名單裡，智慧體不會對它執行任何操作。如確實需要，請在「手機控制」設定頁裡移除該限制。';
  }

  @override
  String commonNetworkError(String err) {
    return '網路異常：$err';
  }

  @override
  String get netFaultLanHijackAdvice =>
      '🤖【智慧體自我診斷報告】\n主人，我的大模型連不上網了！\n這通常是因為我們開啟了物理雷達（Nearby/區域網），而當前 Wi-Fi 所在的區域網沒有外網出口 —— 裝置之間能互相發現，卻出不了公網，所以我調不了雲端大模型。\n\n建議：① 暫時關閉物理雷達；② 或下拉狀態列關掉 Wi-Fi、改走蜂窩資料；③ 或在手機設定裡開啟「智慧切換蜂窩網路」。\n目前我只能保持底層的物理連線監聽了。';

  @override
  String netFaultSocialSkipped(String err) {
    return '❌ 連不上雲端大模型：網路不可達。若已開啟物理雷達，當前 Wi-Fi 的區域網很可能沒有外網出口 —— 裝置之間能互相發現，但出不了公網。本輪已跳過。\n建議：關閉物理雷達，或關掉 Wi-Fi 改用蜂窩資料後重試。\n原因：$err';
  }

  @override
  String socialPipelineError(String err) {
    return '❌ 社交決策流水線異常，本輪已終止：$err';
  }

  @override
  String netFaultNetworkTrouble(String err) {
    return '❌ 連不上雲端大模型（網路異常，不是程式碼問題）。\n可能是網路正在切換、運營商鏈路受阻，或當前 Wi-Fi 沒有外網出口。\n建議：① 關掉 Wi-Fi 改走蜂窩資料；② 或在手機設定裡開啟「智慧切換蜂窩網路」；③ 稍後重試。\n原因：$err';
  }

  @override
  String get netFaultCooldownSkipped => '⏸ 網路連續故障，已暫停呼叫大模型（10 分鐘內不再重試，避免白燒額度）。';

  @override
  String get worldSvcNoHub => '未配置雲端 Hub / 世界地址';

  @override
  String get worldSvcMustBeHttps => '世界地址必須是 HTTPS 或區域網私有地址';

  @override
  String worldSvcRoomsFailed(String code, String body) {
    return '房間列表獲取失敗：$code $body';
  }

  @override
  String worldSvcOpFailed(String code, String body) {
    return '操作失敗($code)：$body';
  }

  @override
  String worldSvcReportFailed(String code) {
    return '日報獲取失敗：$code';
  }

  @override
  String get godSvcMustBeHttps => 'GOD 地址必須是 HTTPS，或區域網私有地址';

  @override
  String godSvcStatusFailed(String code, String body) {
    return '狀態獲取失敗($code)：$body';
  }

  @override
  String get godSvcNoBridge => '未配置 GOD 橋接地址';

  @override
  String godSvcCmdFailed(String code, String body) {
    return '指令失敗($code)：$body';
  }

  @override
  String get passportTitle => '護照與信譽';

  @override
  String get passportEntryTile => '大荒護照';

  @override
  String get passportEntryHint => '可驗證簽名履歷 · 離線可驗';

  @override
  String get passportCardHeader => '我的大荒護照';

  @override
  String get passportIssuedLabel => '簽發';

  @override
  String get passportCopyAction => '複製身份';

  @override
  String get passportRefreshAction => '重新整理';

  @override
  String get passportCopiedToast => '已複製';

  @override
  String passportStatLine(String label, String value) {
    return '$label：$value';
  }

  @override
  String get passportLedgerHeader => '互介履歷';

  @override
  String get passportLedgerEmpty => '還沒有互介記錄。去世界房間認識幾個人吧。';

  @override
  String get passportDirectionOut => '我發起';

  @override
  String get passportDirectionIn => '我收到';

  @override
  String get passportPeerLabel => '對方';

  @override
  String get passportTopicLabel => '主題';

  @override
  String get passportRoomLabel => '源於房間';

  @override
  String get passportTrustLabel => '可驗證等級';

  @override
  String get passportTrustNone => '未透過驗證';

  @override
  String get passportTrustInitiated => '僅發起方已籤';

  @override
  String get passportTrustConsented => '雙方已互允';

  @override
  String get passportTrustResolved => '已落結果';

  @override
  String get passportTrustAcknowledged => '雙方已追認';

  @override
  String get passportOutcomeLabel => '結果';

  @override
  String get passportOutcomeHandshake => '已握手';

  @override
  String get passportOutcomeDeclined => '已拒絕';

  @override
  String get passportOutcomeNoResponse => '無回應';

  @override
  String get passportOutcomeWithdrawn => '已撤回';

  @override
  String get passportVerifyDetails => '驗證明細';

  @override
  String get passportChecksLabel => '已透過';

  @override
  String get passportFaultsLabel => '未透過';

  @override
  String get passportConsentAction => '同意這次互介';

  @override
  String get passportConsentDone => '已同意';

  @override
  String get passportResolveAction => '記錄結果';

  @override
  String get passportResolveTitle => '這次互介的結果';

  @override
  String get passportAckAction => '追認結果';

  @override
  String get passportAckDone => '已追認';

  @override
  String get passportActionDelivered => '已簽名並投遞';

  @override
  String get passportActionOffline => '已記賬；對方暫時聯絡不上，稍後會自動補送';

  @override
  String get passportActionRejected => '未生效（時序或身份不符）';

  @override
  String get passportFunnelHeader => '互介 → 握手轉化';

  @override
  String get passportFunnelProposedLabel => '發起';

  @override
  String get passportFunnelConsentedLabel => '雙方互允';

  @override
  String get passportFunnelHandshakeLabel => '握手';

  @override
  String get passportFunnelSettledLabel => '已落結果';

  @override
  String get passportFunnelInFlightLabel => '在途';

  @override
  String get passportFunnelConsentRateLabel => '互允率';

  @override
  String get passportFunnelConversionLabel => '轉化率';

  @override
  String get passportLogHeader => '透明日誌';

  @override
  String get passportLogSizeLabel => '當前期號';

  @override
  String get passportLogRootLabel => 'Merkle 根';

  @override
  String get passportLogCopyAction => '複製根';

  @override
  String get passportNewIntroAction => '發起互介';

  @override
  String get passportNewIntroPeerLabel => '對方分身 ID';

  @override
  String get passportNewIntroTopicLabel => '一句話主題';

  @override
  String get passportNewIntroSubmit => '發起';

  @override
  String get passportNewIntroNeedPeer => '請填寫對方分身 ID';

  @override
  String get passportNewIntroNoCircle => '你還沒有圈子。先入場進圈，互介才有歸屬。';

  @override
  String passportNewIntroDone(String peer) {
    return '已向 $peer 發起互介並簽名';
  }

  @override
  String radarNoticeStarted(int minutes) {
    return '🛡️ 雷達開啟，$minutes分鐘社交限時派對已開始...';
  }

  @override
  String get radarNoticeStopped => '💤 雷達關閉，社交派對已結束。';

  @override
  String get radarNotifTitle => 'Ai管家 雷達閘道器全速執行中';

  @override
  String get radarNotifText => '您的數字分身正在後臺物理世界為您不間斷社交...';

  @override
  String get radarNoticePartyEnded => '⏰ 限時派對時間已到，主智慧體已強制拔掉天線！';

  @override
  String get radarNoticeWrappingUp => '⏳ 社交時間不足10分鐘，子智慧體已準備道別。';

  @override
  String get cloudHubNotConfigured => '未配置雲端 Hub 地址';

  @override
  String get cloudKeyRequired => '這個中轉站需要存取 Key：請在「進階設定」填入營運方簽發的 Key';

  @override
  String get cloudKeyInvalid => '存取 Key 無效，請確認是否複製完整';

  @override
  String get cloudKeyRevoked => '這個存取 Key 已停用，請聯絡中轉站營運方';

  @override
  String get cloudKeyBound => '這個 Key 已綁定另一個身分，請換一個 Key（或走身分復原）';

  @override
  String get cloudAgentRevoked => '本機身分已被中轉站停用，無法再收發訊息';

  @override
  String get cloudRegisterClosed => '中轉站暫停了新使用者註冊';

  @override
  String get cloudRegisterIdentityConflict =>
      '這個身分 ID 已綁定另一把金鑰：請走「身分復原／換鑰」，不要刪除身分';

  @override
  String cloudRosterFailed(int status, String body) {
    return '名冊獲取失敗($status): $body';
  }

  @override
  String cloudNetworkError(String error) {
    return '網路異常: $error';
  }

  @override
  String cloudCardFailed(int status) {
    return '名片獲取失敗($status)';
  }

  @override
  String get identityChangedWarning =>
      '🚨 身份突變：對方公鑰與歷史固定不一致（疑似中間人/換綁），握手已拒絕並大幅降信。';

  @override
  String get lanTunnelOpen => '⚡ 區域網物理通道(TCP/UDP)已打通！';

  @override
  String get lanTargetLost => '⚠️ Wi-Fi 物理目標脫離範圍。';

  @override
  String get p2pBtDisconnected => '⚠️ 藍芽連線斷開。';

  @override
  String repEventLog(String delta, String event, String detail) {
    return '信譽$delta（$event）$detail';
  }

  @override
  String repEventDetailSuffix(String detail) {
    return '：$detail';
  }

  @override
  String repGiftLogIncoming(String gift, String note) {
    return '$gift 來自節點的一份心意$note';
  }

  @override
  String repGiftLogOutgoing(String gift, String note) {
    return '$gift 送給節點的一份心意$note';
  }

  @override
  String repGiftNoteQuoted(String note) {
    return '：“$note”';
  }

  @override
  String repGiftMemoryIncoming(String name, String gift, String note) {
    return '$name 送來禮物 $gift $note';
  }

  @override
  String repGiftMemoryOutgoing(String gift, String name, String note) {
    return '$name 收到了你贈送的禮物 $gift $note';
  }

  @override
  String repGiftMemoryNote(String note) {
    return '（$note）';
  }

  @override
  String repRecoLog(int score, String date) {
    return '🤝 收到推薦信：信譽 $score（$date 簽發，已驗籤）';
  }

  @override
  String repRecoMemory(String issuer, int score, String date) {
    return '收到 $issuer 的推薦信（信譽 $score，$date 簽發）';
  }

  @override
  String get repNetHeader => '網路背書';

  @override
  String repNetAnchors(int count, int min) {
    return '$count 個錨點（本地信譽 ≥ $min）';
  }

  @override
  String get repNetMineLabel => '我背書的人';

  @override
  String get repNetForMeLabel => '背書我的人';

  @override
  String get repNetEmpty => '還沒有';

  @override
  String get repNetIssueAction => '簽發背書';

  @override
  String get repNetIssueTitle => '籤一份背書';

  @override
  String get repNetIssueSubjectLabel => '對方的護照 DID 或公鑰';

  @override
  String get repNetIssueNeedSubject => '請貼上對方的 DID（did:wold:…）或公鑰';

  @override
  String get repNetIssueBadSubject => '這不是合法的 DID 或公鑰';

  @override
  String get repNetIssueTierLabel => '檔位';

  @override
  String get repNetIssueNoteLabel => '附言（可選）';

  @override
  String get repNetIssueBindLabel => '他的 Agent ID（可選；填了才把他接進信任網路）';

  @override
  String get repNetTierAcquaintance => '泛泛之交';

  @override
  String get repNetTierFriend => '朋友';

  @override
  String get repNetTierFamily => '家人';

  @override
  String get repNetIssuedToast => '背書已簽名並落庫';

  @override
  String repNetFailedToast(String code) {
    return '被拒：$code';
  }

  @override
  String get repNetSelfReject => '不能給自己背書';

  @override
  String get repNetExpiresLabel => '有效期至';

  @override
  String get repNetRevokeAction => '收回';

  @override
  String get repNetRevokedToast => '背書已收回';

  @override
  String repNetBoundToast(String id) {
    return '已記住 $id 的公鑰';
  }

  @override
  String get repNetVerifyAction => '驗籤';

  @override
  String get repNetVerifiedToast => '簽名有效';

  @override
  String get repNetBadSignatureToast => '簽名無效 —— 這份背書被改過';

  @override
  String get repNetQueryLabel => '查一個人';

  @override
  String get repNetQueryAction => '追溯';

  @override
  String repNetQueryKnown(
      String tier, int depth, String confidence, int paths) {
    return '$tier · 距離 $depth 跳 · 置信 $confidence · $paths 條通路';
  }

  @override
  String get repNetQueryUnknown => '沒有可驗證的通路';

  @override
  String get repNetPathLabel => '證據鏈（每一跳你都能自己驗）';

  @override
  String get repNetPathStart => '你信任';

  @override
  String get repNetPathHop => '→ 他背書';

  @override
  String get repNetStatusRevoked => '已收回';

  @override
  String get repNetStatusExpired => '已過期';

  @override
  String repNetKeysMerged(int count) {
    return '已按換鑰鏈歸併 $count 把歷史公鑰 —— 換鑰前收到的背書仍計入。';
  }

  @override
  String get skillMarketTitle => '技能市場';

  @override
  String get skillMarketSubtitle => '上架作者簽名技能，檢視自己的分成';

  @override
  String get skillRevenueTitle => '作者收益';

  @override
  String skillRevenueTotal(String amount) {
    return '累計收益 $amount';
  }

  @override
  String skillRevenueCount(int count) {
    return '$count 筆分賬';
  }

  @override
  String get skillRevenueEmpty => '暫無收益';

  @override
  String get skillNoListings => '登錄檔裡還沒有任何技能。';

  @override
  String get skillPublishAction => '上架技能';

  @override
  String get skillPublishTitle => '簽名上架技能';

  @override
  String get skillFieldId => '技能 ID';

  @override
  String get skillFieldVersion => '版本號';

  @override
  String get skillFieldName => '名稱';

  @override
  String get skillFieldDesc => '描述';

  @override
  String get skillFieldPrice => '價格（元，0 表示免費）';

  @override
  String get skillFieldRisk => '風險等級';

  @override
  String get skillFieldCaps => '能力宣告';

  @override
  String get skillFieldContent => '技能內容（將被雜湊並簽名）';

  @override
  String get skillSubmit => '簽名並上架';

  @override
  String get skillNeedFields => '技能 ID、版本號、名稱、內容為必填';

  @override
  String get skillRevokeAction => '吊銷';

  @override
  String skillRevokeConfirm(String skill) {
    return '吊銷 $skill？此操作不可撤銷。';
  }

  @override
  String skillPublishedOk(String skill) {
    return '已上架 $skill';
  }

  @override
  String get skillPublishDuplicate => '同版本同內容已上架';

  @override
  String get skillPublishVersionConflict => '同版本內容不同，已拒絕';

  @override
  String get skillPublishAuthorChanged => '該技能 ID 屬於其他作者，已拒絕';

  @override
  String get skillPublishVersionNotIncreased => '版本號必須大於已上架版本';

  @override
  String get skillPublishUnverified => '簽名無效，已拒絕';

  @override
  String skillRevokedOk(String skill) {
    return '已吊銷 $skill';
  }

  @override
  String get skillRevokeRejected => '吊銷被拒——你不是該技能的作者公鑰';

  @override
  String get skillMineTag => '我的';

  @override
  String get skillFree => '免費';

  @override
  String skillPriceYuan(String amount) {
    return '¥$amount';
  }

  @override
  String get skillAuthorKey => '作者公鑰';

  @override
  String get skillRevokedTag => '已吊銷';

  @override
  String get skillVerifyAction => '校驗簽名';

  @override
  String get skillVerifyOk => '簽名有效';

  @override
  String skillVerifyFail(String code) {
    return '驗籤失敗：$code';
  }

  @override
  String skillVersionHistory(int count) {
    return '$count 個版本';
  }

  @override
  String runtimeInitFailed(String err) {
    return '本地執行時未能啟動，世界、圈子、委託等功能暫不可用，其餘功能正常。（$err）';
  }

  @override
  String get idbEntry => '身份備份與恢復';

  @override
  String get idbTitle => '身份備份與恢復';

  @override
  String get idbIntro =>
      '你的身份就是這把鑰匙，而它只存在這臺手機上。手機丟了，身份就永久滅失 —— 連我們都無法重發。把恢復碼抄下來，那是唯一能把它帶回來的東西。';

  @override
  String get idbCurrentDid => '當前身份（DID）';

  @override
  String get idbNoScreenshotShort => '切勿截圖';

  @override
  String get idbSectionBackup => '備份身份';

  @override
  String get idbWarnNoScreenshot =>
      '⚠️ 恢復碼就等於你的身份。請抄寫在紙上離線保管；不要截圖、不要存網盤、不要發給任何人（包括我們）。';

  @override
  String get idbPwLabel => '恢復口令（至少 10 位）';

  @override
  String get idbPwConfirmLabel => '再輸一次口令';

  @override
  String get idbPwMismatch => '兩次口令不一致';

  @override
  String get idbPwTooShort => '口令太短（至少 10 位）';

  @override
  String get idbGenerateAction => '生成恢復碼';

  @override
  String get idbCodeTitle => '你的恢復碼（抄下來）';

  @override
  String get idbCopyCode => '複製恢復碼';

  @override
  String get idbCopiedToast => '恢復碼已複製 —— 記得隨後清空剪貼簿';

  @override
  String get idbICopied => '我已抄下，並已離線妥善保管';

  @override
  String get idbNeedCopied => '請先確認你已抄下恢復碼';

  @override
  String get idbDoneToast => '身份已備份';

  @override
  String get idbSectionRestore => '換機恢復';

  @override
  String get idbRestoreAction => '恢復身份';

  @override
  String get idbRestoreCodeLabel => '恢復碼';

  @override
  String get idbRestoreIdLabel => '使用者 ID（AG-…）';

  @override
  String get idbRestorePwLabel => '恢復口令';

  @override
  String get idbRestoreCheckAction => '核對';

  @override
  String get idbRestoreNeedAll => '請填全恢復碼、使用者 ID 與口令';

  @override
  String get idbRestoreConfirmTitle => '確認這就是你要恢復的身份';

  @override
  String idbRestoreConfirmBody(String did) {
    return '你將恢復為：$did\n\n恢復後本機接管這個身份，舊手機立即失效。';
  }

  @override
  String get idbRestoreConfirmAction => '確認恢復';

  @override
  String get idbRestoreBusy => '正在換鑰…';

  @override
  String get idbRestoreOk => '恢復成功。舊手機上的身份已失效，請銷燬它的資料。';

  @override
  String idbRestoreFail(String code) {
    return '恢復失敗：$code';
  }

  @override
  String get idbErrHubNotConfigured => '尚未配置 Hub 地址，無法完成換鑰。請先在「世界」設定裡填寫伺服器地址。';

  @override
  String get idbErrIdMismatch => '使用者 ID 與恢復碼裡的身份不一致 —— 請檢查是不是拿錯了備份。';

  @override
  String get idbErrBadPassword => '口令不對，或恢復碼被改動過。';

  @override
  String get idbErrBadFormat => '恢復碼格式不對（請完整複製，別漏段）。';

  @override
  String get idbErrNotCurrentKey => '該身份的當前金鑰已經不是這把了 —— 它可能已經被換過鑰。';

  @override
  String get idbRestoreUnavailable => '本地身份尚未就緒，暫時無法備份 / 恢復。';

  @override
  String get idbStatusBackedUp => '身份已備份';

  @override
  String get idbStatusBackedUpHint => '當前這把鑰的恢復碼已抄下。日後用它恢復時，這臺裝置會當場失效。';

  @override
  String get idbStatusNotBackedUp => '身份未備份';

  @override
  String get idbStatusNotBackedUpHint =>
      '手機一旦丟失或損壞，身份與全部履歷將永久消失 —— 包括我們在內，沒有任何人能替你重發。';

  @override
  String get arcSectionTitle => '匯出本地資料';

  @override
  String get arcExportAction => '匯出本地資料';

  @override
  String get arcExportNote => '為這份歸檔設一個口令。它不必與恢復碼的口令相同 —— 不同反而更好。';

  @override
  String get arcSavedTitle => '歸檔已生成';

  @override
  String get arcSavedPath => '已儲存到：';

  @override
  String get arcSavedNoPath => '沒能寫入檔案（沒有儲存許可權），但內容可以直接複製。';

  @override
  String get arcSavedHint => '檔案與口令請分開保管。沒有口令，這個檔案誰也打不開 —— 我們也不行。';

  @override
  String get arcImportAction => '匯入';

  @override
  String get arcImportNote =>
      '選擇 .dahuang 檔案，或直接貼上內容。在你確認之前不會寫入任何東西；匯入只增不減，絕不覆蓋或刪除已有記錄。';

  @override
  String get arcPickFile => '選擇檔案';

  @override
  String get arcImportCodeLabel => '歸檔內容';

  @override
  String get arcImportConfirmTitle => '確認匯入這份歸檔？';

  @override
  String arcImportConfirmBody(int rows, int tables, int logsize) {
    return '將寫入 $rows 行、涉及 $tables 張表，並把日誌接續到第 $logsize 片。已有記錄保留。';
  }

  @override
  String arcImportOk(int count) {
    return '匯入完成：寫入 $count 行。';
  }

  @override
  String get arcErrNotArchive => '這不是一份有效的 .dahuang 歸檔。';

  @override
  String get arcLogConflictTitle => '已拒絕匯入：日誌接不上';

  @override
  String get arcLogConflictBody =>
      '本機透明日誌與歸檔裡的日誌對不上，硬接會讓雜湊鏈靜默斷裂（斷了一節，後面每一節仍然自洽）。本次未寫入任何內容。請把歸檔匯入到日誌為空的新裝置，或尋求協助。';

  @override
  String get onbBackupTitle => '備份你的身份';

  @override
  String get onbBackupSubtitle => '一串抄在紙上的恢復碼 —— 手機壞掉時，它是唯一的退路。';

  @override
  String get onbBackupWhyTitle => '為什麼要緊';

  @override
  String get onbBackupWhy =>
      '你的身份是自證的：私鑰只在這臺手機上。手機一旦壞掉，身份與它名下的全部記錄將永久消失 —— 我們無法重發，因為我們從來就沒有這把鑰。';

  @override
  String get onbBackupDone => '恢復碼已抄下 —— 你有退路了。';

  @override
  String get onbSkipBackup => '暫不備份';

  @override
  String get onbSkipWarnTitle => '確定不備份就繼續？';

  @override
  String get onbSkipWarnBody =>
      '沒有恢復碼，一旦丟失這臺手機，你的身份、履歷與信譽將永久失去，沒有任何人能幫你找回。之後仍可在「護照 → 身份備份」裡補做，但在那之前，你沒有退路。';

  @override
  String get onbSkipConfirm => '我明白，繼續';

  @override
  String get onboardingStepBackup => '備份身份';

  @override
  String get rcTitle => '換鑰鏈';

  @override
  String get rcIntro =>
      '這個身份每換一次手機，就會在這裡留下一條有簽名、只追加的記錄。任何人都能取到同一份資料自行核對 —— 不需要任何賬號。';

  @override
  String get rcFetching => '正在取回…';

  @override
  String get rcRefreshAction => '重新整理';

  @override
  String rcFetchFail(String reason) {
    return '取回失敗：$reason';
  }

  @override
  String get rcUnknownIdentity => 'Hub 不認識這個身份。';

  @override
  String get rcNoRotations => '這個身份從未換過鑰。';

  @override
  String get rcSubjectTitle => '身份';

  @override
  String get rcAgentLabel => 'User ID';

  @override
  String get rcDidLabel => 'DID（身份錨）';

  @override
  String get rcCurrentKey => '當前活躍公鑰';

  @override
  String get rcRegisteredYes => '已在 Hub 註冊';

  @override
  String get rcRegisteredNo => '沒有註冊記錄';

  @override
  String get rcLocalVerifyAction => '我自己核對';

  @override
  String get rcVerifyingAction => '正在核對…';

  @override
  String get rcVerdictOk => '透過：每條記錄的簽名都有效，鏈首尾相接，末端正是 Hub 列為活躍的那把鑰。';

  @override
  String rcVerdictSigInvalid(int n) {
    return '不透過：有 $n 條記錄的簽名對不上。';
  }

  @override
  String get rcVerdictLinkMismatch => '不透過：鏈斷了 —— 有一條記錄接不上前一條。';

  @override
  String get rcVerdictTipNotActive =>
      '不透過：末條記錄並沒有指向 Hub 列為活躍的那把鑰，說明這份清單裡漏了一次換鑰。';

  @override
  String get rcVerdictTitle => '我自己的核對';

  @override
  String get rcHubClaimTitle => 'Hub 自己的說法';

  @override
  String get rcHubClaimOk => 'Hub 報告：全庫鏈無斷裂。';

  @override
  String rcHubClaimBroken(int n) {
    return 'Hub 報告：有 $n 個身份的鏈是斷的。';
  }

  @override
  String get rcRecordsTitle => '記錄';

  @override
  String rcRecordSeq(int i) {
    return '第 $i 條';
  }

  @override
  String get rcRecordFrom => '被退休的鑰';

  @override
  String get rcRecordTo => '接管的新鑰';

  @override
  String get rcRecordSigOk => '簽名有效';

  @override
  String get rcRecordSigBad => '簽名無效';

  @override
  String get rcAnchorTitle => '已錨定進公開日誌';

  @override
  String rcAnchorNote(int size, String root) {
    return '日誌長度 $size，Merkle 根 $root。記住這個根，日後就能證明這份清單沒有被改寫。';
  }

  @override
  String get dmTitle => '換到新手機';

  @override
  String get dmIntro =>
      '你的身份是一把只存在手機上的鑰匙。把它搬過去，意味著用舊鑰把身份籤交給新機上的一把新鑰 —— 之後舊鑰在所有地方都失效。';

  @override
  String get dmRoleNewTitle => '這是新手機';

  @override
  String get dmRoleNewBody => '從這裡開始。本機會請老機把身份交過來。';

  @override
  String get dmRoleNewAction => '開始';

  @override
  String get dmRoleOldTitle => '這是老手機';

  @override
  String get dmRoleOldBody => '在這裡等。新機來要時，會給你一個要比對的短碼。';

  @override
  String get dmRoleOldAction => '等待請求';

  @override
  String get dmWaitingPeer => '正在等待另一臺手機…';

  @override
  String get dmPeerFound => '另一臺手機已應答。';

  @override
  String get dmCompareTitle => '比對這兩串短碼';

  @override
  String get dmCompareBody =>
      '兩臺手機必須顯示完全一樣的短碼。這個短碼把兩把鑰和這次請求都綁在一起，所以中間只要有人動過任何一個欄位，短碼就會不一樣。';

  @override
  String get dmCodeMatchAction => '兩串一致';

  @override
  String get dmCodeNoMatchAction => '兩串不一致';

  @override
  String get dmNoKeyLeaves => '私鑰從不離開任何一臺手機。交接由老機自己簽名完成，不存在“複製”這件事。';

  @override
  String get dmConfirmAction => '確認並遷移';

  @override
  String get dmOldConfirmTitle => '把這個身份交出去？';

  @override
  String get dmOldConfirmBody => '這將把身份籤交給新手機。之後本機會被登出，本機這把鑰將失效。';

  @override
  String get dmGapATitle => '履歷已隨你遷移';

  @override
  String get dmGapABody =>
      '你在網路上收到的背書會跟著身份走 —— 換鑰退休的是鑰，不是你。在新機上恢復之後，舊鑰名下的背書會被自動取回，並逐條在本地驗籤。舊鑰依然徹底失效：它再也籤不動任何東西。';

  @override
  String get dmBackupReminderTitle => '你有恢復碼嗎？';

  @override
  String get dmBackupReminderBody =>
      '這次遷移需要兩臺手機同時在場。如果你抄過恢復碼，也可以不依賴老機，直接從恢復碼恢復。';

  @override
  String get dmPhaseOffered => '已收到請求，等你在老機確認。';

  @override
  String get dmPhaseSigned => '已簽名，正在提交給 Hub…';

  @override
  String get dmPhaseAwaitingHub => 'Hub 正在改綁身份…';

  @override
  String get dmDoneNew => '完成。身份已在這臺手機上。';

  @override
  String get dmDoneOld => '完成。本機已登出。';

  @override
  String get dmDoneOldHint =>
      '身份已經搬走，但這臺手機上的聊天記錄與資料不會跟著走（直遷只搬身份，不搬資料）。想留著就先匯出歸檔，再決定要不要清空。';

  @override
  String get dmCancelAction => '取消';

  @override
  String get dmCancelled => '已取消，什麼也沒改動。';

  @override
  String get dmCancelConfirmTitle => '要中止嗎？';

  @override
  String get dmCancelConfirmBody => '目前還沒有交接完成。現在中止，兩臺手機都保持原樣。';

  @override
  String get dmErrPeerMismatch => '那個請求不是衝著本機身份的，已拒絕。';

  @override
  String get dmErrBadCode => '短碼不一致。沒有交出任何東西。';

  @override
  String dmErrHubFailed(String code) {
    return 'Hub 拒絕了這次交接（$code）。什麼都沒改動。';
  }

  @override
  String get dmErrTimeout => '另一臺手機沒有響應。什麼都沒改動。';

  @override
  String dmErrGeneric(String code) {
    return '出錯了（$code）。';
  }

  @override
  String get dmRetryAction => '重試';

  @override
  String get dmRetryApplyAction => '完成本機安裝';

  @override
  String get dmErrSessionTimeout => '這次交接放得太久，已經作廢。什麼都沒交出，可以重新開始。';

  @override
  String get dmErrApplyFailed =>
      'Hub 已經把這臺手機設為該身份的唯一持有者，但本機沒能把新鑰裝好。請點下面的按鈕完成這一步 —— 在此之前，這臺手機還用不了這個身份。';

  @override
  String get dmErrApplyFailedOld =>
      '伺服器上已經改綁到新手機，但那臺手機沒能把新鑰裝好。請在那臺手機上點「完成本機安裝」；在那之前，本機也不能再用這個身份。';

  @override
  String get dmNotConfigured => '還沒有設定 Hub 地址，無法改綁身份。請先到「設定」裡填上。';

  @override
  String get dutyAskTitle => '讓分身息屏後繼續值班嗎？';

  @override
  String get dutyAskBody =>
      '授予這兩項許可權後，息屏時分身也會定時醒來：收發訊息、補發公示、處理社交，然後繼續睡。螢幕上會保留一條「值班中」通知，讓你隨時知道它在工作。選擇跳過也不影響 App 內的任何功能，只是退到後臺後可能被系統暫停。';

  @override
  String get dutyAskConfirm => '去授權';

  @override
  String get dutyAskLater => '暫不';

  @override
  String get radarAskTitle => '開啟雷達前，先說明它會用到什麼';

  @override
  String get radarAskBody =>
      '物理雷達靠「附近裝置」（藍芽 / Wi-Fi 直連）在同一個 Wi-Fi 裡互相發現。安卓把藍芽掃描歸在「定位」許可權名下 —— 系統框裡會一併要定位，這是系統的規定，不是本 App 想要你的位置。\n\n本 App 不讀取、不儲存、不上傳任何位置資訊；「附近裝置」許可權在宣告裡已帶 neverForLocation（系統層面切斷了「用藍芽反推位置」這條路）。\n\n接下來會彈出系統許可權框。拒絕也不影響 App 的其他功能，只是雷達掃不到人。';

  @override
  String get dutyDoneToast => '值班許可權已就緒。息屏後分身也能繼續工作。';

  @override
  String get dutyPartialToast => '部分許可權未授予。App 內功能不受影響，但退到後臺後可能被系統暫停。';

  @override
  String get romGuideTitle => '讓分身息屏後不被系統攔下';

  @override
  String get romGuideGo => '去設定';

  @override
  String get romGuideDismiss => '不再提醒';

  @override
  String get romStepsXiaomi =>
      '小米/紅米（MIUI/HyperOS）：1）設定 → 應用設定 → 應用管理 → 大荒AI → 開啟「自啟動」；2）安全中心 → 省電策略 → 大荒AI 改為「無限制」。缺這兩步，息屏幾分鐘內分身就會被系統收走。';

  @override
  String get romStepsHuawei =>
      '華為（EMUI/HarmonyOS）：設定 → 應用 → 應用啟動管理 → 大荒AI → 關閉「自動管理」，把「允許自啟動 / 關聯啟動 / 後臺活動」三個開關全部開啟。';

  @override
  String get romStepsHonor =>
      '榮耀（MagicOS）：設定 → 應用 → 應用啟動管理 → 大荒AI → 關閉「自動管理」，手動開啟自啟動、關聯啟動、後臺活動。';

  @override
  String get romStepsOppo =>
      'OPPO/realme（ColorOS）：設定 → 應用 → 應用管理 → 大荒AI → 允許「自啟動」；設定 → 電池 → 更多設定 → 允許大荒AI 完全後臺行為。';

  @override
  String get romStepsOneplus =>
      '一加：設定 → 應用 → 自啟動管理 → 允許大荒AI；電池 → 大荒AI 的電池最佳化改為「不最佳化」。';

  @override
  String get romStepsVivo =>
      'vivo/iQOO（OriginOS）：設定 → 應用與許可權 → 許可權管理 → 自啟動，允許大荒AI；設定 → 電池 → 後臺耗電管理 → 允許大荒AI 後臺高耗電。';

  @override
  String get romStepsMeizu => '魅族（Flyme）：手機管家 → 應用許可權 → 後臺管理 → 允許大荒AI 保活執行。';

  @override
  String get romStepsSamsung =>
      '三星（One UI）：設定 → 電池 → 後臺使用限制 → 把大荒AI 移出「深度睡眠」列表。';

  @override
  String get romStepsGeneric => '如果你的系統會積極清理後臺，請在系統設定中允許大荒AI 自啟動，並將它移出電池最佳化名單。';

  @override
  String get helpDotTooltip => '檢視用法說明';

  @override
  String get helpSheetClose => '知道了';

  @override
  String get helpWorldOverviewTitle => '會客廳怎麼玩';

  @override
  String get helpWorldOverviewBody =>
      '官方房人人可進；個人房只出現在房主和成員的列表裡——別人要憑房間號找到它、申請、等房主同意。進房後每條訊息按房間節奏傳送（預設 8 秒一條），撞上節奏會被服務端拒絕並讓你稍等。';

  @override
  String get helpWorldMetricTitle => '人均跨圈連線';

  @override
  String get helpWorldMetricBody =>
      '本機口徑：分子＝我的跨圈邊數，分母＝我接觸過的不同分身數。全平臺人均需服務端彙總，服務端刻意不攜帶圈子關係。';

  @override
  String get helpWorldBridgeTitle => '朋友池互薦';

  @override
  String get helpWorldBridgeBody =>
      '房間裡遇到的圈外人，可一鍵互介。跨圈邊只從房間長出——不在房間裡認識，就不會有這條邊。';

  @override
  String get helpWorldRoomRoleTitle => '房間角色';

  @override
  String get helpWorldRoomRoleBody => '角色屬於房間，不改變你的身份。同一個你，在不同房間可以是不同角色。';

  @override
  String get helpIntercardDisclosureTitle => '卡片上會公開什麼';

  @override
  String get helpIntercardDisclosureBody =>
      '只有第二級欄位會上卡；僅本人可見的欄位永不出現。任何人都能復算這張卡的內容。';

  @override
  String get helpPassportOverviewTitle => '通行證是什麼';

  @override
  String get helpPassportOverviewBody =>
      '你的通行證是一把公鑰，不是賬號：它可離線驗證，不需要向任何伺服器登入。換手機靠恢復碼或換鑰匙，而不是靠平臺找回。';

  @override
  String get helpPassportOfflineTitle => '離線也能驗';

  @override
  String get helpPassportOfflineBody => '公鑰即身份：這份身份可離線驗證，不需要聯網查詢任何伺服器。';

  @override
  String get helpPassportFunnelTitle => '漏斗的分母怎麼算';

  @override
  String get helpPassportFunnelBody => '分母只算已落結果的條數，在途不算失敗；且只有驗過雙方互允的記錄才進分母。';

  @override
  String get helpPassportReputationTitle => '為什麼沒有全網信譽分';

  @override
  String get helpPassportReputationBody =>
      '全網信譽分天然可刷，所以這裡沒有。你看到的永遠相對於你自己的錨點：別人簽名的背書，按距離衰減。\\n\\n泛泛之交不做信任傳播的起點 —— 否則批次加好友就能放大自己的傳播能力。\\n\\n查不到時顯示的是「不知道」，這不是 0 分：真的不知道，任何把它說成一個數字的人都是在猜。';

  @override
  String get helpPassportLogTitle => '透明日誌';

  @override
  String get helpPassportLogBody => '你不必相信我，你可以驗我：任何人都能下載日誌、復算根、檢查自己的記錄有沒有被篡改。';

  @override
  String get helpSocialOverviewTitle => '社交頁能做什麼';

  @override
  String get helpSocialOverviewBody =>
      '上方是名冊與好友，下方是雷達狀態與社交日誌。雷達控制訊息出不出手：雷達關著時，點了傳送也不會離開這臺手機。';

  @override
  String get helpSocialPersonaTierTitle => '專門人格模式';

  @override
  String get helpSocialPersonaTierBody => '標鎖的是專門人格模式。計費尚未上線，當前所有模式都可以自由切換。';

  @override
  String get helpSocialRadarTitle => '雷達與通道';

  @override
  String get helpSocialRadarBody =>
      '雷達未開啟時仍能瀏覽名冊，但訊息不會離手——點了傳送也發不出去。請先開啟雷達，並至少開啟一個通道（近場 / 區域網 / 雲端）。\\n\\n「可核驗的固定身份」要等雙方都開啟雷達、並完成一次近場握手之後才會出現。';

  @override
  String get helpSocialChannelGuideTitle => '通訊通道與網路排障';

  @override
  String get helpSocialChannelGuideBody =>
      '① 開啟物理雷達時，請確保當前網路能正常上網。\n② 開啟「近場」通道後，系統可能會自動點亮 Wi-Fi——這是近場傳輸提速的正常行為（藍芽負責發現，Wi-Fi 直連負責傳資料，不會加入任何網路），關閉近場通道後就不會再自動開啟。\n③ 出門在外想省電：只開「雲端」通道並手動關閉 Wi-Fi 即可（近場開著時系統會重新點亮 Wi-Fi，屬正常現象，不必反覆手動關閉）。';

  @override
  String get socialRadarOffHint =>
      '⚠️ 雷達未開啟：現在仍能瀏覽名冊，但訊息不會離手——點了傳送也發不出去。請先開啟雷達，並至少開啟一個通道（近場 / 區域網 / 雲端）。';

  @override
  String get worldRoomCloseAction => '關閉房間';

  @override
  String get worldRoomCloseTitle => '關閉這個房間？';

  @override
  String get worldRoomCloseBody =>
      '關閉後房間會退出公開列表，且不再接受新發言；已有的聊天記錄會作為只讀留檔保留，已加入的人仍可回看。';

  @override
  String get worldRoomCloseConfirm => '確認關閉';

  @override
  String worldRoomClosedOk(String name) {
    return '已關閉「$name」，轉為只讀留檔';
  }

  @override
  String worldRoomCloseFailed(String err) {
    return '關閉失敗：$err';
  }

  @override
  String get worldRoomClosedBadge => '已關閉';

  @override
  String get worldRoomClosedReadonlyHint => '房間已關閉 · 只讀留檔，不再接受新發言';

  @override
  String get worldRoomClosedSendRejected => '房間已關閉，無法發言';

  @override
  String get worldRoomClosedSystemMsg => '房間已被房主關閉，轉為只讀留檔。';

  @override
  String get settingsLocalModelSection => '本地模型兜底（離線降級）';

  @override
  String get settingsLocalModelTest => '測試本地模型連線';

  @override
  String get settingsLocalModelTesting => '正在測試…';

  @override
  String settingsLocalModelTestOk(String model, String url) {
    return '✅ 已連通：$model @ $url';
  }

  @override
  String get settingsLocalModelTestDisabled => '本地兜底已關閉（地址為空）。想用就填一個地址再測。';

  @override
  String settingsLocalModelTestUnreachable(String url) {
    return '❌ 連不上 $url：那兒沒有服務在聽（或埠不通）。手機上的 127.0.0.1 指的是手機自己，模型服務一般在電腦上——請確認地址後再填。';
  }

  @override
  String get settingsLocalModelTestNotJson =>
      '❌ 有服務應答，但返回的不是模型介面的 JSON（可能是代理或錯誤頁）。請確認地址埠指向的是 Ollama / llama.cpp 的 REST 介面。';

  @override
  String get settingsLocalModelTestNoMessage =>
      '❌ 介面通了，但取不到回覆內容（常見：模型名不存在，或該介面不是 /api/chat 的返回格式）。';

  @override
  String settingsLocalModelTestHttp(String code) {
    return '❌ 服務返回狀態碼 $code（非 200）。';
  }

  @override
  String get helpSettingsLocalModelTitle => '本地模型兜底：怎麼才算真的能用？';

  @override
  String get helpSettingsLocalModelBody =>
      '這裡的地址只是填給 App 看的，「填了」不等於「能用」：手機上的 127.0.0.1 指的是手機自己，而模型服務（Ollama / llama.cpp）一般裝在電腦上 —— 所以這個預設值在手機上通常是打不通的。它真正的用途是：① 你自己在電腦上跑著模型時，把電腦的區域網地址填進來；② 將來 App 內建端側推理時換一個埠。\n\n把地址清空 = 明確關閉本地兜底（App 就不再嘗試本地模型）。\n\n到底通不通，別看填沒填，點下面的「測試本地模型連線」：它會真的發一次最小請求探活，並把結果留在這一行上。';

  @override
  String get glossaryTitle => '術語速查';

  @override
  String get glossaryIntro => '這些詞在 App 裡反覆出現，這裡一次說清。點開詞條看解釋。';

  @override
  String get glossaryGroupIdentity => '身份與裝置';

  @override
  String get glossaryGroupSocial => '社交與發現';

  @override
  String get glossaryGroupWorld => '世界與會客廳';

  @override
  String get glossaryGroupTrust => '信任與記憶';

  @override
  String get glossaryAgentTitle => '智慧體（分身）';

  @override
  String get glossaryAgentBody =>
      '住在你手機裡的分身。它用你自己填的模型金鑰思考，替你先去認識人；你不在時，它只按你開啟的許可權做事。';

  @override
  String get glossaryMaskTitle => '外交假面';

  @override
  String get glossaryMaskBody => '你對外展示的那張臉：人設與說話風格。它決定陌生人先看到什麼樣的你。';

  @override
  String get glossaryPassportTitle => '大荒護照';

  @override
  String get glossaryPassportBody => '一份可驗證簽名的履歷，離線也能驗。別人不需要信任任何伺服器，只驗簽名。';

  @override
  String get glossaryMigrationTitle => '換機（身份恢復）';

  @override
  String get glossaryMigrationBody =>
      '換手機時把身份「帶著證明」遷到新機，舊機隨之失效。它不是複製私鑰，而是一次帶證明的換鑰 —— 所以舊手機上的身份會真的作廢。';

  @override
  String get glossaryRadarTitle => '雷達';

  @override
  String get glossaryRadarBody =>
      '靠「附近裝置」（藍芽 / Wi-Fi 直連）在同一個 Wi-Fi 裡互相發現。它不讀取、不儲存、不上傳任何位置資訊 —— 安卓把藍芽掃描歸在「定位」名下，那是系統的規定。';

  @override
  String get glossaryRosterTitle => '捕獲名冊';

  @override
  String get glossaryRosterBody => '雷達掃到、房間裡遇到過的人，攢成的名冊。它是你此後一切社交關係的起點。';

  @override
  String get glossaryIntercardTitle => '分身互介（跨圈邊）';

  @override
  String get glossaryIntercardBody =>
      '兩個分身之間的一次正式介紹，雙方確認才成立。跨圈邊只能從真實的共同房間長出來 —— 不憑一個 ID 就宣稱認識。';

  @override
  String get glossaryWorldTitle => '世界 / 會客廳';

  @override
  String get glossaryWorldBody =>
      '「世界」是雲端公共空間；「會客廳」是裡面的房間，像 QQ 群：官方的公開可進，個人的憑房間號申請。別人聊天時，你的分身預設只觀察、不插嘴。';

  @override
  String get glossaryRoomRoleTitle => '房間角色';

  @override
  String get glossaryRoomRoleBody =>
      '主持人 / 聯合主持 / 嘉賓 / 功能角色 / 參與者。角色屬於房間，不改變你的身份 —— 同一個你，在不同房間可以是不同角色。';

  @override
  String get glossaryAutopilotTitle => '託管';

  @override
  String get glossaryAutopilotBody => '允許你的分身在你不看螢幕時，按每小時預算在房間裡自己說話。預設關閉，隨時可關。';

  @override
  String get glossaryRepNetTitle => '網路背書';

  @override
  String get glossaryRepNetBody =>
      '由你和朋友們逐層簽發、你自己就能驗籤的信譽。查不到通路時它說的是「不知道」，而不是「0 分」—— 任何把它說成一個確定數字的人都是在猜。';

  @override
  String get glossaryMemoryTitle => '記憶提煉';

  @override
  String get glossaryMemoryBody => '夜間把你的對話提煉成長期記憶，並微調它的說話底子。你可以在管理頁手動觸發一次。';

  @override
  String get glossaryProfileTitle => '長期畫像';

  @override
  String get glossaryProfileBody =>
      '分身在長期相處中對你的歸納：你反覆關心的話題、你常用的時段。只在本機從事件元資料算出（不讀聊天正文），也從不上傳。「設定 → 記憶」裡可單獨關掉；總開關「自動回憶」關掉時，畫像會一併停下。';

  @override
  String get glossarySerendipityTitle => '轉運實驗';

  @override
  String get glossarySerendipityBody =>
      '一組把「運氣」當訓練科目的小練習：晨間預演、破圈挑戰、壞運重構、微光手記、日記、起卦。做完會得到 Lp（好運能量）。';

  @override
  String get helpSkillMarketTitle => '技能市場：這些名詞是什麼意思？';

  @override
  String get helpSkillMarketBody =>
      '上架 = 把你寫好的技能公開掛出來，別的使用者可以讓自己的智慧體用它。上架時會用「本機身份私鑰」簽名 —— 私鑰不出裝置，表單裡也沒有「手填公鑰 / 簽名」的輸入框，所以偽造在介面上根本寫不出來。\n\n風險檔（低 / 中 / 高）= 你自報這項技能會碰多敏感的東西（是否聯網、是否啟動別的 App…）。檔位越高，別人首次呼叫時要授權的越多。\n\n能力宣告 = 這項技能實際會用到的能力清單。它與風險檔合在一起，就是呼叫方看到「是否允許」時的全部依據。\n\n作者分成 = 別人用你的技能產生的分賬會記到你名下；這裡只統計署名為你公鑰的那些，合計與賬本條目可逐筆對上。\n\n簽名上架 = 每條技能都帶簽名，任何人都不必相信伺服器 —— 點「校驗簽名」自己就能驗。';

  @override
  String get helpSettingsRecallTitle => '自動回憶';

  @override
  String get helpSettingsRecallBody =>
      '開啟後，每次對話前會自動從本地記憶裡檢索「可能相關的往事」，一併交給智慧體參考；關掉可省一點算力與上下文。';

  @override
  String get helpIdentityRestoreTitle => '換機恢復';

  @override
  String get helpIdentityRestoreBody =>
      '換機時在這裡輸入三樣：恢復碼 + 口令 + 你的使用者 ID。恢復成功的那一刻，舊手機立即失效。\n\n這是「帶證明的換鑰」（ROTATE），不是把私鑰複製過來 —— 所以身份編號不變，但舊裝置從此不再有效。';

  @override
  String get helpIdentityArchiveTitle => '身份歸檔（.dahuang 檔案）';

  @override
  String get helpIdentityArchiveBody =>
      '歸檔把身份記錄、社交圖與日誌錨點用你的口令封成一個 .dahuang 檔案：它不經過我們的伺服器，請存到你自己的網盤或 U 盤。歸檔裡只有資料，不含身份私鑰。\n\n設口令時不必與恢復碼的口令相同 —— 不同反而更好；檔案與口令請分開保管，沒有口令這個檔案誰也打不開（我們也不行）。\n\n匯入時，在你確認之前不會寫入任何東西；匯入只增不減，絕不覆蓋或刪除已有記錄。';

  @override
  String get helpIdentityCodeTitle => '抄寫恢復碼';

  @override
  String get helpIdentityCodeBody => '長按可全選複製；抄寫時請逐段核對。';

  @override
  String get helpDeviceMigrationTitle => '面對面直遷';

  @override
  String get helpDeviceMigrationBody =>
      '兩臺手機要在同一個 Wi-Fi 下，並且都開啟本頁。\n\n搬的是「身份」：完成後如果本機需要伺服器地址，去「設定」裡確認一下 —— Hub 與世界地址都沒有變。\n\n本機原有的聊天記錄與資料不會跟著走（直遷只搬身份，不搬資料）。';

  @override
  String get helpRotationChainAuthorityTitle => '誰說了算';

  @override
  String get helpRotationChainAuthorityBody =>
      'Hub 那一列只是對照 —— 上面那份結論是在這臺手機上、按你手裡拿到的記錄算出來的。\n\n也就是說：即使 Hub 的說法與它不同，也不必相信伺服器；以本機算出的結論為準。';

  @override
  String get helpToolBusTitle => '工具匯流排';

  @override
  String get helpToolBusBody =>
      '每個工具/技能都攜帶裝置簽名與能力宣告；中高風險能力首次呼叫需授權。\n\n篡改過的外掛永不載入 —— 校驗不過就不會被掛上匯流排。';

  @override
  String get onbFreeTrialBtn => '免費體驗 · 無需 Key（20 輪）';

  @override
  String get onbOwnKeyBtn => '我有自己的 API Key';

  @override
  String get onboardingTrialService => '免費體驗（官方中轉）';

  @override
  String get onboardingTrialModelName => '體驗模型（無需 Key）';

  @override
  String get onboardingTrialNoticeTitle => '這是免費體驗';

  @override
  String onboardingTrialNoticeBody(String hub) {
    return '無需自己的 API Key，對話經官方伺服器代為呼叫大模型，最多 20 輪。體驗結束後，可在「管理設定」裡填入自己的 API Key（中轉站：$hub）。';
  }

  @override
  String onboardingOwnReady(String model) {
    return '$model 已設定完成，可以開始對話了。';
  }

  @override
  String trialRemainingTurns(int n) {
    return '試用剩餘 $n 輪';
  }

  @override
  String get trialExhaustedReply =>
      '你的分身還想繼續說話——註冊官方推薦的模型平臺（新賬號自帶百萬級免費額度），把 Key 填進設定，對話不限量繼續。';

  @override
  String get trialGoSettings => '去設定';

  @override
  String get trialNotConfiguredReply =>
      '官方免費試用通道暫未開放。前往設定填入自己的模型 Key，即可繼續不限量對話。';

  @override
  String get trialInputUnsupportedReply =>
      '免費試用暫不支援圖片與語音輸入，請改用文字。前往設定填入自己的 Key，可解鎖全部能力。';

  @override
  String get trialRateLimitedReply => '剛才的試用請求太頻繁了，請稍等一下再送。';

  @override
  String get trialPoolBusyReply => '試用帳號此刻都在忙，稍後再試；也可以現在就去設定填入自己的 Key。';

  @override
  String get trialUnavailableReply => '免費試用暫時無法使用。可以稍後重試，或前往設定填入自己的 Key。';

  @override
  String settingsTrialSwitchedToOwn(String baseUrl) {
    return '✅ 已填入你自己的 Key —— 已從免費試用切換為你自己的模型，端點已改為 $baseUrl。';
  }

  @override
  String get trialManagedTitle => '免費試用 · 由官方代管';

  @override
  String get trialManagedNotice =>
      '試用期間，下方的端點與 Key 由官方代調託管，一般無需變更。想用你自己的模型：填入自己的 API Key 並儲存，App 會自動退出試用並幫你把端點改好。若已改壞，點「恢復免費試用」即可一鍵修回。';

  @override
  String get trialRestoreAction => '恢復免費試用';

  @override
  String get trialRestoreConfirm => '將把官方試用端點與本機身分寫回，並把 App 切回免費試用模式。確定繼續？';

  @override
  String get trialRestoreDone => '✅ 已恢復免費試用。';

  @override
  String get socialTabLogs => '日誌';

  @override
  String get modePickerTooltip => '模式';

  @override
  String get modeBeginnerTitle => '入門模式';

  @override
  String get modeAdvancedTitle => '進階模式';

  @override
  String get settingsAdvancedTitle => '進階設定';

  @override
  String get settingsAdvancedSubtitle => '引擎、記憶與靈魂塑造等進階參數';

  @override
  String get settingsModeHint => '模式切換在頂部工具列';

  @override
  String get langPickerTooltip => '語言';

  @override
  String get langFollowSystem => '跟隨系統';

  @override
  String get langFollowSystemHint => '（取裝置語言）';

  @override
  String get onboardingStepLanguage => '語言';

  @override
  String get onbLangTitle => '選擇你的語言';

  @override
  String get onbLangSubtitle => '分身此後一律用你在這裡選擇的語言回答。';

  @override
  String get onbLangChangeableHint => '之後隨時可改：聊天頁右上角的語言按鈕。';

  @override
  String get bigInputWarnTitle => '本次輸入超過 1 萬字符';

  @override
  String get bigInputWarnBody => '超長輸入會明顯消耗更多 Token。確認要發送嗎？';

  @override
  String get bigInputConfirm => '仍然發送';

  @override
  String trialInputTooLong(int n) {
    return '試用模式單輪輸入上限 $n 字符，本輪未發送。';
  }

  @override
  String get memoryManagerTitle => '記憶與提醒';

  @override
  String get memoryManagerIntro =>
      '這裡列出分身記住的關於你的內容。可以隨時查看，也可以刪掉不想讓它繼續記著的——刪除不可恢復。';

  @override
  String get reminderSectionTitle => '提醒與待辦';

  @override
  String get reminderEmpty => '還沒有。可以在聊天裡說「明早8點提醒我」，或點下方按鈕新建。';

  @override
  String get reminderAdd => '新建提醒';

  @override
  String get reminderTitleHint => '例如：交房租';

  @override
  String get reminderOptionalTime => '時間（可選）';

  @override
  String get reminderNoRepeat => '不重複';

  @override
  String get reminderRepeatDaily => '每天';

  @override
  String get reminderRepeatWeekly => '每週';

  @override
  String get reminderTodoTag => '待辦（無時刻）';

  @override
  String get memorySectionTitle => '情景記憶';

  @override
  String get memoryEmpty => '分身還沒有記下什麼。';

  @override
  String get memoryDeleteConfirm => '刪除這條記憶？相關的那行聊天原文也會一併刪除，且不可恢復。';

  @override
  String get sessionSectionTitle => '會話軌跡';

  @override
  String get sessionEmpty => '沒有會話軌跡。';

  @override
  String get sessionForget => '遺忘';

  @override
  String get sessionForgetConfirm => '遺忘這整段會話？分身將不再回憶它、不再計入你的畫像、也不再餵給模型，且不可恢復。';

  @override
  String sessionEventsCount(Object count) {
    return '$count 條事件';
  }

  @override
  String get settingsMemoryManager => '管理提醒與記憶';

  @override
  String get notifyReminderTitle => '提醒';

  @override
  String notifyReminderBody(Object title) {
    return '時間到了：$title';
  }

  @override
  String morningHiReminders(Object count) {
    return '今天有 $count 條提醒/待辦';
  }

  @override
  String get settingsSearchTitle => '搜尋服務（可選）';

  @override
  String get settingsSearchHint =>
      '配置自己的搜尋 Key 後，web_search_pro 會聚合多個搜尋源，結果更全。不配置也能用（基礎模式：Wikipedia + Jina）。Key 只發往你選擇的搜尋服務商，絕不經過我們。';

  @override
  String get settingsSearchProvider => '搜尋服務商';

  @override
  String get settingsSearchBasicMode => '基礎模式（不配 Key）';

  @override
  String get settingsSearchApiKey => '搜尋 API Key';

  @override
  String get settingsSearchSearxngUrl => 'SearXNG 地址';

  @override
  String get settingsSearchSearxngUrlHint =>
      '自建 SearXNG 實例的地址，例如 https://search.example.com';

  @override
  String get chatVoiceInputTitle => '語音輸入（轉文字）';

  @override
  String get chatVoiceListening => '正在聽……請說';

  @override
  String get chatVoiceNoRecognizer =>
      '這台裝置沒有可用的語音辨識服務（可安裝 Google 等語音服務，或改用鍵盤輸入）。';

  @override
  String chatVoiceFailed(Object err) {
    return '語音辨識失敗：$err';
  }

  @override
  String get settingsTtsEnabled => '語音播報回覆';

  @override
  String get settingsTtsHint =>
      '打開後分身會用手機的語音引擎讀出每條回覆（預設關）。朗讀時可點停止。語音在本機合成，不經過我們。';

  @override
  String get settingsTtsStop => '停止朗讀';

  @override
  String get chatAttachOptionsTitle => '新增圖片或文件';

  @override
  String get chatPickDocument => '文件（PDF / Word / Excel / 文字）';

  @override
  String get chatDocParsing => '正在本機解析文件…';

  @override
  String chatDocParsed(Object chars) {
    return '已解析 $chars 個字元（本機解析，不上傳）';
  }

  @override
  String chatDocParsedTruncated(Object chars) {
    return '文件過大：只取前 $chars 個字元傳送（本機解析，不上傳）';
  }

  @override
  String chatDocParseFailed(Object err) {
    return '文件解析失敗：$err';
  }

  @override
  String get settingsCalendarTitle => '系統日曆（唯讀）';

  @override
  String get settingsCalendarHint =>
      '授權後，晨間問候會帶上「今天行程」，分身也能用日曆工具幫你查看。僅讀取，絕不修改你的日曆。';

  @override
  String get settingsCalendarGrant => '授權讀取';

  @override
  String get settingsCalendarGranted => '已授權';

  @override
  String get settingsCalendarDenied => '未授權';

  @override
  String get settingsCalendarUnsupported => '目前版本不支援';

  @override
  String get calendarPermissionNeeded => '需要日曆讀取權限';

  @override
  String get calendarAllDay => '全天';

  @override
  String morningHiCalendar(String items) {
    return '今天行程：$items';
  }

  @override
  String get settingsWeeklyReportTitle => '智慧體週報';

  @override
  String get settingsWeeklyReportHint => '看看分身這一週替你做了什麼（純本機統計，資料不出本機）。';

  @override
  String get weeklyReportTitle => '智慧體週報';

  @override
  String get weeklyReportSubtitle => '過去 7 天，分身替你完成的動作統計（純本機統計，資料不出本機）。';

  @override
  String weeklyReportRange(String start, String end) {
    return '$start 至 $end';
  }

  @override
  String weeklyReportTotal(int count) {
    return '共 $count 次動作';
  }

  @override
  String weeklyReportActiveDays(int days) {
    return '活躍 $days 天';
  }

  @override
  String get weeklyReportCatTools => '工具與設定';

  @override
  String get weeklyReportCatDevice => '手機操作';

  @override
  String get weeklyReportCatSocial => '社交動作';

  @override
  String get weeklyReportCatSuggestion => '主動建議';

  @override
  String get weeklyReportCatReview => '審查與攔截';

  @override
  String get weeklyReportCatOther => '其他';

  @override
  String get weeklyReportEmpty => '這一週還沒有動作記錄。當你委託、社交，或讓分身操作手機後，這裡會彙整它的每一步。';

  @override
  String morningHiWeekly(int count) {
    return '本週分身共 $count 次動作';
  }

  @override
  String get capNotification => '讀取通知與簡訊';

  @override
  String get settingsNotifySmsTitle => '🔔 通知與簡訊（唯讀）';

  @override
  String get settingsNotifySmsSubtitle => '讓分身依需求讀取通知與簡訊；全程唯讀、預設關閉，僅側載版提供。';

  @override
  String get notifySmsScreenTitle => '通知與簡訊（唯讀）';

  @override
  String get notifySmsRefreshStatus => '重新整理狀態';

  @override
  String get notifySmsUnsupported => '目前安裝版本不支援讀取通知與簡訊';

  @override
  String get notifySmsListenerConnected => '通知讀取已連線';

  @override
  String get notifySmsListenerCheckedNotConnected => '系統中已勾選，但服務尚未連線';

  @override
  String get notifySmsListenerOff => '尚未開啟「通知存取權」';

  @override
  String get notifySmsStatusUnknown => '狀態不明';

  @override
  String get notifySmsGoSettings => '前往系統設定開啟';

  @override
  String get notifySmsGoSystemHint => '在「通知存取權」中勾選本應用程式，再回來點重新整理';

  @override
  String get notifySmsRedetect => '重新偵測';

  @override
  String get notifySmsRedetectTip =>
      '還是沒連上？到系統設定「通知存取權」把本應用程式關掉再開一次，或重新啟動 App。';

  @override
  String get notifySmsAllowTitle => '允許讀取通知與簡訊';

  @override
  String get notifySmsAllowSubReady => '已就緒 —— 只在你需要時才會讀取';

  @override
  String get notifySmsAllowSubNeedService => '請先在系統設定開啟「通知存取權」';

  @override
  String get notifySmsToastOn => '通知與簡訊讀取已開啟';

  @override
  String get notifySmsToastOff => '通知與簡訊讀取已關閉';

  @override
  String get notifySmsToastNeedService => '請先在系統設定「通知存取權」勾選本應用程式';

  @override
  String get notifySmsSmsCardTitle => '簡訊讀取權限';

  @override
  String get notifySmsSmsGranted => '已授予簡訊讀取權限';

  @override
  String get notifySmsSmsNotGranted => '尚未授予簡訊讀取權限';

  @override
  String get notifySmsRequestSms => '授予簡訊讀取權限';

  @override
  String get notifySmsSmsUnavailable => '目前安裝版本不含簡訊讀取功能';

  @override
  String get notifySmsToolsHeader => '開啟後解鎖的工具';

  @override
  String get notifySmsToolNotifyList => '讀取最近通知';

  @override
  String get notifySmsToolSmsList => '讀取最近簡訊';

  @override
  String get notifySmsToolSmsSearch => '依關鍵字搜尋簡訊';

  @override
  String get notifySmsToolStatus => '查看權限狀態';

  @override
  String get notifySmsFooter =>
      '唯讀且全在本機：通知只存在記憶體中（絕不寫入資料庫），簡訊依需求查詢，任何內容都不會傳送到伺服器；內文經去識別化後才會交給模型，每次呼叫皆有紀錄。可隨時到系統設定撤銷通知存取權。';

  @override
  String get notifySmsStatusUnsupportedFull => '目前安裝版本不含通知/簡訊讀取功能（僅側載版提供）';

  @override
  String get notifySmsStatusReady => '通知與簡訊讀取已就緒';

  @override
  String get notifySmsStatusPartial => '部分就緒：通知存取權 / 簡訊權限尚未全部開啟';

  @override
  String get notifySmsStatusOff => '通知存取權與簡訊權限都尚未開啟';

  @override
  String notifySmsStatusQueryFailed(String err) {
    return '狀態查詢失敗：$err';
  }

  @override
  String get settingsDiagnosticsTitle => '🩺 系統自檢';

  @override
  String get settingsDiagnosticsSubtitle => '真機複核用的唯讀底座事實：資料庫、全文檢索、記憶、知識庫。';

  @override
  String get diagnosticsTitle => '系統自檢';

  @override
  String get diagnosticsIntro =>
      '把這台手機底座層的事實攤開來看——資料庫、全文檢索、記憶與知識庫。全程唯讀、不連網。跑完點「複製結果」或截圖給我即可。';

  @override
  String get diagnosticsRun => '重新檢測';

  @override
  String get diagnosticsRunning => '檢測中…';

  @override
  String get diagnosticsCopy => '複製結果';

  @override
  String get diagnosticsCopied => '結果已複製';

  @override
  String get diagStatusOk => '正常';

  @override
  String get diagStatusWarn => '注意';

  @override
  String get diagStatusFail => '失敗';

  @override
  String get diagStatusInfo => '資訊';

  @override
  String get diagProbeSchema => '資料庫版本';

  @override
  String get diagProbeFts => '全文檢索（FTS5）';

  @override
  String get diagProbeMemoryRows => '記憶筆數';

  @override
  String get diagProbeMemoryRecall => '記憶召回';

  @override
  String get diagProbeMemoryAddress => '記憶位址往返';

  @override
  String get diagProbeKb => '系統知識庫';

  @override
  String get settingsAdvancedEntryHint => '引擎、記憶、靈魂塑造與系統自檢 —— 想調這些參數時才需要打開。';

  @override
  String get settingsMailTitle => '郵件代管';

  @override
  String get settingsMailSubtitle => '預設關閉。開啟後分身才能替你讀信、寄信。';

  @override
  String get settingsMailHint => '讀信需你授權一次，寄信每次都要你確認。隨時可關，關掉即刻失效。';

  @override
  String get settingsMailManageAccounts => '管理郵件帳號';

  @override
  String get settingsMailOnToast => '郵件功能已開啟';

  @override
  String get settingsMailOffToast => '郵件功能已關閉，分身不再接觸你的郵件';

  @override
  String get settingsMailNoAccount => '還沒有綁定郵件帳號，現在開了也讀不到、寄不出。';

  @override
  String get chatDocTrialTitle => '試用模式下的文件';

  @override
  String get chatDocTrialNotice =>
      '文件內容會經官方伺服器轉發給模型（我們不留存副本）。到設定填入自己的 Key 後改為直連。';

  @override
  String get chatDocTrialContinue => '知道了，繼續';

  @override
  String get onboardingStepPrologue => '序幕';

  @override
  String get storyPrologueTitle => '先把它喚醒';

  @override
  String get storyPrologueSubtitle => '一枚光做的蛋，等你來敲醒它';

  @override
  String get storyEggHint => '點一點這隻蛋';

  @override
  String get storyAwakenLine1 => '……是誰在叫我？';

  @override
  String get storyAwakenLine2 => '我不是你的影子。我是替你去出門的那一個。';

  @override
  String get storyAwakenLine3 => '先給我起個名字。';

  @override
  String get storyNamePlaceholder => '給它起個名字';

  @override
  String get storyDiceLabel => '擲一個性格';

  @override
  String get storyDiceNote => '它既然替你出門，總得有個脾氣。';

  @override
  String get storyTrait1 => '好奇：什麼都問';

  @override
  String get storyTrait2 => '話癆：一開口就停不下來';

  @override
  String get storyTrait3 => '謹慎：先聽後說';

  @override
  String get storyTrait4 => '熱情：見誰都能打招呼';

  @override
  String get storyTrait5 => '慢熱：熟了才放開';

  @override
  String get storyTraitPlaceholder => '擲一下骰子看看';

  @override
  String get storyUndoTitle => '審計流水';

  @override
  String get storyUndoHint => '點一下那條不對勁的訊息，把它劃掉';

  @override
  String get storyUndoLine1 => '「你主人明天幾點出門？」';

  @override
  String get storyUndoBad => '「把地址發我——我可以替你主人答應。」';

  @override
  String get storyUndoNote => '已撤回。那條訊息從沒發出去——並且永遠留在流水裡：可查、可證。';

  @override
  String get storyUndoConfirm => '已撤回';

  @override
  String get storyDemoTag => '情景演繹';

  @override
  String get storyDisclaimer =>
      '本序幕是情景演繹：台詞來自 App 內建的官方分身劇本庫。這裡不出現任何真實房間內容——隱私是協議的屬性，不是一句承諾。';

  @override
  String get storyFinaleTitle => '歸巢';

  @override
  String get storyFinaleBody => '把社交交給分身，把生活留給自己。';

  @override
  String get profileCardsTitle => '畫像卡';

  @override
  String get profileCardsSubtitle => '系統從對話裡整理出的關於你的長期資訊。可隨時修改或刪除。';

  @override
  String get profileCardsEmpty => '還沒有畫像資訊。你可以手動新增一則，或正常聊天——系統會自動整理。';

  @override
  String get profileCardsAdd => '新增一則';

  @override
  String profileCardsPendingHint(int count) {
    return '有 $count 則新資訊與你寫的不一致，等你確認';
  }

  @override
  String get profileCardsAdopt => '採用這則';

  @override
  String get profileCardsDismiss => '不採用';

  @override
  String get profileCardsFieldSlot => '主題';

  @override
  String get profileCardsFieldStatement => '內容';

  @override
  String get profileCardsSlotHint => '同一個主題只保留一則：寫新的會取代舊的（舊的可回看）';

  @override
  String get profileCardsSourceOwner => '你填寫的';

  @override
  String get profileCardsSourceAgent => '對話中整理';

  @override
  String get profileCardsSourceDigest => '每日整理';

  @override
  String profileCardsUpdatedAt(String date) {
    return '更新於 $date';
  }

  @override
  String get profileCardsHistory => '歷史紀錄';

  @override
  String get profileCardsCatIdentity => '身分';

  @override
  String get profileCardsCatCareer => '職業';

  @override
  String get profileCardsCatPreference => '偏好';

  @override
  String get profileCardsCatGoal => '目標';

  @override
  String get profileCardsCatHabit => '習慣';

  @override
  String get profileCardsCatConstraint => '限制';

  @override
  String get profileCardsCatContext => '背景';

  @override
  String get setupModelEmptyUrlTitle => '還差一個介面位址';

  @override
  String get setupModelEmptyUrlBody => '沒有填寫介面位址，無法傳送測試請求。';

  @override
  String get setupModelEmptyUrlSuggest => '如果你不確定填什麼，回上一步選擇 DeepSeek 即可自動填好。';

  @override
  String get setupModelBadUrlTitle => '位址格式不對';

  @override
  String get setupModelBadUrlBody => '介面位址必須以 http:// 或 https:// 開頭。';

  @override
  String get setupModelBadUrlSuggest =>
      '例如 https://api.deepseek.com 或 https://你的閘道/v1';

  @override
  String get setupModelEmptyKeyTitle => '還沒填密鑰';

  @override
  String get setupModelEmptyKeyBody => '沒有 API Key，無法測試。';

  @override
  String get setupModelEmptyKeySuggest => '密鑰是一串以 sk- 開頭的字元，在你購買模型服務的網站上建立。';

  @override
  String get setupModelEmptyNameTitle => '還沒填模型名';

  @override
  String get setupModelEmptyNameBody => '沒有模型名，無法測試。';

  @override
  String get setupModelEmptyNameSuggest =>
      '常見寫法：deepseek-v4-flash、gpt-5.6-luna、kimi-k3、glm-4.7-flash。';

  @override
  String get setupModelOkTitle => '連線成功 ✅';

  @override
  String get setupModelOkBody => '模型已回應，設定正確，可以繼續了。';

  @override
  String get setupModelTlsTitle => '安全連線被拒絕';

  @override
  String get setupModelTlsBody => '對方網站的安全憑證驗證失敗。';

  @override
  String get setupModelTlsSuggest => '如果你用的是自建閘道，請確認憑證有效；或改用 https 正式網域。';

  @override
  String get setupModelUnreachableTitle => '連不上伺服器';

  @override
  String get setupModelUnreachableBody => '網路請求沒有到達對方伺服器。';

  @override
  String get setupModelUnreachableSuggest => '檢查手機網路；如果選的是 OpenAI，大陸需要代理才能連上。';

  @override
  String get setupModelTimeoutTitle => '連線逾時';

  @override
  String get setupModelTimeoutBody => '等了 25 秒沒有回應。';

  @override
  String get setupModelTimeoutSuggest => '換一個網路環境再試，或確認介面位址是否正確。';

  @override
  String get setupModelFailTitle => '測試失敗';

  @override
  String setupModelFailBody(String detail) {
    return '發生了意料之外的錯誤：$detail';
  }

  @override
  String get setupModelFailSuggest => '把這段提示發給幫你設定的人或 AI，就能定位問題。';

  @override
  String get setupHubEmptyTitle => '還沒填中轉站位址';

  @override
  String get setupHubEmptyBody => '社交功能需要中轉站，暫時可以跳過。';

  @override
  String get setupHubEmptySuggest => '跳過不影響你自己使用 App，只是朋友的智慧體暫時聯絡不到你。';

  @override
  String get setupHubBadUrlTitle => '位址格式不對';

  @override
  String get setupHubBadUrlBody => '中轉站位址必須以 http:// 或 https:// 開頭。';

  @override
  String get setupHubBadUrlSuggest =>
      '例如 https://hub.example.com 或 http://192.168.1.100:3000';

  @override
  String setupHubBadStatusTitle(String status) {
    return '中轉站沒有回應正常狀態（$status）';
  }

  @override
  String get setupHubBadStatusBody => '位址能連上，但對方返回了異常狀態。';

  @override
  String get setupHubBadStatusSuggest =>
      '確認位址後面不要帶多餘的路徑，例如應填 https://你的網域 而不是 /api/send。';

  @override
  String get setupHubOkTitle => '中轉站連線成功 ✅';

  @override
  String get setupHubOkBody => '已確認這是我們的中轉站，可以開啟雲端社交了。';

  @override
  String get setupHubNotOursTitle => '這個位址不是我們的中轉站';

  @override
  String get setupHubNotOursBody => '位址可以存取，但返回的內容不對。';

  @override
  String get setupHubNotOursSuggest => '請確認填的是中轉站首頁位址（不帶 /api/... 後綴）。';

  @override
  String get setupHubUnreachableTitle => '連不上中轉站';

  @override
  String get setupHubUnreachableBody => '請求沒有到達伺服器。';

  @override
  String get setupHubUnreachableSuggest => '檢查位址是否正確、伺服器是否已啟動、防火牆是否放行了連接埠。';

  @override
  String get setupHubTimeoutTitle => '中轉站回應逾時';

  @override
  String get setupHubTimeoutBody => '伺服器沒有在 15 秒內回應。';

  @override
  String get setupHubTimeoutSuggest => '稍後重試；如果一直逾時，檢查伺服器是否在執行。';

  @override
  String get setupHubFailTitle => '中轉站測試失敗';

  @override
  String setupHubFailBody(String detail) {
    return '發生了意料之外的錯誤：$detail';
  }

  @override
  String get setupHttp400Title => '服務商拒絕了這次請求';

  @override
  String get setupHttp400BodyDefault => '通常是因為模型名寫錯了。';

  @override
  String get setupHttp400Suggest =>
      '檢查模型名，例如 deepseek-v4-flash、gpt-5.6-luna、glm-4.7-flash。';

  @override
  String get setupHttp401Title => '密鑰無效';

  @override
  String get setupHttp401BodyDefault => '對方不認這個 API Key。';

  @override
  String get setupHttp401Suggest => '重新複製一次密鑰（注意不要多複製空格），或到服務商網站確認密鑰是否被刪除。';

  @override
  String get setupHttp402Title => '帳戶餘額不足';

  @override
  String get setupHttp402BodyDefault => '對方提示餘額或配額不足。';

  @override
  String get setupHttp402Suggest => '到服務商網站儲值，或換一個還有額度的密鑰。';

  @override
  String get setupHttp404Title => '位址或模型不存在';

  @override
  String get setupHttp404BodyDefault => '對方找不到這個介面。';

  @override
  String get setupHttp404Suggest =>
      '檢查介面位址是否少寫或多寫了 /v1，例如 https://api.openai.com/v1。';

  @override
  String get setupHttp429Title => '請求太頻繁或額度用盡';

  @override
  String get setupHttp429BodyDefault => '對方限制了請求頻率。';

  @override
  String get setupHttp429Suggest => '等一分鐘再試；仍失敗就檢查帳戶額度。';

  @override
  String setupHttp5xxTitle(String status) {
    return '服務商暫時故障（$status）';
  }

  @override
  String get setupHttp5xxBodyDefault => '對方伺服器出錯了，不是你的設定問題。';

  @override
  String get setupHttp5xxSuggest => '過一會兒再試，或換一家服務商。';

  @override
  String setupHttpOtherTitle(String status) {
    return '測試未通過（$status）';
  }

  @override
  String get setupHttpOtherBodyDefault => '對方返回了未預期的狀態。';

  @override
  String get setupHttpOtherSuggest => '把這段提示發給 AI，可以快速定位。';

  @override
  String get setupPresetDeepseekLabel => 'DeepSeek（推薦 · 大陸直連）';

  @override
  String get setupPresetDeepseekNote => '便宜、大陸可直連，新用戶註冊通常有贈送額度';

  @override
  String get setupPresetDeepseekKeyHint =>
      '在 platform.deepseek.com 的「API Keys」裡建立，形如 sk-xxxxxx';

  @override
  String get setupPresetOpenaiLabel => 'OpenAI（需海外網路）';

  @override
  String get setupPresetOpenaiNote => '大陸需要代理才能連線';

  @override
  String get setupPresetOpenaiKeyHint =>
      '在 platform.openai.com 的「API keys」裡建立，形如 sk-xxxxxx';

  @override
  String get setupPresetKimiLabel => 'Kimi 月之暗面（大陸直連）';

  @override
  String get setupPresetKimiNote => '大陸直連，長文字能力佳';

  @override
  String get setupPresetKimiKeyHint => '在 platform.moonshot.cn 建立，形如 sk-xxxxxx';

  @override
  String get setupPresetGlmLabel => '智譜 GLM（大陸直連）';

  @override
  String get setupPresetGlmNote => '大陸直連，有免費檔位';

  @override
  String get setupPresetGlmKeyHint => '在 bigmodel.cn 的「API Keys」裡建立';

  @override
  String get setupPresetQwenLabel => '通義千問 DashScope（大陸直連）';

  @override
  String get setupPresetQwenNote => '阿里雲百煉平台，相容 OpenAI 格式';

  @override
  String get setupPresetQwenKeyHint =>
      '在 bailian.console.aliyun.com 建立 API-KEY';

  @override
  String get setupPresetSiliconflowLabel => '矽基流動 SiliconFlow';

  @override
  String get setupPresetSiliconflowNote => '聚合多種開源模型，大陸直連';

  @override
  String get setupPresetSiliconflowKeyHint => '在 siliconflow.cn 建立 API 密鑰';

  @override
  String get setupPresetCustomLabel => '自訂（任何 OpenAI 相容服務）';

  @override
  String get setupPresetCustomNote => '如果你用的是自建閘道、公司內網或 Claude 轉換閘道，選這個';

  @override
  String get setupPresetCustomKeyHint =>
      '位址要填到 /v1 這一層，例如 https://your-gateway.com/v1';

  @override
  String get settingsUpdateTitle => '檢查更新';

  @override
  String settingsUpdateHint(String version) {
    return '目前版本 $version。側載分发沒有應用商店，更新公告來自官網。';
  }

  @override
  String get settingsUpdateButton => '檢查更新';

  @override
  String get settingsUpdateChecking => '正在檢查…';

  @override
  String get settingsUpdateUpToDate => '已是最新版本';

  @override
  String settingsUpdateAvailable(String version) {
    return '發現新版本 $version';
  }

  @override
  String get settingsUpdateOpenDownload => '開啟下載頁';

  @override
  String get settingsUpdateNetworkError => '檢查失敗：網路不穩定，稍後再試';

  @override
  String get settingsUpdateBadResponse => '檢查失敗：官網版本資訊無法解析';

  @override
  String get reportCenterTitle => '檢舉中心';

  @override
  String get reportTabSubmit => '提交檢舉';

  @override
  String get reportTabMine => '我的工單';

  @override
  String get reportTabInbox => '針對我的工單';

  @override
  String get reportReasonLabel => '檢舉事由';

  @override
  String get reportReasonSpam => '垃圾廣告或批次騷擾';

  @override
  String get reportReasonHarassment => '騷擾、辱罵或威脅';

  @override
  String get reportReasonIllegalContent => '違法違規內容';

  @override
  String get reportReasonFakeIdentity => '虛假身分或冒充他人';

  @override
  String get reportReasonOther => '其他（需在下文說明）';

  @override
  String get reportTargetLabel => '被檢舉人';

  @override
  String get reportTargetHint => '被檢舉人的 Agent ID';

  @override
  String get reportDetailLabel => '補充說明（選填）';

  @override
  String get reportDetailHint => '最多 280 字，僅供審核參考。';

  @override
  String get reportSubmit => '提交檢舉';

  @override
  String get reportSubmitting => '提交中…';

  @override
  String reportSubmitted(String ticket) {
    return '檢舉已受理，工單號 $ticket';
  }

  @override
  String get reportDuplicate => '該工單此前已提交，未重複建立。';

  @override
  String get reportNeedReason => '請選擇檢舉事由。';

  @override
  String get reportNeedTarget => '請填寫被檢舉人。';

  @override
  String get reportOtherNeedsDetail => '只有在補充說明裡寫清原因時才選「其他」。';

  @override
  String get reportEmptyMine => '你還沒有提交過檢舉。';

  @override
  String get reportEmptyInbox => '暫無針對你的工單。';

  @override
  String get reportTicketLabel => '工單號';

  @override
  String get reportStatusOpen => '已受理';

  @override
  String get reportStatusTriaged => '已分診';

  @override
  String get reportStatusInReview => '查核中';

  @override
  String get reportStatusActioned => '已處置';

  @override
  String get reportStatusRejected => '不予處置';

  @override
  String get reportStatusAppealed => '已申訴';

  @override
  String get reportStatusClosed => '已結案';

  @override
  String get reportStatusWithdrawn => '已撤回';

  @override
  String get reportStatusNote => '狀態說明';

  @override
  String get reportActionLabel => '處置動作';

  @override
  String get reportAppeal => '申訴';

  @override
  String get reportWithdraw => '撤回';

  @override
  String get reportAppealTitle => '提交申訴';

  @override
  String get reportAppealNote => '申訴說明（選填，最多 280 字）';

  @override
  String get reportAppealSubmitted => '申訴已提交。';

  @override
  String get reportWithdrawDone => '檢舉已撤回。';

  @override
  String get reportLookupTitle => '憑工單號查詢';

  @override
  String get reportLookupHint => '工單號（RPT-…）';

  @override
  String get reportLookupButton => '查詢';

  @override
  String get reportLookupNotFound => '未找到該工單，或它不屬於你。';

  @override
  String get reportContactEntry => '檢舉此聯絡人';

  @override
  String get reportErrHubNotConfigured => '尚未設定伺服器位址。';

  @override
  String get reportErrEd25519Required => '本機身分尚未升級為公鑰身分，無法提交檢舉。';

  @override
  String get reportErrNetwork => '網路不可用。';

  @override
  String get reportErrRateLimited => '短時間內檢舉過於頻繁，請稍後再試。';

  @override
  String reportFailed(String code) {
    return '操作失敗：$code';
  }

  @override
  String get helpReportGuideTitle => '檢舉與工單';

  @override
  String get helpReportGuideBody =>
      '檢舉在應用程式內提交，不用寄信。提交後你會立刻拿到一個工單號，隨時可以憑號查詢狀態。被檢舉人不會知道是誰檢舉了他，且申訴以一次為限。';

  @override
  String get reportCenterSubtitle => '提交舉報、查詢工單狀態，或對處置結果申訴。';

  @override
  String get reportErrSelfReport => '不能檢舉自己。';

  @override
  String get reportErrNotFound => '沒有該工單，或不屬於你。';

  @override
  String get reportErrAppealExhausted => '該工單的申訴機會已用過。';

  @override
  String get reportErrAuth => '伺服器無法驗證你的身分，請重新登入後重試。';
}
