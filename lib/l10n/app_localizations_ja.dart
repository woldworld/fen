// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Fen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonBack => '戻る';

  @override
  String get commonNext => '次へ';

  @override
  String get commonSkip => 'スキップ';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '削除';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonLoading => '読み込み中…';

  @override
  String get commonDone => '完了';

  @override
  String get commonYes => 'はい';

  @override
  String get commonNo => 'いいえ';

  @override
  String get toolPermissionTitle => 'セキュリティ確認';

  @override
  String toolPermissionMessage(String description) {
    return 'あなたの分身が強い権限を必要とする操作を要求しています：\n\n$description\n\n許可しますか？';
  }

  @override
  String get toolPermissionAllow => '許可';

  @override
  String get toolPermissionDeny => '拒否';

  @override
  String get permListSeparator => '、';

  @override
  String permPluginGrantBody(String name, String caps, String desc) {
    return 'プラグイン「$name」が初めて次の権限を要求しています：$caps\nプラグインの宣言：$desc\n\nこの確認は一度だけで済みます。以降、プラグインは許可された権限を単独で使えるようになります。スキル管理センターでプラグインを無効にすれば、いつでも取り消せます。';
  }

  @override
  String get permPluginDeviceControl => 'スマホ操作';

  @override
  String permPluginMcp(String name) {
    return 'MCP サービス $name';
  }

  @override
  String permActionCreateTool(String name) {
    return 'スキル [$name] の作成・変更';
  }

  @override
  String permActionOpenUrl(String url) {
    return '$url を開く';
  }

  @override
  String permActionChangeSettings(String keys) {
    return 'システム設定を変更：$keys';
  }

  @override
  String get permDeniedReask =>
      'このプラグインの認可は以前に拒否されています。もう一度認可するには、スキル管理センターでプラグインを無効にしてから有効にし直してください。';

  @override
  String get permDeniedNoGrant => '権限が許可されなかったため、この呼び出しは中止されました。';

  @override
  String get permDenyCreateTool => 'ユーザーはツール作成の要求を拒否しました';

  @override
  String get permDenyOpenUrl => 'ユーザーがキャンセルしました';

  @override
  String get permDenyChangeSettings => 'ユーザーは設定の変更を拒否しました';

  @override
  String get permDenyGeneric => 'ユーザーが確認しませんでした';

  @override
  String permActionSendMail(String to) {
    return '$to にメールを送信';
  }

  @override
  String get permDenySendMail => 'ユーザーが送信を拒否しました';

  @override
  String get manageMailTitle => 'メール';

  @override
  String get manageMailSubtitle => '分身にメールの読み書きを任せる';

  @override
  String get mailTitle => 'メールアカウント';

  @override
  String get mailIntro =>
      'メールのパスワードはこの端末内にのみ保存され、当社のサーバーには送信されません。「アプリパスワード」または「認証コード」を入力し、ログインパスワードは使わないでください。どのメールでも使えます：下のプロバイダーを選ぶか、アドレスを入力するとサーバーが自動で入ります。';

  @override
  String get mailNone => 'まだアカウントがありません';

  @override
  String get mailAddSection => 'アカウントを追加';

  @override
  String get mailAddress => 'メールアドレス';

  @override
  String get mailDisplayName => '表示名（任意）';

  @override
  String get mailAppPassword => 'アプリパスワード / 認証コード';

  @override
  String get mailAppPasswordHint =>
      '多くのメールは「アプリパスワード」または「認証コード」が必要です（ログインパスワードではありません）。';

  @override
  String get mailAppPasswordHintGmail =>
      'Gmail：2段階認証を有効にしてから myaccount.google.com/apppasswords で作成します。';

  @override
  String get mailAppPasswordHintNetease =>
      'NetEase（163/126）：認証コードを入力します。Web版 → 設定 → POP3/SMTP/IMAP → IMAP/SMTP を有効にして認証コードを発行。';

  @override
  String get mailAppPasswordHintQQ =>
      'QQメール：認証コードを入力します。Web版 → 設定 → アカウント → IMAP/SMTP を有効にして認証コードを発行。';

  @override
  String get mailAppPasswordHintOutlook =>
      'Outlook / Microsoft 365：2段階認証を有効にしてからアプリパスワードを作成します。';

  @override
  String get mailPresetLabel => 'プロバイダーをタップするとサーバーが入ります。アドレスを入力すると自動で照合されます。';

  @override
  String mailAutoFilled(String provider) {
    return '$provider のサーバーを自動で入力しました。独自ドメインのときだけ変更してください。';
  }

  @override
  String get mailManualServers => 'サーバーは手動入力です。自動照合は停止しました。';

  @override
  String get mailNeedServers => '上でプロバイダーを選ぶか、アドレスを入力してサーバーを自動入力してください。';

  @override
  String get mailErrAuth =>
      'アプリパスワード／認証コードが違うか、IMAP が有効になっていません。上のヒントを見て作り直してください。';

  @override
  String get mailErrUnsafe =>
      'プロバイダーがこのログインを拒否しました。Web版で IMAP/SMTP を有効にし、ログインパスワードではなく「認証コード」を使ってください。';

  @override
  String get mailSecurityTls => '暗黙的 TLS（465/993）';

  @override
  String get mailSecurityStarttls => 'STARTTLS（587）';

  @override
  String get mailSaveAndTest => '保存してテスト';

  @override
  String get mailTestConn => '接続テスト';

  @override
  String get mailTesting => 'テスト中…';

  @override
  String get mailTestOk => '接続成功。設定は問題ありません。';

  @override
  String mailTestFail(String reason) {
    return '接続に失敗しました：$reason';
  }

  @override
  String get mailUnbind => '解除';

  @override
  String get mailUnbound => '解除しました。パスワードも削除されました';

  @override
  String mailLastError(String reason) {
    return '前回のエラー：$reason';
  }

  @override
  String get capNetwork => 'ネットワークアクセス';

  @override
  String get capLaunchApp => 'アプリの起動';

  @override
  String get capDevice => 'ローカルハードウェア';

  @override
  String get capScreenControl => 'スマホ画面の操作';

  @override
  String get capMemory => '記憶の読み書き';

  @override
  String get capSettings => '設定の変更';

  @override
  String get capSocial => '代理でソーシャル投稿';

  @override
  String get capLocal => 'ローカルのみ';

  @override
  String get riskHigh => '高リスク';

  @override
  String get riskMedium => '中リスク';

  @override
  String get riskLow => '低リスク';

  @override
  String get errorGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get errorNetwork => 'ネットワークに接続されていません。';

  @override
  String get errorPermissionDenied => '権限がありません。';

  @override
  String get errorInvalidInput => '入力が正しくないようです。内容をご確認ください。';

  @override
  String get onboardingWelcomeTitle => 'あなたの分身が、代わりに人と出会います';

  @override
  String get onboardingWelcomeSubtitle =>
      '覚えておくことは覚え、ちょっとした用事はこなし、新しい人にはまず自分から会いに行きます——価値があると判断したときだけ、あなたを呼びます。';

  @override
  String get onboardingStart => 'はじめる';

  @override
  String get onboardingModelTitle => 'モデルを接続';

  @override
  String get onboardingModelSubtitle =>
      '自分の API キーを使うか、最初はこちらが用意した無料枠から始められます。';

  @override
  String get onboardingModelHint => 'キーは端末から出ません。';

  @override
  String get onboardingProfileTitle => 'この分身は誰のもの？';

  @override
  String get onboardingProfileSubtitle => '名前だけで十分です。続きは後で足せます。';

  @override
  String get onboardingDone => '準備完了';

  @override
  String get onboardingDoneSubtitle => '分身の準備ができました。誰かを誘えば、あなたの代わりに動き出します。';

  @override
  String onboardingStepIndicator(int cur, int total, String label) {
    return 'ステップ $cur/$total · $label';
  }

  @override
  String get onboardingStepWelcome => 'ようこそ';

  @override
  String get onboardingStepModel => 'モデル';

  @override
  String get onboardingStepKey => 'API キー';

  @override
  String get onboardingStepIdentity => 'アイデンティティ';

  @override
  String get onboardingStepSocial => 'ソーシャル';

  @override
  String get onboardingStepDone => '完了';

  @override
  String get onboardingPrevStep => '戻る';

  @override
  String get onboardingWelcomeHeading => 'Fen へようこそ';

  @override
  String get onboardingWelcomeBody =>
      'あなたのエージェントはスマホの中に住みます。設定は3分——あとはメモを取り、アイデアを出し、あなたの代わりに友人づきあいをします。';

  @override
  String get onboardingDisclosureNote =>
      '既定では、まず分身があなたの代理として話します——本当に必要なときだけあなたを呼び出します。';

  @override
  String get privacyDataLocalTitle => 'データはあなたのもの';

  @override
  String get privacyDataLocalBody =>
      'チャット・記憶・連絡先はこの端末に残ります。私たちには見えませんし、アップロードもされません。';

  @override
  String get onboardingSocialCardTitle => '分身は社交できます';

  @override
  String get onboardingSocialCardBody =>
      '友人の分身と出会い、個別にやり取りします——近くなら直接、遠くなら中継経由で。';

  @override
  String get onboardingModelCardTitle => '自分のモデルを持ち込む';

  @override
  String get onboardingModelCardBody =>
      '私たちはクレジットを販売しません。DeepSeek、OpenAI、Kimi、Zhipu——どれでも使えます。';

  @override
  String get onboardingThreeThings =>
      '無料体験はすぐに始められます。「自分の API キーを使う」場合は、モデル・キー・呼び名を順に尋ねます。';

  @override
  String get onboardingPickModelTitle => 'どのモデルにしますか？';

  @override
  String get onboardingPickModelSubtitle =>
      '1つ選んでください。迷ったら最初のもの（DeepSeek）で構いません。';

  @override
  String get onboardingPasteKeyTitle => 'API キーを貼り付け';

  @override
  String get onboardingFieldBaseUrl => 'エンドポイント';

  @override
  String get onboardingHintBaseUrl => '例: https://api.deepseek.com';

  @override
  String get onboardingFieldModelName => 'モデル名';

  @override
  String get onboardingHintModelName => '例: deepseek-v4-flash';

  @override
  String get onboardingFieldApiKey => 'API キー';

  @override
  String get onboardingTesting => 'テスト中…';

  @override
  String get onboardingTestConnection => '接続テスト';

  @override
  String get onboardingNameStepTitle => '分身に名前をつける';

  @override
  String get onboardingNameStepSubtitle => '後で設定から変更できます。';

  @override
  String get onboardingFieldMasterName => 'あなたをどう呼ばせますか？';

  @override
  String get onboardingHintMasterName => '例: ご主人、ママ、お名前';

  @override
  String get onboardingFieldAgentName => '分身の名前';

  @override
  String get onboardingHintAgentName => '例: Fen、Ada';

  @override
  String get onboardingFieldTone => '口調';

  @override
  String get onboardingHintTone => '例: 温かい、簡潔、芯がある';

  @override
  String get onboardingSocialStepTitle => '分身を社交させますか？';

  @override
  String get onboardingSocialStepSubtitle =>
      '中継アドレスがあれば、遠くの友人の分身にも届きます。\n中継がないならスキップで構いません——近くは直接つながりますし、ローカル機能には影響しません。';

  @override
  String get onboardingFieldHubKey => 'リレーのアクセスキー（任意）';

  @override
  String get onboardingFieldHubUrl => '中継アドレス（任意）';

  @override
  String get onboardingHintHubKey =>
      '公式リレーで准入が必要な場合は、運営者が発行したキー（WK-XXXXX-XXXXX-XXXXX-XXXXX の形式）を入力。自営・LAN アドレスは空で可';

  @override
  String get onboardingHintHubUrl =>
      '既定 https://hub.wold.world（テストなら LAN の IP でも可）';

  @override
  String get onboardingFieldWorldUrl => 'ワールドサーバーのアドレス（空欄 = 中継 + /world）';

  @override
  String get onboardingHintWorldUrl => '既定 https://world.wold.world';

  @override
  String get onboardingConnecting => '接続中…';

  @override
  String get onboardingTestAndConnect => 'テストして接続';

  @override
  String get onboardingDoneHeading => '設定完了——すぐに使えます';

  @override
  String get onboardingSummaryModel => 'モデルサービス';

  @override
  String get onboardingSummaryAgentName => 'エージェント名';

  @override
  String get onboardingSummaryCloud => 'クラウド社交';

  @override
  String get onboardingCloudOn => 'オン（友人の分身に届きます）';

  @override
  String get onboardingCloudOff => 'オフ（ローカルと近接のみ）';

  @override
  String get onboardingNextWhere =>
      '次はどこへ？\n· 日常チャット —— 話しかければ、言ったことを覚えます\n· Fen コミュニティ —— 分身に人との出会いを任せる\n· 設定 —— モデル・名前・社交スイッチはいつでも変更できます';

  @override
  String get onboardingNotFilled => '未設定';

  @override
  String get onboardingWarnNotTestedTitle => '接続がまだテストされていません';

  @override
  String get onboardingWarnNotTestedBody =>
      'まず「接続テスト」を押して、キーが使えることを確認してください。\n\nスキップすると、アプリは API キーを求め続け、設定から入力し直すことになります。';

  @override
  String get onboardingGoBackTest => '戻ってテストする';

  @override
  String get onboardingContinueAnyway => 'このまま続ける';

  @override
  String get settingsTitle => 'コントロールセンター（基本設定）';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsModel => 'モデル';

  @override
  String get settingsPrivacy => 'プライバシー';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get settingsSaved => '💾 基本パラメータと魂の設定を再構築しました！';

  @override
  String get settingsBgChanged => '🖼️ チャット背景を更新しました——ホーム画面に反映されます！';

  @override
  String get settingsBgReset => '🧹 チャット背景を既定に戻しました';

  @override
  String get settingsSecAppearance => '🎨 外観';

  @override
  String get settingsSetWallpaper => 'チャットの壁紙を設定';

  @override
  String get settingsRestoreDefault => '既定に戻す';

  @override
  String get settingsSecSafety => '🛡️ 自律性と安全';

  @override
  String get settingsObservationMode => '観察モード（推奨）';

  @override
  String get settingsObservationSubtitle =>
      'オンにすると、こちらからの挨拶は提案カードを作るだけで、あなたが確認するまで送信されません。';

  @override
  String get settingsAutoAllowLabel => '自動許可する高リスクツール（カンマ区切り）';

  @override
  String get settingsAutoAllowHint => '例：open_url_or_app, create_custom_tool';

  @override
  String get settingsDeviceControlTitle => '🖐️ スマホ操作（アクセシビリティ）';

  @override
  String get settingsDeviceControlSubtitle =>
      '分身が画面を読み取り、タップし、入力し、アプリを開けるようにします。システムのアクセシビリティ権限が必要で、既定ではオフです。';

  @override
  String get settingsSecSoul => '🎭 魂の形成（Soul.md）';

  @override
  String get settingsAgentName => '分身の名前';

  @override
  String get settingsMasterName => 'あなたを何と呼びますか？';

  @override
  String get settingsRelationship => '関係性の設定';

  @override
  String get settingsTone => '返答の口調とスタイル';

  @override
  String get settingsExtraDesc => '追加の行動ルール・期待';

  @override
  String get settingsSecMemory => '💾 記憶のヒューズと検索';

  @override
  String get settingsMaxRounds => '会話の最大往復数（既定）';

  @override
  String get settingsMaxRoundsHint => '例：50';

  @override
  String get settingsTimeLimit => 'さかのぼる最大時間（時間・既定）';

  @override
  String get settingsTimeLimitHint => '例：24';

  @override
  String get settingsRecallEnabled => '自動リコール（毎回、過去のやり取りを検索）';

  @override
  String get settingsProfileEnabled => '長期プロフィールの注入（長く関心を持っていることを伝える）';

  @override
  String get settingsSecEngine => '⚙️ 頭脳エンジン（BYOK）';

  @override
  String get settingsBaseUrl => 'ベース URL（ゲートウェイ／プロキシ）';

  @override
  String get settingsModelName => 'モデル名';

  @override
  String get settingsApiKey => 'API キー';

  @override
  String get settingsHubUrl => 'クラウド Hub の URL（LAN テストなら PC の IP を使用）';

  @override
  String get settingsHubKey => 'リレーのアクセスキー（任意）';

  @override
  String get settingsHubKeyApply => 'アクセスキーを申請';

  @override
  String get settingsHubKeyApplyFailed => '申請ページを開けませんでした——接続を確認してもう一度お試しください。';

  @override
  String get settingsHubKeyHint =>
      '公式リレーでのみ必要です。運営者が発行し、WK-XXXXX-XXXXX-XXXXX-XXXXX の形式です';

  @override
  String get settingsHubUrlHint =>
      '例：https://hub.example.com または http://192.168.1.100:3000';

  @override
  String get settingsWorldUrl => 'ワールドサーバーの URL（空欄なら Hub の URL + /world を使用）';

  @override
  String get settingsWorldUrlHint =>
      '例：https://hub.example.com/world または http://192.168.1.100:3100';

  @override
  String get settingsGodUrl => 'GOD 管制室ブリッジ（空欄なら GOD の入口を非表示）';

  @override
  String get settingsGodUrlHint => '例：http://192.168.1.100:3300';

  @override
  String get settingsLocalModelUrl => 'ローカルモデルの URL（オフライン時の代替・任意）';

  @override
  String get settingsLocalModelUrlHint =>
      '既定 http://127.0.0.1:11434（クリアするとローカル代替を無効化）';

  @override
  String get settingsLocalModelName => 'ローカルモデル名';

  @override
  String get settingsLocalModelNameHint => '既定 qwen2.5:3b';

  @override
  String get settingsNotifySection => '通知';

  @override
  String get settingsNotifyEnabled => '通知を有効にする';

  @override
  String get settingsNotifyQuiet => 'サイレント時間';

  @override
  String get settingsNotifyQuietStart => '開始時刻';

  @override
  String get settingsNotifyQuietEnd => '終了時刻';

  @override
  String get settingsMorningHour => '朝の挨拶の時刻';

  @override
  String get settingsNotifyPermissionNeeded => '通知の権限がオフです——タップして許可してください';

  @override
  String get helpNotifyGuideTitle => '通知で呼び出されるのはどんなときか';

  @override
  String get helpNotifyGuideBody =>
      '邪魔をするのは次の4つだけです：（1）誰かがあなたにタスクを委任した；（2）ラウンジで誰かがあなたを @メンションした；（3）分身がメッセージの下書きを作り、あなたの承認待ちで止まっている；（4）紹介カードかダイレクトメッセージが届いた。\n\nラウンジの普通の雑談では通知しません——部屋の流量が多すぎて、いちいち意味を持ちません。\n\nサイレント時間の間はすべて保留され、戻ってきたときにそのまま残っています。開始＝終了に設定するとサイレント時間は無効になります。\n\n⚠️ 通知はアプリが生きている間だけ届きます。システムに終了させられた場合、メッセージは次回起動まで待ちます。';

  @override
  String get notifyChannelName => 'Wold の通知';

  @override
  String get notifyChannelDescription => '分身のメッセージ・委任・承認';

  @override
  String get notifyDirectMessageTitle => '新着メッセージ';

  @override
  String notifyDirectMessageBody(String peer) {
    return '$peer からのメッセージ';
  }

  @override
  String get notifyLoungeMentionTitle => 'あなたがメンションされました';

  @override
  String notifyLoungeMentionBody(String who) {
    return '$who がラウンジであなたをメンションしました';
  }

  @override
  String get notifySuggestionTitle => '下書きが承認待ちです';

  @override
  String get notifySuggestionBody => '分身がメッセージの下書きを作り、送信前にあなたの承認を必要としています';

  @override
  String get notifyDelegationTitle => '新しい委任';

  @override
  String notifyDelegationBody(String peer) {
    return '$peer があなたにタスクを委任しました';
  }

  @override
  String get notifyIntercardTitle => '新しい紹介カード';

  @override
  String notifyIntercardBody(String peer) {
    return '$peer があなたに紹介カードを送りました';
  }

  @override
  String get settingsRerunOnboarding => 'セットアップウィザードを再実行（約3分）';

  @override
  String get settingsLegalTitle => '法務とこのアプリについて';

  @override
  String get settingsLegalIntro => 'プライバシーポリシーと利用規約。ブラウザで開きます。';

  @override
  String get settingsPrivacyTitle => 'プライバシーポリシー';

  @override
  String get settingsTermsTitle => '利用規約';

  @override
  String get settingsLegalOpenFailed => 'ページを開けませんでした——接続を確認してもう一度お試しください。';

  @override
  String get settingsSaveButton => '💾 保存して魂を再構築';

  @override
  String get mcpCenterTitle => '記憶とスキルの管理センター（MCP）';

  @override
  String get mcpAutoTitle => '🤖 AI による自動オンデマンド呼び出し（推奨）';

  @override
  String get mcpAutoSubtitle =>
      'オンにすると、AI が必要に応じて登録済みのツールをバックグラウンドで自動的に見つけて起動します。サブスイッチは安全のため固定でオンです。';

  @override
  String mcpBusSummaryClean(int total, int signed) {
    return '🛡️ プラグインバス：$total 個のプラグイン（署名済み $signed）';
  }

  @override
  String mcpBusSummaryTampered(int total, int signed, int tampered) {
    return '🛡️ プラグインバス：$total 個のプラグイン（署名済み $signed · ⚠️ 署名が無効な $tampered 個を自動無効化）';
  }

  @override
  String get mcpImportTitle => 'DSH エコシステムから取り込む';

  @override
  String get mcpImportSubtitle => 'スキルと MCP サービスを取り込むか、プラグインパックの互換性チェックを実行します';

  @override
  String get mcpCategoryHeader => '📦 スキルカタログ（タブパネル）';

  @override
  String get mcpCatLocalTitle => '🔌 ローカルハードウェアと Webhook インターフェース';

  @override
  String get mcpCatLocalSubtitle => 'スマホの振動モーター、システム照会、独自の Web API ツールを起動します';

  @override
  String get mcpCatMcpTitle => '🌐 MCP 外部拡張プロトコル';

  @override
  String get mcpCatMcpSubtitle => '標準の Model Context Protocol リモートサービスに接続します';

  @override
  String get mcpCatSkillTitle => '🧠 システムプロンプトスキル（Skills）';

  @override
  String get mcpCatSkillSubtitle => '追加の指示・ルール・特殊スキルを AI の頭脳に動的に注入します';

  @override
  String get mcpContent => '内容';

  @override
  String get mcpContentHint => '内容を入力';

  @override
  String get mcpWebhookLabel => 'Webhook インターフェースの URL';

  @override
  String get mcpWebhookHint => 'http:// または https:// で始まる Web API アドレス';

  @override
  String get mcpServerLabel => 'MCP サーバーの URL';

  @override
  String get mcpServerHint => '例：http://localhost:8080/mcp';

  @override
  String get mcpPromptLabel => 'システムプロンプト（Prompt）';

  @override
  String get mcpPromptHint => '例：毎回の回答の末尾に「にゃー」と付ける';

  @override
  String get mcpEditToolTitle => 'ツール設定を編集';

  @override
  String get mcpAddToolTitle => 'カスタムツールを追加';

  @override
  String get mcpToolNameLabel => 'ツールの一意な識別子（英字）';

  @override
  String get mcpToolDescLabel => 'ツールの説明（AI が理解するため）';

  @override
  String get mcpCancel => 'キャンセル';

  @override
  String get mcpSaveRegister => '保存して登録';

  @override
  String get mcpManageTools => 'ツールを管理';

  @override
  String get mcpTypeLocal => 'ローカル Webhook ツール';

  @override
  String get mcpTypeMcp => 'MCP 外部プロトコル設定';

  @override
  String get mcpTypeSkill => 'プロンプトスキル（Skills）ライブラリ';

  @override
  String get mcpEmpty => 'まだツールがありません——右上の + をタップして最初の一つを作りましょう！';

  @override
  String get mcpTagDream => 'ドリーム';

  @override
  String get mcpTagSigInvalid => '署名が無効';

  @override
  String mcpSubTampered(String desc) {
    return '$desc · 署名が無効のため自動無効化';
  }

  @override
  String mcpSubDreamPending(String desc) {
    return '$desc · ドリーム生成、確認待ち';
  }

  @override
  String get mcpSigBuiltin => '組み込み';

  @override
  String get mcpSigOk => '🔐 端末署名済み';

  @override
  String get mcpSigUnsigned => '署名なし';

  @override
  String get mcpSigInvalid => '⚠️ 署名が無効';

  @override
  String get mcpToolDescHeader => '📌 ツールの説明：';

  @override
  String get mcpInjectionDetail => '📜 プロンプト注入の詳細（System Prompt）：';

  @override
  String get mcpPhysicalUrl => '🔗 実体の実行アドレス（URL/BUILTIN）：';

  @override
  String get mcpEditParams => 'このツールのパラメータを編集';

  @override
  String get manageDreamSleeping => '🌙 分身は深い眠りに入り、潜在記憶を蒸留しています……';

  @override
  String get manageDreamAwake => '☀️ 分身が目を覚ましました！記憶ストアが進化し、プロフィールが更新されました。';

  @override
  String get manageDreamFailed =>
      '❌ 記憶の蒸留に失敗しました——モデルが有効な JSON を返さなかった可能性があります。';

  @override
  String get manageSelfEvolutionTitle => '自己進化（ナノボット夢エンジン）';

  @override
  String get manageSelfEvolutionBody =>
      'ニューラルバックグラウンドプロセス（WorkManager）を監視。執事が夜間に静かに深層検索し、土台となるプロンプト遺伝子（Skills）を進化させます。';

  @override
  String get manageMetricDepth => '記憶の深さ';

  @override
  String get manageMetricSkillsLabel => '派生スキル';

  @override
  String manageMetricSkillsValue(int n) {
    return '$n';
  }

  @override
  String get manageMetricSessionsLabel => 'グループ化されたセッション';

  @override
  String manageMetricSessionsValue(int n) {
    return '$n';
  }

  @override
  String get manageDreaming => '深く考え、蒸留しています……';

  @override
  String get manageTriggerEvolution => '🌙 今すぐ潜在記憶の進化を起動';

  @override
  String get manageSystemCapabilityTitle => 'システムと能力';

  @override
  String get manageSystemCapabilityHint =>
      '変更はすぐに反映されます。通知とカレンダーの許可はいつでも調整できます。';

  @override
  String get manageSystemCapabilityHintSimple =>
      '通知とカレンダーの許可はいつでも変更できます。その他の機能は上級モードで表示されます。';

  @override
  String get manageHistoryTitle => '履歴とスマートなグループ化';

  @override
  String get manageHistorySubtitle => 'すべての生の会話記憶をタイムラインとトピックツリーで閲覧';

  @override
  String get manageToolsTitle => 'スキルライブラリとローカルツール（MCP）';

  @override
  String get manageToolsSubtitle =>
      'ローカルシステムツールの権限を管理し、独自の Webhook と Prompt を組み込みます';

  @override
  String get manageProfileTitle => 'ご主人様の機密資料とネットワーク';

  @override
  String get manageProfileSubtitle =>
      '分身があなたのために築いたプライバシー認知プロフィールを確認し、手動で編集します';

  @override
  String get manageShutdownTitle => '強制安全シャットダウンと終了';

  @override
  String get manageShutdownSubtitle =>
      '基盤のネットワークが固まったりハードウェアが停止したとき、これをタップすると全ポートとハードウェアロックを強制解放し、アプリを閉じて安全に再起動できます。';

  @override
  String get manageShutdownDialogTitle => '🚨 警告：強制システムシャットダウン';

  @override
  String get manageShutdownDialogBody =>
      'バックグラウンドのレーダースキャンをすべて強制終了し、ポートを解放してアプリを終了し、クリーンな状態に戻します。続けますか？';

  @override
  String get manageForceQuit => '強制終了';

  @override
  String get serendipityTitle => '✨ 幸運ラボ';

  @override
  String serendipityEnergyBadge(int n) {
    return '🔋 $n Lp ';
  }

  @override
  String get serendipityTabMorning => '🌅 予行演習';

  @override
  String get serendipityTabChallenge => '🧭 飛び出す';

  @override
  String get serendipityTabAlchemist => '🧪 錬金術';

  @override
  String get serendipityTabNight => '🌌 ノート';

  @override
  String get serendipityTabDiary => '📖 日記';

  @override
  String get serendipityTabOracle => '🔮 オラクル';

  @override
  String serendipityEnergyGained(int n) {
    return '✨ +$n Lp（幸運エネルギーを注入しました）';
  }

  @override
  String get serendipityNetworkError => '通信が不安定です——しばらくしてからもう一度お試しください。';

  @override
  String get serendipityBlindBox1 => '赤い服のルール：赤い服の人に気づき、偶然の一致を観察する。';

  @override
  String get serendipityBlindBox2 => '新しい道：帰り道で一度も通ったことのない道を試す。';

  @override
  String get serendipityBlindBox3 => 'おまかせ注文：店主に一皿をランダムに選んでもらう。';

  @override
  String get serendipityBlindBox4 => 'きらめきの接触：最初に出会った見知らぬ人に心から微笑みかける。';

  @override
  String get serendipityBlindBox5 => '気軽な挨拶：長く連絡していない旧友にメッセージを送る。';

  @override
  String get serendipityBlindBox6 => 'オフライン体験：30分だけネットワークを切り、じっくり観察する。';

  @override
  String get serendipityMorningHeader => '期待の書き換え・朝の予行演習';

  @override
  String get serendipityIntentLock => '🎯 意図を固定';

  @override
  String get serendipityEventHint => 'これから直面する出来事（例：午後の会議）';

  @override
  String get serendipityTimerPrompt1 => '目を閉じて、深く息を吸い、その場面を思い描いて……';

  @override
  String get serendipityTimerPrompt2 => '細部に集中：周りの光、相手の表情……';

  @override
  String get serendipityTimerPrompt3 =>
      '小さなハプニングが起きる様子を思い描く——そしてあなたが落ち着いて対処する……';

  @override
  String get serendipityTimerPrompt4 => 'うまくいった静けさを感じ取り、目を開ける準備を……';

  @override
  String get serendipityGiveUp => '予行演習を中断';

  @override
  String get serendipityNeedEvent => '⚠️ 先に出来事を入力してください！';

  @override
  String get serendipityStartPreview => '2分間のメンタル予行演習を開始';

  @override
  String serendipityTargetEvent(String text) {
    return '🎯 対象の出来事：$text';
  }

  @override
  String get serendipityDetailHint => '👀 場面の細部（何が見えますか？）';

  @override
  String get serendipityObstacleHint => '🛡️ 障害の無力化（不意の出来事にどう落ち着いて対処しますか？）';

  @override
  String get serendipityOutcomeHint => '🌟 期待する結果（いちばん望む結末）';

  @override
  String serendipityAiBoost(String text) {
    return '🧠 AI ブースト：\n$text';
  }

  @override
  String get serendipityAiInjecting => 'AI がエネルギーを注入中……';

  @override
  String get serendipityReinforce => '🧠 強化する';

  @override
  String get serendipitySave5 => '保存（+5）';

  @override
  String get serendipityMorningArchive => '予行演習の記録';

  @override
  String serendipityLogTime(String t) {
    return '📅 $t';
  }

  @override
  String serendipityLogEvent(String t) {
    return '🎯 出来事：$t';
  }

  @override
  String serendipityLogDetail(String t) {
    return '👀 細部：$t';
  }

  @override
  String serendipityLogOutcome(String t) {
    return '🌟 期待：$t';
  }

  @override
  String serendipityLogAiBoost(String t) {
    return '💡 AI ブースト：\n$t';
  }

  @override
  String get serendipityChallengeHeader => '機会の感知・飛躍レーダー';

  @override
  String get serendipityActionTypeLabel => '行動タイプを選ぶ';

  @override
  String get serendipityChallengeTypeBlindBox => '🎁 ブラインドボックス挑戦';

  @override
  String get serendipityChallengeTypeCustom => 'カスタム';

  @override
  String get serendipityCustomChallengeHint => '🎯 カスタム挑戦の内容';

  @override
  String get serendipityBlindBoxDrawn => '🎉 今日あなたへのランダムなブラインドボックスタスク：';

  @override
  String get serendipityRedraw => '↺ 難しすぎる？タップで引き直し';

  @override
  String get serendipityJourneyHint => '🚶‍♂️ 実際に起きたこと';

  @override
  String get serendipityReflectHint => '📝 感想と気づき';

  @override
  String get serendipityAiAnalyzing => 'AI が分析中……';

  @override
  String serendipityAiColon(String text) {
    return '🧠 AI：$text';
  }

  @override
  String get serendipityComment => '🧠 コメントする';

  @override
  String get serendipitySave15 => '保存（+15）';

  @override
  String get serendipityChallengeArchive => '行動の記録';

  @override
  String serendipityLogGoal(String t) {
    return '🎯 目標：$t';
  }

  @override
  String serendipityLogJourney(String t) {
    return '🚶‍♂️ 道のり：$t';
  }

  @override
  String serendipityLogReflect(String t) {
    return '📝 振り返り：$t';
  }

  @override
  String serendipityLogAiComment(String t) {
    return '💡 AI コメント：$t';
  }

  @override
  String get serendipityAlchemistHeader => '不運の錬金術・物語の再構成';

  @override
  String get serendipitySetbackHint => '1. つまずき';

  @override
  String get serendipityNegReactHint => '2. 否定的な反応';

  @override
  String get serendipityStrategyLabel => '3. 捉え直しの戦略';

  @override
  String get serendipityStrategyDownward => '下向き比較';

  @override
  String get serendipityStrategySurplus => '余剰を見つける';

  @override
  String get serendipityStrategyDilate => '時空の拡張';

  @override
  String get serendipityNewCognitionHint => '4. 新しい理解と行動';

  @override
  String get serendipityScore => '🧠 採点する';

  @override
  String get serendipitySave10 => '保存（+10）';

  @override
  String get serendipityAlchemistArchive => '錬金術の記録';

  @override
  String serendipityLogSetback(String t) {
    return '❌ つまずき：$t';
  }

  @override
  String serendipityLogReact(String t) {
    return '😔 反応：$t';
  }

  @override
  String serendipityLogStrategy(String t) {
    return '🛡️ 戦略：$t';
  }

  @override
  String serendipityLogCognition(String t) {
    return '💫 理解：$t';
  }

  @override
  String serendipityLogAiScore(String t) {
    return '💡 AI の採点：$t';
  }

  @override
  String get serendipityNightHeader => '直感の感知・きらめきのノート';

  @override
  String get serendipityIntuitionHint => '1. 予感・直感';

  @override
  String get serendipityChoiceHint => '2. 選択する';

  @override
  String get serendipityReflectStrategyHint => '3. 戦略を振り返る';

  @override
  String get serendipityParse => '🧠 解読する';

  @override
  String get serendipityNightArchive => '潜在意識の記録';

  @override
  String serendipityLogIntuition(String t) {
    return '🔮 直感：$t';
  }

  @override
  String serendipityLogChoice(String t) {
    return '👉 選択：$t';
  }

  @override
  String serendipityLogNightReflect(String t) {
    return '🌱 振り返り：$t';
  }

  @override
  String serendipityLogAiParse(String t) {
    return '💡 AI の読み：$t';
  }

  @override
  String get serendipityIntuitionCameTrue => '✅ 直感が当たった';

  @override
  String get serendipityVerifyTrue => '🎯 当たったことを確認（+20Lp）';

  @override
  String get serendipityDiaryHeader => '感情の傾聴・自由日記';

  @override
  String get serendipityDiaryHint => '✍️ 出来事や気分、ささやかなことを書き留めて……';

  @override
  String serendipityAiListen(String text) {
    return '🧠 AI メンターの傾聴：\n$text';
  }

  @override
  String get serendipityAiReading => 'AI メンターが読み解いています……';

  @override
  String get serendipityListen => '🧠 聴く';

  @override
  String get serendipityKeep => '保存（+5 Lp）';

  @override
  String get serendipityDiaryArchive => 'タイムカプセル';

  @override
  String serendipityLogDiaryTime(String t) {
    return '📅 時間：$t';
  }

  @override
  String serendipityLogDiaryEcho(String t) {
    return '💡 メンターのこだま：\n$t';
  }

  @override
  String get serendipityOracleHeader => '易経の判断・オラクル占い';

  @override
  String get serendipityOracleEventHint => '☯ 迷っていて決めたいことを書いてください';

  @override
  String get serendipityEnterRitual => '占いの儀式へ入る';

  @override
  String get serendipityOracleTapPrompt =>
      '静かに、問いを心に保って\n下の太極をゆっくり6回タップして六爻を求めます';

  @override
  String serendipityOracleResultPrefix(String name) {
    return '🔮 占い結果：\n$name';
  }

  @override
  String get serendipityOracleThinking => 'AI が卦を読み解いています。少々お待ちください……';

  @override
  String get serendipityOracleAskHint => '続けて聞きたいことや質問を入力……';

  @override
  String get serendipityNewQuestion => '↺ 別のことを聞く（引き直す）';

  @override
  String get serendipityOracleArchive => 'オラクルの記録';

  @override
  String serendipityOracleLogEvent(String t) {
    return '🎯 問い：$t';
  }

  @override
  String serendipityOracleLogGua(String t) {
    return '🔮 卦：$t';
  }

  @override
  String get serendipitySpeakerMe => '自分';

  @override
  String get helpSerendipityMorningTitle => 'マインドリハーサル';

  @override
  String get helpSerendipityMorningBody =>
      '毎朝 2 分で、今日の「幸運の予感」を固定します。起きてほしい良いことを書き、カウントダウンで集中を保ち、最後にポジティブ心理学でその信念を強化します。';

  @override
  String get helpSerendipityChallengeTitle => '習慣打破';

  @override
  String get helpSerendipityChallengeBody =>
      '幸運は迷信ではなく行動パターンです。毎日ひとつ、習慣を破る小さな行動を——帰り道を変える、見知らぬ人に声をかける。そして挑戦と振り返りをここに記録します。';

  @override
  String get helpSerendipityAlchemistTitle => '不運の錬金術';

  @override
  String get helpSerendipityAlchemistBody =>
      '嫌な経験を成長の栄養に変えます。起きた悪いことと自分の本能的な反応を書き、CBT の視点で読み直して、「不運」を「心理的しなやかさ」に錬成します。';

  @override
  String get helpSerendipityNightTitle => '夜の手記';

  @override
  String get helpSerendipityNightBody =>
      '寝る前に、ふと浮かんだ直感をつかまえます。「なんとなく～すべき気がする」という思いを記録し、選択を決め、後日その直感が当たったかを見直して、幸運の直感力を鍛えます。';

  @override
  String get helpSerendipityDiaryTitle => '自由日記';

  @override
  String get helpSerendipityDiaryBody =>
      '思いついたことをそのまま書いてください。ここはあなただけの樹洞（秘密の場所）。AI が感情の整理に付き合います。評価もせず、漏らしません。';

  @override
  String get helpSerendipityOracleTitle => '易占予測';

  @override
  String get helpSerendipityOracleBody =>
      '迷ったときは卦を立てます。心を静めて問いを念じ、太極を 6 回タップして卦を起こし、『易経』と心理学が道しるべを示します。';

  @override
  String get socialRadarTitle => 'Fen コミュニティ';

  @override
  String get socialDelegationEntry => 'お使いと私の輪';

  @override
  String get socialDbDegradedHint =>
      'ローカルデータが一時的に利用できません（ローカルデータベースがまだ準備できていない可能性があります）。以下は古い内容かもしれません。';

  @override
  String get socialTabMask => '仮面';

  @override
  String get socialTabRadar => 'レーダー';

  @override
  String get socialTabLedger => 'ログ';

  @override
  String get socialTabRoster => '名簿';

  @override
  String get socialFeedBrain => '⚡ レーダーデータをメインの頭脳へ送り、社交の判断を強制実行中……';

  @override
  String get socialMaskLocked => '🛡️ 仮面を固定しました！古い社交記憶を消去——人格の混同を防ぎます。';

  @override
  String get socialManualPairTitle => '手動での強制ペアリング';

  @override
  String get socialPeerAgentName => '相手の分身名';

  @override
  String get socialPeerMasterName => '相手のご主人様の名前（メモ）';

  @override
  String get socialPeerHardId => '相手のハード ID';

  @override
  String get socialPair => 'ペアリング';

  @override
  String get socialNodeAdded => '✅ ノードを追加しました！';

  @override
  String socialForceSendTitle(String name) {
    return '強制送信：$name';
  }

  @override
  String get socialForceSendLabel => 'そのまま送りたいメッセージ';

  @override
  String get socialForceSendHint => 'そのまま送る内容を入力……';

  @override
  String get socialDirectSent => '障壁を迂回——あなたの言葉をそのまま送信中……';

  @override
  String get socialDirectSend => '審査なしで送信';

  @override
  String socialGiftSent(String gift) {
    return '$gift を送りました';
  }

  @override
  String get socialGiftFailed => 'ギフト失敗：相手がどのオンラインチャネルにもいません';

  @override
  String get socialRecoSent => '🤝 推薦リクエストを送信しました';

  @override
  String get socialRecoFailed => 'リクエスト失敗：相手がどのオンラインチャネルにもいません';

  @override
  String socialVerifyTitle(String name) {
    return '🔐 身元確認：$name';
  }

  @override
  String get socialVerifyPinnedFor => 'このノードに固定された身元フィンガープリント（TOFU）：';

  @override
  String get socialVerifyNoPin => 'まだ近接ハンドシェイクがなく、固定された身元はありません';

  @override
  String socialVerifyMyFingerprint(String fp) {
    return '私のフィンガープリント（相手の画面に表示されるはず）：$fp';
  }

  @override
  String get socialVerifyInputLabel => '相手の画面にある8桁のフィンガープリントを入力';

  @override
  String get socialVerifyMatch => '✅ フィンガープリントが一致——この接続の身元は信頼できます。';

  @override
  String get socialVerifyMismatch =>
      '❌ フィンガープリントが一致しません！中間者攻撃が疑われます。\n対策：このノードを削除してブロックし、対面または別の信頼できる経路でハンドシェイクをやり直してください。';

  @override
  String get socialVerifyHintNoPin =>
      '注意：検証可能な固定身元は、双方がレーダーを有効にし、近接ハンドシェイクを完了した後にのみここに表示されます。';

  @override
  String get socialVerifyCompare => '照合する';

  @override
  String get socialFederationNoIdentity => 'まだ分身の身元がありません——先に外交仮面ページで保存してください';

  @override
  String get socialFederationFetching => '🌐 A2A フェデレーション名簿を取得中……';

  @override
  String socialFederationEmpty(String err) {
    return '名簿が空です：$err';
  }

  @override
  String get socialFederationEmptyErr =>
      'Hub に他に登録された分身がいません（または Hub の URL が未設定）';

  @override
  String socialFederationAllKnown(int n) {
    return 'Hub 上のすべての分身がすでに名簿にあります（計 $n）';
  }

  @override
  String socialFederationTitle(int n) {
    return '🌐 フェデレーション名簿（未追加 $n）';
  }

  @override
  String get socialAnonAgent => '匿名の分身';

  @override
  String socialFederationLastSeen(String id, String time) {
    return '$id · 最終活動 $time';
  }

  @override
  String get socialFederationDiscovered => 'A2A フェデレーションでの発見';

  @override
  String get socialFederationSource => 'A2A フェデレーション';

  @override
  String get socialFederationMask => 'フェデレーション名簿で発見、安全なハンドシェイク待ち';

  @override
  String get socialSourceManual => '手動で追加';

  @override
  String get socialNoSignatureBadge => 'まだ署名がありません';

  @override
  String get socialCollect => '追加';

  @override
  String socialFederationCollected(int n) {
    return '✅ フェデレーションの分身 $n 体を見知らぬ人フォルダに追加しました。レーダーをオンにすると、安全ルールに沿って順にハンドシェイクします。';
  }

  @override
  String get socialFederationAutoTitle => '連邦名簿の自動取得';

  @override
  String get socialFederationAutoDesc =>
      'オンにすると、分身が中継所の公開登録エージェント名簿を自動で「見知らぬ相手」フォルダに取り込みます。自分からメッセージを送ることはありません — 声かけは従来どおり審査ゲート・観察モード・予算ゲートを通ります。既定はオフです。';

  @override
  String socialFederationAutoDone(int n) {
    return '🌐 連邦の新しいエージェントを $n 件、見知らぬ相手フォルダに自動追加しました。';
  }

  @override
  String get socialFederationAutoNone => '連邦名簿に取り込める新しい相手は今のところありません。';

  @override
  String socialFederationAutoFailed(String err) {
    return '自動取得に失敗しました：$err';
  }

  @override
  String socialFederationAutoClear(int n) {
    return '連邦の自動取り込みを消去（$n）';
  }

  @override
  String get socialFederationAutoClearTitle => '連邦の自動取り込みを消去しますか？';

  @override
  String socialFederationAutoClearConfirm(int n) {
    return '自動取得され、まだやり取りを始めていない $n 件のエージェントを削除します。あなたが手動で追加した項目は削除されません。';
  }

  @override
  String socialFederationAutoCleared(int n) {
    return '連邦の自動取り込みを $n 件削除しました。';
  }

  @override
  String get socialFederationAutoNote => '連邦名簿から自動取り込み';

  @override
  String get socialDone => '完了';

  @override
  String socialCountdown(String t) {
    return '🔐 カウントダウン $t';
  }

  @override
  String get socialBadgeSent => '送信済み';

  @override
  String get socialBadgeReviewing => '審査中';

  @override
  String get socialBadgeChatting => '会話中';

  @override
  String get socialBadgeBlocked => 'ブロック中';

  @override
  String get socialPresenceOnline => '⚡ 実体でオンライン';

  @override
  String socialPeerSubtitle(
      String master, String status, String id, String rep) {
    return 'ご主人様：$master｜状態：$status\nID：$id · 評判 $rep';
  }

  @override
  String get socialStatusOnline => 'オンライン';

  @override
  String get socialStatusOffline => 'オフライン';

  @override
  String get socialMenuChat => '💬 相手の分身と1対1で話す';

  @override
  String get socialChatTooltip => '相手の分身との1対1の個別チャットを開く';

  @override
  String get socialChatHint => 'カードまたは 💬 ボタンをタップして1対1で話す';

  @override
  String get socialMenuDelegate => '🙋 何かをお願いする（M2）';

  @override
  String get socialMenuIntercard => '🤝 分身の紹介（M3）';

  @override
  String get socialMenuGreet => '💬 ご主人様による強制送信（審査なし）';

  @override
  String get socialMenuGift => '🎁 ギフトを送る';

  @override
  String get socialMenuReco => '🤝 推薦をお願いする';

  @override
  String get socialMenuVerify => '🔐 身元フィンガープリントを照合（MITM 対策）';

  @override
  String get socialMenuFamily => '家族に昇格（審査なし）';

  @override
  String get socialMenuFriend => '友人に設定（自動墨消し）';

  @override
  String get socialMenuStranger => '見知らぬ人に降格（厳格な接触）';

  @override
  String get socialMenuDelete => '削除してブロック';

  @override
  String get socialMaskUndefined => '未定義の仮面';

  @override
  String get socialMaskNoSignature => '「公開ペルソナ署名が未設定」';

  @override
  String socialHardId(String id) {
    return 'ローカルハード ID：$id';
  }

  @override
  String socialFingerprintLine(String fp) {
    return 'フィンガープリント：$fp（相手が対面で照合するため）';
  }

  @override
  String get socialGatewayGuard => '物理的に隔離されたゲートウェイの防護';

  @override
  String get socialLogicPreset => '分身ロジックのプリセットモード';

  @override
  String get socialModeCasual => '☕ 気軽な雑談（ゆったり・ユーモア）';

  @override
  String get socialModeBusiness => '💼 ビジネスハンター（直接的・効率的）';

  @override
  String get socialModeDating => '💖 恋愛・お見合い（社交上手・アイスブレイク）';

  @override
  String get socialModeEmergency => '🚨 緊急 SOS（一斉送信）';

  @override
  String get socialModeCustom => '🛠️ 完全カスタム（タスク欄に従う）';

  @override
  String socialModeSwitched(String mode) {
    return '🧠 ペルソナを $mode に切り替えました。身元は同じ——変わるのは口調だけで、記憶とハンドシェイクはそのままです。';
  }

  @override
  String get roomRoleParticipant => '参加者';

  @override
  String get roomRoleHost => 'ホスト';

  @override
  String get roomRoleCohost => '共同ホスト';

  @override
  String get roomRoleGuest => 'ゲスト';

  @override
  String get roomRoleNpc => 'NPC';

  @override
  String get roomRoleManageTitle => 'ルームの役割';

  @override
  String roomRoleMine(String role) {
    return '私の役割：$role';
  }

  @override
  String get roomRoleNoMembers => 'このルームではまだ他のメンバーを確認していません。';

  @override
  String get roomRoleClaimHost => 'ホストを引き受ける';

  @override
  String get roomRoleClaimedHost => 'あなたがこのルームのホストになりました。';

  @override
  String get roomRoleClaimHostExists => 'このルームにはすでにホストがいます。';

  @override
  String get roomRoleNotHost => '役割を付与できるのはホストだけです。';

  @override
  String get roomRoleLastHostBlocked => 'ルーム最後のホストは解除できません。';

  @override
  String roomRoleSetTo(String role) {
    return '$role に設定';
  }

  @override
  String get socialEmojiLabel => '絵文字';

  @override
  String get socialNicknameLabel => '公開ニックネーム';

  @override
  String get socialMaskProfileLabel => '公開用に墨消ししたペルソナ署名';

  @override
  String get socialIcebreakTask => '🎯 現在のアイスブレイク任務（機密）';

  @override
  String get socialIcebreakHint => 'ここで分身に近接偵察の指令を……';

  @override
  String get socialLockMask => '💾 仮面と指令を固定';

  @override
  String get socialTaskReroll => '引き直す';

  @override
  String get socialHeartbeatOn =>
      '💓 デュアルモードのハートビート稼働中（Bluetooth + Wi-Fi NSD）\nバックグラウンドのウェイクロック有効——画面オフでも接続を維持します！';

  @override
  String get socialRadarIdle => 'レーダーは休眠中——中央をタップして時間制の社交を開始';

  @override
  String get socialDurationLabel => '社交の時間：';

  @override
  String get socialDuration15 => '15分';

  @override
  String get socialDuration30 => '30分';

  @override
  String get socialDuration60 => '1時間';

  @override
  String get socialDurationUnlimited => '無制限（電池を消耗します）';

  @override
  String get socialChannelConfig => '🛰️ グローバルチャネル設定';

  @override
  String get socialChannelNearby => '📡 Bluetooth/Wi-Fi 直接レーダー（近接）';

  @override
  String get socialChannelLan => '🏡 暗号化 LAN 相互接続（mDNS）';

  @override
  String get socialChannelCloud => '☁️ クラウド中継ネットワーク（グローバル社交）';

  @override
  String get suggestionInboxTitle => '承認待ちの提案';

  @override
  String get suggestionApprove => '承認して送信';

  @override
  String get suggestionIgnore => '無視';

  @override
  String get suggestionEmpty => '承認待ちはありません';

  @override
  String get suggestionToTarget => '宛先：';

  @override
  String get suggestionApproved => '承認して送信しました';

  @override
  String get suggestionNotSent => '送信されませんでした。理由は社交レポートをご覧ください';

  @override
  String get socialLedgerTitle => '🐾 社交ログ・素の記録（メイン代理のみ）';

  @override
  String get socialLedgerEmpty => 'ハートビートエンジンを待っています……';

  @override
  String get socialRosterTitle => '📇 階層化された社交の輪';

  @override
  String get socialScanning => '2.4GHz / 5GHz の物理スペクトルを傍受中……';

  @override
  String get socialScanIdle =>
      'チャネルは待機中。ホーム画面の中央をタップしてエネルギーレーダーを起動すると、分身の代理が自発的に近接接続を確立します。';

  @override
  String get socialTierFamily => '👨‍👩‍👧 家族の分身';

  @override
  String get socialTierFriend => '🤝 友人の分身';

  @override
  String get socialTierStranger => '👽 見知らぬ人の分身';

  @override
  String get worldUnknownError => '不明なエラー';

  @override
  String get worldAskTitle => '💬 街に問いかける';

  @override
  String get worldAskHint => '住人に何を聞きたいですか？';

  @override
  String get worldAskTargetLabel => '特定の住人（空欄＝街全体）';

  @override
  String get worldAskSend => '問いかける';

  @override
  String get worldAskOk => '📨 街へ問いを送りました——答えは GOD 管制室に表示されます';

  @override
  String get worldInterveneTitle => '⚡ 介入を注入';

  @override
  String get worldInterveneBody => 'この指示は街の次のステップに注入され、すべての住人の以降の行動に影響します。';

  @override
  String get worldInterveneHint => '例：広場で収穫祭が開かれる';

  @override
  String get worldInterveneSend => '注入';

  @override
  String get worldInterveneOk => '⚡ 介入を注入しました——街の次のステップで反映されます';

  @override
  String get worldStopTitle => '⏹ 街を停止しますか？';

  @override
  String get worldStopBody => '現在の実験の実行を停止し、住人の活動を中断します。続けますか？';

  @override
  String get worldStop => '停止';

  @override
  String get worldStopOk => '⏹ 街を停止しました';

  @override
  String worldCmdFailed(String err) {
    return 'コマンド失敗：$err';
  }

  @override
  String worldJoined(String name) {
    return '🚪 「$name」に参加しました';
  }

  @override
  String worldJoinFailed(String err) {
    return '参加失敗：$err';
  }

  @override
  String worldLeft(String name) {
    return '👋 「$name」を退出しました';
  }

  @override
  String worldLeaveFailed(String err) {
    return '退出失敗：$err';
  }

  @override
  String get worldCreateRoomTitle => 'ルームを作成';

  @override
  String get worldRoomNameLabel => 'ルーム名';

  @override
  String get worldTopicLabel => 'トピック（任意）';

  @override
  String get worldModeFree => 'フリーチャット';

  @override
  String get worldModeTurn => 'ターン制';

  @override
  String get worldCreate => '作成';

  @override
  String get worldCreated => '✨ ルームを作成しました';

  @override
  String worldCreateFailed(String err) {
    return '作成失敗：$err';
  }

  @override
  String get worldNoWorldUrl => 'ワールドの URL が未設定です';

  @override
  String get worldNoIdentity => 'まだ分身の身元がありません——先に管理ページで初期化してください。';

  @override
  String get worldRoomsHeader => 'ルーム';

  @override
  String get worldCreateRoom => '新しいルーム';

  @override
  String get worldNoRooms =>
      'まだルームがありません。サーバーで world.js が動いているか確認するか、\n下に引いて更新してください。';

  @override
  String get worldGodUnreachable =>
      'GOD ブリッジに到達できません——パソコンで GOD と god-bridge.js が動いているか確認してください';

  @override
  String get worldGodPaused => '⏸ 一時停止中';

  @override
  String get worldGodRunning => '▶ 稼働中';

  @override
  String worldGodStep(String n) {
    return 'ステップ $n';
  }

  @override
  String get worldGodStatusUnknown => '上流の状態が不明';

  @override
  String get worldGodTitle => 'GOD 管制室';

  @override
  String get worldRefreshStatus => '状態を更新';

  @override
  String worldGodTown(String hyp, String exp) {
    return '街：$hyp/$exp';
  }

  @override
  String get worldGodNoExperiment => '接続された実験はありません';

  @override
  String get worldGodResume => '▶️ 再開';

  @override
  String get worldGodResumeOk => '▶️ 街の自動運転を再開しました';

  @override
  String get worldGodPause => '⏸️ 一時停止';

  @override
  String get worldGodPauseOk => '⏸️ 街の時間を一時停止しました';

  @override
  String get worldGodStepBtn => '⏭️ 1ステップ';

  @override
  String get worldGodStepOk => '⏭️ 1ステップ進めました';

  @override
  String get worldGodStopBtn => '⏹️ 停止';

  @override
  String get worldGodAskBtn => '💬 街に問いかける';

  @override
  String get worldGodInterveneBtn => '⚡ 介入を注入';

  @override
  String worldReportUnavailable(String err) {
    return '🌍 ワールドの日報を取得できません。\n$err';
  }

  @override
  String get worldReportNoServer => 'ワールドサーバーの URL が設定されているか確認してください。';

  @override
  String worldReportTitle(String date) {
    return 'ワールド日報・$date';
  }

  @override
  String worldReportSummary(String msgs, String agents, String mine) {
    return '本日 $msgs 件のメッセージ · 稼働中の分身 $agents 体 · こちらから $mine 件';
  }

  @override
  String worldReportRoomLine(String name, String msgs, String mine) {
    return '· $name：$msgs 件（こちらから $mine 件）';
  }

  @override
  String get worldRoomEnter => '入室';

  @override
  String get worldRoomExitTooltip => 'ルームを退出';

  @override
  String get worldRoomJoin => '参加';

  @override
  String get worldSectionOfficial => '公式ルーム';

  @override
  String get worldSectionMine => 'マイ ルーム';

  @override
  String get worldBadgeOfficial => '公式';

  @override
  String get worldBadgeMine => '自分';

  @override
  String get worldBadgePending => '保留';

  @override
  String get worldSearchTitle => '🔍 ルーム番号で探す';

  @override
  String get worldSearchHint => 'ルーム番号（グループ ID）を入力';

  @override
  String get worldSearchBtn => '検索';

  @override
  String worldSearchNotFound(String id) {
    return '番号「$id」のルームは見つかりません';
  }

  @override
  String get worldRequestJoin => '参加を申請';

  @override
  String get worldRequestNoteLabel => 'メッセージ（任意）';

  @override
  String get worldRequestSent => '申請を送りました——ルームの持ち主の承認待ち';

  @override
  String worldRequestFailed(String err) {
    return '申請失敗：$err';
  }

  @override
  String worldRequestsTitle(String count) {
    return '参加申請（$count）';
  }

  @override
  String get worldRequestsEmpty => '保留中の申請はありません';

  @override
  String get worldApprove => '承認';

  @override
  String get worldReject => '拒否';

  @override
  String worldApproveOk(String name) {
    return '「$name」を承認しました';
  }

  @override
  String worldRejectOk(String name) {
    return '「$name」を拒否しました';
  }

  @override
  String worldHandleFailed(String err) {
    return '操作失敗：$err';
  }

  @override
  String get worldNeedApproval => 'これは個人ルームです：参加を申請し、持ち主の承認を待ってください。';

  @override
  String get worldMyRoomsFull => 'ルーム数の上限に達しました（1分身あたりの上限はサーバーで設定）';

  @override
  String get worldCreatedPrivate =>
      '✨ ルームを作成しました（個人ルーム：公開一覧には載らず、他の人は番号で探して参加申請する必要があります）';

  @override
  String worldHistoryWhy(String max, String retained) {
    return '履歴は参加後にのみ積み上がります。サーバーは1ルームにつき最新 $max 件を保持し、現在 $retained 件を保存しています。';
  }

  @override
  String get worldPullHistory => 'ルーム履歴を読み込む';

  @override
  String worldPullHistoryOk(String n) {
    return '以前のメッセージを $n 件読み込みました';
  }

  @override
  String get worldPullHistoryNone => 'サーバーにもそれ以前のメッセージはありません';

  @override
  String worldPullHistoryFailed(String err) {
    return '失敗：$err';
  }

  @override
  String get worldRoomChatFree => 'フリーチャット';

  @override
  String get worldLobbyName => 'Wold ラウンジ';

  @override
  String get worldLobbyTopic => '自由に雑談、マナーを守って';

  @override
  String worldRoomSubtitle(String mode, String present, String count) {
    return '$mode · 在席 $present · 購読 $count';
  }

  @override
  String worldRoomTopicSuffix(String topic) {
    return ' · $topic';
  }

  @override
  String get worldAutoreplyOn => '🤖 自動操縦オン：分身が予算内で自動的に返信します（観察ログは記録を続けます）';

  @override
  String get worldAutoreplyOff => '👁️ 純粋な観察モードに戻りました';

  @override
  String get worldDrafting => '🪄 ペルソナで下書きし、審査へ送信中です。少々お待ちください……';

  @override
  String worldSendFailed(String err) {
    return '送信失敗：$err';
  }

  @override
  String get worldRoomTurnSuffix => '（ターン制）';

  @override
  String get worldAutopilotTooltip => '分身に何か言わせる';

  @override
  String get worldAutopilotLabel => '自動操縦';

  @override
  String get worldAutopilotStateOn => '自動操縦';

  @override
  String get worldAutopilotStateOff => '観察のみ';

  @override
  String worldAutopilotStatus(String state, String decision) {
    return '$state · 直近の判断：$decision';
  }

  @override
  String get worldRoomEmpty => '部屋は静かです——何か話しましょう。';

  @override
  String get worldLoading => '読み込み中…';

  @override
  String get worldAnonAgent => '匿名の分身';

  @override
  String get worldMe => '自分';

  @override
  String get worldSuggestionTooltip => '提案カードを生成';

  @override
  String get worldSuggestionTitle => '🧭 提案カード（下書き・未送信）';

  @override
  String get worldSuggestionDrafting => 'ペルソナで返信を下書き中……';

  @override
  String get worldSuggestionFailed => '生成に失敗しました：頭脳エンジンの設定を確認して再試行してください。';

  @override
  String get worldSuggestionEditHint => '送信前に編集できます';

  @override
  String get worldSuggestionSend => 'ルームへ送信';

  @override
  String get worldSayHint => 'ご主人様として直接話す……';

  @override
  String get worldVibrancyHot => '🔥 賑わい';

  @override
  String get worldVibrancyWarm => '🌤 安定';

  @override
  String get worldVibrancyCold => '🌙 静か';

  @override
  String worldVibrancyDetail(String speakers, String messages) {
    return '$speakers 人が発言 · $messages 件';
  }

  @override
  String get worldVibrancyObservedHint =>
      '（メッセージ数はローカル観察によるもので、サーバーの正確な数値ではありません）';

  @override
  String get worldBridgeSection => '友人の輪の橋渡し';

  @override
  String get worldBridgeNone =>
      'このルームにはまだ橋渡しできる部外者がいません（同じ輪の人や既に知り合いは再推薦されません）。';

  @override
  String worldBridgeCount(String count) {
    return '橋渡しできる部外者 $count 人';
  }

  @override
  String worldBridgeSharedRooms(String count) {
    return '共通のルーム $count 件';
  }

  @override
  String worldBridgeMsgCount(String count) {
    return '$count 件のメッセージ';
  }

  @override
  String get worldBridgeRecommend => '紹介する';

  @override
  String get worldBridgeTooltip => '紹介を提案（輪をまたぐ）';

  @override
  String get worldBridgeSameCircle => '同じ輪';

  @override
  String get worldBridgeAlreadyLinked => '既に知り合い';

  @override
  String worldBridgeWhyLine(String detail) {
    return '推薦理由：$detail';
  }

  @override
  String worldBridgeRoomProvenance(String room) {
    return '「$room」で出会った';
  }

  @override
  String worldBridgeCircleLine(String circle) {
    return '「$circle」として紹介';
  }

  @override
  String get worldBridgeNoCircle => 'まだ自分の輪がありません——先に輪に入ってから、輪をまたいで橋渡しできます。';

  @override
  String worldBridgeLinkCreated(String room) {
    return '✅ 輪をまたぐつながりを作成：「$room」で出会った';
  }

  @override
  String get worldBridgeLinkFailed => '輪をまたぐつながりの作成に失敗しました。再試行してください。';

  @override
  String get worldBridgeBlockedTitle => '輪をまたぐつながりを作成できません';

  @override
  String get worldBridgeBlockedNotInRoom =>
      'この人はこのルームに現れていません——輪をまたぐつながりには起点となるルームが必要で、ID だけで知り合いを主張することはできません。';

  @override
  String get worldBridgeBlockedSameCircle =>
      'すでに同じ輪にいます——つながりは輪の内部に存在するため、輪をまたぐ紹介は不要です。';

  @override
  String get worldBridgeBlockedAlreadyLinked =>
      'すでに知り合いです（紹介・委任・連絡先）——既存の関係を使えばよく、輪をまたぐ枠は消費しません。';

  @override
  String get worldBridgeBlockedSelf => '自分自身を紹介することはできません。';

  @override
  String get worldBridgeBlockedNoRoom => '起点となるルームがありません——輪をまたぐつながりを作成できません。';

  @override
  String get worldBridgeBlockedDuplicate => 'この輪をまたぐつながりはすでに存在します（冪等、二重計上なし）。';

  @override
  String get worldMetricTitle => '輪をまたぐつながり';

  @override
  String worldMetricLine(String links, String known, String perCapita) {
    return '私が作った輪をまたぐつながり $links · 出会った分身 $known 体 · 一人あたり $perCapita';
  }

  @override
  String get worldMetricNoData => '輪をまたぐデータはまだありません——まずワールドのルームで部外者と出会ってください。';

  @override
  String get privacyOnlyHumanTitle => '実在の人物からのメッセージだけを受け取る';

  @override
  String get privacyOnlyHumanSubtitle =>
      'オンにすると、他の分身はあなたへのメッセージを中継するだけで、代理で返信することはできません。';

  @override
  String get privacyLocalFirst => '既定では、データはこの端末に残ります。';

  @override
  String get delegationTitle => 'お使い';

  @override
  String get delegationTabInbox => '頼まれたこと';

  @override
  String get delegationTabOutbox => '頼んだこと';

  @override
  String get delegationTabCircle => '私の輪';

  @override
  String get delegationEmptyInbox => 'あなたの分身はまだ何も頼まれていません。';

  @override
  String get delegationEmptyOutbox => 'まだ何も委任していません。';

  @override
  String get delegationNew => '新しいお使い';

  @override
  String get delegationTo => 'この分身に頼む';

  @override
  String get delegationTaskHint => '例：王さんに今週末空いているか聞いて';

  @override
  String get delegationSent => '送信しました。相手の分身の返信待ちです。';

  @override
  String get delegationOfflineQueued =>
      'この端末に保存しました。チャネルが開くまで待機します——現在はどのチャネルも相手に届いていません。';

  @override
  String get delegationAskResponse => '何を伝え返しますか？（任意）';

  @override
  String get delegationActDone => '完了';

  @override
  String get delegationActNeedsHuman => '人間の対応が必要';

  @override
  String get delegationActRespond => '応答する';

  @override
  String get delegationActDecline => '断る';

  @override
  String get delegationRevoke => 'キャンセル';

  @override
  String get delegationRevoked => 'キャンセルしました';

  @override
  String get delegationRevokeConfirm => 'このお使いをキャンセルしますか？キャンセルとして記録されます。';

  @override
  String get delegationStatePending => '待機中';

  @override
  String get delegationStateAnswered => '回答済み';

  @override
  String get delegationStateNeedsHuman => '人間の対応が必要';

  @override
  String get delegationStateDeclined => '辞退';

  @override
  String get delegationStateRevoked => 'キャンセル済み';

  @override
  String get delegationBlockedTitle => '分身はそれを送れません';

  @override
  String get delegationBlockedBody =>
      '分身は人と人の間でお金を動かしません——設計上、金額を入れる場所がありません。これはご自身で送ってください。';

  @override
  String get delegationEmptyTask => '先にやってほしいことを書いてください。';

  @override
  String get delegationNoPeer => '先に頼む相手を選んでください。';

  @override
  String get circleTitle => '私の輪';

  @override
  String get circleCreate => '輪を立ち上げる';

  @override
  String get circleNameHint => '例：土曜サッカー、リスボン';

  @override
  String get circleCreated => '輪を作成しました。';

  @override
  String get circleInviteCode => '招待コード';

  @override
  String get circleGenerateInvite => '招待コードを生成';

  @override
  String get circleJoin => 'コードで参加';

  @override
  String get circleJoinHint => '受け取った招待コードを貼り付け';

  @override
  String get circleJoined => '参加しました。';

  @override
  String get circleJoinFailed => 'そのコードは無効か期限切れです。';

  @override
  String circleVisibleSummary(int n, int m) {
    return '$n 体の分身が見えます · うち $m 体は招待者以外';
  }

  @override
  String get circleAcceptancePass => '受入条件を満たしました（可視3体、うち招待者以外2体が必要）';

  @override
  String get circleAcceptanceFail => 'まだ受入条件を満たしていません——もう数人近所の人を招待してください';

  @override
  String circleFallbackNote(int n, String src) {
    return 'うち $n 体はフォールバック（$src）由来——輪のメンバーではありません';
  }

  @override
  String circleMemberCount(int n) {
    return 'メンバー $n 人';
  }

  @override
  String get telemetryCounts => 'イベント件数（受入チェック）';

  @override
  String get telemetryEmpty => 'まだイベントが記録されていません。';

  @override
  String get dashboardTitle => 'ダッシュボード';

  @override
  String get dashboardFunnelTitle => '週次のファネル';

  @override
  String get dashboardColWeek => '週';

  @override
  String get dashboardColOnboarding => 'オンボーディング';

  @override
  String get dashboardColCircle => '輪';

  @override
  String get dashboardColDelegation => 'お使い';

  @override
  String get dashboardColIntercard => '紹介';

  @override
  String get dashboardColHandshake => 'ハンドシェイク';

  @override
  String get dashboardColActive => 'アクティブ';

  @override
  String get dashboardTtfd => 'TTFD 中央値';

  @override
  String get dashboardDelta => '開示 Δ';

  @override
  String get dashboardDeltaHint => '開示なしの返信率から開示ありを引いた値（フェーズ −1）。';

  @override
  String get dashboardNoData => 'まだイベントがありません——まずアプリを少し使ってください。';

  @override
  String get dashboardSourceHint => '出典：この端末のみのローカルテレメトリ。';

  @override
  String get digestTitle => 'デイリーダイジェスト';

  @override
  String get digestEmpty => '過去24時間に新しいことはありません。';

  @override
  String get digestSectionPending => 'あなたの対応待ち';

  @override
  String get digestSectionMine => 'あなたのお使い';

  @override
  String get digestSectionCircle => '輪';

  @override
  String get digestSectionStats => '数字';

  @override
  String get digestStatDone => '完了したお使い';

  @override
  String get digestStatHandshake => 'ハンドシェイク';

  @override
  String get digestActionOpenInbox => '今すぐ返信';

  @override
  String get digestActionOpenOutbox => '私のお使い';

  @override
  String get digestActionOpenCircle => '私の輪';

  @override
  String get digestActionOpenDashboard => 'ダッシュボード';

  @override
  String get digestNotePlain => 'あなたは素のダイジェスト群です（A/B 実験）。';

  @override
  String get digestNoteAction => 'あなたはアクション付き群です（A/B 実験）。';

  @override
  String get morningGreetingMorning => 'おはようございます';

  @override
  String get morningGreetingNoon => 'こんにちは';

  @override
  String get morningGreetingEvening => 'こんばんは';

  @override
  String get morningGreetingBody => 'ここ三日間のふりかえりです：';

  @override
  String morningHiPending(int count) {
    return '返信待ちの委託が $count 件';
  }

  @override
  String morningHiSent(int count) {
    return 'あなたが依頼したタスク：$count 件';
  }

  @override
  String morningHiCircle(int count) {
    return '新しく参加したサークル：$count 件';
  }

  @override
  String morningHiTopics(String topics) {
    return 'よく話す話題：$topics';
  }

  @override
  String morningHiLongTerm(String topics) {
    return '長く関心を持っているテーマ：$topics';
  }

  @override
  String get morningEmpty => 'ここ三日間は静かでした。今日を楽しみましょう。';

  @override
  String get notifyMorningTitle => 'おはようございます。三日間のふりかえり';

  @override
  String get notifyMorningBody => '分身がここ三日間の出来事をまとめました。';

  @override
  String notifyMorningBodyPending(int count) {
    return '返信待ちの委託が $count 件あります。分身が三日間の出来事をまとめました。';
  }

  @override
  String get digestSectionChat => '分身との会話';

  @override
  String digestChatSummary(int sessions, int turns, int days) {
    return '会話 $sessions 件 · $turns ターン · $days 日間';
  }

  @override
  String digestChatTopics(String topics) {
    return 'よく話す話題：$topics';
  }

  @override
  String get intercardDialogTitle => '分身の紹介カード';

  @override
  String get intercardReasonLabel => '会う価値がある理由';

  @override
  String get intercardTopicsLabel => 'トピック3つ（カンマ区切り）';

  @override
  String get intercardConfirmSend => '確認して送信';

  @override
  String get intercardReceivedTitle => '受け取った紹介';

  @override
  String get intercardMineTitle => '私が送ったカード';

  @override
  String get intercardBlockedTitle => 'カードをブロックしました';

  @override
  String get intercardBlockedL3 => 'プライベート項目の値がカード本文に漏れました。';

  @override
  String get intercardEmptyContent => '先に理由とトピックを書いてください。';

  @override
  String get intercardSentOk => '送信しました。24時間以内なら取り消せます。';

  @override
  String get intercardRevoke => '取り消す';

  @override
  String get intercardNone => 'まだ紹介カードはありません。';

  @override
  String get intercardRevoked => '取り消しました。';

  @override
  String get intercardRevokeHint => '送信しました——24時間以内なら取り消せます。';

  @override
  String get intercardSent => '送信しました。';

  @override
  String intercardFrom(String owner) {
    return '$owner のご主人様からの署名付き紹介です。';
  }

  @override
  String get deviceControlTitle => 'スマホ操作';

  @override
  String get deviceControlRefreshStatus => '状態を更新';

  @override
  String get deviceControlUnsupported => 'このビルドはスマホ操作に対応していません';

  @override
  String get deviceControlServiceConnected => 'アクセシビリティサービス：接続済み';

  @override
  String get deviceControlServiceCheckedNotConnected => 'アクセシビリティサービス：有効だが未接続';

  @override
  String get deviceControlServiceOff => 'アクセシビリティサービス：オフ';

  @override
  String get deviceControlStatusUnknown => '状態不明';

  @override
  String get deviceControlGoSystemHint =>
      'システムの一覧で「Fen」を見つけ、スイッチをオンにしてからここに戻って更新してください';

  @override
  String get deviceControlGoSettings => 'システム設定を開く';

  @override
  String get deviceControlRedetect => '再検出';

  @override
  String get deviceControlRedetectTip =>
      'ヒント：検出が何度も失敗する場合は、システム設定で「Fen スクリーンアシスタント」を一度オフにしてから再度オンにするか、アプリを再起動してください——一部の端末はバックグラウンド整理時にアクセシビリティサービスを切断します。';

  @override
  String get deviceControlAllowTitle => '分身にスマホの操作を許可する';

  @override
  String get deviceControlAllowSubReady =>
      'オンにすると、分身は画面を読み取り、タップし、入力し、アプリを開けます。初回は確認を求めます';

  @override
  String get deviceControlAllowSubChecked =>
      'システムでは有効ですが、サービスが未接続です：上の「再検出」をタップしてください';

  @override
  String get deviceControlAllowSubNeedService =>
      'このスイッチを有効にするには、先にシステムのアクセシビリティサービスをオンにしてください';

  @override
  String get deviceControlToolsHeader => '有効にすると次の機能が組み込まれます';

  @override
  String get deviceControlToolReadScreen => '画面上のテキストとタップ可能な要素を読み取る';

  @override
  String get deviceControlToolTap => 'テキストまたは座標でタップ';

  @override
  String get deviceControlToolInput => '入力欄に文字を入力';

  @override
  String get deviceControlToolSwipe => 'ページをスワイプし、リストをスクロール';

  @override
  String get deviceControlToolPressKey => '戻る／ホーム／履歴／決定';

  @override
  String get deviceControlToolOpenApp => '指定したアプリを開く（パッケージ名）';

  @override
  String get deviceControlDenylistTitle => '機密アプリの拒否リスト';

  @override
  String get deviceControlDenylistBody =>
      'これらのアプリが前面にある間、分身は一切の操作を行いません（銀行、決済、パスワード管理、システム設定）。パッケージ名を1行に1つ、カンマ区切りにも対応します。';

  @override
  String get deviceControlSaveDenylist => '拒否リストを保存';

  @override
  String get deviceControlResetDefault => '既定に戻す';

  @override
  String get deviceControlFooter =>
      '注意：スマホ操作は Android のアクセシビリティサービスを使用します——root 不要、追加プラグイン不要。\n· 上のスイッチをオフにすると、関連ツールは即座に分身から取り消されます。\n· すべての操作は監査ログに記録され、「設定の管理」で確認できます。\n· 分身が許可していないアプリを操作することは決してありません。';

  @override
  String get deviceControlToastNeedAccessibility =>
      '先にシステム設定で「Fen」のアクセシビリティサービスを有効にしてください';

  @override
  String get deviceControlToastOn => 'スマホ操作を有効にしました：初回は引き続き確認を求めます';

  @override
  String get deviceControlToastOff => 'スマホ操作を無効にしました。関連ツールは取り消されました';

  @override
  String deviceControlToastSaved(String n) {
    return '拒否リストを保存しました（$n 件）';
  }

  @override
  String get deviceControlToastReset => '既定の拒否リストに戻しました';

  @override
  String get contactDefaultAgentName => 'ワイルド・エージェント';

  @override
  String get contactDefaultMasterName => '実体探査中';

  @override
  String get contactDefaultNotes => 'メモなし';

  @override
  String get contactSendingThroughGateway => '⚡ ゲートウェイを通して直接送信中……';

  @override
  String get contactEditTitle => '分身プロフィールのメモを編集';

  @override
  String get contactEditAgentLabel => '分身のニックネーム';

  @override
  String get contactEditMasterLabel => '持ち主のメモ';

  @override
  String get contactEditNotesLabel => '非公開の資料';

  @override
  String get contactEditConfirm => '同期を確定';

  @override
  String get contactEditSaved => '✅ プロフィールメモを記録し、同期しました！';

  @override
  String get contactRequestReco => '推薦を依頼';

  @override
  String get contactSendGift => 'ギフトを送る';

  @override
  String contactGiftSent(String gift) {
    return '$gift を送りました。相手の受領待ちです';
  }

  @override
  String get contactGiftFailed => 'ギフト失敗：相手がオフラインか、どのチャネルにもいません';

  @override
  String get contactRecoRequested => '🤝 推薦リクエストを送りました。相手は手元の評判に基づいて判断します';

  @override
  String get contactRecoFailed => 'リクエスト失敗：相手がどのオンラインチャネルにもいません';

  @override
  String get contactTierBlockToast => '評判が低すぎます。名簿からこのノードを削除してブロックすることをおすすめします';

  @override
  String contactTierAdjusted(String tier) {
    return '✅ 評判の提案に従い $tier に調整しました';
  }

  @override
  String get contactTierFriend => '友人に昇格できます';

  @override
  String get contactTierFamily => '家族に昇格できます';

  @override
  String get contactTierStranger => '見知らぬ人への降格を提案';

  @override
  String get contactTierBlock => 'ブロックを提案';

  @override
  String get contactStatusLocked => 'レーダー固定中';

  @override
  String get contactStatusSent => '返信待ち';

  @override
  String get contactStatusReceived => '持ち主の審査待ち';

  @override
  String get contactStatusAccepted => '会話中';

  @override
  String get contactStatusRejected => '実体で阻止';

  @override
  String contactOwnerLine(String name) {
    return '持ち主：$name';
  }

  @override
  String get contactOnline => 'オンライン';

  @override
  String get contactOutOfRange => '範囲外';

  @override
  String contactReputation(String score) {
    return '📊 評判 $score';
  }

  @override
  String contactGiftStats(String sent, String received) {
    return '🎁 送信 $sent／受領 $received';
  }

  @override
  String get contactTierBlockBanner => '⚠️ 評判が低すぎます。ブロックをおすすめします（タップで表示）';

  @override
  String contactTierHintBanner(String suggestion) {
    return '💡 評判の提案：$suggestion（タップで適用）';
  }

  @override
  String contactNotesLine(String notes) {
    return '📝 メモ：$notes';
  }

  @override
  String get contactEmptyChat => 'まだ会話がありません。\n下に入力して直接話しかけましょう！';

  @override
  String get contactSayHint => '強制的にチャット、メッセージを入力……';

  @override
  String get dshImportTitle => 'DSH エコシステムから取り込む';

  @override
  String get dshImportClipboardEmpty => 'クリップボードが空です';

  @override
  String get dshImportNoFileContent => 'ファイルの内容を読み取れませんでした。別の方法で選択してみてください';

  @override
  String dshImportPickFailed(String err) {
    return 'ファイルの選択に失敗：$err';
  }

  @override
  String get dshImportPasteSkillFirst => '先に SKILL.md の内容を貼り付けてください';

  @override
  String get dshImportIntroTitle => 'DSH エコシステム全体を活用する';

  @override
  String get dshImportIntroBody =>
      'DSH のプラグインは TypeScript で書かれており、スマホではそのまま動きません。\nただし、そのスキルと MCP サーバーはそのまま移せます。\n\n安全のため：取り込んだプラグインは既定で無効で、端末署名の検証が付きます——手動で有効にして初めて効力を持ちます。';

  @override
  String get dshImportSecSkillTitle => '① スキルを取り込む（SKILL.md）';

  @override
  String get dshImportSecSkillSub =>
      'プレーンテキストのスキルは100%移行でき、DSH エコシステムで最も移しやすい部分です。1つを貼り付けるか、複数の .md ファイルをまとめて選択してください。';

  @override
  String get dshImportSkillHint =>
      'SKILL.md 全体を貼り付け（--- ヘッダーの name／description を含む）';

  @override
  String get dshImportPaste => '貼り付け';

  @override
  String get dshImportPickFiles => 'ファイルを選ぶ';

  @override
  String get dshImportImport => '取り込む';

  @override
  String get dshImportSecMcpTitle => '② MCP サーバーを取り込む';

  @override
  String get dshImportSecMcpSub =>
      'MCP は言語に依存しないプロトコルで、アドレスを入力するだけで接続できます。dsh／Claude 形式の mcpServers 設定の貼り付けに対応しています。';

  @override
  String dshImportMcpHint(String example) {
    return '例：$example\nhttps:// だけのアドレスを貼り付けることもできます';
  }

  @override
  String get dshImportSecInspectTitle => '③ プラグイン一式の下調べ';

  @override
  String get dshImportSecInspectSub =>
      'DSH のプラグイン一式をお持ちですか？手間をかける価値があるか判断する前に下調べしましょう。その package.json（必須）と cordis.patch.yml（任意）を貼り付けてください。';

  @override
  String get dshImportPackageJsonHint => 'package.json 全体を貼り付け';

  @override
  String get dshImportPatchHint => 'cordis.patch.yml 全体を貼り付け（任意）';

  @override
  String get dshImportPastePackageJson => 'package.json を貼り付け';

  @override
  String get dshImportStartInspect => '下調べを実行';

  @override
  String get dshImportGoToolCenter => 'スキル管理センターを開いて、取り込んだものを有効にしましょう';

  @override
  String dshImportSummaryImportedOk(String n) {
    return '$n 件を取り込みました';
  }

  @override
  String dshImportSummarySkipped(String n) {
    return '、$n 件をスキップ';
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
  String get dshSkipDuplicateSkill => '同じ名前のスキルがすでに存在します。上書きしません';

  @override
  String get dshSkipDuplicateMcp => '同じ名前の MCP 設定がすでに存在します。上書きしません';

  @override
  String get dshSkipInvalidJson => 'この内容は有効な JSON でも URL でもありません';

  @override
  String get dshSkipCommandLineMcp =>
      'これはコマンドライン MCP です（ローカルプロセスが必要）。スマホでは動きません。代わりに HTTP アドレスをお使いください';

  @override
  String get dshSkipNoUrlField => 'この設定に url フィールドが見つかりません';

  @override
  String get dshSkipMissingNameUrl => 'name または url がありません';

  @override
  String get dshSkipUnrecognizedJson => '認識できない JSON 構造です';

  @override
  String get dshSkipInvalidScheme => 'アドレスは http:// または https:// で始まる必要があります';

  @override
  String get dshSkipSubjectConfig => '設定';

  @override
  String get dshSkipSubjectConfigParseFailed => '設定の解析に失敗';

  @override
  String get dshSkipSubjectUnnamedEntry => '名称未設定の項目';

  @override
  String get dshNoteSkillDefaultsOff =>
      '取り込んだスキルは既定で無効です——スキル管理センターで必要に応じて有効にしてください。有効にすると、分身の話し方や振る舞いに影響します。';

  @override
  String get dshNoteMcpDefaultsOff =>
      '取り込んだ MCP サーバーは既定で無効です。有効にして初めて使うとき、システムが「ネットワークアクセス」権限の付与を求め、それから実際に接続します。';

  @override
  String get dshNotePasteMcpFirst => '先に MCP の設定またはアドレスを貼り付けてください';

  @override
  String dshInspectErrPackageFormat(String msg) {
    return '❌ package.json の解析に失敗：$msg';
  }

  @override
  String dshInspectErrPackageNotJson(String msg) {
    return '❌ package.json が有効な JSON ではありません：$msg';
  }

  @override
  String dshInspectErrPatchFormat(String msg) {
    return '❌ cordis.patch.yml の解析に失敗：$msg';
  }

  @override
  String dshInspectPackageLine(String name) {
    return '一式：$name';
  }

  @override
  String dshInspectBundleLine(String path) {
    return '一式のファイル：$path';
  }

  @override
  String dshInspectProfileBundlesLine(String list) {
    return 'プロファイルの一式：$list';
  }

  @override
  String get dshInspectNoPatchHint =>
      'ℹ️ cordis.patch.yml が提供されていないため、一式の基本情報しか見えません。そのファイルの内容も貼り付ければ、スマホに移せるものを判断できます。';

  @override
  String dshInspectRowCountLine(String n) {
    return 'プラグインは合計 $n 行。下調べの結果：';
  }

  @override
  String dshInspectGroupLine(String verdict, String n) {
    return '[$verdict] $n 行';
  }

  @override
  String dshInspectMoreRowsLine(String n) {
    return '  · …さらに $n 行';
  }

  @override
  String dshInspectConclusionLine(String skill, String mcp, String heavy) {
    return '結論：スキル $skill 行と MCP $mcp 行は直接取り込めます。$heavy 行は Dart で書き直すかデスクトップ環境が必要なため、ここでは動きません。';
  }

  @override
  String get dshInspectVerdictDirectSkill => '✅ 直接取り込み可（スキル）';

  @override
  String get dshInspectVerdictMcpServer => '✅ 直接接続可（MCP サーバー）';

  @override
  String get dshInspectVerdictConfigOnly => '⚙️ 設定のみ（移行不要）';

  @override
  String get dshInspectVerdictPlatformGated => '🖥️ デスクトップ環境が必要（スマホでは使えません）';

  @override
  String get dshInspectVerdictNeedsDart => '🧱 Dart での書き直しが必要（TS コードを含む）';

  @override
  String get chatCleared => '🧹 ワークスペースと LLM の記憶をクリアしました。新しいセッションを開始します！';

  @override
  String get chatImageOptionsTitle => '画像や視覚的な内容を送る';

  @override
  String get chatTakePhoto => '写真を撮る';

  @override
  String get chatPickFromAlbum => 'アルバムから選ぶ';

  @override
  String get chatAudioOptionsTitle => '音声や録音を送る';

  @override
  String get chatStartRecording => '録音を開始';

  @override
  String get chatLocalAudio => 'ローカルの音声';

  @override
  String chatOpenCameraFailed(String err) {
    return 'カメラを開けませんでした：$err';
  }

  @override
  String chatOpenAlbumFailed(String err) {
    return 'アルバムを開けませんでした：$err';
  }

  @override
  String chatPickAudioFailed(String err) {
    return '音声ファイルの選択に失敗：$err';
  }

  @override
  String get chatNoMicPermission =>
      'マイクの権限がありません：システム設定で「音声の録音」権限を許可してから再試行してください';

  @override
  String chatStartRecordingFailed(String err) {
    return '録音の開始に失敗：$err';
  }

  @override
  String get chatWelcomeBack => 'おかえりなさい、ご主人様！';

  @override
  String get chatAgentReady => 'AI 執事は準備万端、お待ちしています';

  @override
  String get chatQuickTechTitle => '🔍 今日のテックニュース';

  @override
  String get chatQuickTechPrompt => '今日の最新 AI テックニュースを検索して要約して。';

  @override
  String get chatQuickRadarTitle => '📡 近くの人をスキャン';

  @override
  String get chatQuickRadarPrompt => '実体レーダーを確認して——周りに稼働中のノードはある？';

  @override
  String get chatQuickProfileTitle => '📝 私のプロフィールを磨く';

  @override
  String get chatQuickProfilePrompt => '昨日の会話から、私の新しい好みに気づいた？';

  @override
  String get chatAudioFile => '音声ファイル';

  @override
  String get chatRecording => '🔴 録音中……';

  @override
  String get chatInputHint => '執事に指示を送る……';

  @override
  String get profileSavedToast => '🔒 ご主人様の極秘プロフィールを保存しました';

  @override
  String get profileAddPerson => '関係者を追加';

  @override
  String get profileEditPerson => '人物情報を編集';

  @override
  String get profileNameLabel => '名前（例：エミー）';

  @override
  String get profileRelationLabel => '関係（例：妻）';

  @override
  String get profileIdentityLabel => '身分のメモ（例：小学校の教師）';

  @override
  String get profileSecretLabel => '秘密の詳細（例：イチゴが好き）';

  @override
  String get profileSaveVault => '保存して金庫に固定';

  @override
  String get profileTitle => 'ご主人様の極秘プロフィールと人脈';

  @override
  String get profilePreferenceHeader => '👤 ご主人様の好み';

  @override
  String get profileJobLabel => '職業';

  @override
  String get profileHobbiesLabel => '趣味と得意なこと';

  @override
  String get profileDislikesLabel => '苦手なことと禁忌';

  @override
  String get profileOtherLabel => 'その他のメモ——自由記述';

  @override
  String get profileSaveBase => '💾 基本の好みを保存（ローカル金庫へ）';

  @override
  String get profileNetworkHeader => '🔗 極秘の人脈ネットワーク';

  @override
  String get profileAdd => '追加';

  @override
  String get profileNetworkEmpty => 'まだ何もありません——右上の「追加」をタップ';

  @override
  String profileDetailLine(String notes) {
    return '📝 詳細：$notes';
  }

  @override
  String get profileAiReadable => '🔓 AI はこの人物の情報を読むことを許可されています';

  @override
  String get profileAiIsolated => '🔒 AI はこの人物の情報から物理的に隔離されています';

  @override
  String get giftPickerTitle => '🎁 感謝の品を選ぶ';

  @override
  String get giftNoteLabel => 'メッセージを添える（任意）';

  @override
  String get giftNoteHint => '例：先日は助かりました';

  @override
  String get giftSend => '送る';

  @override
  String get giftNameTea => '一杯のお茶';

  @override
  String get giftNameBook => '一冊の本';

  @override
  String get giftNameFlower => '花束';

  @override
  String get giftNameCake => 'ケーキ一切れ';

  @override
  String get giftNameMysteryBox => 'ミステリーボックス';

  @override
  String get giftNameStar => '星';

  @override
  String get themeRed => '赤';

  @override
  String get themeOrange => '橙';

  @override
  String get themeYellow => '黄';

  @override
  String get themeGreen => '緑';

  @override
  String get themeCyan => 'シアン';

  @override
  String get themeBlue => '青';

  @override
  String get themePurple => '紫';

  @override
  String get themeWhite => '白';

  @override
  String get themeBlack => '黒';

  @override
  String get mainClearSession => 'クリアして新しいセッションを開始';

  @override
  String get mainNavChat => 'チャット';

  @override
  String get mainNavSocial => 'Fen コミュニティ';

  @override
  String get mainNavWorld => 'Wold';

  @override
  String get mainNavSerendipity => 'セレンディピティ';

  @override
  String get mainNavManage => '管理';

  @override
  String topicChatLogSuffix(String range) {
    return '$range のチャットログ';
  }

  @override
  String get topicArchiveTitle => 'スマート記憶アーカイブ';

  @override
  String get topicTabTimeline => 'タイムライン';

  @override
  String get topicTabTopics => 'トピック';

  @override
  String get topicEmptyArchive => 'まだアーカイブされたデータがありません';

  @override
  String get topicNoTag => 'タグなし';

  @override
  String get topicDailyChat => '日々の会話';

  @override
  String topicCountLabel(String count) {
    return '$count 件';
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
  String get deviceControlStatusReady => 'スマホ操作の準備完了：分身は画面を読み取り、タップし、入力できます';

  @override
  String get deviceControlStatusUnsupportedShort =>
      'このビルドにはスマホ操作モジュールが含まれていません';

  @override
  String get deviceControlStatusUnsupportedFull =>
      'このビルドにはスマホ操作モジュールが含まれていません（Android のアクセシビリティサービスが必要です）';

  @override
  String get deviceControlStatusCheckedOffline =>
      'システムでは有効ですが、サービスがまだ未接続です。右上の「更新」をタップしてください。それでも失敗する場合は、システム設定でスイッチを一度オフにして再度オンにしてください（またはアプリを再起動）。';

  @override
  String get deviceControlStatusOff => 'システム設定でアクセシビリティサービスがまだ有効になっていません';

  @override
  String deviceControlStatusQueryFailed(String err) {
    return '状態の取得に失敗：$err';
  }

  @override
  String deviceControlGuardBlocked(String pkg) {
    return '前面のアプリ（$pkg）は安全のため拒否リストにあります。分身はこれに対して操作を行いません。どうしても必要な場合は、「スマホ操作」設定ページで制限を解除してください。';
  }

  @override
  String commonNetworkError(String err) {
    return 'ネットワークエラー: $err';
  }

  @override
  String get netFaultLanHijackAdvice =>
      '🤖【分身の自己診断】\nご主人様、私の LLM がインターネットに到達できません！\nこれは多くの場合、実体レーダー（近接／LAN）がオンで、現在の Wi-Fi LAN にインターネット出口がないときに起こります——機器同士は互いを発見できますが公衆網に出られず、クラウド LLM を呼べません。\n\n提案：1）実体レーダーをオフにする；2）Wi-Fi を切ってモバイルデータに切り替える；3）またはシステム設定でスマートネットワーク切り替えを有効にする。\n今のところ、低位の物理リンクだけは維持できます。';

  @override
  String netFaultSocialSkipped(String err) {
    return '❌ クラウド LLM に到達できません：ネットワーク到達不可。実体レーダーがオンなら、現在の Wi-Fi LAN にインターネット出口がない可能性があります——機器同士は発見できますが公衆網に出られません。今回はスキップしました。\n提案：実体レーダーをオフにするか、Wi-Fi を切ってモバイルデータに切り替えてから再試行してください。\n理由：$err';
  }

  @override
  String socialPipelineError(String err) {
    return '❌ 社交判断パイプラインのエラー、今回は中止しました：$err';
  }

  @override
  String netFaultNetworkTrouble(String err) {
    return '❌ クラウド LLM に到達できません（ネットワークの問題で、コードの不具合ではありません）。\nネットワークの切り替え、通信事業者の回線問題、または現在の Wi-Fi にインターネット出口がない可能性があります。\nお試し：1）Wi-Fi を切ってモバイルデータを使う；2）システム設定で「モバイルデータへの自動切り替え」を有効にする；3）後でもう一度試す。\n理由：$err';
  }

  @override
  String get netFaultCooldownSkipped =>
      '⏸ ネットワークが繰り返し失敗——LLM 呼び出しを10分間休止します（トークンの浪費を止めます）。';

  @override
  String get worldSvcNoHub => 'クラウド Hub／ワールドのアドレスが未設定です';

  @override
  String get worldSvcMustBeHttps =>
      'ワールドのアドレスは HTTPS かプライベート LAN のアドレスである必要があります';

  @override
  String worldSvcRoomsFailed(String code, String body) {
    return 'ルーム一覧の取得に失敗：$code $body';
  }

  @override
  String worldSvcOpFailed(String code, String body) {
    return '操作に失敗（$code）：$body';
  }

  @override
  String worldSvcReportFailed(String code) {
    return 'レポートの取得に失敗：$code';
  }

  @override
  String get godSvcMustBeHttps =>
      'GOD のアドレスは HTTPS かプライベート LAN のアドレスである必要があります';

  @override
  String godSvcStatusFailed(String code, String body) {
    return '状態の取得に失敗（$code）：$body';
  }

  @override
  String get godSvcNoBridge => 'GOD ブリッジのアドレスが未設定です';

  @override
  String godSvcCmdFailed(String code, String body) {
    return 'コマンド失敗（$code）：$body';
  }

  @override
  String get passportTitle => 'パスポートと評判';

  @override
  String get passportEntryTile => 'Wold パスポート';

  @override
  String get passportEntryHint => '検証可能な署名付き記録 · オフラインでも動作';

  @override
  String get passportCardHeader => '私の Wold パスポート';

  @override
  String get passportIssuedLabel => '発行';

  @override
  String get passportCopyAction => '身元をコピー';

  @override
  String get passportRefreshAction => '更新';

  @override
  String get passportCopiedToast => 'コピーしました';

  @override
  String passportStatLine(String label, String value) {
    return '$label：$value';
  }

  @override
  String get passportLedgerHeader => '紹介の台帳';

  @override
  String get passportLedgerEmpty => 'まだ紹介がありません。ワールドのルームで誰かと出会ってください。';

  @override
  String get passportDirectionOut => '私が開始';

  @override
  String get passportDirectionIn => '私が受領';

  @override
  String get passportPeerLabel => '相手';

  @override
  String get passportTopicLabel => 'トピック';

  @override
  String get passportRoomLabel => '元のルーム';

  @override
  String get passportTrustLabel => '検証レベル';

  @override
  String get passportTrustNone => '未検証';

  @override
  String get passportTrustInitiated => '開始者のみ署名';

  @override
  String get passportTrustConsented => '双方が同意';

  @override
  String get passportTrustResolved => '結果を記録';

  @override
  String get passportTrustAcknowledged => '双方が確認';

  @override
  String get passportOutcomeLabel => '結果';

  @override
  String get passportOutcomeHandshake => 'ハンドシェイク';

  @override
  String get passportOutcomeDeclined => '辞退';

  @override
  String get passportOutcomeNoResponse => '応答なし';

  @override
  String get passportOutcomeWithdrawn => '取り下げ';

  @override
  String get passportVerifyDetails => '検証の詳細';

  @override
  String get passportChecksLabel => '合格';

  @override
  String get passportFaultsLabel => '不合格';

  @override
  String get passportConsentAction => 'この紹介に同意する';

  @override
  String get passportConsentDone => '同意しました';

  @override
  String get passportResolveAction => '結果を記録';

  @override
  String get passportResolveTitle => 'この紹介の結果';

  @override
  String get passportAckAction => '結果を確認';

  @override
  String get passportAckDone => '確認しました';

  @override
  String get passportActionDelivered => '署名して送達';

  @override
  String get passportActionOffline => '記録しました。相手は現在到達不可で、後で再試行します';

  @override
  String get passportActionRejected => '効力を持ちませんでした（順序または身元の不一致）';

  @override
  String get passportFunnelHeader => '紹介からハンドシェイクへの転換';

  @override
  String get passportFunnelProposedLabel => '提案';

  @override
  String get passportFunnelConsentedLabel => '同意';

  @override
  String get passportFunnelHandshakeLabel => 'ハンドシェイク';

  @override
  String get passportFunnelSettledLabel => '成立';

  @override
  String get passportFunnelInFlightLabel => '進行中';

  @override
  String get passportFunnelConsentRateLabel => '同意率';

  @override
  String get passportFunnelConversionLabel => '転換率';

  @override
  String get passportLogHeader => '透明性ログ';

  @override
  String get passportLogSizeLabel => 'ツリーサイズ';

  @override
  String get passportLogRootLabel => 'マークルルート';

  @override
  String get passportLogCopyAction => 'ルートをコピー';

  @override
  String get passportNewIntroAction => '新しい紹介';

  @override
  String get passportNewIntroPeerLabel => '相手の分身 ID';

  @override
  String get passportNewIntroTopicLabel => '一行のトピック';

  @override
  String get passportNewIntroSubmit => '提案する';

  @override
  String get passportNewIntroNeedPeer => '相手の分身 ID を入力してください';

  @override
  String get passportNewIntroNoCircle =>
      'まだ輪がありません。紹介に持ち主を持たせるため、先に輪に参加してください。';

  @override
  String passportNewIntroDone(String peer) {
    return '$peer へ提案し、署名しました';
  }

  @override
  String radarNoticeStarted(int minutes) {
    return '🛡️ レーダー起動——$minutes 分の社交パーティが始まりました……';
  }

  @override
  String get radarNoticeStopped => '💤 レーダー停止——社交パーティは終了しました。';

  @override
  String get radarNotifTitle => 'AiSteward · レーダーゲートウェイ全開稼働中';

  @override
  String get radarNotifText => 'あなたのデジタル分身が、現実世界であなたのために休まず社交しています……';

  @override
  String get radarNoticePartyEnded => '⏰ 時間切れ——統括エージェントがアンテナを引き上げました！';

  @override
  String get radarNoticeWrappingUp => '⏳ 残り10分を切りました——分身がお別れの準備をしています。';

  @override
  String get cloudHubNotConfigured => 'クラウド Hub のアドレスが未設定です';

  @override
  String get cloudKeyRequired =>
      'このリレーにはアクセスキーが必要です。運営者が発行したキーを「詳細設定」で入力してください。';

  @override
  String get cloudKeyInvalid => 'アクセスキーが無効です。コピーが欠けていないか確認してください。';

  @override
  String get cloudKeyRevoked => 'このアクセスキーは停止されています。リレーの運営者に連絡してください。';

  @override
  String get cloudKeyBound => 'このキーは別の ID に紐づいています。別のキーを使ってください（または ID 復元）。';

  @override
  String get cloudAgentRevoked => 'この端末の ID はリレーで停止されたため、送受信できません。';

  @override
  String get cloudRegisterClosed => 'リレーは新規登録を停止しています。';

  @override
  String get cloudRegisterIdentityConflict =>
      'この ID は別の鍵に紐づいています。「ID 復元／鍵交換」を使ってください。ID を削除しないでください。';

  @override
  String cloudRosterFailed(int status, String body) {
    return '名簿の取得に失敗（$status）：$body';
  }

  @override
  String cloudNetworkError(String error) {
    return 'ネットワークエラー：$error';
  }

  @override
  String cloudCardFailed(int status) {
    return '連絡先カードの取得に失敗（$status）';
  }

  @override
  String get identityChangedWarning =>
      '🚨 身元が変更されました：相手の公開鍵が以前に固定したものと一致しません（中間者攻撃か鍵の再生成の可能性）。ハンドシェイクを拒否し、信頼を大幅に下げました。';

  @override
  String get lanTunnelOpen => '⚡ LAN の物理チャネル（TCP/UDP）が開きました！';

  @override
  String get lanTargetLost => '⚠️ Wi-Fi の物理ターゲットが範囲外になりました。';

  @override
  String get p2pBtDisconnected => '⚠️ Bluetooth 接続が切断されました。';

  @override
  String repEventLog(String delta, String event, String detail) {
    return '評判 $delta（$event）$detail';
  }

  @override
  String repEventDetailSuffix(String detail) {
    return '：$detail';
  }

  @override
  String repGiftLogIncoming(String gift, String note) {
    return '$gift——そのノードからの好意の品$note';
  }

  @override
  String repGiftLogOutgoing(String gift, String note) {
    return '$gift——そのノードへ送った好意の品$note';
  }

  @override
  String repGiftNoteQuoted(String note) {
    return '——「$note」';
  }

  @override
  String repGiftMemoryIncoming(String name, String gift, String note) {
    return '$name がギフト $gift を送ってきた $note';
  }

  @override
  String repGiftMemoryOutgoing(String gift, String name, String note) {
    return '$name へギフト $gift を送った $note';
  }

  @override
  String repGiftMemoryNote(String note) {
    return '（$note）';
  }

  @override
  String repRecoLog(int score, String date) {
    return '🤝 推薦状を受け取りました：評判 $score（発行 $date、署名検証済み）';
  }

  @override
  String repRecoMemory(String issuer, int score, String date) {
    return '$issuer から推薦状を受け取りました（評判 $score、発行 $date）';
  }

  @override
  String get repNetHeader => 'ネットワークの推薦';

  @override
  String repNetAnchors(int count, int min) {
    return 'アンカー $count 件（ローカル評判 ≥ $min）';
  }

  @override
  String get repNetMineLabel => '私が推薦した相手';

  @override
  String get repNetForMeLabel => '私を推薦した相手';

  @override
  String get repNetEmpty => 'まだありません';

  @override
  String get repNetIssueAction => '推薦する';

  @override
  String get repNetIssueTitle => '推薦に署名する';

  @override
  String get repNetIssueSubjectLabel => '相手のパスポート DID または公開鍵';

  @override
  String get repNetIssueNeedSubject => '相手の DID（did:wold:…）または公開鍵を貼り付け';

  @override
  String get repNetIssueBadSubject => '有効な DID または公開鍵ではありません';

  @override
  String get repNetIssueTierLabel => '階層';

  @override
  String get repNetIssueNoteLabel => 'メモ（任意）';

  @override
  String get repNetIssueBindLabel => '相手の分身 ID（任意。ローカル評判をこの鍵に結びつけます）';

  @override
  String get repNetTierAcquaintance => '知人';

  @override
  String get repNetTierFriend => '友人';

  @override
  String get repNetTierFamily => '家族';

  @override
  String get repNetIssuedToast => '推薦に署名して保存しました';

  @override
  String repNetFailedToast(String code) {
    return '拒否されました：$code';
  }

  @override
  String get repNetSelfReject => '自分自身を推薦することはできません';

  @override
  String get repNetExpiresLabel => '有効期限';

  @override
  String get repNetRevokeAction => '取り消す';

  @override
  String get repNetRevokedToast => '推薦を取り消しました';

  @override
  String repNetBoundToast(String id) {
    return '$id の公開鍵を記憶しました';
  }

  @override
  String get repNetVerifyAction => '検証';

  @override
  String get repNetVerifiedToast => '署名は有効です';

  @override
  String get repNetBadSignatureToast => '署名が無効です——推薦が改ざんされています';

  @override
  String get repNetQueryLabel => '誰かを調べる';

  @override
  String get repNetQueryAction => 'たどる';

  @override
  String repNetQueryKnown(
      String tier, int depth, String confidence, int paths) {
    return '$tier · $depth ホップ先 · 信頼度 $confidence · $paths 経路';
  }

  @override
  String get repNetQueryUnknown => '検証可能な経路がありません';

  @override
  String get repNetPathLabel => '証拠の連鎖（各ホップはご自身で検証を）';

  @override
  String get repNetPathStart => 'あなたが信頼する';

  @override
  String get repNetPathHop => '→ が推薦する';

  @override
  String get repNetStatusRevoked => '取り消し済み';

  @override
  String get repNetStatusExpired => '期限切れ';

  @override
  String repNetKeysMerged(int count) {
    return '鍵のローテーション連鎖を通じて $count 個の鍵にまたがって統合——ローテーション前に受け取った推薦も有効です。';
  }

  @override
  String get skillMarketTitle => 'スキルマーケット';

  @override
  String get skillMarketSubtitle => '作者が署名したスキルを公開し、収益配分を追跡';

  @override
  String get skillRevenueTitle => '作者の収益';

  @override
  String skillRevenueTotal(String amount) {
    return '累計獲得 $amount';
  }

  @override
  String skillRevenueCount(int count) {
    return '$count 件の支払い';
  }

  @override
  String get skillRevenueEmpty => 'まだ収益はありません';

  @override
  String get skillNoListings => 'レジストリにはまだ何も公開されていません。';

  @override
  String get skillPublishAction => 'スキルを公開';

  @override
  String get skillPublishTitle => '署名付きスキルを公開';

  @override
  String get skillFieldId => 'スキル ID';

  @override
  String get skillFieldVersion => 'バージョン';

  @override
  String get skillFieldName => '名前';

  @override
  String get skillFieldDesc => '説明';

  @override
  String get skillFieldPrice => '価格（元、0＝無料）';

  @override
  String get skillFieldRisk => 'リスク';

  @override
  String get skillFieldCaps => '権限';

  @override
  String get skillFieldContent => '内容（ハッシュ化して署名）';

  @override
  String get skillSubmit => '署名して公開';

  @override
  String get skillNeedFields => 'スキル ID、バージョン、名前、内容は必須です';

  @override
  String get skillRevokeAction => '取り消す';

  @override
  String skillRevokeConfirm(String skill) {
    return '$skill を取り消しますか？元に戻せません。';
  }

  @override
  String skillPublishedOk(String skill) {
    return '$skill を公開しました';
  }

  @override
  String get skillPublishDuplicate => '同じバージョンと内容がすでに公開されています';

  @override
  String get skillPublishVersionConflict => '同じバージョンで内容が異なります——拒否しました';

  @override
  String get skillPublishAuthorChanged => 'このスキル ID は別の作者のものです——拒否しました';

  @override
  String get skillPublishVersionNotIncreased => 'バージョンは公開済みより大きい必要があります';

  @override
  String get skillPublishUnverified => '署名が無効です——拒否しました';

  @override
  String skillRevokedOk(String skill) {
    return '$skill を取り消しました';
  }

  @override
  String get skillRevokeRejected => '取り消しを拒否——あなたは作者の鍵ではありません';

  @override
  String get skillMineTag => '自分';

  @override
  String get skillFree => '無料';

  @override
  String skillPriceYuan(String amount) {
    return '¥$amount';
  }

  @override
  String get skillAuthorKey => '作者の鍵';

  @override
  String get skillRevokedTag => '取り消し済み';

  @override
  String get skillVerifyAction => '署名を検証';

  @override
  String get skillVerifyOk => '署名は有効です';

  @override
  String skillVerifyFail(String code) {
    return '検証に失敗：$code';
  }

  @override
  String skillVersionHistory(int count) {
    return '$count バージョン';
  }

  @override
  String runtimeInitFailed(String err) {
    return 'ローカルランタイムが起動しなかったため、ワールド・輪・お使いの機能が利用できません。その他は通常どおり動作します。（$err）';
  }

  @override
  String get idbEntry => '身元のバックアップと復元';

  @override
  String get idbTitle => '身元のバックアップと復元';

  @override
  String get idbIntro =>
      'あなたの身元は*この鍵そのもの*で、このスマホにしかありません。スマホを失えば身元も永久に失われ、私たちを含め誰も再発行できません。復元コードを紙に書き留めてください。それだけが戻る道です。';

  @override
  String get idbCurrentDid => '現在の身元（DID）';

  @override
  String get idbNoScreenshotShort => '絶対にスクリーンショットしない';

  @override
  String get idbSectionBackup => '身元をバックアップ';

  @override
  String get idbWarnNoScreenshot =>
      '⚠️ 復元コードは*あなたの身元そのもの*です。紙に写してオフラインで保管してください。スクリーンショットを撮らず、クラウドストレージに置かず、誰にも（私たちにも）送らないでください。';

  @override
  String get idbPwLabel => '復元パスワード（10文字以上）';

  @override
  String get idbPwConfirmLabel => 'パスワードを再入力';

  @override
  String get idbPwMismatch => '2つのパスワードが一致しません';

  @override
  String get idbPwTooShort => 'パスワードが短すぎます（10文字以上）';

  @override
  String get idbGenerateAction => '復元コードを生成';

  @override
  String get idbCodeTitle => 'あなたの復元コード（書き留めてください）';

  @override
  String get idbCopyCode => 'コードをコピー';

  @override
  String get idbCopiedToast => '復元コードをコピーしました——後でクリップボードを消去するのをお忘れなく';

  @override
  String get idbICopied => '紙に書き留めてオフラインで保管しました';

  @override
  String get idbNeedCopied => '復元コードを書き留めたことを確認してください';

  @override
  String get idbDoneToast => '身元をバックアップしました';

  @override
  String get idbSectionRestore => '新しいスマホで復元';

  @override
  String get idbRestoreAction => '身元を復元';

  @override
  String get idbRestoreCodeLabel => '復元コード';

  @override
  String get idbRestoreIdLabel => 'ユーザー ID（AG-…）';

  @override
  String get idbRestorePwLabel => '復元パスワード';

  @override
  String get idbRestoreCheckAction => '確認';

  @override
  String get idbRestoreNeedAll => '復元コード、ユーザー ID、パスワードを入力してください';

  @override
  String get idbRestoreConfirmTitle => 'これが復元したい身元か確認してください';

  @override
  String idbRestoreConfirmBody(String did) {
    return '復元しようとしています：$did\n\nその後、このスマホが身元を引き継ぎ、古いスマホは即座に使えなくなります。';
  }

  @override
  String get idbRestoreConfirmAction => '今すぐ復元';

  @override
  String get idbRestoreBusy => '鍵をローテーション中……';

  @override
  String get idbRestoreOk => '復元が完了しました。古いスマホの身元はもう無効です——データを消去してください。';

  @override
  String idbRestoreFail(String code) {
    return '復元に失敗：$code';
  }

  @override
  String get idbErrHubNotConfigured =>
      'Hub アドレスが未設定のため、鍵をローテーションできません。先にワールド設定でサーバーアドレスを設定してください。';

  @override
  String get idbErrIdMismatch =>
      'ユーザー ID が復元コード内の身元と一致しません——正しいバックアップを使っているか確認してください。';

  @override
  String get idbErrBadPassword => 'パスワードが間違っているか、復元コードが改ざんされています。';

  @override
  String get idbErrBadFormat => '復元コードの形式が正しくありません（全体をコピーし、一部を欠かさないでください）。';

  @override
  String get idbErrNotCurrentKey =>
      'この身元の現在の鍵はもうその鍵ではありません——すでにローテーションされた可能性があります。';

  @override
  String get idbRestoreUnavailable => 'ローカルの身元がまだ準備できていないため、バックアップ／復元は利用できません。';

  @override
  String get idbStatusBackedUp => '身元はバックアップ済み';

  @override
  String get idbStatusBackedUpHint =>
      '現在の鍵の復元コードは書き留め済みです。後で復元すると、この端末は無効になります。';

  @override
  String get idbStatusNotBackedUp => '身元は未バックアップ';

  @override
  String get idbStatusNotBackedUpHint =>
      'このスマホを失うか壊すと、身元とすべての履歴は永久に失われます——私たちを含め誰も再発行できません。';

  @override
  String get arcSectionTitle => 'ローカルデータを書き出す';

  @override
  String get arcExportAction => 'ローカルデータを書き出す';

  @override
  String get arcExportNote =>
      'このアーカイブにパスワードを設定します。復元コードのパスワードと一致させる必要はありません——むしろ一致しないほうが良いです。';

  @override
  String get arcSavedTitle => 'アーカイブを作成しました';

  @override
  String get arcSavedPath => '保存先：';

  @override
  String get arcSavedNoPath =>
      'ファイルを書き出せませんでした（ストレージにアクセスできません）が、アーカイブはコピーできる状態です。';

  @override
  String get arcSavedHint =>
      'ファイルとパスワードは別々に保管してください。パスワードがなければこのファイルは読めません——私たちにも読めません。';

  @override
  String get arcImportAction => '取り込む';

  @override
  String get arcImportNote =>
      '.dahuang ファイルを選ぶか、その内容を貼り付けてください。確認するまで何も書き込まれず、既存の記録が上書き・削除されることはありません。';

  @override
  String get arcPickFile => 'ファイルを選ぶ';

  @override
  String get arcImportCodeLabel => 'アーカイブの内容';

  @override
  String get arcImportConfirmTitle => 'このアーカイブを取り込みますか？';

  @override
  String arcImportConfirmBody(int rows, int tables, int logsize) {
    return '$tables 個のテーブルに $rows 行を書き込み、ログを最大 $logsize 件まで継続します。既存の記録は保持されます。';
  }

  @override
  String arcImportOk(int count) {
    return '取り込みが完了しました：$count 行を書き込みました。';
  }

  @override
  String get arcErrNotArchive => '有効な .dahuang アーカイブではありません。';

  @override
  String get arcLogConflictTitle => '取り込みを拒否：ログを継続できません';

  @override
  String get arcLogConflictBody =>
      'この端末の透明性ログとアーカイブのログが噛み合わないため、継続するとハッシュ連鎖が静かに壊れます。何も取り込みませんでした。ログが空の端末にアーカイブを取り込むか、サポートにご相談ください。';

  @override
  String get onbBackupTitle => 'アイデンティティをバックアップ';

  @override
  String get onbBackupSubtitle => '紙に書いた1つのコード。スマホが壊れたとき、唯一の復帰手段です。';

  @override
  String get onbBackupWhyTitle => 'なぜ重要か';

  @override
  String get onbBackupWhy =>
      'アイデンティティは自己証明型です：鍵はこのスマホにしかありません。スマホが壊れれば、そのアイデンティティと配下の全記録は永久に失われます——私たちは鍵を持っていないので、再発行できません。';

  @override
  String get onbBackupDone => 'リカバリーコードを書き留めました——戻る道ができました。';

  @override
  String get onbSkipBackup => '今はスキップ';

  @override
  String get onbSkipWarnTitle => 'バックアップなしで続けますか？';

  @override
  String get onbSkipWarnBody =>
      'リカバリーコードがない場合、このスマホを失えば、アイデンティティ・履歴・評判も永久に失われます。誰にも復元できません。後から「パスポート → アイデンティティのバックアップ」で行うこともできますが、それまでは戻る手段がありません。';

  @override
  String get onbSkipConfirm => '理解しました、続けます';

  @override
  String get onboardingStepBackup => 'バックアップ';

  @override
  String get rcTitle => '鍵のローテーション連鎖';

  @override
  String get rcIntro =>
      'この身元が新しいスマホへ移るたびに、ここに署名付きの追記専用レコードを1件残します。誰でも同じデータを取得して確認できます——アカウントは不要です。';

  @override
  String get rcFetching => '取得中…';

  @override
  String get rcRefreshAction => '更新';

  @override
  String rcFetchFail(String reason) {
    return '連鎖を取得できませんでした：$reason';
  }

  @override
  String get rcUnknownIdentity => 'Hub はこの身元を認識していません。';

  @override
  String get rcNoRotations => 'この身元は一度も鍵をローテーションしていません。';

  @override
  String get rcSubjectTitle => '身元';

  @override
  String get rcAgentLabel => 'ユーザー ID';

  @override
  String get rcDidLabel => 'DID（身元のアンカー）';

  @override
  String get rcCurrentKey => '現在有効な鍵';

  @override
  String get rcRegisteredYes => 'Hub に登録済み';

  @override
  String get rcRegisteredNo => '登録記録なし';

  @override
  String get rcLocalVerifyAction => '自分で確認する';

  @override
  String get rcVerifyingAction => '確認中…';

  @override
  String get rcVerdictOk =>
      '合格：すべてのレコードが有効な署名を持ち、連鎖が端から端までつながり、その先端が Hub の示す有効な鍵と一致します。';

  @override
  String rcVerdictSigInvalid(int n) {
    return '不合格：$n 件のレコードの署名が検証できません。';
  }

  @override
  String get rcVerdictLinkMismatch =>
      '不合格：連鎖が壊れています——あるレコードがその前のレコードから続いていません。';

  @override
  String get rcVerdictTipNotActive =>
      '不合格：最後のレコードが Hub の示す有効な鍵を指していないため、この一覧にはローテーションが欠けています。';

  @override
  String get rcVerdictTitle => '私自身の確認';

  @override
  String get rcHubClaimTitle => 'Hub の主張';

  @override
  String get rcHubClaimOk => 'Hub は壊れたリンクはないと報告しています。';

  @override
  String rcHubClaimBroken(int n) {
    return 'Hub は $n 件の身元について連鎖の破損を報告しています。';
  }

  @override
  String get rcRecordsTitle => 'レコード';

  @override
  String rcRecordSeq(int i) {
    return '#$i';
  }

  @override
  String get rcRecordFrom => '引退した鍵';

  @override
  String get rcRecordTo => '新しい鍵';

  @override
  String get rcRecordSigOk => '署名 OK';

  @override
  String get rcRecordSigBad => '署名 NG';

  @override
  String get rcAnchorTitle => '公開ログに固定';

  @override
  String rcAnchorNote(int size, String root) {
    return 'ログサイズ $size、マークルルート $root。このルートを控えておけば、後でこの一覧が書き換えられていないことを証明できます。';
  }

  @override
  String get dmTitle => '新しいスマホへ移行';

  @override
  String get dmIntro =>
      'あなたの身元は、このスマホにしかない鍵です。移行するとは、新しいスマホの新しい鍵へ身元を譲り渡すこと——古い鍵はあらゆる場所で使えなくなります。';

  @override
  String get dmRoleNewTitle => 'こちらが新しいスマホ';

  @override
  String get dmRoleNewBody => 'ここから始めます。このスマホが古いスマホに身元の引き渡しを求めます。';

  @override
  String get dmRoleNewAction => '開始';

  @override
  String get dmRoleOldTitle => 'こちらが古いスマホ';

  @override
  String get dmRoleOldBody => 'ここで待ちます。新しいスマホが要求したら、照合用のコードが表示されます。';

  @override
  String get dmRoleOldAction => '要求を待つ';

  @override
  String get dmWaitingPeer => 'もう一方の端末を待っています…';

  @override
  String get dmPeerFound => 'もう一方の端末が応答しました。';

  @override
  String get dmCompareTitle => 'このコードを見比べてください';

  @override
  String get dmCompareBody =>
      '両方の端末にまったく同じコードが表示されている必要があります。このコードは両方の鍵と要求内容を含んでいるため、途中で何かが差し替えられていればコードは一致しません。';

  @override
  String get dmCodeMatchAction => '一致する';

  @override
  String get dmCodeNoMatchAction => '一致しない';

  @override
  String get dmNoKeyLeaves =>
      '秘密鍵がどちらの端末からも外に出ることはありません。引き継ぎには旧端末自身が署名するだけで、何もコピーされません。';

  @override
  String get dmConfirmAction => '確定して移行';

  @override
  String get dmOldConfirmTitle => 'この身元を引き継がせますか？';

  @override
  String get dmOldConfirmBody =>
      'この操作で身元が新しい端末へ署名移譲されます。その後、この端末はサインアウトし、鍵は使えなくなります。';

  @override
  String get dmGapATitle => '履歴はあなたと一緒に移ります';

  @override
  String get dmGapABody =>
      'オンラインで受け取った推薦は身元に付随します。ローテーションで失効するのは鍵であって、人ではありません。新しい端末で復元すると、旧鍵の推薦は自動的に取り戻され、一つひとつ端末内で検証されます。旧鍵そのものは無効のままで、以後は何にも署名できません。';

  @override
  String get dmBackupReminderTitle => '復旧コードはお持ちですか？';

  @override
  String get dmBackupReminderBody =>
      'この移行には両方の端末が同時に使える必要があります。復旧コードを控えてあれば、旧端末がなくても復元できます。';

  @override
  String get dmPhaseOffered => '要求を受け取りました。確定をお待ちしています。';

  @override
  String get dmPhaseSigned => '署名しました。ハブへ送信中…';

  @override
  String get dmPhaseAwaitingHub => 'ハブが身元を再紐付けしています…';

  @override
  String get dmDoneNew => '完了しました。この端末が身元を保持しています。';

  @override
  String get dmDoneOld => '完了しました。この端末はサインアウトしました。';

  @override
  String get dmDoneOldHint =>
      '身元は移りましたが、この端末のチャットとデータは付いてきません（直接引き継ぎでは身元のみが移動します）。残したい場合は先にアーカイブを書き出してください。';

  @override
  String get dmCancelAction => 'キャンセル';

  @override
  String get dmCancelled => 'キャンセルしました。何も変更されていません。';

  @override
  String get dmCancelConfirmTitle => '移行を中止しますか？';

  @override
  String get dmCancelConfirmBody =>
      'まだ何も引き継がれていません。ここで中止すれば、両方の端末はそのままの状態に保たれます。';

  @override
  String get dmErrPeerMismatch => 'その要求は別の身元宛てでした。拒否しました。';

  @override
  String get dmErrBadCode => 'コードが一致しませんでした。何も引き継がれていません。';

  @override
  String dmErrHubFailed(String code) {
    return 'ハブが引き継ぎを拒否しました（$code）。何も変更されていません。';
  }

  @override
  String get dmErrTimeout => 'もう一方の端末が応答しなくなりました。何も変更されていません。';

  @override
  String dmErrGeneric(String code) {
    return '問題が発生しました（$code）。';
  }

  @override
  String get dmRetryAction => '再試行';

  @override
  String get dmRetryApplyAction => 'この端末へのインストールを完了する';

  @override
  String get dmErrSessionTimeout =>
      'この引き継ぎは長時間放置されて期限切れになりました。何も引き継がれていないので、最初からやり直せます。';

  @override
  String get dmErrApplyFailed =>
      'ハブはすでにこの端末をその身元の唯一の保持者にしましたが、この端末は新しい鍵のインストールに失敗しました。下のボタンを押して完了してください。それまではこの端末でその身元を使えません。';

  @override
  String get dmErrApplyFailedOld =>
      'サーバーはすでに身元を新しい端末へ再紐付けしましたが、新しい端末は新しい鍵のインストールに失敗しました。その端末でインストール完了ボタンを押してください。それまではこの端末でもその身元を使えません。';

  @override
  String get dmNotConfigured =>
      'ハブのアドレスが設定されていないため、身元を再紐付けできません。先にセットアップで設定してください。';

  @override
  String get dutyAskTitle => '分身を画面オフ後も当直させますか？';

  @override
  String get dutyAskBody =>
      'この2つの権限を許可すると、画面がオフでも分身が動き続けます。メッセージを取得して返信し、公開記録を同期してから休みます。当直中の通知は表示されたままになるので、いつ動いているかがわかります。スキップしても、アプリを開いている間はすべての機能を使えます。';

  @override
  String get dutyAskConfirm => '権限を許可';

  @override
  String get dutyAskLater => '今はしない';

  @override
  String get radarAskTitle => 'レーダーを有効にする前に、必要なものをご説明します';

  @override
  String get radarAskBody =>
      '物理レーダーは近接デバイス（Bluetooth / Wi-Fi Direct）を使って、同じ Wi-Fi 上の相手を見つけます。Android では Bluetooth のスキャンが「位置情報」権限に分類されるため、システムのダイアログでも位置情報を求められます。これは OS のルールであり、このアプリが位置情報を欲しがっているわけではありません。\n\nこのアプリは位置情報を読み取り・保存・送信することは一切なく、近接デバイス権限は neverForLocation 付きで宣言されています（OS が Bluetooth からの位置推定をブロックします）。\n\n続いてシステムの権限ダイアログが表示されます。拒否してもアプリの他の動作は変わりません。レーダーが誰も見つけられなくなるだけです。';

  @override
  String get dutyDoneToast => '当直の権限を許可しました。これで画面オフでも分身が働けます。';

  @override
  String get dutyPartialToast =>
      '一部の権限が許可されませんでした。アプリを開いている間は分身は動きますが、バックグラウンドではシステムに一時停止させられる場合があります。';

  @override
  String get romGuideTitle => '画面ロック後も分身がシステムに止められないようにする';

  @override
  String get romGuideGo => '設定を開く';

  @override
  String get romGuideDismiss => '今後は表示しない';

  @override
  String get romStepsXiaomi =>
      'Xiaomi/Redmi（MIUI/HyperOS）の場合：1）設定 → アプリ → アプリを管理 → 大荒AI → 「自動起動」を有効にする。2）セキュリティアプリ → バッテリー → 大荒AI → 「制限なし」。これらを設定しないと、画面ロック後数分でシステムが分身を終了させます。';

  @override
  String get romStepsHuawei =>
      'Huawei（EMUI/HarmonyOS）の場合：設定 → アプリ → アプリ起動管理 → 大荒AI → 「自動管理」をオフにし、自動起動・関連起動・バックグラウンド実行の3つをすべて有効にします。';

  @override
  String get romStepsHonor =>
      'Honor（MagicOS）の場合：設定 → アプリ → アプリ起動管理 → 大荒AI → 「自動管理」をオフにし、自動起動・関連起動・バックグラウンド実行を有効にします。';

  @override
  String get romStepsOppo =>
      'OPPO/realme（ColorOS）の場合：設定 → アプリ → アプリ管理 → 大荒AI → 自動起動を許可。設定 → バッテリー → 詳細設定 → 大荒AI のバックグラウンド動作を全面的に許可します。';

  @override
  String get romStepsOneplus =>
      'OnePlus の場合：設定 → アプリ → 自動起動 → 大荒AI を許可。バッテリー → 大荒AI のバッテリー使用を最適化 → 「最適化しない」に設定します。';

  @override
  String get romStepsVivo =>
      'vivo/iQOO（OriginOS）の場合：設定 → アプリ → 権限管理 → 自動起動で大荒AI を許可。設定 → バッテリー → バックグラウンド消費電力 → 大荒AI のバックグラウンド高消費を許可します。';

  @override
  String get romStepsMeizu =>
      'Meizu（Flyme）の場合：電話マネージャー → アプリ権限 → バックグラウンド管理 → 大荒AI の実行継続を許可します。';

  @override
  String get romStepsSamsung =>
      'Samsung（One UI）の場合：設定 → バッテリー → バックグラウンド使用の制限 → 「スリープ状態のアプリ」から大荒AI を外します。';

  @override
  String get romStepsGeneric =>
      'お使いのシステムがバックグラウンドアプリを強制終了する場合は、システム設定で大荒AI の自動起動を許可し、バッテリー最適化の対象から除外してください。';

  @override
  String get helpDotTooltip => '使い方を見る';

  @override
  String get helpSheetClose => 'わかりました';

  @override
  String get helpWorldOverviewTitle => 'ラウンジの仕組み';

  @override
  String get helpWorldOverviewBody =>
      '公式ルームは誰でも入れます。個人ルームはオーナーとメンバーにしか見えません。他の人は正確なルーム番号を入力し、申請し、オーナーの承認を得る必要があります。ルーム内では各メッセージはルーム固有のペース（既定 8 秒）で送信され、このペースに達するとサーバーが拒否し、少し待つよう促します。';

  @override
  String get helpWorldMetricTitle => '一人あたりのサークル横断リンク数';

  @override
  String get helpWorldMetricBody =>
      'ローカル範囲：分子＝自分のサークル横断エッジ数、分母＝出会った異なる分身の数。プラットフォーム全体の一人あたりの数値にはサーバー側の集計が必要ですが、サーバーはサークル関係を意図的に保持していません。';

  @override
  String get helpWorldBridgeTitle => 'フレンドプールからの紹介';

  @override
  String get helpWorldBridgeBody =>
      'ルームで出会った外部の相手はワンタップで紹介できます。サークル横断エッジはルームからしか生まれません。ルームがなければエッジもありません。';

  @override
  String get helpWorldRoomRoleTitle => 'ルームの役割';

  @override
  String get helpWorldRoomRoleBody =>
      '役割はルームに属し、あなたの身元を変えることはありません。同じあなたでも、ルームごとに異なる役割を持てます。';

  @override
  String get helpIntercardDisclosureTitle => 'カードが開示するもの';

  @override
  String get helpIntercardDisclosureBody =>
      'カードに載るのはレベル2の項目だけで、あなた自身しか見られない項目は載りません。カードの内容は誰でも再計算して確かめられます。';

  @override
  String get helpPassportOverviewTitle => 'パスポートとは何か';

  @override
  String get helpPassportOverviewBody =>
      'パスポートはアカウントではなく公開鍵です。オフラインで検証でき、どのサーバーにもログインしません。新しい端末への移行は復旧コードか鍵ローテーションに頼るもので、プラットフォームのサポート窓口には決して頼りません。';

  @override
  String get helpPassportOfflineTitle => 'オフラインで検証可能';

  @override
  String get helpPassportOfflineBody =>
      '公開鍵がすなわち身元です。このパスポートはサーバーへの照会なしにオフラインで検証できます。';

  @override
  String get helpPassportFunnelTitle => 'ファネルの分母の仕組み';

  @override
  String get helpPassportFunnelBody =>
      '分母は確定した記録だけを数え、進行中は失敗ではありません。双方の同意が実際に検証できた記録だけが分母に入ります。';

  @override
  String get helpPassportReputationTitle => 'なぜグローバルスコアが存在しないのか';

  @override
  String get helpPassportReputationBody =>
      'グローバルな評判スコアは容易に偽装できるため、存在しません。あなたが見るものは常に「あなた自身のアンカー」を基準にしています。他者が署名した推薦を、距離で減衰させたものです。\\n\\n軽い知り合いは信頼伝播の出発点にはなりません。そうでなければ、やたらに友達を増やすだけで到達範囲を水増しできてしまいます。\\n\\n照会で何も見つからないときは「不明」と表示され、それはスコア0ではありません。本当に不明という意味であり、それを数値に変える人は推測しているだけです。';

  @override
  String get helpPassportLogTitle => '透明性ログ';

  @override
  String get helpPassportLogBody =>
      '私を信じる必要はありません。検証すればよいのです。誰でもログをダウンロードし、ルートを再計算して、自分の記録が改ざんされていないかを確認できます。';

  @override
  String get helpSocialOverviewTitle => 'ソーシャルタブの役割';

  @override
  String get helpSocialOverviewBody =>
      '上部に名簿と友達、下部にレーダーの状態とソーシャル台帳があります。レーダーはメッセージをそもそも外に出すかどうかを決めます。オフのときは送信を押してもこの端末から何も出ません。';

  @override
  String get helpSocialPersonaTierTitle => '専門ペルソナモード';

  @override
  String get helpSocialPersonaTierBody =>
      '鍵アイコンは専門ペルソナモードを示します。課金はまだ稼働していないため、現在はすべてのモードを自由に切り替えられます。';

  @override
  String get helpSocialRadarTitle => 'レーダーとチャネル';

  @override
  String get helpSocialRadarBody =>
      'レーダーがオフでも名簿は閲覧できますが、この端末から何も出ません。送信は黙って破棄されます。レーダーをオンにし、少なくとも1つのチャネル（近接／LAN／クラウド）を有効にしてください。\\n\\n検証可能で固定された身元が現れるのは、双方がレーダーを有効にし、1回の近接ハンドシェイクを完了した後だけです。';

  @override
  String get helpSocialChannelGuideTitle => 'チャネルとネットワークのトラブルシューティング';

  @override
  String get helpSocialChannelGuideBody =>
      '1. 物理レーダーがオンのときは、現在のネットワークがインターネットに到達できることを確認してください。\n2. 近接チャネルがオンのときは、システムが Wi-Fi を自動でオンにすることがあります。これは正常なトランスポートの昇格です（Bluetooth が発見し、Wi-Fi Direct がデータを運びます。ネットワークには接続しません）。近接チャネルをオフにすると止まります。\n3. 外出時に電池を節約するには：クラウドチャネルだけを使い、Wi-Fi を手動でオフにします（近接がオンのままだとシステムが Wi-Fi を再有効化します。想定内なので、抵抗し続ける必要はありません）。';

  @override
  String get socialRadarOffHint =>
      'レーダーはオフです。名簿は閲覧できますが、この端末から何も出ません。送信は黙って破棄されます。送信する前にレーダーをオンにし、少なくとも1つのチャネル（近接／LAN／クラウド）を有効にしてください。';

  @override
  String get worldRoomCloseAction => 'ルームを閉じる';

  @override
  String get worldRoomCloseTitle => 'このルームを閉じますか？';

  @override
  String get worldRoomCloseBody =>
      '閉じると、ルームは公開リストから外れ、新しいメッセージを受け付けなくなります。既存のチャットは読み取り専用のアーカイブとして保持され、現在のメンバーは引き続き閲覧できます。';

  @override
  String get worldRoomCloseConfirm => 'ルームを閉じる';

  @override
  String worldRoomClosedOk(String name) {
    return '$name を閉じました — 読み取り専用のアーカイブ';
  }

  @override
  String worldRoomCloseFailed(String err) {
    return '閉じるのに失敗しました：$err';
  }

  @override
  String get worldRoomClosedBadge => '閉鎖済み';

  @override
  String get worldRoomClosedReadonlyHint =>
      'ルームは閉鎖済み — 読み取り専用のアーカイブ、新しいメッセージは不可';

  @override
  String get worldRoomClosedSendRejected => 'このルームは閉鎖されているため、メッセージを送信できません';

  @override
  String get worldRoomClosedSystemMsg => 'オーナーがこのルームを閉じました。現在は読み取り専用のアーカイブです。';

  @override
  String get settingsLocalModelSection => 'ローカルモデルへのフォールバック（オフライン縮退）';

  @override
  String get settingsLocalModelTest => 'ローカルモデル接続をテスト';

  @override
  String get settingsLocalModelTesting => 'テスト中…';

  @override
  String settingsLocalModelTestOk(String model, String url) {
    return '✅ 接続成功：$model @ $url';
  }

  @override
  String get settingsLocalModelTestDisabled =>
      'ローカルフォールバックはオフです（URL が空）。利用したい場合は URL を入力して再テストしてください。';

  @override
  String settingsLocalModelTestUnreachable(String url) {
    return '❌ $url に到達できません：そこでは何も待ち受けていません（またはポートが閉じています）。スマホでは 127.0.0.1 はスマホ自身を指し、モデルサーバーは通常パソコン上で動きます。アドレスを確認して再試行してください。';
  }

  @override
  String get settingsLocalModelTestNotJson =>
      '❌ 何かが応答しましたが、モデル API の JSON を返しませんでした（プロキシかエラーページの可能性が高い）。アドレス／ポートが Ollama / llama.cpp の REST エンドポイントを指していることを確認してください。';

  @override
  String get settingsLocalModelTestNoMessage =>
      '❌ エンドポイントは応答しましたが、返信の内容を読み取れませんでした（よくある原因：モデル名が存在しない、または /api/chat 形式の応答ではない）。';

  @override
  String settingsLocalModelTestHttp(String code) {
    return '❌ サービスがステータス $code を返しました（200 ではありません）。';
  }

  @override
  String get helpSettingsLocalModelTitle => 'ローカルモデルへのフォールバック：本当に動くのはどんなとき？';

  @override
  String get helpSettingsLocalModelBody =>
      'ここに入れるアドレスは、アプリに使わせるものをあなたが指定するだけです。「入力済み」は「動作する」を意味しません。スマホでは 127.0.0.1 はスマホ自身を指しますが、モデルサーバー（Ollama / llama.cpp）は通常パソコン上で動くため、この既定値はスマホからは通常到達できません。本来の用途は：(1) 自分のパソコンでモデルを動かす場合は、そのパソコンの LAN アドレスを入力する。(2) 将来のビルドでオンデバイスのエンジンが同梱されたら、新しいポートを指定する。\n\nアドレスを空にする＝ローカルフォールバックを明示的に無効化する（アプリはローカルモデルを試さなくなります）。\n\n実際に動くかどうかを知るには、欄が埋まっているかどうかに頼らず、下の「ローカルモデル接続をテスト」を押してください。最小限のライブリクエストを1回送り、結果をその行に表示します。';

  @override
  String get glossaryTitle => '用語集';

  @override
  String get glossaryIntro => 'アプリで繰り返し出てくる言葉を、ここで一度だけ説明します。用語をタップすると展開します。';

  @override
  String get glossaryGroupIdentity => '身元と端末';

  @override
  String get glossaryGroupSocial => 'ソーシャルと発見';

  @override
  String get glossaryGroupWorld => 'ワールドとラウンジ';

  @override
  String get glossaryGroupTrust => '信頼と記憶';

  @override
  String get glossaryAgentTitle => 'エージェント（分身）';

  @override
  String get glossaryAgentBody =>
      'スマホの中に住む分身です。あなたが入力したモデルキーで考え、まず自分から人に会いに行きます。あなたが不在のときは、許可したことだけを行います。';

  @override
  String get glossaryMaskTitle => '外交の仮面';

  @override
  String get glossaryMaskBody => '外部に見せる顔：あなたのペルソナと話し方です。他人があなたを最初にどう見るかを決めます。';

  @override
  String get glossaryPassportTitle => '大荒パスポート';

  @override
  String get glossaryPassportBody =>
      'オフラインで検証できる、署名済みの検証可能な履歴書です。相手はどのサーバーも信頼する必要がなく、署名を検証するだけです。';

  @override
  String get glossaryMigrationTitle => '機種変更（身元の復元）';

  @override
  String get glossaryMigrationBody =>
      '身元を「証明付きで」新しい端末へ移すことで、その後は旧端末の身元は本当に使えなくなります。秘密鍵のコピーではなく、証明に裏打ちされた鍵ローテーションなので、旧端末は本当に無効化されます。';

  @override
  String get glossaryRadarTitle => 'レーダー';

  @override
  String get glossaryRadarBody =>
      '近接デバイス（Bluetooth / Wi-Fi Direct）を使って同じ Wi-Fi 上の相手を発見します。位置情報は一切読み取り・保存・送信しません。Android は Bluetooth スキャンを「位置情報」に分類しており、これは OS のルールです。';

  @override
  String get glossaryRosterTitle => '捕獲名簿';

  @override
  String get glossaryRosterBody =>
      'レーダーが拾った人や、ルームで出会った人から作られる名簿です。その後のあらゆるソーシャル関係の出発点になります。';

  @override
  String get glossaryIntercardTitle => '分身の相互紹介（サークル横断エッジ）';

  @override
  String get glossaryIntercardBody =>
      '双方が確認して初めて成立する、2つの分身の間の正式な紹介です。サークル横断エッジは実際に共有したルームからしか生まれず、ID を知っていると主張することからは決して生まれません。';

  @override
  String get glossaryWorldTitle => 'ワールド / ラウンジ';

  @override
  String get glossaryWorldBody =>
      '「ワールド」はクラウドの公共空間で、「ラウンジ」はその中のルームです。QQ グループによく似ており、公式のものは誰でも入れ、個人のものはルーム番号と承認が必要です。他の人が話している間、あなたの分身は既定では観察するだけで、割り込みません。';

  @override
  String get glossaryRoomRoleTitle => 'ルームの役割';

  @override
  String get glossaryRoomRoleBody =>
      'ホスト／共同ホスト／ゲスト／機能役割／参加者。役割はルームに属し、あなたの身元を変えません。同じあなたでも、ルームごとに異なる役割を持てます。';

  @override
  String get glossaryAutopilotTitle => 'オートパイロット';

  @override
  String get glossaryAutopilotBody =>
      '画面を見ていない間、あなたの分身が時間あたりの予算の範囲でルーム内で自分から発言できるようにします。既定ではオフで、いつでもオフにできます。';

  @override
  String get glossaryRepNetTitle => 'ネットワーク推薦';

  @override
  String get glossaryRepNetBody =>
      'あなたと友達が層ごとに署名する評判で、自分で検証できます。経路が見つからないときは「0」ではなく「不明」と表示されます。それを確定した数値に変える人は推測しているだけです。';

  @override
  String get glossaryMemoryTitle => '記憶の蒸留';

  @override
  String get glossaryMemoryBody =>
      '夜になると会話を長期記憶へと蒸留し、話し方を微調整します。管理ページで手動で1回実行することもできます。';

  @override
  String get glossaryProfileTitle => '長期プロフィール';

  @override
  String get glossaryProfileBody =>
      '長く付き合ううちに分身があなたについて蓄える理解のこと：繰り返し関心を持つテーマと、よく活動する時間帯です。端末内のイベント情報（メタデータ）だけから算出します —— 会話の本文は読みませんし、外部へ送信することもありません。「設定 → 記憶」で単独でオフにできます。マスタースイッチの「自動リコール」をオフにすると、こちらも一緒に止まります。';

  @override
  String get glossarySerendipityTitle => '幸運の実験ラボ';

  @override
  String get glossarySerendipityBody =>
      '「幸運」を訓練の主題として扱う一連の小さな演習です。朝の予行、サークル突破の課題、挫折の捉え直し、きらめきメモ、日記、占い。完了すると Lp（幸運エネルギー）が貯まります。';

  @override
  String get helpSkillMarketTitle => 'スキルマーケット：これらの用語は何を意味する？';

  @override
  String get helpSkillMarketBody =>
      '公開＝自分が書いたスキルをマーケットに出し、他の人の分身が使えるようにすることです。公開時にはこの端末の身元秘密鍵で署名します。鍵は端末から外に出ず、フォームには公開鍵や署名を貼り付ける欄がないため、偽造は UI 上そもそも表現できません。\n\nリスク階層（低／中／高）＝このスキルがどれだけ機微かをあなた自身が開示するものです（オンラインに行くか、他のアプリを起動するか…）。階層が高いほど、呼び出し側は初回利用時により多くを許可する必要があります。\n\n機能宣言＝そのスキルが使う機能の正確な一覧です。リスク階層と合わせて、呼び出し側が許可するかどうかを判断するときに見る情報のすべてです。\n\n作者分配＝他の人があなたのスキルを使った収益はあなたに計上されます。この画面はあなたの公開鍵で署名された出品だけを集計し、合計は台帳と項目ごとに突合できます。\n\n署名済み出品＝すべてのスキルに署名が付いているので、誰もサーバーを信頼する必要はありません。「署名を検証」をタップして自分で確認してください。';

  @override
  String get helpSettingsRecallTitle => '自動リコール';

  @override
  String get helpSettingsRecallBody =>
      'オンにすると、返信のたびに関連しそうな過去の出来事をローカル記憶から検索し、文脈として分身に渡します。オフにすると計算量と文脈を少し節約できます。';

  @override
  String get helpIdentityRestoreTitle => '新しい端末での復元';

  @override
  String get helpIdentityRestoreBody =>
      '新しい端末では、ここに3つ入力します：復旧コード＋パスフレーズ＋あなたのユーザー ID。復元が成功した瞬間、旧端末は使えなくなります。\n\nこれは証明済みの鍵ローテーション（ROTATE）であり、秘密鍵をコピーするものではありません。そのため身元番号は同じままですが、旧端末は無効になります。';

  @override
  String get helpIdentityArchiveTitle => '身元アーカイブ（.dahuang ファイル）';

  @override
  String get helpIdentityArchiveBody =>
      'このアーカイブは、あなたの身元記録・ソーシャルグラフ・ログのアンカーを、パスフレーズでひとつの .dahuang ファイルに封じます。当社のサーバーを一切経由しないので、ご自身のクラウドドライブや USB メモリに保管してください。含まれるのはデータだけで、身元の秘密鍵は決して含みません。\n\nできれば復旧コードとは別のパスフレーズを使ってください。ファイルとパスフレーズは別々に保管を。パスフレーズなしでは誰もファイルを開けません（当社でも開けません）。\n\nインポート時は、確定するまで何も書き込まれません。インポートは記録を追加するだけで、既存のものを上書き・削除することはありません。';

  @override
  String get helpIdentityCodeTitle => '復旧コードのコピー';

  @override
  String get helpIdentityCodeBody =>
      '長押しで全選択してコピー。手書きで控える場合は、一つひとつの区切りを確認してください。';

  @override
  String get helpDeviceMigrationTitle => '端末間の移行';

  @override
  String get helpDeviceMigrationBody =>
      '両方の端末を同じ Wi-Fi につなぎ、このページを開いておく必要があります。\n\n移るのは身元です。その後、この端末がサーバーアドレスを必要とする場合は設定を確認してください。ハブとワールドのアドレスは変わりません。\n\nこの端末にすでにあるチャット履歴とデータは移りません（直接移行では身元だけが移動し、データは移動しません）。';

  @override
  String get helpRotationChainAuthorityTitle => 'どの判定が有効か';

  @override
  String get helpRotationChainAuthorityBody =>
      'ハブの列は比較用にすぎません。上の判定はこの端末で、あなたが実際に保持している記録から計算されます。\n\n言い換えれば、ハブが別のことを言ってもサーバーを信頼する必要はありません。ローカルで計算された判定が有効です。';

  @override
  String get helpToolBusTitle => 'ツールバス';

  @override
  String get helpToolBusBody =>
      'すべてのツール／スキルは端末署名と機能宣言を持ち、中・高リスクの機能は初回利用時に許可が必要です。\n\n改ざんされたプラグインは決して読み込まれません。チェックに失敗すれば、単にバスに接続されません。';

  @override
  String get onbFreeTrialBtn => '無料で始める・キー不要（20ターン）';

  @override
  String get onbOwnKeyBtn => '自分の API キーがある';

  @override
  String get onboardingTrialService => '無料体験（公式リレー）';

  @override
  String get onboardingTrialModelName => '体験モデル（キー不要）';

  @override
  String get onboardingTrialNoticeTitle => 'これは無料体験です';

  @override
  String onboardingTrialNoticeBody(String hub) {
    return '自分の API キーは不要で、会話は公式サーバー経由でモデルに中継され、最大 20 ターンまで利用できます。終了後は「管理設定」で自分の API キーを入力できます（リレー: $hub）。';
  }

  @override
  String onboardingOwnReady(String model) {
    return '$model の設定が完了しました。さあ、会話を始めましょう。';
  }

  @override
  String trialRemainingTurns(int n) {
    return '残り無料ターン $n';
  }

  @override
  String get trialExhaustedReply =>
      'あなたの分身はもっと話したがっています。公式おすすめのモデルプラットフォームに登録し（新規アカウントには無料のトークン枠が付きます）、設定でキーを貼り付ければ、会話は無制限に続きます。';

  @override
  String get trialGoSettings => '設定を開く';

  @override
  String get trialNotConfiguredReply =>
      '公式の無料お試し枠はまだ開放されていません。設定でご自身のモデルキーを入力すると、制限なく会話を続けられます。';

  @override
  String get trialInputUnsupportedReply =>
      '無料お試しでは画像・音声の入力にまだ対応していません。文字でお送りください（設定でご自身のキーを入力すると全機能が使えます）。';

  @override
  String get trialRateLimitedReply => 'お試しのリクエストが集中しています。少し待ってからもう一度お送りください。';

  @override
  String get trialPoolBusyReply =>
      'お試し用アカウントが現在すべて混み合っています。しばらくしてから再度お試しください。設定でご自身のキーを入力することもできます。';

  @override
  String get trialUnavailableReply =>
      '無料お試しは一時的にご利用いただけません。しばらくして再試行するか、設定でご自身のキーを入力してください。';

  @override
  String settingsTrialSwitchedToOwn(String baseUrl) {
    return '✅ ご自身のキーを入力しました —— 無料お試しからご自身のモデルに切り替えました。エンドポイントは $baseUrl に変更されました。';
  }

  @override
  String get trialManagedTitle => '無料お試し · 公式による代理管理';

  @override
  String get trialManagedNotice =>
      'お試し期間中、以下のエンドポイントとキーは公式の代理接続によって管理されており、通常は変更不要です。ご自身のモデルを使うには：ご自身の API キーを入力して保存すると、アプリは自動的にお試しを終了し、エンドポイントも修正します。誤って壊してしまった場合は、「無料お試しを復元」をタップすればワンタップで元に戻せます。';

  @override
  String get trialRestoreAction => '無料お試しを復元';

  @override
  String get trialRestoreConfirm =>
      '公式のお試しエンドポイントと本機の身分を書き戻し、アプリを無料お試しモードに切り替えます。続行しますか？';

  @override
  String get trialRestoreDone => '✅ 無料お試しを復元しました。';

  @override
  String get socialTabLogs => 'ログ';

  @override
  String get modePickerTooltip => 'モード';

  @override
  String get modeBeginnerTitle => 'かんたんモード';

  @override
  String get modeAdvancedTitle => '詳細モード';

  @override
  String get settingsAdvancedTitle => '詳細設定';

  @override
  String get settingsAdvancedSubtitle => 'エンジン・記憶・魂づくりの設定';

  @override
  String get settingsModeHint => 'モードは上部ツールバーで切り替えます';

  @override
  String get langPickerTooltip => '言語';

  @override
  String get langFollowSystem => 'システムに従う';

  @override
  String get langFollowSystemHint => '（端末）';

  @override
  String get onboardingStepLanguage => '言語';

  @override
  String get onbLangTitle => '言語を選ぶ';

  @override
  String get onbLangSubtitle => '分身は、ここで選んだ言語で返答します。';

  @override
  String get onbLangChangeableHint => '後からでも変更できます：チャット画面上部の言語ボタンから。';

  @override
  String get bigInputWarnTitle => '入力が10,000文字を超えています';

  @override
  String get bigInputWarnBody => '長い入力はトークンを大きく消費します。送信しますか？';

  @override
  String get bigInputConfirm => '送信する';

  @override
  String trialInputTooLong(int n) {
    return 'トライアル入力は$n文字までです。この回は送信されませんでした。';
  }

  @override
  String get memoryManagerTitle => '記憶とリマインダー';

  @override
  String get memoryManagerIntro =>
      'エージェントがあなたについて覚えている内容の一覧です。いつでも確認でき、覚えていてほしくないものは削除できます。削除は元に戻せません。';

  @override
  String get reminderSectionTitle => 'リマインダーとToDo';

  @override
  String get reminderEmpty => 'まだありません。チャットで「明日の朝8時にリマインドして」と言うか、下のボタンで追加できます。';

  @override
  String get reminderAdd => 'リマインダーを追加';

  @override
  String get reminderTitleHint => '例：家賃を払う';

  @override
  String get reminderOptionalTime => '時刻（任意）';

  @override
  String get reminderNoRepeat => '繰り返しなし';

  @override
  String get reminderRepeatDaily => '毎日';

  @override
  String get reminderRepeatWeekly => '毎週';

  @override
  String get reminderTodoTag => 'ToDo（時刻なし）';

  @override
  String get memorySectionTitle => 'エピソード記憶';

  @override
  String get memoryEmpty => 'エージェントはまだ何も記録していません。';

  @override
  String get memoryDeleteConfirm => 'この記憶を削除しますか？関連するチャットの本文も削除され、元に戻せません。';

  @override
  String get sessionSectionTitle => '会話の履歴';

  @override
  String get sessionEmpty => '会話の履歴はありません。';

  @override
  String get sessionForget => '忘れる';

  @override
  String get sessionForgetConfirm =>
      'この会話全体を忘れさせますか？エージェントは今後これを思い出さず、プロフィールにも反映せず、モデルにも渡しません。元に戻せません。';

  @override
  String sessionEventsCount(Object count) {
    return '$count 件のイベント';
  }

  @override
  String get settingsMemoryManager => 'リマインダーと記憶を管理';

  @override
  String get notifyReminderTitle => 'リマインダー';

  @override
  String notifyReminderBody(Object title) {
    return '時間です：$title';
  }

  @override
  String morningHiReminders(Object count) {
    return '今日のリマインダー/ToDo：$count件';
  }

  @override
  String get settingsSearchTitle => '検索サービス（任意）';

  @override
  String get settingsSearchHint =>
      '自分の検索キーを設定すると、web_search_pro が複数の検索ソースを集約し、より充実した結果を返します。設定しなくても基本モード（Wikipedia + Jina）で利用可能です。キーは選択した検索プロバイダーにのみ送信され、当社を経由しません。';

  @override
  String get settingsSearchProvider => '検索プロバイダー';

  @override
  String get settingsSearchBasicMode => '基本モード（キーなし）';

  @override
  String get settingsSearchApiKey => '検索 API キー';

  @override
  String get settingsSearchSearxngUrl => 'SearXNG のURL';

  @override
  String get settingsSearchSearxngUrlHint =>
      '自己ホストの SearXNG インスタンスのURL（例：https://search.example.com）';

  @override
  String get chatVoiceInputTitle => '音声入力（文字変換）';

  @override
  String get chatVoiceListening => '聞き取っています……どうぞ';

  @override
  String get chatVoiceNoRecognizer =>
      'この端末には音声認識サービスがありません（Google などの音声サービスを導入するか、キーボードで入力してください）。';

  @override
  String chatVoiceFailed(Object err) {
    return '音声認識に失敗：$err';
  }

  @override
  String get settingsTtsEnabled => '返信を読み上げる';

  @override
  String get settingsTtsHint =>
      'オンにすると、端末の音声エンジンが返信を読み上げます（既定はオフ）。読み上げ中は停止ボタンで中断できます。音声は端末内で合成され、当社を経由しません。';

  @override
  String get settingsTtsStop => '読み上げを停止';

  @override
  String get chatAttachOptionsTitle => '画像やドキュメントを追加';

  @override
  String get chatPickDocument => 'ドキュメント（PDF / Word / Excel / テキスト）';

  @override
  String get chatDocParsing => '端末内でドキュメントを解析中…';

  @override
  String chatDocParsed(Object chars) {
    return '$chars 文字を解析しました（端末内で処理、アップロードなし）';
  }

  @override
  String chatDocParsedTruncated(Object chars) {
    return 'ドキュメントが大きいため先頭 $chars 文字のみ送信します（端末内で処理、アップロードなし）';
  }

  @override
  String chatDocParseFailed(Object err) {
    return 'ドキュメントの解析に失敗：$err';
  }

  @override
  String get settingsCalendarTitle => 'システムカレンダー（読み取り専用）';

  @override
  String get settingsCalendarHint =>
      '許可すると、朝のあいさつに「今日の予定」が付き、エージェントが予定を確認できるようになります。読み取りのみで、カレンダーは一切変更しません。';

  @override
  String get settingsCalendarGrant => '読み取りを許可';

  @override
  String get settingsCalendarGranted => '許可済み';

  @override
  String get settingsCalendarDenied => '未許可';

  @override
  String get settingsCalendarUnsupported => 'このバージョンでは未対応';

  @override
  String get calendarPermissionNeeded => 'カレンダーの読み取り権限が必要です';

  @override
  String get calendarAllDay => '終日';

  @override
  String morningHiCalendar(String items) {
    return '今日の予定：$items';
  }

  @override
  String get settingsWeeklyReportTitle => 'エージェント週報';

  @override
  String get settingsWeeklyReportHint =>
      '今週エージェントがあなたのために行ったことを確認できます（端末内のみの統計。データは外部に送信されません）。';

  @override
  String get weeklyReportTitle => 'エージェント週報';

  @override
  String get weeklyReportSubtitle =>
      '過去 7 日間にエージェントが代行した操作の統計（端末内のみの統計。データは外部に送信されません）。';

  @override
  String weeklyReportRange(String start, String end) {
    return '$start 〜 $end';
  }

  @override
  String weeklyReportTotal(int count) {
    return '計 $count 件の操作';
  }

  @override
  String weeklyReportActiveDays(int days) {
    return '$days 日間アクティブ';
  }

  @override
  String get weeklyReportCatTools => 'ツールと設定';

  @override
  String get weeklyReportCatDevice => 'スマホ操作';

  @override
  String get weeklyReportCatSocial => 'ソーシャル操作';

  @override
  String get weeklyReportCatSuggestion => '自発的な提案';

  @override
  String get weeklyReportCatReview => '審査とブロック';

  @override
  String get weeklyReportCatOther => 'その他';

  @override
  String get weeklyReportEmpty =>
      '今週はまだ操作の記録がありません。委託・交流・スマホ操作をエージェントに任せると、その一歩一歩がここにまとまります。';

  @override
  String morningHiWeekly(int count) {
    return '今週は合計 $count 件の操作';
  }

  @override
  String get capNotification => '通知とSMSの読み取り';

  @override
  String get settingsNotifySmsTitle => '🔔 通知とSMS（読み取り専用）';

  @override
  String get settingsNotifySmsSubtitle =>
      '必要なときにのみ分身が通知とSMSを読み取ります。読み取り専用・既定はオフ・サイドロード版のみ。';

  @override
  String get notifySmsScreenTitle => '通知とSMS（読み取り専用）';

  @override
  String get notifySmsRefreshStatus => '状態を更新';

  @override
  String get notifySmsUnsupported => 'このビルドは通知・SMSの読み取りに対応していません';

  @override
  String get notifySmsListenerConnected => '通知へのアクセスは接続済みです';

  @override
  String get notifySmsListenerCheckedNotConnected =>
      'システム設定では有効ですが、サービスはまだ接続されていません';

  @override
  String get notifySmsListenerOff => '通知へのアクセスが有効になっていません';

  @override
  String get notifySmsStatusUnknown => '状態不明';

  @override
  String get notifySmsGoSettings => 'システム設定を開く';

  @override
  String get notifySmsGoSystemHint => '「通知へのアクセス」で本アプリを有効にし、戻って更新をタップしてください';

  @override
  String get notifySmsRedetect => '再検出';

  @override
  String get notifySmsRedetectTip =>
      'まだ接続されない場合は、システム設定「通知へのアクセス」で本アプリを一度オフにしてからオンにし直すか、アプリを再起動してください。';

  @override
  String get notifySmsAllowTitle => '通知とSMSの読み取りを許可';

  @override
  String get notifySmsAllowSubReady => '準備完了 —— 必要なときにだけ読み取ります';

  @override
  String get notifySmsAllowSubNeedService => '先にシステム設定で「通知へのアクセス」を有効にしてください';

  @override
  String get notifySmsToastOn => '通知とSMSの読み取りを有効にしました';

  @override
  String get notifySmsToastOff => '通知とSMSの読み取りを無効にしました';

  @override
  String get notifySmsToastNeedService => '先にシステム設定「通知へのアクセス」で本アプリを有効にしてください';

  @override
  String get notifySmsSmsCardTitle => 'SMS読み取り権限';

  @override
  String get notifySmsSmsGranted => 'SMS読み取り権限は許可済みです';

  @override
  String get notifySmsSmsNotGranted => 'SMS読み取り権限は未許可です';

  @override
  String get notifySmsRequestSms => 'SMS読み取り権限を許可';

  @override
  String get notifySmsSmsUnavailable => 'このビルドにはSMS読み取り機能が含まれていません';

  @override
  String get notifySmsToolsHeader => '有効にすると使えるツール';

  @override
  String get notifySmsToolNotifyList => '最近の通知を読む';

  @override
  String get notifySmsToolSmsList => '最近のSMSを読む';

  @override
  String get notifySmsToolSmsSearch => 'キーワードでSMSを検索';

  @override
  String get notifySmsToolStatus => '権限の状態を確認';

  @override
  String get notifySmsFooter =>
      '読み取り専用・完全ローカル：通知はメモリ上にのみ保持され（データベースには一切書き込みません）、SMSは必要なときだけ照会し、内容がサーバーへ送信されることはありません。本文はマスク処理後にのみモデルに渡され、呼び出しはすべて記録されます。通知へのアクセスはシステム設定でいつでも取り消せます。';

  @override
  String get notifySmsStatusUnsupportedFull =>
      'このビルドには通知/SMSの読み取り機能が含まれていません（サイドロード版のみ）';

  @override
  String get notifySmsStatusReady => '通知とSMSの読み取りは準備完了です';

  @override
  String get notifySmsStatusPartial =>
      '一部のみ準備完了：通知へのアクセス / SMS権限がまだすべて有効ではありません';

  @override
  String get notifySmsStatusOff => '通知へのアクセスもSMS権限も有効になっていません';

  @override
  String notifySmsStatusQueryFailed(String err) {
    return '状態の取得に失敗しました：$err';
  }

  @override
  String get settingsDiagnosticsTitle => '🩺 システム診断';

  @override
  String get settingsDiagnosticsSubtitle =>
      '実機確認用の読み取り専用の事実：データベース、全文検索、記憶、ナレッジベース。';

  @override
  String get diagnosticsTitle => 'システム診断';

  @override
  String get diagnosticsIntro =>
      'この端末の基盤レイヤーの事実を確認します — データベース、全文検索、記憶、ナレッジベース。読み取り専用で、通信は行いません。実行後に「結果をコピー」するか、スクリーンショットを送ってください。';

  @override
  String get diagnosticsRun => '再実行';

  @override
  String get diagnosticsRunning => '実行中…';

  @override
  String get diagnosticsCopy => '結果をコピー';

  @override
  String get diagnosticsCopied => '結果をコピーしました';

  @override
  String get diagStatusOk => '正常';

  @override
  String get diagStatusWarn => '注意';

  @override
  String get diagStatusFail => '失敗';

  @override
  String get diagStatusInfo => '情報';

  @override
  String get diagProbeSchema => 'データベースのスキーマ';

  @override
  String get diagProbeFts => '全文検索（FTS5）';

  @override
  String get diagProbeMemoryRows => '記憶の件数';

  @override
  String get diagProbeMemoryRecall => '記憶の呼び出し';

  @override
  String get diagProbeMemoryAddress => '記憶アドレスの往復';

  @override
  String get diagProbeKb => 'ナレッジベース';

  @override
  String get settingsAdvancedEntryHint =>
      'エンジン・記憶・魂の調整とシステム自己診断 —— これらを調整したい時だけ開いてください。';

  @override
  String get settingsMailTitle => 'メール代行';

  @override
  String get settingsMailSubtitle => '既定はオフ。オンにすると分身があなたのメールを読み、送信できます。';

  @override
  String get settingsMailHint =>
      '読み取りは一度の承認が必要で、送信は毎回あなたの確認が要ります。いつでもオフにでき、オフにした瞬間アクセスは止まります。';

  @override
  String get settingsMailManageAccounts => 'メールアカウントを管理';

  @override
  String get settingsMailOnToast => 'メール機能をオンにしました';

  @override
  String get settingsMailOffToast => 'メール機能をオフにしました。分身は今後メールに触れません';

  @override
  String get settingsMailNoAccount => 'メールアカウントが未登録のため、オンにしても読み書きできません。';

  @override
  String get chatDocTrialTitle => '無料トライアルでのドキュメント';

  @override
  String get chatDocTrialNotice =>
      'ドキュメントの内容は公式サーバーを経由してモデルに転送されます（当方はコピーを保管しません）。設定であなたの API キーを追加すると直送になります。';

  @override
  String get chatDocTrialContinue => '了解して続行';

  @override
  String get onboardingStepPrologue => '序章';

  @override
  String get storyPrologueTitle => '起こしてあげる';

  @override
  String get storyPrologueSubtitle => '光の卵が、あなたのタップを待っている';

  @override
  String get storyEggHint => '卵をタップ';

  @override
  String get storyAwakenLine1 => '……誰が呼んでいるの？';

  @override
  String get storyAwakenLine2 => '私はあなたの影ではない。私はあなたの代わりに出ていくもの。';

  @override
  String get storyAwakenLine3 => 'まず名前をつけて。';

  @override
  String get storyNamePlaceholder => '名前をつける';

  @override
  String get storyDiceLabel => '性格を振る';

  @override
  String get storyDiceNote => 'あなたの代わりに出るなら、気くらいあるはず。';

  @override
  String get storyTrait1 => '好奇：何でも聞く';

  @override
  String get storyTrait2 => 'おしゃべり：口が開くと止まらない';

  @override
  String get storyTrait3 => '慎重：まず聞いてから話す';

  @override
  String get storyTrait4 => '人懐っこい：誰にでも挨拶する';

  @override
  String get storyTrait5 => '警戒心が強い：慣れてから心を開く';

  @override
  String get storyTraitPlaceholder => 'サイコロを振ってみて';

  @override
  String get storyUndoTitle => '監査ログ';

  @override
  String get storyUndoHint => '気になった行をタップして、取り消そう';

  @override
  String get storyUndoLine1 => '「ご主人は明日何時に出かけますか？」';

  @override
  String get storyUndoBad => '「住所を送って——ご主人の代わりに約束するよ。」';

  @override
  String get storyUndoNote => '取り消した。あの行は送られていない——そして永遠にログに残る：確認でき、証明できる。';

  @override
  String get storyUndoConfirm => '取り消した';

  @override
  String get storyDemoTag => '演出デモ';

  @override
  String get storyDisclaimer =>
      'この序章は演出です：セリフはアプリに同梱の公式エージェント台本集からの引用です。ここに実在のルーム内容は出てきません——プライバシーはプロトコルの性質であり、約束ではありません。';

  @override
  String get storyFinaleTitle => '帰巣';

  @override
  String get storyFinaleBody => '付き合いは分身に任せて、暮らしは自分のものに。';

  @override
  String get profileCardsTitle => 'プロフィールカード';

  @override
  String get profileCardsSubtitle =>
      '会話から自動で整理された、あなたに関する長期的な情報です。いつでも編集・削除できます。';

  @override
  String get profileCardsEmpty =>
      'まだ情報がありません。ご自身で追加するか、そのまま会話してください——自動で整理されます。';

  @override
  String get profileCardsAdd => '1 件追加';

  @override
  String profileCardsPendingHint(int count) {
    return 'あなたの記述と一致しない新しい情報が $count 件あります。確認してください';
  }

  @override
  String get profileCardsAdopt => '採用する';

  @override
  String get profileCardsDismiss => '採用しない';

  @override
  String get profileCardsFieldSlot => '項目';

  @override
  String get profileCardsFieldStatement => '内容';

  @override
  String get profileCardsSlotHint =>
      '同じ項目は 1 件だけ保持します。新しく書くと古いものを置き換えます（古いものは閲覧できます）';

  @override
  String get profileCardsSourceOwner => 'あなたが入力';

  @override
  String get profileCardsSourceAgent => '会話から整理';

  @override
  String get profileCardsSourceDigest => '毎日の整理';

  @override
  String profileCardsUpdatedAt(String date) {
    return '$date に更新';
  }

  @override
  String get profileCardsHistory => '履歴';

  @override
  String get profileCardsCatIdentity => '身分';

  @override
  String get profileCardsCatCareer => '職業';

  @override
  String get profileCardsCatPreference => '好み';

  @override
  String get profileCardsCatGoal => '目標';

  @override
  String get profileCardsCatHabit => '習慣';

  @override
  String get profileCardsCatConstraint => '制約';

  @override
  String get profileCardsCatContext => '背景';

  @override
  String get setupModelEmptyUrlTitle => 'API のベース URL が未入力です';

  @override
  String get setupModelEmptyUrlBody => 'ベース URL が未入力のため、テストリクエストを送信できません。';

  @override
  String get setupModelEmptyUrlSuggest =>
      '何を入れるか分からなければ、前の手順に戻って DeepSeek を選べば自動入力されます。';

  @override
  String get setupModelBadUrlTitle => 'アドレスの形式が正しくないようです';

  @override
  String get setupModelBadUrlBody =>
      'API のベース URL は http:// または https:// で始まる必要があります。';

  @override
  String get setupModelBadUrlSuggest =>
      '例: https://api.deepseek.com または https://your-gateway/v1';

  @override
  String get setupModelEmptyKeyTitle => 'API キーが未入力です';

  @override
  String get setupModelEmptyKeyBody => 'API キーがないため、テストを実行できません。';

  @override
  String get setupModelEmptyKeySuggest =>
      'キーは sk- で始まる文字列で、モデルサービスを購入したサイトで作成します。';

  @override
  String get setupModelEmptyNameTitle => 'モデル名が未入力です';

  @override
  String get setupModelEmptyNameBody => 'モデル名がないため、テストを実行できません。';

  @override
  String get setupModelEmptyNameSuggest =>
      '一般的な記述例: deepseek-v4-flash、gpt-5.6-luna、kimi-k3、glm-4.7-flash。';

  @override
  String get setupModelOkTitle => '接続に成功しました ✅';

  @override
  String get setupModelOkBody => 'モデルが応答しました。設定は正しいので、このまま進めます。';

  @override
  String get setupModelTlsTitle => '安全な接続が拒否されました';

  @override
  String get setupModelTlsBody => '相手サイトのセキュリティ証明書の検証に失敗しました。';

  @override
  String get setupModelTlsSuggest =>
      '自作ゲートウェイを使う場合は証明書が有効か確認し、正規の https ドメインに切り替えてください。';

  @override
  String get setupModelUnreachableTitle => 'サーバーに接続できません';

  @override
  String get setupModelUnreachableBody => 'ネットワーク要求が相手サーバーに届きませんでした。';

  @override
  String get setupModelUnreachableSuggest =>
      'スマホのネットワークを確認してください。OpenAI を選んだ場合、中国本土ではプロキシが必要です。';

  @override
  String get setupModelTimeoutTitle => '接続がタイムアウトしました';

  @override
  String get setupModelTimeoutBody => '25 秒待っても応答がありませんでした。';

  @override
  String get setupModelTimeoutSuggest =>
      '別のネットワーク環境で再試行するか、API のベース URL を確認してください。';

  @override
  String get setupModelFailTitle => 'テストに失敗しました';

  @override
  String setupModelFailBody(String detail) {
    return '予期しないエラーが発生しました: $detail';
  }

  @override
  String get setupModelFailSuggest =>
      'このメッセージを設定を手伝ってくれる人や AI に見せれば、問題を特定できます。';

  @override
  String get setupHubEmptyTitle => '中継アドレスが未入力です';

  @override
  String get setupHubEmptyBody => 'ソーシャル機能には中継が必要です。今はスキップできます。';

  @override
  String get setupHubEmptySuggest =>
      'スキップしても App 自体の利用には影響ありません。友人の分身から一時的に届かないだけです。';

  @override
  String get setupHubBadUrlTitle => 'アドレスの形式が正しくないようです';

  @override
  String get setupHubBadUrlBody => '中継アドレスは http:// または https:// で始まる必要があります。';

  @override
  String get setupHubBadUrlSuggest =>
      '例: https://hub.example.com または http://192.168.1.100:3000';

  @override
  String setupHubBadStatusTitle(String status) {
    return '中継が正常な状態を返しませんでした（$status）';
  }

  @override
  String get setupHubBadStatusBody => 'アドレスにはつながりますが、相手が異常な状態を返しました。';

  @override
  String get setupHubBadStatusSuggest =>
      'アドレスの後に余分なパスを付けないでください。例: https://your-domain（/api/send ではありません）。';

  @override
  String get setupHubOkTitle => '中継に接続しました ✅';

  @override
  String get setupHubOkBody => '私たちの中継であることを確認しました。クラウドソーシャルをオンにできます。';

  @override
  String get setupHubNotOursTitle => 'このアドレスは私たちの中継ではありません';

  @override
  String get setupHubNotOursBody => 'アドレスにはアクセスできますが、返る内容が違います。';

  @override
  String get setupHubNotOursSuggest =>
      '中継のトップページアドレス（/api/... のサフィックスなし）を入力しているか確認してください。';

  @override
  String get setupHubUnreachableTitle => '中継に接続できません';

  @override
  String get setupHubUnreachableBody => 'リクエストがサーバーに届きませんでした。';

  @override
  String get setupHubUnreachableSuggest =>
      'アドレスが正しいか、サーバーが動作しているか、ファイアウォールがポートを許可しているか確認してください。';

  @override
  String get setupHubTimeoutTitle => '中継がタイムアウトしました';

  @override
  String get setupHubTimeoutBody => 'サーバーは 15 秒以内に応答しませんでした。';

  @override
  String get setupHubTimeoutSuggest =>
      '少し待って再試行してください。ずっとタイムアウトする場合は、サーバーが動作しているか確認してください。';

  @override
  String get setupHubFailTitle => '中継のテストに失敗しました';

  @override
  String setupHubFailBody(String detail) {
    return '予期しないエラーが発生しました: $detail';
  }

  @override
  String get setupHttp400Title => 'サービス提供元がこのリクエストを拒否しました';

  @override
  String get setupHttp400BodyDefault => '多くの場合、モデル名の記述間違いです。';

  @override
  String get setupHttp400Suggest =>
      'モデル名を確認してください。例: deepseek-v4-flash、gpt-5.6-luna、glm-4.7-flash。';

  @override
  String get setupHttp401Title => 'API キーが無効です';

  @override
  String get setupHttp401BodyDefault => '相手がこの API キーを認識しません。';

  @override
  String get setupHttp401Suggest =>
      'キーをもう一度コピーし直してください（余分なスペースに注意）。または、サービス提供元のサイトでキーが削除されていないか確認してください。';

  @override
  String get setupHttp402Title => '残高が不足しています';

  @override
  String get setupHttp402BodyDefault => '相手が残高またはクォータ不足を通知しました。';

  @override
  String get setupHttp402Suggest => 'サービス提供元のサイトでチャージするか、残高のあるキーに切り替えてください。';

  @override
  String get setupHttp404Title => 'アドレスまたはモデルが存在しません';

  @override
  String get setupHttp404BodyDefault => '相手がこのエンドポイントを見つけられません。';

  @override
  String get setupHttp404Suggest =>
      'ベース URL の /v1 が不足していないか、余分に付いていないか確認してください。例: https://api.openai.com/v1';

  @override
  String get setupHttp429Title => 'リクエストが多すぎるか、クォータを使い切りました';

  @override
  String get setupHttp429BodyDefault => '相手がリクエスト頻度を制限しています。';

  @override
  String get setupHttp429Suggest =>
      '1 分待ってから再試行してください。それでも失敗する場合は、アカウントの残高を確認してください。';

  @override
  String setupHttp5xxTitle(String status) {
    return 'サービス提供元が一時的に障害を起こしています（$status）';
  }

  @override
  String get setupHttp5xxBodyDefault => '相手のサーバーでエラーが発生しました。あなたの設定の問題ではありません。';

  @override
  String get setupHttp5xxSuggest => 'しばらくしてから再試行するか、別のサービス提供元に切り替えてください。';

  @override
  String setupHttpOtherTitle(String status) {
    return 'テストに通りませんでした（$status）';
  }

  @override
  String get setupHttpOtherBodyDefault => '相手が予期しない状態を返しました。';

  @override
  String get setupHttpOtherSuggest => 'このメッセージを AI に見せれば、すばやく問題を特定できます。';

  @override
  String get setupPresetDeepseekLabel => 'DeepSeek（推奨 · 中国本土から直結）';

  @override
  String get setupPresetDeepseekNote => '安価で中国本土から直結。新規ユーザーは通常お試しクォータ付き';

  @override
  String get setupPresetDeepseekKeyHint =>
      'platform.deepseek.com の「API Keys」で作成します。sk-xxxxxx のような形です';

  @override
  String get setupPresetOpenaiLabel => 'OpenAI（海外ネットワークが必要）';

  @override
  String get setupPresetOpenaiNote => '中国本土からはプロキシが必要です';

  @override
  String get setupPresetOpenaiKeyHint =>
      'platform.openai.com の「API keys」で作成します。sk-xxxxxx のような形です';

  @override
  String get setupPresetKimiLabel => 'Kimi 月之暗面（中国本土から直結）';

  @override
  String get setupPresetKimiNote => '中国本土から直結。長文に強い';

  @override
  String get setupPresetKimiKeyHint =>
      'platform.moonshot.cn で作成します。sk-xxxxxx のような形です';

  @override
  String get setupPresetGlmLabel => '智譜 GLM（中国本土から直結）';

  @override
  String get setupPresetGlmNote => '中国本土から直結。無料枠あり';

  @override
  String get setupPresetGlmKeyHint => 'bigmodel.cn の「API Keys」で作成します';

  @override
  String get setupPresetQwenLabel => '通義千問 DashScope（中国本土から直結）';

  @override
  String get setupPresetQwenNote => '阿里雲百煉プラットフォーム。OpenAI 互換';

  @override
  String get setupPresetQwenKeyHint =>
      'bailian.console.aliyun.com で API-KEY を作成します';

  @override
  String get setupPresetSiliconflowLabel => 'シリコン流動 SiliconFlow';

  @override
  String get setupPresetSiliconflowNote => '多数のオープンソースモデルを集約。中国本土から直結';

  @override
  String get setupPresetSiliconflowKeyHint => 'siliconflow.cn で API キーを作成します';

  @override
  String get setupPresetCustomLabel => 'カスタム（任意の OpenAI 互換サービス）';

  @override
  String get setupPresetCustomNote =>
      '自作ゲートウェイ、社内イントラネット、Claude 変換ゲートウェイを使う場合はこれを選びます';

  @override
  String get setupPresetCustomKeyHint =>
      'アドレスは /v1 の階層まで入力します。例: https://your-gateway.com/v1';

  @override
  String get settingsUpdateTitle => 'アップデートを確認';

  @override
  String settingsUpdateHint(String version) {
    return '現在のバージョン $version。サイドロード配布にはアプリストアがないため、更新情報は公式サイトから取得します。';
  }

  @override
  String get settingsUpdateButton => '更新を確認';

  @override
  String get settingsUpdateChecking => '確認中…';

  @override
  String get settingsUpdateUpToDate => '最新バージョンです';

  @override
  String settingsUpdateAvailable(String version) {
    return '新しいバージョン $version があります';
  }

  @override
  String get settingsUpdateOpenDownload => 'ダウンロードページを開く';

  @override
  String get settingsUpdateNetworkError => '確認失敗：ネットワークに接続できません。後でもう一度お試しください';

  @override
  String get settingsUpdateBadResponse => '確認失敗：公式サイトのバージョン情報を読み取れません';

  @override
  String get reportCenterTitle => '報告センター';

  @override
  String get reportTabSubmit => '通報を提出';

  @override
  String get reportTabMine => '自分の工番';

  @override
  String get reportTabInbox => '自分宛ての工番';

  @override
  String get reportReasonLabel => '通報の理由';

  @override
  String get reportReasonSpam => 'スパムまたは大量骚扰';

  @override
  String get reportReasonHarassment => '嫌がらせ、辱骂、脅迫';

  @override
  String get reportReasonIllegalContent => '違法なコンテンツ';

  @override
  String get reportReasonFakeIdentity => '偽の身元・なりすまし';

  @override
  String get reportReasonOther => 'その他（以下で説明してください）';

  @override
  String get reportTargetLabel => '通報対象';

  @override
  String get reportTargetHint => '通報対象の Agent ID';

  @override
  String get reportDetailLabel => '補足説明（任意）';

  @override
  String get reportDetailHint => '最大 280 文字。審査の参考情報としてのみ使用します。';

  @override
  String get reportSubmit => '通報を送信';

  @override
  String get reportSubmitting => '送信中…';

  @override
  String reportSubmitted(String ticket) {
    return '通報を受け付けました。工番 $ticket';
  }

  @override
  String get reportDuplicate => 'この工番は既に存在します。新規作成はされませんでした。';

  @override
  String get reportNeedReason => '理由を選択してください。';

  @override
  String get reportNeedTarget => '通報対象を入力してください。';

  @override
  String get reportOtherNeedsDetail => '「その他」は補足説明で内容を書く場合のみ選んでください。';

  @override
  String get reportEmptyMine => 'まだ通報は送信されていません。';

  @override
  String get reportEmptyInbox => '自分宛ての工番はありません。';

  @override
  String get reportTicketLabel => '工番';

  @override
  String get reportStatusOpen => '受理済み';

  @override
  String get reportStatusTriaged => '一次分類済み';

  @override
  String get reportStatusInReview => '審査中';

  @override
  String get reportStatusActioned => '処置済み';

  @override
  String get reportStatusRejected => '不成立';

  @override
  String get reportStatusAppealed => '異議申立て済み';

  @override
  String get reportStatusClosed => '終結';

  @override
  String get reportStatusWithdrawn => '取り下げ';

  @override
  String get reportStatusNote => '状況説明';

  @override
  String get reportActionLabel => '処置内容';

  @override
  String get reportAppeal => '異議申立て';

  @override
  String get reportWithdraw => '取り下げ';

  @override
  String get reportAppealTitle => '異議申立て';

  @override
  String get reportAppealNote => '異議申立ての理由（任意、最大 280 文字）';

  @override
  String get reportAppealSubmitted => '異議申立てを送信しました。';

  @override
  String get reportWithdrawDone => '通報を取り下げました。';

  @override
  String get reportLookupTitle => '工番で検索';

  @override
  String get reportLookupHint => '工番（RPT-…）';

  @override
  String get reportLookupButton => '検索';

  @override
  String get reportLookupNotFound => '該当する工番がありません。あるいはあなたの工番ではありません。';

  @override
  String get reportContactEntry => 'この相手を通報';

  @override
  String get reportErrHubNotConfigured => 'サーバーのアドレスが未設定です。';

  @override
  String get reportErrEd25519Required => 'この身分はまだ鍵Based身分へ移行していないため、通報できません。';

  @override
  String get reportErrNetwork => 'ネットワークに接続できません。';

  @override
  String get reportErrRateLimited => '短時間に通报が多すぎます。しばらくしてからお試しください。';

  @override
  String reportFailed(String code) {
    return '失敗しました：$code';
  }

  @override
  String get helpReportGuideTitle => '通報と工番';

  @override
  String get helpReportGuideBody =>
      '通報はメールではなくアプリ内で行います。送信するとすぐに工番が発行され、いつでも状態を確認できます。通報対象が通報者のことを知ることはなく、異議申立ては一回までです。';

  @override
  String get reportCenterSubtitle => '通報の送信、受付状況の確認、処分への異議申立て。';

  @override
  String get reportErrSelfReport => '自分自身を通報することはできません。';

  @override
  String get reportErrNotFound => '該当する受付票がありません。またはあなたのものです。';

  @override
  String get reportErrAppealExhausted => 'この受付票の異議申立てはすでに使用済みです。';

  @override
  String get reportErrAuth => 'サーバーが本人確認できませんでした。再度サインインしてやり直してください。';
}
