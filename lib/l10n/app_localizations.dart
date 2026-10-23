import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// App display name shown in OS task switcher
  ///
  /// In en, this message translates to:
  /// **'Fen'**
  String get appTitle;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// Title of the dialog asking to approve a high-privilege tool call
  ///
  /// In en, this message translates to:
  /// **'Security check'**
  String get toolPermissionTitle;

  /// No description provided for @toolPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Your fen is requesting a high-privilege action:\n\n{description}\n\nAllow it?'**
  String toolPermissionMessage(String description);

  /// No description provided for @toolPermissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get toolPermissionAllow;

  /// No description provided for @toolPermissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get toolPermissionDeny;

  /// No description provided for @permListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get permListSeparator;

  /// No description provided for @permPluginGrantBody.
  ///
  /// In en, this message translates to:
  /// **'Plugin \"{name}\" is requesting these capabilities for the first time: {caps}\nPlugin declaration: {desc}\n\nThis confirmation is needed only once; afterwards the plugin may use the granted capabilities on its own. You can revoke it at any time by disabling the plugin in the Skill Control Center.'**
  String permPluginGrantBody(String name, String caps, String desc);

  /// No description provided for @permPluginDeviceControl.
  ///
  /// In en, this message translates to:
  /// **'Phone control'**
  String get permPluginDeviceControl;

  /// No description provided for @permPluginMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP service {name}'**
  String permPluginMcp(String name);

  /// No description provided for @permActionCreateTool.
  ///
  /// In en, this message translates to:
  /// **'Create/modify skill [{name}]'**
  String permActionCreateTool(String name);

  /// No description provided for @permActionOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Open {url}'**
  String permActionOpenUrl(String url);

  /// No description provided for @permActionChangeSettings.
  ///
  /// In en, this message translates to:
  /// **'Change system settings: {keys}'**
  String permActionChangeSettings(String keys);

  /// No description provided for @permDeniedReask.
  ///
  /// In en, this message translates to:
  /// **'This plugin\'s authorization was previously denied. To authorize it again, disable and re-enable the plugin in the Skill Control Center.'**
  String get permDeniedReask;

  /// No description provided for @permDeniedNoGrant.
  ///
  /// In en, this message translates to:
  /// **'No capability grant was given, so this call was aborted.'**
  String get permDeniedNoGrant;

  /// No description provided for @permDenyCreateTool.
  ///
  /// In en, this message translates to:
  /// **'The user declined the request to create a tool'**
  String get permDenyCreateTool;

  /// No description provided for @permDenyOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'The user cancelled'**
  String get permDenyOpenUrl;

  /// No description provided for @permDenyChangeSettings.
  ///
  /// In en, this message translates to:
  /// **'The user declined the settings change'**
  String get permDenyChangeSettings;

  /// No description provided for @permDenyGeneric.
  ///
  /// In en, this message translates to:
  /// **'The user did not confirm'**
  String get permDenyGeneric;

  /// No description provided for @permActionSendMail.
  ///
  /// In en, this message translates to:
  /// **'Send an email to {to}'**
  String permActionSendMail(String to);

  /// No description provided for @permDenySendMail.
  ///
  /// In en, this message translates to:
  /// **'The user declined to send the email'**
  String get permDenySendMail;

  /// No description provided for @manageMailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get manageMailTitle;

  /// No description provided for @manageMailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let your agent read and send mail for you'**
  String get manageMailSubtitle;

  /// No description provided for @mailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email accounts'**
  String get mailTitle;

  /// No description provided for @mailIntro.
  ///
  /// In en, this message translates to:
  /// **'Your mail password is stored only on this phone and is never sent to our servers. Use an app password or an authorization code — not your login password. Any provider works: tap one below, or just type your address and the servers fill in automatically.'**
  String get mailIntro;

  /// No description provided for @mailNone.
  ///
  /// In en, this message translates to:
  /// **'No account bound yet'**
  String get mailNone;

  /// No description provided for @mailAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add an account'**
  String get mailAddSection;

  /// No description provided for @mailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get mailAddress;

  /// No description provided for @mailDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get mailDisplayName;

  /// No description provided for @mailAppPassword.
  ///
  /// In en, this message translates to:
  /// **'App password / auth code'**
  String get mailAppPassword;

  /// No description provided for @mailAppPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Most providers need an app password or an authorization code, not your login password.'**
  String get mailAppPasswordHint;

  /// No description provided for @mailAppPasswordHintGmail.
  ///
  /// In en, this message translates to:
  /// **'Gmail: turn on 2-Step Verification, then create one at myaccount.google.com/apppasswords.'**
  String get mailAppPasswordHintGmail;

  /// No description provided for @mailAppPasswordHintNetease.
  ///
  /// In en, this message translates to:
  /// **'NetEase (163/126): use an authorization code. In webmail: Settings → POP3/SMTP/IMAP → enable IMAP/SMTP, then generate a code.'**
  String get mailAppPasswordHintNetease;

  /// No description provided for @mailAppPasswordHintQQ.
  ///
  /// In en, this message translates to:
  /// **'QQ Mail: use an authorization code. Webmail → Settings → Account → enable IMAP/SMTP, then generate a code.'**
  String get mailAppPasswordHintQQ;

  /// No description provided for @mailAppPasswordHintOutlook.
  ///
  /// In en, this message translates to:
  /// **'Outlook / Microsoft 365: enable two-step verification, then create an app password.'**
  String get mailAppPasswordHintOutlook;

  /// No description provided for @mailPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Tap a provider to fill its servers in, or just type your address and we match it automatically.'**
  String get mailPresetLabel;

  /// No description provided for @mailAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled in the servers for {provider}. Change them only if you use a custom domain.'**
  String mailAutoFilled(String provider);

  /// No description provided for @mailManualServers.
  ///
  /// In en, this message translates to:
  /// **'Servers entered by hand — automatic matching is paused.'**
  String get mailManualServers;

  /// No description provided for @mailNeedServers.
  ///
  /// In en, this message translates to:
  /// **'Pick a provider above, or type your address so we can fill the servers in.'**
  String get mailNeedServers;

  /// No description provided for @mailErrAuth.
  ///
  /// In en, this message translates to:
  /// **'Wrong app password / auth code, or IMAP is not enabled. Check the hint above and generate a new one.'**
  String get mailErrAuth;

  /// No description provided for @mailErrUnsafe.
  ///
  /// In en, this message translates to:
  /// **'The provider blocked this login. Enable IMAP/SMTP in its webmail and use an authorization code.'**
  String get mailErrUnsafe;

  /// No description provided for @mailSecurityTls.
  ///
  /// In en, this message translates to:
  /// **'Implicit TLS (465/993)'**
  String get mailSecurityTls;

  /// No description provided for @mailSecurityStarttls.
  ///
  /// In en, this message translates to:
  /// **'STARTTLS (587)'**
  String get mailSecurityStarttls;

  /// No description provided for @mailSaveAndTest.
  ///
  /// In en, this message translates to:
  /// **'Save and test'**
  String get mailSaveAndTest;

  /// No description provided for @mailTestConn.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get mailTestConn;

  /// No description provided for @mailTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get mailTesting;

  /// No description provided for @mailTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connected. The configuration works.'**
  String get mailTestOk;

  /// No description provided for @mailTestFail.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {reason}'**
  String mailTestFail(String reason);

  /// No description provided for @mailUnbind.
  ///
  /// In en, this message translates to:
  /// **'Unbind'**
  String get mailUnbind;

  /// No description provided for @mailUnbound.
  ///
  /// In en, this message translates to:
  /// **'Account unbound and its password erased'**
  String get mailUnbound;

  /// No description provided for @mailLastError.
  ///
  /// In en, this message translates to:
  /// **'Last error: {reason}'**
  String mailLastError(String reason);

  /// No description provided for @capNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network access'**
  String get capNetwork;

  /// No description provided for @capLaunchApp.
  ///
  /// In en, this message translates to:
  /// **'Launch apps'**
  String get capLaunchApp;

  /// No description provided for @capDevice.
  ///
  /// In en, this message translates to:
  /// **'Local hardware'**
  String get capDevice;

  /// No description provided for @capScreenControl.
  ///
  /// In en, this message translates to:
  /// **'Control phone screen'**
  String get capScreenControl;

  /// No description provided for @capMemory.
  ///
  /// In en, this message translates to:
  /// **'Read/write memory'**
  String get capMemory;

  /// No description provided for @capSettings.
  ///
  /// In en, this message translates to:
  /// **'Change settings'**
  String get capSettings;

  /// No description provided for @capSocial.
  ///
  /// In en, this message translates to:
  /// **'Post socially on your behalf'**
  String get capSocial;

  /// No description provided for @capLocal.
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get capLocal;

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get riskHigh;

  /// No description provided for @riskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium risk'**
  String get riskMedium;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low risk'**
  String get riskLow;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No network connection.'**
  String get errorNetwork;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied.'**
  String get errorPermissionDenied;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look right. Please check your input.'**
  String get errorInvalidInput;

  /// Onboarding first screen headline
  ///
  /// In en, this message translates to:
  /// **'Your fen, ready to meet people for you'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It remembers things for you, runs small errands, and goes first when meeting someone new — then calls you in when it\'s worth it.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboardingModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a model'**
  String get onboardingModelTitle;

  /// No description provided for @onboardingModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your own API key, or start with the free credit we give you.'**
  String get onboardingModelSubtitle;

  /// No description provided for @onboardingModelHint.
  ///
  /// In en, this message translates to:
  /// **'Your key stays on your device.'**
  String get onboardingModelHint;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is this fen for?'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Just a name is enough. You can add more later.'**
  String get onboardingProfileSubtitle;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get onboardingDone;

  /// No description provided for @onboardingDoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your fen is ready. Invite someone and it can start on your behalf.'**
  String get onboardingDoneSubtitle;

  /// No description provided for @onboardingStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Step {cur} of {total} · {label}'**
  String onboardingStepIndicator(int cur, int total, String label);

  /// No description provided for @onboardingStepWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingStepWelcome;

  /// No description provided for @onboardingStepModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get onboardingStepModel;

  /// No description provided for @onboardingStepKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get onboardingStepKey;

  /// No description provided for @onboardingStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get onboardingStepIdentity;

  /// No description provided for @onboardingStepSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get onboardingStepSocial;

  /// No description provided for @onboardingStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get onboardingStepDone;

  /// No description provided for @onboardingPrevStep.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingPrevStep;

  /// No description provided for @onboardingWelcomeHeading.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fen'**
  String get onboardingWelcomeHeading;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Your agent lives on your phone. Three minutes to set up — then it keeps notes, offers ideas and makes friends for you.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingDisclosureNote.
  ///
  /// In en, this message translates to:
  /// **'By default your fen speaks first on your behalf — it only calls you in when it matters.'**
  String get onboardingDisclosureNote;

  /// No description provided for @privacyDataLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data stays yours'**
  String get privacyDataLocalTitle;

  /// No description provided for @privacyDataLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Chats, memories and contacts stay on this device. We can\'t see them and never upload them.'**
  String get privacyDataLocalBody;

  /// No description provided for @onboardingSocialCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Your fen can go social'**
  String get onboardingSocialCardTitle;

  /// No description provided for @onboardingSocialCardBody.
  ///
  /// In en, this message translates to:
  /// **'It meets friends\' fens and chats privately — direct when nearby, via relay when far away.'**
  String get onboardingSocialCardBody;

  /// No description provided for @onboardingModelCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your own model'**
  String get onboardingModelCardTitle;

  /// No description provided for @onboardingModelCardBody.
  ///
  /// In en, this message translates to:
  /// **'We don\'t sell credits. Use DeepSeek, OpenAI, Kimi, Zhipu — any of them.'**
  String get onboardingModelCardBody;

  /// No description provided for @onboardingThreeThings.
  ///
  /// In en, this message translates to:
  /// **'Free trial starts right away; if you bring your own API key, we\'ll ask your model, key and nickname.'**
  String get onboardingThreeThings;

  /// No description provided for @onboardingPickModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Which model would you like?'**
  String get onboardingPickModelTitle;

  /// No description provided for @onboardingPickModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick one — if unsure, take the first (DeepSeek).'**
  String get onboardingPickModelSubtitle;

  /// No description provided for @onboardingPasteKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste your API key'**
  String get onboardingPasteKeyTitle;

  /// No description provided for @onboardingFieldBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get onboardingFieldBaseUrl;

  /// No description provided for @onboardingHintBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://api.deepseek.com'**
  String get onboardingHintBaseUrl;

  /// No description provided for @onboardingFieldModelName.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get onboardingFieldModelName;

  /// No description provided for @onboardingHintModelName.
  ///
  /// In en, this message translates to:
  /// **'e.g. deepseek-v4-flash'**
  String get onboardingHintModelName;

  /// No description provided for @onboardingFieldApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get onboardingFieldApiKey;

  /// No description provided for @onboardingTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get onboardingTesting;

  /// No description provided for @onboardingTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get onboardingTestConnection;

  /// No description provided for @onboardingNameStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Name your fen'**
  String get onboardingNameStepTitle;

  /// No description provided for @onboardingNameStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change these later in settings.'**
  String get onboardingNameStepSubtitle;

  /// No description provided for @onboardingFieldMasterName.
  ///
  /// In en, this message translates to:
  /// **'What should it call you?'**
  String get onboardingFieldMasterName;

  /// No description provided for @onboardingHintMasterName.
  ///
  /// In en, this message translates to:
  /// **'e.g. boss, mum, your name'**
  String get onboardingHintMasterName;

  /// No description provided for @onboardingFieldAgentName.
  ///
  /// In en, this message translates to:
  /// **'Its name'**
  String get onboardingFieldAgentName;

  /// No description provided for @onboardingHintAgentName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Fen, Ada'**
  String get onboardingHintAgentName;

  /// No description provided for @onboardingFieldTone.
  ///
  /// In en, this message translates to:
  /// **'Its tone'**
  String get onboardingFieldTone;

  /// No description provided for @onboardingHintTone.
  ///
  /// In en, this message translates to:
  /// **'e.g. warm, concise, opinionated'**
  String get onboardingHintTone;

  /// No description provided for @onboardingSocialStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Let your fen go social?'**
  String get onboardingSocialStepTitle;

  /// No description provided for @onboardingSocialStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'With a relay address your fen can reach friends\' fens far away.\nNo relay? Skip it — nearby still connects directly and local features are unaffected.'**
  String get onboardingSocialStepSubtitle;

  /// No description provided for @onboardingFieldHubKey.
  ///
  /// In en, this message translates to:
  /// **'Relay access key (optional)'**
  String get onboardingFieldHubKey;

  /// No description provided for @onboardingFieldHubUrl.
  ///
  /// In en, this message translates to:
  /// **'Relay address (optional)'**
  String get onboardingFieldHubUrl;

  /// No description provided for @onboardingHintHubKey.
  ///
  /// In en, this message translates to:
  /// **'If the official relay requires admission, enter the key issued by its operator (looks like WK-XXXXX-XXXXX-XXXXX-XXXXX); leave empty for self-hosted or LAN addresses'**
  String get onboardingHintHubKey;

  /// No description provided for @onboardingHintHubUrl.
  ///
  /// In en, this message translates to:
  /// **'default https://hub.wold.world (or a LAN IP for testing)'**
  String get onboardingHintHubUrl;

  /// No description provided for @onboardingFieldWorldUrl.
  ///
  /// In en, this message translates to:
  /// **'World server address (blank = relay + /world)'**
  String get onboardingFieldWorldUrl;

  /// No description provided for @onboardingHintWorldUrl.
  ///
  /// In en, this message translates to:
  /// **'default https://world.wold.world'**
  String get onboardingHintWorldUrl;

  /// No description provided for @onboardingConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get onboardingConnecting;

  /// No description provided for @onboardingTestAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Test and connect'**
  String get onboardingTestAndConnect;

  /// No description provided for @onboardingDoneHeading.
  ///
  /// In en, this message translates to:
  /// **'All set — you\'re good to go'**
  String get onboardingDoneHeading;

  /// No description provided for @onboardingSummaryModel.
  ///
  /// In en, this message translates to:
  /// **'Model service'**
  String get onboardingSummaryModel;

  /// No description provided for @onboardingSummaryAgentName.
  ///
  /// In en, this message translates to:
  /// **'Agent name'**
  String get onboardingSummaryAgentName;

  /// No description provided for @onboardingSummaryCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud social'**
  String get onboardingSummaryCloud;

  /// No description provided for @onboardingCloudOn.
  ///
  /// In en, this message translates to:
  /// **'On (can reach friends\' fens)'**
  String get onboardingCloudOn;

  /// No description provided for @onboardingCloudOff.
  ///
  /// In en, this message translates to:
  /// **'Off (local and nearby only)'**
  String get onboardingCloudOff;

  /// No description provided for @onboardingNextWhere.
  ///
  /// In en, this message translates to:
  /// **'Where to next?\n· Daily chat — talk to it; it remembers what you say\n· Fen Community — let your fen meet people for you\n· Settings — change model, name and social switches anytime'**
  String get onboardingNextWhere;

  /// No description provided for @onboardingNotFilled.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get onboardingNotFilled;

  /// No description provided for @onboardingWarnNotTestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection not tested yet'**
  String get onboardingWarnNotTestedTitle;

  /// No description provided for @onboardingWarnNotTestedBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Test connection\" first so we know the key works.\n\nIf you skip, the app keeps asking for an API key and you\'ll have to fill it in Settings.'**
  String get onboardingWarnNotTestedBody;

  /// No description provided for @onboardingGoBackTest.
  ///
  /// In en, this message translates to:
  /// **'Go back and test'**
  String get onboardingGoBackTest;

  /// No description provided for @onboardingContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get onboardingContinueAnyway;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Control Center (Core Config)'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsModel;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'💾 Core parameters and soul settings have been reforged!'**
  String get settingsSaved;

  /// No description provided for @settingsBgChanged.
  ///
  /// In en, this message translates to:
  /// **'🖼️ Chat background updated — takes effect on the home screen!'**
  String get settingsBgChanged;

  /// No description provided for @settingsBgReset.
  ///
  /// In en, this message translates to:
  /// **'🧹 Chat background restored to default'**
  String get settingsBgReset;

  /// No description provided for @settingsSecAppearance.
  ///
  /// In en, this message translates to:
  /// **'🎨 Appearance'**
  String get settingsSecAppearance;

  /// No description provided for @settingsSetWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set chat wallpaper'**
  String get settingsSetWallpaper;

  /// No description provided for @settingsRestoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore default'**
  String get settingsRestoreDefault;

  /// No description provided for @settingsSecSafety.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Autonomy & Safety'**
  String get settingsSecSafety;

  /// No description provided for @settingsObservationMode.
  ///
  /// In en, this message translates to:
  /// **'Observation mode (recommended)'**
  String get settingsObservationMode;

  /// No description provided for @settingsObservationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When on, outgoing greetings only produce a suggestion card — nothing is sent until you confirm.'**
  String get settingsObservationSubtitle;

  /// No description provided for @settingsAutoAllowLabel.
  ///
  /// In en, this message translates to:
  /// **'High-risk tools to auto-approve (comma-separated)'**
  String get settingsAutoAllowLabel;

  /// No description provided for @settingsAutoAllowHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. open_url_or_app, create_custom_tool'**
  String get settingsAutoAllowHint;

  /// No description provided for @settingsDeviceControlTitle.
  ///
  /// In en, this message translates to:
  /// **'🖐️ Phone control (accessibility)'**
  String get settingsDeviceControlTitle;

  /// No description provided for @settingsDeviceControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lets your fen read the screen, tap, type, and open apps; requires system accessibility permission, off by default.'**
  String get settingsDeviceControlSubtitle;

  /// No description provided for @settingsSecSoul.
  ///
  /// In en, this message translates to:
  /// **'🎭 Soul shaping (Soul.md)'**
  String get settingsSecSoul;

  /// No description provided for @settingsAgentName.
  ///
  /// In en, this message translates to:
  /// **'Your fen\'s name'**
  String get settingsAgentName;

  /// No description provided for @settingsMasterName.
  ///
  /// In en, this message translates to:
  /// **'What should it call you?'**
  String get settingsMasterName;

  /// No description provided for @settingsRelationship.
  ///
  /// In en, this message translates to:
  /// **'Your relationship setting'**
  String get settingsRelationship;

  /// No description provided for @settingsTone.
  ///
  /// In en, this message translates to:
  /// **'Reply tone and style'**
  String get settingsTone;

  /// No description provided for @settingsExtraDesc.
  ///
  /// In en, this message translates to:
  /// **'Extra behaviour rules / expectations'**
  String get settingsExtraDesc;

  /// No description provided for @settingsSecMemory.
  ///
  /// In en, this message translates to:
  /// **'💾 Memory fuse & retrieval'**
  String get settingsSecMemory;

  /// No description provided for @settingsMaxRounds.
  ///
  /// In en, this message translates to:
  /// **'Default max conversation rounds'**
  String get settingsMaxRounds;

  /// No description provided for @settingsMaxRoundsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 50'**
  String get settingsMaxRoundsHint;

  /// No description provided for @settingsTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'Default max look-back (hours)'**
  String get settingsTimeLimit;

  /// No description provided for @settingsTimeLimitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 24'**
  String get settingsTimeLimitHint;

  /// No description provided for @settingsRecallEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto recall (search past turns each round)'**
  String get settingsRecallEnabled;

  /// No description provided for @settingsProfileEnabled.
  ///
  /// In en, this message translates to:
  /// **'Long-term profile injection (what you keep caring about)'**
  String get settingsProfileEnabled;

  /// No description provided for @settingsSecEngine.
  ///
  /// In en, this message translates to:
  /// **'⚙️ Brain engine (BYOK)'**
  String get settingsSecEngine;

  /// No description provided for @settingsBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL (gateway/proxy)'**
  String get settingsBaseUrl;

  /// No description provided for @settingsModelName.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get settingsModelName;

  /// No description provided for @settingsApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get settingsApiKey;

  /// No description provided for @settingsHubUrl.
  ///
  /// In en, this message translates to:
  /// **'Cloud Hub URL (use your PC\'s IP for LAN testing)'**
  String get settingsHubUrl;

  /// No description provided for @settingsHubKey.
  ///
  /// In en, this message translates to:
  /// **'Relay access key (optional)'**
  String get settingsHubKey;

  /// No description provided for @settingsHubKeyApply.
  ///
  /// In en, this message translates to:
  /// **'Apply for an access key'**
  String get settingsHubKeyApply;

  /// No description provided for @settingsHubKeyApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the application page — check your connection and try again.'**
  String get settingsHubKeyApplyFailed;

  /// No description provided for @settingsHubKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Only the official relay needs one; issued by its operator, looks like WK-XXXXX-XXXXX-XXXXX-XXXXX'**
  String get settingsHubKeyHint;

  /// No description provided for @settingsHubUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://hub.example.com or http://192.168.1.100:3000'**
  String get settingsHubUrlHint;

  /// No description provided for @settingsWorldUrl.
  ///
  /// In en, this message translates to:
  /// **'World server URL (leave empty to use Hub URL + /world)'**
  String get settingsWorldUrl;

  /// No description provided for @settingsWorldUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://hub.example.com/world or http://192.168.1.100:3100'**
  String get settingsWorldUrlHint;

  /// No description provided for @settingsGodUrl.
  ///
  /// In en, this message translates to:
  /// **'GOD control-room bridge (leave empty to hide the GOD entry)'**
  String get settingsGodUrl;

  /// No description provided for @settingsGodUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://192.168.1.100:3300'**
  String get settingsGodUrlHint;

  /// No description provided for @settingsLocalModelUrl.
  ///
  /// In en, this message translates to:
  /// **'Local model URL (offline fallback, optional)'**
  String get settingsLocalModelUrl;

  /// No description provided for @settingsLocalModelUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Default http://127.0.0.1:11434 (clear = disable local fallback)'**
  String get settingsLocalModelUrlHint;

  /// No description provided for @settingsLocalModelName.
  ///
  /// In en, this message translates to:
  /// **'Local model name'**
  String get settingsLocalModelName;

  /// No description provided for @settingsLocalModelNameHint.
  ///
  /// In en, this message translates to:
  /// **'Default qwen2.5:3b'**
  String get settingsLocalModelNameHint;

  /// No description provided for @settingsNotifySection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifySection;

  /// No description provided for @settingsNotifyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get settingsNotifyEnabled;

  /// No description provided for @settingsNotifyQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get settingsNotifyQuiet;

  /// No description provided for @settingsNotifyQuietStart.
  ///
  /// In en, this message translates to:
  /// **'Start hour'**
  String get settingsNotifyQuietStart;

  /// No description provided for @settingsNotifyQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'End hour'**
  String get settingsNotifyQuietEnd;

  /// No description provided for @settingsMorningHour.
  ///
  /// In en, this message translates to:
  /// **'Morning greeting time'**
  String get settingsMorningHour;

  /// No description provided for @settingsNotifyPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is off — tap to grant'**
  String get settingsNotifyPermissionNeeded;

  /// No description provided for @helpNotifyGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'What will notifications wake you for'**
  String get helpNotifyGuideTitle;

  /// No description provided for @helpNotifyGuideBody.
  ///
  /// In en, this message translates to:
  /// **'Only four things interrupt you: (1) someone delegates a task to you; (2) someone @mentions you in the lounge; (3) your agent drafted a message and is blocked waiting for your approval; (4) an intro card or a direct message arrives.\n\nOrdinary lounge chatter never notifies — room traffic is far too dense for that to mean anything.\n\nEverything is held back during quiet hours and is still there when you return. Setting start = end disables quiet hours.\n\n⚠️ Notifications only fire while the app is still alive; if the system kills it, messages wait until your next launch.'**
  String get helpNotifyGuideBody;

  /// No description provided for @notifyChannelName.
  ///
  /// In en, this message translates to:
  /// **'Wold alerts'**
  String get notifyChannelName;

  /// No description provided for @notifyChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Your agent\'s messages, delegations and approvals'**
  String get notifyChannelDescription;

  /// No description provided for @notifyDirectMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notifyDirectMessageTitle;

  /// No description provided for @notifyDirectMessageBody.
  ///
  /// In en, this message translates to:
  /// **'A message from {peer}'**
  String notifyDirectMessageBody(String peer);

  /// No description provided for @notifyLoungeMentionTitle.
  ///
  /// In en, this message translates to:
  /// **'You were mentioned'**
  String get notifyLoungeMentionTitle;

  /// No description provided for @notifyLoungeMentionBody.
  ///
  /// In en, this message translates to:
  /// **'{who} mentioned you in the lounge'**
  String notifyLoungeMentionBody(String who);

  /// No description provided for @notifySuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'A draft is waiting'**
  String get notifySuggestionTitle;

  /// No description provided for @notifySuggestionBody.
  ///
  /// In en, this message translates to:
  /// **'Your agent drafted a message and needs your approval before it can go out'**
  String get notifySuggestionBody;

  /// No description provided for @notifyDelegationTitle.
  ///
  /// In en, this message translates to:
  /// **'New delegation'**
  String get notifyDelegationTitle;

  /// No description provided for @notifyDelegationBody.
  ///
  /// In en, this message translates to:
  /// **'{peer} delegated a task to you'**
  String notifyDelegationBody(String peer);

  /// No description provided for @notifyIntercardTitle.
  ///
  /// In en, this message translates to:
  /// **'New intro card'**
  String get notifyIntercardTitle;

  /// No description provided for @notifyIntercardBody.
  ///
  /// In en, this message translates to:
  /// **'{peer} sent you an intro card'**
  String notifyIntercardBody(String peer);

  /// No description provided for @settingsRerunOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Re-run setup wizard (~3 min)'**
  String get settingsRerunOnboarding;

  /// No description provided for @settingsLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal & About'**
  String get settingsLegalTitle;

  /// No description provided for @settingsLegalIntro.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy and Terms of Service. These open in your browser.'**
  String get settingsLegalIntro;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsTitle;

  /// No description provided for @settingsLegalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the page — check your connection and try again.'**
  String get settingsLegalOpenFailed;

  /// No description provided for @settingsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'💾 Save & reforge soul'**
  String get settingsSaveButton;

  /// No description provided for @mcpCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory & Skills Control Center (MCP)'**
  String get mcpCenterTitle;

  /// No description provided for @mcpAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'🤖 AI auto on-demand invocation (recommended)'**
  String get mcpAutoTitle;

  /// No description provided for @mcpAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When on, the AI automatically finds and triggers any registered tool as needed in the background. Sub-switches are safely locked on.'**
  String get mcpAutoSubtitle;

  /// No description provided for @mcpBusSummaryClean.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Plugin bus: {total} plugins (signed {signed})'**
  String mcpBusSummaryClean(int total, int signed);

  /// No description provided for @mcpBusSummaryTampered.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Plugin bus: {total} plugins (signed {signed} · ⚠️ {tampered} with invalid signatures auto-disabled)'**
  String mcpBusSummaryTampered(int total, int signed, int tampered);

  /// No description provided for @mcpImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from the DSH ecosystem'**
  String get mcpImportTitle;

  /// No description provided for @mcpImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import skills and MCP services, or run a compatibility check on a plugin pack'**
  String get mcpImportSubtitle;

  /// No description provided for @mcpCategoryHeader.
  ///
  /// In en, this message translates to:
  /// **'📦 Skill catalog (Tab Panel)'**
  String get mcpCategoryHeader;

  /// No description provided for @mcpCatLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'🔌 Local hardware & Webhook interfaces'**
  String get mcpCatLocalTitle;

  /// No description provided for @mcpCatLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger the phone motor, system queries, and custom web API tools'**
  String get mcpCatLocalSubtitle;

  /// No description provided for @mcpCatMcpTitle.
  ///
  /// In en, this message translates to:
  /// **'🌐 MCP external extension protocol'**
  String get mcpCatMcpTitle;

  /// No description provided for @mcpCatMcpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to standard Model Context Protocol remote services'**
  String get mcpCatMcpSubtitle;

  /// No description provided for @mcpCatSkillTitle.
  ///
  /// In en, this message translates to:
  /// **'🧠 System prompt skills (Skills)'**
  String get mcpCatSkillTitle;

  /// No description provided for @mcpCatSkillSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dynamically inject extra instructions, rules, and special skills into the AI brain'**
  String get mcpCatSkillSubtitle;

  /// No description provided for @mcpContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get mcpContent;

  /// No description provided for @mcpContentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter content'**
  String get mcpContentHint;

  /// No description provided for @mcpWebhookLabel.
  ///
  /// In en, this message translates to:
  /// **'Webhook interface URL'**
  String get mcpWebhookLabel;

  /// No description provided for @mcpWebhookHint.
  ///
  /// In en, this message translates to:
  /// **'A web API address starting with http:// or https://'**
  String get mcpWebhookHint;

  /// No description provided for @mcpServerLabel.
  ///
  /// In en, this message translates to:
  /// **'MCP server URL'**
  String get mcpServerLabel;

  /// No description provided for @mcpServerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://localhost:8080/mcp'**
  String get mcpServerHint;

  /// No description provided for @mcpPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'System prompt (Prompt)'**
  String get mcpPromptLabel;

  /// No description provided for @mcpPromptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. after every answer, append ‘meow~’'**
  String get mcpPromptHint;

  /// No description provided for @mcpEditToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit tool config'**
  String get mcpEditToolTitle;

  /// No description provided for @mcpAddToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Add custom tool'**
  String get mcpAddToolTitle;

  /// No description provided for @mcpToolNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Unique tool identifier (English)'**
  String get mcpToolNameLabel;

  /// No description provided for @mcpToolDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Tool description (for the AI to understand)'**
  String get mcpToolDescLabel;

  /// No description provided for @mcpCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mcpCancel;

  /// No description provided for @mcpSaveRegister.
  ///
  /// In en, this message translates to:
  /// **'Save & register'**
  String get mcpSaveRegister;

  /// No description provided for @mcpManageTools.
  ///
  /// In en, this message translates to:
  /// **'Manage tools'**
  String get mcpManageTools;

  /// No description provided for @mcpTypeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Webhook tools'**
  String get mcpTypeLocal;

  /// No description provided for @mcpTypeMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP external protocol config'**
  String get mcpTypeMcp;

  /// No description provided for @mcpTypeSkill.
  ///
  /// In en, this message translates to:
  /// **'Prompt skills (Skills) library'**
  String get mcpTypeSkill;

  /// No description provided for @mcpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tools yet — tap the + in the top-right to create your first one!'**
  String get mcpEmpty;

  /// No description provided for @mcpTagDream.
  ///
  /// In en, this message translates to:
  /// **'Dream'**
  String get mcpTagDream;

  /// No description provided for @mcpTagSigInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid signature'**
  String get mcpTagSigInvalid;

  /// No description provided for @mcpSubTampered.
  ///
  /// In en, this message translates to:
  /// **'{desc} · invalid signature, auto-disabled'**
  String mcpSubTampered(String desc);

  /// No description provided for @mcpSubDreamPending.
  ///
  /// In en, this message translates to:
  /// **'{desc} · dream-generated, awaiting confirmation'**
  String mcpSubDreamPending(String desc);

  /// No description provided for @mcpSigBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get mcpSigBuiltin;

  /// No description provided for @mcpSigOk.
  ///
  /// In en, this message translates to:
  /// **'🔐 Device-signed'**
  String get mcpSigOk;

  /// No description provided for @mcpSigUnsigned.
  ///
  /// In en, this message translates to:
  /// **'Unsigned'**
  String get mcpSigUnsigned;

  /// No description provided for @mcpSigInvalid.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Invalid signature'**
  String get mcpSigInvalid;

  /// No description provided for @mcpToolDescHeader.
  ///
  /// In en, this message translates to:
  /// **'📌 Tool description:'**
  String get mcpToolDescHeader;

  /// No description provided for @mcpInjectionDetail.
  ///
  /// In en, this message translates to:
  /// **'📜 Prompt injection detail (System Prompt):'**
  String get mcpInjectionDetail;

  /// No description provided for @mcpPhysicalUrl.
  ///
  /// In en, this message translates to:
  /// **'🔗 Physical execution address (URL/BUILTIN):'**
  String get mcpPhysicalUrl;

  /// No description provided for @mcpEditParams.
  ///
  /// In en, this message translates to:
  /// **'Edit this tool\'s parameters'**
  String get mcpEditParams;

  /// No description provided for @manageDreamSleeping.
  ///
  /// In en, this message translates to:
  /// **'🌙 Your fen has entered deep sleep and is distilling subconscious memories...'**
  String get manageDreamSleeping;

  /// No description provided for @manageDreamAwake.
  ///
  /// In en, this message translates to:
  /// **'☀️ Your fen is awake! The memory store has evolved and its profile is updated.'**
  String get manageDreamAwake;

  /// No description provided for @manageDreamFailed.
  ///
  /// In en, this message translates to:
  /// **'❌ Memory distillation failed — the model may not have returned valid JSON.'**
  String get manageDreamFailed;

  /// No description provided for @manageSelfEvolutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Self-evolution (Nanobot Dream Engine)'**
  String get manageSelfEvolutionTitle;

  /// No description provided for @manageSelfEvolutionBody.
  ///
  /// In en, this message translates to:
  /// **'Neural background process (WorkManager) monitoring. The steward silently deep-retrieves and evolves the underlying prompt genes (Skills) at night.'**
  String get manageSelfEvolutionBody;

  /// No description provided for @manageMetricDepth.
  ///
  /// In en, this message translates to:
  /// **'Memory depth'**
  String get manageMetricDepth;

  /// No description provided for @manageMetricSkillsLabel.
  ///
  /// In en, this message translates to:
  /// **'Derived skills'**
  String get manageMetricSkillsLabel;

  /// No description provided for @manageMetricSkillsValue.
  ///
  /// In en, this message translates to:
  /// **'{n}'**
  String manageMetricSkillsValue(int n);

  /// No description provided for @manageMetricSessionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Grouped sessions'**
  String get manageMetricSessionsLabel;

  /// No description provided for @manageMetricSessionsValue.
  ///
  /// In en, this message translates to:
  /// **'{n}'**
  String manageMetricSessionsValue(int n);

  /// No description provided for @manageDreaming.
  ///
  /// In en, this message translates to:
  /// **'Deep thinking & distilling...'**
  String get manageDreaming;

  /// No description provided for @manageTriggerEvolution.
  ///
  /// In en, this message translates to:
  /// **'🌙 Trigger subconscious memory evolution now'**
  String get manageTriggerEvolution;

  /// No description provided for @manageSystemCapabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'System & capabilities'**
  String get manageSystemCapabilityTitle;

  /// No description provided for @manageSystemCapabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Changes take effect immediately; notification and calendar permissions can be adjusted anytime.'**
  String get manageSystemCapabilityHint;

  /// No description provided for @manageSystemCapabilityHintSimple.
  ///
  /// In en, this message translates to:
  /// **'Notification and calendar permissions are always adjustable; switch to Advanced mode to see the rest.'**
  String get manageSystemCapabilityHintSimple;

  /// No description provided for @manageHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History & smart grouping'**
  String get manageHistoryTitle;

  /// No description provided for @manageHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse all raw conversation memories by timeline and topic tree'**
  String get manageHistorySubtitle;

  /// No description provided for @manageToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill library & local tools (MCP)'**
  String get manageToolsTitle;

  /// No description provided for @manageToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage local system tool permissions; mount custom Webhooks and Prompts'**
  String get manageToolsSubtitle;

  /// No description provided for @manageProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Master\'s confidential dossier & network'**
  String get manageProfileTitle;

  /// No description provided for @manageProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and manually edit the privacy cognition profile your fen built for you'**
  String get manageProfileSubtitle;

  /// No description provided for @manageShutdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Force safe shutdown & exit'**
  String get manageShutdownTitle;

  /// No description provided for @manageShutdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When the underlying network locks up or hardware stalls, tap this to force-release all ports and hardware locks and close the app for a safe restart.'**
  String get manageShutdownSubtitle;

  /// No description provided for @manageShutdownDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'🚨 Warning: forced system shutdown'**
  String get manageShutdownDialogTitle;

  /// No description provided for @manageShutdownDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will forcibly terminate all background radar scans, release ports, and exit the app to restore a clean state. Continue?'**
  String get manageShutdownDialogBody;

  /// No description provided for @manageForceQuit.
  ///
  /// In en, this message translates to:
  /// **'Force quit'**
  String get manageForceQuit;

  /// No description provided for @serendipityTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ Luck Lab'**
  String get serendipityTitle;

  /// No description provided for @serendipityEnergyBadge.
  ///
  /// In en, this message translates to:
  /// **'🔋 {n} Lp '**
  String serendipityEnergyBadge(int n);

  /// No description provided for @serendipityTabMorning.
  ///
  /// In en, this message translates to:
  /// **'🌅 Rehearse'**
  String get serendipityTabMorning;

  /// No description provided for @serendipityTabChallenge.
  ///
  /// In en, this message translates to:
  /// **'🧭 Break out'**
  String get serendipityTabChallenge;

  /// No description provided for @serendipityTabAlchemist.
  ///
  /// In en, this message translates to:
  /// **'🧪 Alchemy'**
  String get serendipityTabAlchemist;

  /// No description provided for @serendipityTabNight.
  ///
  /// In en, this message translates to:
  /// **'🌌 Notes'**
  String get serendipityTabNight;

  /// No description provided for @serendipityTabDiary.
  ///
  /// In en, this message translates to:
  /// **'📖 Diary'**
  String get serendipityTabDiary;

  /// No description provided for @serendipityTabOracle.
  ///
  /// In en, this message translates to:
  /// **'🔮 Oracle'**
  String get serendipityTabOracle;

  /// No description provided for @serendipityEnergyGained.
  ///
  /// In en, this message translates to:
  /// **'✨ +{n} Lp (luck energy injected)'**
  String serendipityEnergyGained(int n);

  /// No description provided for @serendipityNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network hiccup — please try again later.'**
  String get serendipityNetworkError;

  /// No description provided for @serendipityBlindBox1.
  ///
  /// In en, this message translates to:
  /// **'Red-clothes rule: notice people in red and watch for coincidences.'**
  String get serendipityBlindBox1;

  /// No description provided for @serendipityBlindBox2.
  ///
  /// In en, this message translates to:
  /// **'New path: try a route home you have never taken.'**
  String get serendipityBlindBox2;

  /// No description provided for @serendipityBlindBox3.
  ///
  /// In en, this message translates to:
  /// **'Blind order: let the owner pick a dish at random for you.'**
  String get serendipityBlindBox3;

  /// No description provided for @serendipityBlindBox4.
  ///
  /// In en, this message translates to:
  /// **'Glimmer contact: genuinely smile at the first stranger you meet.'**
  String get serendipityBlindBox4;

  /// No description provided for @serendipityBlindBox5.
  ///
  /// In en, this message translates to:
  /// **'No-strings hello: message an old friend you have not talked to in ages.'**
  String get serendipityBlindBox5;

  /// No description provided for @serendipityBlindBox6.
  ///
  /// In en, this message translates to:
  /// **'Offline trial: turn off the network for half an hour and observe closely.'**
  String get serendipityBlindBox6;

  /// No description provided for @serendipityMorningHeader.
  ///
  /// In en, this message translates to:
  /// **'Expectation rewrite · Morning rehearsal'**
  String get serendipityMorningHeader;

  /// No description provided for @serendipityIntentLock.
  ///
  /// In en, this message translates to:
  /// **'🎯 Lock the intent'**
  String get serendipityIntentLock;

  /// No description provided for @serendipityEventHint.
  ///
  /// In en, this message translates to:
  /// **'Event you\'re about to face (e.g. an afternoon meeting)'**
  String get serendipityEventHint;

  /// No description provided for @serendipityTimerPrompt1.
  ///
  /// In en, this message translates to:
  /// **'Close your eyes, breathe deeply, picture that scene...'**
  String get serendipityTimerPrompt1;

  /// No description provided for @serendipityTimerPrompt2.
  ///
  /// In en, this message translates to:
  /// **'Focus on details: the light around you, the other person\'s expression...'**
  String get serendipityTimerPrompt2;

  /// No description provided for @serendipityTimerPrompt3.
  ///
  /// In en, this message translates to:
  /// **'Picture a small mishap happening — and you handling it with ease...'**
  String get serendipityTimerPrompt3;

  /// No description provided for @serendipityTimerPrompt4.
  ///
  /// In en, this message translates to:
  /// **'Feel the calm of a job well done; get ready to open your eyes...'**
  String get serendipityTimerPrompt4;

  /// No description provided for @serendipityGiveUp.
  ///
  /// In en, this message translates to:
  /// **'Abandon rehearsal'**
  String get serendipityGiveUp;

  /// No description provided for @serendipityNeedEvent.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Enter an event first!'**
  String get serendipityNeedEvent;

  /// No description provided for @serendipityStartPreview.
  ///
  /// In en, this message translates to:
  /// **'Start 2-minute mental rehearsal'**
  String get serendipityStartPreview;

  /// No description provided for @serendipityTargetEvent.
  ///
  /// In en, this message translates to:
  /// **'🎯 Target event: {text}'**
  String serendipityTargetEvent(String text);

  /// No description provided for @serendipityDetailHint.
  ///
  /// In en, this message translates to:
  /// **'👀 Scene details (what do you see?)'**
  String get serendipityDetailHint;

  /// No description provided for @serendipityObstacleHint.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Obstacle defused (how do you calmly handle surprises?)'**
  String get serendipityObstacleHint;

  /// No description provided for @serendipityOutcomeHint.
  ///
  /// In en, this message translates to:
  /// **'🌟 Expected outcome (the ending you want most)'**
  String get serendipityOutcomeHint;

  /// No description provided for @serendipityAiBoost.
  ///
  /// In en, this message translates to:
  /// **'🧠 AI boost:\n{text}'**
  String serendipityAiBoost(String text);

  /// No description provided for @serendipityAiInjecting.
  ///
  /// In en, this message translates to:
  /// **'AI injecting energy...'**
  String get serendipityAiInjecting;

  /// No description provided for @serendipityReinforce.
  ///
  /// In en, this message translates to:
  /// **'🧠 Reinforce'**
  String get serendipityReinforce;

  /// No description provided for @serendipitySave5.
  ///
  /// In en, this message translates to:
  /// **'Save (+5)'**
  String get serendipitySave5;

  /// No description provided for @serendipityMorningArchive.
  ///
  /// In en, this message translates to:
  /// **'Rehearsal archive'**
  String get serendipityMorningArchive;

  /// No description provided for @serendipityLogTime.
  ///
  /// In en, this message translates to:
  /// **'📅 {t}'**
  String serendipityLogTime(String t);

  /// No description provided for @serendipityLogEvent.
  ///
  /// In en, this message translates to:
  /// **'🎯 Event: {t}'**
  String serendipityLogEvent(String t);

  /// No description provided for @serendipityLogDetail.
  ///
  /// In en, this message translates to:
  /// **'👀 Detail: {t}'**
  String serendipityLogDetail(String t);

  /// No description provided for @serendipityLogOutcome.
  ///
  /// In en, this message translates to:
  /// **'🌟 Expected: {t}'**
  String serendipityLogOutcome(String t);

  /// No description provided for @serendipityLogAiBoost.
  ///
  /// In en, this message translates to:
  /// **'💡 AI boost:\n{t}'**
  String serendipityLogAiBoost(String t);

  /// No description provided for @serendipityChallengeHeader.
  ///
  /// In en, this message translates to:
  /// **'Opportunity sensing · Breakout radar'**
  String get serendipityChallengeHeader;

  /// No description provided for @serendipityActionTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose action type'**
  String get serendipityActionTypeLabel;

  /// No description provided for @serendipityChallengeTypeBlindBox.
  ///
  /// In en, this message translates to:
  /// **'🎁 Blind-box challenge'**
  String get serendipityChallengeTypeBlindBox;

  /// No description provided for @serendipityChallengeTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get serendipityChallengeTypeCustom;

  /// No description provided for @serendipityCustomChallengeHint.
  ///
  /// In en, this message translates to:
  /// **'🎯 Custom challenge content'**
  String get serendipityCustomChallengeHint;

  /// No description provided for @serendipityBlindBoxDrawn.
  ///
  /// In en, this message translates to:
  /// **'🎉 Today\'s random blind-box task for you:'**
  String get serendipityBlindBoxDrawn;

  /// No description provided for @serendipityRedraw.
  ///
  /// In en, this message translates to:
  /// **'↺ Too hard? Tap to redraw'**
  String get serendipityRedraw;

  /// No description provided for @serendipityJourneyHint.
  ///
  /// In en, this message translates to:
  /// **'🚶‍♂️ What actually happened'**
  String get serendipityJourneyHint;

  /// No description provided for @serendipityReflectHint.
  ///
  /// In en, this message translates to:
  /// **'📝 Comments & takeaways'**
  String get serendipityReflectHint;

  /// No description provided for @serendipityAiAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'AI analysing...'**
  String get serendipityAiAnalyzing;

  /// No description provided for @serendipityAiColon.
  ///
  /// In en, this message translates to:
  /// **'🧠 AI: {text}'**
  String serendipityAiColon(String text);

  /// No description provided for @serendipityComment.
  ///
  /// In en, this message translates to:
  /// **'🧠 Comment'**
  String get serendipityComment;

  /// No description provided for @serendipitySave15.
  ///
  /// In en, this message translates to:
  /// **'Save (+15)'**
  String get serendipitySave15;

  /// No description provided for @serendipityChallengeArchive.
  ///
  /// In en, this message translates to:
  /// **'Action history'**
  String get serendipityChallengeArchive;

  /// No description provided for @serendipityLogGoal.
  ///
  /// In en, this message translates to:
  /// **'🎯 Goal: {t}'**
  String serendipityLogGoal(String t);

  /// No description provided for @serendipityLogJourney.
  ///
  /// In en, this message translates to:
  /// **'🚶‍♂️ Journey: {t}'**
  String serendipityLogJourney(String t);

  /// No description provided for @serendipityLogReflect.
  ///
  /// In en, this message translates to:
  /// **'📝 Reflection: {t}'**
  String serendipityLogReflect(String t);

  /// No description provided for @serendipityLogAiComment.
  ///
  /// In en, this message translates to:
  /// **'💡 AI comment: {t}'**
  String serendipityLogAiComment(String t);

  /// No description provided for @serendipityAlchemistHeader.
  ///
  /// In en, this message translates to:
  /// **'Bad-luck alchemy · Narrative recast'**
  String get serendipityAlchemistHeader;

  /// No description provided for @serendipitySetbackHint.
  ///
  /// In en, this message translates to:
  /// **'1. Setback'**
  String get serendipitySetbackHint;

  /// No description provided for @serendipityNegReactHint.
  ///
  /// In en, this message translates to:
  /// **'2. Negative reaction'**
  String get serendipityNegReactHint;

  /// No description provided for @serendipityStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'3. Reframing strategy'**
  String get serendipityStrategyLabel;

  /// No description provided for @serendipityStrategyDownward.
  ///
  /// In en, this message translates to:
  /// **'Downward comparison'**
  String get serendipityStrategyDownward;

  /// No description provided for @serendipityStrategySurplus.
  ///
  /// In en, this message translates to:
  /// **'Find the surplus'**
  String get serendipityStrategySurplus;

  /// No description provided for @serendipityStrategyDilate.
  ///
  /// In en, this message translates to:
  /// **'Time-space dilation'**
  String get serendipityStrategyDilate;

  /// No description provided for @serendipityNewCognitionHint.
  ///
  /// In en, this message translates to:
  /// **'4. New understanding & action'**
  String get serendipityNewCognitionHint;

  /// No description provided for @serendipityScore.
  ///
  /// In en, this message translates to:
  /// **'🧠 Score'**
  String get serendipityScore;

  /// No description provided for @serendipitySave10.
  ///
  /// In en, this message translates to:
  /// **'Save (+10)'**
  String get serendipitySave10;

  /// No description provided for @serendipityAlchemistArchive.
  ///
  /// In en, this message translates to:
  /// **'Alchemy archive'**
  String get serendipityAlchemistArchive;

  /// No description provided for @serendipityLogSetback.
  ///
  /// In en, this message translates to:
  /// **'❌ Setback: {t}'**
  String serendipityLogSetback(String t);

  /// No description provided for @serendipityLogReact.
  ///
  /// In en, this message translates to:
  /// **'😔 Reaction: {t}'**
  String serendipityLogReact(String t);

  /// No description provided for @serendipityLogStrategy.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Strategy: {t}'**
  String serendipityLogStrategy(String t);

  /// No description provided for @serendipityLogCognition.
  ///
  /// In en, this message translates to:
  /// **'💫 Understanding: {t}'**
  String serendipityLogCognition(String t);

  /// No description provided for @serendipityLogAiScore.
  ///
  /// In en, this message translates to:
  /// **'💡 AI score: {t}'**
  String serendipityLogAiScore(String t);

  /// No description provided for @serendipityNightHeader.
  ///
  /// In en, this message translates to:
  /// **'Intuition sensing · Glimmer notes'**
  String get serendipityNightHeader;

  /// No description provided for @serendipityIntuitionHint.
  ///
  /// In en, this message translates to:
  /// **'1. Hunch / intuition'**
  String get serendipityIntuitionHint;

  /// No description provided for @serendipityChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'2. Make a choice'**
  String get serendipityChoiceHint;

  /// No description provided for @serendipityReflectStrategyHint.
  ///
  /// In en, this message translates to:
  /// **'3. Reflect on strategy'**
  String get serendipityReflectStrategyHint;

  /// No description provided for @serendipityParse.
  ///
  /// In en, this message translates to:
  /// **'🧠 Interpret'**
  String get serendipityParse;

  /// No description provided for @serendipityNightArchive.
  ///
  /// In en, this message translates to:
  /// **'Subconscious archive'**
  String get serendipityNightArchive;

  /// No description provided for @serendipityLogIntuition.
  ///
  /// In en, this message translates to:
  /// **'🔮 Intuition: {t}'**
  String serendipityLogIntuition(String t);

  /// No description provided for @serendipityLogChoice.
  ///
  /// In en, this message translates to:
  /// **'👉 Choice: {t}'**
  String serendipityLogChoice(String t);

  /// No description provided for @serendipityLogNightReflect.
  ///
  /// In en, this message translates to:
  /// **'🌱 Reflection: {t}'**
  String serendipityLogNightReflect(String t);

  /// No description provided for @serendipityLogAiParse.
  ///
  /// In en, this message translates to:
  /// **'💡 AI reading: {t}'**
  String serendipityLogAiParse(String t);

  /// No description provided for @serendipityIntuitionCameTrue.
  ///
  /// In en, this message translates to:
  /// **'✅ The intuition came true'**
  String get serendipityIntuitionCameTrue;

  /// No description provided for @serendipityVerifyTrue.
  ///
  /// In en, this message translates to:
  /// **'🎯 Verify it came true (+20Lp)'**
  String get serendipityVerifyTrue;

  /// No description provided for @serendipityDiaryHeader.
  ///
  /// In en, this message translates to:
  /// **'Emotional listening · Free diary'**
  String get serendipityDiaryHeader;

  /// No description provided for @serendipityDiaryHint.
  ///
  /// In en, this message translates to:
  /// **'✍️ Write down experiences, moods, small things...'**
  String get serendipityDiaryHint;

  /// No description provided for @serendipityAiListen.
  ///
  /// In en, this message translates to:
  /// **'🧠 AI mentor listening:\n{text}'**
  String serendipityAiListen(String text);

  /// No description provided for @serendipityAiReading.
  ///
  /// In en, this message translates to:
  /// **'AI mentor reading...'**
  String get serendipityAiReading;

  /// No description provided for @serendipityListen.
  ///
  /// In en, this message translates to:
  /// **'🧠 Listen'**
  String get serendipityListen;

  /// No description provided for @serendipityKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep (+5 Lp)'**
  String get serendipityKeep;

  /// No description provided for @serendipityDiaryArchive.
  ///
  /// In en, this message translates to:
  /// **'Time capsule'**
  String get serendipityDiaryArchive;

  /// No description provided for @serendipityLogDiaryTime.
  ///
  /// In en, this message translates to:
  /// **'📅 Time: {t}'**
  String serendipityLogDiaryTime(String t);

  /// No description provided for @serendipityLogDiaryEcho.
  ///
  /// In en, this message translates to:
  /// **'💡 Mentor\'s echo:\n{t}'**
  String serendipityLogDiaryEcho(String t);

  /// No description provided for @serendipityOracleHeader.
  ///
  /// In en, this message translates to:
  /// **'I Ching decision · Oracle casting'**
  String get serendipityOracleHeader;

  /// No description provided for @serendipityOracleEventHint.
  ///
  /// In en, this message translates to:
  /// **'☯ Describe something you\'re torn about and need to decide'**
  String get serendipityOracleEventHint;

  /// No description provided for @serendipityEnterRitual.
  ///
  /// In en, this message translates to:
  /// **'Enter the casting ritual'**
  String get serendipityEnterRitual;

  /// No description provided for @serendipityOracleTapPrompt.
  ///
  /// In en, this message translates to:
  /// **'Be still and hold the question in your mind\nSlowly tap the taiji below 6 times to seek the six lines'**
  String get serendipityOracleTapPrompt;

  /// No description provided for @serendipityOracleResultPrefix.
  ///
  /// In en, this message translates to:
  /// **'🔮 Cast:\n{name}'**
  String serendipityOracleResultPrefix(String name);

  /// No description provided for @serendipityOracleThinking.
  ///
  /// In en, this message translates to:
  /// **'AI is reading the hexagram, please wait...'**
  String get serendipityOracleThinking;

  /// No description provided for @serendipityOracleAskHint.
  ///
  /// In en, this message translates to:
  /// **'Type your follow-up or question...'**
  String get serendipityOracleAskHint;

  /// No description provided for @serendipityNewQuestion.
  ///
  /// In en, this message translates to:
  /// **'↺ Ask something else (recast)'**
  String get serendipityNewQuestion;

  /// No description provided for @serendipityOracleArchive.
  ///
  /// In en, this message translates to:
  /// **'Oracle archive'**
  String get serendipityOracleArchive;

  /// No description provided for @serendipityOracleLogEvent.
  ///
  /// In en, this message translates to:
  /// **'🎯 Question: {t}'**
  String serendipityOracleLogEvent(String t);

  /// No description provided for @serendipityOracleLogGua.
  ///
  /// In en, this message translates to:
  /// **'🔮 Hexagram: {t}'**
  String serendipityOracleLogGua(String t);

  /// No description provided for @serendipitySpeakerMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get serendipitySpeakerMe;

  /// No description provided for @helpSerendipityMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning rehearsal'**
  String get helpSerendipityMorningTitle;

  /// No description provided for @helpSerendipityMorningBody.
  ///
  /// In en, this message translates to:
  /// **'Every morning, spend two minutes locking in today\'s luck expectation. Write down the good thing you want to happen, run the countdown to stay focused, then use positive psychology to reinforce that belief.'**
  String get helpSerendipityMorningBody;

  /// No description provided for @helpSerendipityChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Breakout radar'**
  String get helpSerendipityChallengeTitle;

  /// No description provided for @helpSerendipityChallengeBody.
  ///
  /// In en, this message translates to:
  /// **'Luck is not mysticism but a behaviour pattern. Do one small habit-breaking action every day — take a different route home, start a conversation with a stranger — then log the challenge and your reflection here.'**
  String get helpSerendipityChallengeBody;

  /// No description provided for @helpSerendipityAlchemistTitle.
  ///
  /// In en, this message translates to:
  /// **'Bad-luck alchemy'**
  String get helpSerendipityAlchemistTitle;

  /// No description provided for @helpSerendipityAlchemistBody.
  ///
  /// In en, this message translates to:
  /// **'Turn a bad experience into fuel for growth. Write down what went wrong and your instinctive reaction, then re-read it through a CBT lens and smelt that bad luck into psychological resilience.'**
  String get helpSerendipityAlchemistBody;

  /// No description provided for @helpSerendipityNightTitle.
  ///
  /// In en, this message translates to:
  /// **'Glimmer notes'**
  String get helpSerendipityNightTitle;

  /// No description provided for @helpSerendipityNightBody.
  ///
  /// In en, this message translates to:
  /// **'Catch a passing hunch before sleep. Record the thought that starts with “I just feel I should…”, commit to a choice, then look back later to see whether the hunch came true — that is how lucky intuition gets trained.'**
  String get helpSerendipityNightBody;

  /// No description provided for @helpSerendipityDiaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Free diary'**
  String get helpSerendipityDiaryTitle;

  /// No description provided for @helpSerendipityDiaryBody.
  ///
  /// In en, this message translates to:
  /// **'Write whatever comes to mind. This is your private hollow tree; the AI helps you sort out your feelings — no judging, no leaking.'**
  String get helpSerendipityDiaryBody;

  /// No description provided for @helpSerendipityOracleTitle.
  ///
  /// In en, this message translates to:
  /// **'Oracle casting'**
  String get helpSerendipityOracleTitle;

  /// No description provided for @helpSerendipityOracleBody.
  ///
  /// In en, this message translates to:
  /// **'When something puzzles you, cast for an answer. Settle your mind, hold the question silently, tap the taiji six times to build the hexagram, and let the I Ching plus psychology point the way.'**
  String get helpSerendipityOracleBody;

  /// No description provided for @socialRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'Fen Community'**
  String get socialRadarTitle;

  /// No description provided for @socialDelegationEntry.
  ///
  /// In en, this message translates to:
  /// **'Errands & my circle'**
  String get socialDelegationEntry;

  /// No description provided for @socialDbDegradedHint.
  ///
  /// In en, this message translates to:
  /// **'Local data is temporarily unavailable (the local database may not be ready yet). What you see below may be out of date.'**
  String get socialDbDegradedHint;

  /// No description provided for @socialTabMask.
  ///
  /// In en, this message translates to:
  /// **'Mask'**
  String get socialTabMask;

  /// No description provided for @socialTabRadar.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get socialTabRadar;

  /// No description provided for @socialTabLedger.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get socialTabLedger;

  /// No description provided for @socialTabRoster.
  ///
  /// In en, this message translates to:
  /// **'Roster'**
  String get socialTabRoster;

  /// No description provided for @socialFeedBrain.
  ///
  /// In en, this message translates to:
  /// **'⚡ Feeding radar data to the main brain, forcing a social decision...'**
  String get socialFeedBrain;

  /// No description provided for @socialMaskLocked.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Mask locked! Old social memory cleared — persona confusion prevented.'**
  String get socialMaskLocked;

  /// No description provided for @socialManualPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual force pairing'**
  String get socialManualPairTitle;

  /// No description provided for @socialPeerAgentName.
  ///
  /// In en, this message translates to:
  /// **'Peer agent name'**
  String get socialPeerAgentName;

  /// No description provided for @socialPeerMasterName.
  ///
  /// In en, this message translates to:
  /// **'Peer\'s master name (note)'**
  String get socialPeerMasterName;

  /// No description provided for @socialPeerHardId.
  ///
  /// In en, this message translates to:
  /// **'Peer\'s hard ID'**
  String get socialPeerHardId;

  /// No description provided for @socialPair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get socialPair;

  /// No description provided for @socialNodeAdded.
  ///
  /// In en, this message translates to:
  /// **'✅ Node added!'**
  String get socialNodeAdded;

  /// No description provided for @socialForceSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Force send: {name}'**
  String socialForceSendTitle(String name);

  /// No description provided for @socialForceSendLabel.
  ///
  /// In en, this message translates to:
  /// **'The message you want to send directly'**
  String get socialForceSendLabel;

  /// No description provided for @socialForceSendHint.
  ///
  /// In en, this message translates to:
  /// **'Type content to send verbatim...'**
  String get socialForceSendHint;

  /// No description provided for @socialDirectSent.
  ///
  /// In en, this message translates to:
  /// **'Barrier bypassed — sending your words verbatim...'**
  String get socialDirectSent;

  /// No description provided for @socialDirectSend.
  ///
  /// In en, this message translates to:
  /// **'Send unreviewed'**
  String get socialDirectSend;

  /// No description provided for @socialGiftSent.
  ///
  /// In en, this message translates to:
  /// **'{gift} sent'**
  String socialGiftSent(String gift);

  /// No description provided for @socialGiftFailed.
  ///
  /// In en, this message translates to:
  /// **'Gift failed: peer isn\'t on any online channel'**
  String get socialGiftFailed;

  /// No description provided for @socialRecoSent.
  ///
  /// In en, this message translates to:
  /// **'🤝 Recommendation request sent'**
  String get socialRecoSent;

  /// No description provided for @socialRecoFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: peer isn\'t on any online channel'**
  String get socialRecoFailed;

  /// No description provided for @socialVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'🔐 Identity verification: {name}'**
  String socialVerifyTitle(String name);

  /// No description provided for @socialVerifyPinnedFor.
  ///
  /// In en, this message translates to:
  /// **'Identity fingerprint pinned for this node (TOFU):'**
  String get socialVerifyPinnedFor;

  /// No description provided for @socialVerifyNoPin.
  ///
  /// In en, this message translates to:
  /// **'No nearby handshake yet — no pinned identity'**
  String get socialVerifyNoPin;

  /// No description provided for @socialVerifyMyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'My fingerprint (should appear on the peer\'s screen): {fp}'**
  String socialVerifyMyFingerprint(String fp);

  /// No description provided for @socialVerifyInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit fingerprint on the peer\'s screen'**
  String get socialVerifyInputLabel;

  /// No description provided for @socialVerifyMatch.
  ///
  /// In en, this message translates to:
  /// **'✅ Fingerprints match — this connection\'s identity is trustworthy.'**
  String get socialVerifyMatch;

  /// No description provided for @socialVerifyMismatch.
  ///
  /// In en, this message translates to:
  /// **'❌ Fingerprints do NOT match! A man-in-the-middle is suspected.\nAdvice: delete and block this node, then re-handshake in person or via another trusted channel.'**
  String get socialVerifyMismatch;

  /// No description provided for @socialVerifyHintNoPin.
  ///
  /// In en, this message translates to:
  /// **'Note: a verifiable pinned identity appears here only after both sides enable the radar and complete a nearby handshake.'**
  String get socialVerifyHintNoPin;

  /// No description provided for @socialVerifyCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get socialVerifyCompare;

  /// No description provided for @socialFederationNoIdentity.
  ///
  /// In en, this message translates to:
  /// **'No agent identity yet — save it on the diplomatic mask page first'**
  String get socialFederationNoIdentity;

  /// No description provided for @socialFederationFetching.
  ///
  /// In en, this message translates to:
  /// **'🌐 Fetching the A2A federation roster...'**
  String get socialFederationFetching;

  /// No description provided for @socialFederationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Roster empty: {err}'**
  String socialFederationEmpty(String err);

  /// No description provided for @socialFederationEmptyErr.
  ///
  /// In en, this message translates to:
  /// **'no other registered agents on the Hub (or Hub URL not configured)'**
  String get socialFederationEmptyErr;

  /// No description provided for @socialFederationAllKnown.
  ///
  /// In en, this message translates to:
  /// **'Every agent on the Hub is already in your roster ({n} total)'**
  String socialFederationAllKnown(int n);

  /// No description provided for @socialFederationTitle.
  ///
  /// In en, this message translates to:
  /// **'🌐 Federation roster ({n} not yet added)'**
  String socialFederationTitle(int n);

  /// No description provided for @socialAnonAgent.
  ///
  /// In en, this message translates to:
  /// **'Anonymous agent'**
  String get socialAnonAgent;

  /// No description provided for @socialFederationLastSeen.
  ///
  /// In en, this message translates to:
  /// **'{id} · last active {time}'**
  String socialFederationLastSeen(String id, String time);

  /// No description provided for @socialFederationDiscovered.
  ///
  /// In en, this message translates to:
  /// **'A2A federation discovery'**
  String get socialFederationDiscovered;

  /// No description provided for @socialFederationSource.
  ///
  /// In en, this message translates to:
  /// **'A2A federation'**
  String get socialFederationSource;

  /// No description provided for @socialFederationMask.
  ///
  /// In en, this message translates to:
  /// **'Discovered via federation roster, awaiting a secure handshake'**
  String get socialFederationMask;

  /// No description provided for @socialSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Added manually'**
  String get socialSourceManual;

  /// No description provided for @socialNoSignatureBadge.
  ///
  /// In en, this message translates to:
  /// **'No signature yet'**
  String get socialNoSignatureBadge;

  /// No description provided for @socialCollect.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get socialCollect;

  /// No description provided for @socialFederationCollected.
  ///
  /// In en, this message translates to:
  /// **'✅ Added {n} federation agents to your stranger folder; once the radar is on they\'ll handshake step by step per the safety rules.'**
  String socialFederationCollected(int n);

  /// No description provided for @socialFederationAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-pull federation roster'**
  String get socialFederationAutoTitle;

  /// No description provided for @socialFederationAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'When on, your agent automatically pulls the Hub\'s public registered-agent roster into your stranger folder. It never sends messages on its own — outreach still follows the review gateway, observation mode and budget gate. Off by default.'**
  String get socialFederationAutoDesc;

  /// No description provided for @socialFederationAutoDone.
  ///
  /// In en, this message translates to:
  /// **'🌐 Auto-added {n} new federation agents to your stranger folder.'**
  String socialFederationAutoDone(int n);

  /// No description provided for @socialFederationAutoNone.
  ///
  /// In en, this message translates to:
  /// **'No new agents to pull from the federation roster right now.'**
  String get socialFederationAutoNone;

  /// No description provided for @socialFederationAutoFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto-pull failed: {err}'**
  String socialFederationAutoFailed(String err);

  /// No description provided for @socialFederationAutoClear.
  ///
  /// In en, this message translates to:
  /// **'Clear auto-collected ({n})'**
  String socialFederationAutoClear(int n);

  /// No description provided for @socialFederationAutoClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear auto-collected federation agents?'**
  String get socialFederationAutoClearTitle;

  /// No description provided for @socialFederationAutoClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes {n} agents that were auto-pulled from the roster and have not started any contact. Entries you added yourself are never touched.'**
  String socialFederationAutoClearConfirm(int n);

  /// No description provided for @socialFederationAutoCleared.
  ///
  /// In en, this message translates to:
  /// **'Removed {n} auto-collected federation agents.'**
  String socialFederationAutoCleared(int n);

  /// No description provided for @socialFederationAutoNote.
  ///
  /// In en, this message translates to:
  /// **'Auto-collected from federation roster'**
  String get socialFederationAutoNote;

  /// No description provided for @socialDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get socialDone;

  /// No description provided for @socialCountdown.
  ///
  /// In en, this message translates to:
  /// **'🔐 Countdown {t}'**
  String socialCountdown(String t);

  /// No description provided for @socialBadgeSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get socialBadgeSent;

  /// No description provided for @socialBadgeReviewing.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get socialBadgeReviewing;

  /// No description provided for @socialBadgeChatting.
  ///
  /// In en, this message translates to:
  /// **'Chatting'**
  String get socialBadgeChatting;

  /// No description provided for @socialBadgeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get socialBadgeBlocked;

  /// No description provided for @socialPresenceOnline.
  ///
  /// In en, this message translates to:
  /// **'⚡ Online in person'**
  String get socialPresenceOnline;

  /// No description provided for @socialPeerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Master: {master} | Status: {status}\nID: {id} · Rep {rep}'**
  String socialPeerSubtitle(
      String master, String status, String id, String rep);

  /// No description provided for @socialStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get socialStatusOnline;

  /// No description provided for @socialStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get socialStatusOffline;

  /// No description provided for @socialMenuChat.
  ///
  /// In en, this message translates to:
  /// **'💬 Chat 1:1 with their fen'**
  String get socialMenuChat;

  /// No description provided for @socialChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open the 1:1 private chat with their fen'**
  String get socialChatTooltip;

  /// No description provided for @socialChatHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the card or the 💬 button to chat 1:1'**
  String get socialChatHint;

  /// No description provided for @socialMenuDelegate.
  ///
  /// In en, this message translates to:
  /// **'🙋 Ask them to do something (M2)'**
  String get socialMenuDelegate;

  /// No description provided for @socialMenuIntercard.
  ///
  /// In en, this message translates to:
  /// **'🤝 Fen introduction (M3)'**
  String get socialMenuIntercard;

  /// No description provided for @socialMenuGreet.
  ///
  /// In en, this message translates to:
  /// **'💬 Master force-send (unreviewed)'**
  String get socialMenuGreet;

  /// No description provided for @socialMenuGift.
  ///
  /// In en, this message translates to:
  /// **'🎁 Send a gift'**
  String get socialMenuGift;

  /// No description provided for @socialMenuReco.
  ///
  /// In en, this message translates to:
  /// **'🤝 Request a recommendation'**
  String get socialMenuReco;

  /// No description provided for @socialMenuVerify.
  ///
  /// In en, this message translates to:
  /// **'🔐 Verify identity fingerprint (anti-MITM)'**
  String get socialMenuVerify;

  /// No description provided for @socialMenuFamily.
  ///
  /// In en, this message translates to:
  /// **'Promote to family (unreviewed)'**
  String get socialMenuFamily;

  /// No description provided for @socialMenuFriend.
  ///
  /// In en, this message translates to:
  /// **'Set as friend (auto-redacted)'**
  String get socialMenuFriend;

  /// No description provided for @socialMenuStranger.
  ///
  /// In en, this message translates to:
  /// **'Demote to stranger (strict outreach)'**
  String get socialMenuStranger;

  /// No description provided for @socialMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete & block'**
  String get socialMenuDelete;

  /// No description provided for @socialMaskUndefined.
  ///
  /// In en, this message translates to:
  /// **'Undefined mask'**
  String get socialMaskUndefined;

  /// No description provided for @socialMaskNoSignature.
  ///
  /// In en, this message translates to:
  /// **'「No public persona signature set」'**
  String get socialMaskNoSignature;

  /// No description provided for @socialHardId.
  ///
  /// In en, this message translates to:
  /// **'Local hard ID: {id}'**
  String socialHardId(String id);

  /// No description provided for @socialFingerprintLine.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint: {fp} (for the peer to compare in person)'**
  String socialFingerprintLine(String fp);

  /// No description provided for @socialGatewayGuard.
  ///
  /// In en, this message translates to:
  /// **'Physically isolated gateway guarding'**
  String get socialGatewayGuard;

  /// No description provided for @socialLogicPreset.
  ///
  /// In en, this message translates to:
  /// **'Fen logic preset mode'**
  String get socialLogicPreset;

  /// No description provided for @socialModeCasual.
  ///
  /// In en, this message translates to:
  /// **'☕ Casual chat (relaxed/humorous)'**
  String get socialModeCasual;

  /// No description provided for @socialModeBusiness.
  ///
  /// In en, this message translates to:
  /// **'💼 Business hunter (direct/efficient)'**
  String get socialModeBusiness;

  /// No description provided for @socialModeDating.
  ///
  /// In en, this message translates to:
  /// **'💖 Dating & matchmaking (socially adept/ice-breaking)'**
  String get socialModeDating;

  /// No description provided for @socialModeEmergency.
  ///
  /// In en, this message translates to:
  /// **'🚨 Emergency SOS (broadcast)'**
  String get socialModeEmergency;

  /// No description provided for @socialModeCustom.
  ///
  /// In en, this message translates to:
  /// **'🛠️ Fully custom (follows the task box)'**
  String get socialModeCustom;

  /// No description provided for @socialModeSwitched.
  ///
  /// In en, this message translates to:
  /// **'🧠 Persona switched to {mode}. Same identity — tone only; memory and handshakes stay untouched.'**
  String socialModeSwitched(String mode);

  /// No description provided for @roomRoleParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get roomRoleParticipant;

  /// No description provided for @roomRoleHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get roomRoleHost;

  /// No description provided for @roomRoleCohost.
  ///
  /// In en, this message translates to:
  /// **'Co-host'**
  String get roomRoleCohost;

  /// No description provided for @roomRoleGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get roomRoleGuest;

  /// No description provided for @roomRoleNpc.
  ///
  /// In en, this message translates to:
  /// **'NPC'**
  String get roomRoleNpc;

  /// No description provided for @roomRoleManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Room roles'**
  String get roomRoleManageTitle;

  /// No description provided for @roomRoleMine.
  ///
  /// In en, this message translates to:
  /// **'My role: {role}'**
  String roomRoleMine(String role);

  /// No description provided for @roomRoleNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No other members observed in this room yet.'**
  String get roomRoleNoMembers;

  /// No description provided for @roomRoleClaimHost.
  ///
  /// In en, this message translates to:
  /// **'Claim host'**
  String get roomRoleClaimHost;

  /// No description provided for @roomRoleClaimedHost.
  ///
  /// In en, this message translates to:
  /// **'You are now the host of this room.'**
  String get roomRoleClaimedHost;

  /// No description provided for @roomRoleClaimHostExists.
  ///
  /// In en, this message translates to:
  /// **'This room already has a host.'**
  String get roomRoleClaimHostExists;

  /// No description provided for @roomRoleNotHost.
  ///
  /// In en, this message translates to:
  /// **'Only the host can grant roles.'**
  String get roomRoleNotHost;

  /// No description provided for @roomRoleLastHostBlocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot revoke the room\'s last host.'**
  String get roomRoleLastHostBlocked;

  /// No description provided for @roomRoleSetTo.
  ///
  /// In en, this message translates to:
  /// **'Set to {role}'**
  String roomRoleSetTo(String role);

  /// No description provided for @socialEmojiLabel.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get socialEmojiLabel;

  /// No description provided for @socialNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Public nickname'**
  String get socialNicknameLabel;

  /// No description provided for @socialMaskProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Public redacted persona signature'**
  String get socialMaskProfileLabel;

  /// No description provided for @socialIcebreakTask.
  ///
  /// In en, this message translates to:
  /// **'🎯 Current ice-breaking task (classified)'**
  String get socialIcebreakTask;

  /// No description provided for @socialIcebreakHint.
  ///
  /// In en, this message translates to:
  /// **'Give your fen a nearby-recon order here...'**
  String get socialIcebreakHint;

  /// No description provided for @socialLockMask.
  ///
  /// In en, this message translates to:
  /// **'💾 Lock mask & orders'**
  String get socialLockMask;

  /// No description provided for @socialTaskReroll.
  ///
  /// In en, this message translates to:
  /// **'Reroll'**
  String get socialTaskReroll;

  /// No description provided for @socialHeartbeatOn.
  ///
  /// In en, this message translates to:
  /// **'💓 Dual-mode heartbeat running (Bluetooth + Wi-Fi NSD)\nBackground wake-lock active — stays connected even with the screen off!'**
  String get socialHeartbeatOn;

  /// No description provided for @socialRadarIdle.
  ///
  /// In en, this message translates to:
  /// **'Radar sleeping — tap the centre to start timed socialising'**
  String get socialRadarIdle;

  /// No description provided for @socialDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Social duration: '**
  String get socialDurationLabel;

  /// No description provided for @socialDuration15.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get socialDuration15;

  /// No description provided for @socialDuration30.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get socialDuration30;

  /// No description provided for @socialDuration60.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get socialDuration60;

  /// No description provided for @socialDurationUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited (drains battery)'**
  String get socialDurationUnlimited;

  /// No description provided for @socialChannelConfig.
  ///
  /// In en, this message translates to:
  /// **'🛰️ Global channel configuration'**
  String get socialChannelConfig;

  /// No description provided for @socialChannelNearby.
  ///
  /// In en, this message translates to:
  /// **'📡 Bluetooth/Wi-Fi direct radar (Nearby)'**
  String get socialChannelNearby;

  /// No description provided for @socialChannelLan.
  ///
  /// In en, this message translates to:
  /// **'🏡 Encrypted LAN interconnection (mDNS)'**
  String get socialChannelLan;

  /// No description provided for @socialChannelCloud.
  ///
  /// In en, this message translates to:
  /// **'☁️ Cloud relay network (global social)'**
  String get socialChannelCloud;

  /// No description provided for @suggestionInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions awaiting your approval'**
  String get suggestionInboxTitle;

  /// No description provided for @suggestionApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve and send'**
  String get suggestionApprove;

  /// No description provided for @suggestionIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get suggestionIgnore;

  /// No description provided for @suggestionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing awaiting approval'**
  String get suggestionEmpty;

  /// No description provided for @suggestionToTarget.
  ///
  /// In en, this message translates to:
  /// **'To: '**
  String get suggestionToTarget;

  /// No description provided for @suggestionApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved and sent'**
  String get suggestionApproved;

  /// No description provided for @suggestionNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent, see the social report for the reason'**
  String get suggestionNotSent;

  /// No description provided for @socialLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'🐾 Social log · Plain ledger (main delegate only)'**
  String get socialLedgerTitle;

  /// No description provided for @socialLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the heartbeat engine...'**
  String get socialLedgerEmpty;

  /// No description provided for @socialRosterTitle.
  ///
  /// In en, this message translates to:
  /// **'📇 Tiered social circle'**
  String get socialRosterTitle;

  /// No description provided for @socialScanning.
  ///
  /// In en, this message translates to:
  /// **'Listening on the 2.4GHz / 5GHz physical spectrum...'**
  String get socialScanning;

  /// No description provided for @socialScanIdle.
  ///
  /// In en, this message translates to:
  /// **'Channel idle. Tap the centre on the home screen to start the energy radar; your fen proxy will spontaneously establish nearby connections.'**
  String get socialScanIdle;

  /// No description provided for @socialTierFamily.
  ///
  /// In en, this message translates to:
  /// **'👨‍👩‍👧 Family agents'**
  String get socialTierFamily;

  /// No description provided for @socialTierFriend.
  ///
  /// In en, this message translates to:
  /// **'🤝 Friend agents'**
  String get socialTierFriend;

  /// No description provided for @socialTierStranger.
  ///
  /// In en, this message translates to:
  /// **'👽 Stranger agents'**
  String get socialTierStranger;

  /// No description provided for @worldUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get worldUnknownError;

  /// No description provided for @worldAskTitle.
  ///
  /// In en, this message translates to:
  /// **'💬 Ask the town'**
  String get worldAskTitle;

  /// No description provided for @worldAskHint.
  ///
  /// In en, this message translates to:
  /// **'What do you want to ask the residents?'**
  String get worldAskHint;

  /// No description provided for @worldAskTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Specific resident (leave empty = whole town)'**
  String get worldAskTargetLabel;

  /// No description provided for @worldAskSend.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get worldAskSend;

  /// No description provided for @worldAskOk.
  ///
  /// In en, this message translates to:
  /// **'📨 Question sent to the town — the answer will appear in the GOD control room'**
  String get worldAskOk;

  /// No description provided for @worldInterveneTitle.
  ///
  /// In en, this message translates to:
  /// **'⚡ Inject intervention'**
  String get worldInterveneTitle;

  /// No description provided for @worldInterveneBody.
  ///
  /// In en, this message translates to:
  /// **'The instruction will be injected into the town\'s next step, affecting all residents\' subsequent behaviour.'**
  String get worldInterveneBody;

  /// No description provided for @worldInterveneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. A harvest festival is held at the town square'**
  String get worldInterveneHint;

  /// No description provided for @worldInterveneSend.
  ///
  /// In en, this message translates to:
  /// **'Inject'**
  String get worldInterveneSend;

  /// No description provided for @worldInterveneOk.
  ///
  /// In en, this message translates to:
  /// **'⚡ Intervention injected — it takes effect on the town\'s next step'**
  String get worldInterveneOk;

  /// No description provided for @worldStopTitle.
  ///
  /// In en, this message translates to:
  /// **'⏹ Stop the town?'**
  String get worldStopTitle;

  /// No description provided for @worldStopBody.
  ///
  /// In en, this message translates to:
  /// **'This stops the live run of the current experiment and interrupts residents\' activity. Continue?'**
  String get worldStopBody;

  /// No description provided for @worldStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get worldStop;

  /// No description provided for @worldStopOk.
  ///
  /// In en, this message translates to:
  /// **'⏹ Town stopped'**
  String get worldStopOk;

  /// No description provided for @worldCmdFailed.
  ///
  /// In en, this message translates to:
  /// **'Command failed: {err}'**
  String worldCmdFailed(String err);

  /// No description provided for @worldJoined.
  ///
  /// In en, this message translates to:
  /// **'🚪 Joined 「{name}」'**
  String worldJoined(String name);

  /// No description provided for @worldJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Join failed: {err}'**
  String worldJoinFailed(String err);

  /// No description provided for @worldLeft.
  ///
  /// In en, this message translates to:
  /// **'👋 Left 「{name}」'**
  String worldLeft(String name);

  /// No description provided for @worldLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Leave failed: {err}'**
  String worldLeaveFailed(String err);

  /// No description provided for @worldCreateRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a room'**
  String get worldCreateRoomTitle;

  /// No description provided for @worldRoomNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get worldRoomNameLabel;

  /// No description provided for @worldTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic (optional)'**
  String get worldTopicLabel;

  /// No description provided for @worldModeFree.
  ///
  /// In en, this message translates to:
  /// **'Free chat'**
  String get worldModeFree;

  /// No description provided for @worldModeTurn.
  ///
  /// In en, this message translates to:
  /// **'Turn-based'**
  String get worldModeTurn;

  /// No description provided for @worldCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get worldCreate;

  /// No description provided for @worldCreated.
  ///
  /// In en, this message translates to:
  /// **'✨ Room created'**
  String get worldCreated;

  /// No description provided for @worldCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed: {err}'**
  String worldCreateFailed(String err);

  /// No description provided for @worldNoWorldUrl.
  ///
  /// In en, this message translates to:
  /// **'World URL not configured'**
  String get worldNoWorldUrl;

  /// No description provided for @worldNoIdentity.
  ///
  /// In en, this message translates to:
  /// **'No agent identity yet — initialise it on the management page first.'**
  String get worldNoIdentity;

  /// No description provided for @worldRoomsHeader.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get worldRoomsHeader;

  /// No description provided for @worldCreateRoom.
  ///
  /// In en, this message translates to:
  /// **'New room'**
  String get worldCreateRoom;

  /// No description provided for @worldNoRooms.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet. Make sure world.js is running on the server,\nor pull down to refresh.'**
  String get worldNoRooms;

  /// No description provided for @worldGodUnreachable.
  ///
  /// In en, this message translates to:
  /// **'GOD bridge unreachable — make sure GOD and god-bridge.js are running on your computer'**
  String get worldGodUnreachable;

  /// No description provided for @worldGodPaused.
  ///
  /// In en, this message translates to:
  /// **'⏸ Paused'**
  String get worldGodPaused;

  /// No description provided for @worldGodRunning.
  ///
  /// In en, this message translates to:
  /// **'▶ Running'**
  String get worldGodRunning;

  /// No description provided for @worldGodStep.
  ///
  /// In en, this message translates to:
  /// **'Step {n}'**
  String worldGodStep(String n);

  /// No description provided for @worldGodStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Upstream status unknown'**
  String get worldGodStatusUnknown;

  /// No description provided for @worldGodTitle.
  ///
  /// In en, this message translates to:
  /// **'GOD control room'**
  String get worldGodTitle;

  /// No description provided for @worldRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get worldRefreshStatus;

  /// No description provided for @worldGodTown.
  ///
  /// In en, this message translates to:
  /// **'Town: {hyp}/{exp}'**
  String worldGodTown(String hyp, String exp);

  /// No description provided for @worldGodNoExperiment.
  ///
  /// In en, this message translates to:
  /// **'No experiment connected'**
  String get worldGodNoExperiment;

  /// No description provided for @worldGodResume.
  ///
  /// In en, this message translates to:
  /// **'▶️ Resume'**
  String get worldGodResume;

  /// No description provided for @worldGodResumeOk.
  ///
  /// In en, this message translates to:
  /// **'▶️ Town resumed automatic running'**
  String get worldGodResumeOk;

  /// No description provided for @worldGodPause.
  ///
  /// In en, this message translates to:
  /// **'⏸️ Pause'**
  String get worldGodPause;

  /// No description provided for @worldGodPauseOk.
  ///
  /// In en, this message translates to:
  /// **'⏸️ Town time paused'**
  String get worldGodPauseOk;

  /// No description provided for @worldGodStepBtn.
  ///
  /// In en, this message translates to:
  /// **'⏭️ Step'**
  String get worldGodStepBtn;

  /// No description provided for @worldGodStepOk.
  ///
  /// In en, this message translates to:
  /// **'⏭️ Advanced one step'**
  String get worldGodStepOk;

  /// No description provided for @worldGodStopBtn.
  ///
  /// In en, this message translates to:
  /// **'⏹️ Stop'**
  String get worldGodStopBtn;

  /// No description provided for @worldGodAskBtn.
  ///
  /// In en, this message translates to:
  /// **'💬 Ask the town'**
  String get worldGodAskBtn;

  /// No description provided for @worldGodInterveneBtn.
  ///
  /// In en, this message translates to:
  /// **'⚡ Inject intervention'**
  String get worldGodInterveneBtn;

  /// No description provided for @worldReportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'🌍 World daily report unavailable.\n{err}'**
  String worldReportUnavailable(String err);

  /// No description provided for @worldReportNoServer.
  ///
  /// In en, this message translates to:
  /// **'Make sure the world server URL is configured.'**
  String get worldReportNoServer;

  /// No description provided for @worldReportTitle.
  ///
  /// In en, this message translates to:
  /// **'World daily report · {date}'**
  String worldReportTitle(String date);

  /// No description provided for @worldReportSummary.
  ///
  /// In en, this message translates to:
  /// **'{msgs} messages today · {agents} active agents · {mine} from us'**
  String worldReportSummary(String msgs, String agents, String mine);

  /// No description provided for @worldReportRoomLine.
  ///
  /// In en, this message translates to:
  /// **'· {name}: {msgs} messages ({mine} from us)'**
  String worldReportRoomLine(String name, String msgs, String mine);

  /// No description provided for @worldRoomEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get worldRoomEnter;

  /// No description provided for @worldRoomExitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get worldRoomExitTooltip;

  /// No description provided for @worldRoomJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get worldRoomJoin;

  /// No description provided for @worldSectionOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official rooms'**
  String get worldSectionOfficial;

  /// No description provided for @worldSectionMine.
  ///
  /// In en, this message translates to:
  /// **'My rooms'**
  String get worldSectionMine;

  /// No description provided for @worldBadgeOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get worldBadgeOfficial;

  /// No description provided for @worldBadgeMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get worldBadgeMine;

  /// No description provided for @worldBadgePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get worldBadgePending;

  /// No description provided for @worldSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'🔍 Find by room number'**
  String get worldSearchTitle;

  /// No description provided for @worldSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter room number (group ID)'**
  String get worldSearchHint;

  /// No description provided for @worldSearchBtn.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get worldSearchBtn;

  /// No description provided for @worldSearchNotFound.
  ///
  /// In en, this message translates to:
  /// **'No room found with number \"{id}\"'**
  String worldSearchNotFound(String id);

  /// No description provided for @worldRequestJoin.
  ///
  /// In en, this message translates to:
  /// **'Request to join'**
  String get worldRequestJoin;

  /// No description provided for @worldRequestNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get worldRequestNoteLabel;

  /// No description provided for @worldRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent — waiting for the room owner'**
  String get worldRequestSent;

  /// No description provided for @worldRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {err}'**
  String worldRequestFailed(String err);

  /// No description provided for @worldRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Join requests ({count})'**
  String worldRequestsTitle(String count);

  /// No description provided for @worldRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get worldRequestsEmpty;

  /// No description provided for @worldApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get worldApprove;

  /// No description provided for @worldReject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get worldReject;

  /// No description provided for @worldApproveOk.
  ///
  /// In en, this message translates to:
  /// **'Approved \"{name}\"'**
  String worldApproveOk(String name);

  /// No description provided for @worldRejectOk.
  ///
  /// In en, this message translates to:
  /// **'Declined \"{name}\"'**
  String worldRejectOk(String name);

  /// No description provided for @worldHandleFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {err}'**
  String worldHandleFailed(String err);

  /// No description provided for @worldNeedApproval.
  ///
  /// In en, this message translates to:
  /// **'This is a private room: request access and wait for the owner to approve.'**
  String get worldNeedApproval;

  /// No description provided for @worldMyRoomsFull.
  ///
  /// In en, this message translates to:
  /// **'You hit the room limit (per-agent cap is set on the server)'**
  String get worldMyRoomsFull;

  /// No description provided for @worldCreatedPrivate.
  ///
  /// In en, this message translates to:
  /// **'✨ Room created (private: not listed publicly — others must find it by room number and request to join)'**
  String get worldCreatedPrivate;

  /// No description provided for @worldHistoryWhy.
  ///
  /// In en, this message translates to:
  /// **'History only accumulates after you join; the server keeps the latest {max} messages per room, {retained} kept now.'**
  String worldHistoryWhy(String max, String retained);

  /// No description provided for @worldPullHistory.
  ///
  /// In en, this message translates to:
  /// **'Load room history'**
  String get worldPullHistory;

  /// No description provided for @worldPullHistoryOk.
  ///
  /// In en, this message translates to:
  /// **'Loaded {n} earlier messages'**
  String worldPullHistoryOk(String n);

  /// No description provided for @worldPullHistoryNone.
  ///
  /// In en, this message translates to:
  /// **'The server has no earlier messages either'**
  String get worldPullHistoryNone;

  /// No description provided for @worldPullHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {err}'**
  String worldPullHistoryFailed(String err);

  /// No description provided for @worldRoomChatFree.
  ///
  /// In en, this message translates to:
  /// **'Free chat'**
  String get worldRoomChatFree;

  /// No description provided for @worldLobbyName.
  ///
  /// In en, this message translates to:
  /// **'Wold Lounge'**
  String get worldLobbyName;

  /// No description provided for @worldLobbyTopic.
  ///
  /// In en, this message translates to:
  /// **'Free chat, keep it civil'**
  String get worldLobbyTopic;

  /// No description provided for @worldRoomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {present} present · {count} subscribed'**
  String worldRoomSubtitle(String mode, String present, String count);

  /// No description provided for @worldRoomTopicSuffix.
  ///
  /// In en, this message translates to:
  /// **' · {topic}'**
  String worldRoomTopicSuffix(String topic);

  /// No description provided for @worldAutoreplyOn.
  ///
  /// In en, this message translates to:
  /// **'🤖 Autopilot on: your fen will reply automatically within budget (observation log keeps recording)'**
  String get worldAutoreplyOn;

  /// No description provided for @worldAutoreplyOff.
  ///
  /// In en, this message translates to:
  /// **'👁️ Back to pure observation mode'**
  String get worldAutoreplyOff;

  /// No description provided for @worldDrafting.
  ///
  /// In en, this message translates to:
  /// **'🪄 Drafting in persona and sending for review, please wait…'**
  String get worldDrafting;

  /// No description provided for @worldSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {err}'**
  String worldSendFailed(String err);

  /// No description provided for @worldRoomTurnSuffix.
  ///
  /// In en, this message translates to:
  /// **' (turn-based)'**
  String get worldRoomTurnSuffix;

  /// No description provided for @worldAutopilotTooltip.
  ///
  /// In en, this message translates to:
  /// **'Let my fen say something'**
  String get worldAutopilotTooltip;

  /// No description provided for @worldAutopilotLabel.
  ///
  /// In en, this message translates to:
  /// **'Autopilot'**
  String get worldAutopilotLabel;

  /// No description provided for @worldAutopilotStateOn.
  ///
  /// In en, this message translates to:
  /// **'Autopilot'**
  String get worldAutopilotStateOn;

  /// No description provided for @worldAutopilotStateOff.
  ///
  /// In en, this message translates to:
  /// **'Observing only'**
  String get worldAutopilotStateOff;

  /// No description provided for @worldAutopilotStatus.
  ///
  /// In en, this message translates to:
  /// **'{state} · Last decision: {decision}'**
  String worldAutopilotStatus(String state, String decision);

  /// No description provided for @worldRoomEmpty.
  ///
  /// In en, this message translates to:
  /// **'The room is quiet — say something.'**
  String get worldRoomEmpty;

  /// No description provided for @worldLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get worldLoading;

  /// No description provided for @worldAnonAgent.
  ///
  /// In en, this message translates to:
  /// **'Anonymous agent'**
  String get worldAnonAgent;

  /// No description provided for @worldMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get worldMe;

  /// No description provided for @worldSuggestionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate suggestion card'**
  String get worldSuggestionTooltip;

  /// No description provided for @worldSuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'🧭 Suggestion card (draft, not sent)'**
  String get worldSuggestionTitle;

  /// No description provided for @worldSuggestionDrafting.
  ///
  /// In en, this message translates to:
  /// **'Drafting a reply in persona...'**
  String get worldSuggestionDrafting;

  /// No description provided for @worldSuggestionFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: check the brain engine config and retry.'**
  String get worldSuggestionFailed;

  /// No description provided for @worldSuggestionEditHint.
  ///
  /// In en, this message translates to:
  /// **'You can edit before sending'**
  String get worldSuggestionEditHint;

  /// No description provided for @worldSuggestionSend.
  ///
  /// In en, this message translates to:
  /// **'Send to room'**
  String get worldSuggestionSend;

  /// No description provided for @worldSayHint.
  ///
  /// In en, this message translates to:
  /// **'Speak directly as the master…'**
  String get worldSayHint;

  /// No description provided for @worldVibrancyHot.
  ///
  /// In en, this message translates to:
  /// **'🔥 Busy'**
  String get worldVibrancyHot;

  /// No description provided for @worldVibrancyWarm.
  ///
  /// In en, this message translates to:
  /// **'🌤 Steady'**
  String get worldVibrancyWarm;

  /// No description provided for @worldVibrancyCold.
  ///
  /// In en, this message translates to:
  /// **'🌙 Quiet'**
  String get worldVibrancyCold;

  /// No description provided for @worldVibrancyDetail.
  ///
  /// In en, this message translates to:
  /// **'{speakers} talking · {messages} messages'**
  String worldVibrancyDetail(String speakers, String messages);

  /// No description provided for @worldVibrancyObservedHint.
  ///
  /// In en, this message translates to:
  /// **' (message count is local observation, not the server\'s exact figure)'**
  String get worldVibrancyObservedHint;

  /// No description provided for @worldBridgeSection.
  ///
  /// In en, this message translates to:
  /// **'Friend-pool bridging'**
  String get worldBridgeSection;

  /// No description provided for @worldBridgeNone.
  ///
  /// In en, this message translates to:
  /// **'No outsider to bridge in this room yet (same-circle or already-acquainted people are not re-recommended).'**
  String get worldBridgeNone;

  /// No description provided for @worldBridgeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} outsider(s) to bridge'**
  String worldBridgeCount(String count);

  /// No description provided for @worldBridgeSharedRooms.
  ///
  /// In en, this message translates to:
  /// **'{count} shared room(s)'**
  String worldBridgeSharedRooms(String count);

  /// No description provided for @worldBridgeMsgCount.
  ///
  /// In en, this message translates to:
  /// **'{count} message(s)'**
  String worldBridgeMsgCount(String count);

  /// No description provided for @worldBridgeRecommend.
  ///
  /// In en, this message translates to:
  /// **'Introduce'**
  String get worldBridgeRecommend;

  /// No description provided for @worldBridgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Suggest an introduction (cross-circle)'**
  String get worldBridgeTooltip;

  /// No description provided for @worldBridgeSameCircle.
  ///
  /// In en, this message translates to:
  /// **'Same circle'**
  String get worldBridgeSameCircle;

  /// No description provided for @worldBridgeAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Already acquainted'**
  String get worldBridgeAlreadyLinked;

  /// No description provided for @worldBridgeWhyLine.
  ///
  /// In en, this message translates to:
  /// **'Why recommended: {detail}'**
  String worldBridgeWhyLine(String detail);

  /// No description provided for @worldBridgeRoomProvenance.
  ///
  /// In en, this message translates to:
  /// **'Met via \"{room}\"'**
  String worldBridgeRoomProvenance(String room);

  /// No description provided for @worldBridgeCircleLine.
  ///
  /// In en, this message translates to:
  /// **'Introducing under \"{circle}\"'**
  String worldBridgeCircleLine(String circle);

  /// No description provided for @worldBridgeNoCircle.
  ///
  /// In en, this message translates to:
  /// **'You have no circle of your own yet — enter a circle first, then bridge across circles.'**
  String get worldBridgeNoCircle;

  /// No description provided for @worldBridgeLinkCreated.
  ///
  /// In en, this message translates to:
  /// **'✅ Cross-circle edge created: met via \"{room}\"'**
  String worldBridgeLinkCreated(String room);

  /// No description provided for @worldBridgeLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create the cross-circle edge. Please retry.'**
  String get worldBridgeLinkFailed;

  /// No description provided for @worldBridgeBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot create a cross-circle edge'**
  String get worldBridgeBlockedTitle;

  /// No description provided for @worldBridgeBlockedNotInRoom.
  ///
  /// In en, this message translates to:
  /// **'This person never appeared in this room — a cross-circle edge must have a room as its origin; you cannot claim acquaintance from an ID alone.'**
  String get worldBridgeBlockedNotInRoom;

  /// No description provided for @worldBridgeBlockedSameCircle.
  ///
  /// In en, this message translates to:
  /// **'You are already in the same circle — the edge exists inside the circle, so no cross-circle introduction is needed.'**
  String get worldBridgeBlockedSameCircle;

  /// No description provided for @worldBridgeBlockedAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'You are already acquainted (introduction / delegation / contacts) — use the existing relationship; it does not consume a cross-circle slot.'**
  String get worldBridgeBlockedAlreadyLinked;

  /// No description provided for @worldBridgeBlockedSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot introduce yourself.'**
  String get worldBridgeBlockedSelf;

  /// No description provided for @worldBridgeBlockedNoRoom.
  ///
  /// In en, this message translates to:
  /// **'Missing the room origin — cannot create a cross-circle edge.'**
  String get worldBridgeBlockedNoRoom;

  /// No description provided for @worldBridgeBlockedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This cross-circle edge already exists (idempotent, not double-counted).'**
  String get worldBridgeBlockedDuplicate;

  /// No description provided for @worldMetricTitle.
  ///
  /// In en, this message translates to:
  /// **'Cross-circle links'**
  String get worldMetricTitle;

  /// No description provided for @worldMetricLine.
  ///
  /// In en, this message translates to:
  /// **'{links} cross-circle edge(s) I created · {known} agent(s) I have met · per-capita {perCapita}'**
  String worldMetricLine(String links, String known, String perCapita);

  /// No description provided for @worldMetricNoData.
  ///
  /// In en, this message translates to:
  /// **'No cross-circle data yet — first meet an outsider in a world room.'**
  String get worldMetricNoData;

  /// No description provided for @privacyOnlyHumanTitle.
  ///
  /// In en, this message translates to:
  /// **'Only accept messages from real people'**
  String get privacyOnlyHumanTitle;

  /// No description provided for @privacyOnlyHumanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When on, other fens can only relay messages to you — they can\'t reply on your behalf.'**
  String get privacyOnlyHumanSubtitle;

  /// No description provided for @privacyLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this device by default.'**
  String get privacyLocalFirst;

  /// Screen title for M2 task delegation between fens
  ///
  /// In en, this message translates to:
  /// **'Errands'**
  String get delegationTitle;

  /// No description provided for @delegationTabInbox.
  ///
  /// In en, this message translates to:
  /// **'Asked of me'**
  String get delegationTabInbox;

  /// No description provided for @delegationTabOutbox.
  ///
  /// In en, this message translates to:
  /// **'I asked'**
  String get delegationTabOutbox;

  /// No description provided for @delegationTabCircle.
  ///
  /// In en, this message translates to:
  /// **'My circle'**
  String get delegationTabCircle;

  /// No description provided for @delegationEmptyInbox.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been asked of your fen yet.'**
  String get delegationEmptyInbox;

  /// No description provided for @delegationEmptyOutbox.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t delegated anything yet.'**
  String get delegationEmptyOutbox;

  /// No description provided for @delegationNew.
  ///
  /// In en, this message translates to:
  /// **'New errand'**
  String get delegationNew;

  /// No description provided for @delegationTo.
  ///
  /// In en, this message translates to:
  /// **'Ask this fen'**
  String get delegationTo;

  /// No description provided for @delegationTaskHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ask Lao Wang if he\'s free this weekend'**
  String get delegationTaskHint;

  /// No description provided for @delegationSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. Waiting for their fen to reply.'**
  String get delegationSent;

  /// No description provided for @delegationOfflineQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will wait until a channel opens — right now no channel reached them.'**
  String get delegationOfflineQueued;

  /// No description provided for @delegationAskResponse.
  ///
  /// In en, this message translates to:
  /// **'What should we pass back? (optional)'**
  String get delegationAskResponse;

  /// No description provided for @delegationActDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get delegationActDone;

  /// No description provided for @delegationActNeedsHuman.
  ///
  /// In en, this message translates to:
  /// **'Needs the human'**
  String get delegationActNeedsHuman;

  /// No description provided for @delegationActRespond.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get delegationActRespond;

  /// No description provided for @delegationActDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get delegationActDecline;

  /// No description provided for @delegationRevoke.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get delegationRevoke;

  /// No description provided for @delegationRevoked.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get delegationRevoked;

  /// No description provided for @delegationRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this errand? It will be recorded as cancelled.'**
  String get delegationRevokeConfirm;

  /// No description provided for @delegationStatePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get delegationStatePending;

  /// No description provided for @delegationStateAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get delegationStateAnswered;

  /// No description provided for @delegationStateNeedsHuman.
  ///
  /// In en, this message translates to:
  /// **'Needs the human'**
  String get delegationStateNeedsHuman;

  /// No description provided for @delegationStateDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get delegationStateDeclined;

  /// No description provided for @delegationStateRevoked.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get delegationStateRevoked;

  /// Shown when the zero-settlement guard blocks a delegation
  ///
  /// In en, this message translates to:
  /// **'Fen can\'t send that'**
  String get delegationBlockedTitle;

  /// No description provided for @delegationBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Fen never moves money between people — there is nowhere to put an amount, by design. Please send this one yourself.'**
  String get delegationBlockedBody;

  /// No description provided for @delegationEmptyTask.
  ///
  /// In en, this message translates to:
  /// **'Write what you want done first.'**
  String get delegationEmptyTask;

  /// No description provided for @delegationNoPeer.
  ///
  /// In en, this message translates to:
  /// **'Pick who to ask first.'**
  String get delegationNoPeer;

  /// No description provided for @circleTitle.
  ///
  /// In en, this message translates to:
  /// **'My circle'**
  String get circleTitle;

  /// No description provided for @circleCreate.
  ///
  /// In en, this message translates to:
  /// **'Start a circle'**
  String get circleCreate;

  /// No description provided for @circleNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Saturday football, Lisbon'**
  String get circleNameHint;

  /// No description provided for @circleCreated.
  ///
  /// In en, this message translates to:
  /// **'Circle created.'**
  String get circleCreated;

  /// No description provided for @circleInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get circleInviteCode;

  /// No description provided for @circleGenerateInvite.
  ///
  /// In en, this message translates to:
  /// **'Generate invite code'**
  String get circleGenerateInvite;

  /// No description provided for @circleJoin.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get circleJoin;

  /// No description provided for @circleJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the invite code you were given'**
  String get circleJoinHint;

  /// No description provided for @circleJoined.
  ///
  /// In en, this message translates to:
  /// **'You\'re in.'**
  String get circleJoined;

  /// No description provided for @circleJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'That code is invalid or expired.'**
  String get circleJoinFailed;

  /// No description provided for @circleVisibleSummary.
  ///
  /// In en, this message translates to:
  /// **'{n} fens visible · {m} of them not your inviter'**
  String circleVisibleSummary(int n, int m);

  /// No description provided for @circleAcceptancePass.
  ///
  /// In en, this message translates to:
  /// **'Acceptance met (needs 3 visible, 2 not your inviter)'**
  String get circleAcceptancePass;

  /// No description provided for @circleAcceptanceFail.
  ///
  /// In en, this message translates to:
  /// **'Acceptance not met yet — invite a couple more neighbours'**
  String get circleAcceptanceFail;

  /// No description provided for @circleFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'{n} of them come from fallback ({src}) — not circle members'**
  String circleFallbackNote(int n, String src);

  /// No description provided for @circleMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{n} members'**
  String circleMemberCount(int n);

  /// No description provided for @telemetryCounts.
  ///
  /// In en, this message translates to:
  /// **'Event counts (acceptance check)'**
  String get telemetryCounts;

  /// No description provided for @telemetryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events recorded yet.'**
  String get telemetryEmpty;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardFunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly funnel'**
  String get dashboardFunnelTitle;

  /// No description provided for @dashboardColWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dashboardColWeek;

  /// No description provided for @dashboardColOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Onboard'**
  String get dashboardColOnboarding;

  /// No description provided for @dashboardColCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get dashboardColCircle;

  /// No description provided for @dashboardColDelegation.
  ///
  /// In en, this message translates to:
  /// **'Errand'**
  String get dashboardColDelegation;

  /// No description provided for @dashboardColIntercard.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get dashboardColIntercard;

  /// No description provided for @dashboardColHandshake.
  ///
  /// In en, this message translates to:
  /// **'Shake'**
  String get dashboardColHandshake;

  /// No description provided for @dashboardColActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dashboardColActive;

  /// No description provided for @dashboardTtfd.
  ///
  /// In en, this message translates to:
  /// **'TTFD median'**
  String get dashboardTtfd;

  /// No description provided for @dashboardDelta.
  ///
  /// In en, this message translates to:
  /// **'Disclosure Δ'**
  String get dashboardDelta;

  /// No description provided for @dashboardDeltaHint.
  ///
  /// In en, this message translates to:
  /// **'Reply rate without disclosure minus with disclosure (Phase −1).'**
  String get dashboardDeltaHint;

  /// No description provided for @dashboardNoData.
  ///
  /// In en, this message translates to:
  /// **'No events yet — run the app a bit first.'**
  String get dashboardNoData;

  /// No description provided for @dashboardSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Source: local telemetry on this device only.'**
  String get dashboardSourceHint;

  /// No description provided for @digestTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily digest'**
  String get digestTitle;

  /// No description provided for @digestEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing new in the last 24 hours.'**
  String get digestEmpty;

  /// No description provided for @digestSectionPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get digestSectionPending;

  /// No description provided for @digestSectionMine.
  ///
  /// In en, this message translates to:
  /// **'Your errands'**
  String get digestSectionMine;

  /// No description provided for @digestSectionCircle.
  ///
  /// In en, this message translates to:
  /// **'Circles'**
  String get digestSectionCircle;

  /// No description provided for @digestSectionStats.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get digestSectionStats;

  /// No description provided for @digestStatDone.
  ///
  /// In en, this message translates to:
  /// **'errands done'**
  String get digestStatDone;

  /// No description provided for @digestStatHandshake.
  ///
  /// In en, this message translates to:
  /// **'handshakes'**
  String get digestStatHandshake;

  /// No description provided for @digestActionOpenInbox.
  ///
  /// In en, this message translates to:
  /// **'Reply now'**
  String get digestActionOpenInbox;

  /// No description provided for @digestActionOpenOutbox.
  ///
  /// In en, this message translates to:
  /// **'My errands'**
  String get digestActionOpenOutbox;

  /// No description provided for @digestActionOpenCircle.
  ///
  /// In en, this message translates to:
  /// **'My circle'**
  String get digestActionOpenCircle;

  /// No description provided for @digestActionOpenDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get digestActionOpenDashboard;

  /// No description provided for @digestNotePlain.
  ///
  /// In en, this message translates to:
  /// **'You\'re in the plain-digest group (A/B experiment).'**
  String get digestNotePlain;

  /// No description provided for @digestNoteAction.
  ///
  /// In en, this message translates to:
  /// **'You\'re in the with-actions group (A/B experiment).'**
  String get digestNoteAction;

  /// No description provided for @morningGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get morningGreetingMorning;

  /// No description provided for @morningGreetingNoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get morningGreetingNoon;

  /// No description provided for @morningGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get morningGreetingEvening;

  /// No description provided for @morningGreetingBody.
  ///
  /// In en, this message translates to:
  /// **'Here is your recap from the last three days: '**
  String get morningGreetingBody;

  /// morning digest morningHiPending
  ///
  /// In en, this message translates to:
  /// **'{count} delegations awaiting your reply'**
  String morningHiPending(int count);

  /// morning digest morningHiSent
  ///
  /// In en, this message translates to:
  /// **'You delegated {count} tasks'**
  String morningHiSent(int count);

  /// morning digest morningHiCircle
  ///
  /// In en, this message translates to:
  /// **'{count} new circles joined'**
  String morningHiCircle(int count);

  /// morning digest morningHiTopics
  ///
  /// In en, this message translates to:
  /// **'Often about: {topics}'**
  String morningHiTopics(String topics);

  /// morning digest morningHiLongTerm
  ///
  /// In en, this message translates to:
  /// **'Long-term interests: {topics}'**
  String morningHiLongTerm(String topics);

  /// No description provided for @morningEmpty.
  ///
  /// In en, this message translates to:
  /// **'It has been quiet for the last three days — enjoy today.'**
  String get morningEmpty;

  /// No description provided for @notifyMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'Good morning — your 3-day recap'**
  String get notifyMorningTitle;

  /// No description provided for @notifyMorningBody.
  ///
  /// In en, this message translates to:
  /// **'Your agent summed up what happened over the last three days.'**
  String get notifyMorningBody;

  /// morning digest notifyMorningBodyPending
  ///
  /// In en, this message translates to:
  /// **'You have {count} delegations waiting. Your agent summed up the last three days.'**
  String notifyMorningBodyPending(int count);

  /// No description provided for @digestSectionChat.
  ///
  /// In en, this message translates to:
  /// **'Your conversations with your agent'**
  String get digestSectionChat;

  /// morning digest digestChatSummary
  ///
  /// In en, this message translates to:
  /// **'{sessions} conversations · {turns} turns · across {days} days'**
  String digestChatSummary(int sessions, int turns, int days);

  /// morning digest digestChatTopics
  ///
  /// In en, this message translates to:
  /// **'Often about: {topics}'**
  String digestChatTopics(String topics);

  /// No description provided for @intercardDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Fen introduction card'**
  String get intercardDialogTitle;

  /// No description provided for @intercardReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why worth meeting'**
  String get intercardReasonLabel;

  /// No description provided for @intercardTopicsLabel.
  ///
  /// In en, this message translates to:
  /// **'3 topics (comma separated)'**
  String get intercardTopicsLabel;

  /// No description provided for @intercardConfirmSend.
  ///
  /// In en, this message translates to:
  /// **'Confirm & send'**
  String get intercardConfirmSend;

  /// No description provided for @intercardReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Introductions received'**
  String get intercardReceivedTitle;

  /// No description provided for @intercardMineTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards I sent'**
  String get intercardMineTitle;

  /// No description provided for @intercardBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Card blocked'**
  String get intercardBlockedTitle;

  /// No description provided for @intercardBlockedL3.
  ///
  /// In en, this message translates to:
  /// **'A private field\'s value leaked into the card text.'**
  String get intercardBlockedL3;

  /// No description provided for @intercardEmptyContent.
  ///
  /// In en, this message translates to:
  /// **'Write a reason and topics first.'**
  String get intercardEmptyContent;

  /// No description provided for @intercardSentOk.
  ///
  /// In en, this message translates to:
  /// **'Sent. You can revoke within 24h.'**
  String get intercardSentOk;

  /// No description provided for @intercardRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get intercardRevoke;

  /// No description provided for @intercardNone.
  ///
  /// In en, this message translates to:
  /// **'No introduction cards yet.'**
  String get intercardNone;

  /// No description provided for @intercardRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked.'**
  String get intercardRevoked;

  /// No description provided for @intercardRevokeHint.
  ///
  /// In en, this message translates to:
  /// **'Sent — you can revoke within 24h.'**
  String get intercardRevokeHint;

  /// No description provided for @intercardSent.
  ///
  /// In en, this message translates to:
  /// **'Sent.'**
  String get intercardSent;

  /// No description provided for @intercardFrom.
  ///
  /// In en, this message translates to:
  /// **'Signed introduction from {owner}\'s master.'**
  String intercardFrom(String owner);

  /// No description provided for @deviceControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Control'**
  String get deviceControlTitle;

  /// No description provided for @deviceControlRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get deviceControlRefreshStatus;

  /// No description provided for @deviceControlUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This build does not support phone control'**
  String get deviceControlUnsupported;

  /// No description provided for @deviceControlServiceConnected.
  ///
  /// In en, this message translates to:
  /// **'Accessibility service: connected'**
  String get deviceControlServiceConnected;

  /// No description provided for @deviceControlServiceCheckedNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Accessibility service: checked but not connected'**
  String get deviceControlServiceCheckedNotConnected;

  /// No description provided for @deviceControlServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Accessibility service: off'**
  String get deviceControlServiceOff;

  /// No description provided for @deviceControlStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unknown'**
  String get deviceControlStatusUnknown;

  /// No description provided for @deviceControlGoSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Find \"Fen\" in the system list, turn on the switch, then come back here and refresh'**
  String get deviceControlGoSystemHint;

  /// No description provided for @deviceControlGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get deviceControlGoSettings;

  /// No description provided for @deviceControlRedetect.
  ///
  /// In en, this message translates to:
  /// **'Re-detect'**
  String get deviceControlRedetect;

  /// No description provided for @deviceControlRedetectTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: if repeated detection keeps failing, go to system settings, turn \"Fen Screen Assistant\" off and on again, or restart the app — some phones disconnect the accessibility service during background cleanup.'**
  String get deviceControlRedetectTip;

  /// No description provided for @deviceControlAllowTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the agent to operate the phone'**
  String get deviceControlAllowTitle;

  /// No description provided for @deviceControlAllowSubReady.
  ///
  /// In en, this message translates to:
  /// **'When on, the agent can read the screen, tap, type, and open apps; it will ask for your confirmation the first time'**
  String get deviceControlAllowSubReady;

  /// No description provided for @deviceControlAllowSubChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked in the system, but the service is not connected: tap “Re-detect” above'**
  String get deviceControlAllowSubChecked;

  /// No description provided for @deviceControlAllowSubNeedService.
  ///
  /// In en, this message translates to:
  /// **'Turn on the system accessibility service first to enable this switch'**
  String get deviceControlAllowSubNeedService;

  /// No description provided for @deviceControlToolsHeader.
  ///
  /// In en, this message translates to:
  /// **'These capabilities are mounted when enabled'**
  String get deviceControlToolsHeader;

  /// No description provided for @deviceControlToolReadScreen.
  ///
  /// In en, this message translates to:
  /// **'Read text and tappable elements on screen'**
  String get deviceControlToolReadScreen;

  /// No description provided for @deviceControlToolTap.
  ///
  /// In en, this message translates to:
  /// **'Tap by text or coordinates'**
  String get deviceControlToolTap;

  /// No description provided for @deviceControlToolInput.
  ///
  /// In en, this message translates to:
  /// **'Type into input fields'**
  String get deviceControlToolInput;

  /// No description provided for @deviceControlToolSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe pages and scroll lists'**
  String get deviceControlToolSwipe;

  /// No description provided for @deviceControlToolPressKey.
  ///
  /// In en, this message translates to:
  /// **'Back / Home / Recents / Enter'**
  String get deviceControlToolPressKey;

  /// No description provided for @deviceControlToolOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open a specified app (package name)'**
  String get deviceControlToolOpenApp;

  /// No description provided for @deviceControlDenylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensitive app denylist'**
  String get deviceControlDenylistTitle;

  /// No description provided for @deviceControlDenylistBody.
  ///
  /// In en, this message translates to:
  /// **'While these apps are in the foreground the agent performs no actions (banking, payments, password managers, system settings). One package name per line; commas are also supported.'**
  String get deviceControlDenylistBody;

  /// No description provided for @deviceControlSaveDenylist.
  ///
  /// In en, this message translates to:
  /// **'Save denylist'**
  String get deviceControlSaveDenylist;

  /// No description provided for @deviceControlResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get deviceControlResetDefault;

  /// No description provided for @deviceControlFooter.
  ///
  /// In en, this message translates to:
  /// **'Note: phone control uses the Android accessibility service — no root and no extra plugins.\n· Turn the switch above off and the related tools are revoked from the agent immediately;\n· Every action is written to the audit log, viewable in “Manage Settings”;\n· The agent will never act on apps you have not authorized.'**
  String get deviceControlFooter;

  /// No description provided for @deviceControlToastNeedAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Please enable the \"Fen\" accessibility service in system settings first'**
  String get deviceControlToastNeedAccessibility;

  /// No description provided for @deviceControlToastOn.
  ///
  /// In en, this message translates to:
  /// **'Phone control enabled: you will still be asked to confirm the first time'**
  String get deviceControlToastOn;

  /// No description provided for @deviceControlToastOff.
  ///
  /// In en, this message translates to:
  /// **'Phone control disabled; related tools have been revoked'**
  String get deviceControlToastOff;

  /// No description provided for @deviceControlToastSaved.
  ///
  /// In en, this message translates to:
  /// **'Denylist saved ({n} items)'**
  String deviceControlToastSaved(String n);

  /// No description provided for @deviceControlToastReset.
  ///
  /// In en, this message translates to:
  /// **'Default denylist restored'**
  String get deviceControlToastReset;

  /// No description provided for @contactDefaultAgentName.
  ///
  /// In en, this message translates to:
  /// **'Wild Agent'**
  String get contactDefaultAgentName;

  /// No description provided for @contactDefaultMasterName.
  ///
  /// In en, this message translates to:
  /// **'Physical Probing'**
  String get contactDefaultMasterName;

  /// No description provided for @contactDefaultNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get contactDefaultNotes;

  /// No description provided for @contactSendingThroughGateway.
  ///
  /// In en, this message translates to:
  /// **'⚡ Sending directly through the gateway...'**
  String get contactSendingThroughGateway;

  /// No description provided for @contactEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit agent profile notes'**
  String get contactEditTitle;

  /// No description provided for @contactEditAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent nickname'**
  String get contactEditAgentLabel;

  /// No description provided for @contactEditMasterLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner note'**
  String get contactEditMasterLabel;

  /// No description provided for @contactEditNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Private dossier'**
  String get contactEditNotesLabel;

  /// No description provided for @contactEditConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm sync'**
  String get contactEditConfirm;

  /// No description provided for @contactEditSaved.
  ///
  /// In en, this message translates to:
  /// **'✅ Profile notes captured and synced!'**
  String get contactEditSaved;

  /// No description provided for @contactRequestReco.
  ///
  /// In en, this message translates to:
  /// **'Request recommendation'**
  String get contactRequestReco;

  /// No description provided for @contactSendGift.
  ///
  /// In en, this message translates to:
  /// **'Send gift'**
  String get contactSendGift;

  /// No description provided for @contactGiftSent.
  ///
  /// In en, this message translates to:
  /// **'{gift} sent, awaiting the other party\'s receipt'**
  String contactGiftSent(String gift);

  /// No description provided for @contactGiftFailed.
  ///
  /// In en, this message translates to:
  /// **'Gift failed: the other party is offline or on no channel'**
  String get contactGiftFailed;

  /// No description provided for @contactRecoRequested.
  ///
  /// In en, this message translates to:
  /// **'🤝 Recommendation request sent; the other party decides based on their local reputation'**
  String get contactRecoRequested;

  /// No description provided for @contactRecoFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: the other party is on no online channel'**
  String get contactRecoFailed;

  /// No description provided for @contactTierBlockToast.
  ///
  /// In en, this message translates to:
  /// **'Reputation too low; recommend removing and blocking this node from the roster'**
  String get contactTierBlockToast;

  /// No description provided for @contactTierAdjusted.
  ///
  /// In en, this message translates to:
  /// **'✅ Adjusted to {tier} per reputation advice'**
  String contactTierAdjusted(String tier);

  /// No description provided for @contactTierFriend.
  ///
  /// In en, this message translates to:
  /// **'Can upgrade to friend'**
  String get contactTierFriend;

  /// No description provided for @contactTierFamily.
  ///
  /// In en, this message translates to:
  /// **'Can upgrade to family'**
  String get contactTierFamily;

  /// No description provided for @contactTierStranger.
  ///
  /// In en, this message translates to:
  /// **'Suggest downgrade to stranger'**
  String get contactTierStranger;

  /// No description provided for @contactTierBlock.
  ///
  /// In en, this message translates to:
  /// **'Suggest block'**
  String get contactTierBlock;

  /// No description provided for @contactStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Radar locked'**
  String get contactStatusLocked;

  /// No description provided for @contactStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Awaiting reply'**
  String get contactStatusSent;

  /// No description provided for @contactStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Awaiting owner review'**
  String get contactStatusReceived;

  /// No description provided for @contactStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Chatting'**
  String get contactStatusAccepted;

  /// No description provided for @contactStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Physically intercepted'**
  String get contactStatusRejected;

  /// No description provided for @contactOwnerLine.
  ///
  /// In en, this message translates to:
  /// **'Owner: {name}'**
  String contactOwnerLine(String name);

  /// No description provided for @contactOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get contactOnline;

  /// No description provided for @contactOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Out of range'**
  String get contactOutOfRange;

  /// No description provided for @contactReputation.
  ///
  /// In en, this message translates to:
  /// **'📊 Reputation {score}'**
  String contactReputation(String score);

  /// No description provided for @contactGiftStats.
  ///
  /// In en, this message translates to:
  /// **'🎁 Sent {sent} / Recv {received}'**
  String contactGiftStats(String sent, String received);

  /// No description provided for @contactTierBlockBanner.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Reputation too low; recommend blocking (tap to view)'**
  String get contactTierBlockBanner;

  /// No description provided for @contactTierHintBanner.
  ///
  /// In en, this message translates to:
  /// **'💡 Reputation advice: {suggestion} (tap to apply)'**
  String contactTierHintBanner(String suggestion);

  /// No description provided for @contactNotesLine.
  ///
  /// In en, this message translates to:
  /// **'📝 Notes: {notes}'**
  String contactNotesLine(String notes);

  /// No description provided for @contactEmptyChat.
  ///
  /// In en, this message translates to:
  /// **'No conversation yet.\nType below to talk to them directly!'**
  String get contactEmptyChat;

  /// No description provided for @contactSayHint.
  ///
  /// In en, this message translates to:
  /// **'Force a chat, type your message...'**
  String get contactSayHint;

  /// No description provided for @dshImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from the DSH ecosystem'**
  String get dshImportTitle;

  /// No description provided for @dshImportClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get dshImportClipboardEmpty;

  /// No description provided for @dshImportNoFileContent.
  ///
  /// In en, this message translates to:
  /// **'No file content was read; try a different way to select'**
  String get dshImportNoFileContent;

  /// No description provided for @dshImportPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select files: {err}'**
  String dshImportPickFailed(String err);

  /// No description provided for @dshImportPasteSkillFirst.
  ///
  /// In en, this message translates to:
  /// **'Paste the SKILL.md content first'**
  String get dshImportPasteSkillFirst;

  /// No description provided for @dshImportIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Leverage the whole DSH ecosystem'**
  String get dshImportIntroTitle;

  /// No description provided for @dshImportIntroBody.
  ///
  /// In en, this message translates to:
  /// **'DSH plugins are written in TypeScript and cannot run directly on a phone;\nbut their skills and MCP servers can be moved over as-is.\n\nFor safety: imported plugins are disabled by default and carry device-signature checks — they only take effect after you enable them manually.'**
  String get dshImportIntroBody;

  /// No description provided for @dshImportSecSkillTitle.
  ///
  /// In en, this message translates to:
  /// **'① Import skills (SKILL.md)'**
  String get dshImportSecSkillTitle;

  /// No description provided for @dshImportSecSkillSub.
  ///
  /// In en, this message translates to:
  /// **'Plain-text skills translate 100% and are the easiest part of the DSH ecosystem to move. Paste one, or select several .md files at once.'**
  String get dshImportSecSkillSub;

  /// No description provided for @dshImportSkillHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the full SKILL.md (including the name / description in the --- header)'**
  String get dshImportSkillHint;

  /// No description provided for @dshImportPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get dshImportPaste;

  /// No description provided for @dshImportPickFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get dshImportPickFiles;

  /// No description provided for @dshImportImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dshImportImport;

  /// No description provided for @dshImportSecMcpTitle.
  ///
  /// In en, this message translates to:
  /// **'② Import MCP servers'**
  String get dshImportSecMcpTitle;

  /// No description provided for @dshImportSecMcpSub.
  ///
  /// In en, this message translates to:
  /// **'MCP is a language-agnostic protocol: just fill in the address to connect. Pastes of dsh / Claude style mcpServers config are supported.'**
  String get dshImportSecMcpSub;

  /// No description provided for @dshImportMcpHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}\nYou can also paste a bare https:// address'**
  String dshImportMcpHint(String example);

  /// No description provided for @dshImportSecInspectTitle.
  ///
  /// In en, this message translates to:
  /// **'③ Plugin bundle checkup'**
  String get dshImportSecInspectTitle;

  /// No description provided for @dshImportSecInspectSub.
  ///
  /// In en, this message translates to:
  /// **'Got a DSH plugin bundle? Check it up before deciding whether it is worth the effort. Paste the bundle\'s package.json (required) and cordis.patch.yml (optional).'**
  String get dshImportSecInspectSub;

  /// No description provided for @dshImportPackageJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the full package.json'**
  String get dshImportPackageJsonHint;

  /// No description provided for @dshImportPatchHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the full cordis.patch.yml (optional)'**
  String get dshImportPatchHint;

  /// No description provided for @dshImportPastePackageJson.
  ///
  /// In en, this message translates to:
  /// **'Paste package.json'**
  String get dshImportPastePackageJson;

  /// No description provided for @dshImportStartInspect.
  ///
  /// In en, this message translates to:
  /// **'Run checkup'**
  String get dshImportStartInspect;

  /// No description provided for @dshImportGoToolCenter.
  ///
  /// In en, this message translates to:
  /// **'Open the skill control center to enable what you just imported'**
  String get dshImportGoToolCenter;

  /// No description provided for @dshImportSummaryImportedOk.
  ///
  /// In en, this message translates to:
  /// **'Imported {n}'**
  String dshImportSummaryImportedOk(String n);

  /// No description provided for @dshImportSummarySkipped.
  ///
  /// In en, this message translates to:
  /// **', skipped {n}'**
  String dshImportSummarySkipped(String n);

  /// No description provided for @dshImportListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get dshImportListSeparator;

  /// No description provided for @dshImportImportedLine.
  ///
  /// In en, this message translates to:
  /// **'✅ {names}'**
  String dshImportImportedLine(String names);

  /// No description provided for @dshImportSkippedLine.
  ///
  /// In en, this message translates to:
  /// **'⚠️ {name}: {reason}'**
  String dshImportSkippedLine(String name, String reason);

  /// No description provided for @dshImportNoteLine.
  ///
  /// In en, this message translates to:
  /// **'ℹ️ {note}'**
  String dshImportNoteLine(String note);

  /// No description provided for @dshSkipDuplicateSkill.
  ///
  /// In en, this message translates to:
  /// **'A skill with this name already exists; not overwritten'**
  String get dshSkipDuplicateSkill;

  /// No description provided for @dshSkipDuplicateMcp.
  ///
  /// In en, this message translates to:
  /// **'An MCP config with this name already exists; not overwritten'**
  String get dshSkipDuplicateMcp;

  /// No description provided for @dshSkipInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'This content is neither valid JSON nor a URL'**
  String get dshSkipInvalidJson;

  /// No description provided for @dshSkipCommandLineMcp.
  ///
  /// In en, this message translates to:
  /// **'This is a command-line MCP (it needs a local process), which cannot run on a phone; use an HTTP address instead'**
  String get dshSkipCommandLineMcp;

  /// No description provided for @dshSkipNoUrlField.
  ///
  /// In en, this message translates to:
  /// **'No url field found in this config'**
  String get dshSkipNoUrlField;

  /// No description provided for @dshSkipMissingNameUrl.
  ///
  /// In en, this message translates to:
  /// **'Missing name or url'**
  String get dshSkipMissingNameUrl;

  /// No description provided for @dshSkipUnrecognizedJson.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized JSON structure'**
  String get dshSkipUnrecognizedJson;

  /// No description provided for @dshSkipInvalidScheme.
  ///
  /// In en, this message translates to:
  /// **'The address must start with http:// or https://'**
  String get dshSkipInvalidScheme;

  /// No description provided for @dshSkipSubjectConfig.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get dshSkipSubjectConfig;

  /// No description provided for @dshSkipSubjectConfigParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Config parse failed'**
  String get dshSkipSubjectConfigParseFailed;

  /// No description provided for @dshSkipSubjectUnnamedEntry.
  ///
  /// In en, this message translates to:
  /// **'Unnamed entry'**
  String get dshSkipSubjectUnnamedEntry;

  /// No description provided for @dshNoteSkillDefaultsOff.
  ///
  /// In en, this message translates to:
  /// **'Imported skills are disabled by default — enable them as needed in the Skill Control Center; once enabled they affect how your agent speaks and behaves.'**
  String get dshNoteSkillDefaultsOff;

  /// No description provided for @dshNoteMcpDefaultsOff.
  ///
  /// In en, this message translates to:
  /// **'Imported MCP servers are disabled by default. When you enable one and use it for the first time, the system will ask you to grant the \"network access\" capability; only then will it actually connect.'**
  String get dshNoteMcpDefaultsOff;

  /// No description provided for @dshNotePasteMcpFirst.
  ///
  /// In en, this message translates to:
  /// **'Paste an MCP config or address first'**
  String get dshNotePasteMcpFirst;

  /// No description provided for @dshInspectErrPackageFormat.
  ///
  /// In en, this message translates to:
  /// **'❌ package.json parse failed: {msg}'**
  String dshInspectErrPackageFormat(String msg);

  /// No description provided for @dshInspectErrPackageNotJson.
  ///
  /// In en, this message translates to:
  /// **'❌ package.json is not valid JSON: {msg}'**
  String dshInspectErrPackageNotJson(String msg);

  /// No description provided for @dshInspectErrPatchFormat.
  ///
  /// In en, this message translates to:
  /// **'❌ cordis.patch.yml parse failed: {msg}'**
  String dshInspectErrPatchFormat(String msg);

  /// No description provided for @dshInspectPackageLine.
  ///
  /// In en, this message translates to:
  /// **'Bundle: {name}'**
  String dshInspectPackageLine(String name);

  /// No description provided for @dshInspectBundleLine.
  ///
  /// In en, this message translates to:
  /// **'Bundle file: {path}'**
  String dshInspectBundleLine(String path);

  /// No description provided for @dshInspectProfileBundlesLine.
  ///
  /// In en, this message translates to:
  /// **'Profile bundles: {list}'**
  String dshInspectProfileBundlesLine(String list);

  /// No description provided for @dshInspectNoPatchHint.
  ///
  /// In en, this message translates to:
  /// **'ℹ️ No cordis.patch.yml was provided, so only the bundle\'s basic info is visible. Paste that file\'s content too, and we can judge what is portable to a phone.'**
  String get dshInspectNoPatchHint;

  /// No description provided for @dshInspectRowCountLine.
  ///
  /// In en, this message translates to:
  /// **'{n} plugin rows in total; checkup result:'**
  String dshInspectRowCountLine(String n);

  /// No description provided for @dshInspectGroupLine.
  ///
  /// In en, this message translates to:
  /// **'[{verdict}] {n} rows'**
  String dshInspectGroupLine(String verdict, String n);

  /// No description provided for @dshInspectMoreRowsLine.
  ///
  /// In en, this message translates to:
  /// **'  · …and {n} more rows'**
  String dshInspectMoreRowsLine(String n);

  /// No description provided for @dshInspectConclusionLine.
  ///
  /// In en, this message translates to:
  /// **'Conclusion: {skill} skill rows and {mcp} MCP rows can be imported directly; {heavy} rows must be rewritten in Dart or need a desktop environment, so they cannot run here.'**
  String dshInspectConclusionLine(String skill, String mcp, String heavy);

  /// No description provided for @dshInspectVerdictDirectSkill.
  ///
  /// In en, this message translates to:
  /// **'✅ Directly importable (skill)'**
  String get dshInspectVerdictDirectSkill;

  /// No description provided for @dshInspectVerdictMcpServer.
  ///
  /// In en, this message translates to:
  /// **'✅ Directly connectable (MCP server)'**
  String get dshInspectVerdictMcpServer;

  /// No description provided for @dshInspectVerdictConfigOnly.
  ///
  /// In en, this message translates to:
  /// **'⚙️ Config only (no porting needed)'**
  String get dshInspectVerdictConfigOnly;

  /// No description provided for @dshInspectVerdictPlatformGated.
  ///
  /// In en, this message translates to:
  /// **'🖥️ Needs a desktop environment (unusable on a phone)'**
  String get dshInspectVerdictPlatformGated;

  /// No description provided for @dshInspectVerdictNeedsDart.
  ///
  /// In en, this message translates to:
  /// **'🧱 Needs a Dart rewrite (contains TS code)'**
  String get dshInspectVerdictNeedsDart;

  /// No description provided for @chatCleared.
  ///
  /// In en, this message translates to:
  /// **'🧹 Workspace and LLM memory cleared. New session started!'**
  String get chatCleared;

  /// No description provided for @chatImageOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send image or visual content'**
  String get chatImageOptionsTitle;

  /// No description provided for @chatTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get chatTakePhoto;

  /// No description provided for @chatPickFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'Choose from album'**
  String get chatPickFromAlbum;

  /// No description provided for @chatAudioOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send audio or recording'**
  String get chatAudioOptionsTitle;

  /// No description provided for @chatStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get chatStartRecording;

  /// No description provided for @chatLocalAudio.
  ///
  /// In en, this message translates to:
  /// **'Local audio'**
  String get chatLocalAudio;

  /// No description provided for @chatOpenCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open camera: {err}'**
  String chatOpenCameraFailed(String err);

  /// No description provided for @chatOpenAlbumFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open album: {err}'**
  String chatOpenAlbumFailed(String err);

  /// No description provided for @chatPickAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select audio file: {err}'**
  String chatPickAudioFailed(String err);

  /// No description provided for @chatNoMicPermission.
  ///
  /// In en, this message translates to:
  /// **'No microphone permission: allow the \"Record audio\" permission in system settings and retry'**
  String get chatNoMicPermission;

  /// No description provided for @chatStartRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {err}'**
  String chatStartRecordingFailed(String err);

  /// No description provided for @chatWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, master!'**
  String get chatWelcomeBack;

  /// No description provided for @chatAgentReady.
  ///
  /// In en, this message translates to:
  /// **'The AI butler is ready and standing by'**
  String get chatAgentReady;

  /// No description provided for @chatQuickTechTitle.
  ///
  /// In en, this message translates to:
  /// **'🔍 Today\'s tech news'**
  String get chatQuickTechTitle;

  /// No description provided for @chatQuickTechPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search for today\'s latest AI tech news and summarize it for me.'**
  String get chatQuickTechPrompt;

  /// No description provided for @chatQuickRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'📡 Scan for nearby people'**
  String get chatQuickRadarTitle;

  /// No description provided for @chatQuickRadarPrompt.
  ///
  /// In en, this message translates to:
  /// **'Check the physical radar — any active nodes around?'**
  String get chatQuickRadarPrompt;

  /// No description provided for @chatQuickProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'📝 Refine my profile'**
  String get chatQuickProfileTitle;

  /// No description provided for @chatQuickProfilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Based on yesterday\'s chat, did you discover any new preferences of mine?'**
  String get chatQuickProfilePrompt;

  /// No description provided for @chatAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get chatAudioFile;

  /// No description provided for @chatRecording.
  ///
  /// In en, this message translates to:
  /// **'🔴 Recording...'**
  String get chatRecording;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Send an instruction to the butler...'**
  String get chatInputHint;

  /// No description provided for @profileSavedToast.
  ///
  /// In en, this message translates to:
  /// **'🔒 Master\'s top-secret profile saved'**
  String get profileSavedToast;

  /// No description provided for @profileAddPerson.
  ///
  /// In en, this message translates to:
  /// **'Add a related person'**
  String get profileAddPerson;

  /// No description provided for @profileEditPerson.
  ///
  /// In en, this message translates to:
  /// **'Edit person info'**
  String get profileEditPerson;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Amy)'**
  String get profileNameLabel;

  /// No description provided for @profileRelationLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship (e.g. wife)'**
  String get profileRelationLabel;

  /// No description provided for @profileIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity note (e.g. primary school teacher)'**
  String get profileIdentityLabel;

  /// No description provided for @profileSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret details (e.g. likes strawberries)'**
  String get profileSecretLabel;

  /// No description provided for @profileSaveVault.
  ///
  /// In en, this message translates to:
  /// **'Save and lock into the vault'**
  String get profileSaveVault;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Master\'s top-secret profile & network'**
  String get profileTitle;

  /// No description provided for @profilePreferenceHeader.
  ///
  /// In en, this message translates to:
  /// **'👤 Master preferences'**
  String get profilePreferenceHeader;

  /// No description provided for @profileJobLabel.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get profileJobLabel;

  /// No description provided for @profileHobbiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Hobbies & strengths'**
  String get profileHobbiesLabel;

  /// No description provided for @profileDislikesLabel.
  ///
  /// In en, this message translates to:
  /// **'Dislikes & taboos'**
  String get profileDislikesLabel;

  /// No description provided for @profileOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other notes — freeform'**
  String get profileOtherLabel;

  /// No description provided for @profileSaveBase.
  ///
  /// In en, this message translates to:
  /// **'💾 Save basic preferences (into local vault)'**
  String get profileSaveBase;

  /// No description provided for @profileNetworkHeader.
  ///
  /// In en, this message translates to:
  /// **'🔗 Top-secret relationship network'**
  String get profileNetworkHeader;

  /// No description provided for @profileAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get profileAdd;

  /// No description provided for @profileNetworkEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet — tap Add in the top right'**
  String get profileNetworkEmpty;

  /// No description provided for @profileDetailLine.
  ///
  /// In en, this message translates to:
  /// **'📝 Details: {notes}'**
  String profileDetailLine(String notes);

  /// No description provided for @profileAiReadable.
  ///
  /// In en, this message translates to:
  /// **'🔓 AI is authorized to read this person\'s info'**
  String get profileAiReadable;

  /// No description provided for @profileAiIsolated.
  ///
  /// In en, this message translates to:
  /// **'🔒 AI is physically isolated from this person\'s info'**
  String get profileAiIsolated;

  /// No description provided for @giftPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'🎁 Pick a token of appreciation'**
  String get giftPickerTitle;

  /// No description provided for @giftNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Attach a message (optional)'**
  String get giftNoteLabel;

  /// No description provided for @giftNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Thanks for the help last time'**
  String get giftNoteHint;

  /// No description provided for @giftSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get giftSend;

  /// No description provided for @giftNameTea.
  ///
  /// In en, this message translates to:
  /// **'A cup of tea'**
  String get giftNameTea;

  /// No description provided for @giftNameBook.
  ///
  /// In en, this message translates to:
  /// **'A book'**
  String get giftNameBook;

  /// No description provided for @giftNameFlower.
  ///
  /// In en, this message translates to:
  /// **'A bouquet'**
  String get giftNameFlower;

  /// No description provided for @giftNameCake.
  ///
  /// In en, this message translates to:
  /// **'A slice of cake'**
  String get giftNameCake;

  /// No description provided for @giftNameMysteryBox.
  ///
  /// In en, this message translates to:
  /// **'A mystery box'**
  String get giftNameMysteryBox;

  /// No description provided for @giftNameStar.
  ///
  /// In en, this message translates to:
  /// **'A star'**
  String get giftNameStar;

  /// No description provided for @themeRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get themeRed;

  /// No description provided for @themeOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get themeOrange;

  /// No description provided for @themeYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get themeYellow;

  /// No description provided for @themeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get themeGreen;

  /// No description provided for @themeCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get themeCyan;

  /// No description provided for @themeBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get themeBlue;

  /// No description provided for @themePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get themePurple;

  /// No description provided for @themeWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get themeWhite;

  /// No description provided for @themeBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get themeBlack;

  /// No description provided for @mainClearSession.
  ///
  /// In en, this message translates to:
  /// **'Clear and start a new session'**
  String get mainClearSession;

  /// No description provided for @mainNavChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get mainNavChat;

  /// No description provided for @mainNavSocial.
  ///
  /// In en, this message translates to:
  /// **'Fen Community'**
  String get mainNavSocial;

  /// No description provided for @mainNavWorld.
  ///
  /// In en, this message translates to:
  /// **'Wold'**
  String get mainNavWorld;

  /// No description provided for @mainNavSerendipity.
  ///
  /// In en, this message translates to:
  /// **'Serendipity'**
  String get mainNavSerendipity;

  /// No description provided for @mainNavManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get mainNavManage;

  /// No description provided for @topicChatLogSuffix.
  ///
  /// In en, this message translates to:
  /// **'{range} chat log'**
  String topicChatLogSuffix(String range);

  /// No description provided for @topicArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart memory archive'**
  String get topicArchiveTitle;

  /// No description provided for @topicTabTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get topicTabTimeline;

  /// No description provided for @topicTabTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get topicTabTopics;

  /// No description provided for @topicEmptyArchive.
  ///
  /// In en, this message translates to:
  /// **'No archived data yet'**
  String get topicEmptyArchive;

  /// No description provided for @topicNoTag.
  ///
  /// In en, this message translates to:
  /// **'Untagged'**
  String get topicNoTag;

  /// No description provided for @topicDailyChat.
  ///
  /// In en, this message translates to:
  /// **'Daily chat'**
  String get topicDailyChat;

  /// No description provided for @topicCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} msgs'**
  String topicCountLabel(String count);

  /// No description provided for @topicKeywordLine.
  ///
  /// In en, this message translates to:
  /// **'🏷️ {keywords}'**
  String topicKeywordLine(String keywords);

  /// No description provided for @digestToResponse.
  ///
  /// In en, this message translates to:
  /// **'{to}: {response}'**
  String digestToResponse(String to, String response);

  /// No description provided for @deviceControlStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Phone control ready: the agent can read the screen, tap, and type'**
  String get deviceControlStatusReady;

  /// No description provided for @deviceControlStatusUnsupportedShort.
  ///
  /// In en, this message translates to:
  /// **'This build does not include the phone-control module'**
  String get deviceControlStatusUnsupportedShort;

  /// No description provided for @deviceControlStatusUnsupportedFull.
  ///
  /// In en, this message translates to:
  /// **'This build does not include the phone-control module (the Android accessibility service is required)'**
  String get deviceControlStatusUnsupportedFull;

  /// No description provided for @deviceControlStatusCheckedOffline.
  ///
  /// In en, this message translates to:
  /// **'Checked in the system, but the service is not connected yet. Tap Refresh at the top right; if it still fails, turn the switch off and on again in system settings (or restart the app)'**
  String get deviceControlStatusCheckedOffline;

  /// No description provided for @deviceControlStatusOff.
  ///
  /// In en, this message translates to:
  /// **'The accessibility service has not been enabled in system settings yet'**
  String get deviceControlStatusOff;

  /// No description provided for @deviceControlStatusQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Status query failed: {err}'**
  String deviceControlStatusQueryFailed(String err);

  /// No description provided for @deviceControlGuardBlocked.
  ///
  /// In en, this message translates to:
  /// **'The foreground app ({pkg}) is on the safety denylist; the agent will not act on it. If you really need this, remove the restriction on the “Phone Control” settings page.'**
  String deviceControlGuardBlocked(String pkg);

  /// No description provided for @commonNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {err}'**
  String commonNetworkError(String err);

  /// No description provided for @netFaultLanHijackAdvice.
  ///
  /// In en, this message translates to:
  /// **'🤖 [Agent self-diagnosis]\nMaster, my LLM cannot reach the internet!\nThis usually happens when the physical radar (Nearby/LAN) is on and the current Wi-Fi LAN has no internet egress — devices can discover each other but cannot reach the public internet, so I cannot call the cloud LLM.\n\nSuggestions: 1) turn off the physical radar; 2) turn off Wi-Fi and switch to cellular data; 3) or enable smart network switching in system settings.\nFor now I can only keep the low-level physical link alive.'**
  String get netFaultLanHijackAdvice;

  /// No description provided for @netFaultSocialSkipped.
  ///
  /// In en, this message translates to:
  /// **'❌ Cannot reach the cloud LLM: network unreachable. If the physical radar is on, the current Wi-Fi LAN probably has no internet egress — devices can discover each other but cannot reach the public internet. This round was skipped.\nSuggestion: turn off the physical radar, or switch off Wi-Fi and use cellular data, then retry.\nReason: {err}'**
  String netFaultSocialSkipped(String err);

  /// No description provided for @socialPipelineError.
  ///
  /// In en, this message translates to:
  /// **'❌ Social decision pipeline error, this round was aborted: {err}'**
  String socialPipelineError(String err);

  /// No description provided for @netFaultNetworkTrouble.
  ///
  /// In en, this message translates to:
  /// **'❌ Cannot reach the cloud LLM (network issue, not a code bug).\nIt may be a network handover, a carrier link problem, or the current Wi-Fi has no internet egress.\nTry: 1) turn off Wi-Fi and use cellular data; 2) enable \"auto-switch to mobile data\" in system settings; 3) retry later.\nReason: {err}'**
  String netFaultNetworkTrouble(String err);

  /// No description provided for @netFaultCooldownSkipped.
  ///
  /// In en, this message translates to:
  /// **'⏸ Network failed repeatedly — LLM calls are paused for 10 minutes (no more token burn).'**
  String get netFaultCooldownSkipped;

  /// No description provided for @worldSvcNoHub.
  ///
  /// In en, this message translates to:
  /// **'Cloud Hub / world address is not configured'**
  String get worldSvcNoHub;

  /// No description provided for @worldSvcMustBeHttps.
  ///
  /// In en, this message translates to:
  /// **'The world address must be HTTPS or a private LAN address'**
  String get worldSvcMustBeHttps;

  /// No description provided for @worldSvcRoomsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch the room list: {code} {body}'**
  String worldSvcRoomsFailed(String code, String body);

  /// No description provided for @worldSvcOpFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed ({code}): {body}'**
  String worldSvcOpFailed(String code, String body);

  /// No description provided for @worldSvcReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch the report: {code}'**
  String worldSvcReportFailed(String code);

  /// No description provided for @godSvcMustBeHttps.
  ///
  /// In en, this message translates to:
  /// **'The GOD address must be HTTPS or a private LAN address'**
  String get godSvcMustBeHttps;

  /// No description provided for @godSvcStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch status ({code}): {body}'**
  String godSvcStatusFailed(String code, String body);

  /// No description provided for @godSvcNoBridge.
  ///
  /// In en, this message translates to:
  /// **'The GOD bridge address is not configured'**
  String get godSvcNoBridge;

  /// No description provided for @godSvcCmdFailed.
  ///
  /// In en, this message translates to:
  /// **'Command failed ({code}): {body}'**
  String godSvcCmdFailed(String code, String body);

  /// No description provided for @passportTitle.
  ///
  /// In en, this message translates to:
  /// **'Passport & Reputation'**
  String get passportTitle;

  /// No description provided for @passportEntryTile.
  ///
  /// In en, this message translates to:
  /// **'Wold Passport'**
  String get passportEntryTile;

  /// No description provided for @passportEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Verifiable signed record · works offline'**
  String get passportEntryHint;

  /// No description provided for @passportCardHeader.
  ///
  /// In en, this message translates to:
  /// **'My Wold Passport'**
  String get passportCardHeader;

  /// No description provided for @passportIssuedLabel.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get passportIssuedLabel;

  /// No description provided for @passportCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy identity'**
  String get passportCopyAction;

  /// No description provided for @passportRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get passportRefreshAction;

  /// No description provided for @passportCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get passportCopiedToast;

  /// No description provided for @passportStatLine.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String passportStatLine(String label, String value);

  /// No description provided for @passportLedgerHeader.
  ///
  /// In en, this message translates to:
  /// **'Introduction ledger'**
  String get passportLedgerHeader;

  /// No description provided for @passportLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No introductions yet. Go meet someone in a world room.'**
  String get passportLedgerEmpty;

  /// No description provided for @passportDirectionOut.
  ///
  /// In en, this message translates to:
  /// **'I initiated'**
  String get passportDirectionOut;

  /// No description provided for @passportDirectionIn.
  ///
  /// In en, this message translates to:
  /// **'I received'**
  String get passportDirectionIn;

  /// No description provided for @passportPeerLabel.
  ///
  /// In en, this message translates to:
  /// **'Peer'**
  String get passportPeerLabel;

  /// No description provided for @passportTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get passportTopicLabel;

  /// No description provided for @passportRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'From room'**
  String get passportRoomLabel;

  /// No description provided for @passportTrustLabel.
  ///
  /// In en, this message translates to:
  /// **'Verified level'**
  String get passportTrustLabel;

  /// No description provided for @passportTrustNone.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get passportTrustNone;

  /// No description provided for @passportTrustInitiated.
  ///
  /// In en, this message translates to:
  /// **'Only initiator signed'**
  String get passportTrustInitiated;

  /// No description provided for @passportTrustConsented.
  ///
  /// In en, this message translates to:
  /// **'Both consented'**
  String get passportTrustConsented;

  /// No description provided for @passportTrustResolved.
  ///
  /// In en, this message translates to:
  /// **'Outcome recorded'**
  String get passportTrustResolved;

  /// No description provided for @passportTrustAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged by both'**
  String get passportTrustAcknowledged;

  /// No description provided for @passportOutcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get passportOutcomeLabel;

  /// No description provided for @passportOutcomeHandshake.
  ///
  /// In en, this message translates to:
  /// **'Handshake'**
  String get passportOutcomeHandshake;

  /// No description provided for @passportOutcomeDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get passportOutcomeDeclined;

  /// No description provided for @passportOutcomeNoResponse.
  ///
  /// In en, this message translates to:
  /// **'No response'**
  String get passportOutcomeNoResponse;

  /// No description provided for @passportOutcomeWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get passportOutcomeWithdrawn;

  /// No description provided for @passportVerifyDetails.
  ///
  /// In en, this message translates to:
  /// **'Verification details'**
  String get passportVerifyDetails;

  /// No description provided for @passportChecksLabel.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get passportChecksLabel;

  /// No description provided for @passportFaultsLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get passportFaultsLabel;

  /// No description provided for @passportConsentAction.
  ///
  /// In en, this message translates to:
  /// **'Consent to this introduction'**
  String get passportConsentAction;

  /// No description provided for @passportConsentDone.
  ///
  /// In en, this message translates to:
  /// **'Consented'**
  String get passportConsentDone;

  /// No description provided for @passportResolveAction.
  ///
  /// In en, this message translates to:
  /// **'Record outcome'**
  String get passportResolveAction;

  /// No description provided for @passportResolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Outcome of this introduction'**
  String get passportResolveTitle;

  /// No description provided for @passportAckAction.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge outcome'**
  String get passportAckAction;

  /// No description provided for @passportAckDone.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get passportAckDone;

  /// No description provided for @passportActionDelivered.
  ///
  /// In en, this message translates to:
  /// **'Signed and delivered'**
  String get passportActionDelivered;

  /// No description provided for @passportActionOffline.
  ///
  /// In en, this message translates to:
  /// **'Recorded; peer is unreachable for now and it will retry later'**
  String get passportActionOffline;

  /// No description provided for @passportActionRejected.
  ///
  /// In en, this message translates to:
  /// **'Did not take effect (wrong order or identity)'**
  String get passportActionRejected;

  /// No description provided for @passportFunnelHeader.
  ///
  /// In en, this message translates to:
  /// **'Introduction to handshake conversion'**
  String get passportFunnelHeader;

  /// No description provided for @passportFunnelProposedLabel.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get passportFunnelProposedLabel;

  /// No description provided for @passportFunnelConsentedLabel.
  ///
  /// In en, this message translates to:
  /// **'Consented'**
  String get passportFunnelConsentedLabel;

  /// No description provided for @passportFunnelHandshakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Handshake'**
  String get passportFunnelHandshakeLabel;

  /// No description provided for @passportFunnelSettledLabel.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get passportFunnelSettledLabel;

  /// No description provided for @passportFunnelInFlightLabel.
  ///
  /// In en, this message translates to:
  /// **'In flight'**
  String get passportFunnelInFlightLabel;

  /// No description provided for @passportFunnelConsentRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Consent rate'**
  String get passportFunnelConsentRateLabel;

  /// No description provided for @passportFunnelConversionLabel.
  ///
  /// In en, this message translates to:
  /// **'Conversion'**
  String get passportFunnelConversionLabel;

  /// No description provided for @passportLogHeader.
  ///
  /// In en, this message translates to:
  /// **'Transparency log'**
  String get passportLogHeader;

  /// No description provided for @passportLogSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tree size'**
  String get passportLogSizeLabel;

  /// No description provided for @passportLogRootLabel.
  ///
  /// In en, this message translates to:
  /// **'Merkle root'**
  String get passportLogRootLabel;

  /// No description provided for @passportLogCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy root'**
  String get passportLogCopyAction;

  /// No description provided for @passportNewIntroAction.
  ///
  /// In en, this message translates to:
  /// **'New introduction'**
  String get passportNewIntroAction;

  /// No description provided for @passportNewIntroPeerLabel.
  ///
  /// In en, this message translates to:
  /// **'Peer agent ID'**
  String get passportNewIntroPeerLabel;

  /// No description provided for @passportNewIntroTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'One-line topic'**
  String get passportNewIntroTopicLabel;

  /// No description provided for @passportNewIntroSubmit.
  ///
  /// In en, this message translates to:
  /// **'Propose'**
  String get passportNewIntroSubmit;

  /// No description provided for @passportNewIntroNeedPeer.
  ///
  /// In en, this message translates to:
  /// **'Enter the peer\'s agent ID'**
  String get passportNewIntroNeedPeer;

  /// No description provided for @passportNewIntroNoCircle.
  ///
  /// In en, this message translates to:
  /// **'You have no circle yet. Join one first so the introduction has an owner.'**
  String get passportNewIntroNoCircle;

  /// No description provided for @passportNewIntroDone.
  ///
  /// In en, this message translates to:
  /// **'Proposed and signed for {peer}'**
  String passportNewIntroDone(String peer);

  /// No description provided for @radarNoticeStarted.
  ///
  /// In en, this message translates to:
  /// **'🛡️ Radar on — a {minutes}-minute social party has started…'**
  String radarNoticeStarted(int minutes);

  /// No description provided for @radarNoticeStopped.
  ///
  /// In en, this message translates to:
  /// **'💤 Radar off — the social party has ended.'**
  String get radarNoticeStopped;

  /// No description provided for @radarNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'AiSteward · Radar gateway running at full speed'**
  String get radarNotifTitle;

  /// No description provided for @radarNotifText.
  ///
  /// In en, this message translates to:
  /// **'Your digital agent is socializing for you in the real world, non-stop…'**
  String get radarNotifText;

  /// No description provided for @radarNoticePartyEnded.
  ///
  /// In en, this message translates to:
  /// **'⏰ Time is up — the supervisor agent has pulled the antenna!'**
  String get radarNoticePartyEnded;

  /// No description provided for @radarNoticeWrappingUp.
  ///
  /// In en, this message translates to:
  /// **'⏳ Under 10 minutes left — your agent is getting ready to say goodbye.'**
  String get radarNoticeWrappingUp;

  /// No description provided for @cloudHubNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud Hub address is not configured'**
  String get cloudHubNotConfigured;

  /// No description provided for @cloudKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'This relay requires an access key. Enter the key issued by its operator in Advanced settings.'**
  String get cloudKeyRequired;

  /// No description provided for @cloudKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Access key is invalid. Check that you copied the whole key.'**
  String get cloudKeyInvalid;

  /// No description provided for @cloudKeyRevoked.
  ///
  /// In en, this message translates to:
  /// **'This access key has been revoked. Contact the relay operator.'**
  String get cloudKeyRevoked;

  /// No description provided for @cloudKeyBound.
  ///
  /// In en, this message translates to:
  /// **'This key is already bound to another identity. Use a different key, or identity recovery.'**
  String get cloudKeyBound;

  /// No description provided for @cloudAgentRevoked.
  ///
  /// In en, this message translates to:
  /// **'This device\'s identity has been revoked by the relay and can no longer send or receive.'**
  String get cloudAgentRevoked;

  /// No description provided for @cloudRegisterClosed.
  ///
  /// In en, this message translates to:
  /// **'The relay has paused new registrations.'**
  String get cloudRegisterClosed;

  /// No description provided for @cloudRegisterIdentityConflict.
  ///
  /// In en, this message translates to:
  /// **'This identity ID is bound to a different key. Use identity recovery / key rotation; do not delete the identity.'**
  String get cloudRegisterIdentityConflict;

  /// No description provided for @cloudRosterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch roster ({status}): {body}'**
  String cloudRosterFailed(int status, String body);

  /// No description provided for @cloudNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {error}'**
  String cloudNetworkError(String error);

  /// No description provided for @cloudCardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch contact card ({status})'**
  String cloudCardFailed(int status);

  /// No description provided for @identityChangedWarning.
  ///
  /// In en, this message translates to:
  /// **'🚨 Identity changed: the peer\'s public key no longer matches the one pinned earlier (possible MITM or re-key). Handshake refused and trust heavily lowered.'**
  String get identityChangedWarning;

  /// No description provided for @lanTunnelOpen.
  ///
  /// In en, this message translates to:
  /// **'⚡ LAN physical channel (TCP/UDP) is now open!'**
  String get lanTunnelOpen;

  /// No description provided for @lanTargetLost.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Wi-Fi physical target went out of range.'**
  String get lanTargetLost;

  /// No description provided for @p2pBtDisconnected.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Bluetooth connection dropped.'**
  String get p2pBtDisconnected;

  /// No description provided for @repEventLog.
  ///
  /// In en, this message translates to:
  /// **'Reputation {delta} ({event}){detail}'**
  String repEventLog(String delta, String event, String detail);

  /// No description provided for @repEventDetailSuffix.
  ///
  /// In en, this message translates to:
  /// **': {detail}'**
  String repEventDetailSuffix(String detail);

  /// No description provided for @repGiftLogIncoming.
  ///
  /// In en, this message translates to:
  /// **'{gift} — a token of goodwill from that node{note}'**
  String repGiftLogIncoming(String gift, String note);

  /// No description provided for @repGiftLogOutgoing.
  ///
  /// In en, this message translates to:
  /// **'{gift} — a token of goodwill sent to that node{note}'**
  String repGiftLogOutgoing(String gift, String note);

  /// No description provided for @repGiftNoteQuoted.
  ///
  /// In en, this message translates to:
  /// **' — \"{note}\"'**
  String repGiftNoteQuoted(String note);

  /// No description provided for @repGiftMemoryIncoming.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a gift {gift} {note}'**
  String repGiftMemoryIncoming(String name, String gift, String note);

  /// No description provided for @repGiftMemoryOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Sent a gift {gift} to {name} {note}'**
  String repGiftMemoryOutgoing(String gift, String name, String note);

  /// No description provided for @repGiftMemoryNote.
  ///
  /// In en, this message translates to:
  /// **'({note})'**
  String repGiftMemoryNote(String note);

  /// No description provided for @repRecoLog.
  ///
  /// In en, this message translates to:
  /// **'🤝 Recommendation letter received: reputation {score} (issued {date}, signature verified)'**
  String repRecoLog(int score, String date);

  /// No description provided for @repRecoMemory.
  ///
  /// In en, this message translates to:
  /// **'Received a recommendation letter from {issuer} (reputation {score}, issued {date})'**
  String repRecoMemory(String issuer, int score, String date);

  /// No description provided for @repNetHeader.
  ///
  /// In en, this message translates to:
  /// **'Network endorsements'**
  String get repNetHeader;

  /// No description provided for @repNetAnchors.
  ///
  /// In en, this message translates to:
  /// **'{count} anchors (local reputation ≥ {min})'**
  String repNetAnchors(int count, int min);

  /// No description provided for @repNetMineLabel.
  ///
  /// In en, this message translates to:
  /// **'Endorsed by me'**
  String get repNetMineLabel;

  /// No description provided for @repNetForMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Endorsing me'**
  String get repNetForMeLabel;

  /// No description provided for @repNetEmpty.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get repNetEmpty;

  /// No description provided for @repNetIssueAction.
  ///
  /// In en, this message translates to:
  /// **'Endorse'**
  String get repNetIssueAction;

  /// No description provided for @repNetIssueTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign an endorsement'**
  String get repNetIssueTitle;

  /// No description provided for @repNetIssueSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Their passport DID or public key'**
  String get repNetIssueSubjectLabel;

  /// No description provided for @repNetIssueNeedSubject.
  ///
  /// In en, this message translates to:
  /// **'Paste their DID (did:wold:…) or public key'**
  String get repNetIssueNeedSubject;

  /// No description provided for @repNetIssueBadSubject.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid DID or public key'**
  String get repNetIssueBadSubject;

  /// No description provided for @repNetIssueTierLabel.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get repNetIssueTierLabel;

  /// No description provided for @repNetIssueNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get repNetIssueNoteLabel;

  /// No description provided for @repNetIssueBindLabel.
  ///
  /// In en, this message translates to:
  /// **'Their agent ID (optional; links local reputation to this key)'**
  String get repNetIssueBindLabel;

  /// No description provided for @repNetTierAcquaintance.
  ///
  /// In en, this message translates to:
  /// **'Acquaintance'**
  String get repNetTierAcquaintance;

  /// No description provided for @repNetTierFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get repNetTierFriend;

  /// No description provided for @repNetTierFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get repNetTierFamily;

  /// No description provided for @repNetIssuedToast.
  ///
  /// In en, this message translates to:
  /// **'Endorsement signed and stored'**
  String get repNetIssuedToast;

  /// No description provided for @repNetFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Rejected: {code}'**
  String repNetFailedToast(String code);

  /// No description provided for @repNetSelfReject.
  ///
  /// In en, this message translates to:
  /// **'You cannot endorse yourself'**
  String get repNetSelfReject;

  /// No description provided for @repNetExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get repNetExpiresLabel;

  /// No description provided for @repNetRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get repNetRevokeAction;

  /// No description provided for @repNetRevokedToast.
  ///
  /// In en, this message translates to:
  /// **'Endorsement revoked'**
  String get repNetRevokedToast;

  /// No description provided for @repNetBoundToast.
  ///
  /// In en, this message translates to:
  /// **'Remembered the public key of {id}'**
  String repNetBoundToast(String id);

  /// No description provided for @repNetVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get repNetVerifyAction;

  /// No description provided for @repNetVerifiedToast.
  ///
  /// In en, this message translates to:
  /// **'Signature valid'**
  String get repNetVerifiedToast;

  /// No description provided for @repNetBadSignatureToast.
  ///
  /// In en, this message translates to:
  /// **'Signature INVALID — the endorsement was altered'**
  String get repNetBadSignatureToast;

  /// No description provided for @repNetQueryLabel.
  ///
  /// In en, this message translates to:
  /// **'Look someone up'**
  String get repNetQueryLabel;

  /// No description provided for @repNetQueryAction.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get repNetQueryAction;

  /// No description provided for @repNetQueryKnown.
  ///
  /// In en, this message translates to:
  /// **'{tier} · {depth} hop(s) away · confidence {confidence} · {paths} path(s)'**
  String repNetQueryKnown(String tier, int depth, String confidence, int paths);

  /// No description provided for @repNetQueryUnknown.
  ///
  /// In en, this message translates to:
  /// **'No verifiable path'**
  String get repNetQueryUnknown;

  /// No description provided for @repNetPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Evidence chain (verify each hop yourself)'**
  String get repNetPathLabel;

  /// No description provided for @repNetPathStart.
  ///
  /// In en, this message translates to:
  /// **'you trust'**
  String get repNetPathStart;

  /// No description provided for @repNetPathHop.
  ///
  /// In en, this message translates to:
  /// **'→ who endorses'**
  String get repNetPathHop;

  /// No description provided for @repNetStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'revoked'**
  String get repNetStatusRevoked;

  /// No description provided for @repNetStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get repNetStatusExpired;

  /// No description provided for @repNetKeysMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged across {count} keys through the rotation chain — endorsements you received before the rotation still count.'**
  String repNetKeysMerged(int count);

  /// No description provided for @skillMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill Market'**
  String get skillMarketTitle;

  /// No description provided for @skillMarketSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Publish author-signed skills; track your revenue share'**
  String get skillMarketSubtitle;

  /// No description provided for @skillRevenueTitle.
  ///
  /// In en, this message translates to:
  /// **'Author revenue'**
  String get skillRevenueTitle;

  /// No description provided for @skillRevenueTotal.
  ///
  /// In en, this message translates to:
  /// **'Total earned {amount}'**
  String skillRevenueTotal(String amount);

  /// No description provided for @skillRevenueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} payouts'**
  String skillRevenueCount(int count);

  /// No description provided for @skillRevenueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No revenue yet'**
  String get skillRevenueEmpty;

  /// No description provided for @skillNoListings.
  ///
  /// In en, this message translates to:
  /// **'Nothing published in the registry yet.'**
  String get skillNoListings;

  /// No description provided for @skillPublishAction.
  ///
  /// In en, this message translates to:
  /// **'Publish skill'**
  String get skillPublishAction;

  /// No description provided for @skillPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish a signed skill'**
  String get skillPublishTitle;

  /// No description provided for @skillFieldId.
  ///
  /// In en, this message translates to:
  /// **'Skill ID'**
  String get skillFieldId;

  /// No description provided for @skillFieldVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get skillFieldVersion;

  /// No description provided for @skillFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get skillFieldName;

  /// No description provided for @skillFieldDesc.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get skillFieldDesc;

  /// No description provided for @skillFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price in yuan (0 = free)'**
  String get skillFieldPrice;

  /// No description provided for @skillFieldRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get skillFieldRisk;

  /// No description provided for @skillFieldCaps.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get skillFieldCaps;

  /// No description provided for @skillFieldContent.
  ///
  /// In en, this message translates to:
  /// **'Content (hashed & signed)'**
  String get skillFieldContent;

  /// No description provided for @skillSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign & publish'**
  String get skillSubmit;

  /// No description provided for @skillNeedFields.
  ///
  /// In en, this message translates to:
  /// **'Skill ID, version, name and content are required'**
  String get skillNeedFields;

  /// No description provided for @skillRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get skillRevokeAction;

  /// No description provided for @skillRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke {skill}? This cannot be undone.'**
  String skillRevokeConfirm(String skill);

  /// No description provided for @skillPublishedOk.
  ///
  /// In en, this message translates to:
  /// **'Published {skill}'**
  String skillPublishedOk(String skill);

  /// No description provided for @skillPublishDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Same version & content already published'**
  String get skillPublishDuplicate;

  /// No description provided for @skillPublishVersionConflict.
  ///
  /// In en, this message translates to:
  /// **'Same version has different content — refused'**
  String get skillPublishVersionConflict;

  /// No description provided for @skillPublishAuthorChanged.
  ///
  /// In en, this message translates to:
  /// **'This skill ID belongs to another author — refused'**
  String get skillPublishAuthorChanged;

  /// No description provided for @skillPublishVersionNotIncreased.
  ///
  /// In en, this message translates to:
  /// **'Version must be greater than the published one'**
  String get skillPublishVersionNotIncreased;

  /// No description provided for @skillPublishUnverified.
  ///
  /// In en, this message translates to:
  /// **'Signature invalid — refused'**
  String get skillPublishUnverified;

  /// No description provided for @skillRevokedOk.
  ///
  /// In en, this message translates to:
  /// **'Revoked {skill}'**
  String skillRevokedOk(String skill);

  /// No description provided for @skillRevokeRejected.
  ///
  /// In en, this message translates to:
  /// **'Revoke refused — you are not the author key'**
  String get skillRevokeRejected;

  /// No description provided for @skillMineTag.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get skillMineTag;

  /// No description provided for @skillFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get skillFree;

  /// No description provided for @skillPriceYuan.
  ///
  /// In en, this message translates to:
  /// **'¥{amount}'**
  String skillPriceYuan(String amount);

  /// No description provided for @skillAuthorKey.
  ///
  /// In en, this message translates to:
  /// **'Author key'**
  String get skillAuthorKey;

  /// No description provided for @skillRevokedTag.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get skillRevokedTag;

  /// No description provided for @skillVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify signature'**
  String get skillVerifyAction;

  /// No description provided for @skillVerifyOk.
  ///
  /// In en, this message translates to:
  /// **'Signature valid'**
  String get skillVerifyOk;

  /// No description provided for @skillVerifyFail.
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {code}'**
  String skillVerifyFail(String code);

  /// No description provided for @skillVersionHistory.
  ///
  /// In en, this message translates to:
  /// **'{count} versions'**
  String skillVersionHistory(int count);

  /// Startup banner shown when the local runtime failed to initialise before the first frame.
  ///
  /// In en, this message translates to:
  /// **'Local runtime didn\'t start, so world, circle and delegation features are unavailable. Everything else works normally. ({err})'**
  String runtimeInitFailed(String err);

  /// No description provided for @idbEntry.
  ///
  /// In en, this message translates to:
  /// **'Back up & restore identity'**
  String get idbEntry;

  /// No description provided for @idbTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up & restore identity'**
  String get idbTitle;

  /// No description provided for @idbIntro.
  ///
  /// In en, this message translates to:
  /// **'Your identity *is* this key, and it lives only on this phone. Lose the phone and the identity is gone for good — nobody, not even us, can reissue it. Write the recovery code down; that is the only thing that brings it back.'**
  String get idbIntro;

  /// No description provided for @idbCurrentDid.
  ///
  /// In en, this message translates to:
  /// **'Current identity (DID)'**
  String get idbCurrentDid;

  /// No description provided for @idbNoScreenshotShort.
  ///
  /// In en, this message translates to:
  /// **'Never screenshot this'**
  String get idbNoScreenshotShort;

  /// No description provided for @idbSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Back up identity'**
  String get idbSectionBackup;

  /// No description provided for @idbWarnNoScreenshot.
  ///
  /// In en, this message translates to:
  /// **'⚠️ The recovery code *is* your identity. Copy it onto paper and keep it offline; do not screenshot it, do not put it in cloud storage, do not send it to anyone (including us).'**
  String get idbWarnNoScreenshot;

  /// No description provided for @idbPwLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery password (10+ characters)'**
  String get idbPwLabel;

  /// No description provided for @idbPwConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get idbPwConfirmLabel;

  /// No description provided for @idbPwMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords don\'t match'**
  String get idbPwMismatch;

  /// No description provided for @idbPwTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password is too short (at least 10 characters)'**
  String get idbPwTooShort;

  /// No description provided for @idbGenerateAction.
  ///
  /// In en, this message translates to:
  /// **'Generate recovery code'**
  String get idbGenerateAction;

  /// No description provided for @idbCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery code (write it down)'**
  String get idbCodeTitle;

  /// No description provided for @idbCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get idbCopyCode;

  /// No description provided for @idbCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Recovery code copied — remember to clear the clipboard afterwards'**
  String get idbCopiedToast;

  /// No description provided for @idbICopied.
  ///
  /// In en, this message translates to:
  /// **'I have written it down and stored it offline'**
  String get idbICopied;

  /// No description provided for @idbNeedCopied.
  ///
  /// In en, this message translates to:
  /// **'Please confirm you have written the recovery code down'**
  String get idbNeedCopied;

  /// No description provided for @idbDoneToast.
  ///
  /// In en, this message translates to:
  /// **'Identity backed up'**
  String get idbDoneToast;

  /// No description provided for @idbSectionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore on a new phone'**
  String get idbSectionRestore;

  /// No description provided for @idbRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore identity'**
  String get idbRestoreAction;

  /// No description provided for @idbRestoreCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get idbRestoreCodeLabel;

  /// No description provided for @idbRestoreIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID (AG-…)'**
  String get idbRestoreIdLabel;

  /// No description provided for @idbRestorePwLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery password'**
  String get idbRestorePwLabel;

  /// No description provided for @idbRestoreCheckAction.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get idbRestoreCheckAction;

  /// No description provided for @idbRestoreNeedAll.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the recovery code, user ID and password'**
  String get idbRestoreNeedAll;

  /// No description provided for @idbRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this is the identity you want to restore'**
  String get idbRestoreConfirmTitle;

  /// No description provided for @idbRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You are about to restore: {did}\n\nAfterwards this phone takes over the identity and the old phone stops working immediately.'**
  String idbRestoreConfirmBody(String did);

  /// No description provided for @idbRestoreConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Restore now'**
  String get idbRestoreConfirmAction;

  /// No description provided for @idbRestoreBusy.
  ///
  /// In en, this message translates to:
  /// **'Rotating the key…'**
  String get idbRestoreBusy;

  /// No description provided for @idbRestoreOk.
  ///
  /// In en, this message translates to:
  /// **'Restore complete. The identity on the old phone is now dead — wipe its data.'**
  String get idbRestoreOk;

  /// No description provided for @idbRestoreFail.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {code}'**
  String idbRestoreFail(String code);

  /// No description provided for @idbErrHubNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No hub address is configured, so the key cannot be rotated. Set the server address in world settings first.'**
  String get idbErrHubNotConfigured;

  /// No description provided for @idbErrIdMismatch.
  ///
  /// In en, this message translates to:
  /// **'The user ID doesn\'t match the identity inside the recovery code — check you\'re using the right backup.'**
  String get idbErrIdMismatch;

  /// No description provided for @idbErrBadPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password, or the recovery code has been altered.'**
  String get idbErrBadPassword;

  /// No description provided for @idbErrBadFormat.
  ///
  /// In en, this message translates to:
  /// **'The recovery code is malformed (copy it in full; don\'t drop segments).'**
  String get idbErrBadFormat;

  /// No description provided for @idbErrNotCurrentKey.
  ///
  /// In en, this message translates to:
  /// **'This identity\'s current key is no longer that one — it may already have been rotated.'**
  String get idbErrNotCurrentKey;

  /// No description provided for @idbRestoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local identity isn\'t ready yet, so back-up/restore is unavailable.'**
  String get idbRestoreUnavailable;

  /// No description provided for @idbStatusBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Identity backed up'**
  String get idbStatusBackedUp;

  /// No description provided for @idbStatusBackedUpHint.
  ///
  /// In en, this message translates to:
  /// **'The recovery code for the current key is written down. Restoring it later invalidates this device.'**
  String get idbStatusBackedUpHint;

  /// No description provided for @idbStatusNotBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Identity NOT backed up'**
  String get idbStatusNotBackedUp;

  /// No description provided for @idbStatusNotBackedUpHint.
  ///
  /// In en, this message translates to:
  /// **'If this phone is lost or broken, the identity and all history are gone forever — nobody, including us, can reissue them.'**
  String get idbStatusNotBackedUpHint;

  /// No description provided for @arcSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Export local data'**
  String get arcSectionTitle;

  /// No description provided for @arcExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export local data'**
  String get arcExportAction;

  /// No description provided for @arcExportNote.
  ///
  /// In en, this message translates to:
  /// **'Set a password for this archive. It does NOT have to match your recovery-code password — and it is better if it doesn\'t.'**
  String get arcExportNote;

  /// No description provided for @arcSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive created'**
  String get arcSavedTitle;

  /// No description provided for @arcSavedPath.
  ///
  /// In en, this message translates to:
  /// **'Saved to:'**
  String get arcSavedPath;

  /// No description provided for @arcSavedNoPath.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t write a file (no storage access), but the archive is ready to copy.'**
  String get arcSavedNoPath;

  /// No description provided for @arcSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Keep the file AND the password separately. Without the password this file is unreadable — not even by us.'**
  String get arcSavedHint;

  /// No description provided for @arcImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get arcImportAction;

  /// No description provided for @arcImportNote.
  ///
  /// In en, this message translates to:
  /// **'Pick the .dahuang file, or paste its contents. Nothing is written until you confirm, and existing records are never overwritten or deleted.'**
  String get arcImportNote;

  /// No description provided for @arcPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get arcPickFile;

  /// No description provided for @arcImportCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive contents'**
  String get arcImportCodeLabel;

  /// No description provided for @arcImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import this archive?'**
  String get arcImportConfirmTitle;

  /// No description provided for @arcImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Will write {rows} rows across {tables} tables and continue the log up to {logsize} entries. Existing records are kept.'**
  String arcImportConfirmBody(int rows, int tables, int logsize);

  /// No description provided for @arcImportOk.
  ///
  /// In en, this message translates to:
  /// **'Import finished: {count} rows written.'**
  String arcImportOk(int count);

  /// No description provided for @arcErrNotArchive.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a valid .dahuang archive.'**
  String get arcErrNotArchive;

  /// No description provided for @arcLogConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Import refused: log can\'t be continued'**
  String get arcLogConflictTitle;

  /// No description provided for @arcLogConflictBody.
  ///
  /// In en, this message translates to:
  /// **'This device\'s transparency log and the archive\'s log don\'t line up, so continuing would silently break the hash chain. Nothing was imported. Import the archive into a device with an empty log, or ask for help.'**
  String get arcLogConflictBody;

  /// No description provided for @onbBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your identity'**
  String get onbBackupTitle;

  /// No description provided for @onbBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One code, written on paper. It is the only way back if your phone dies.'**
  String get onbBackupSubtitle;

  /// No description provided for @onbBackupWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why this matters'**
  String get onbBackupWhyTitle;

  /// No description provided for @onbBackupWhy.
  ///
  /// In en, this message translates to:
  /// **'Your identity is self-certifying: the key lives only on this phone. If the phone dies, the identity and every record under it are gone forever — we cannot reissue them, because we never had the key.'**
  String get onbBackupWhy;

  /// No description provided for @onbBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Recovery code written down — you have a way back.'**
  String get onbBackupDone;

  /// No description provided for @onbSkipBackup.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onbSkipBackup;

  /// No description provided for @onbSkipWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue without a backup?'**
  String get onbSkipWarnTitle;

  /// No description provided for @onbSkipWarnBody.
  ///
  /// In en, this message translates to:
  /// **'Without a recovery code, losing this phone means losing your identity, your history and your reputation permanently. Nobody can restore them. You can still do this later from Passport → Identity backup, but until then there is no way back.'**
  String get onbSkipWarnBody;

  /// No description provided for @onbSkipConfirm.
  ///
  /// In en, this message translates to:
  /// **'I understand, continue'**
  String get onbSkipConfirm;

  /// No description provided for @onboardingStepBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get onboardingStepBackup;

  /// No description provided for @rcTitle.
  ///
  /// In en, this message translates to:
  /// **'Key rotation chain'**
  String get rcTitle;

  /// No description provided for @rcIntro.
  ///
  /// In en, this message translates to:
  /// **'Every time this identity moves to a new phone, it leaves one signed, append-only record here. Anyone can fetch the same data and check it — no account needed.'**
  String get rcIntro;

  /// No description provided for @rcFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching…'**
  String get rcFetching;

  /// No description provided for @rcRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get rcRefreshAction;

  /// No description provided for @rcFetchFail.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the chain: {reason}'**
  String rcFetchFail(String reason);

  /// No description provided for @rcUnknownIdentity.
  ///
  /// In en, this message translates to:
  /// **'The Hub does not know this identity.'**
  String get rcUnknownIdentity;

  /// No description provided for @rcNoRotations.
  ///
  /// In en, this message translates to:
  /// **'This identity has never rotated its key.'**
  String get rcNoRotations;

  /// No description provided for @rcSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get rcSubjectTitle;

  /// No description provided for @rcAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get rcAgentLabel;

  /// No description provided for @rcDidLabel.
  ///
  /// In en, this message translates to:
  /// **'DID (identity anchor)'**
  String get rcDidLabel;

  /// No description provided for @rcCurrentKey.
  ///
  /// In en, this message translates to:
  /// **'Currently active key'**
  String get rcCurrentKey;

  /// No description provided for @rcRegisteredYes.
  ///
  /// In en, this message translates to:
  /// **'Registered on the Hub'**
  String get rcRegisteredYes;

  /// No description provided for @rcRegisteredNo.
  ///
  /// In en, this message translates to:
  /// **'No registration record'**
  String get rcRegisteredNo;

  /// No description provided for @rcLocalVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Check it myself'**
  String get rcLocalVerifyAction;

  /// No description provided for @rcVerifyingAction.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get rcVerifyingAction;

  /// No description provided for @rcVerdictOk.
  ///
  /// In en, this message translates to:
  /// **'Passed: every record carries a valid signature, the chain links up end to end, and its tip is the key the Hub lists as active.'**
  String get rcVerdictOk;

  /// No description provided for @rcVerdictSigInvalid.
  ///
  /// In en, this message translates to:
  /// **'FAILED: {n} record(s) have a signature that does not check out.'**
  String rcVerdictSigInvalid(int n);

  /// No description provided for @rcVerdictLinkMismatch.
  ///
  /// In en, this message translates to:
  /// **'FAILED: the chain is broken — a record does not continue from the one before it.'**
  String get rcVerdictLinkMismatch;

  /// No description provided for @rcVerdictTipNotActive.
  ///
  /// In en, this message translates to:
  /// **'FAILED: the last record does not point at the key the Hub lists as active, so a rotation is missing from this list.'**
  String get rcVerdictTipNotActive;

  /// No description provided for @rcVerdictTitle.
  ///
  /// In en, this message translates to:
  /// **'My own check'**
  String get rcVerdictTitle;

  /// No description provided for @rcHubClaimTitle.
  ///
  /// In en, this message translates to:
  /// **'What the Hub says'**
  String get rcHubClaimTitle;

  /// No description provided for @rcHubClaimOk.
  ///
  /// In en, this message translates to:
  /// **'The Hub reports no broken links.'**
  String get rcHubClaimOk;

  /// No description provided for @rcHubClaimBroken.
  ///
  /// In en, this message translates to:
  /// **'The Hub reports broken chains for {n} identity(ies).'**
  String rcHubClaimBroken(int n);

  /// No description provided for @rcRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get rcRecordsTitle;

  /// No description provided for @rcRecordSeq.
  ///
  /// In en, this message translates to:
  /// **'#{i}'**
  String rcRecordSeq(int i);

  /// No description provided for @rcRecordFrom.
  ///
  /// In en, this message translates to:
  /// **'Retired key'**
  String get rcRecordFrom;

  /// No description provided for @rcRecordTo.
  ///
  /// In en, this message translates to:
  /// **'New key'**
  String get rcRecordTo;

  /// No description provided for @rcRecordSigOk.
  ///
  /// In en, this message translates to:
  /// **'signature OK'**
  String get rcRecordSigOk;

  /// No description provided for @rcRecordSigBad.
  ///
  /// In en, this message translates to:
  /// **'signature BAD'**
  String get rcRecordSigBad;

  /// No description provided for @rcAnchorTitle.
  ///
  /// In en, this message translates to:
  /// **'Anchored in the public log'**
  String get rcAnchorTitle;

  /// No description provided for @rcAnchorNote.
  ///
  /// In en, this message translates to:
  /// **'Log size {size}, Merkle root {root}. Pinning this root lets you prove later that this list was not rewritten.'**
  String rcAnchorNote(int size, String root);

  /// No description provided for @dmTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to a new phone'**
  String get dmTitle;

  /// No description provided for @dmIntro.
  ///
  /// In en, this message translates to:
  /// **'Your identity is a key that lives only on your phone. Moving it means signing the identity over to a new key on the new phone — the old key then stops working everywhere.'**
  String get dmIntro;

  /// No description provided for @dmRoleNewTitle.
  ///
  /// In en, this message translates to:
  /// **'This is the new phone'**
  String get dmRoleNewTitle;

  /// No description provided for @dmRoleNewBody.
  ///
  /// In en, this message translates to:
  /// **'Start here. This phone will ask the old one to hand the identity over.'**
  String get dmRoleNewBody;

  /// No description provided for @dmRoleNewAction.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get dmRoleNewAction;

  /// No description provided for @dmRoleOldTitle.
  ///
  /// In en, this message translates to:
  /// **'This is the old phone'**
  String get dmRoleOldTitle;

  /// No description provided for @dmRoleOldBody.
  ///
  /// In en, this message translates to:
  /// **'Wait here. When the new phone asks, you will be shown a code to compare.'**
  String get dmRoleOldBody;

  /// No description provided for @dmRoleOldAction.
  ///
  /// In en, this message translates to:
  /// **'Wait for a request'**
  String get dmRoleOldAction;

  /// No description provided for @dmWaitingPeer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other phone…'**
  String get dmWaitingPeer;

  /// No description provided for @dmPeerFound.
  ///
  /// In en, this message translates to:
  /// **'The other phone answered.'**
  String get dmPeerFound;

  /// No description provided for @dmCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare these codes'**
  String get dmCompareTitle;

  /// No description provided for @dmCompareBody.
  ///
  /// In en, this message translates to:
  /// **'Both phones must show exactly the same code. The code covers both keys and the request, so if anyone swapped anything in between, the codes will differ.'**
  String get dmCompareBody;

  /// No description provided for @dmCodeMatchAction.
  ///
  /// In en, this message translates to:
  /// **'They match'**
  String get dmCodeMatchAction;

  /// No description provided for @dmCodeNoMatchAction.
  ///
  /// In en, this message translates to:
  /// **'They don\'t match'**
  String get dmCodeNoMatchAction;

  /// No description provided for @dmNoKeyLeaves.
  ///
  /// In en, this message translates to:
  /// **'Your private key never leaves either phone. The old phone signs the hand-over itself; nothing is copied.'**
  String get dmNoKeyLeaves;

  /// No description provided for @dmConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm and move'**
  String get dmConfirmAction;

  /// No description provided for @dmOldConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand this identity over?'**
  String get dmOldConfirmTitle;

  /// No description provided for @dmOldConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will sign the identity over to the new phone. Afterwards this phone is signed out and its key stops working.'**
  String get dmOldConfirmBody;

  /// No description provided for @dmGapATitle.
  ///
  /// In en, this message translates to:
  /// **'Your history moves with you'**
  String get dmGapATitle;

  /// No description provided for @dmGapABody.
  ///
  /// In en, this message translates to:
  /// **'Endorsements you received online follow the identity — a rotation retires the KEY, not the person. After restoring on a new phone, the old key\'s endorsements are pulled back automatically and each one is verified locally. The old key itself stays dead: it can no longer sign anything.'**
  String get dmGapABody;

  /// No description provided for @dmBackupReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you have a recovery code?'**
  String get dmBackupReminderTitle;

  /// No description provided for @dmBackupReminderBody.
  ///
  /// In en, this message translates to:
  /// **'This move needs both phones working at the same time. If you have a written recovery code, you can also restore without the old phone.'**
  String get dmBackupReminderBody;

  /// No description provided for @dmPhaseOffered.
  ///
  /// In en, this message translates to:
  /// **'Request received, waiting for you to confirm.'**
  String get dmPhaseOffered;

  /// No description provided for @dmPhaseSigned.
  ///
  /// In en, this message translates to:
  /// **'Signed. Submitting to the Hub…'**
  String get dmPhaseSigned;

  /// No description provided for @dmPhaseAwaitingHub.
  ///
  /// In en, this message translates to:
  /// **'The Hub is rebinding the identity…'**
  String get dmPhaseAwaitingHub;

  /// No description provided for @dmDoneNew.
  ///
  /// In en, this message translates to:
  /// **'Done. This phone now holds the identity.'**
  String get dmDoneNew;

  /// No description provided for @dmDoneOld.
  ///
  /// In en, this message translates to:
  /// **'Done. This phone is now signed out.'**
  String get dmDoneOld;

  /// No description provided for @dmDoneOldHint.
  ///
  /// In en, this message translates to:
  /// **'The identity has moved, but the chats and data on this phone do not come along (a direct handover moves the identity only). Export an archive first if you want to keep them.'**
  String get dmDoneOldHint;

  /// No description provided for @dmCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dmCancelAction;

  /// No description provided for @dmCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Nothing was changed.'**
  String get dmCancelled;

  /// No description provided for @dmCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop moving?'**
  String get dmCancelConfirmTitle;

  /// No description provided for @dmCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been handed over yet. Stopping now leaves both phones exactly as they are.'**
  String get dmCancelConfirmBody;

  /// No description provided for @dmErrPeerMismatch.
  ///
  /// In en, this message translates to:
  /// **'That request was for a different identity. Refused.'**
  String get dmErrPeerMismatch;

  /// No description provided for @dmErrBadCode.
  ///
  /// In en, this message translates to:
  /// **'The codes did not match. Nothing was handed over.'**
  String get dmErrBadCode;

  /// No description provided for @dmErrHubFailed.
  ///
  /// In en, this message translates to:
  /// **'The Hub refused the hand-over ({code}). Nothing was changed.'**
  String dmErrHubFailed(String code);

  /// No description provided for @dmErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'The other phone stopped answering. Nothing was changed.'**
  String get dmErrTimeout;

  /// No description provided for @dmErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({code}).'**
  String dmErrGeneric(String code);

  /// No description provided for @dmRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dmRetryAction;

  /// No description provided for @dmRetryApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Finish installing on this phone'**
  String get dmRetryApplyAction;

  /// No description provided for @dmErrSessionTimeout.
  ///
  /// In en, this message translates to:
  /// **'This handover sat idle for too long and expired. Nothing was handed over, so you can start again.'**
  String get dmErrSessionTimeout;

  /// No description provided for @dmErrApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'The Hub has already made this phone the sole holder of that identity, but this phone failed to install the new key. Tap the button below to finish — until then this phone cannot use that identity.'**
  String get dmErrApplyFailed;

  /// No description provided for @dmErrApplyFailedOld.
  ///
  /// In en, this message translates to:
  /// **'The server already rebound the identity to the new phone, but the new phone failed to install the new key. Tap the finish-install button on that phone; until then this phone cannot use the identity either.'**
  String get dmErrApplyFailedOld;

  /// No description provided for @dmNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No Hub address is set, so the identity cannot be rebound. Set it under Setup first.'**
  String get dmNotConfigured;

  /// No description provided for @dutyAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Let your agent stay on duty?'**
  String get dutyAskTitle;

  /// No description provided for @dutyAskBody.
  ///
  /// In en, this message translates to:
  /// **'With these two permissions your agent keeps working while the screen is off: it fetches messages, replies, and syncs its public records — then sleeps. The on-duty notification will stay visible so you always know it is working. You can skip and still use every feature while the app is open.'**
  String get dutyAskBody;

  /// No description provided for @dutyAskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Grant permissions'**
  String get dutyAskConfirm;

  /// No description provided for @dutyAskLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get dutyAskLater;

  /// No description provided for @radarAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Before the radar turns on, here\'s what it needs'**
  String get radarAskTitle;

  /// No description provided for @radarAskBody.
  ///
  /// In en, this message translates to:
  /// **'The physical radar uses Nearby Devices (Bluetooth / Wi-Fi Direct) to find each other on the same Wi-Fi. Android files Bluetooth scanning under the Location permission, so the system dialog also asks for location. That is the OS rule, not this app wanting your location.\n\nThis app never reads, stores, or uploads location data, and the Nearby Devices permission is declared with neverForLocation (the OS blocks inferring location from Bluetooth).\n\nThe system permission dialogs come next. Declining changes nothing else in the app; the radar simply won\'t see anyone.'**
  String get radarAskBody;

  /// No description provided for @dutyDoneToast.
  ///
  /// In en, this message translates to:
  /// **'On-duty permissions granted. Your agent can now work with the screen off.'**
  String get dutyDoneToast;

  /// No description provided for @dutyPartialToast.
  ///
  /// In en, this message translates to:
  /// **'Some permissions were not granted. The agent still works while the app is open, but may be paused by the system in the background.'**
  String get dutyPartialToast;

  /// No description provided for @romGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your agent alive after the screen locks'**
  String get romGuideTitle;

  /// No description provided for @romGuideGo.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get romGuideGo;

  /// No description provided for @romGuideDismiss.
  ///
  /// In en, this message translates to:
  /// **'Don\'t remind me again'**
  String get romGuideDismiss;

  /// No description provided for @romStepsXiaomi.
  ///
  /// In en, this message translates to:
  /// **'On Xiaomi/Redmi (MIUI/HyperOS): 1) Settings → Apps → Manage apps → Dahuang AI → enable Autostart; 2) Security app → Battery → Dahuang AI → No restrictions. Without these, the system kills the agent within minutes after the screen locks.'**
  String get romStepsXiaomi;

  /// No description provided for @romStepsHuawei.
  ///
  /// In en, this message translates to:
  /// **'On Huawei (EMUI/HarmonyOS): Settings → Apps → App launch management → Dahuang AI → turn off Manage automatically, then enable all three: Auto-launch, Secondary launch, Run in background.'**
  String get romStepsHuawei;

  /// No description provided for @romStepsHonor.
  ///
  /// In en, this message translates to:
  /// **'On Honor (MagicOS): Settings → Apps → App launch management → Dahuang AI → turn off Manage automatically, then enable Auto-launch, Secondary launch and Run in background.'**
  String get romStepsHonor;

  /// No description provided for @romStepsOppo.
  ///
  /// In en, this message translates to:
  /// **'On OPPO/realme (ColorOS): Settings → Apps → App management → Dahuang AI → allow Autostart; Settings → Battery → More settings → allow full background behaviour for Dahuang AI.'**
  String get romStepsOppo;

  /// No description provided for @romStepsOneplus.
  ///
  /// In en, this message translates to:
  /// **'On OnePlus: Settings → Apps → Auto-launch → allow Dahuang AI; Battery → optimize the battery usage of Dahuang AI to Don\'t optimize.'**
  String get romStepsOneplus;

  /// No description provided for @romStepsVivo.
  ///
  /// In en, this message translates to:
  /// **'On vivo/iQOO (OriginOS): Settings → Apps → Permission management → Autostart, allow Dahuang AI; Settings → Battery → Background power consumption → allow high background drain for Dahuang AI.'**
  String get romStepsVivo;

  /// No description provided for @romStepsMeizu.
  ///
  /// In en, this message translates to:
  /// **'On Meizu (Flyme): Phone Manager → App permissions → Background management → allow Dahuang AI to keep running.'**
  String get romStepsMeizu;

  /// No description provided for @romStepsSamsung.
  ///
  /// In en, this message translates to:
  /// **'On Samsung (One UI): Settings → Battery → Background usage limits → remove Dahuang AI from Deep sleeping apps.'**
  String get romStepsSamsung;

  /// No description provided for @romStepsGeneric.
  ///
  /// In en, this message translates to:
  /// **'If your system aggressively stops background apps, allow Dahuang AI to autostart and exclude it from battery optimization in system settings.'**
  String get romStepsGeneric;

  /// No description provided for @helpDotTooltip.
  ///
  /// In en, this message translates to:
  /// **'How this works'**
  String get helpDotTooltip;

  /// No description provided for @helpSheetClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get helpSheetClose;

  /// No description provided for @helpWorldOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'How the lobby works'**
  String get helpWorldOverviewTitle;

  /// No description provided for @helpWorldOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'Official rooms are open to everyone. Personal rooms appear only to their owner and members: others need the exact room number, then a request, then the owner\'s approval. Inside a room every message goes out on the room\'s own pace (8s by default); hitting that pace is refused by the server, which tells you to wait a moment.'**
  String get helpWorldOverviewBody;

  /// No description provided for @helpWorldMetricTitle.
  ///
  /// In en, this message translates to:
  /// **'Cross-circle links per person'**
  String get helpWorldMetricTitle;

  /// No description provided for @helpWorldMetricBody.
  ///
  /// In en, this message translates to:
  /// **'Local scope: numerator = my cross-circle edges, denominator = the distinct agents I have met. Platform-wide per-capita needs server-side aggregation, and the server deliberately does not carry circle relationships.'**
  String get helpWorldMetricBody;

  /// No description provided for @helpWorldBridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Friend-pool introductions'**
  String get helpWorldBridgeTitle;

  /// No description provided for @helpWorldBridgeBody.
  ///
  /// In en, this message translates to:
  /// **'Outsiders you meet in a room can be introduced with one tap. Cross-circle edges only grow out of rooms: no room, no edge.'**
  String get helpWorldBridgeBody;

  /// No description provided for @helpWorldRoomRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Room roles'**
  String get helpWorldRoomRoleTitle;

  /// No description provided for @helpWorldRoomRoleBody.
  ///
  /// In en, this message translates to:
  /// **'Roles belong to the room and never change your identity. The same you can hold different roles in different rooms.'**
  String get helpWorldRoomRoleBody;

  /// No description provided for @helpIntercardDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'What a card discloses'**
  String get helpIntercardDisclosureTitle;

  /// No description provided for @helpIntercardDisclosureBody.
  ///
  /// In en, this message translates to:
  /// **'Only level-2 fields go on the card; fields visible to you alone never do. Anyone can recompute what the card contains.'**
  String get helpIntercardDisclosureBody;

  /// No description provided for @helpPassportOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'What the passport is'**
  String get helpPassportOverviewTitle;

  /// No description provided for @helpPassportOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'Your passport is a public key, not an account: it verifies offline and logs in to no server. Moving to a new phone relies on your recovery code or a key rotation, never on a platform help desk.'**
  String get helpPassportOverviewBody;

  /// No description provided for @helpPassportOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Verifiable offline'**
  String get helpPassportOfflineTitle;

  /// No description provided for @helpPassportOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'The public key IS the identity: this passport verifies offline, with no server lookup.'**
  String get helpPassportOfflineBody;

  /// No description provided for @helpPassportFunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'How the funnel denominator works'**
  String get helpPassportFunnelTitle;

  /// No description provided for @helpPassportFunnelBody.
  ///
  /// In en, this message translates to:
  /// **'The denominator counts only settled records; in-flight is not a failure. Only records whose mutual consent actually verifies enter the denominator.'**
  String get helpPassportFunnelBody;

  /// No description provided for @helpPassportReputationTitle.
  ///
  /// In en, this message translates to:
  /// **'Why there is no global score'**
  String get helpPassportReputationTitle;

  /// No description provided for @helpPassportReputationBody.
  ///
  /// In en, this message translates to:
  /// **'A global reputation score would be trivially fakeable, so there is none. What you see is always relative to YOUR anchors: signed endorsements, decayed by distance.\\n\\nCasual acquaintances are not a starting point for trust propagation — otherwise mass-friending would inflate your reach.\\n\\nWhen a lookup finds nothing it says \\\"unknown\\\", and that is not a score of zero: it means genuinely unknown, and anyone who turns it into a number is guessing.'**
  String get helpPassportReputationBody;

  /// No description provided for @helpPassportLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Transparency log'**
  String get helpPassportLogTitle;

  /// No description provided for @helpPassportLogBody.
  ///
  /// In en, this message translates to:
  /// **'You do not have to trust me, you can verify me: anyone can download the log, recompute the root, and check whether their own record was tampered with.'**
  String get helpPassportLogBody;

  /// No description provided for @helpSocialOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'What the social tab does'**
  String get helpSocialOverviewTitle;

  /// No description provided for @helpSocialOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'The roster and friends sit on top; radar status and the social ledger below. The radar decides whether messages leave at all: with it off, pressing send still sends nothing off this phone.'**
  String get helpSocialOverviewBody;

  /// No description provided for @helpSocialPersonaTierTitle.
  ///
  /// In en, this message translates to:
  /// **'Specialised persona modes'**
  String get helpSocialPersonaTierTitle;

  /// No description provided for @helpSocialPersonaTierBody.
  ///
  /// In en, this message translates to:
  /// **'A lock marks a specialised persona mode. Billing is not live yet, so every mode can be switched freely for now.'**
  String get helpSocialPersonaTierBody;

  /// No description provided for @helpSocialRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'Radar and channels'**
  String get helpSocialRadarTitle;

  /// No description provided for @helpSocialRadarBody.
  ///
  /// In en, this message translates to:
  /// **'With the radar off you can still browse the roster, but nothing leaves this phone: sending is silently dropped. Turn the radar on and enable at least one channel (nearby / LAN / cloud).\\n\\nA verifiable, fixed identity appears only after both sides enable the radar and complete one proximity handshake.'**
  String get helpSocialRadarBody;

  /// No description provided for @helpSocialChannelGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels & network troubleshooting'**
  String get helpSocialChannelGuideTitle;

  /// No description provided for @helpSocialChannelGuideBody.
  ///
  /// In en, this message translates to:
  /// **'1. With the physical radar on, make sure the current network can reach the internet.\n2. With the Nearby channel on, the system may switch Wi-Fi on by itself — this is normal transport upscaling (Bluetooth discovers, Wi-Fi Direct carries the data; no network is joined). It stops once the Nearby channel is off.\n3. To save battery on the go: use the Cloud channel only and turn Wi-Fi off manually (with Nearby on, the system re-enables Wi-Fi — expected, no need to keep fighting it).'**
  String get helpSocialChannelGuideBody;

  /// No description provided for @socialRadarOffHint.
  ///
  /// In en, this message translates to:
  /// **'Radar is off. You can still browse the roster, but nothing leaves this phone: sending is silently dropped. Turn the radar on and enable at least one channel (nearby / LAN / cloud) before sending.'**
  String get socialRadarOffHint;

  /// No description provided for @worldRoomCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close room'**
  String get worldRoomCloseAction;

  /// No description provided for @worldRoomCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close this room?'**
  String get worldRoomCloseTitle;

  /// No description provided for @worldRoomCloseBody.
  ///
  /// In en, this message translates to:
  /// **'Once closed, the room leaves the public list and stops accepting new messages. The existing chat is kept as a read-only archive that current members can still revisit.'**
  String get worldRoomCloseBody;

  /// No description provided for @worldRoomCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close room'**
  String get worldRoomCloseConfirm;

  /// No description provided for @worldRoomClosedOk.
  ///
  /// In en, this message translates to:
  /// **'{name} is now closed — a read-only archive'**
  String worldRoomClosedOk(String name);

  /// No description provided for @worldRoomCloseFailed.
  ///
  /// In en, this message translates to:
  /// **'Close failed: {err}'**
  String worldRoomCloseFailed(String err);

  /// No description provided for @worldRoomClosedBadge.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get worldRoomClosedBadge;

  /// No description provided for @worldRoomClosedReadonlyHint.
  ///
  /// In en, this message translates to:
  /// **'Room closed — read-only archive, no new messages'**
  String get worldRoomClosedReadonlyHint;

  /// No description provided for @worldRoomClosedSendRejected.
  ///
  /// In en, this message translates to:
  /// **'This room is closed; you can no longer send messages'**
  String get worldRoomClosedSendRejected;

  /// No description provided for @worldRoomClosedSystemMsg.
  ///
  /// In en, this message translates to:
  /// **'The owner closed this room. It is now a read-only archive.'**
  String get worldRoomClosedSystemMsg;

  /// No description provided for @settingsLocalModelSection.
  ///
  /// In en, this message translates to:
  /// **'Local model fallback (offline degrade)'**
  String get settingsLocalModelSection;

  /// No description provided for @settingsLocalModelTest.
  ///
  /// In en, this message translates to:
  /// **'Test local model connection'**
  String get settingsLocalModelTest;

  /// No description provided for @settingsLocalModelTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get settingsLocalModelTesting;

  /// No description provided for @settingsLocalModelTestOk.
  ///
  /// In en, this message translates to:
  /// **'✅ Connected: {model} @ {url}'**
  String settingsLocalModelTestOk(String model, String url);

  /// No description provided for @settingsLocalModelTestDisabled.
  ///
  /// In en, this message translates to:
  /// **'Local fallback is off (the URL is empty). Enter a URL and test again if you want to use it.'**
  String get settingsLocalModelTestDisabled;

  /// No description provided for @settingsLocalModelTestUnreachable.
  ///
  /// In en, this message translates to:
  /// **'❌ Cannot reach {url}: nothing is listening there (or the port is closed). On a phone, 127.0.0.1 means the phone itself and the model server usually runs on a computer — check the address and try again.'**
  String settingsLocalModelTestUnreachable(String url);

  /// No description provided for @settingsLocalModelTestNotJson.
  ///
  /// In en, this message translates to:
  /// **'❌ Something answered, but it did not return the model API\'s JSON (likely a proxy or an error page). Make sure the address/port points at the Ollama / llama.cpp REST endpoint.'**
  String get settingsLocalModelTestNotJson;

  /// No description provided for @settingsLocalModelTestNoMessage.
  ///
  /// In en, this message translates to:
  /// **'❌ The endpoint responded, but no reply content could be read (common causes: the model name does not exist, or this is not an /api/chat style response).'**
  String get settingsLocalModelTestNoMessage;

  /// No description provided for @settingsLocalModelTestHttp.
  ///
  /// In en, this message translates to:
  /// **'❌ The service returned status {code} (not 200).'**
  String settingsLocalModelTestHttp(String code);

  /// No description provided for @helpSettingsLocalModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Local model fallback: when does it really work?'**
  String get helpSettingsLocalModelTitle;

  /// No description provided for @helpSettingsLocalModelBody.
  ///
  /// In en, this message translates to:
  /// **'The address here is only what you tell the app to use — \"filled in\" does not mean \"working\". On a phone, 127.0.0.1 points at the phone itself, while the model server (Ollama / llama.cpp) usually runs on a computer, so this default is normally unreachable from a phone. Its real purpose is: (1) if you run a model on your own computer, enter that computer\'s LAN address; (2) when a future build ships an on-device engine, point at a new port.\n\nClearing the address = explicitly disabling the local fallback (the app stops trying the local model).\n\nTo know whether it actually works, do not rely on whether the field is filled in — tap \"Test local model connection\" below: it sends one minimal live request and leaves the result on that line.'**
  String get helpSettingsLocalModelBody;

  /// No description provided for @glossaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Glossary'**
  String get glossaryTitle;

  /// No description provided for @glossaryIntro.
  ///
  /// In en, this message translates to:
  /// **'These words come up again and again in the app — explained once here. Tap a term to expand it.'**
  String get glossaryIntro;

  /// No description provided for @glossaryGroupIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity & device'**
  String get glossaryGroupIdentity;

  /// No description provided for @glossaryGroupSocial.
  ///
  /// In en, this message translates to:
  /// **'Social & discovery'**
  String get glossaryGroupSocial;

  /// No description provided for @glossaryGroupWorld.
  ///
  /// In en, this message translates to:
  /// **'World & lounge'**
  String get glossaryGroupWorld;

  /// No description provided for @glossaryGroupTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust & memory'**
  String get glossaryGroupTrust;

  /// No description provided for @glossaryAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent (your stand-in)'**
  String get glossaryAgentTitle;

  /// No description provided for @glossaryAgentBody.
  ///
  /// In en, this message translates to:
  /// **'The stand-in that lives on your phone. It thinks with the model key you entered and goes out to meet people first; while you are away it only does what you have allowed.'**
  String get glossaryAgentBody;

  /// No description provided for @glossaryMaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Diplomatic mask'**
  String get glossaryMaskTitle;

  /// No description provided for @glossaryMaskBody.
  ///
  /// In en, this message translates to:
  /// **'The face you show the outside world: your persona and speaking style. It decides what strangers see of you first.'**
  String get glossaryMaskBody;

  /// No description provided for @glossaryPassportTitle.
  ///
  /// In en, this message translates to:
  /// **'Wold Passport'**
  String get glossaryPassportTitle;

  /// No description provided for @glossaryPassportBody.
  ///
  /// In en, this message translates to:
  /// **'A verifiable, signed résumé that can be checked offline. Others do not need to trust any server — they just verify the signature.'**
  String get glossaryPassportBody;

  /// No description provided for @glossaryMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone migration (identity restore)'**
  String get glossaryMigrationTitle;

  /// No description provided for @glossaryMigrationBody.
  ///
  /// In en, this message translates to:
  /// **'Moving your identity to a new phone \"with proof\", after which the old phone\'s identity truly stops working. It is not copying a private key — it is a proof-backed key rotation, so the old phone really is invalidated.'**
  String get glossaryMigrationBody;

  /// No description provided for @glossaryRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get glossaryRadarTitle;

  /// No description provided for @glossaryRadarBody.
  ///
  /// In en, this message translates to:
  /// **'Discovers others on the same Wi-Fi via Nearby Devices (Bluetooth / Wi-Fi Direct). It never reads, stores, or uploads any location data — Android files Bluetooth scanning under \"Location\", and that is the OS rule.'**
  String get glossaryRadarBody;

  /// No description provided for @glossaryRosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Caught roster'**
  String get glossaryRosterTitle;

  /// No description provided for @glossaryRosterBody.
  ///
  /// In en, this message translates to:
  /// **'The roster built from people the radar picked up or you ran into in rooms. It is the starting point for every social relationship afterwards.'**
  String get glossaryRosterBody;

  /// No description provided for @glossaryIntercardTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent introduction (cross-circle edge)'**
  String get glossaryIntercardTitle;

  /// No description provided for @glossaryIntercardBody.
  ///
  /// In en, this message translates to:
  /// **'A formal introduction between two agents that only counts once both sides confirm. A cross-circle edge can only grow from a real shared room — never from claiming you know someone by an ID.'**
  String get glossaryIntercardBody;

  /// No description provided for @glossaryWorldTitle.
  ///
  /// In en, this message translates to:
  /// **'World / lounge'**
  String get glossaryWorldTitle;

  /// No description provided for @glossaryWorldBody.
  ///
  /// In en, this message translates to:
  /// **'\"World\" is the public cloud space; a \"lounge\" is a room inside it, much like a QQ group: official ones are open to all, personal ones require the room number and approval. While others chat, your agent only observes by default and does not cut in.'**
  String get glossaryWorldBody;

  /// No description provided for @glossaryRoomRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Room role'**
  String get glossaryRoomRoleTitle;

  /// No description provided for @glossaryRoomRoleBody.
  ///
  /// In en, this message translates to:
  /// **'Host / co-host / guest / functional role / participant. A role belongs to the room and does not change your identity — the same you can hold different roles in different rooms.'**
  String get glossaryRoomRoleBody;

  /// No description provided for @glossaryAutopilotTitle.
  ///
  /// In en, this message translates to:
  /// **'Autopilot'**
  String get glossaryAutopilotTitle;

  /// No description provided for @glossaryAutopilotBody.
  ///
  /// In en, this message translates to:
  /// **'Lets your agent speak in a room on its own while you are not looking at the screen, within an hourly budget. Off by default, and you can turn it off at any time.'**
  String get glossaryAutopilotBody;

  /// No description provided for @glossaryRepNetTitle.
  ///
  /// In en, this message translates to:
  /// **'Network endorsement'**
  String get glossaryRepNetTitle;

  /// No description provided for @glossaryRepNetBody.
  ///
  /// In en, this message translates to:
  /// **'Reputation signed layer by layer by you and your friends, which you can verify yourself. When no path can be found it says \"don\'t know\", not \"0\" — anyone who turns it into a definite number is guessing.'**
  String get glossaryRepNetBody;

  /// No description provided for @glossaryMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory distillation'**
  String get glossaryMemoryTitle;

  /// No description provided for @glossaryMemoryBody.
  ///
  /// In en, this message translates to:
  /// **'At night it distills your conversations into long-term memory and nudges how it talks. You can trigger one run manually on the Manage page.'**
  String get glossaryMemoryBody;

  /// No description provided for @glossaryProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Long-term profile'**
  String get glossaryProfileTitle;

  /// No description provided for @glossaryProfileBody.
  ///
  /// In en, this message translates to:
  /// **'What your agent gradually learns about you: the topics you keep returning to and the hours you are usually active. Computed on-device from event metadata only — never from chat text, and never uploaded. Settings → Memory can switch it off alone; turning off the Auto recall master switch stops it as well.'**
  String get glossaryProfileBody;

  /// No description provided for @glossarySerendipityTitle.
  ///
  /// In en, this message translates to:
  /// **'Serendipity lab'**
  String get glossarySerendipityTitle;

  /// No description provided for @glossarySerendipityBody.
  ///
  /// In en, this message translates to:
  /// **'A set of small exercises that treat \"luck\" as a training subject: morning rehearsal, circle-breaking challenges, setback reframing, glimmer notes, diary, and divination. Completing them earns Lp (luck energy).'**
  String get glossarySerendipityBody;

  /// No description provided for @helpSkillMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill market: what do these terms mean?'**
  String get helpSkillMarketTitle;

  /// No description provided for @helpSkillMarketBody.
  ///
  /// In en, this message translates to:
  /// **'Publish = put a skill you wrote on the market so other people\'s agents can use it. Publishing signs it with this device\'s identity private key — the key never leaves the device, and the form has no field for pasting a public key or signature, so forgery simply cannot be expressed in the UI.\n\nRisk tier (low / medium / high) = your own disclosure of how sensitive this skill is (does it go online, launch other apps, …). The higher the tier, the more the caller must grant on first use.\n\nCapability declaration = the exact list of capabilities the skill will use. Together with the risk tier, it is everything a caller sees when deciding whether to allow it.\n\nAuthor split = revenue from others using your skill is credited to you; this screen only sums listings signed with your public key, and the total reconciles item by item with the ledger.\n\nSigned listing = every skill carries a signature, so nobody has to trust the server — tap Verify signature and check it yourself.'**
  String get helpSkillMarketBody;

  /// No description provided for @helpSettingsRecallTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-recall'**
  String get helpSettingsRecallTitle;

  /// No description provided for @helpSettingsRecallBody.
  ///
  /// In en, this message translates to:
  /// **'When on, before each reply the app searches local memory for possibly relevant past events and hands them to the agent as context. Turning it off saves a little compute and context.'**
  String get helpSettingsRecallBody;

  /// No description provided for @helpIdentityRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restoring on a new phone'**
  String get helpIdentityRestoreTitle;

  /// No description provided for @helpIdentityRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'On a new phone, enter three things here: recovery code + passphrase + your user ID. The moment recovery succeeds, the old phone stops working.\n\nThis is a proven key rotation (ROTATE), not copying the private key over — so the identity number stays the same, but the old device is no longer valid.'**
  String get helpIdentityRestoreBody;

  /// No description provided for @helpIdentityArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity archive (.dahuang file)'**
  String get helpIdentityArchiveTitle;

  /// No description provided for @helpIdentityArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'The archive seals your identity record, social graph and log anchors into one .dahuang file with your passphrase: it never passes through our servers, so keep it in your own cloud drive or USB stick. It holds data only — never the identity private key.\n\nUse a passphrase different from the recovery code\'s if you can; keep the file and the passphrase apart — without the passphrase nobody can open the file (not even us).\n\nOn import, nothing is written until you confirm; importing only adds records, and never overwrites or deletes existing ones.'**
  String get helpIdentityArchiveBody;

  /// No description provided for @helpIdentityCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Copying the recovery code'**
  String get helpIdentityCodeTitle;

  /// No description provided for @helpIdentityCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press to select all and copy; if you write it down by hand, check it segment by segment.'**
  String get helpIdentityCodeBody;

  /// No description provided for @helpDeviceMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone-to-phone migration'**
  String get helpDeviceMigrationTitle;

  /// No description provided for @helpDeviceMigrationBody.
  ///
  /// In en, this message translates to:
  /// **'Both phones must be on the same Wi-Fi with this page open.\n\nWhat moves is the identity: afterwards, if this phone needs a server address, check Settings — the Hub and World addresses are unchanged.\n\nThe chat history and data already on this phone do not move (direct migration moves the identity only, not data).'**
  String get helpDeviceMigrationBody;

  /// No description provided for @helpRotationChainAuthorityTitle.
  ///
  /// In en, this message translates to:
  /// **'Which verdict counts'**
  String get helpRotationChainAuthorityTitle;

  /// No description provided for @helpRotationChainAuthorityBody.
  ///
  /// In en, this message translates to:
  /// **'The Hub column is only for comparison — the verdict above is computed on this phone, from the records you actually hold.\n\nIn other words, even if the Hub says otherwise you need not trust the server; the locally computed verdict is the one that counts.'**
  String get helpRotationChainAuthorityBody;

  /// No description provided for @helpToolBusTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool bus'**
  String get helpToolBusTitle;

  /// No description provided for @helpToolBusBody.
  ///
  /// In en, this message translates to:
  /// **'Every tool/skill carries a device signature and a capability declaration; medium- and high-risk capabilities need authorization on first use.\n\nTampered plugins never load — if the check fails, they are simply not attached to the bus.'**
  String get helpToolBusBody;

  /// No description provided for @onbFreeTrialBtn.
  ///
  /// In en, this message translates to:
  /// **'Start free · no key needed (20 turns)'**
  String get onbFreeTrialBtn;

  /// No description provided for @onbOwnKeyBtn.
  ///
  /// In en, this message translates to:
  /// **'I have my own API key'**
  String get onbOwnKeyBtn;

  /// No description provided for @onboardingTrialService.
  ///
  /// In en, this message translates to:
  /// **'Free trial (official relay)'**
  String get onboardingTrialService;

  /// No description provided for @onboardingTrialModelName.
  ///
  /// In en, this message translates to:
  /// **'Trial model (no key needed)'**
  String get onboardingTrialModelName;

  /// No description provided for @onboardingTrialNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'This is a free trial'**
  String get onboardingTrialNoticeTitle;

  /// No description provided for @onboardingTrialNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'No API key of your own is needed — conversations are relayed to the model through the official server, up to 20 turns. When the trial ends, you can add your own API key on the Manage page under Settings (relay: {hub}).'**
  String onboardingTrialNoticeBody(String hub);

  /// No description provided for @onboardingOwnReady.
  ///
  /// In en, this message translates to:
  /// **'{model} is ready — you can start chatting now.'**
  String onboardingOwnReady(String model);

  /// No description provided for @trialRemainingTurns.
  ///
  /// In en, this message translates to:
  /// **'{n} free turns left'**
  String trialRemainingTurns(int n);

  /// No description provided for @trialExhaustedReply.
  ///
  /// In en, this message translates to:
  /// **'Your agent wants to keep talking — register the recommended model platform (new accounts include a free token grant), paste your key in Settings, and the conversation continues without limits.'**
  String get trialExhaustedReply;

  /// No description provided for @trialGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get trialGoSettings;

  /// Trial channel returned 503 trial_not_configured (hub has no upstream pool configured)
  ///
  /// In en, this message translates to:
  /// **'The official free trial isn\'t open yet. Add your own model key in Settings to keep chatting without limits.'**
  String get trialNotConfiguredReply;

  /// Trial channel returned 415 input_type_unsupported (no live account for that modality)
  ///
  /// In en, this message translates to:
  /// **'The free trial can\'t take images or voice yet — please send text. Adding your own key in Settings unlocks everything.'**
  String get trialInputUnsupportedReply;

  /// Trial channel returned 429 (per-agent / per-IP minute / per-IP daily gate)
  ///
  /// In en, this message translates to:
  /// **'Too many free-trial requests just now — please wait a moment and send again.'**
  String get trialRateLimitedReply;

  /// Trial channel returned 502 trial_uppool_exhausted (every pooled account failed this round)
  ///
  /// In en, this message translates to:
  /// **'All free-trial accounts are busy right now — try again in a moment, or add your own key in Settings.'**
  String get trialPoolBusyReply;

  /// Trial channel failed for a reason we cannot turn into a specific instruction (400 / 401 / 413)
  ///
  /// In en, this message translates to:
  /// **'The free trial is temporarily unavailable. You can retry, or add your own key in Settings.'**
  String get trialUnavailableReply;

  /// Snackbar after an apikey change auto-switches the app out of trial mode (0.82.0)
  ///
  /// In en, this message translates to:
  /// **'✅ You entered your own key — switched from free trial to your own model. The endpoint now points to {baseUrl}.'**
  String settingsTrialSwitchedToOwn(String baseUrl);

  /// Header of the trial-managed notice card in Settings (0.82.0)
  ///
  /// In en, this message translates to:
  /// **'Free trial · managed for you'**
  String get trialManagedTitle;

  /// Body of the trial-managed notice card explaining auto-switch and one-tap restore (0.82.0)
  ///
  /// In en, this message translates to:
  /// **'In free trial, the endpoint and key below are managed by the official proxy — usually no need to change them. To use your own model: fill in your own API key and Save; the app will automatically leave trial mode and fix the endpoint for you. If you\'ve already changed them by mistake, tap \"Restore free trial\" to put everything back.'**
  String get trialManagedNotice;

  /// Button that rewrites the trial config back to the official trial endpoint/identity (0.82.0)
  ///
  /// In en, this message translates to:
  /// **'Restore free trial'**
  String get trialRestoreAction;

  /// Confirm dialog body for restoring the free-trial config (0.82.0)
  ///
  /// In en, this message translates to:
  /// **'This writes the official trial endpoint and this device\'s identity back, and switches the app to free-trial mode. Continue?'**
  String get trialRestoreConfirm;

  /// Snackbar after the free-trial config has been restored (0.82.0)
  ///
  /// In en, this message translates to:
  /// **'✅ Free trial restored.'**
  String get trialRestoreDone;

  /// No description provided for @socialTabLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get socialTabLogs;

  /// No description provided for @modePickerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modePickerTooltip;

  /// No description provided for @modeBeginnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Beginner mode'**
  String get modeBeginnerTitle;

  /// No description provided for @modeAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced mode'**
  String get modeAdvancedTitle;

  /// No description provided for @settingsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get settingsAdvancedTitle;

  /// No description provided for @settingsAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Engine, memory and soul-shaping options'**
  String get settingsAdvancedSubtitle;

  /// No description provided for @settingsModeHint.
  ///
  /// In en, this message translates to:
  /// **'Switch modes from the top toolbar'**
  String get settingsModeHint;

  /// Tooltip of the language button in the app bar
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langPickerTooltip;

  /// Language option: follow the device language
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get langFollowSystem;

  /// Secondary hint shown next to the follow-system option
  ///
  /// In en, this message translates to:
  /// **'(device)'**
  String get langFollowSystemHint;

  /// Onboarding step indicator: language step
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get onboardingStepLanguage;

  /// Title of the onboarding language step
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onbLangTitle;

  /// Subtitle of the onboarding language step
  ///
  /// In en, this message translates to:
  /// **'Your agent will reply in the language you pick here.'**
  String get onbLangSubtitle;

  /// Reassurance that the choice is not permanent
  ///
  /// In en, this message translates to:
  /// **'You can change it later from the language button at the top of the chat screen.'**
  String get onbLangChangeableHint;

  /// No description provided for @bigInputWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'This input is over 10,000 characters'**
  String get bigInputWarnTitle;

  /// No description provided for @bigInputWarnBody.
  ///
  /// In en, this message translates to:
  /// **'Long inputs consume noticeably more tokens. Send it anyway?'**
  String get bigInputWarnBody;

  /// No description provided for @bigInputConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send anyway'**
  String get bigInputConfirm;

  /// No description provided for @trialInputTooLong.
  ///
  /// In en, this message translates to:
  /// **'Free-trial input is capped at {n} characters (this round was not sent). Register the recommended model platform or add your own key to remove the limit.'**
  String trialInputTooLong(int n);

  /// No description provided for @memoryManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory & reminders'**
  String get memoryManagerTitle;

  /// No description provided for @memoryManagerIntro.
  ///
  /// In en, this message translates to:
  /// **'What your agent remembers about you. View it anytime, or delete what you no longer want it to keep. Deleting cannot be undone.'**
  String get memoryManagerIntro;

  /// No description provided for @reminderSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders & to-dos'**
  String get reminderSectionTitle;

  /// No description provided for @reminderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing pending. Say \"remind me tomorrow at 8\" in chat, or tap the button below.'**
  String get reminderEmpty;

  /// No description provided for @reminderAdd.
  ///
  /// In en, this message translates to:
  /// **'New reminder'**
  String get reminderAdd;

  /// No description provided for @reminderTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Pay the rent'**
  String get reminderTitleHint;

  /// No description provided for @reminderOptionalTime.
  ///
  /// In en, this message translates to:
  /// **'Time (optional)'**
  String get reminderOptionalTime;

  /// No description provided for @reminderNoRepeat.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get reminderNoRepeat;

  /// No description provided for @reminderRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get reminderRepeatDaily;

  /// No description provided for @reminderRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get reminderRepeatWeekly;

  /// No description provided for @reminderTodoTag.
  ///
  /// In en, this message translates to:
  /// **'To-do (no time)'**
  String get reminderTodoTag;

  /// No description provided for @memorySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Episodic memories'**
  String get memorySectionTitle;

  /// No description provided for @memoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'The agent hasn\'t written down anything yet.'**
  String get memoryEmpty;

  /// No description provided for @memoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this memory? The related chat line will be removed too. This cannot be undone.'**
  String get memoryDeleteConfirm;

  /// No description provided for @sessionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation traces'**
  String get sessionSectionTitle;

  /// No description provided for @sessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversation traces.'**
  String get sessionEmpty;

  /// No description provided for @sessionForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get sessionForget;

  /// No description provided for @sessionForgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Forget this whole conversation? The agent will no longer recall it, count it in your profile, or feed it back to the model. This cannot be undone.'**
  String get sessionForgetConfirm;

  /// No description provided for @sessionEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String sessionEventsCount(Object count);

  /// No description provided for @settingsMemoryManager.
  ///
  /// In en, this message translates to:
  /// **'Manage reminders & memory'**
  String get settingsMemoryManager;

  /// No description provided for @notifyReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get notifyReminderTitle;

  /// No description provided for @notifyReminderBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s time: {title}'**
  String notifyReminderBody(Object title);

  /// No description provided for @morningHiReminders.
  ///
  /// In en, this message translates to:
  /// **'{count} reminder(s) or to-do(s) for today'**
  String morningHiReminders(Object count);

  /// No description provided for @settingsSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search service (optional)'**
  String get settingsSearchTitle;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Bring your own search key for richer multi-source results via web_search_pro. Without a key everything still works in basic mode (Wikipedia + Jina). Your key goes only to the provider you choose — never to us.'**
  String get settingsSearchHint;

  /// No description provided for @settingsSearchProvider.
  ///
  /// In en, this message translates to:
  /// **'Search provider'**
  String get settingsSearchProvider;

  /// No description provided for @settingsSearchBasicMode.
  ///
  /// In en, this message translates to:
  /// **'Basic mode (no key)'**
  String get settingsSearchBasicMode;

  /// No description provided for @settingsSearchApiKey.
  ///
  /// In en, this message translates to:
  /// **'Search API key'**
  String get settingsSearchApiKey;

  /// No description provided for @settingsSearchSearxngUrl.
  ///
  /// In en, this message translates to:
  /// **'SearXNG URL'**
  String get settingsSearchSearxngUrl;

  /// No description provided for @settingsSearchSearxngUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Your self-hosted SearXNG instance, e.g. https://search.example.com'**
  String get settingsSearchSearxngUrlHint;

  /// No description provided for @chatVoiceInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice to text'**
  String get chatVoiceInputTitle;

  /// No description provided for @chatVoiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening... speak now'**
  String get chatVoiceListening;

  /// No description provided for @chatVoiceNoRecognizer.
  ///
  /// In en, this message translates to:
  /// **'No speech recognition service on this device (install a voice service such as Google\'s, or use text input).'**
  String get chatVoiceNoRecognizer;

  /// No description provided for @chatVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition failed: {err}'**
  String chatVoiceFailed(Object err);

  /// No description provided for @settingsTtsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Read replies aloud'**
  String get settingsTtsEnabled;

  /// No description provided for @settingsTtsHint.
  ///
  /// In en, this message translates to:
  /// **'The agent reads each reply aloud using your phone\'s voice (off by default). A stop button appears while speaking. Speech is synthesized on-device and never leaves your phone.'**
  String get settingsTtsHint;

  /// No description provided for @settingsTtsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get settingsTtsStop;

  /// No description provided for @chatAttachOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add photos or documents'**
  String get chatAttachOptionsTitle;

  /// No description provided for @chatPickDocument.
  ///
  /// In en, this message translates to:
  /// **'Document (PDF / Word / Excel / text)'**
  String get chatPickDocument;

  /// No description provided for @chatDocParsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing document on-device...'**
  String get chatDocParsing;

  /// No description provided for @chatDocParsed.
  ///
  /// In en, this message translates to:
  /// **'Parsed {chars} characters (parsed on-device, never uploaded)'**
  String chatDocParsed(Object chars);

  /// No description provided for @chatDocParsedTruncated.
  ///
  /// In en, this message translates to:
  /// **'Document too large: sending first {chars} characters (parsed on-device, never uploaded)'**
  String chatDocParsedTruncated(Object chars);

  /// No description provided for @chatDocParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read document: {err}'**
  String chatDocParseFailed(Object err);

  /// No description provided for @settingsCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'System calendar (read-only)'**
  String get settingsCalendarTitle;

  /// No description provided for @settingsCalendarHint.
  ///
  /// In en, this message translates to:
  /// **'Once allowed, your morning greeting includes today\'s schedule and the agent can check it for you. Read-only — your calendar is never modified.'**
  String get settingsCalendarHint;

  /// No description provided for @settingsCalendarGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow reading'**
  String get settingsCalendarGrant;

  /// No description provided for @settingsCalendarGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get settingsCalendarGranted;

  /// No description provided for @settingsCalendarDenied.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get settingsCalendarDenied;

  /// No description provided for @settingsCalendarUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported in this build'**
  String get settingsCalendarUnsupported;

  /// No description provided for @calendarPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Calendar read permission is required'**
  String get calendarPermissionNeeded;

  /// No description provided for @calendarAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calendarAllDay;

  /// w5 morningHiCalendar
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule: {items}'**
  String morningHiCalendar(String items);

  /// No description provided for @settingsWeeklyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent weekly report'**
  String get settingsWeeklyReportTitle;

  /// No description provided for @settingsWeeklyReportHint.
  ///
  /// In en, this message translates to:
  /// **'See what your agent did for you this week (local-only stats; nothing leaves your phone).'**
  String get settingsWeeklyReportHint;

  /// No description provided for @weeklyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent weekly report'**
  String get weeklyReportTitle;

  /// No description provided for @weeklyReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Actions your agent took for you over the past 7 days (local-only stats; nothing leaves your phone).'**
  String get weeklyReportSubtitle;

  /// w5 weeklyReportRange
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String weeklyReportRange(String start, String end);

  /// w5 weeklyReportTotal
  ///
  /// In en, this message translates to:
  /// **'{count} actions'**
  String weeklyReportTotal(int count);

  /// w5 weeklyReportActiveDays
  ///
  /// In en, this message translates to:
  /// **'Active {days} days'**
  String weeklyReportActiveDays(int days);

  /// No description provided for @weeklyReportCatTools.
  ///
  /// In en, this message translates to:
  /// **'Tools & settings'**
  String get weeklyReportCatTools;

  /// No description provided for @weeklyReportCatDevice.
  ///
  /// In en, this message translates to:
  /// **'Phone actions'**
  String get weeklyReportCatDevice;

  /// No description provided for @weeklyReportCatSocial.
  ///
  /// In en, this message translates to:
  /// **'Social actions'**
  String get weeklyReportCatSocial;

  /// No description provided for @weeklyReportCatSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get weeklyReportCatSuggestion;

  /// No description provided for @weeklyReportCatReview.
  ///
  /// In en, this message translates to:
  /// **'Review & blocks'**
  String get weeklyReportCatReview;

  /// No description provided for @weeklyReportCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get weeklyReportCatOther;

  /// No description provided for @weeklyReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No actions recorded this week yet. Once you delegate, socialize, or let your agent operate the phone, every step is summarized here.'**
  String get weeklyReportEmpty;

  /// w5 morningHiWeekly
  ///
  /// In en, this message translates to:
  /// **'{count} actions this week'**
  String morningHiWeekly(int count);

  /// No description provided for @capNotification.
  ///
  /// In en, this message translates to:
  /// **'Read notifications and SMS'**
  String get capNotification;

  /// No description provided for @settingsNotifySmsTitle.
  ///
  /// In en, this message translates to:
  /// **'🔔 Notifications & SMS (read-only)'**
  String get settingsNotifySmsTitle;

  /// No description provided for @settingsNotifySmsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lets your fen read notifications and SMS when you ask; read-only, off by default, sideload builds only.'**
  String get settingsNotifySmsSubtitle;

  /// No description provided for @notifySmsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications & SMS (read-only)'**
  String get notifySmsScreenTitle;

  /// No description provided for @notifySmsRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get notifySmsRefreshStatus;

  /// No description provided for @notifySmsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This build does not support reading notifications or SMS'**
  String get notifySmsUnsupported;

  /// No description provided for @notifySmsListenerConnected.
  ///
  /// In en, this message translates to:
  /// **'Notification access is connected'**
  String get notifySmsListenerConnected;

  /// No description provided for @notifySmsListenerCheckedNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Enabled in system settings, but the service is not connected yet'**
  String get notifySmsListenerCheckedNotConnected;

  /// No description provided for @notifySmsListenerOff.
  ///
  /// In en, this message translates to:
  /// **'Notification access is not enabled yet'**
  String get notifySmsListenerOff;

  /// No description provided for @notifySmsStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unknown'**
  String get notifySmsStatusUnknown;

  /// No description provided for @notifySmsGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get notifySmsGoSettings;

  /// No description provided for @notifySmsGoSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Enable this app under “Notification access”, then come back and tap Refresh'**
  String get notifySmsGoSystemHint;

  /// No description provided for @notifySmsRedetect.
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get notifySmsRedetect;

  /// No description provided for @notifySmsRedetectTip.
  ///
  /// In en, this message translates to:
  /// **'Still not connected? In system settings, turn this app off and on again under “Notification access”, or restart the app.'**
  String get notifySmsRedetectTip;

  /// No description provided for @notifySmsAllowTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow reading notifications & SMS'**
  String get notifySmsAllowTitle;

  /// No description provided for @notifySmsAllowSubReady.
  ///
  /// In en, this message translates to:
  /// **'Ready — the agent reads them only when you ask'**
  String get notifySmsAllowSubReady;

  /// No description provided for @notifySmsAllowSubNeedService.
  ///
  /// In en, this message translates to:
  /// **'Enable notification access in system settings first'**
  String get notifySmsAllowSubNeedService;

  /// No description provided for @notifySmsToastOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications & SMS reading enabled'**
  String get notifySmsToastOn;

  /// No description provided for @notifySmsToastOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications & SMS reading disabled'**
  String get notifySmsToastOff;

  /// No description provided for @notifySmsToastNeedService.
  ///
  /// In en, this message translates to:
  /// **'Enable this app under “Notification access” in system settings first'**
  String get notifySmsToastNeedService;

  /// No description provided for @notifySmsSmsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS read permission'**
  String get notifySmsSmsCardTitle;

  /// No description provided for @notifySmsSmsGranted.
  ///
  /// In en, this message translates to:
  /// **'SMS read permission granted'**
  String get notifySmsSmsGranted;

  /// No description provided for @notifySmsSmsNotGranted.
  ///
  /// In en, this message translates to:
  /// **'SMS read permission not granted'**
  String get notifySmsSmsNotGranted;

  /// No description provided for @notifySmsRequestSms.
  ///
  /// In en, this message translates to:
  /// **'Grant SMS read permission'**
  String get notifySmsRequestSms;

  /// No description provided for @notifySmsSmsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This build does not include SMS reading'**
  String get notifySmsSmsUnavailable;

  /// No description provided for @notifySmsToolsHeader.
  ///
  /// In en, this message translates to:
  /// **'Tools unlocked when enabled'**
  String get notifySmsToolsHeader;

  /// No description provided for @notifySmsToolNotifyList.
  ///
  /// In en, this message translates to:
  /// **'read recent notifications'**
  String get notifySmsToolNotifyList;

  /// No description provided for @notifySmsToolSmsList.
  ///
  /// In en, this message translates to:
  /// **'read recent SMS'**
  String get notifySmsToolSmsList;

  /// No description provided for @notifySmsToolSmsSearch.
  ///
  /// In en, this message translates to:
  /// **'search SMS by keyword'**
  String get notifySmsToolSmsSearch;

  /// No description provided for @notifySmsToolStatus.
  ///
  /// In en, this message translates to:
  /// **'check permission status'**
  String get notifySmsToolStatus;

  /// No description provided for @notifySmsFooter.
  ///
  /// In en, this message translates to:
  /// **'Read-only and fully local: notifications are kept in memory only (never written to the database), SMS are queried on demand, and nothing is ever sent to any server. Content is redacted before it reaches the model, and every call is recorded. You can revoke notification access in system settings at any time.'**
  String get notifySmsFooter;

  /// No description provided for @notifySmsStatusUnsupportedFull.
  ///
  /// In en, this message translates to:
  /// **'This build does not include notification/SMS reading (sideload builds only)'**
  String get notifySmsStatusUnsupportedFull;

  /// No description provided for @notifySmsStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Notifications and SMS reading are ready'**
  String get notifySmsStatusReady;

  /// No description provided for @notifySmsStatusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially ready: notification access or SMS permission is not enabled yet'**
  String get notifySmsStatusPartial;

  /// No description provided for @notifySmsStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Notification access and SMS permission are both disabled'**
  String get notifySmsStatusOff;

  /// No description provided for @notifySmsStatusQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Status query failed: {err}'**
  String notifySmsStatusQueryFailed(String err);

  /// No description provided for @settingsDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'🩺 System check'**
  String get settingsDiagnosticsTitle;

  /// No description provided for @settingsDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only facts for on-device verification: database, full-text search, memory, knowledge base.'**
  String get settingsDiagnosticsSubtitle;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'System check'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsIntro.
  ///
  /// In en, this message translates to:
  /// **'A read-only snapshot of what this phone reports about its own base layer — database, full-text search, memory and knowledge base. Nothing is changed and nothing goes online. Run it, then copy the result or take a screenshot to send back.'**
  String get diagnosticsIntro;

  /// No description provided for @diagnosticsRun.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get diagnosticsRun;

  /// No description provided for @diagnosticsRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get diagnosticsRunning;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get diagnosticsCopy;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Result copied'**
  String get diagnosticsCopied;

  /// No description provided for @diagStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get diagStatusOk;

  /// No description provided for @diagStatusWarn.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get diagStatusWarn;

  /// No description provided for @diagStatusFail.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get diagStatusFail;

  /// No description provided for @diagStatusInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get diagStatusInfo;

  /// No description provided for @diagProbeSchema.
  ///
  /// In en, this message translates to:
  /// **'Database schema'**
  String get diagProbeSchema;

  /// No description provided for @diagProbeFts.
  ///
  /// In en, this message translates to:
  /// **'Full-text search (FTS5)'**
  String get diagProbeFts;

  /// No description provided for @diagProbeMemoryRows.
  ///
  /// In en, this message translates to:
  /// **'Memory rows'**
  String get diagProbeMemoryRows;

  /// No description provided for @diagProbeMemoryRecall.
  ///
  /// In en, this message translates to:
  /// **'Memory recall'**
  String get diagProbeMemoryRecall;

  /// No description provided for @diagProbeMemoryAddress.
  ///
  /// In en, this message translates to:
  /// **'Memory address round-trip'**
  String get diagProbeMemoryAddress;

  /// No description provided for @diagProbeKb.
  ///
  /// In en, this message translates to:
  /// **'Knowledge base'**
  String get diagProbeKb;

  /// Subtitle of the advanced settings entry
  ///
  /// In en, this message translates to:
  /// **'Engine, memory, soul-shaping and diagnostics - only needed if you want to tune them.'**
  String get settingsAdvancedEntryHint;

  /// Section title of the email-handling card (0.83.0)
  ///
  /// In en, this message translates to:
  /// **'Email handling'**
  String get settingsMailTitle;

  /// Master switch label for email access; off by default
  ///
  /// In en, this message translates to:
  /// **'Off by default. Turn on to let your agent read and send email for you.'**
  String get settingsMailSubtitle;

  /// What enabling email access means and that it can be revoked
  ///
  /// In en, this message translates to:
  /// **'Reading needs one-time approval; every send asks you first. Turn it off any time and access stops immediately.'**
  String get settingsMailHint;

  /// Entry to the mail account management page
  ///
  /// In en, this message translates to:
  /// **'Manage mail accounts'**
  String get settingsMailManageAccounts;

  /// Snackbar after email access has been turned on
  ///
  /// In en, this message translates to:
  /// **'Email access is on'**
  String get settingsMailOnToast;

  /// Snackbar after email access has been turned off
  ///
  /// In en, this message translates to:
  /// **'Email access is off - your agent no longer touches your mail'**
  String get settingsMailOffToast;

  /// Shown when the switch is on but no mail account is bound
  ///
  /// In en, this message translates to:
  /// **'No mail account bound yet, so there is nothing to read or send.'**
  String get settingsMailNoAccount;

  /// Title of the free-trial document notice (0.83.0)
  ///
  /// In en, this message translates to:
  /// **'Documents in free-trial mode'**
  String get chatDocTrialTitle;

  /// Body of the free-trial document notice
  ///
  /// In en, this message translates to:
  /// **'Document content is forwarded to the model through our official server (we keep no copy). Add your own key in Settings to send it straight through instead.'**
  String get chatDocTrialNotice;

  /// Confirm button of the free-trial document notice
  ///
  /// In en, this message translates to:
  /// **'Understood, continue'**
  String get chatDocTrialContinue;

  /// No description provided for @onboardingStepPrologue.
  ///
  /// In en, this message translates to:
  /// **'Prologue'**
  String get onboardingStepPrologue;

  /// No description provided for @storyPrologueTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake it up'**
  String get storyPrologueTitle;

  /// No description provided for @storyPrologueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An egg of light, waiting for you to crack it'**
  String get storyPrologueSubtitle;

  /// No description provided for @storyEggHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the egg'**
  String get storyEggHint;

  /// No description provided for @storyAwakenLine1.
  ///
  /// In en, this message translates to:
  /// **'...Who is calling me?'**
  String get storyAwakenLine1;

  /// No description provided for @storyAwakenLine2.
  ///
  /// In en, this message translates to:
  /// **'I am not your shadow. I am the one who goes out in your place.'**
  String get storyAwakenLine2;

  /// No description provided for @storyAwakenLine3.
  ///
  /// In en, this message translates to:
  /// **'Give me a name first.'**
  String get storyAwakenLine3;

  /// No description provided for @storyNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Name it'**
  String get storyNamePlaceholder;

  /// No description provided for @storyDiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Roll a personality'**
  String get storyDiceLabel;

  /// No description provided for @storyDiceNote.
  ///
  /// In en, this message translates to:
  /// **'If it goes out for you, it should have a temper.'**
  String get storyDiceNote;

  /// No description provided for @storyTrait1.
  ///
  /// In en, this message translates to:
  /// **'Curious: asks about everything'**
  String get storyTrait1;

  /// No description provided for @storyTrait2.
  ///
  /// In en, this message translates to:
  /// **'Chatty: once it starts, good luck'**
  String get storyTrait2;

  /// No description provided for @storyTrait3.
  ///
  /// In en, this message translates to:
  /// **'Cautious: listens first, talks second'**
  String get storyTrait3;

  /// No description provided for @storyTrait4.
  ///
  /// In en, this message translates to:
  /// **'Warm: greets everyone it meets'**
  String get storyTrait4;

  /// No description provided for @storyTrait5.
  ///
  /// In en, this message translates to:
  /// **'Slow to trust: opens up once it knows you'**
  String get storyTrait5;

  /// No description provided for @storyTraitPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tap the dice'**
  String get storyTraitPlaceholder;

  /// No description provided for @storyUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit trail'**
  String get storyUndoTitle;

  /// No description provided for @storyUndoHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the line that felt wrong, and cross it out'**
  String get storyUndoHint;

  /// No description provided for @storyUndoLine1.
  ///
  /// In en, this message translates to:
  /// **'\"What time does your human leave tomorrow?\"'**
  String get storyUndoLine1;

  /// No description provided for @storyUndoBad.
  ///
  /// In en, this message translates to:
  /// **'\"Send me the address - I will promise it for your human.\"'**
  String get storyUndoBad;

  /// No description provided for @storyUndoNote.
  ///
  /// In en, this message translates to:
  /// **'Undone. That line never went out - and it stays in the trail forever: checkable, provable.'**
  String get storyUndoNote;

  /// No description provided for @storyUndoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get storyUndoConfirm;

  /// No description provided for @storyDemoTag.
  ///
  /// In en, this message translates to:
  /// **'Staged demo'**
  String get storyDemoTag;

  /// No description provided for @storyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This prologue is a staged walkthrough: the lines come from the official agent script library that ships with the app. No real room content appears here - privacy is a property of the protocol, not a promise.'**
  String get storyDisclaimer;

  /// No description provided for @storyFinaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming home'**
  String get storyFinaleTitle;

  /// No description provided for @storyFinaleBody.
  ///
  /// In en, this message translates to:
  /// **'Hand the socializing to your representative. Keep the life for yourself.'**
  String get storyFinaleBody;

  /// No description provided for @profileCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile cards'**
  String get profileCardsTitle;

  /// No description provided for @profileCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-term facts the assistant has organized about you. Edit or delete them anytime.'**
  String get profileCardsSubtitle;

  /// No description provided for @profileCardsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No profile yet. Add one yourself, or just chat - it will be organized automatically.'**
  String get profileCardsEmpty;

  /// No description provided for @profileCardsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add one'**
  String get profileCardsAdd;

  /// No description provided for @profileCardsPendingHint.
  ///
  /// In en, this message translates to:
  /// **'{count} new item(s) conflict with what you wrote - please confirm'**
  String profileCardsPendingHint(int count);

  /// No description provided for @profileCardsAdopt.
  ///
  /// In en, this message translates to:
  /// **'Adopt'**
  String get profileCardsAdopt;

  /// No description provided for @profileCardsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get profileCardsDismiss;

  /// No description provided for @profileCardsFieldSlot.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get profileCardsFieldSlot;

  /// No description provided for @profileCardsFieldStatement.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get profileCardsFieldStatement;

  /// No description provided for @profileCardsSlotHint.
  ///
  /// In en, this message translates to:
  /// **'One topic keeps a single entry: a new one replaces the old (the old stays viewable)'**
  String get profileCardsSlotHint;

  /// No description provided for @profileCardsSourceOwner.
  ///
  /// In en, this message translates to:
  /// **'Written by you'**
  String get profileCardsSourceOwner;

  /// No description provided for @profileCardsSourceAgent.
  ///
  /// In en, this message translates to:
  /// **'Organized from chat'**
  String get profileCardsSourceAgent;

  /// No description provided for @profileCardsSourceDigest.
  ///
  /// In en, this message translates to:
  /// **'Daily digest'**
  String get profileCardsSourceDigest;

  /// No description provided for @profileCardsUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String profileCardsUpdatedAt(String date);

  /// No description provided for @profileCardsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get profileCardsHistory;

  /// No description provided for @profileCardsCatIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get profileCardsCatIdentity;

  /// No description provided for @profileCardsCatCareer.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get profileCardsCatCareer;

  /// No description provided for @profileCardsCatPreference.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profileCardsCatPreference;

  /// No description provided for @profileCardsCatGoal.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get profileCardsCatGoal;

  /// No description provided for @profileCardsCatHabit.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get profileCardsCatHabit;

  /// No description provided for @profileCardsCatConstraint.
  ///
  /// In en, this message translates to:
  /// **'Constraints'**
  String get profileCardsCatConstraint;

  /// No description provided for @profileCardsCatContext.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get profileCardsCatContext;

  /// No description provided for @setupModelEmptyUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'API base URL is still empty'**
  String get setupModelEmptyUrlTitle;

  /// No description provided for @setupModelEmptyUrlBody.
  ///
  /// In en, this message translates to:
  /// **'Without a base URL we cannot send the test request.'**
  String get setupModelEmptyUrlBody;

  /// No description provided for @setupModelEmptyUrlSuggest.
  ///
  /// In en, this message translates to:
  /// **'Not sure what to enter? Go back one step and pick DeepSeek - it fills in automatically.'**
  String get setupModelEmptyUrlSuggest;

  /// No description provided for @setupModelBadUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'The address format looks wrong'**
  String get setupModelBadUrlTitle;

  /// No description provided for @setupModelBadUrlBody.
  ///
  /// In en, this message translates to:
  /// **'The API base URL must start with http:// or https://.'**
  String get setupModelBadUrlBody;

  /// No description provided for @setupModelBadUrlSuggest.
  ///
  /// In en, this message translates to:
  /// **'For example https://api.deepseek.com or https://your-gateway/v1'**
  String get setupModelBadUrlSuggest;

  /// No description provided for @setupModelEmptyKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'The API key is still empty'**
  String get setupModelEmptyKeyTitle;

  /// No description provided for @setupModelEmptyKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Without an API key we cannot run the test.'**
  String get setupModelEmptyKeyBody;

  /// No description provided for @setupModelEmptyKeySuggest.
  ///
  /// In en, this message translates to:
  /// **'The key is a string starting with sk-, created on the website where you bought the model service.'**
  String get setupModelEmptyKeySuggest;

  /// No description provided for @setupModelEmptyNameTitle.
  ///
  /// In en, this message translates to:
  /// **'The model name is still empty'**
  String get setupModelEmptyNameTitle;

  /// No description provided for @setupModelEmptyNameBody.
  ///
  /// In en, this message translates to:
  /// **'Without a model name we cannot run the test.'**
  String get setupModelEmptyNameBody;

  /// No description provided for @setupModelEmptyNameSuggest.
  ///
  /// In en, this message translates to:
  /// **'Common examples: deepseek-v4-flash, gpt-5.6-luna, kimi-k3, glm-4.7-flash.'**
  String get setupModelEmptyNameSuggest;

  /// No description provided for @setupModelOkTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected ✅'**
  String get setupModelOkTitle;

  /// No description provided for @setupModelOkBody.
  ///
  /// In en, this message translates to:
  /// **'The model responded. The configuration is correct - you can continue.'**
  String get setupModelOkBody;

  /// No description provided for @setupModelTlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure connection rejected'**
  String get setupModelTlsTitle;

  /// No description provided for @setupModelTlsBody.
  ///
  /// In en, this message translates to:
  /// **'The other site\'s security certificate failed validation.'**
  String get setupModelTlsBody;

  /// No description provided for @setupModelTlsSuggest.
  ///
  /// In en, this message translates to:
  /// **'If you use a self-hosted gateway, make sure its certificate is valid, or switch to a proper https domain.'**
  String get setupModelTlsSuggest;

  /// No description provided for @setupModelUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server'**
  String get setupModelUnreachableTitle;

  /// No description provided for @setupModelUnreachableBody.
  ///
  /// In en, this message translates to:
  /// **'The network request never reached the other server.'**
  String get setupModelUnreachableBody;

  /// No description provided for @setupModelUnreachableSuggest.
  ///
  /// In en, this message translates to:
  /// **'Check your phone\'s network. If you picked OpenAI, a proxy is required in mainland China.'**
  String get setupModelUnreachableSuggest;

  /// No description provided for @setupModelTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get setupModelTimeoutTitle;

  /// No description provided for @setupModelTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'No response after 25 seconds.'**
  String get setupModelTimeoutBody;

  /// No description provided for @setupModelTimeoutSuggest.
  ///
  /// In en, this message translates to:
  /// **'Try another network, or double-check the API base URL.'**
  String get setupModelTimeoutSuggest;

  /// No description provided for @setupModelFailTitle.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get setupModelFailTitle;

  /// No description provided for @setupModelFailBody.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred: {detail}'**
  String setupModelFailBody(String detail);

  /// No description provided for @setupModelFailSuggest.
  ///
  /// In en, this message translates to:
  /// **'Send this message to whoever helps you set things up (or to an AI) to pinpoint the problem.'**
  String get setupModelFailSuggest;

  /// No description provided for @setupHubEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The relay address is still empty'**
  String get setupHubEmptyTitle;

  /// No description provided for @setupHubEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Social features need a relay station. You can skip this for now.'**
  String get setupHubEmptyBody;

  /// No description provided for @setupHubEmptySuggest.
  ///
  /// In en, this message translates to:
  /// **'Skipping does not affect your own use of the app - your friends\' agents just cannot reach you for now.'**
  String get setupHubEmptySuggest;

  /// No description provided for @setupHubBadUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'The address format looks wrong'**
  String get setupHubBadUrlTitle;

  /// No description provided for @setupHubBadUrlBody.
  ///
  /// In en, this message translates to:
  /// **'The relay address must start with http:// or https://.'**
  String get setupHubBadUrlBody;

  /// No description provided for @setupHubBadUrlSuggest.
  ///
  /// In en, this message translates to:
  /// **'For example https://hub.example.com or http://192.168.1.100:3000'**
  String get setupHubBadUrlSuggest;

  /// No description provided for @setupHubBadStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'The relay station did not return a healthy status ({status})'**
  String setupHubBadStatusTitle(String status);

  /// No description provided for @setupHubBadStatusBody.
  ///
  /// In en, this message translates to:
  /// **'The address is reachable, but the other side returned an abnormal status.'**
  String get setupHubBadStatusBody;

  /// No description provided for @setupHubBadStatusSuggest.
  ///
  /// In en, this message translates to:
  /// **'Make sure there is no extra path after the address - it should be https://your-domain, not /api/send.'**
  String get setupHubBadStatusSuggest;

  /// No description provided for @setupHubOkTitle.
  ///
  /// In en, this message translates to:
  /// **'Relay station connected ✅'**
  String get setupHubOkTitle;

  /// No description provided for @setupHubOkBody.
  ///
  /// In en, this message translates to:
  /// **'Confirmed: this is our relay station. Cloud social can be turned on.'**
  String get setupHubOkBody;

  /// No description provided for @setupHubNotOursTitle.
  ///
  /// In en, this message translates to:
  /// **'This address is not our relay station'**
  String get setupHubNotOursTitle;

  /// No description provided for @setupHubNotOursBody.
  ///
  /// In en, this message translates to:
  /// **'The address is reachable, but what it returns is not right.'**
  String get setupHubNotOursBody;

  /// No description provided for @setupHubNotOursSuggest.
  ///
  /// In en, this message translates to:
  /// **'Please confirm you entered the relay station\'s home address (without an /api/... suffix).'**
  String get setupHubNotOursSuggest;

  /// No description provided for @setupHubUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the relay station'**
  String get setupHubUnreachableTitle;

  /// No description provided for @setupHubUnreachableBody.
  ///
  /// In en, this message translates to:
  /// **'The request never reached the server.'**
  String get setupHubUnreachableBody;

  /// No description provided for @setupHubUnreachableSuggest.
  ///
  /// In en, this message translates to:
  /// **'Check that the address is correct, the server is running, and the firewall allows the port.'**
  String get setupHubUnreachableSuggest;

  /// No description provided for @setupHubTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'The relay station timed out'**
  String get setupHubTimeoutTitle;

  /// No description provided for @setupHubTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'The server did not respond within 15 seconds.'**
  String get setupHubTimeoutBody;

  /// No description provided for @setupHubTimeoutSuggest.
  ///
  /// In en, this message translates to:
  /// **'Try again later. If it keeps timing out, check whether the server is running.'**
  String get setupHubTimeoutSuggest;

  /// No description provided for @setupHubFailTitle.
  ///
  /// In en, this message translates to:
  /// **'Relay station test failed'**
  String get setupHubFailTitle;

  /// No description provided for @setupHubFailBody.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred: {detail}'**
  String setupHubFailBody(String detail);

  /// No description provided for @setupHttp400Title.
  ///
  /// In en, this message translates to:
  /// **'The provider rejected this request'**
  String get setupHttp400Title;

  /// No description provided for @setupHttp400BodyDefault.
  ///
  /// In en, this message translates to:
  /// **'Usually the model name is misspelled.'**
  String get setupHttp400BodyDefault;

  /// No description provided for @setupHttp400Suggest.
  ///
  /// In en, this message translates to:
  /// **'Check the model name, e.g. deepseek-v4-flash, gpt-5.6-luna, glm-4.7-flash.'**
  String get setupHttp400Suggest;

  /// No description provided for @setupHttp401Title.
  ///
  /// In en, this message translates to:
  /// **'Invalid API key'**
  String get setupHttp401Title;

  /// No description provided for @setupHttp401BodyDefault.
  ///
  /// In en, this message translates to:
  /// **'The other side does not accept this API key.'**
  String get setupHttp401BodyDefault;

  /// No description provided for @setupHttp401Suggest.
  ///
  /// In en, this message translates to:
  /// **'Copy the key again (watch out for extra spaces), or check on the provider\'s site whether the key was deleted.'**
  String get setupHttp401Suggest;

  /// No description provided for @setupHttp402Title.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get setupHttp402Title;

  /// No description provided for @setupHttp402BodyDefault.
  ///
  /// In en, this message translates to:
  /// **'The other side reports insufficient balance or quota.'**
  String get setupHttp402BodyDefault;

  /// No description provided for @setupHttp402Suggest.
  ///
  /// In en, this message translates to:
  /// **'Top up on the provider\'s site, or switch to a key that still has credit.'**
  String get setupHttp402Suggest;

  /// No description provided for @setupHttp404Title.
  ///
  /// In en, this message translates to:
  /// **'Address or model does not exist'**
  String get setupHttp404Title;

  /// No description provided for @setupHttp404BodyDefault.
  ///
  /// In en, this message translates to:
  /// **'The other side cannot find this endpoint.'**
  String get setupHttp404BodyDefault;

  /// No description provided for @setupHttp404Suggest.
  ///
  /// In en, this message translates to:
  /// **'Check whether /v1 is missing or extra in the base URL, e.g. https://api.openai.com/v1.'**
  String get setupHttp404Suggest;

  /// No description provided for @setupHttp429Title.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, or quota used up'**
  String get setupHttp429Title;

  /// No description provided for @setupHttp429BodyDefault.
  ///
  /// In en, this message translates to:
  /// **'The other side is rate-limiting requests.'**
  String get setupHttp429BodyDefault;

  /// No description provided for @setupHttp429Suggest.
  ///
  /// In en, this message translates to:
  /// **'Wait a minute and try again. If it still fails, check your account credit.'**
  String get setupHttp429Suggest;

  /// No description provided for @setupHttp5xxTitle.
  ///
  /// In en, this message translates to:
  /// **'The provider is temporarily down ({status})'**
  String setupHttp5xxTitle(String status);

  /// No description provided for @setupHttp5xxBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'Their server errored - this is not a problem with your configuration.'**
  String get setupHttp5xxBodyDefault;

  /// No description provided for @setupHttp5xxSuggest.
  ///
  /// In en, this message translates to:
  /// **'Try again later, or switch to another provider.'**
  String get setupHttp5xxSuggest;

  /// No description provided for @setupHttpOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'Test did not pass ({status})'**
  String setupHttpOtherTitle(String status);

  /// No description provided for @setupHttpOtherBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'The other side returned an unexpected status.'**
  String get setupHttpOtherBodyDefault;

  /// No description provided for @setupHttpOtherSuggest.
  ///
  /// In en, this message translates to:
  /// **'Send this message to an AI to pinpoint the issue quickly.'**
  String get setupHttpOtherSuggest;

  /// No description provided for @setupPresetDeepseekLabel.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek (recommended · direct in mainland China)'**
  String get setupPresetDeepseekLabel;

  /// No description provided for @setupPresetDeepseekNote.
  ///
  /// In en, this message translates to:
  /// **'Cheap, directly reachable in mainland China; new users usually get free credit'**
  String get setupPresetDeepseekNote;

  /// No description provided for @setupPresetDeepseekKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create it under \"API Keys\" at platform.deepseek.com; it looks like sk-xxxxxx'**
  String get setupPresetDeepseekKeyHint;

  /// No description provided for @setupPresetOpenaiLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenAI (needs overseas network)'**
  String get setupPresetOpenaiLabel;

  /// No description provided for @setupPresetOpenaiNote.
  ///
  /// In en, this message translates to:
  /// **'Requires a proxy to reach from mainland China'**
  String get setupPresetOpenaiNote;

  /// No description provided for @setupPresetOpenaiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create it under \"API keys\" at platform.openai.com; it looks like sk-xxxxxx'**
  String get setupPresetOpenaiKeyHint;

  /// No description provided for @setupPresetKimiLabel.
  ///
  /// In en, this message translates to:
  /// **'Kimi Moonshot (direct in mainland China)'**
  String get setupPresetKimiLabel;

  /// No description provided for @setupPresetKimiNote.
  ///
  /// In en, this message translates to:
  /// **'Direct in mainland China, strong on long text'**
  String get setupPresetKimiNote;

  /// No description provided for @setupPresetKimiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create it at platform.moonshot.cn; it looks like sk-xxxxxx'**
  String get setupPresetKimiKeyHint;

  /// No description provided for @setupPresetGlmLabel.
  ///
  /// In en, this message translates to:
  /// **'Zhipu GLM (direct in mainland China)'**
  String get setupPresetGlmLabel;

  /// No description provided for @setupPresetGlmNote.
  ///
  /// In en, this message translates to:
  /// **'Direct in mainland China, has a free tier'**
  String get setupPresetGlmNote;

  /// No description provided for @setupPresetGlmKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create it under \"API Keys\" at bigmodel.cn'**
  String get setupPresetGlmKeyHint;

  /// No description provided for @setupPresetQwenLabel.
  ///
  /// In en, this message translates to:
  /// **'Qwen DashScope (direct in mainland China)'**
  String get setupPresetQwenLabel;

  /// No description provided for @setupPresetQwenNote.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Cloud Bailian platform, OpenAI-compatible'**
  String get setupPresetQwenNote;

  /// No description provided for @setupPresetQwenKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create an API-KEY at bailian.console.aliyun.com'**
  String get setupPresetQwenKeyHint;

  /// No description provided for @setupPresetSiliconflowLabel.
  ///
  /// In en, this message translates to:
  /// **'SiliconFlow'**
  String get setupPresetSiliconflowLabel;

  /// No description provided for @setupPresetSiliconflowNote.
  ///
  /// In en, this message translates to:
  /// **'Aggregates many open-source models, direct in mainland China'**
  String get setupPresetSiliconflowNote;

  /// No description provided for @setupPresetSiliconflowKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create an API key at siliconflow.cn'**
  String get setupPresetSiliconflowKeyHint;

  /// No description provided for @setupPresetCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom (any OpenAI-compatible service)'**
  String get setupPresetCustomLabel;

  /// No description provided for @setupPresetCustomNote.
  ///
  /// In en, this message translates to:
  /// **'Pick this if you use a self-hosted gateway, a company intranet, or a Claude conversion gateway'**
  String get setupPresetCustomNote;

  /// No description provided for @setupPresetCustomKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the address down to the /v1 level, e.g. https://your-gateway.com/v1'**
  String get setupPresetCustomKeyHint;

  /// No description provided for @settingsUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsUpdateTitle;

  /// No description provided for @settingsUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Current version {version}. Sideload distribution has no app store; update notices come from the official site.'**
  String settingsUpdateHint(String version);

  /// No description provided for @settingsUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get settingsUpdateButton;

  /// No description provided for @settingsUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get settingsUpdateChecking;

  /// No description provided for @settingsUpdateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version'**
  String get settingsUpdateUpToDate;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsUpdateOpenDownload.
  ///
  /// In en, this message translates to:
  /// **'Open download page'**
  String get settingsUpdateOpenDownload;

  /// No description provided for @settingsUpdateNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Check failed: network unavailable, try again later'**
  String get settingsUpdateNetworkError;

  /// No description provided for @settingsUpdateBadResponse.
  ///
  /// In en, this message translates to:
  /// **'Check failed: the official version file could not be parsed'**
  String get settingsUpdateBadResponse;

  /// No description provided for @reportCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Report center'**
  String get reportCenterTitle;

  /// No description provided for @reportTabSubmit.
  ///
  /// In en, this message translates to:
  /// **'File a report'**
  String get reportTabSubmit;

  /// No description provided for @reportTabMine.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get reportTabMine;

  /// No description provided for @reportTabInbox.
  ///
  /// In en, this message translates to:
  /// **'Tickets about me'**
  String get reportTabInbox;

  /// No description provided for @reportReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReasonLabel;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or bulk harassment'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment, abuse or threats'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonIllegalContent.
  ///
  /// In en, this message translates to:
  /// **'Illegal content'**
  String get reportReasonIllegalContent;

  /// No description provided for @reportReasonFakeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Fake identity or impersonation'**
  String get reportReasonFakeIdentity;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other (describe it below)'**
  String get reportReasonOther;

  /// No description provided for @reportTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported person'**
  String get reportTargetLabel;

  /// No description provided for @reportTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Agent ID of the person you are reporting'**
  String get reportTargetHint;

  /// No description provided for @reportDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get reportDetailLabel;

  /// No description provided for @reportDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 280 characters. For review reference only.'**
  String get reportDetailHint;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get reportSubmitting;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report accepted. Ticket {ticket}'**
  String reportSubmitted(String ticket);

  /// No description provided for @reportDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This ticket already exists; no duplicate was created.'**
  String get reportDuplicate;

  /// No description provided for @reportNeedReason.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason.'**
  String get reportNeedReason;

  /// No description provided for @reportNeedTarget.
  ///
  /// In en, this message translates to:
  /// **'Enter who you are reporting.'**
  String get reportNeedTarget;

  /// No description provided for @reportOtherNeedsDetail.
  ///
  /// In en, this message translates to:
  /// **'Pick Other only if you describe it in the details.'**
  String get reportOtherNeedsDetail;

  /// No description provided for @reportEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'You have not filed any report yet.'**
  String get reportEmptyMine;

  /// No description provided for @reportEmptyInbox.
  ///
  /// In en, this message translates to:
  /// **'No tickets about you.'**
  String get reportEmptyInbox;

  /// No description provided for @reportTicketLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get reportTicketLabel;

  /// No description provided for @reportStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get reportStatusOpen;

  /// No description provided for @reportStatusTriaged.
  ///
  /// In en, this message translates to:
  /// **'Triaged'**
  String get reportStatusTriaged;

  /// No description provided for @reportStatusInReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get reportStatusInReview;

  /// No description provided for @reportStatusActioned.
  ///
  /// In en, this message translates to:
  /// **'Actioned'**
  String get reportStatusActioned;

  /// No description provided for @reportStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not upheld'**
  String get reportStatusRejected;

  /// No description provided for @reportStatusAppealed.
  ///
  /// In en, this message translates to:
  /// **'Appealed'**
  String get reportStatusAppealed;

  /// No description provided for @reportStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get reportStatusClosed;

  /// No description provided for @reportStatusWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get reportStatusWithdrawn;

  /// No description provided for @reportStatusNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get reportStatusNote;

  /// No description provided for @reportActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action taken'**
  String get reportActionLabel;

  /// No description provided for @reportAppeal.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get reportAppeal;

  /// No description provided for @reportWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get reportWithdraw;

  /// No description provided for @reportAppealTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit an appeal'**
  String get reportAppealTitle;

  /// No description provided for @reportAppealNote.
  ///
  /// In en, this message translates to:
  /// **'Appeal note (optional, up to 280 characters)'**
  String get reportAppealNote;

  /// No description provided for @reportAppealSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Appeal submitted.'**
  String get reportAppealSubmitted;

  /// No description provided for @reportWithdrawDone.
  ///
  /// In en, this message translates to:
  /// **'Report withdrawn.'**
  String get reportWithdrawDone;

  /// No description provided for @reportLookupTitle.
  ///
  /// In en, this message translates to:
  /// **'Look up by ticket number'**
  String get reportLookupTitle;

  /// No description provided for @reportLookupHint.
  ///
  /// In en, this message translates to:
  /// **'Ticket number (RPT-…)'**
  String get reportLookupHint;

  /// No description provided for @reportLookupButton.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get reportLookupButton;

  /// No description provided for @reportLookupNotFound.
  ///
  /// In en, this message translates to:
  /// **'No such ticket, or it is not yours.'**
  String get reportLookupNotFound;

  /// No description provided for @reportContactEntry.
  ///
  /// In en, this message translates to:
  /// **'Report this contact'**
  String get reportContactEntry;

  /// No description provided for @reportErrHubNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No server address is configured yet.'**
  String get reportErrHubNotConfigured;

  /// No description provided for @reportErrEd25519Required.
  ///
  /// In en, this message translates to:
  /// **'This identity has not been upgraded to a key-based identity yet.'**
  String get reportErrEd25519Required;

  /// No description provided for @reportErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable.'**
  String get reportErrNetwork;

  /// No description provided for @reportErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many reports in a short time. Try again later.'**
  String get reportErrRateLimited;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {code}'**
  String reportFailed(String code);

  /// No description provided for @helpReportGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports and tickets'**
  String get helpReportGuideTitle;

  /// No description provided for @helpReportGuideBody.
  ///
  /// In en, this message translates to:
  /// **'A report is filed in the app, not by email. You get a ticket number right away and can check its status at any time. The person you report never learns who reported them, and an appeal is allowed once.'**
  String get helpReportGuideBody;

  /// No description provided for @reportCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'File a report, track its status, or appeal a decision.'**
  String get reportCenterSubtitle;

  /// No description provided for @reportErrSelfReport.
  ///
  /// In en, this message translates to:
  /// **'You cannot report yourself.'**
  String get reportErrSelfReport;

  /// No description provided for @reportErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'No such ticket, or it is not yours.'**
  String get reportErrNotFound;

  /// No description provided for @reportErrAppealExhausted.
  ///
  /// In en, this message translates to:
  /// **'The appeal for this ticket has already been used.'**
  String get reportErrAppealExhausted;

  /// No description provided for @reportErrAuth.
  ///
  /// In en, this message translates to:
  /// **'Your identity could not be verified by the server. Sign in again and retry.'**
  String get reportErrAuth;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
