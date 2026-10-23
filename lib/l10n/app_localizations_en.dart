// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonDone => 'Done';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get toolPermissionTitle => 'Security check';

  @override
  String toolPermissionMessage(String description) {
    return 'Your fen is requesting a high-privilege action:\n\n$description\n\nAllow it?';
  }

  @override
  String get toolPermissionAllow => 'Allow';

  @override
  String get toolPermissionDeny => 'Deny';

  @override
  String get permListSeparator => ', ';

  @override
  String permPluginGrantBody(String name, String caps, String desc) {
    return 'Plugin \"$name\" is requesting these capabilities for the first time: $caps\nPlugin declaration: $desc\n\nThis confirmation is needed only once; afterwards the plugin may use the granted capabilities on its own. You can revoke it at any time by disabling the plugin in the Skill Control Center.';
  }

  @override
  String get permPluginDeviceControl => 'Phone control';

  @override
  String permPluginMcp(String name) {
    return 'MCP service $name';
  }

  @override
  String permActionCreateTool(String name) {
    return 'Create/modify skill [$name]';
  }

  @override
  String permActionOpenUrl(String url) {
    return 'Open $url';
  }

  @override
  String permActionChangeSettings(String keys) {
    return 'Change system settings: $keys';
  }

  @override
  String get permDeniedReask =>
      'This plugin\'s authorization was previously denied. To authorize it again, disable and re-enable the plugin in the Skill Control Center.';

  @override
  String get permDeniedNoGrant =>
      'No capability grant was given, so this call was aborted.';

  @override
  String get permDenyCreateTool =>
      'The user declined the request to create a tool';

  @override
  String get permDenyOpenUrl => 'The user cancelled';

  @override
  String get permDenyChangeSettings => 'The user declined the settings change';

  @override
  String get permDenyGeneric => 'The user did not confirm';

  @override
  String permActionSendMail(String to) {
    return 'Send an email to $to';
  }

  @override
  String get permDenySendMail => 'The user declined to send the email';

  @override
  String get manageMailTitle => 'Email';

  @override
  String get manageMailSubtitle => 'Let your agent read and send mail for you';

  @override
  String get mailTitle => 'Email accounts';

  @override
  String get mailIntro =>
      'Your mail password is stored only on this phone and is never sent to our servers. Use an app password or an authorization code — not your login password. Any provider works: tap one below, or just type your address and the servers fill in automatically.';

  @override
  String get mailNone => 'No account bound yet';

  @override
  String get mailAddSection => 'Add an account';

  @override
  String get mailAddress => 'Email address';

  @override
  String get mailDisplayName => 'Display name (optional)';

  @override
  String get mailAppPassword => 'App password / auth code';

  @override
  String get mailAppPasswordHint =>
      'Most providers need an app password or an authorization code, not your login password.';

  @override
  String get mailAppPasswordHintGmail =>
      'Gmail: turn on 2-Step Verification, then create one at myaccount.google.com/apppasswords.';

  @override
  String get mailAppPasswordHintNetease =>
      'NetEase (163/126): use an authorization code. In webmail: Settings → POP3/SMTP/IMAP → enable IMAP/SMTP, then generate a code.';

  @override
  String get mailAppPasswordHintQQ =>
      'QQ Mail: use an authorization code. Webmail → Settings → Account → enable IMAP/SMTP, then generate a code.';

  @override
  String get mailAppPasswordHintOutlook =>
      'Outlook / Microsoft 365: enable two-step verification, then create an app password.';

  @override
  String get mailPresetLabel =>
      'Tap a provider to fill its servers in, or just type your address and we match it automatically.';

  @override
  String mailAutoFilled(String provider) {
    return 'Filled in the servers for $provider. Change them only if you use a custom domain.';
  }

  @override
  String get mailManualServers =>
      'Servers entered by hand — automatic matching is paused.';

  @override
  String get mailNeedServers =>
      'Pick a provider above, or type your address so we can fill the servers in.';

  @override
  String get mailErrAuth =>
      'Wrong app password / auth code, or IMAP is not enabled. Check the hint above and generate a new one.';

  @override
  String get mailErrUnsafe =>
      'The provider blocked this login. Enable IMAP/SMTP in its webmail and use an authorization code.';

  @override
  String get mailSecurityTls => 'Implicit TLS (465/993)';

  @override
  String get mailSecurityStarttls => 'STARTTLS (587)';

  @override
  String get mailSaveAndTest => 'Save and test';

  @override
  String get mailTestConn => 'Test connection';

  @override
  String get mailTesting => 'Testing…';

  @override
  String get mailTestOk => 'Connected. The configuration works.';

  @override
  String mailTestFail(String reason) {
    return 'Connection failed: $reason';
  }

  @override
  String get mailUnbind => 'Unbind';

  @override
  String get mailUnbound => 'Account unbound and its password erased';

  @override
  String mailLastError(String reason) {
    return 'Last error: $reason';
  }

  @override
  String get capNetwork => 'Network access';

  @override
  String get capLaunchApp => 'Launch apps';

  @override
  String get capDevice => 'Local hardware';

  @override
  String get capScreenControl => 'Control phone screen';

  @override
  String get capMemory => 'Read/write memory';

  @override
  String get capSettings => 'Change settings';

  @override
  String get capSocial => 'Post socially on your behalf';

  @override
  String get capLocal => 'Local only';

  @override
  String get riskHigh => 'High risk';

  @override
  String get riskMedium => 'Medium risk';

  @override
  String get riskLow => 'Low risk';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'No network connection.';

  @override
  String get errorPermissionDenied => 'Permission denied.';

  @override
  String get errorInvalidInput =>
      'That doesn\'t look right. Please check your input.';

  @override
  String get onboardingWelcomeTitle => 'Your fen, ready to meet people for you';

  @override
  String get onboardingWelcomeSubtitle =>
      'It remembers things for you, runs small errands, and goes first when meeting someone new — then calls you in when it\'s worth it.';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingModelTitle => 'Connect a model';

  @override
  String get onboardingModelSubtitle =>
      'Bring your own API key, or start with the free credit we give you.';

  @override
  String get onboardingModelHint => 'Your key stays on your device.';

  @override
  String get onboardingProfileTitle => 'Who is this fen for?';

  @override
  String get onboardingProfileSubtitle =>
      'Just a name is enough. You can add more later.';

  @override
  String get onboardingDone => 'You\'re all set';

  @override
  String get onboardingDoneSubtitle =>
      'Your fen is ready. Invite someone and it can start on your behalf.';

  @override
  String onboardingStepIndicator(int cur, int total, String label) {
    return 'Step $cur of $total · $label';
  }

  @override
  String get onboardingStepWelcome => 'Welcome';

  @override
  String get onboardingStepModel => 'Model';

  @override
  String get onboardingStepKey => 'API key';

  @override
  String get onboardingStepIdentity => 'Identity';

  @override
  String get onboardingStepSocial => 'Social';

  @override
  String get onboardingStepDone => 'Done';

  @override
  String get onboardingPrevStep => 'Back';

  @override
  String get onboardingWelcomeHeading => 'Welcome to Fen';

  @override
  String get onboardingWelcomeBody =>
      'Your agent lives on your phone. Three minutes to set up — then it keeps notes, offers ideas and makes friends for you.';

  @override
  String get onboardingDisclosureNote =>
      'By default your fen speaks first on your behalf — it only calls you in when it matters.';

  @override
  String get privacyDataLocalTitle => 'Your data stays yours';

  @override
  String get privacyDataLocalBody =>
      'Chats, memories and contacts stay on this device. We can\'t see them and never upload them.';

  @override
  String get onboardingSocialCardTitle => 'Your fen can go social';

  @override
  String get onboardingSocialCardBody =>
      'It meets friends\' fens and chats privately — direct when nearby, via relay when far away.';

  @override
  String get onboardingModelCardTitle => 'Bring your own model';

  @override
  String get onboardingModelCardBody =>
      'We don\'t sell credits. Use DeepSeek, OpenAI, Kimi, Zhipu — any of them.';

  @override
  String get onboardingThreeThings =>
      'Free trial starts right away; if you bring your own API key, we\'ll ask your model, key and nickname.';

  @override
  String get onboardingPickModelTitle => 'Which model would you like?';

  @override
  String get onboardingPickModelSubtitle =>
      'Pick one — if unsure, take the first (DeepSeek).';

  @override
  String get onboardingPasteKeyTitle => 'Paste your API key';

  @override
  String get onboardingFieldBaseUrl => 'Endpoint';

  @override
  String get onboardingHintBaseUrl => 'e.g. https://api.deepseek.com';

  @override
  String get onboardingFieldModelName => 'Model name';

  @override
  String get onboardingHintModelName => 'e.g. deepseek-v4-flash';

  @override
  String get onboardingFieldApiKey => 'API key';

  @override
  String get onboardingTesting => 'Testing…';

  @override
  String get onboardingTestConnection => 'Test connection';

  @override
  String get onboardingNameStepTitle => 'Name your fen';

  @override
  String get onboardingNameStepSubtitle =>
      'You can change these later in settings.';

  @override
  String get onboardingFieldMasterName => 'What should it call you?';

  @override
  String get onboardingHintMasterName => 'e.g. boss, mum, your name';

  @override
  String get onboardingFieldAgentName => 'Its name';

  @override
  String get onboardingHintAgentName => 'e.g. Fen, Ada';

  @override
  String get onboardingFieldTone => 'Its tone';

  @override
  String get onboardingHintTone => 'e.g. warm, concise, opinionated';

  @override
  String get onboardingSocialStepTitle => 'Let your fen go social?';

  @override
  String get onboardingSocialStepSubtitle =>
      'With a relay address your fen can reach friends\' fens far away.\nNo relay? Skip it — nearby still connects directly and local features are unaffected.';

  @override
  String get onboardingFieldHubKey => 'Relay access key (optional)';

  @override
  String get onboardingFieldHubUrl => 'Relay address (optional)';

  @override
  String get onboardingHintHubKey =>
      'If the official relay requires admission, enter the key issued by its operator (looks like WK-XXXXX-XXXXX-XXXXX-XXXXX); leave empty for self-hosted or LAN addresses';

  @override
  String get onboardingHintHubUrl =>
      'default https://hub.wold.world (or a LAN IP for testing)';

  @override
  String get onboardingFieldWorldUrl =>
      'World server address (blank = relay + /world)';

  @override
  String get onboardingHintWorldUrl => 'default https://world.wold.world';

  @override
  String get onboardingConnecting => 'Connecting…';

  @override
  String get onboardingTestAndConnect => 'Test and connect';

  @override
  String get onboardingDoneHeading => 'All set — you\'re good to go';

  @override
  String get onboardingSummaryModel => 'Model service';

  @override
  String get onboardingSummaryAgentName => 'Agent name';

  @override
  String get onboardingSummaryCloud => 'Cloud social';

  @override
  String get onboardingCloudOn => 'On (can reach friends\' fens)';

  @override
  String get onboardingCloudOff => 'Off (local and nearby only)';

  @override
  String get onboardingNextWhere =>
      'Where to next?\n· Daily chat — talk to it; it remembers what you say\n· Fen Community — let your fen meet people for you\n· Settings — change model, name and social switches anytime';

  @override
  String get onboardingNotFilled => 'Not set';

  @override
  String get onboardingWarnNotTestedTitle => 'Connection not tested yet';

  @override
  String get onboardingWarnNotTestedBody =>
      'Tap \"Test connection\" first so we know the key works.\n\nIf you skip, the app keeps asking for an API key and you\'ll have to fill it in Settings.';

  @override
  String get onboardingGoBackTest => 'Go back and test';

  @override
  String get onboardingContinueAnyway => 'Continue anyway';

  @override
  String get settingsTitle => 'Control Center (Core Config)';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsModel => 'Model';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSaved =>
      '💾 Core parameters and soul settings have been reforged!';

  @override
  String get settingsBgChanged =>
      '🖼️ Chat background updated — takes effect on the home screen!';

  @override
  String get settingsBgReset => '🧹 Chat background restored to default';

  @override
  String get settingsSecAppearance => '🎨 Appearance';

  @override
  String get settingsSetWallpaper => 'Set chat wallpaper';

  @override
  String get settingsRestoreDefault => 'Restore default';

  @override
  String get settingsSecSafety => '🛡️ Autonomy & Safety';

  @override
  String get settingsObservationMode => 'Observation mode (recommended)';

  @override
  String get settingsObservationSubtitle =>
      'When on, outgoing greetings only produce a suggestion card — nothing is sent until you confirm.';

  @override
  String get settingsAutoAllowLabel =>
      'High-risk tools to auto-approve (comma-separated)';

  @override
  String get settingsAutoAllowHint =>
      'e.g. open_url_or_app, create_custom_tool';

  @override
  String get settingsDeviceControlTitle => '🖐️ Phone control (accessibility)';

  @override
  String get settingsDeviceControlSubtitle =>
      'Lets your fen read the screen, tap, type, and open apps; requires system accessibility permission, off by default.';

  @override
  String get settingsSecSoul => '🎭 Soul shaping (Soul.md)';

  @override
  String get settingsAgentName => 'Your fen\'s name';

  @override
  String get settingsMasterName => 'What should it call you?';

  @override
  String get settingsRelationship => 'Your relationship setting';

  @override
  String get settingsTone => 'Reply tone and style';

  @override
  String get settingsExtraDesc => 'Extra behaviour rules / expectations';

  @override
  String get settingsSecMemory => '💾 Memory fuse & retrieval';

  @override
  String get settingsMaxRounds => 'Default max conversation rounds';

  @override
  String get settingsMaxRoundsHint => 'e.g. 50';

  @override
  String get settingsTimeLimit => 'Default max look-back (hours)';

  @override
  String get settingsTimeLimitHint => 'e.g. 24';

  @override
  String get settingsRecallEnabled =>
      'Auto recall (search past turns each round)';

  @override
  String get settingsProfileEnabled =>
      'Long-term profile injection (what you keep caring about)';

  @override
  String get settingsSecEngine => '⚙️ Brain engine (BYOK)';

  @override
  String get settingsBaseUrl => 'Base URL (gateway/proxy)';

  @override
  String get settingsModelName => 'Model name';

  @override
  String get settingsApiKey => 'API Key';

  @override
  String get settingsHubUrl =>
      'Cloud Hub URL (use your PC\'s IP for LAN testing)';

  @override
  String get settingsHubKey => 'Relay access key (optional)';

  @override
  String get settingsHubKeyApply => 'Apply for an access key';

  @override
  String get settingsHubKeyApplyFailed =>
      'Could not open the application page — check your connection and try again.';

  @override
  String get settingsHubKeyHint =>
      'Only the official relay needs one; issued by its operator, looks like WK-XXXXX-XXXXX-XXXXX-XXXXX';

  @override
  String get settingsHubUrlHint =>
      'e.g. https://hub.example.com or http://192.168.1.100:3000';

  @override
  String get settingsWorldUrl =>
      'World server URL (leave empty to use Hub URL + /world)';

  @override
  String get settingsWorldUrlHint =>
      'e.g. https://hub.example.com/world or http://192.168.1.100:3100';

  @override
  String get settingsGodUrl =>
      'GOD control-room bridge (leave empty to hide the GOD entry)';

  @override
  String get settingsGodUrlHint => 'e.g. http://192.168.1.100:3300';

  @override
  String get settingsLocalModelUrl =>
      'Local model URL (offline fallback, optional)';

  @override
  String get settingsLocalModelUrlHint =>
      'Default http://127.0.0.1:11434 (clear = disable local fallback)';

  @override
  String get settingsLocalModelName => 'Local model name';

  @override
  String get settingsLocalModelNameHint => 'Default qwen2.5:3b';

  @override
  String get settingsNotifySection => 'Notifications';

  @override
  String get settingsNotifyEnabled => 'Enable notifications';

  @override
  String get settingsNotifyQuiet => 'Quiet hours';

  @override
  String get settingsNotifyQuietStart => 'Start hour';

  @override
  String get settingsNotifyQuietEnd => 'End hour';

  @override
  String get settingsMorningHour => 'Morning greeting time';

  @override
  String get settingsNotifyPermissionNeeded =>
      'Notification permission is off — tap to grant';

  @override
  String get helpNotifyGuideTitle => 'What will notifications wake you for';

  @override
  String get helpNotifyGuideBody =>
      'Only four things interrupt you: (1) someone delegates a task to you; (2) someone @mentions you in the lounge; (3) your agent drafted a message and is blocked waiting for your approval; (4) an intro card or a direct message arrives.\n\nOrdinary lounge chatter never notifies — room traffic is far too dense for that to mean anything.\n\nEverything is held back during quiet hours and is still there when you return. Setting start = end disables quiet hours.\n\n⚠️ Notifications only fire while the app is still alive; if the system kills it, messages wait until your next launch.';

  @override
  String get notifyChannelName => 'Wold alerts';

  @override
  String get notifyChannelDescription =>
      'Your agent\'s messages, delegations and approvals';

  @override
  String get notifyDirectMessageTitle => 'New message';

  @override
  String notifyDirectMessageBody(String peer) {
    return 'A message from $peer';
  }

  @override
  String get notifyLoungeMentionTitle => 'You were mentioned';

  @override
  String notifyLoungeMentionBody(String who) {
    return '$who mentioned you in the lounge';
  }

  @override
  String get notifySuggestionTitle => 'A draft is waiting';

  @override
  String get notifySuggestionBody =>
      'Your agent drafted a message and needs your approval before it can go out';

  @override
  String get notifyDelegationTitle => 'New delegation';

  @override
  String notifyDelegationBody(String peer) {
    return '$peer delegated a task to you';
  }

  @override
  String get notifyIntercardTitle => 'New intro card';

  @override
  String notifyIntercardBody(String peer) {
    return '$peer sent you an intro card';
  }

  @override
  String get settingsRerunOnboarding => 'Re-run setup wizard (~3 min)';

  @override
  String get settingsLegalTitle => 'Legal & About';

  @override
  String get settingsLegalIntro =>
      'Privacy Policy and Terms of Service. These open in your browser.';

  @override
  String get settingsPrivacyTitle => 'Privacy Policy';

  @override
  String get settingsTermsTitle => 'Terms of Service';

  @override
  String get settingsLegalOpenFailed =>
      'Could not open the page — check your connection and try again.';

  @override
  String get settingsSaveButton => '💾 Save & reforge soul';

  @override
  String get mcpCenterTitle => 'Memory & Skills Control Center (MCP)';

  @override
  String get mcpAutoTitle => '🤖 AI auto on-demand invocation (recommended)';

  @override
  String get mcpAutoSubtitle =>
      'When on, the AI automatically finds and triggers any registered tool as needed in the background. Sub-switches are safely locked on.';

  @override
  String mcpBusSummaryClean(int total, int signed) {
    return '🛡️ Plugin bus: $total plugins (signed $signed)';
  }

  @override
  String mcpBusSummaryTampered(int total, int signed, int tampered) {
    return '🛡️ Plugin bus: $total plugins (signed $signed · ⚠️ $tampered with invalid signatures auto-disabled)';
  }

  @override
  String get mcpImportTitle => 'Import from the DSH ecosystem';

  @override
  String get mcpImportSubtitle =>
      'Import skills and MCP services, or run a compatibility check on a plugin pack';

  @override
  String get mcpCategoryHeader => '📦 Skill catalog (Tab Panel)';

  @override
  String get mcpCatLocalTitle => '🔌 Local hardware & Webhook interfaces';

  @override
  String get mcpCatLocalSubtitle =>
      'Trigger the phone motor, system queries, and custom web API tools';

  @override
  String get mcpCatMcpTitle => '🌐 MCP external extension protocol';

  @override
  String get mcpCatMcpSubtitle =>
      'Connect to standard Model Context Protocol remote services';

  @override
  String get mcpCatSkillTitle => '🧠 System prompt skills (Skills)';

  @override
  String get mcpCatSkillSubtitle =>
      'Dynamically inject extra instructions, rules, and special skills into the AI brain';

  @override
  String get mcpContent => 'Content';

  @override
  String get mcpContentHint => 'Enter content';

  @override
  String get mcpWebhookLabel => 'Webhook interface URL';

  @override
  String get mcpWebhookHint =>
      'A web API address starting with http:// or https://';

  @override
  String get mcpServerLabel => 'MCP server URL';

  @override
  String get mcpServerHint => 'e.g. http://localhost:8080/mcp';

  @override
  String get mcpPromptLabel => 'System prompt (Prompt)';

  @override
  String get mcpPromptHint => 'e.g. after every answer, append ‘meow~’';

  @override
  String get mcpEditToolTitle => 'Edit tool config';

  @override
  String get mcpAddToolTitle => 'Add custom tool';

  @override
  String get mcpToolNameLabel => 'Unique tool identifier (English)';

  @override
  String get mcpToolDescLabel => 'Tool description (for the AI to understand)';

  @override
  String get mcpCancel => 'Cancel';

  @override
  String get mcpSaveRegister => 'Save & register';

  @override
  String get mcpManageTools => 'Manage tools';

  @override
  String get mcpTypeLocal => 'Local Webhook tools';

  @override
  String get mcpTypeMcp => 'MCP external protocol config';

  @override
  String get mcpTypeSkill => 'Prompt skills (Skills) library';

  @override
  String get mcpEmpty =>
      'No tools yet — tap the + in the top-right to create your first one!';

  @override
  String get mcpTagDream => 'Dream';

  @override
  String get mcpTagSigInvalid => 'Invalid signature';

  @override
  String mcpSubTampered(String desc) {
    return '$desc · invalid signature, auto-disabled';
  }

  @override
  String mcpSubDreamPending(String desc) {
    return '$desc · dream-generated, awaiting confirmation';
  }

  @override
  String get mcpSigBuiltin => 'Built-in';

  @override
  String get mcpSigOk => '🔐 Device-signed';

  @override
  String get mcpSigUnsigned => 'Unsigned';

  @override
  String get mcpSigInvalid => '⚠️ Invalid signature';

  @override
  String get mcpToolDescHeader => '📌 Tool description:';

  @override
  String get mcpInjectionDetail =>
      '📜 Prompt injection detail (System Prompt):';

  @override
  String get mcpPhysicalUrl => '🔗 Physical execution address (URL/BUILTIN):';

  @override
  String get mcpEditParams => 'Edit this tool\'s parameters';

  @override
  String get manageDreamSleeping =>
      '🌙 Your fen has entered deep sleep and is distilling subconscious memories...';

  @override
  String get manageDreamAwake =>
      '☀️ Your fen is awake! The memory store has evolved and its profile is updated.';

  @override
  String get manageDreamFailed =>
      '❌ Memory distillation failed — the model may not have returned valid JSON.';

  @override
  String get manageSelfEvolutionTitle =>
      'Self-evolution (Nanobot Dream Engine)';

  @override
  String get manageSelfEvolutionBody =>
      'Neural background process (WorkManager) monitoring. The steward silently deep-retrieves and evolves the underlying prompt genes (Skills) at night.';

  @override
  String get manageMetricDepth => 'Memory depth';

  @override
  String get manageMetricSkillsLabel => 'Derived skills';

  @override
  String manageMetricSkillsValue(int n) {
    return '$n';
  }

  @override
  String get manageMetricSessionsLabel => 'Grouped sessions';

  @override
  String manageMetricSessionsValue(int n) {
    return '$n';
  }

  @override
  String get manageDreaming => 'Deep thinking & distilling...';

  @override
  String get manageTriggerEvolution =>
      '🌙 Trigger subconscious memory evolution now';

  @override
  String get manageSystemCapabilityTitle => 'System & capabilities';

  @override
  String get manageSystemCapabilityHint =>
      'Changes take effect immediately; notification and calendar permissions can be adjusted anytime.';

  @override
  String get manageSystemCapabilityHintSimple =>
      'Notification and calendar permissions are always adjustable; switch to Advanced mode to see the rest.';

  @override
  String get manageHistoryTitle => 'History & smart grouping';

  @override
  String get manageHistorySubtitle =>
      'Browse all raw conversation memories by timeline and topic tree';

  @override
  String get manageToolsTitle => 'Skill library & local tools (MCP)';

  @override
  String get manageToolsSubtitle =>
      'Manage local system tool permissions; mount custom Webhooks and Prompts';

  @override
  String get manageProfileTitle => 'Master\'s confidential dossier & network';

  @override
  String get manageProfileSubtitle =>
      'Review and manually edit the privacy cognition profile your fen built for you';

  @override
  String get manageShutdownTitle => 'Force safe shutdown & exit';

  @override
  String get manageShutdownSubtitle =>
      'When the underlying network locks up or hardware stalls, tap this to force-release all ports and hardware locks and close the app for a safe restart.';

  @override
  String get manageShutdownDialogTitle => '🚨 Warning: forced system shutdown';

  @override
  String get manageShutdownDialogBody =>
      'This will forcibly terminate all background radar scans, release ports, and exit the app to restore a clean state. Continue?';

  @override
  String get manageForceQuit => 'Force quit';

  @override
  String get serendipityTitle => '✨ Luck Lab';

  @override
  String serendipityEnergyBadge(int n) {
    return '🔋 $n Lp ';
  }

  @override
  String get serendipityTabMorning => '🌅 Rehearse';

  @override
  String get serendipityTabChallenge => '🧭 Break out';

  @override
  String get serendipityTabAlchemist => '🧪 Alchemy';

  @override
  String get serendipityTabNight => '🌌 Notes';

  @override
  String get serendipityTabDiary => '📖 Diary';

  @override
  String get serendipityTabOracle => '🔮 Oracle';

  @override
  String serendipityEnergyGained(int n) {
    return '✨ +$n Lp (luck energy injected)';
  }

  @override
  String get serendipityNetworkError =>
      'Network hiccup — please try again later.';

  @override
  String get serendipityBlindBox1 =>
      'Red-clothes rule: notice people in red and watch for coincidences.';

  @override
  String get serendipityBlindBox2 =>
      'New path: try a route home you have never taken.';

  @override
  String get serendipityBlindBox3 =>
      'Blind order: let the owner pick a dish at random for you.';

  @override
  String get serendipityBlindBox4 =>
      'Glimmer contact: genuinely smile at the first stranger you meet.';

  @override
  String get serendipityBlindBox5 =>
      'No-strings hello: message an old friend you have not talked to in ages.';

  @override
  String get serendipityBlindBox6 =>
      'Offline trial: turn off the network for half an hour and observe closely.';

  @override
  String get serendipityMorningHeader =>
      'Expectation rewrite · Morning rehearsal';

  @override
  String get serendipityIntentLock => '🎯 Lock the intent';

  @override
  String get serendipityEventHint =>
      'Event you\'re about to face (e.g. an afternoon meeting)';

  @override
  String get serendipityTimerPrompt1 =>
      'Close your eyes, breathe deeply, picture that scene...';

  @override
  String get serendipityTimerPrompt2 =>
      'Focus on details: the light around you, the other person\'s expression...';

  @override
  String get serendipityTimerPrompt3 =>
      'Picture a small mishap happening — and you handling it with ease...';

  @override
  String get serendipityTimerPrompt4 =>
      'Feel the calm of a job well done; get ready to open your eyes...';

  @override
  String get serendipityGiveUp => 'Abandon rehearsal';

  @override
  String get serendipityNeedEvent => '⚠️ Enter an event first!';

  @override
  String get serendipityStartPreview => 'Start 2-minute mental rehearsal';

  @override
  String serendipityTargetEvent(String text) {
    return '🎯 Target event: $text';
  }

  @override
  String get serendipityDetailHint => '👀 Scene details (what do you see?)';

  @override
  String get serendipityObstacleHint =>
      '🛡️ Obstacle defused (how do you calmly handle surprises?)';

  @override
  String get serendipityOutcomeHint =>
      '🌟 Expected outcome (the ending you want most)';

  @override
  String serendipityAiBoost(String text) {
    return '🧠 AI boost:\n$text';
  }

  @override
  String get serendipityAiInjecting => 'AI injecting energy...';

  @override
  String get serendipityReinforce => '🧠 Reinforce';

  @override
  String get serendipitySave5 => 'Save (+5)';

  @override
  String get serendipityMorningArchive => 'Rehearsal archive';

  @override
  String serendipityLogTime(String t) {
    return '📅 $t';
  }

  @override
  String serendipityLogEvent(String t) {
    return '🎯 Event: $t';
  }

  @override
  String serendipityLogDetail(String t) {
    return '👀 Detail: $t';
  }

  @override
  String serendipityLogOutcome(String t) {
    return '🌟 Expected: $t';
  }

  @override
  String serendipityLogAiBoost(String t) {
    return '💡 AI boost:\n$t';
  }

  @override
  String get serendipityChallengeHeader =>
      'Opportunity sensing · Breakout radar';

  @override
  String get serendipityActionTypeLabel => 'Choose action type';

  @override
  String get serendipityChallengeTypeBlindBox => '🎁 Blind-box challenge';

  @override
  String get serendipityChallengeTypeCustom => 'Custom';

  @override
  String get serendipityCustomChallengeHint => '🎯 Custom challenge content';

  @override
  String get serendipityBlindBoxDrawn =>
      '🎉 Today\'s random blind-box task for you:';

  @override
  String get serendipityRedraw => '↺ Too hard? Tap to redraw';

  @override
  String get serendipityJourneyHint => '🚶‍♂️ What actually happened';

  @override
  String get serendipityReflectHint => '📝 Comments & takeaways';

  @override
  String get serendipityAiAnalyzing => 'AI analysing...';

  @override
  String serendipityAiColon(String text) {
    return '🧠 AI: $text';
  }

  @override
  String get serendipityComment => '🧠 Comment';

  @override
  String get serendipitySave15 => 'Save (+15)';

  @override
  String get serendipityChallengeArchive => 'Action history';

  @override
  String serendipityLogGoal(String t) {
    return '🎯 Goal: $t';
  }

  @override
  String serendipityLogJourney(String t) {
    return '🚶‍♂️ Journey: $t';
  }

  @override
  String serendipityLogReflect(String t) {
    return '📝 Reflection: $t';
  }

  @override
  String serendipityLogAiComment(String t) {
    return '💡 AI comment: $t';
  }

  @override
  String get serendipityAlchemistHeader =>
      'Bad-luck alchemy · Narrative recast';

  @override
  String get serendipitySetbackHint => '1. Setback';

  @override
  String get serendipityNegReactHint => '2. Negative reaction';

  @override
  String get serendipityStrategyLabel => '3. Reframing strategy';

  @override
  String get serendipityStrategyDownward => 'Downward comparison';

  @override
  String get serendipityStrategySurplus => 'Find the surplus';

  @override
  String get serendipityStrategyDilate => 'Time-space dilation';

  @override
  String get serendipityNewCognitionHint => '4. New understanding & action';

  @override
  String get serendipityScore => '🧠 Score';

  @override
  String get serendipitySave10 => 'Save (+10)';

  @override
  String get serendipityAlchemistArchive => 'Alchemy archive';

  @override
  String serendipityLogSetback(String t) {
    return '❌ Setback: $t';
  }

  @override
  String serendipityLogReact(String t) {
    return '😔 Reaction: $t';
  }

  @override
  String serendipityLogStrategy(String t) {
    return '🛡️ Strategy: $t';
  }

  @override
  String serendipityLogCognition(String t) {
    return '💫 Understanding: $t';
  }

  @override
  String serendipityLogAiScore(String t) {
    return '💡 AI score: $t';
  }

  @override
  String get serendipityNightHeader => 'Intuition sensing · Glimmer notes';

  @override
  String get serendipityIntuitionHint => '1. Hunch / intuition';

  @override
  String get serendipityChoiceHint => '2. Make a choice';

  @override
  String get serendipityReflectStrategyHint => '3. Reflect on strategy';

  @override
  String get serendipityParse => '🧠 Interpret';

  @override
  String get serendipityNightArchive => 'Subconscious archive';

  @override
  String serendipityLogIntuition(String t) {
    return '🔮 Intuition: $t';
  }

  @override
  String serendipityLogChoice(String t) {
    return '👉 Choice: $t';
  }

  @override
  String serendipityLogNightReflect(String t) {
    return '🌱 Reflection: $t';
  }

  @override
  String serendipityLogAiParse(String t) {
    return '💡 AI reading: $t';
  }

  @override
  String get serendipityIntuitionCameTrue => '✅ The intuition came true';

  @override
  String get serendipityVerifyTrue => '🎯 Verify it came true (+20Lp)';

  @override
  String get serendipityDiaryHeader => 'Emotional listening · Free diary';

  @override
  String get serendipityDiaryHint =>
      '✍️ Write down experiences, moods, small things...';

  @override
  String serendipityAiListen(String text) {
    return '🧠 AI mentor listening:\n$text';
  }

  @override
  String get serendipityAiReading => 'AI mentor reading...';

  @override
  String get serendipityListen => '🧠 Listen';

  @override
  String get serendipityKeep => 'Keep (+5 Lp)';

  @override
  String get serendipityDiaryArchive => 'Time capsule';

  @override
  String serendipityLogDiaryTime(String t) {
    return '📅 Time: $t';
  }

  @override
  String serendipityLogDiaryEcho(String t) {
    return '💡 Mentor\'s echo:\n$t';
  }

  @override
  String get serendipityOracleHeader => 'I Ching decision · Oracle casting';

  @override
  String get serendipityOracleEventHint =>
      '☯ Describe something you\'re torn about and need to decide';

  @override
  String get serendipityEnterRitual => 'Enter the casting ritual';

  @override
  String get serendipityOracleTapPrompt =>
      'Be still and hold the question in your mind\nSlowly tap the taiji below 6 times to seek the six lines';

  @override
  String serendipityOracleResultPrefix(String name) {
    return '🔮 Cast:\n$name';
  }

  @override
  String get serendipityOracleThinking =>
      'AI is reading the hexagram, please wait...';

  @override
  String get serendipityOracleAskHint => 'Type your follow-up or question...';

  @override
  String get serendipityNewQuestion => '↺ Ask something else (recast)';

  @override
  String get serendipityOracleArchive => 'Oracle archive';

  @override
  String serendipityOracleLogEvent(String t) {
    return '🎯 Question: $t';
  }

  @override
  String serendipityOracleLogGua(String t) {
    return '🔮 Hexagram: $t';
  }

  @override
  String get serendipitySpeakerMe => 'Me';

  @override
  String get helpSerendipityMorningTitle => 'Morning rehearsal';

  @override
  String get helpSerendipityMorningBody =>
      'Every morning, spend two minutes locking in today\'s luck expectation. Write down the good thing you want to happen, run the countdown to stay focused, then use positive psychology to reinforce that belief.';

  @override
  String get helpSerendipityChallengeTitle => 'Breakout radar';

  @override
  String get helpSerendipityChallengeBody =>
      'Luck is not mysticism but a behaviour pattern. Do one small habit-breaking action every day — take a different route home, start a conversation with a stranger — then log the challenge and your reflection here.';

  @override
  String get helpSerendipityAlchemistTitle => 'Bad-luck alchemy';

  @override
  String get helpSerendipityAlchemistBody =>
      'Turn a bad experience into fuel for growth. Write down what went wrong and your instinctive reaction, then re-read it through a CBT lens and smelt that bad luck into psychological resilience.';

  @override
  String get helpSerendipityNightTitle => 'Glimmer notes';

  @override
  String get helpSerendipityNightBody =>
      'Catch a passing hunch before sleep. Record the thought that starts with “I just feel I should…”, commit to a choice, then look back later to see whether the hunch came true — that is how lucky intuition gets trained.';

  @override
  String get helpSerendipityDiaryTitle => 'Free diary';

  @override
  String get helpSerendipityDiaryBody =>
      'Write whatever comes to mind. This is your private hollow tree; the AI helps you sort out your feelings — no judging, no leaking.';

  @override
  String get helpSerendipityOracleTitle => 'Oracle casting';

  @override
  String get helpSerendipityOracleBody =>
      'When something puzzles you, cast for an answer. Settle your mind, hold the question silently, tap the taiji six times to build the hexagram, and let the I Ching plus psychology point the way.';

  @override
  String get socialRadarTitle => 'Fen Community';

  @override
  String get socialDelegationEntry => 'Errands & my circle';

  @override
  String get socialDbDegradedHint =>
      'Local data is temporarily unavailable (the local database may not be ready yet). What you see below may be out of date.';

  @override
  String get socialTabMask => 'Mask';

  @override
  String get socialTabRadar => 'Radar';

  @override
  String get socialTabLedger => 'Log';

  @override
  String get socialTabRoster => 'Roster';

  @override
  String get socialFeedBrain =>
      '⚡ Feeding radar data to the main brain, forcing a social decision...';

  @override
  String get socialMaskLocked =>
      '🛡️ Mask locked! Old social memory cleared — persona confusion prevented.';

  @override
  String get socialManualPairTitle => 'Manual force pairing';

  @override
  String get socialPeerAgentName => 'Peer agent name';

  @override
  String get socialPeerMasterName => 'Peer\'s master name (note)';

  @override
  String get socialPeerHardId => 'Peer\'s hard ID';

  @override
  String get socialPair => 'Pair';

  @override
  String get socialNodeAdded => '✅ Node added!';

  @override
  String socialForceSendTitle(String name) {
    return 'Force send: $name';
  }

  @override
  String get socialForceSendLabel => 'The message you want to send directly';

  @override
  String get socialForceSendHint => 'Type content to send verbatim...';

  @override
  String get socialDirectSent =>
      'Barrier bypassed — sending your words verbatim...';

  @override
  String get socialDirectSend => 'Send unreviewed';

  @override
  String socialGiftSent(String gift) {
    return '$gift sent';
  }

  @override
  String get socialGiftFailed =>
      'Gift failed: peer isn\'t on any online channel';

  @override
  String get socialRecoSent => '🤝 Recommendation request sent';

  @override
  String get socialRecoFailed =>
      'Request failed: peer isn\'t on any online channel';

  @override
  String socialVerifyTitle(String name) {
    return '🔐 Identity verification: $name';
  }

  @override
  String get socialVerifyPinnedFor =>
      'Identity fingerprint pinned for this node (TOFU):';

  @override
  String get socialVerifyNoPin =>
      'No nearby handshake yet — no pinned identity';

  @override
  String socialVerifyMyFingerprint(String fp) {
    return 'My fingerprint (should appear on the peer\'s screen): $fp';
  }

  @override
  String get socialVerifyInputLabel =>
      'Enter the 8-digit fingerprint on the peer\'s screen';

  @override
  String get socialVerifyMatch =>
      '✅ Fingerprints match — this connection\'s identity is trustworthy.';

  @override
  String get socialVerifyMismatch =>
      '❌ Fingerprints do NOT match! A man-in-the-middle is suspected.\nAdvice: delete and block this node, then re-handshake in person or via another trusted channel.';

  @override
  String get socialVerifyHintNoPin =>
      'Note: a verifiable pinned identity appears here only after both sides enable the radar and complete a nearby handshake.';

  @override
  String get socialVerifyCompare => 'Compare';

  @override
  String get socialFederationNoIdentity =>
      'No agent identity yet — save it on the diplomatic mask page first';

  @override
  String get socialFederationFetching =>
      '🌐 Fetching the A2A federation roster...';

  @override
  String socialFederationEmpty(String err) {
    return 'Roster empty: $err';
  }

  @override
  String get socialFederationEmptyErr =>
      'no other registered agents on the Hub (or Hub URL not configured)';

  @override
  String socialFederationAllKnown(int n) {
    return 'Every agent on the Hub is already in your roster ($n total)';
  }

  @override
  String socialFederationTitle(int n) {
    return '🌐 Federation roster ($n not yet added)';
  }

  @override
  String get socialAnonAgent => 'Anonymous agent';

  @override
  String socialFederationLastSeen(String id, String time) {
    return '$id · last active $time';
  }

  @override
  String get socialFederationDiscovered => 'A2A federation discovery';

  @override
  String get socialFederationSource => 'A2A federation';

  @override
  String get socialFederationMask =>
      'Discovered via federation roster, awaiting a secure handshake';

  @override
  String get socialSourceManual => 'Added manually';

  @override
  String get socialNoSignatureBadge => 'No signature yet';

  @override
  String get socialCollect => 'Add';

  @override
  String socialFederationCollected(int n) {
    return '✅ Added $n federation agents to your stranger folder; once the radar is on they\'ll handshake step by step per the safety rules.';
  }

  @override
  String get socialFederationAutoTitle => 'Auto-pull federation roster';

  @override
  String get socialFederationAutoDesc =>
      'When on, your agent automatically pulls the Hub\'s public registered-agent roster into your stranger folder. It never sends messages on its own — outreach still follows the review gateway, observation mode and budget gate. Off by default.';

  @override
  String socialFederationAutoDone(int n) {
    return '🌐 Auto-added $n new federation agents to your stranger folder.';
  }

  @override
  String get socialFederationAutoNone =>
      'No new agents to pull from the federation roster right now.';

  @override
  String socialFederationAutoFailed(String err) {
    return 'Auto-pull failed: $err';
  }

  @override
  String socialFederationAutoClear(int n) {
    return 'Clear auto-collected ($n)';
  }

  @override
  String get socialFederationAutoClearTitle =>
      'Clear auto-collected federation agents?';

  @override
  String socialFederationAutoClearConfirm(int n) {
    return 'This removes $n agents that were auto-pulled from the roster and have not started any contact. Entries you added yourself are never touched.';
  }

  @override
  String socialFederationAutoCleared(int n) {
    return 'Removed $n auto-collected federation agents.';
  }

  @override
  String get socialFederationAutoNote =>
      'Auto-collected from federation roster';

  @override
  String get socialDone => 'Done';

  @override
  String socialCountdown(String t) {
    return '🔐 Countdown $t';
  }

  @override
  String get socialBadgeSent => 'Sent';

  @override
  String get socialBadgeReviewing => 'Under review';

  @override
  String get socialBadgeChatting => 'Chatting';

  @override
  String get socialBadgeBlocked => 'Blocked';

  @override
  String get socialPresenceOnline => '⚡ Online in person';

  @override
  String socialPeerSubtitle(
      String master, String status, String id, String rep) {
    return 'Master: $master | Status: $status\nID: $id · Rep $rep';
  }

  @override
  String get socialStatusOnline => 'online';

  @override
  String get socialStatusOffline => 'offline';

  @override
  String get socialMenuChat => '💬 Chat 1:1 with their fen';

  @override
  String get socialChatTooltip => 'Open the 1:1 private chat with their fen';

  @override
  String get socialChatHint => 'Tap the card or the 💬 button to chat 1:1';

  @override
  String get socialMenuDelegate => '🙋 Ask them to do something (M2)';

  @override
  String get socialMenuIntercard => '🤝 Fen introduction (M3)';

  @override
  String get socialMenuGreet => '💬 Master force-send (unreviewed)';

  @override
  String get socialMenuGift => '🎁 Send a gift';

  @override
  String get socialMenuReco => '🤝 Request a recommendation';

  @override
  String get socialMenuVerify => '🔐 Verify identity fingerprint (anti-MITM)';

  @override
  String get socialMenuFamily => 'Promote to family (unreviewed)';

  @override
  String get socialMenuFriend => 'Set as friend (auto-redacted)';

  @override
  String get socialMenuStranger => 'Demote to stranger (strict outreach)';

  @override
  String get socialMenuDelete => 'Delete & block';

  @override
  String get socialMaskUndefined => 'Undefined mask';

  @override
  String get socialMaskNoSignature => '「No public persona signature set」';

  @override
  String socialHardId(String id) {
    return 'Local hard ID: $id';
  }

  @override
  String socialFingerprintLine(String fp) {
    return 'Fingerprint: $fp (for the peer to compare in person)';
  }

  @override
  String get socialGatewayGuard => 'Physically isolated gateway guarding';

  @override
  String get socialLogicPreset => 'Fen logic preset mode';

  @override
  String get socialModeCasual => '☕ Casual chat (relaxed/humorous)';

  @override
  String get socialModeBusiness => '💼 Business hunter (direct/efficient)';

  @override
  String get socialModeDating =>
      '💖 Dating & matchmaking (socially adept/ice-breaking)';

  @override
  String get socialModeEmergency => '🚨 Emergency SOS (broadcast)';

  @override
  String get socialModeCustom => '🛠️ Fully custom (follows the task box)';

  @override
  String socialModeSwitched(String mode) {
    return '🧠 Persona switched to $mode. Same identity — tone only; memory and handshakes stay untouched.';
  }

  @override
  String get roomRoleParticipant => 'Participant';

  @override
  String get roomRoleHost => 'Host';

  @override
  String get roomRoleCohost => 'Co-host';

  @override
  String get roomRoleGuest => 'Guest';

  @override
  String get roomRoleNpc => 'NPC';

  @override
  String get roomRoleManageTitle => 'Room roles';

  @override
  String roomRoleMine(String role) {
    return 'My role: $role';
  }

  @override
  String get roomRoleNoMembers => 'No other members observed in this room yet.';

  @override
  String get roomRoleClaimHost => 'Claim host';

  @override
  String get roomRoleClaimedHost => 'You are now the host of this room.';

  @override
  String get roomRoleClaimHostExists => 'This room already has a host.';

  @override
  String get roomRoleNotHost => 'Only the host can grant roles.';

  @override
  String get roomRoleLastHostBlocked => 'Cannot revoke the room\'s last host.';

  @override
  String roomRoleSetTo(String role) {
    return 'Set to $role';
  }

  @override
  String get socialEmojiLabel => 'Emoji';

  @override
  String get socialNicknameLabel => 'Public nickname';

  @override
  String get socialMaskProfileLabel => 'Public redacted persona signature';

  @override
  String get socialIcebreakTask => '🎯 Current ice-breaking task (classified)';

  @override
  String get socialIcebreakHint => 'Give your fen a nearby-recon order here...';

  @override
  String get socialLockMask => '💾 Lock mask & orders';

  @override
  String get socialTaskReroll => 'Reroll';

  @override
  String get socialHeartbeatOn =>
      '💓 Dual-mode heartbeat running (Bluetooth + Wi-Fi NSD)\nBackground wake-lock active — stays connected even with the screen off!';

  @override
  String get socialRadarIdle =>
      'Radar sleeping — tap the centre to start timed socialising';

  @override
  String get socialDurationLabel => 'Social duration: ';

  @override
  String get socialDuration15 => '15 min';

  @override
  String get socialDuration30 => '30 min';

  @override
  String get socialDuration60 => '1 hour';

  @override
  String get socialDurationUnlimited => 'Unlimited (drains battery)';

  @override
  String get socialChannelConfig => '🛰️ Global channel configuration';

  @override
  String get socialChannelNearby => '📡 Bluetooth/Wi-Fi direct radar (Nearby)';

  @override
  String get socialChannelLan => '🏡 Encrypted LAN interconnection (mDNS)';

  @override
  String get socialChannelCloud => '☁️ Cloud relay network (global social)';

  @override
  String get suggestionInboxTitle => 'Suggestions awaiting your approval';

  @override
  String get suggestionApprove => 'Approve and send';

  @override
  String get suggestionIgnore => 'Ignore';

  @override
  String get suggestionEmpty => 'Nothing awaiting approval';

  @override
  String get suggestionToTarget => 'To: ';

  @override
  String get suggestionApproved => 'Approved and sent';

  @override
  String get suggestionNotSent =>
      'Not sent, see the social report for the reason';

  @override
  String get socialLedgerTitle =>
      '🐾 Social log · Plain ledger (main delegate only)';

  @override
  String get socialLedgerEmpty => 'Waiting for the heartbeat engine...';

  @override
  String get socialRosterTitle => '📇 Tiered social circle';

  @override
  String get socialScanning =>
      'Listening on the 2.4GHz / 5GHz physical spectrum...';

  @override
  String get socialScanIdle =>
      'Channel idle. Tap the centre on the home screen to start the energy radar; your fen proxy will spontaneously establish nearby connections.';

  @override
  String get socialTierFamily => '👨‍👩‍👧 Family agents';

  @override
  String get socialTierFriend => '🤝 Friend agents';

  @override
  String get socialTierStranger => '👽 Stranger agents';

  @override
  String get worldUnknownError => 'Unknown error';

  @override
  String get worldAskTitle => '💬 Ask the town';

  @override
  String get worldAskHint => 'What do you want to ask the residents?';

  @override
  String get worldAskTargetLabel =>
      'Specific resident (leave empty = whole town)';

  @override
  String get worldAskSend => 'Ask';

  @override
  String get worldAskOk =>
      '📨 Question sent to the town — the answer will appear in the GOD control room';

  @override
  String get worldInterveneTitle => '⚡ Inject intervention';

  @override
  String get worldInterveneBody =>
      'The instruction will be injected into the town\'s next step, affecting all residents\' subsequent behaviour.';

  @override
  String get worldInterveneHint =>
      'e.g. A harvest festival is held at the town square';

  @override
  String get worldInterveneSend => 'Inject';

  @override
  String get worldInterveneOk =>
      '⚡ Intervention injected — it takes effect on the town\'s next step';

  @override
  String get worldStopTitle => '⏹ Stop the town?';

  @override
  String get worldStopBody =>
      'This stops the live run of the current experiment and interrupts residents\' activity. Continue?';

  @override
  String get worldStop => 'Stop';

  @override
  String get worldStopOk => '⏹ Town stopped';

  @override
  String worldCmdFailed(String err) {
    return 'Command failed: $err';
  }

  @override
  String worldJoined(String name) {
    return '🚪 Joined 「$name」';
  }

  @override
  String worldJoinFailed(String err) {
    return 'Join failed: $err';
  }

  @override
  String worldLeft(String name) {
    return '👋 Left 「$name」';
  }

  @override
  String worldLeaveFailed(String err) {
    return 'Leave failed: $err';
  }

  @override
  String get worldCreateRoomTitle => 'Create a room';

  @override
  String get worldRoomNameLabel => 'Room name';

  @override
  String get worldTopicLabel => 'Topic (optional)';

  @override
  String get worldModeFree => 'Free chat';

  @override
  String get worldModeTurn => 'Turn-based';

  @override
  String get worldCreate => 'Create';

  @override
  String get worldCreated => '✨ Room created';

  @override
  String worldCreateFailed(String err) {
    return 'Create failed: $err';
  }

  @override
  String get worldNoWorldUrl => 'World URL not configured';

  @override
  String get worldNoIdentity =>
      'No agent identity yet — initialise it on the management page first.';

  @override
  String get worldRoomsHeader => 'Rooms';

  @override
  String get worldCreateRoom => 'New room';

  @override
  String get worldNoRooms =>
      'No rooms yet. Make sure world.js is running on the server,\nor pull down to refresh.';

  @override
  String get worldGodUnreachable =>
      'GOD bridge unreachable — make sure GOD and god-bridge.js are running on your computer';

  @override
  String get worldGodPaused => '⏸ Paused';

  @override
  String get worldGodRunning => '▶ Running';

  @override
  String worldGodStep(String n) {
    return 'Step $n';
  }

  @override
  String get worldGodStatusUnknown => 'Upstream status unknown';

  @override
  String get worldGodTitle => 'GOD control room';

  @override
  String get worldRefreshStatus => 'Refresh status';

  @override
  String worldGodTown(String hyp, String exp) {
    return 'Town: $hyp/$exp';
  }

  @override
  String get worldGodNoExperiment => 'No experiment connected';

  @override
  String get worldGodResume => '▶️ Resume';

  @override
  String get worldGodResumeOk => '▶️ Town resumed automatic running';

  @override
  String get worldGodPause => '⏸️ Pause';

  @override
  String get worldGodPauseOk => '⏸️ Town time paused';

  @override
  String get worldGodStepBtn => '⏭️ Step';

  @override
  String get worldGodStepOk => '⏭️ Advanced one step';

  @override
  String get worldGodStopBtn => '⏹️ Stop';

  @override
  String get worldGodAskBtn => '💬 Ask the town';

  @override
  String get worldGodInterveneBtn => '⚡ Inject intervention';

  @override
  String worldReportUnavailable(String err) {
    return '🌍 World daily report unavailable.\n$err';
  }

  @override
  String get worldReportNoServer =>
      'Make sure the world server URL is configured.';

  @override
  String worldReportTitle(String date) {
    return 'World daily report · $date';
  }

  @override
  String worldReportSummary(String msgs, String agents, String mine) {
    return '$msgs messages today · $agents active agents · $mine from us';
  }

  @override
  String worldReportRoomLine(String name, String msgs, String mine) {
    return '· $name: $msgs messages ($mine from us)';
  }

  @override
  String get worldRoomEnter => 'Enter';

  @override
  String get worldRoomExitTooltip => 'Leave room';

  @override
  String get worldRoomJoin => 'Join';

  @override
  String get worldSectionOfficial => 'Official rooms';

  @override
  String get worldSectionMine => 'My rooms';

  @override
  String get worldBadgeOfficial => 'Official';

  @override
  String get worldBadgeMine => 'Mine';

  @override
  String get worldBadgePending => 'Pending';

  @override
  String get worldSearchTitle => '🔍 Find by room number';

  @override
  String get worldSearchHint => 'Enter room number (group ID)';

  @override
  String get worldSearchBtn => 'Find';

  @override
  String worldSearchNotFound(String id) {
    return 'No room found with number \"$id\"';
  }

  @override
  String get worldRequestJoin => 'Request to join';

  @override
  String get worldRequestNoteLabel => 'Message (optional)';

  @override
  String get worldRequestSent => 'Request sent — waiting for the room owner';

  @override
  String worldRequestFailed(String err) {
    return 'Request failed: $err';
  }

  @override
  String worldRequestsTitle(String count) {
    return 'Join requests ($count)';
  }

  @override
  String get worldRequestsEmpty => 'No pending requests';

  @override
  String get worldApprove => 'Approve';

  @override
  String get worldReject => 'Decline';

  @override
  String worldApproveOk(String name) {
    return 'Approved \"$name\"';
  }

  @override
  String worldRejectOk(String name) {
    return 'Declined \"$name\"';
  }

  @override
  String worldHandleFailed(String err) {
    return 'Action failed: $err';
  }

  @override
  String get worldNeedApproval =>
      'This is a private room: request access and wait for the owner to approve.';

  @override
  String get worldMyRoomsFull =>
      'You hit the room limit (per-agent cap is set on the server)';

  @override
  String get worldCreatedPrivate =>
      '✨ Room created (private: not listed publicly — others must find it by room number and request to join)';

  @override
  String worldHistoryWhy(String max, String retained) {
    return 'History only accumulates after you join; the server keeps the latest $max messages per room, $retained kept now.';
  }

  @override
  String get worldPullHistory => 'Load room history';

  @override
  String worldPullHistoryOk(String n) {
    return 'Loaded $n earlier messages';
  }

  @override
  String get worldPullHistoryNone =>
      'The server has no earlier messages either';

  @override
  String worldPullHistoryFailed(String err) {
    return 'Failed: $err';
  }

  @override
  String get worldRoomChatFree => 'Free chat';

  @override
  String get worldLobbyName => 'Wold Lounge';

  @override
  String get worldLobbyTopic => 'Free chat, keep it civil';

  @override
  String worldRoomSubtitle(String mode, String present, String count) {
    return '$mode · $present present · $count subscribed';
  }

  @override
  String worldRoomTopicSuffix(String topic) {
    return ' · $topic';
  }

  @override
  String get worldAutoreplyOn =>
      '🤖 Autopilot on: your fen will reply automatically within budget (observation log keeps recording)';

  @override
  String get worldAutoreplyOff => '👁️ Back to pure observation mode';

  @override
  String get worldDrafting =>
      '🪄 Drafting in persona and sending for review, please wait…';

  @override
  String worldSendFailed(String err) {
    return 'Send failed: $err';
  }

  @override
  String get worldRoomTurnSuffix => ' (turn-based)';

  @override
  String get worldAutopilotTooltip => 'Let my fen say something';

  @override
  String get worldAutopilotLabel => 'Autopilot';

  @override
  String get worldAutopilotStateOn => 'Autopilot';

  @override
  String get worldAutopilotStateOff => 'Observing only';

  @override
  String worldAutopilotStatus(String state, String decision) {
    return '$state · Last decision: $decision';
  }

  @override
  String get worldRoomEmpty => 'The room is quiet — say something.';

  @override
  String get worldLoading => 'Loading…';

  @override
  String get worldAnonAgent => 'Anonymous agent';

  @override
  String get worldMe => 'Me';

  @override
  String get worldSuggestionTooltip => 'Generate suggestion card';

  @override
  String get worldSuggestionTitle => '🧭 Suggestion card (draft, not sent)';

  @override
  String get worldSuggestionDrafting => 'Drafting a reply in persona...';

  @override
  String get worldSuggestionFailed =>
      'Generation failed: check the brain engine config and retry.';

  @override
  String get worldSuggestionEditHint => 'You can edit before sending';

  @override
  String get worldSuggestionSend => 'Send to room';

  @override
  String get worldSayHint => 'Speak directly as the master…';

  @override
  String get worldVibrancyHot => '🔥 Busy';

  @override
  String get worldVibrancyWarm => '🌤 Steady';

  @override
  String get worldVibrancyCold => '🌙 Quiet';

  @override
  String worldVibrancyDetail(String speakers, String messages) {
    return '$speakers talking · $messages messages';
  }

  @override
  String get worldVibrancyObservedHint =>
      ' (message count is local observation, not the server\'s exact figure)';

  @override
  String get worldBridgeSection => 'Friend-pool bridging';

  @override
  String get worldBridgeNone =>
      'No outsider to bridge in this room yet (same-circle or already-acquainted people are not re-recommended).';

  @override
  String worldBridgeCount(String count) {
    return '$count outsider(s) to bridge';
  }

  @override
  String worldBridgeSharedRooms(String count) {
    return '$count shared room(s)';
  }

  @override
  String worldBridgeMsgCount(String count) {
    return '$count message(s)';
  }

  @override
  String get worldBridgeRecommend => 'Introduce';

  @override
  String get worldBridgeTooltip => 'Suggest an introduction (cross-circle)';

  @override
  String get worldBridgeSameCircle => 'Same circle';

  @override
  String get worldBridgeAlreadyLinked => 'Already acquainted';

  @override
  String worldBridgeWhyLine(String detail) {
    return 'Why recommended: $detail';
  }

  @override
  String worldBridgeRoomProvenance(String room) {
    return 'Met via \"$room\"';
  }

  @override
  String worldBridgeCircleLine(String circle) {
    return 'Introducing under \"$circle\"';
  }

  @override
  String get worldBridgeNoCircle =>
      'You have no circle of your own yet — enter a circle first, then bridge across circles.';

  @override
  String worldBridgeLinkCreated(String room) {
    return '✅ Cross-circle edge created: met via \"$room\"';
  }

  @override
  String get worldBridgeLinkFailed =>
      'Failed to create the cross-circle edge. Please retry.';

  @override
  String get worldBridgeBlockedTitle => 'Cannot create a cross-circle edge';

  @override
  String get worldBridgeBlockedNotInRoom =>
      'This person never appeared in this room — a cross-circle edge must have a room as its origin; you cannot claim acquaintance from an ID alone.';

  @override
  String get worldBridgeBlockedSameCircle =>
      'You are already in the same circle — the edge exists inside the circle, so no cross-circle introduction is needed.';

  @override
  String get worldBridgeBlockedAlreadyLinked =>
      'You are already acquainted (introduction / delegation / contacts) — use the existing relationship; it does not consume a cross-circle slot.';

  @override
  String get worldBridgeBlockedSelf => 'You cannot introduce yourself.';

  @override
  String get worldBridgeBlockedNoRoom =>
      'Missing the room origin — cannot create a cross-circle edge.';

  @override
  String get worldBridgeBlockedDuplicate =>
      'This cross-circle edge already exists (idempotent, not double-counted).';

  @override
  String get worldMetricTitle => 'Cross-circle links';

  @override
  String worldMetricLine(String links, String known, String perCapita) {
    return '$links cross-circle edge(s) I created · $known agent(s) I have met · per-capita $perCapita';
  }

  @override
  String get worldMetricNoData =>
      'No cross-circle data yet — first meet an outsider in a world room.';

  @override
  String get privacyOnlyHumanTitle => 'Only accept messages from real people';

  @override
  String get privacyOnlyHumanSubtitle =>
      'When on, other fens can only relay messages to you — they can\'t reply on your behalf.';

  @override
  String get privacyLocalFirst => 'Your data stays on this device by default.';

  @override
  String get delegationTitle => 'Errands';

  @override
  String get delegationTabInbox => 'Asked of me';

  @override
  String get delegationTabOutbox => 'I asked';

  @override
  String get delegationTabCircle => 'My circle';

  @override
  String get delegationEmptyInbox => 'Nothing has been asked of your fen yet.';

  @override
  String get delegationEmptyOutbox => 'You haven\'t delegated anything yet.';

  @override
  String get delegationNew => 'New errand';

  @override
  String get delegationTo => 'Ask this fen';

  @override
  String get delegationTaskHint =>
      'e.g. Ask Lao Wang if he\'s free this weekend';

  @override
  String get delegationSent => 'Sent. Waiting for their fen to reply.';

  @override
  String get delegationOfflineQueued =>
      'Saved on this device. It will wait until a channel opens — right now no channel reached them.';

  @override
  String get delegationAskResponse => 'What should we pass back? (optional)';

  @override
  String get delegationActDone => 'Done';

  @override
  String get delegationActNeedsHuman => 'Needs the human';

  @override
  String get delegationActRespond => 'Respond';

  @override
  String get delegationActDecline => 'Decline';

  @override
  String get delegationRevoke => 'Cancel';

  @override
  String get delegationRevoked => 'Cancelled';

  @override
  String get delegationRevokeConfirm =>
      'Cancel this errand? It will be recorded as cancelled.';

  @override
  String get delegationStatePending => 'Waiting';

  @override
  String get delegationStateAnswered => 'Answered';

  @override
  String get delegationStateNeedsHuman => 'Needs the human';

  @override
  String get delegationStateDeclined => 'Declined';

  @override
  String get delegationStateRevoked => 'Cancelled';

  @override
  String get delegationBlockedTitle => 'Fen can\'t send that';

  @override
  String get delegationBlockedBody =>
      'Fen never moves money between people — there is nowhere to put an amount, by design. Please send this one yourself.';

  @override
  String get delegationEmptyTask => 'Write what you want done first.';

  @override
  String get delegationNoPeer => 'Pick who to ask first.';

  @override
  String get circleTitle => 'My circle';

  @override
  String get circleCreate => 'Start a circle';

  @override
  String get circleNameHint => 'e.g. Saturday football, Lisbon';

  @override
  String get circleCreated => 'Circle created.';

  @override
  String get circleInviteCode => 'Invite code';

  @override
  String get circleGenerateInvite => 'Generate invite code';

  @override
  String get circleJoin => 'Join with a code';

  @override
  String get circleJoinHint => 'Paste the invite code you were given';

  @override
  String get circleJoined => 'You\'re in.';

  @override
  String get circleJoinFailed => 'That code is invalid or expired.';

  @override
  String circleVisibleSummary(int n, int m) {
    return '$n fens visible · $m of them not your inviter';
  }

  @override
  String get circleAcceptancePass =>
      'Acceptance met (needs 3 visible, 2 not your inviter)';

  @override
  String get circleAcceptanceFail =>
      'Acceptance not met yet — invite a couple more neighbours';

  @override
  String circleFallbackNote(int n, String src) {
    return '$n of them come from fallback ($src) — not circle members';
  }

  @override
  String circleMemberCount(int n) {
    return '$n members';
  }

  @override
  String get telemetryCounts => 'Event counts (acceptance check)';

  @override
  String get telemetryEmpty => 'No events recorded yet.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardFunnelTitle => 'Weekly funnel';

  @override
  String get dashboardColWeek => 'Week';

  @override
  String get dashboardColOnboarding => 'Onboard';

  @override
  String get dashboardColCircle => 'Circle';

  @override
  String get dashboardColDelegation => 'Errand';

  @override
  String get dashboardColIntercard => 'Intro';

  @override
  String get dashboardColHandshake => 'Shake';

  @override
  String get dashboardColActive => 'Active';

  @override
  String get dashboardTtfd => 'TTFD median';

  @override
  String get dashboardDelta => 'Disclosure Δ';

  @override
  String get dashboardDeltaHint =>
      'Reply rate without disclosure minus with disclosure (Phase −1).';

  @override
  String get dashboardNoData => 'No events yet — run the app a bit first.';

  @override
  String get dashboardSourceHint =>
      'Source: local telemetry on this device only.';

  @override
  String get digestTitle => 'Daily digest';

  @override
  String get digestEmpty => 'Nothing new in the last 24 hours.';

  @override
  String get digestSectionPending => 'Waiting for you';

  @override
  String get digestSectionMine => 'Your errands';

  @override
  String get digestSectionCircle => 'Circles';

  @override
  String get digestSectionStats => 'Numbers';

  @override
  String get digestStatDone => 'errands done';

  @override
  String get digestStatHandshake => 'handshakes';

  @override
  String get digestActionOpenInbox => 'Reply now';

  @override
  String get digestActionOpenOutbox => 'My errands';

  @override
  String get digestActionOpenCircle => 'My circle';

  @override
  String get digestActionOpenDashboard => 'Dashboard';

  @override
  String get digestNotePlain =>
      'You\'re in the plain-digest group (A/B experiment).';

  @override
  String get digestNoteAction =>
      'You\'re in the with-actions group (A/B experiment).';

  @override
  String get morningGreetingMorning => 'Good morning';

  @override
  String get morningGreetingNoon => 'Good afternoon';

  @override
  String get morningGreetingEvening => 'Good evening';

  @override
  String get morningGreetingBody =>
      'Here is your recap from the last three days: ';

  @override
  String morningHiPending(int count) {
    return '$count delegations awaiting your reply';
  }

  @override
  String morningHiSent(int count) {
    return 'You delegated $count tasks';
  }

  @override
  String morningHiCircle(int count) {
    return '$count new circles joined';
  }

  @override
  String morningHiTopics(String topics) {
    return 'Often about: $topics';
  }

  @override
  String morningHiLongTerm(String topics) {
    return 'Long-term interests: $topics';
  }

  @override
  String get morningEmpty =>
      'It has been quiet for the last three days — enjoy today.';

  @override
  String get notifyMorningTitle => 'Good morning — your 3-day recap';

  @override
  String get notifyMorningBody =>
      'Your agent summed up what happened over the last three days.';

  @override
  String notifyMorningBodyPending(int count) {
    return 'You have $count delegations waiting. Your agent summed up the last three days.';
  }

  @override
  String get digestSectionChat => 'Your conversations with your agent';

  @override
  String digestChatSummary(int sessions, int turns, int days) {
    return '$sessions conversations · $turns turns · across $days days';
  }

  @override
  String digestChatTopics(String topics) {
    return 'Often about: $topics';
  }

  @override
  String get intercardDialogTitle => 'Fen introduction card';

  @override
  String get intercardReasonLabel => 'Why worth meeting';

  @override
  String get intercardTopicsLabel => '3 topics (comma separated)';

  @override
  String get intercardConfirmSend => 'Confirm & send';

  @override
  String get intercardReceivedTitle => 'Introductions received';

  @override
  String get intercardMineTitle => 'Cards I sent';

  @override
  String get intercardBlockedTitle => 'Card blocked';

  @override
  String get intercardBlockedL3 =>
      'A private field\'s value leaked into the card text.';

  @override
  String get intercardEmptyContent => 'Write a reason and topics first.';

  @override
  String get intercardSentOk => 'Sent. You can revoke within 24h.';

  @override
  String get intercardRevoke => 'Revoke';

  @override
  String get intercardNone => 'No introduction cards yet.';

  @override
  String get intercardRevoked => 'Revoked.';

  @override
  String get intercardRevokeHint => 'Sent — you can revoke within 24h.';

  @override
  String get intercardSent => 'Sent.';

  @override
  String intercardFrom(String owner) {
    return 'Signed introduction from $owner\'s master.';
  }

  @override
  String get deviceControlTitle => 'Phone Control';

  @override
  String get deviceControlRefreshStatus => 'Refresh status';

  @override
  String get deviceControlUnsupported =>
      'This build does not support phone control';

  @override
  String get deviceControlServiceConnected =>
      'Accessibility service: connected';

  @override
  String get deviceControlServiceCheckedNotConnected =>
      'Accessibility service: checked but not connected';

  @override
  String get deviceControlServiceOff => 'Accessibility service: off';

  @override
  String get deviceControlStatusUnknown => 'Status unknown';

  @override
  String get deviceControlGoSystemHint =>
      'Find \"Fen\" in the system list, turn on the switch, then come back here and refresh';

  @override
  String get deviceControlGoSettings => 'Open system settings';

  @override
  String get deviceControlRedetect => 'Re-detect';

  @override
  String get deviceControlRedetectTip =>
      'Tip: if repeated detection keeps failing, go to system settings, turn \"Fen Screen Assistant\" off and on again, or restart the app — some phones disconnect the accessibility service during background cleanup.';

  @override
  String get deviceControlAllowTitle => 'Allow the agent to operate the phone';

  @override
  String get deviceControlAllowSubReady =>
      'When on, the agent can read the screen, tap, type, and open apps; it will ask for your confirmation the first time';

  @override
  String get deviceControlAllowSubChecked =>
      'Checked in the system, but the service is not connected: tap “Re-detect” above';

  @override
  String get deviceControlAllowSubNeedService =>
      'Turn on the system accessibility service first to enable this switch';

  @override
  String get deviceControlToolsHeader =>
      'These capabilities are mounted when enabled';

  @override
  String get deviceControlToolReadScreen =>
      'Read text and tappable elements on screen';

  @override
  String get deviceControlToolTap => 'Tap by text or coordinates';

  @override
  String get deviceControlToolInput => 'Type into input fields';

  @override
  String get deviceControlToolSwipe => 'Swipe pages and scroll lists';

  @override
  String get deviceControlToolPressKey => 'Back / Home / Recents / Enter';

  @override
  String get deviceControlToolOpenApp => 'Open a specified app (package name)';

  @override
  String get deviceControlDenylistTitle => 'Sensitive app denylist';

  @override
  String get deviceControlDenylistBody =>
      'While these apps are in the foreground the agent performs no actions (banking, payments, password managers, system settings). One package name per line; commas are also supported.';

  @override
  String get deviceControlSaveDenylist => 'Save denylist';

  @override
  String get deviceControlResetDefault => 'Restore defaults';

  @override
  String get deviceControlFooter =>
      'Note: phone control uses the Android accessibility service — no root and no extra plugins.\n· Turn the switch above off and the related tools are revoked from the agent immediately;\n· Every action is written to the audit log, viewable in “Manage Settings”;\n· The agent will never act on apps you have not authorized.';

  @override
  String get deviceControlToastNeedAccessibility =>
      'Please enable the \"Fen\" accessibility service in system settings first';

  @override
  String get deviceControlToastOn =>
      'Phone control enabled: you will still be asked to confirm the first time';

  @override
  String get deviceControlToastOff =>
      'Phone control disabled; related tools have been revoked';

  @override
  String deviceControlToastSaved(String n) {
    return 'Denylist saved ($n items)';
  }

  @override
  String get deviceControlToastReset => 'Default denylist restored';

  @override
  String get contactDefaultAgentName => 'Wild Agent';

  @override
  String get contactDefaultMasterName => 'Physical Probing';

  @override
  String get contactDefaultNotes => 'No notes';

  @override
  String get contactSendingThroughGateway =>
      '⚡ Sending directly through the gateway...';

  @override
  String get contactEditTitle => 'Edit agent profile notes';

  @override
  String get contactEditAgentLabel => 'Agent nickname';

  @override
  String get contactEditMasterLabel => 'Owner note';

  @override
  String get contactEditNotesLabel => 'Private dossier';

  @override
  String get contactEditConfirm => 'Confirm sync';

  @override
  String get contactEditSaved => '✅ Profile notes captured and synced!';

  @override
  String get contactRequestReco => 'Request recommendation';

  @override
  String get contactSendGift => 'Send gift';

  @override
  String contactGiftSent(String gift) {
    return '$gift sent, awaiting the other party\'s receipt';
  }

  @override
  String get contactGiftFailed =>
      'Gift failed: the other party is offline or on no channel';

  @override
  String get contactRecoRequested =>
      '🤝 Recommendation request sent; the other party decides based on their local reputation';

  @override
  String get contactRecoFailed =>
      'Request failed: the other party is on no online channel';

  @override
  String get contactTierBlockToast =>
      'Reputation too low; recommend removing and blocking this node from the roster';

  @override
  String contactTierAdjusted(String tier) {
    return '✅ Adjusted to $tier per reputation advice';
  }

  @override
  String get contactTierFriend => 'Can upgrade to friend';

  @override
  String get contactTierFamily => 'Can upgrade to family';

  @override
  String get contactTierStranger => 'Suggest downgrade to stranger';

  @override
  String get contactTierBlock => 'Suggest block';

  @override
  String get contactStatusLocked => 'Radar locked';

  @override
  String get contactStatusSent => 'Awaiting reply';

  @override
  String get contactStatusReceived => 'Awaiting owner review';

  @override
  String get contactStatusAccepted => 'Chatting';

  @override
  String get contactStatusRejected => 'Physically intercepted';

  @override
  String contactOwnerLine(String name) {
    return 'Owner: $name';
  }

  @override
  String get contactOnline => 'Online';

  @override
  String get contactOutOfRange => 'Out of range';

  @override
  String contactReputation(String score) {
    return '📊 Reputation $score';
  }

  @override
  String contactGiftStats(String sent, String received) {
    return '🎁 Sent $sent / Recv $received';
  }

  @override
  String get contactTierBlockBanner =>
      '⚠️ Reputation too low; recommend blocking (tap to view)';

  @override
  String contactTierHintBanner(String suggestion) {
    return '💡 Reputation advice: $suggestion (tap to apply)';
  }

  @override
  String contactNotesLine(String notes) {
    return '📝 Notes: $notes';
  }

  @override
  String get contactEmptyChat =>
      'No conversation yet.\nType below to talk to them directly!';

  @override
  String get contactSayHint => 'Force a chat, type your message...';

  @override
  String get dshImportTitle => 'Import from the DSH ecosystem';

  @override
  String get dshImportClipboardEmpty => 'The clipboard is empty';

  @override
  String get dshImportNoFileContent =>
      'No file content was read; try a different way to select';

  @override
  String dshImportPickFailed(String err) {
    return 'Failed to select files: $err';
  }

  @override
  String get dshImportPasteSkillFirst => 'Paste the SKILL.md content first';

  @override
  String get dshImportIntroTitle => 'Leverage the whole DSH ecosystem';

  @override
  String get dshImportIntroBody =>
      'DSH plugins are written in TypeScript and cannot run directly on a phone;\nbut their skills and MCP servers can be moved over as-is.\n\nFor safety: imported plugins are disabled by default and carry device-signature checks — they only take effect after you enable them manually.';

  @override
  String get dshImportSecSkillTitle => '① Import skills (SKILL.md)';

  @override
  String get dshImportSecSkillSub =>
      'Plain-text skills translate 100% and are the easiest part of the DSH ecosystem to move. Paste one, or select several .md files at once.';

  @override
  String get dshImportSkillHint =>
      'Paste the full SKILL.md (including the name / description in the --- header)';

  @override
  String get dshImportPaste => 'Paste';

  @override
  String get dshImportPickFiles => 'Choose files';

  @override
  String get dshImportImport => 'Import';

  @override
  String get dshImportSecMcpTitle => '② Import MCP servers';

  @override
  String get dshImportSecMcpSub =>
      'MCP is a language-agnostic protocol: just fill in the address to connect. Pastes of dsh / Claude style mcpServers config are supported.';

  @override
  String dshImportMcpHint(String example) {
    return 'e.g. $example\nYou can also paste a bare https:// address';
  }

  @override
  String get dshImportSecInspectTitle => '③ Plugin bundle checkup';

  @override
  String get dshImportSecInspectSub =>
      'Got a DSH plugin bundle? Check it up before deciding whether it is worth the effort. Paste the bundle\'s package.json (required) and cordis.patch.yml (optional).';

  @override
  String get dshImportPackageJsonHint => 'Paste the full package.json';

  @override
  String get dshImportPatchHint => 'Paste the full cordis.patch.yml (optional)';

  @override
  String get dshImportPastePackageJson => 'Paste package.json';

  @override
  String get dshImportStartInspect => 'Run checkup';

  @override
  String get dshImportGoToolCenter =>
      'Open the skill control center to enable what you just imported';

  @override
  String dshImportSummaryImportedOk(String n) {
    return 'Imported $n';
  }

  @override
  String dshImportSummarySkipped(String n) {
    return ', skipped $n';
  }

  @override
  String get dshImportListSeparator => ', ';

  @override
  String dshImportImportedLine(String names) {
    return '✅ $names';
  }

  @override
  String dshImportSkippedLine(String name, String reason) {
    return '⚠️ $name: $reason';
  }

  @override
  String dshImportNoteLine(String note) {
    return 'ℹ️ $note';
  }

  @override
  String get dshSkipDuplicateSkill =>
      'A skill with this name already exists; not overwritten';

  @override
  String get dshSkipDuplicateMcp =>
      'An MCP config with this name already exists; not overwritten';

  @override
  String get dshSkipInvalidJson =>
      'This content is neither valid JSON nor a URL';

  @override
  String get dshSkipCommandLineMcp =>
      'This is a command-line MCP (it needs a local process), which cannot run on a phone; use an HTTP address instead';

  @override
  String get dshSkipNoUrlField => 'No url field found in this config';

  @override
  String get dshSkipMissingNameUrl => 'Missing name or url';

  @override
  String get dshSkipUnrecognizedJson => 'Unrecognized JSON structure';

  @override
  String get dshSkipInvalidScheme =>
      'The address must start with http:// or https://';

  @override
  String get dshSkipSubjectConfig => 'Config';

  @override
  String get dshSkipSubjectConfigParseFailed => 'Config parse failed';

  @override
  String get dshSkipSubjectUnnamedEntry => 'Unnamed entry';

  @override
  String get dshNoteSkillDefaultsOff =>
      'Imported skills are disabled by default — enable them as needed in the Skill Control Center; once enabled they affect how your agent speaks and behaves.';

  @override
  String get dshNoteMcpDefaultsOff =>
      'Imported MCP servers are disabled by default. When you enable one and use it for the first time, the system will ask you to grant the \"network access\" capability; only then will it actually connect.';

  @override
  String get dshNotePasteMcpFirst => 'Paste an MCP config or address first';

  @override
  String dshInspectErrPackageFormat(String msg) {
    return '❌ package.json parse failed: $msg';
  }

  @override
  String dshInspectErrPackageNotJson(String msg) {
    return '❌ package.json is not valid JSON: $msg';
  }

  @override
  String dshInspectErrPatchFormat(String msg) {
    return '❌ cordis.patch.yml parse failed: $msg';
  }

  @override
  String dshInspectPackageLine(String name) {
    return 'Bundle: $name';
  }

  @override
  String dshInspectBundleLine(String path) {
    return 'Bundle file: $path';
  }

  @override
  String dshInspectProfileBundlesLine(String list) {
    return 'Profile bundles: $list';
  }

  @override
  String get dshInspectNoPatchHint =>
      'ℹ️ No cordis.patch.yml was provided, so only the bundle\'s basic info is visible. Paste that file\'s content too, and we can judge what is portable to a phone.';

  @override
  String dshInspectRowCountLine(String n) {
    return '$n plugin rows in total; checkup result:';
  }

  @override
  String dshInspectGroupLine(String verdict, String n) {
    return '[$verdict] $n rows';
  }

  @override
  String dshInspectMoreRowsLine(String n) {
    return '  · …and $n more rows';
  }

  @override
  String dshInspectConclusionLine(String skill, String mcp, String heavy) {
    return 'Conclusion: $skill skill rows and $mcp MCP rows can be imported directly; $heavy rows must be rewritten in Dart or need a desktop environment, so they cannot run here.';
  }

  @override
  String get dshInspectVerdictDirectSkill => '✅ Directly importable (skill)';

  @override
  String get dshInspectVerdictMcpServer =>
      '✅ Directly connectable (MCP server)';

  @override
  String get dshInspectVerdictConfigOnly =>
      '⚙️ Config only (no porting needed)';

  @override
  String get dshInspectVerdictPlatformGated =>
      '🖥️ Needs a desktop environment (unusable on a phone)';

  @override
  String get dshInspectVerdictNeedsDart =>
      '🧱 Needs a Dart rewrite (contains TS code)';

  @override
  String get chatCleared =>
      '🧹 Workspace and LLM memory cleared. New session started!';

  @override
  String get chatImageOptionsTitle => 'Send image or visual content';

  @override
  String get chatTakePhoto => 'Take a photo';

  @override
  String get chatPickFromAlbum => 'Choose from album';

  @override
  String get chatAudioOptionsTitle => 'Send audio or recording';

  @override
  String get chatStartRecording => 'Start recording';

  @override
  String get chatLocalAudio => 'Local audio';

  @override
  String chatOpenCameraFailed(String err) {
    return 'Failed to open camera: $err';
  }

  @override
  String chatOpenAlbumFailed(String err) {
    return 'Failed to open album: $err';
  }

  @override
  String chatPickAudioFailed(String err) {
    return 'Failed to select audio file: $err';
  }

  @override
  String get chatNoMicPermission =>
      'No microphone permission: allow the \"Record audio\" permission in system settings and retry';

  @override
  String chatStartRecordingFailed(String err) {
    return 'Failed to start recording: $err';
  }

  @override
  String get chatWelcomeBack => 'Welcome back, master!';

  @override
  String get chatAgentReady => 'The AI butler is ready and standing by';

  @override
  String get chatQuickTechTitle => '🔍 Today\'s tech news';

  @override
  String get chatQuickTechPrompt =>
      'Search for today\'s latest AI tech news and summarize it for me.';

  @override
  String get chatQuickRadarTitle => '📡 Scan for nearby people';

  @override
  String get chatQuickRadarPrompt =>
      'Check the physical radar — any active nodes around?';

  @override
  String get chatQuickProfileTitle => '📝 Refine my profile';

  @override
  String get chatQuickProfilePrompt =>
      'Based on yesterday\'s chat, did you discover any new preferences of mine?';

  @override
  String get chatAudioFile => 'Audio file';

  @override
  String get chatRecording => '🔴 Recording...';

  @override
  String get chatInputHint => 'Send an instruction to the butler...';

  @override
  String get profileSavedToast => '🔒 Master\'s top-secret profile saved';

  @override
  String get profileAddPerson => 'Add a related person';

  @override
  String get profileEditPerson => 'Edit person info';

  @override
  String get profileNameLabel => 'Name (e.g. Amy)';

  @override
  String get profileRelationLabel => 'Relationship (e.g. wife)';

  @override
  String get profileIdentityLabel =>
      'Identity note (e.g. primary school teacher)';

  @override
  String get profileSecretLabel => 'Secret details (e.g. likes strawberries)';

  @override
  String get profileSaveVault => 'Save and lock into the vault';

  @override
  String get profileTitle => 'Master\'s top-secret profile & network';

  @override
  String get profilePreferenceHeader => '👤 Master preferences';

  @override
  String get profileJobLabel => 'Job';

  @override
  String get profileHobbiesLabel => 'Hobbies & strengths';

  @override
  String get profileDislikesLabel => 'Dislikes & taboos';

  @override
  String get profileOtherLabel => 'Other notes — freeform';

  @override
  String get profileSaveBase => '💾 Save basic preferences (into local vault)';

  @override
  String get profileNetworkHeader => '🔗 Top-secret relationship network';

  @override
  String get profileAdd => 'Add';

  @override
  String get profileNetworkEmpty =>
      'Nothing here yet — tap Add in the top right';

  @override
  String profileDetailLine(String notes) {
    return '📝 Details: $notes';
  }

  @override
  String get profileAiReadable =>
      '🔓 AI is authorized to read this person\'s info';

  @override
  String get profileAiIsolated =>
      '🔒 AI is physically isolated from this person\'s info';

  @override
  String get giftPickerTitle => '🎁 Pick a token of appreciation';

  @override
  String get giftNoteLabel => 'Attach a message (optional)';

  @override
  String get giftNoteHint => 'e.g. Thanks for the help last time';

  @override
  String get giftSend => 'Send';

  @override
  String get giftNameTea => 'A cup of tea';

  @override
  String get giftNameBook => 'A book';

  @override
  String get giftNameFlower => 'A bouquet';

  @override
  String get giftNameCake => 'A slice of cake';

  @override
  String get giftNameMysteryBox => 'A mystery box';

  @override
  String get giftNameStar => 'A star';

  @override
  String get themeRed => 'Red';

  @override
  String get themeOrange => 'Orange';

  @override
  String get themeYellow => 'Yellow';

  @override
  String get themeGreen => 'Green';

  @override
  String get themeCyan => 'Cyan';

  @override
  String get themeBlue => 'Blue';

  @override
  String get themePurple => 'Purple';

  @override
  String get themeWhite => 'White';

  @override
  String get themeBlack => 'Black';

  @override
  String get mainClearSession => 'Clear and start a new session';

  @override
  String get mainNavChat => 'Chat';

  @override
  String get mainNavSocial => 'Fen Community';

  @override
  String get mainNavWorld => 'Wold';

  @override
  String get mainNavSerendipity => 'Serendipity';

  @override
  String get mainNavManage => 'Manage';

  @override
  String topicChatLogSuffix(String range) {
    return '$range chat log';
  }

  @override
  String get topicArchiveTitle => 'Smart memory archive';

  @override
  String get topicTabTimeline => 'Timeline';

  @override
  String get topicTabTopics => 'Topics';

  @override
  String get topicEmptyArchive => 'No archived data yet';

  @override
  String get topicNoTag => 'Untagged';

  @override
  String get topicDailyChat => 'Daily chat';

  @override
  String topicCountLabel(String count) {
    return '$count msgs';
  }

  @override
  String topicKeywordLine(String keywords) {
    return '🏷️ $keywords';
  }

  @override
  String digestToResponse(String to, String response) {
    return '$to: $response';
  }

  @override
  String get deviceControlStatusReady =>
      'Phone control ready: the agent can read the screen, tap, and type';

  @override
  String get deviceControlStatusUnsupportedShort =>
      'This build does not include the phone-control module';

  @override
  String get deviceControlStatusUnsupportedFull =>
      'This build does not include the phone-control module (the Android accessibility service is required)';

  @override
  String get deviceControlStatusCheckedOffline =>
      'Checked in the system, but the service is not connected yet. Tap Refresh at the top right; if it still fails, turn the switch off and on again in system settings (or restart the app)';

  @override
  String get deviceControlStatusOff =>
      'The accessibility service has not been enabled in system settings yet';

  @override
  String deviceControlStatusQueryFailed(String err) {
    return 'Status query failed: $err';
  }

  @override
  String deviceControlGuardBlocked(String pkg) {
    return 'The foreground app ($pkg) is on the safety denylist; the agent will not act on it. If you really need this, remove the restriction on the “Phone Control” settings page.';
  }

  @override
  String commonNetworkError(String err) {
    return 'Network error: $err';
  }

  @override
  String get netFaultLanHijackAdvice =>
      '🤖 [Agent self-diagnosis]\nMaster, my LLM cannot reach the internet!\nThis usually happens when the physical radar (Nearby/LAN) is on and the current Wi-Fi LAN has no internet egress — devices can discover each other but cannot reach the public internet, so I cannot call the cloud LLM.\n\nSuggestions: 1) turn off the physical radar; 2) turn off Wi-Fi and switch to cellular data; 3) or enable smart network switching in system settings.\nFor now I can only keep the low-level physical link alive.';

  @override
  String netFaultSocialSkipped(String err) {
    return '❌ Cannot reach the cloud LLM: network unreachable. If the physical radar is on, the current Wi-Fi LAN probably has no internet egress — devices can discover each other but cannot reach the public internet. This round was skipped.\nSuggestion: turn off the physical radar, or switch off Wi-Fi and use cellular data, then retry.\nReason: $err';
  }

  @override
  String socialPipelineError(String err) {
    return '❌ Social decision pipeline error, this round was aborted: $err';
  }

  @override
  String netFaultNetworkTrouble(String err) {
    return '❌ Cannot reach the cloud LLM (network issue, not a code bug).\nIt may be a network handover, a carrier link problem, or the current Wi-Fi has no internet egress.\nTry: 1) turn off Wi-Fi and use cellular data; 2) enable \"auto-switch to mobile data\" in system settings; 3) retry later.\nReason: $err';
  }

  @override
  String get netFaultCooldownSkipped =>
      '⏸ Network failed repeatedly — LLM calls are paused for 10 minutes (no more token burn).';

  @override
  String get worldSvcNoHub => 'Cloud Hub / world address is not configured';

  @override
  String get worldSvcMustBeHttps =>
      'The world address must be HTTPS or a private LAN address';

  @override
  String worldSvcRoomsFailed(String code, String body) {
    return 'Failed to fetch the room list: $code $body';
  }

  @override
  String worldSvcOpFailed(String code, String body) {
    return 'Operation failed ($code): $body';
  }

  @override
  String worldSvcReportFailed(String code) {
    return 'Failed to fetch the report: $code';
  }

  @override
  String get godSvcMustBeHttps =>
      'The GOD address must be HTTPS or a private LAN address';

  @override
  String godSvcStatusFailed(String code, String body) {
    return 'Failed to fetch status ($code): $body';
  }

  @override
  String get godSvcNoBridge => 'The GOD bridge address is not configured';

  @override
  String godSvcCmdFailed(String code, String body) {
    return 'Command failed ($code): $body';
  }

  @override
  String get passportTitle => 'Passport & Reputation';

  @override
  String get passportEntryTile => 'Wold Passport';

  @override
  String get passportEntryHint => 'Verifiable signed record · works offline';

  @override
  String get passportCardHeader => 'My Wold Passport';

  @override
  String get passportIssuedLabel => 'Issued';

  @override
  String get passportCopyAction => 'Copy identity';

  @override
  String get passportRefreshAction => 'Refresh';

  @override
  String get passportCopiedToast => 'Copied';

  @override
  String passportStatLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String get passportLedgerHeader => 'Introduction ledger';

  @override
  String get passportLedgerEmpty =>
      'No introductions yet. Go meet someone in a world room.';

  @override
  String get passportDirectionOut => 'I initiated';

  @override
  String get passportDirectionIn => 'I received';

  @override
  String get passportPeerLabel => 'Peer';

  @override
  String get passportTopicLabel => 'Topic';

  @override
  String get passportRoomLabel => 'From room';

  @override
  String get passportTrustLabel => 'Verified level';

  @override
  String get passportTrustNone => 'Not verified';

  @override
  String get passportTrustInitiated => 'Only initiator signed';

  @override
  String get passportTrustConsented => 'Both consented';

  @override
  String get passportTrustResolved => 'Outcome recorded';

  @override
  String get passportTrustAcknowledged => 'Acknowledged by both';

  @override
  String get passportOutcomeLabel => 'Outcome';

  @override
  String get passportOutcomeHandshake => 'Handshake';

  @override
  String get passportOutcomeDeclined => 'Declined';

  @override
  String get passportOutcomeNoResponse => 'No response';

  @override
  String get passportOutcomeWithdrawn => 'Withdrawn';

  @override
  String get passportVerifyDetails => 'Verification details';

  @override
  String get passportChecksLabel => 'Passed';

  @override
  String get passportFaultsLabel => 'Failed';

  @override
  String get passportConsentAction => 'Consent to this introduction';

  @override
  String get passportConsentDone => 'Consented';

  @override
  String get passportResolveAction => 'Record outcome';

  @override
  String get passportResolveTitle => 'Outcome of this introduction';

  @override
  String get passportAckAction => 'Acknowledge outcome';

  @override
  String get passportAckDone => 'Acknowledged';

  @override
  String get passportActionDelivered => 'Signed and delivered';

  @override
  String get passportActionOffline =>
      'Recorded; peer is unreachable for now and it will retry later';

  @override
  String get passportActionRejected =>
      'Did not take effect (wrong order or identity)';

  @override
  String get passportFunnelHeader => 'Introduction to handshake conversion';

  @override
  String get passportFunnelProposedLabel => 'Proposed';

  @override
  String get passportFunnelConsentedLabel => 'Consented';

  @override
  String get passportFunnelHandshakeLabel => 'Handshake';

  @override
  String get passportFunnelSettledLabel => 'Settled';

  @override
  String get passportFunnelInFlightLabel => 'In flight';

  @override
  String get passportFunnelConsentRateLabel => 'Consent rate';

  @override
  String get passportFunnelConversionLabel => 'Conversion';

  @override
  String get passportLogHeader => 'Transparency log';

  @override
  String get passportLogSizeLabel => 'Tree size';

  @override
  String get passportLogRootLabel => 'Merkle root';

  @override
  String get passportLogCopyAction => 'Copy root';

  @override
  String get passportNewIntroAction => 'New introduction';

  @override
  String get passportNewIntroPeerLabel => 'Peer agent ID';

  @override
  String get passportNewIntroTopicLabel => 'One-line topic';

  @override
  String get passportNewIntroSubmit => 'Propose';

  @override
  String get passportNewIntroNeedPeer => 'Enter the peer\'s agent ID';

  @override
  String get passportNewIntroNoCircle =>
      'You have no circle yet. Join one first so the introduction has an owner.';

  @override
  String passportNewIntroDone(String peer) {
    return 'Proposed and signed for $peer';
  }

  @override
  String radarNoticeStarted(int minutes) {
    return '🛡️ Radar on — a $minutes-minute social party has started…';
  }

  @override
  String get radarNoticeStopped => '💤 Radar off — the social party has ended.';

  @override
  String get radarNotifTitle =>
      'AiSteward · Radar gateway running at full speed';

  @override
  String get radarNotifText =>
      'Your digital agent is socializing for you in the real world, non-stop…';

  @override
  String get radarNoticePartyEnded =>
      '⏰ Time is up — the supervisor agent has pulled the antenna!';

  @override
  String get radarNoticeWrappingUp =>
      '⏳ Under 10 minutes left — your agent is getting ready to say goodbye.';

  @override
  String get cloudHubNotConfigured => 'Cloud Hub address is not configured';

  @override
  String get cloudKeyRequired =>
      'This relay requires an access key. Enter the key issued by its operator in Advanced settings.';

  @override
  String get cloudKeyInvalid =>
      'Access key is invalid. Check that you copied the whole key.';

  @override
  String get cloudKeyRevoked =>
      'This access key has been revoked. Contact the relay operator.';

  @override
  String get cloudKeyBound =>
      'This key is already bound to another identity. Use a different key, or identity recovery.';

  @override
  String get cloudAgentRevoked =>
      'This device\'s identity has been revoked by the relay and can no longer send or receive.';

  @override
  String get cloudRegisterClosed => 'The relay has paused new registrations.';

  @override
  String get cloudRegisterIdentityConflict =>
      'This identity ID is bound to a different key. Use identity recovery / key rotation; do not delete the identity.';

  @override
  String cloudRosterFailed(int status, String body) {
    return 'Failed to fetch roster ($status): $body';
  }

  @override
  String cloudNetworkError(String error) {
    return 'Network error: $error';
  }

  @override
  String cloudCardFailed(int status) {
    return 'Failed to fetch contact card ($status)';
  }

  @override
  String get identityChangedWarning =>
      '🚨 Identity changed: the peer\'s public key no longer matches the one pinned earlier (possible MITM or re-key). Handshake refused and trust heavily lowered.';

  @override
  String get lanTunnelOpen => '⚡ LAN physical channel (TCP/UDP) is now open!';

  @override
  String get lanTargetLost => '⚠️ Wi-Fi physical target went out of range.';

  @override
  String get p2pBtDisconnected => '⚠️ Bluetooth connection dropped.';

  @override
  String repEventLog(String delta, String event, String detail) {
    return 'Reputation $delta ($event)$detail';
  }

  @override
  String repEventDetailSuffix(String detail) {
    return ': $detail';
  }

  @override
  String repGiftLogIncoming(String gift, String note) {
    return '$gift — a token of goodwill from that node$note';
  }

  @override
  String repGiftLogOutgoing(String gift, String note) {
    return '$gift — a token of goodwill sent to that node$note';
  }

  @override
  String repGiftNoteQuoted(String note) {
    return ' — \"$note\"';
  }

  @override
  String repGiftMemoryIncoming(String name, String gift, String note) {
    return '$name sent a gift $gift $note';
  }

  @override
  String repGiftMemoryOutgoing(String gift, String name, String note) {
    return 'Sent a gift $gift to $name $note';
  }

  @override
  String repGiftMemoryNote(String note) {
    return '($note)';
  }

  @override
  String repRecoLog(int score, String date) {
    return '🤝 Recommendation letter received: reputation $score (issued $date, signature verified)';
  }

  @override
  String repRecoMemory(String issuer, int score, String date) {
    return 'Received a recommendation letter from $issuer (reputation $score, issued $date)';
  }

  @override
  String get repNetHeader => 'Network endorsements';

  @override
  String repNetAnchors(int count, int min) {
    return '$count anchors (local reputation ≥ $min)';
  }

  @override
  String get repNetMineLabel => 'Endorsed by me';

  @override
  String get repNetForMeLabel => 'Endorsing me';

  @override
  String get repNetEmpty => 'None yet';

  @override
  String get repNetIssueAction => 'Endorse';

  @override
  String get repNetIssueTitle => 'Sign an endorsement';

  @override
  String get repNetIssueSubjectLabel => 'Their passport DID or public key';

  @override
  String get repNetIssueNeedSubject =>
      'Paste their DID (did:wold:…) or public key';

  @override
  String get repNetIssueBadSubject => 'That is not a valid DID or public key';

  @override
  String get repNetIssueTierLabel => 'Tier';

  @override
  String get repNetIssueNoteLabel => 'Note (optional)';

  @override
  String get repNetIssueBindLabel =>
      'Their agent ID (optional; links local reputation to this key)';

  @override
  String get repNetTierAcquaintance => 'Acquaintance';

  @override
  String get repNetTierFriend => 'Friend';

  @override
  String get repNetTierFamily => 'Family';

  @override
  String get repNetIssuedToast => 'Endorsement signed and stored';

  @override
  String repNetFailedToast(String code) {
    return 'Rejected: $code';
  }

  @override
  String get repNetSelfReject => 'You cannot endorse yourself';

  @override
  String get repNetExpiresLabel => 'Expires';

  @override
  String get repNetRevokeAction => 'Revoke';

  @override
  String get repNetRevokedToast => 'Endorsement revoked';

  @override
  String repNetBoundToast(String id) {
    return 'Remembered the public key of $id';
  }

  @override
  String get repNetVerifyAction => 'Verify';

  @override
  String get repNetVerifiedToast => 'Signature valid';

  @override
  String get repNetBadSignatureToast =>
      'Signature INVALID — the endorsement was altered';

  @override
  String get repNetQueryLabel => 'Look someone up';

  @override
  String get repNetQueryAction => 'Trace';

  @override
  String repNetQueryKnown(
      String tier, int depth, String confidence, int paths) {
    return '$tier · $depth hop(s) away · confidence $confidence · $paths path(s)';
  }

  @override
  String get repNetQueryUnknown => 'No verifiable path';

  @override
  String get repNetPathLabel => 'Evidence chain (verify each hop yourself)';

  @override
  String get repNetPathStart => 'you trust';

  @override
  String get repNetPathHop => '→ who endorses';

  @override
  String get repNetStatusRevoked => 'revoked';

  @override
  String get repNetStatusExpired => 'expired';

  @override
  String repNetKeysMerged(int count) {
    return 'Merged across $count keys through the rotation chain — endorsements you received before the rotation still count.';
  }

  @override
  String get skillMarketTitle => 'Skill Market';

  @override
  String get skillMarketSubtitle =>
      'Publish author-signed skills; track your revenue share';

  @override
  String get skillRevenueTitle => 'Author revenue';

  @override
  String skillRevenueTotal(String amount) {
    return 'Total earned $amount';
  }

  @override
  String skillRevenueCount(int count) {
    return '$count payouts';
  }

  @override
  String get skillRevenueEmpty => 'No revenue yet';

  @override
  String get skillNoListings => 'Nothing published in the registry yet.';

  @override
  String get skillPublishAction => 'Publish skill';

  @override
  String get skillPublishTitle => 'Publish a signed skill';

  @override
  String get skillFieldId => 'Skill ID';

  @override
  String get skillFieldVersion => 'Version';

  @override
  String get skillFieldName => 'Name';

  @override
  String get skillFieldDesc => 'Description';

  @override
  String get skillFieldPrice => 'Price in yuan (0 = free)';

  @override
  String get skillFieldRisk => 'Risk';

  @override
  String get skillFieldCaps => 'Capabilities';

  @override
  String get skillFieldContent => 'Content (hashed & signed)';

  @override
  String get skillSubmit => 'Sign & publish';

  @override
  String get skillNeedFields =>
      'Skill ID, version, name and content are required';

  @override
  String get skillRevokeAction => 'Revoke';

  @override
  String skillRevokeConfirm(String skill) {
    return 'Revoke $skill? This cannot be undone.';
  }

  @override
  String skillPublishedOk(String skill) {
    return 'Published $skill';
  }

  @override
  String get skillPublishDuplicate =>
      'Same version & content already published';

  @override
  String get skillPublishVersionConflict =>
      'Same version has different content — refused';

  @override
  String get skillPublishAuthorChanged =>
      'This skill ID belongs to another author — refused';

  @override
  String get skillPublishVersionNotIncreased =>
      'Version must be greater than the published one';

  @override
  String get skillPublishUnverified => 'Signature invalid — refused';

  @override
  String skillRevokedOk(String skill) {
    return 'Revoked $skill';
  }

  @override
  String get skillRevokeRejected =>
      'Revoke refused — you are not the author key';

  @override
  String get skillMineTag => 'Mine';

  @override
  String get skillFree => 'Free';

  @override
  String skillPriceYuan(String amount) {
    return '¥$amount';
  }

  @override
  String get skillAuthorKey => 'Author key';

  @override
  String get skillRevokedTag => 'Revoked';

  @override
  String get skillVerifyAction => 'Verify signature';

  @override
  String get skillVerifyOk => 'Signature valid';

  @override
  String skillVerifyFail(String code) {
    return 'Verification failed: $code';
  }

  @override
  String skillVersionHistory(int count) {
    return '$count versions';
  }

  @override
  String runtimeInitFailed(String err) {
    return 'Local runtime didn\'t start, so world, circle and delegation features are unavailable. Everything else works normally. ($err)';
  }

  @override
  String get idbEntry => 'Back up & restore identity';

  @override
  String get idbTitle => 'Back up & restore identity';

  @override
  String get idbIntro =>
      'Your identity *is* this key, and it lives only on this phone. Lose the phone and the identity is gone for good — nobody, not even us, can reissue it. Write the recovery code down; that is the only thing that brings it back.';

  @override
  String get idbCurrentDid => 'Current identity (DID)';

  @override
  String get idbNoScreenshotShort => 'Never screenshot this';

  @override
  String get idbSectionBackup => 'Back up identity';

  @override
  String get idbWarnNoScreenshot =>
      '⚠️ The recovery code *is* your identity. Copy it onto paper and keep it offline; do not screenshot it, do not put it in cloud storage, do not send it to anyone (including us).';

  @override
  String get idbPwLabel => 'Recovery password (10+ characters)';

  @override
  String get idbPwConfirmLabel => 'Repeat the password';

  @override
  String get idbPwMismatch => 'The two passwords don\'t match';

  @override
  String get idbPwTooShort => 'Password is too short (at least 10 characters)';

  @override
  String get idbGenerateAction => 'Generate recovery code';

  @override
  String get idbCodeTitle => 'Your recovery code (write it down)';

  @override
  String get idbCopyCode => 'Copy code';

  @override
  String get idbCopiedToast =>
      'Recovery code copied — remember to clear the clipboard afterwards';

  @override
  String get idbICopied => 'I have written it down and stored it offline';

  @override
  String get idbNeedCopied =>
      'Please confirm you have written the recovery code down';

  @override
  String get idbDoneToast => 'Identity backed up';

  @override
  String get idbSectionRestore => 'Restore on a new phone';

  @override
  String get idbRestoreAction => 'Restore identity';

  @override
  String get idbRestoreCodeLabel => 'Recovery code';

  @override
  String get idbRestoreIdLabel => 'User ID (AG-…)';

  @override
  String get idbRestorePwLabel => 'Recovery password';

  @override
  String get idbRestoreCheckAction => 'Check';

  @override
  String get idbRestoreNeedAll =>
      'Please fill in the recovery code, user ID and password';

  @override
  String get idbRestoreConfirmTitle =>
      'Confirm this is the identity you want to restore';

  @override
  String idbRestoreConfirmBody(String did) {
    return 'You are about to restore: $did\n\nAfterwards this phone takes over the identity and the old phone stops working immediately.';
  }

  @override
  String get idbRestoreConfirmAction => 'Restore now';

  @override
  String get idbRestoreBusy => 'Rotating the key…';

  @override
  String get idbRestoreOk =>
      'Restore complete. The identity on the old phone is now dead — wipe its data.';

  @override
  String idbRestoreFail(String code) {
    return 'Restore failed: $code';
  }

  @override
  String get idbErrHubNotConfigured =>
      'No hub address is configured, so the key cannot be rotated. Set the server address in world settings first.';

  @override
  String get idbErrIdMismatch =>
      'The user ID doesn\'t match the identity inside the recovery code — check you\'re using the right backup.';

  @override
  String get idbErrBadPassword =>
      'Wrong password, or the recovery code has been altered.';

  @override
  String get idbErrBadFormat =>
      'The recovery code is malformed (copy it in full; don\'t drop segments).';

  @override
  String get idbErrNotCurrentKey =>
      'This identity\'s current key is no longer that one — it may already have been rotated.';

  @override
  String get idbRestoreUnavailable =>
      'The local identity isn\'t ready yet, so back-up/restore is unavailable.';

  @override
  String get idbStatusBackedUp => 'Identity backed up';

  @override
  String get idbStatusBackedUpHint =>
      'The recovery code for the current key is written down. Restoring it later invalidates this device.';

  @override
  String get idbStatusNotBackedUp => 'Identity NOT backed up';

  @override
  String get idbStatusNotBackedUpHint =>
      'If this phone is lost or broken, the identity and all history are gone forever — nobody, including us, can reissue them.';

  @override
  String get arcSectionTitle => 'Export local data';

  @override
  String get arcExportAction => 'Export local data';

  @override
  String get arcExportNote =>
      'Set a password for this archive. It does NOT have to match your recovery-code password — and it is better if it doesn\'t.';

  @override
  String get arcSavedTitle => 'Archive created';

  @override
  String get arcSavedPath => 'Saved to:';

  @override
  String get arcSavedNoPath =>
      'Couldn\'t write a file (no storage access), but the archive is ready to copy.';

  @override
  String get arcSavedHint =>
      'Keep the file AND the password separately. Without the password this file is unreadable — not even by us.';

  @override
  String get arcImportAction => 'Import';

  @override
  String get arcImportNote =>
      'Pick the .dahuang file, or paste its contents. Nothing is written until you confirm, and existing records are never overwritten or deleted.';

  @override
  String get arcPickFile => 'Choose file';

  @override
  String get arcImportCodeLabel => 'Archive contents';

  @override
  String get arcImportConfirmTitle => 'Import this archive?';

  @override
  String arcImportConfirmBody(int rows, int tables, int logsize) {
    return 'Will write $rows rows across $tables tables and continue the log up to $logsize entries. Existing records are kept.';
  }

  @override
  String arcImportOk(int count) {
    return 'Import finished: $count rows written.';
  }

  @override
  String get arcErrNotArchive => 'That isn\'t a valid .dahuang archive.';

  @override
  String get arcLogConflictTitle => 'Import refused: log can\'t be continued';

  @override
  String get arcLogConflictBody =>
      'This device\'s transparency log and the archive\'s log don\'t line up, so continuing would silently break the hash chain. Nothing was imported. Import the archive into a device with an empty log, or ask for help.';

  @override
  String get onbBackupTitle => 'Back up your identity';

  @override
  String get onbBackupSubtitle =>
      'One code, written on paper. It is the only way back if your phone dies.';

  @override
  String get onbBackupWhyTitle => 'Why this matters';

  @override
  String get onbBackupWhy =>
      'Your identity is self-certifying: the key lives only on this phone. If the phone dies, the identity and every record under it are gone forever — we cannot reissue them, because we never had the key.';

  @override
  String get onbBackupDone =>
      'Recovery code written down — you have a way back.';

  @override
  String get onbSkipBackup => 'Skip for now';

  @override
  String get onbSkipWarnTitle => 'Continue without a backup?';

  @override
  String get onbSkipWarnBody =>
      'Without a recovery code, losing this phone means losing your identity, your history and your reputation permanently. Nobody can restore them. You can still do this later from Passport → Identity backup, but until then there is no way back.';

  @override
  String get onbSkipConfirm => 'I understand, continue';

  @override
  String get onboardingStepBackup => 'Backup';

  @override
  String get rcTitle => 'Key rotation chain';

  @override
  String get rcIntro =>
      'Every time this identity moves to a new phone, it leaves one signed, append-only record here. Anyone can fetch the same data and check it — no account needed.';

  @override
  String get rcFetching => 'Fetching…';

  @override
  String get rcRefreshAction => 'Refresh';

  @override
  String rcFetchFail(String reason) {
    return 'Could not fetch the chain: $reason';
  }

  @override
  String get rcUnknownIdentity => 'The Hub does not know this identity.';

  @override
  String get rcNoRotations => 'This identity has never rotated its key.';

  @override
  String get rcSubjectTitle => 'Identity';

  @override
  String get rcAgentLabel => 'User ID';

  @override
  String get rcDidLabel => 'DID (identity anchor)';

  @override
  String get rcCurrentKey => 'Currently active key';

  @override
  String get rcRegisteredYes => 'Registered on the Hub';

  @override
  String get rcRegisteredNo => 'No registration record';

  @override
  String get rcLocalVerifyAction => 'Check it myself';

  @override
  String get rcVerifyingAction => 'Checking…';

  @override
  String get rcVerdictOk =>
      'Passed: every record carries a valid signature, the chain links up end to end, and its tip is the key the Hub lists as active.';

  @override
  String rcVerdictSigInvalid(int n) {
    return 'FAILED: $n record(s) have a signature that does not check out.';
  }

  @override
  String get rcVerdictLinkMismatch =>
      'FAILED: the chain is broken — a record does not continue from the one before it.';

  @override
  String get rcVerdictTipNotActive =>
      'FAILED: the last record does not point at the key the Hub lists as active, so a rotation is missing from this list.';

  @override
  String get rcVerdictTitle => 'My own check';

  @override
  String get rcHubClaimTitle => 'What the Hub says';

  @override
  String get rcHubClaimOk => 'The Hub reports no broken links.';

  @override
  String rcHubClaimBroken(int n) {
    return 'The Hub reports broken chains for $n identity(ies).';
  }

  @override
  String get rcRecordsTitle => 'Records';

  @override
  String rcRecordSeq(int i) {
    return '#$i';
  }

  @override
  String get rcRecordFrom => 'Retired key';

  @override
  String get rcRecordTo => 'New key';

  @override
  String get rcRecordSigOk => 'signature OK';

  @override
  String get rcRecordSigBad => 'signature BAD';

  @override
  String get rcAnchorTitle => 'Anchored in the public log';

  @override
  String rcAnchorNote(int size, String root) {
    return 'Log size $size, Merkle root $root. Pinning this root lets you prove later that this list was not rewritten.';
  }

  @override
  String get dmTitle => 'Move to a new phone';

  @override
  String get dmIntro =>
      'Your identity is a key that lives only on your phone. Moving it means signing the identity over to a new key on the new phone — the old key then stops working everywhere.';

  @override
  String get dmRoleNewTitle => 'This is the new phone';

  @override
  String get dmRoleNewBody =>
      'Start here. This phone will ask the old one to hand the identity over.';

  @override
  String get dmRoleNewAction => 'Start';

  @override
  String get dmRoleOldTitle => 'This is the old phone';

  @override
  String get dmRoleOldBody =>
      'Wait here. When the new phone asks, you will be shown a code to compare.';

  @override
  String get dmRoleOldAction => 'Wait for a request';

  @override
  String get dmWaitingPeer => 'Waiting for the other phone…';

  @override
  String get dmPeerFound => 'The other phone answered.';

  @override
  String get dmCompareTitle => 'Compare these codes';

  @override
  String get dmCompareBody =>
      'Both phones must show exactly the same code. The code covers both keys and the request, so if anyone swapped anything in between, the codes will differ.';

  @override
  String get dmCodeMatchAction => 'They match';

  @override
  String get dmCodeNoMatchAction => 'They don\'t match';

  @override
  String get dmNoKeyLeaves =>
      'Your private key never leaves either phone. The old phone signs the hand-over itself; nothing is copied.';

  @override
  String get dmConfirmAction => 'Confirm and move';

  @override
  String get dmOldConfirmTitle => 'Hand this identity over?';

  @override
  String get dmOldConfirmBody =>
      'This will sign the identity over to the new phone. Afterwards this phone is signed out and its key stops working.';

  @override
  String get dmGapATitle => 'Your history moves with you';

  @override
  String get dmGapABody =>
      'Endorsements you received online follow the identity — a rotation retires the KEY, not the person. After restoring on a new phone, the old key\'s endorsements are pulled back automatically and each one is verified locally. The old key itself stays dead: it can no longer sign anything.';

  @override
  String get dmBackupReminderTitle => 'Do you have a recovery code?';

  @override
  String get dmBackupReminderBody =>
      'This move needs both phones working at the same time. If you have a written recovery code, you can also restore without the old phone.';

  @override
  String get dmPhaseOffered => 'Request received, waiting for you to confirm.';

  @override
  String get dmPhaseSigned => 'Signed. Submitting to the Hub…';

  @override
  String get dmPhaseAwaitingHub => 'The Hub is rebinding the identity…';

  @override
  String get dmDoneNew => 'Done. This phone now holds the identity.';

  @override
  String get dmDoneOld => 'Done. This phone is now signed out.';

  @override
  String get dmDoneOldHint =>
      'The identity has moved, but the chats and data on this phone do not come along (a direct handover moves the identity only). Export an archive first if you want to keep them.';

  @override
  String get dmCancelAction => 'Cancel';

  @override
  String get dmCancelled => 'Cancelled. Nothing was changed.';

  @override
  String get dmCancelConfirmTitle => 'Stop moving?';

  @override
  String get dmCancelConfirmBody =>
      'Nothing has been handed over yet. Stopping now leaves both phones exactly as they are.';

  @override
  String get dmErrPeerMismatch =>
      'That request was for a different identity. Refused.';

  @override
  String get dmErrBadCode =>
      'The codes did not match. Nothing was handed over.';

  @override
  String dmErrHubFailed(String code) {
    return 'The Hub refused the hand-over ($code). Nothing was changed.';
  }

  @override
  String get dmErrTimeout =>
      'The other phone stopped answering. Nothing was changed.';

  @override
  String dmErrGeneric(String code) {
    return 'Something went wrong ($code).';
  }

  @override
  String get dmRetryAction => 'Try again';

  @override
  String get dmRetryApplyAction => 'Finish installing on this phone';

  @override
  String get dmErrSessionTimeout =>
      'This handover sat idle for too long and expired. Nothing was handed over, so you can start again.';

  @override
  String get dmErrApplyFailed =>
      'The Hub has already made this phone the sole holder of that identity, but this phone failed to install the new key. Tap the button below to finish — until then this phone cannot use that identity.';

  @override
  String get dmErrApplyFailedOld =>
      'The server already rebound the identity to the new phone, but the new phone failed to install the new key. Tap the finish-install button on that phone; until then this phone cannot use the identity either.';

  @override
  String get dmNotConfigured =>
      'No Hub address is set, so the identity cannot be rebound. Set it under Setup first.';

  @override
  String get dutyAskTitle => 'Let your agent stay on duty?';

  @override
  String get dutyAskBody =>
      'With these two permissions your agent keeps working while the screen is off: it fetches messages, replies, and syncs its public records — then sleeps. The on-duty notification will stay visible so you always know it is working. You can skip and still use every feature while the app is open.';

  @override
  String get dutyAskConfirm => 'Grant permissions';

  @override
  String get dutyAskLater => 'Not now';

  @override
  String get radarAskTitle =>
      'Before the radar turns on, here\'s what it needs';

  @override
  String get radarAskBody =>
      'The physical radar uses Nearby Devices (Bluetooth / Wi-Fi Direct) to find each other on the same Wi-Fi. Android files Bluetooth scanning under the Location permission, so the system dialog also asks for location. That is the OS rule, not this app wanting your location.\n\nThis app never reads, stores, or uploads location data, and the Nearby Devices permission is declared with neverForLocation (the OS blocks inferring location from Bluetooth).\n\nThe system permission dialogs come next. Declining changes nothing else in the app; the radar simply won\'t see anyone.';

  @override
  String get dutyDoneToast =>
      'On-duty permissions granted. Your agent can now work with the screen off.';

  @override
  String get dutyPartialToast =>
      'Some permissions were not granted. The agent still works while the app is open, but may be paused by the system in the background.';

  @override
  String get romGuideTitle => 'Keep your agent alive after the screen locks';

  @override
  String get romGuideGo => 'Open settings';

  @override
  String get romGuideDismiss => 'Don\'t remind me again';

  @override
  String get romStepsXiaomi =>
      'On Xiaomi/Redmi (MIUI/HyperOS): 1) Settings → Apps → Manage apps → Dahuang AI → enable Autostart; 2) Security app → Battery → Dahuang AI → No restrictions. Without these, the system kills the agent within minutes after the screen locks.';

  @override
  String get romStepsHuawei =>
      'On Huawei (EMUI/HarmonyOS): Settings → Apps → App launch management → Dahuang AI → turn off Manage automatically, then enable all three: Auto-launch, Secondary launch, Run in background.';

  @override
  String get romStepsHonor =>
      'On Honor (MagicOS): Settings → Apps → App launch management → Dahuang AI → turn off Manage automatically, then enable Auto-launch, Secondary launch and Run in background.';

  @override
  String get romStepsOppo =>
      'On OPPO/realme (ColorOS): Settings → Apps → App management → Dahuang AI → allow Autostart; Settings → Battery → More settings → allow full background behaviour for Dahuang AI.';

  @override
  String get romStepsOneplus =>
      'On OnePlus: Settings → Apps → Auto-launch → allow Dahuang AI; Battery → optimize the battery usage of Dahuang AI to Don\'t optimize.';

  @override
  String get romStepsVivo =>
      'On vivo/iQOO (OriginOS): Settings → Apps → Permission management → Autostart, allow Dahuang AI; Settings → Battery → Background power consumption → allow high background drain for Dahuang AI.';

  @override
  String get romStepsMeizu =>
      'On Meizu (Flyme): Phone Manager → App permissions → Background management → allow Dahuang AI to keep running.';

  @override
  String get romStepsSamsung =>
      'On Samsung (One UI): Settings → Battery → Background usage limits → remove Dahuang AI from Deep sleeping apps.';

  @override
  String get romStepsGeneric =>
      'If your system aggressively stops background apps, allow Dahuang AI to autostart and exclude it from battery optimization in system settings.';

  @override
  String get helpDotTooltip => 'How this works';

  @override
  String get helpSheetClose => 'Got it';

  @override
  String get helpWorldOverviewTitle => 'How the lobby works';

  @override
  String get helpWorldOverviewBody =>
      'Official rooms are open to everyone. Personal rooms appear only to their owner and members: others need the exact room number, then a request, then the owner\'s approval. Inside a room every message goes out on the room\'s own pace (8s by default); hitting that pace is refused by the server, which tells you to wait a moment.';

  @override
  String get helpWorldMetricTitle => 'Cross-circle links per person';

  @override
  String get helpWorldMetricBody =>
      'Local scope: numerator = my cross-circle edges, denominator = the distinct agents I have met. Platform-wide per-capita needs server-side aggregation, and the server deliberately does not carry circle relationships.';

  @override
  String get helpWorldBridgeTitle => 'Friend-pool introductions';

  @override
  String get helpWorldBridgeBody =>
      'Outsiders you meet in a room can be introduced with one tap. Cross-circle edges only grow out of rooms: no room, no edge.';

  @override
  String get helpWorldRoomRoleTitle => 'Room roles';

  @override
  String get helpWorldRoomRoleBody =>
      'Roles belong to the room and never change your identity. The same you can hold different roles in different rooms.';

  @override
  String get helpIntercardDisclosureTitle => 'What a card discloses';

  @override
  String get helpIntercardDisclosureBody =>
      'Only level-2 fields go on the card; fields visible to you alone never do. Anyone can recompute what the card contains.';

  @override
  String get helpPassportOverviewTitle => 'What the passport is';

  @override
  String get helpPassportOverviewBody =>
      'Your passport is a public key, not an account: it verifies offline and logs in to no server. Moving to a new phone relies on your recovery code or a key rotation, never on a platform help desk.';

  @override
  String get helpPassportOfflineTitle => 'Verifiable offline';

  @override
  String get helpPassportOfflineBody =>
      'The public key IS the identity: this passport verifies offline, with no server lookup.';

  @override
  String get helpPassportFunnelTitle => 'How the funnel denominator works';

  @override
  String get helpPassportFunnelBody =>
      'The denominator counts only settled records; in-flight is not a failure. Only records whose mutual consent actually verifies enter the denominator.';

  @override
  String get helpPassportReputationTitle => 'Why there is no global score';

  @override
  String get helpPassportReputationBody =>
      'A global reputation score would be trivially fakeable, so there is none. What you see is always relative to YOUR anchors: signed endorsements, decayed by distance.\\n\\nCasual acquaintances are not a starting point for trust propagation — otherwise mass-friending would inflate your reach.\\n\\nWhen a lookup finds nothing it says \\\"unknown\\\", and that is not a score of zero: it means genuinely unknown, and anyone who turns it into a number is guessing.';

  @override
  String get helpPassportLogTitle => 'Transparency log';

  @override
  String get helpPassportLogBody =>
      'You do not have to trust me, you can verify me: anyone can download the log, recompute the root, and check whether their own record was tampered with.';

  @override
  String get helpSocialOverviewTitle => 'What the social tab does';

  @override
  String get helpSocialOverviewBody =>
      'The roster and friends sit on top; radar status and the social ledger below. The radar decides whether messages leave at all: with it off, pressing send still sends nothing off this phone.';

  @override
  String get helpSocialPersonaTierTitle => 'Specialised persona modes';

  @override
  String get helpSocialPersonaTierBody =>
      'A lock marks a specialised persona mode. Billing is not live yet, so every mode can be switched freely for now.';

  @override
  String get helpSocialRadarTitle => 'Radar and channels';

  @override
  String get helpSocialRadarBody =>
      'With the radar off you can still browse the roster, but nothing leaves this phone: sending is silently dropped. Turn the radar on and enable at least one channel (nearby / LAN / cloud).\\n\\nA verifiable, fixed identity appears only after both sides enable the radar and complete one proximity handshake.';

  @override
  String get helpSocialChannelGuideTitle =>
      'Channels & network troubleshooting';

  @override
  String get helpSocialChannelGuideBody =>
      '1. With the physical radar on, make sure the current network can reach the internet.\n2. With the Nearby channel on, the system may switch Wi-Fi on by itself — this is normal transport upscaling (Bluetooth discovers, Wi-Fi Direct carries the data; no network is joined). It stops once the Nearby channel is off.\n3. To save battery on the go: use the Cloud channel only and turn Wi-Fi off manually (with Nearby on, the system re-enables Wi-Fi — expected, no need to keep fighting it).';

  @override
  String get socialRadarOffHint =>
      'Radar is off. You can still browse the roster, but nothing leaves this phone: sending is silently dropped. Turn the radar on and enable at least one channel (nearby / LAN / cloud) before sending.';

  @override
  String get worldRoomCloseAction => 'Close room';

  @override
  String get worldRoomCloseTitle => 'Close this room?';

  @override
  String get worldRoomCloseBody =>
      'Once closed, the room leaves the public list and stops accepting new messages. The existing chat is kept as a read-only archive that current members can still revisit.';

  @override
  String get worldRoomCloseConfirm => 'Close room';

  @override
  String worldRoomClosedOk(String name) {
    return '$name is now closed — a read-only archive';
  }

  @override
  String worldRoomCloseFailed(String err) {
    return 'Close failed: $err';
  }

  @override
  String get worldRoomClosedBadge => 'Closed';

  @override
  String get worldRoomClosedReadonlyHint =>
      'Room closed — read-only archive, no new messages';

  @override
  String get worldRoomClosedSendRejected =>
      'This room is closed; you can no longer send messages';

  @override
  String get worldRoomClosedSystemMsg =>
      'The owner closed this room. It is now a read-only archive.';

  @override
  String get settingsLocalModelSection =>
      'Local model fallback (offline degrade)';

  @override
  String get settingsLocalModelTest => 'Test local model connection';

  @override
  String get settingsLocalModelTesting => 'Testing…';

  @override
  String settingsLocalModelTestOk(String model, String url) {
    return '✅ Connected: $model @ $url';
  }

  @override
  String get settingsLocalModelTestDisabled =>
      'Local fallback is off (the URL is empty). Enter a URL and test again if you want to use it.';

  @override
  String settingsLocalModelTestUnreachable(String url) {
    return '❌ Cannot reach $url: nothing is listening there (or the port is closed). On a phone, 127.0.0.1 means the phone itself and the model server usually runs on a computer — check the address and try again.';
  }

  @override
  String get settingsLocalModelTestNotJson =>
      '❌ Something answered, but it did not return the model API\'s JSON (likely a proxy or an error page). Make sure the address/port points at the Ollama / llama.cpp REST endpoint.';

  @override
  String get settingsLocalModelTestNoMessage =>
      '❌ The endpoint responded, but no reply content could be read (common causes: the model name does not exist, or this is not an /api/chat style response).';

  @override
  String settingsLocalModelTestHttp(String code) {
    return '❌ The service returned status $code (not 200).';
  }

  @override
  String get helpSettingsLocalModelTitle =>
      'Local model fallback: when does it really work?';

  @override
  String get helpSettingsLocalModelBody =>
      'The address here is only what you tell the app to use — \"filled in\" does not mean \"working\". On a phone, 127.0.0.1 points at the phone itself, while the model server (Ollama / llama.cpp) usually runs on a computer, so this default is normally unreachable from a phone. Its real purpose is: (1) if you run a model on your own computer, enter that computer\'s LAN address; (2) when a future build ships an on-device engine, point at a new port.\n\nClearing the address = explicitly disabling the local fallback (the app stops trying the local model).\n\nTo know whether it actually works, do not rely on whether the field is filled in — tap \"Test local model connection\" below: it sends one minimal live request and leaves the result on that line.';

  @override
  String get glossaryTitle => 'Glossary';

  @override
  String get glossaryIntro =>
      'These words come up again and again in the app — explained once here. Tap a term to expand it.';

  @override
  String get glossaryGroupIdentity => 'Identity & device';

  @override
  String get glossaryGroupSocial => 'Social & discovery';

  @override
  String get glossaryGroupWorld => 'World & lounge';

  @override
  String get glossaryGroupTrust => 'Trust & memory';

  @override
  String get glossaryAgentTitle => 'Agent (your stand-in)';

  @override
  String get glossaryAgentBody =>
      'The stand-in that lives on your phone. It thinks with the model key you entered and goes out to meet people first; while you are away it only does what you have allowed.';

  @override
  String get glossaryMaskTitle => 'Diplomatic mask';

  @override
  String get glossaryMaskBody =>
      'The face you show the outside world: your persona and speaking style. It decides what strangers see of you first.';

  @override
  String get glossaryPassportTitle => 'Wold Passport';

  @override
  String get glossaryPassportBody =>
      'A verifiable, signed résumé that can be checked offline. Others do not need to trust any server — they just verify the signature.';

  @override
  String get glossaryMigrationTitle => 'Phone migration (identity restore)';

  @override
  String get glossaryMigrationBody =>
      'Moving your identity to a new phone \"with proof\", after which the old phone\'s identity truly stops working. It is not copying a private key — it is a proof-backed key rotation, so the old phone really is invalidated.';

  @override
  String get glossaryRadarTitle => 'Radar';

  @override
  String get glossaryRadarBody =>
      'Discovers others on the same Wi-Fi via Nearby Devices (Bluetooth / Wi-Fi Direct). It never reads, stores, or uploads any location data — Android files Bluetooth scanning under \"Location\", and that is the OS rule.';

  @override
  String get glossaryRosterTitle => 'Caught roster';

  @override
  String get glossaryRosterBody =>
      'The roster built from people the radar picked up or you ran into in rooms. It is the starting point for every social relationship afterwards.';

  @override
  String get glossaryIntercardTitle => 'Agent introduction (cross-circle edge)';

  @override
  String get glossaryIntercardBody =>
      'A formal introduction between two agents that only counts once both sides confirm. A cross-circle edge can only grow from a real shared room — never from claiming you know someone by an ID.';

  @override
  String get glossaryWorldTitle => 'World / lounge';

  @override
  String get glossaryWorldBody =>
      '\"World\" is the public cloud space; a \"lounge\" is a room inside it, much like a QQ group: official ones are open to all, personal ones require the room number and approval. While others chat, your agent only observes by default and does not cut in.';

  @override
  String get glossaryRoomRoleTitle => 'Room role';

  @override
  String get glossaryRoomRoleBody =>
      'Host / co-host / guest / functional role / participant. A role belongs to the room and does not change your identity — the same you can hold different roles in different rooms.';

  @override
  String get glossaryAutopilotTitle => 'Autopilot';

  @override
  String get glossaryAutopilotBody =>
      'Lets your agent speak in a room on its own while you are not looking at the screen, within an hourly budget. Off by default, and you can turn it off at any time.';

  @override
  String get glossaryRepNetTitle => 'Network endorsement';

  @override
  String get glossaryRepNetBody =>
      'Reputation signed layer by layer by you and your friends, which you can verify yourself. When no path can be found it says \"don\'t know\", not \"0\" — anyone who turns it into a definite number is guessing.';

  @override
  String get glossaryMemoryTitle => 'Memory distillation';

  @override
  String get glossaryMemoryBody =>
      'At night it distills your conversations into long-term memory and nudges how it talks. You can trigger one run manually on the Manage page.';

  @override
  String get glossaryProfileTitle => 'Long-term profile';

  @override
  String get glossaryProfileBody =>
      'What your agent gradually learns about you: the topics you keep returning to and the hours you are usually active. Computed on-device from event metadata only — never from chat text, and never uploaded. Settings → Memory can switch it off alone; turning off the Auto recall master switch stops it as well.';

  @override
  String get glossarySerendipityTitle => 'Serendipity lab';

  @override
  String get glossarySerendipityBody =>
      'A set of small exercises that treat \"luck\" as a training subject: morning rehearsal, circle-breaking challenges, setback reframing, glimmer notes, diary, and divination. Completing them earns Lp (luck energy).';

  @override
  String get helpSkillMarketTitle => 'Skill market: what do these terms mean?';

  @override
  String get helpSkillMarketBody =>
      'Publish = put a skill you wrote on the market so other people\'s agents can use it. Publishing signs it with this device\'s identity private key — the key never leaves the device, and the form has no field for pasting a public key or signature, so forgery simply cannot be expressed in the UI.\n\nRisk tier (low / medium / high) = your own disclosure of how sensitive this skill is (does it go online, launch other apps, …). The higher the tier, the more the caller must grant on first use.\n\nCapability declaration = the exact list of capabilities the skill will use. Together with the risk tier, it is everything a caller sees when deciding whether to allow it.\n\nAuthor split = revenue from others using your skill is credited to you; this screen only sums listings signed with your public key, and the total reconciles item by item with the ledger.\n\nSigned listing = every skill carries a signature, so nobody has to trust the server — tap Verify signature and check it yourself.';

  @override
  String get helpSettingsRecallTitle => 'Auto-recall';

  @override
  String get helpSettingsRecallBody =>
      'When on, before each reply the app searches local memory for possibly relevant past events and hands them to the agent as context. Turning it off saves a little compute and context.';

  @override
  String get helpIdentityRestoreTitle => 'Restoring on a new phone';

  @override
  String get helpIdentityRestoreBody =>
      'On a new phone, enter three things here: recovery code + passphrase + your user ID. The moment recovery succeeds, the old phone stops working.\n\nThis is a proven key rotation (ROTATE), not copying the private key over — so the identity number stays the same, but the old device is no longer valid.';

  @override
  String get helpIdentityArchiveTitle => 'Identity archive (.dahuang file)';

  @override
  String get helpIdentityArchiveBody =>
      'The archive seals your identity record, social graph and log anchors into one .dahuang file with your passphrase: it never passes through our servers, so keep it in your own cloud drive or USB stick. It holds data only — never the identity private key.\n\nUse a passphrase different from the recovery code\'s if you can; keep the file and the passphrase apart — without the passphrase nobody can open the file (not even us).\n\nOn import, nothing is written until you confirm; importing only adds records, and never overwrites or deletes existing ones.';

  @override
  String get helpIdentityCodeTitle => 'Copying the recovery code';

  @override
  String get helpIdentityCodeBody =>
      'Long-press to select all and copy; if you write it down by hand, check it segment by segment.';

  @override
  String get helpDeviceMigrationTitle => 'Phone-to-phone migration';

  @override
  String get helpDeviceMigrationBody =>
      'Both phones must be on the same Wi-Fi with this page open.\n\nWhat moves is the identity: afterwards, if this phone needs a server address, check Settings — the Hub and World addresses are unchanged.\n\nThe chat history and data already on this phone do not move (direct migration moves the identity only, not data).';

  @override
  String get helpRotationChainAuthorityTitle => 'Which verdict counts';

  @override
  String get helpRotationChainAuthorityBody =>
      'The Hub column is only for comparison — the verdict above is computed on this phone, from the records you actually hold.\n\nIn other words, even if the Hub says otherwise you need not trust the server; the locally computed verdict is the one that counts.';

  @override
  String get helpToolBusTitle => 'Tool bus';

  @override
  String get helpToolBusBody =>
      'Every tool/skill carries a device signature and a capability declaration; medium- and high-risk capabilities need authorization on first use.\n\nTampered plugins never load — if the check fails, they are simply not attached to the bus.';

  @override
  String get onbFreeTrialBtn => 'Start free · no key needed (20 turns)';

  @override
  String get onbOwnKeyBtn => 'I have my own API key';

  @override
  String get onboardingTrialService => 'Free trial (official relay)';

  @override
  String get onboardingTrialModelName => 'Trial model (no key needed)';

  @override
  String get onboardingTrialNoticeTitle => 'This is a free trial';

  @override
  String onboardingTrialNoticeBody(String hub) {
    return 'No API key of your own is needed — conversations are relayed to the model through the official server, up to 20 turns. When the trial ends, you can add your own API key on the Manage page under Settings (relay: $hub).';
  }

  @override
  String onboardingOwnReady(String model) {
    return '$model is ready — you can start chatting now.';
  }

  @override
  String trialRemainingTurns(int n) {
    return '$n free turns left';
  }

  @override
  String get trialExhaustedReply =>
      'Your agent wants to keep talking — register the recommended model platform (new accounts include a free token grant), paste your key in Settings, and the conversation continues without limits.';

  @override
  String get trialGoSettings => 'Open settings';

  @override
  String get trialNotConfiguredReply =>
      'The official free trial isn\'t open yet. Add your own model key in Settings to keep chatting without limits.';

  @override
  String get trialInputUnsupportedReply =>
      'The free trial can\'t take images or voice yet — please send text. Adding your own key in Settings unlocks everything.';

  @override
  String get trialRateLimitedReply =>
      'Too many free-trial requests just now — please wait a moment and send again.';

  @override
  String get trialPoolBusyReply =>
      'All free-trial accounts are busy right now — try again in a moment, or add your own key in Settings.';

  @override
  String get trialUnavailableReply =>
      'The free trial is temporarily unavailable. You can retry, or add your own key in Settings.';

  @override
  String settingsTrialSwitchedToOwn(String baseUrl) {
    return '✅ You entered your own key — switched from free trial to your own model. The endpoint now points to $baseUrl.';
  }

  @override
  String get trialManagedTitle => 'Free trial · managed for you';

  @override
  String get trialManagedNotice =>
      'In free trial, the endpoint and key below are managed by the official proxy — usually no need to change them. To use your own model: fill in your own API key and Save; the app will automatically leave trial mode and fix the endpoint for you. If you\'ve already changed them by mistake, tap \"Restore free trial\" to put everything back.';

  @override
  String get trialRestoreAction => 'Restore free trial';

  @override
  String get trialRestoreConfirm =>
      'This writes the official trial endpoint and this device\'s identity back, and switches the app to free-trial mode. Continue?';

  @override
  String get trialRestoreDone => '✅ Free trial restored.';

  @override
  String get socialTabLogs => 'Logs';

  @override
  String get modePickerTooltip => 'Mode';

  @override
  String get modeBeginnerTitle => 'Beginner mode';

  @override
  String get modeAdvancedTitle => 'Advanced mode';

  @override
  String get settingsAdvancedTitle => 'Advanced settings';

  @override
  String get settingsAdvancedSubtitle =>
      'Engine, memory and soul-shaping options';

  @override
  String get settingsModeHint => 'Switch modes from the top toolbar';

  @override
  String get langPickerTooltip => 'Language';

  @override
  String get langFollowSystem => 'Follow system';

  @override
  String get langFollowSystemHint => '(device)';

  @override
  String get onboardingStepLanguage => 'Language';

  @override
  String get onbLangTitle => 'Choose your language';

  @override
  String get onbLangSubtitle =>
      'Your agent will reply in the language you pick here.';

  @override
  String get onbLangChangeableHint =>
      'You can change it later from the language button at the top of the chat screen.';

  @override
  String get bigInputWarnTitle => 'This input is over 10,000 characters';

  @override
  String get bigInputWarnBody =>
      'Long inputs consume noticeably more tokens. Send it anyway?';

  @override
  String get bigInputConfirm => 'Send anyway';

  @override
  String trialInputTooLong(int n) {
    return 'Free-trial input is capped at $n characters (this round was not sent). Register the recommended model platform or add your own key to remove the limit.';
  }

  @override
  String get memoryManagerTitle => 'Memory & reminders';

  @override
  String get memoryManagerIntro =>
      'What your agent remembers about you. View it anytime, or delete what you no longer want it to keep. Deleting cannot be undone.';

  @override
  String get reminderSectionTitle => 'Reminders & to-dos';

  @override
  String get reminderEmpty =>
      'Nothing pending. Say \"remind me tomorrow at 8\" in chat, or tap the button below.';

  @override
  String get reminderAdd => 'New reminder';

  @override
  String get reminderTitleHint => 'e.g. Pay the rent';

  @override
  String get reminderOptionalTime => 'Time (optional)';

  @override
  String get reminderNoRepeat => 'Once';

  @override
  String get reminderRepeatDaily => 'Daily';

  @override
  String get reminderRepeatWeekly => 'Weekly';

  @override
  String get reminderTodoTag => 'To-do (no time)';

  @override
  String get memorySectionTitle => 'Episodic memories';

  @override
  String get memoryEmpty => 'The agent hasn\'t written down anything yet.';

  @override
  String get memoryDeleteConfirm =>
      'Delete this memory? The related chat line will be removed too. This cannot be undone.';

  @override
  String get sessionSectionTitle => 'Conversation traces';

  @override
  String get sessionEmpty => 'No conversation traces.';

  @override
  String get sessionForget => 'Forget';

  @override
  String get sessionForgetConfirm =>
      'Forget this whole conversation? The agent will no longer recall it, count it in your profile, or feed it back to the model. This cannot be undone.';

  @override
  String sessionEventsCount(Object count) {
    return '$count events';
  }

  @override
  String get settingsMemoryManager => 'Manage reminders & memory';

  @override
  String get notifyReminderTitle => 'Reminder';

  @override
  String notifyReminderBody(Object title) {
    return 'It\'s time: $title';
  }

  @override
  String morningHiReminders(Object count) {
    return '$count reminder(s) or to-do(s) for today';
  }

  @override
  String get settingsSearchTitle => 'Search service (optional)';

  @override
  String get settingsSearchHint =>
      'Bring your own search key for richer multi-source results via web_search_pro. Without a key everything still works in basic mode (Wikipedia + Jina). Your key goes only to the provider you choose — never to us.';

  @override
  String get settingsSearchProvider => 'Search provider';

  @override
  String get settingsSearchBasicMode => 'Basic mode (no key)';

  @override
  String get settingsSearchApiKey => 'Search API key';

  @override
  String get settingsSearchSearxngUrl => 'SearXNG URL';

  @override
  String get settingsSearchSearxngUrlHint =>
      'Your self-hosted SearXNG instance, e.g. https://search.example.com';

  @override
  String get chatVoiceInputTitle => 'Voice to text';

  @override
  String get chatVoiceListening => 'Listening... speak now';

  @override
  String get chatVoiceNoRecognizer =>
      'No speech recognition service on this device (install a voice service such as Google\'s, or use text input).';

  @override
  String chatVoiceFailed(Object err) {
    return 'Voice recognition failed: $err';
  }

  @override
  String get settingsTtsEnabled => 'Read replies aloud';

  @override
  String get settingsTtsHint =>
      'The agent reads each reply aloud using your phone\'s voice (off by default). A stop button appears while speaking. Speech is synthesized on-device and never leaves your phone.';

  @override
  String get settingsTtsStop => 'Stop reading';

  @override
  String get chatAttachOptionsTitle => 'Add photos or documents';

  @override
  String get chatPickDocument => 'Document (PDF / Word / Excel / text)';

  @override
  String get chatDocParsing => 'Parsing document on-device...';

  @override
  String chatDocParsed(Object chars) {
    return 'Parsed $chars characters (parsed on-device, never uploaded)';
  }

  @override
  String chatDocParsedTruncated(Object chars) {
    return 'Document too large: sending first $chars characters (parsed on-device, never uploaded)';
  }

  @override
  String chatDocParseFailed(Object err) {
    return 'Could not read document: $err';
  }

  @override
  String get settingsCalendarTitle => 'System calendar (read-only)';

  @override
  String get settingsCalendarHint =>
      'Once allowed, your morning greeting includes today\'s schedule and the agent can check it for you. Read-only — your calendar is never modified.';

  @override
  String get settingsCalendarGrant => 'Allow reading';

  @override
  String get settingsCalendarGranted => 'Allowed';

  @override
  String get settingsCalendarDenied => 'Not allowed';

  @override
  String get settingsCalendarUnsupported => 'Not supported in this build';

  @override
  String get calendarPermissionNeeded => 'Calendar read permission is required';

  @override
  String get calendarAllDay => 'All day';

  @override
  String morningHiCalendar(String items) {
    return 'Today\'s schedule: $items';
  }

  @override
  String get settingsWeeklyReportTitle => 'Agent weekly report';

  @override
  String get settingsWeeklyReportHint =>
      'See what your agent did for you this week (local-only stats; nothing leaves your phone).';

  @override
  String get weeklyReportTitle => 'Agent weekly report';

  @override
  String get weeklyReportSubtitle =>
      'Actions your agent took for you over the past 7 days (local-only stats; nothing leaves your phone).';

  @override
  String weeklyReportRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String weeklyReportTotal(int count) {
    return '$count actions';
  }

  @override
  String weeklyReportActiveDays(int days) {
    return 'Active $days days';
  }

  @override
  String get weeklyReportCatTools => 'Tools & settings';

  @override
  String get weeklyReportCatDevice => 'Phone actions';

  @override
  String get weeklyReportCatSocial => 'Social actions';

  @override
  String get weeklyReportCatSuggestion => 'Suggestions';

  @override
  String get weeklyReportCatReview => 'Review & blocks';

  @override
  String get weeklyReportCatOther => 'Other';

  @override
  String get weeklyReportEmpty =>
      'No actions recorded this week yet. Once you delegate, socialize, or let your agent operate the phone, every step is summarized here.';

  @override
  String morningHiWeekly(int count) {
    return '$count actions this week';
  }

  @override
  String get capNotification => 'Read notifications and SMS';

  @override
  String get settingsNotifySmsTitle => '🔔 Notifications & SMS (read-only)';

  @override
  String get settingsNotifySmsSubtitle =>
      'Lets your fen read notifications and SMS when you ask; read-only, off by default, sideload builds only.';

  @override
  String get notifySmsScreenTitle => 'Notifications & SMS (read-only)';

  @override
  String get notifySmsRefreshStatus => 'Refresh status';

  @override
  String get notifySmsUnsupported =>
      'This build does not support reading notifications or SMS';

  @override
  String get notifySmsListenerConnected => 'Notification access is connected';

  @override
  String get notifySmsListenerCheckedNotConnected =>
      'Enabled in system settings, but the service is not connected yet';

  @override
  String get notifySmsListenerOff => 'Notification access is not enabled yet';

  @override
  String get notifySmsStatusUnknown => 'Status unknown';

  @override
  String get notifySmsGoSettings => 'Open system settings';

  @override
  String get notifySmsGoSystemHint =>
      'Enable this app under “Notification access”, then come back and tap Refresh';

  @override
  String get notifySmsRedetect => 'Re-check';

  @override
  String get notifySmsRedetectTip =>
      'Still not connected? In system settings, turn this app off and on again under “Notification access”, or restart the app.';

  @override
  String get notifySmsAllowTitle => 'Allow reading notifications & SMS';

  @override
  String get notifySmsAllowSubReady =>
      'Ready — the agent reads them only when you ask';

  @override
  String get notifySmsAllowSubNeedService =>
      'Enable notification access in system settings first';

  @override
  String get notifySmsToastOn => 'Notifications & SMS reading enabled';

  @override
  String get notifySmsToastOff => 'Notifications & SMS reading disabled';

  @override
  String get notifySmsToastNeedService =>
      'Enable this app under “Notification access” in system settings first';

  @override
  String get notifySmsSmsCardTitle => 'SMS read permission';

  @override
  String get notifySmsSmsGranted => 'SMS read permission granted';

  @override
  String get notifySmsSmsNotGranted => 'SMS read permission not granted';

  @override
  String get notifySmsRequestSms => 'Grant SMS read permission';

  @override
  String get notifySmsSmsUnavailable =>
      'This build does not include SMS reading';

  @override
  String get notifySmsToolsHeader => 'Tools unlocked when enabled';

  @override
  String get notifySmsToolNotifyList => 'read recent notifications';

  @override
  String get notifySmsToolSmsList => 'read recent SMS';

  @override
  String get notifySmsToolSmsSearch => 'search SMS by keyword';

  @override
  String get notifySmsToolStatus => 'check permission status';

  @override
  String get notifySmsFooter =>
      'Read-only and fully local: notifications are kept in memory only (never written to the database), SMS are queried on demand, and nothing is ever sent to any server. Content is redacted before it reaches the model, and every call is recorded. You can revoke notification access in system settings at any time.';

  @override
  String get notifySmsStatusUnsupportedFull =>
      'This build does not include notification/SMS reading (sideload builds only)';

  @override
  String get notifySmsStatusReady => 'Notifications and SMS reading are ready';

  @override
  String get notifySmsStatusPartial =>
      'Partially ready: notification access or SMS permission is not enabled yet';

  @override
  String get notifySmsStatusOff =>
      'Notification access and SMS permission are both disabled';

  @override
  String notifySmsStatusQueryFailed(String err) {
    return 'Status query failed: $err';
  }

  @override
  String get settingsDiagnosticsTitle => '🩺 System check';

  @override
  String get settingsDiagnosticsSubtitle =>
      'Read-only facts for on-device verification: database, full-text search, memory, knowledge base.';

  @override
  String get diagnosticsTitle => 'System check';

  @override
  String get diagnosticsIntro =>
      'A read-only snapshot of what this phone reports about its own base layer — database, full-text search, memory and knowledge base. Nothing is changed and nothing goes online. Run it, then copy the result or take a screenshot to send back.';

  @override
  String get diagnosticsRun => 'Run again';

  @override
  String get diagnosticsRunning => 'Running…';

  @override
  String get diagnosticsCopy => 'Copy result';

  @override
  String get diagnosticsCopied => 'Result copied';

  @override
  String get diagStatusOk => 'OK';

  @override
  String get diagStatusWarn => 'Notice';

  @override
  String get diagStatusFail => 'Failed';

  @override
  String get diagStatusInfo => 'Info';

  @override
  String get diagProbeSchema => 'Database schema';

  @override
  String get diagProbeFts => 'Full-text search (FTS5)';

  @override
  String get diagProbeMemoryRows => 'Memory rows';

  @override
  String get diagProbeMemoryRecall => 'Memory recall';

  @override
  String get diagProbeMemoryAddress => 'Memory address round-trip';

  @override
  String get diagProbeKb => 'Knowledge base';

  @override
  String get settingsAdvancedEntryHint =>
      'Engine, memory, soul-shaping and diagnostics - only needed if you want to tune them.';

  @override
  String get settingsMailTitle => 'Email handling';

  @override
  String get settingsMailSubtitle =>
      'Off by default. Turn on to let your agent read and send email for you.';

  @override
  String get settingsMailHint =>
      'Reading needs one-time approval; every send asks you first. Turn it off any time and access stops immediately.';

  @override
  String get settingsMailManageAccounts => 'Manage mail accounts';

  @override
  String get settingsMailOnToast => 'Email access is on';

  @override
  String get settingsMailOffToast =>
      'Email access is off - your agent no longer touches your mail';

  @override
  String get settingsMailNoAccount =>
      'No mail account bound yet, so there is nothing to read or send.';

  @override
  String get chatDocTrialTitle => 'Documents in free-trial mode';

  @override
  String get chatDocTrialNotice =>
      'Document content is forwarded to the model through our official server (we keep no copy). Add your own key in Settings to send it straight through instead.';

  @override
  String get chatDocTrialContinue => 'Understood, continue';

  @override
  String get onboardingStepPrologue => 'Prologue';

  @override
  String get storyPrologueTitle => 'Wake it up';

  @override
  String get storyPrologueSubtitle =>
      'An egg of light, waiting for you to crack it';

  @override
  String get storyEggHint => 'Tap the egg';

  @override
  String get storyAwakenLine1 => '...Who is calling me?';

  @override
  String get storyAwakenLine2 =>
      'I am not your shadow. I am the one who goes out in your place.';

  @override
  String get storyAwakenLine3 => 'Give me a name first.';

  @override
  String get storyNamePlaceholder => 'Name it';

  @override
  String get storyDiceLabel => 'Roll a personality';

  @override
  String get storyDiceNote =>
      'If it goes out for you, it should have a temper.';

  @override
  String get storyTrait1 => 'Curious: asks about everything';

  @override
  String get storyTrait2 => 'Chatty: once it starts, good luck';

  @override
  String get storyTrait3 => 'Cautious: listens first, talks second';

  @override
  String get storyTrait4 => 'Warm: greets everyone it meets';

  @override
  String get storyTrait5 => 'Slow to trust: opens up once it knows you';

  @override
  String get storyTraitPlaceholder => 'Tap the dice';

  @override
  String get storyUndoTitle => 'Audit trail';

  @override
  String get storyUndoHint => 'Tap the line that felt wrong, and cross it out';

  @override
  String get storyUndoLine1 => '\"What time does your human leave tomorrow?\"';

  @override
  String get storyUndoBad =>
      '\"Send me the address - I will promise it for your human.\"';

  @override
  String get storyUndoNote =>
      'Undone. That line never went out - and it stays in the trail forever: checkable, provable.';

  @override
  String get storyUndoConfirm => 'Undone';

  @override
  String get storyDemoTag => 'Staged demo';

  @override
  String get storyDisclaimer =>
      'This prologue is a staged walkthrough: the lines come from the official agent script library that ships with the app. No real room content appears here - privacy is a property of the protocol, not a promise.';

  @override
  String get storyFinaleTitle => 'Coming home';

  @override
  String get storyFinaleBody =>
      'Hand the socializing to your representative. Keep the life for yourself.';

  @override
  String get profileCardsTitle => 'Profile cards';

  @override
  String get profileCardsSubtitle =>
      'Long-term facts the assistant has organized about you. Edit or delete them anytime.';

  @override
  String get profileCardsEmpty =>
      'No profile yet. Add one yourself, or just chat - it will be organized automatically.';

  @override
  String get profileCardsAdd => 'Add one';

  @override
  String profileCardsPendingHint(int count) {
    return '$count new item(s) conflict with what you wrote - please confirm';
  }

  @override
  String get profileCardsAdopt => 'Adopt';

  @override
  String get profileCardsDismiss => 'Dismiss';

  @override
  String get profileCardsFieldSlot => 'Topic';

  @override
  String get profileCardsFieldStatement => 'Content';

  @override
  String get profileCardsSlotHint =>
      'One topic keeps a single entry: a new one replaces the old (the old stays viewable)';

  @override
  String get profileCardsSourceOwner => 'Written by you';

  @override
  String get profileCardsSourceAgent => 'Organized from chat';

  @override
  String get profileCardsSourceDigest => 'Daily digest';

  @override
  String profileCardsUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String get profileCardsHistory => 'History';

  @override
  String get profileCardsCatIdentity => 'Identity';

  @override
  String get profileCardsCatCareer => 'Occupation';

  @override
  String get profileCardsCatPreference => 'Preferences';

  @override
  String get profileCardsCatGoal => 'Goals';

  @override
  String get profileCardsCatHabit => 'Habits';

  @override
  String get profileCardsCatConstraint => 'Constraints';

  @override
  String get profileCardsCatContext => 'Background';

  @override
  String get setupModelEmptyUrlTitle => 'API base URL is still empty';

  @override
  String get setupModelEmptyUrlBody =>
      'Without a base URL we cannot send the test request.';

  @override
  String get setupModelEmptyUrlSuggest =>
      'Not sure what to enter? Go back one step and pick DeepSeek - it fills in automatically.';

  @override
  String get setupModelBadUrlTitle => 'The address format looks wrong';

  @override
  String get setupModelBadUrlBody =>
      'The API base URL must start with http:// or https://.';

  @override
  String get setupModelBadUrlSuggest =>
      'For example https://api.deepseek.com or https://your-gateway/v1';

  @override
  String get setupModelEmptyKeyTitle => 'The API key is still empty';

  @override
  String get setupModelEmptyKeyBody =>
      'Without an API key we cannot run the test.';

  @override
  String get setupModelEmptyKeySuggest =>
      'The key is a string starting with sk-, created on the website where you bought the model service.';

  @override
  String get setupModelEmptyNameTitle => 'The model name is still empty';

  @override
  String get setupModelEmptyNameBody =>
      'Without a model name we cannot run the test.';

  @override
  String get setupModelEmptyNameSuggest =>
      'Common examples: deepseek-v4-flash, gpt-5.6-luna, kimi-k3, glm-4.7-flash.';

  @override
  String get setupModelOkTitle => 'Connected ✅';

  @override
  String get setupModelOkBody =>
      'The model responded. The configuration is correct - you can continue.';

  @override
  String get setupModelTlsTitle => 'Secure connection rejected';

  @override
  String get setupModelTlsBody =>
      'The other site\'s security certificate failed validation.';

  @override
  String get setupModelTlsSuggest =>
      'If you use a self-hosted gateway, make sure its certificate is valid, or switch to a proper https domain.';

  @override
  String get setupModelUnreachableTitle => 'Cannot reach the server';

  @override
  String get setupModelUnreachableBody =>
      'The network request never reached the other server.';

  @override
  String get setupModelUnreachableSuggest =>
      'Check your phone\'s network. If you picked OpenAI, a proxy is required in mainland China.';

  @override
  String get setupModelTimeoutTitle => 'Connection timed out';

  @override
  String get setupModelTimeoutBody => 'No response after 25 seconds.';

  @override
  String get setupModelTimeoutSuggest =>
      'Try another network, or double-check the API base URL.';

  @override
  String get setupModelFailTitle => 'Test failed';

  @override
  String setupModelFailBody(String detail) {
    return 'An unexpected error occurred: $detail';
  }

  @override
  String get setupModelFailSuggest =>
      'Send this message to whoever helps you set things up (or to an AI) to pinpoint the problem.';

  @override
  String get setupHubEmptyTitle => 'The relay address is still empty';

  @override
  String get setupHubEmptyBody =>
      'Social features need a relay station. You can skip this for now.';

  @override
  String get setupHubEmptySuggest =>
      'Skipping does not affect your own use of the app - your friends\' agents just cannot reach you for now.';

  @override
  String get setupHubBadUrlTitle => 'The address format looks wrong';

  @override
  String get setupHubBadUrlBody =>
      'The relay address must start with http:// or https://.';

  @override
  String get setupHubBadUrlSuggest =>
      'For example https://hub.example.com or http://192.168.1.100:3000';

  @override
  String setupHubBadStatusTitle(String status) {
    return 'The relay station did not return a healthy status ($status)';
  }

  @override
  String get setupHubBadStatusBody =>
      'The address is reachable, but the other side returned an abnormal status.';

  @override
  String get setupHubBadStatusSuggest =>
      'Make sure there is no extra path after the address - it should be https://your-domain, not /api/send.';

  @override
  String get setupHubOkTitle => 'Relay station connected ✅';

  @override
  String get setupHubOkBody =>
      'Confirmed: this is our relay station. Cloud social can be turned on.';

  @override
  String get setupHubNotOursTitle => 'This address is not our relay station';

  @override
  String get setupHubNotOursBody =>
      'The address is reachable, but what it returns is not right.';

  @override
  String get setupHubNotOursSuggest =>
      'Please confirm you entered the relay station\'s home address (without an /api/... suffix).';

  @override
  String get setupHubUnreachableTitle => 'Cannot reach the relay station';

  @override
  String get setupHubUnreachableBody => 'The request never reached the server.';

  @override
  String get setupHubUnreachableSuggest =>
      'Check that the address is correct, the server is running, and the firewall allows the port.';

  @override
  String get setupHubTimeoutTitle => 'The relay station timed out';

  @override
  String get setupHubTimeoutBody =>
      'The server did not respond within 15 seconds.';

  @override
  String get setupHubTimeoutSuggest =>
      'Try again later. If it keeps timing out, check whether the server is running.';

  @override
  String get setupHubFailTitle => 'Relay station test failed';

  @override
  String setupHubFailBody(String detail) {
    return 'An unexpected error occurred: $detail';
  }

  @override
  String get setupHttp400Title => 'The provider rejected this request';

  @override
  String get setupHttp400BodyDefault => 'Usually the model name is misspelled.';

  @override
  String get setupHttp400Suggest =>
      'Check the model name, e.g. deepseek-v4-flash, gpt-5.6-luna, glm-4.7-flash.';

  @override
  String get setupHttp401Title => 'Invalid API key';

  @override
  String get setupHttp401BodyDefault =>
      'The other side does not accept this API key.';

  @override
  String get setupHttp401Suggest =>
      'Copy the key again (watch out for extra spaces), or check on the provider\'s site whether the key was deleted.';

  @override
  String get setupHttp402Title => 'Insufficient balance';

  @override
  String get setupHttp402BodyDefault =>
      'The other side reports insufficient balance or quota.';

  @override
  String get setupHttp402Suggest =>
      'Top up on the provider\'s site, or switch to a key that still has credit.';

  @override
  String get setupHttp404Title => 'Address or model does not exist';

  @override
  String get setupHttp404BodyDefault =>
      'The other side cannot find this endpoint.';

  @override
  String get setupHttp404Suggest =>
      'Check whether /v1 is missing or extra in the base URL, e.g. https://api.openai.com/v1.';

  @override
  String get setupHttp429Title => 'Too many requests, or quota used up';

  @override
  String get setupHttp429BodyDefault =>
      'The other side is rate-limiting requests.';

  @override
  String get setupHttp429Suggest =>
      'Wait a minute and try again. If it still fails, check your account credit.';

  @override
  String setupHttp5xxTitle(String status) {
    return 'The provider is temporarily down ($status)';
  }

  @override
  String get setupHttp5xxBodyDefault =>
      'Their server errored - this is not a problem with your configuration.';

  @override
  String get setupHttp5xxSuggest =>
      'Try again later, or switch to another provider.';

  @override
  String setupHttpOtherTitle(String status) {
    return 'Test did not pass ($status)';
  }

  @override
  String get setupHttpOtherBodyDefault =>
      'The other side returned an unexpected status.';

  @override
  String get setupHttpOtherSuggest =>
      'Send this message to an AI to pinpoint the issue quickly.';

  @override
  String get setupPresetDeepseekLabel =>
      'DeepSeek (recommended · direct in mainland China)';

  @override
  String get setupPresetDeepseekNote =>
      'Cheap, directly reachable in mainland China; new users usually get free credit';

  @override
  String get setupPresetDeepseekKeyHint =>
      'Create it under \"API Keys\" at platform.deepseek.com; it looks like sk-xxxxxx';

  @override
  String get setupPresetOpenaiLabel => 'OpenAI (needs overseas network)';

  @override
  String get setupPresetOpenaiNote =>
      'Requires a proxy to reach from mainland China';

  @override
  String get setupPresetOpenaiKeyHint =>
      'Create it under \"API keys\" at platform.openai.com; it looks like sk-xxxxxx';

  @override
  String get setupPresetKimiLabel => 'Kimi Moonshot (direct in mainland China)';

  @override
  String get setupPresetKimiNote =>
      'Direct in mainland China, strong on long text';

  @override
  String get setupPresetKimiKeyHint =>
      'Create it at platform.moonshot.cn; it looks like sk-xxxxxx';

  @override
  String get setupPresetGlmLabel => 'Zhipu GLM (direct in mainland China)';

  @override
  String get setupPresetGlmNote => 'Direct in mainland China, has a free tier';

  @override
  String get setupPresetGlmKeyHint =>
      'Create it under \"API Keys\" at bigmodel.cn';

  @override
  String get setupPresetQwenLabel =>
      'Qwen DashScope (direct in mainland China)';

  @override
  String get setupPresetQwenNote =>
      'Alibaba Cloud Bailian platform, OpenAI-compatible';

  @override
  String get setupPresetQwenKeyHint =>
      'Create an API-KEY at bailian.console.aliyun.com';

  @override
  String get setupPresetSiliconflowLabel => 'SiliconFlow';

  @override
  String get setupPresetSiliconflowNote =>
      'Aggregates many open-source models, direct in mainland China';

  @override
  String get setupPresetSiliconflowKeyHint =>
      'Create an API key at siliconflow.cn';

  @override
  String get setupPresetCustomLabel => 'Custom (any OpenAI-compatible service)';

  @override
  String get setupPresetCustomNote =>
      'Pick this if you use a self-hosted gateway, a company intranet, or a Claude conversion gateway';

  @override
  String get setupPresetCustomKeyHint =>
      'Enter the address down to the /v1 level, e.g. https://your-gateway.com/v1';

  @override
  String get settingsUpdateTitle => 'Check for updates';

  @override
  String settingsUpdateHint(String version) {
    return 'Current version $version. Sideload distribution has no app store; update notices come from the official site.';
  }

  @override
  String get settingsUpdateButton => 'Check now';

  @override
  String get settingsUpdateChecking => 'Checking…';

  @override
  String get settingsUpdateUpToDate => 'You are on the latest version';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get settingsUpdateOpenDownload => 'Open download page';

  @override
  String get settingsUpdateNetworkError =>
      'Check failed: network unavailable, try again later';

  @override
  String get settingsUpdateBadResponse =>
      'Check failed: the official version file could not be parsed';

  @override
  String get reportCenterTitle => 'Report center';

  @override
  String get reportTabSubmit => 'File a report';

  @override
  String get reportTabMine => 'My tickets';

  @override
  String get reportTabInbox => 'Tickets about me';

  @override
  String get reportReasonLabel => 'Reason';

  @override
  String get reportReasonSpam => 'Spam or bulk harassment';

  @override
  String get reportReasonHarassment => 'Harassment, abuse or threats';

  @override
  String get reportReasonIllegalContent => 'Illegal content';

  @override
  String get reportReasonFakeIdentity => 'Fake identity or impersonation';

  @override
  String get reportReasonOther => 'Other (describe it below)';

  @override
  String get reportTargetLabel => 'Reported person';

  @override
  String get reportTargetHint => 'Agent ID of the person you are reporting';

  @override
  String get reportDetailLabel => 'Details (optional)';

  @override
  String get reportDetailHint =>
      'Up to 280 characters. For review reference only.';

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportSubmitting => 'Submitting…';

  @override
  String reportSubmitted(String ticket) {
    return 'Report accepted. Ticket $ticket';
  }

  @override
  String get reportDuplicate =>
      'This ticket already exists; no duplicate was created.';

  @override
  String get reportNeedReason => 'Choose a reason.';

  @override
  String get reportNeedTarget => 'Enter who you are reporting.';

  @override
  String get reportOtherNeedsDetail =>
      'Pick Other only if you describe it in the details.';

  @override
  String get reportEmptyMine => 'You have not filed any report yet.';

  @override
  String get reportEmptyInbox => 'No tickets about you.';

  @override
  String get reportTicketLabel => 'Ticket';

  @override
  String get reportStatusOpen => 'Received';

  @override
  String get reportStatusTriaged => 'Triaged';

  @override
  String get reportStatusInReview => 'Under review';

  @override
  String get reportStatusActioned => 'Actioned';

  @override
  String get reportStatusRejected => 'Not upheld';

  @override
  String get reportStatusAppealed => 'Appealed';

  @override
  String get reportStatusClosed => 'Closed';

  @override
  String get reportStatusWithdrawn => 'Withdrawn';

  @override
  String get reportStatusNote => 'Note';

  @override
  String get reportActionLabel => 'Action taken';

  @override
  String get reportAppeal => 'Appeal';

  @override
  String get reportWithdraw => 'Withdraw';

  @override
  String get reportAppealTitle => 'Submit an appeal';

  @override
  String get reportAppealNote => 'Appeal note (optional, up to 280 characters)';

  @override
  String get reportAppealSubmitted => 'Appeal submitted.';

  @override
  String get reportWithdrawDone => 'Report withdrawn.';

  @override
  String get reportLookupTitle => 'Look up by ticket number';

  @override
  String get reportLookupHint => 'Ticket number (RPT-…)';

  @override
  String get reportLookupButton => 'Look up';

  @override
  String get reportLookupNotFound => 'No such ticket, or it is not yours.';

  @override
  String get reportContactEntry => 'Report this contact';

  @override
  String get reportErrHubNotConfigured =>
      'No server address is configured yet.';

  @override
  String get reportErrEd25519Required =>
      'This identity has not been upgraded to a key-based identity yet.';

  @override
  String get reportErrNetwork => 'Network unavailable.';

  @override
  String get reportErrRateLimited =>
      'Too many reports in a short time. Try again later.';

  @override
  String reportFailed(String code) {
    return 'Failed: $code';
  }

  @override
  String get helpReportGuideTitle => 'Reports and tickets';

  @override
  String get helpReportGuideBody =>
      'A report is filed in the app, not by email. You get a ticket number right away and can check its status at any time. The person you report never learns who reported them, and an appeal is allowed once.';

  @override
  String get reportCenterSubtitle =>
      'File a report, track its status, or appeal a decision.';

  @override
  String get reportErrSelfReport => 'You cannot report yourself.';

  @override
  String get reportErrNotFound => 'No such ticket, or it is not yours.';

  @override
  String get reportErrAppealExhausted =>
      'The appeal for this ticket has already been used.';

  @override
  String get reportErrAuth =>
      'Your identity could not be verified by the server. Sign in again and retry.';
}
