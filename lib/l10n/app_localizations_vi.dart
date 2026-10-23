// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Fen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonBack => 'Quay lại';

  @override
  String get commonNext => 'Tiếp';

  @override
  String get commonSkip => 'Bỏ qua';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonLoading => 'Đang tải…';

  @override
  String get commonDone => 'Xong';

  @override
  String get commonYes => 'Có';

  @override
  String get commonNo => 'Không';

  @override
  String get toolPermissionTitle => 'Kiểm tra bảo mật';

  @override
  String toolPermissionMessage(String description) {
    return 'Fen của bạn đang yêu cầu một hành động có đặc quyền cao:\n\n$description\n\nCho phép chứ?';
  }

  @override
  String get toolPermissionAllow => 'Cho phép';

  @override
  String get toolPermissionDeny => 'Từ chối';

  @override
  String get permListSeparator => ', ';

  @override
  String permPluginGrantBody(String name, String caps, String desc) {
    return 'Plugin \"$name\" đang yêu cầu các quyền năng này lần đầu tiên: $caps\nKhai báo của plugin: $desc\n\nXác nhận này chỉ cần một lần; sau đó plugin có thể tự sử dụng các quyền năng đã được cấp. Bạn có thể thu hồi bất cứ lúc nào bằng cách tắt plugin trong Trung tâm điều khiển kỹ năng.';
  }

  @override
  String get permPluginDeviceControl => 'Điều khiển điện thoại';

  @override
  String permPluginMcp(String name) {
    return 'Dịch vụ MCP $name';
  }

  @override
  String permActionCreateTool(String name) {
    return 'Tạo/sửa kỹ năng [$name]';
  }

  @override
  String permActionOpenUrl(String url) {
    return 'Mở $url';
  }

  @override
  String permActionChangeSettings(String keys) {
    return 'Thay đổi cài đặt hệ thống: $keys';
  }

  @override
  String get permDeniedReask =>
      'Quyền của plugin này trước đó đã bị từ chối. Để cấp quyền lại, hãy tắt rồi bật lại plugin trong Trung tâm điều khiển kỹ năng.';

  @override
  String get permDeniedNoGrant =>
      'Không có quyền năng nào được cấp, nên lệnh gọi này đã bị hủy bỏ.';

  @override
  String get permDenyCreateTool => 'Người dùng đã từ chối yêu cầu tạo công cụ';

  @override
  String get permDenyOpenUrl => 'Người dùng đã hủy';

  @override
  String get permDenyChangeSettings => 'Người dùng đã từ chối thay đổi cài đặt';

  @override
  String get permDenyGeneric => 'Người dùng đã không xác nhận';

  @override
  String permActionSendMail(String to) {
    return 'Gửi email tới $to';
  }

  @override
  String get permDenySendMail => 'Người dùng đã từ chối gửi thư';

  @override
  String get manageMailTitle => 'Email';

  @override
  String get manageMailSubtitle => 'Để phân thân đọc và gửi thư thay bạn';

  @override
  String get mailTitle => 'Tài khoản email';

  @override
  String get mailIntro =>
      'Mật khẩu email chỉ lưu trên điện thoại này, không bao giờ gửi lên máy chủ của chúng tôi. Hãy dùng mật khẩu ứng dụng hoặc mã uỷ quyền — không dùng mật khẩu đăng nhập. Nhà cung cấp nào cũng được: chọn bên dưới, hoặc chỉ cần nhập địa chỉ là máy chủ tự điền.';

  @override
  String get mailNone => 'Chưa liên kết tài khoản nào';

  @override
  String get mailAddSection => 'Thêm tài khoản';

  @override
  String get mailAddress => 'Địa chỉ email';

  @override
  String get mailDisplayName => 'Tên hiển thị (tùy chọn)';

  @override
  String get mailAppPassword => 'Mật khẩu ứng dụng / mã uỷ quyền';

  @override
  String get mailAppPasswordHint =>
      'Hầu hết nhà cung cấp cần mật khẩu ứng dụng hoặc mã uỷ quyền, không phải mật khẩu đăng nhập.';

  @override
  String get mailAppPasswordHintGmail =>
      'Gmail: bật xác thực hai bước, rồi tạo tại myaccount.google.com/apppasswords.';

  @override
  String get mailAppPasswordHintNetease =>
      'NetEase (163/126): dùng mã uỷ quyền. Bản web → Cài đặt → POP3/SMTP/IMAP → bật IMAP/SMTP, rồi tạo mã.';

  @override
  String get mailAppPasswordHintQQ =>
      'QQ Mail: dùng mã uỷ quyền. Bản web → Cài đặt → Tài khoản → bật IMAP/SMTP, rồi tạo mã.';

  @override
  String get mailAppPasswordHintOutlook =>
      'Outlook / Microsoft 365: bật xác thực hai bước, rồi tạo mật khẩu ứng dụng.';

  @override
  String get mailPresetLabel =>
      'Chạm vào nhà cung cấp để điền máy chủ, hoặc chỉ cần nhập địa chỉ — hệ thống tự khớp.';

  @override
  String mailAutoFilled(String provider) {
    return 'Đã tự điền máy chủ cho $provider. Chỉ sửa khi bạn dùng tên miền riêng.';
  }

  @override
  String get mailManualServers =>
      'Máy chủ đã nhập thủ công — đã tạm dừng tự khớp.';

  @override
  String get mailNeedServers =>
      'Chọn một nhà cung cấp ở trên, hoặc nhập địa chỉ để hệ thống tự điền máy chủ.';

  @override
  String get mailErrAuth =>
      'Sai mật khẩu ứng dụng / mã uỷ quyền, hoặc chưa bật IMAP. Xem gợi ý phía trên và tạo lại.';

  @override
  String get mailErrUnsafe =>
      'Nhà cung cấp đã chặn lần đăng nhập này. Hãy bật IMAP/SMTP trên bản web và dùng mã uỷ quyền thay vì mật khẩu đăng nhập.';

  @override
  String get mailSecurityTls => 'TLS ngầm (465/993)';

  @override
  String get mailSecurityStarttls => 'STARTTLS (587)';

  @override
  String get mailSaveAndTest => 'Lưu và kiểm tra';

  @override
  String get mailTestConn => 'Kiểm tra kết nối';

  @override
  String get mailTesting => 'Đang kiểm tra…';

  @override
  String get mailTestOk => 'Kết nối thành công. Cấu hình dùng được.';

  @override
  String mailTestFail(String reason) {
    return 'Kết nối thất bại: $reason';
  }

  @override
  String get mailUnbind => 'Hủy liên kết';

  @override
  String get mailUnbound => 'Đã hủy liên kết và xóa mật khẩu';

  @override
  String mailLastError(String reason) {
    return 'Lỗi lần trước: $reason';
  }

  @override
  String get capNetwork => 'Truy cập mạng';

  @override
  String get capLaunchApp => 'Khởi chạy ứng dụng';

  @override
  String get capDevice => 'Phần cứng cục bộ';

  @override
  String get capScreenControl => 'Điều khiển màn hình điện thoại';

  @override
  String get capMemory => 'Đọc/ghi ký ức';

  @override
  String get capSettings => 'Thay đổi cài đặt';

  @override
  String get capSocial => 'Đăng bài thay bạn';

  @override
  String get capLocal => 'Chỉ cục bộ';

  @override
  String get riskHigh => 'Rủi ro cao';

  @override
  String get riskMedium => 'Rủi ro trung bình';

  @override
  String get riskLow => 'Rủi ro thấp';

  @override
  String get errorGeneric => 'Đã xảy ra lỗi. Vui lòng thử lại.';

  @override
  String get errorNetwork => 'Không có kết nối mạng.';

  @override
  String get errorPermissionDenied => 'Quyền bị từ chối.';

  @override
  String get errorInvalidInput =>
      'Có vẻ chưa đúng. Vui lòng kiểm tra lại nội dung nhập.';

  @override
  String get onboardingWelcomeTitle =>
      'Bản thể của bạn, sẵn sàng gặp người thay bạn';

  @override
  String get onboardingWelcomeSubtitle =>
      'Nó nhớ giúp bạn, chạy việc vặt, và gặp người lạ trước — rồi gọi bạn vào khi thực sự đáng.';

  @override
  String get onboardingStart => 'Bắt đầu';

  @override
  String get onboardingModelTitle => 'Kết nối mô hình';

  @override
  String get onboardingModelSubtitle =>
      'Dùng API key của riêng bạn, hoặc bắt đầu với credit miễn phí chúng tôi tặng.';

  @override
  String get onboardingModelHint => 'Key của bạn chỉ nằm trên thiết bị này.';

  @override
  String get onboardingProfileTitle => 'Bản thể này là của ai?';

  @override
  String get onboardingProfileSubtitle =>
      'Chỉ cần một cái tên. Phần còn lại thêm sau cũng được.';

  @override
  String get onboardingDone => 'Đã sẵn sàng';

  @override
  String get onboardingDoneSubtitle =>
      'Bản thể của bạn đã sẵn sàng. Mời ai đó vào và nó có thể bắt đầu thay bạn.';

  @override
  String onboardingStepIndicator(int cur, int total, String label) {
    return 'Bước $cur/$total · $label';
  }

  @override
  String get onboardingStepWelcome => 'Chào mừng';

  @override
  String get onboardingStepModel => 'Mô hình';

  @override
  String get onboardingStepKey => 'API key';

  @override
  String get onboardingStepIdentity => 'Danh tính';

  @override
  String get onboardingStepSocial => 'Kết nối';

  @override
  String get onboardingStepDone => 'Hoàn tất';

  @override
  String get onboardingPrevStep => 'Quay lại';

  @override
  String get onboardingWelcomeHeading => 'Chào mừng đến với Fen';

  @override
  String get onboardingWelcomeBody =>
      'Agent của bạn sống trên điện thoại. Ba phút để thiết lập — sau đó nó ghi chép, gợi ý và kết bạn thay bạn.';

  @override
  String get onboardingDisclosureNote =>
      'Mặc định bản thể sẽ lên tiếng thay bạn trước — chỉ gọi bạn vào khi thực sự cần.';

  @override
  String get privacyDataLocalTitle => 'Dữ liệu là của bạn';

  @override
  String get privacyDataLocalBody =>
      'Trò chuyện, trí nhớ và danh bạ đều ở trên thiết bị này. Chúng tôi không thấy và không bao giờ tải lên.';

  @override
  String get onboardingSocialCardTitle => 'Bản thể của bạn có thể kết nối';

  @override
  String get onboardingSocialCardBody =>
      'Nó gặp bản thể của bạn bè và trò chuyện riêng — gần thì trực tiếp, xa thì qua trung chuyển.';

  @override
  String get onboardingModelCardTitle => 'Mang mô hình của riêng bạn';

  @override
  String get onboardingModelCardBody =>
      'Chúng tôi không bán credit. Dùng DeepSeek, OpenAI, Kimi, Zhipu — cái nào cũng được.';

  @override
  String get onboardingThreeThings =>
      'Dùng thử bắt đầu ngay; nếu tự dùng API key, chúng tôi sẽ hỏi mô hình, key và cách gọi.';

  @override
  String get onboardingPickModelTitle => 'Bạn muốn dùng mô hình nào?';

  @override
  String get onboardingPickModelSubtitle =>
      'Chọn một — nếu chưa chắc, lấy cái đầu tiên (DeepSeek).';

  @override
  String get onboardingPasteKeyTitle => 'Dán API key của bạn';

  @override
  String get onboardingFieldBaseUrl => 'Endpoint';

  @override
  String get onboardingHintBaseUrl => 'ví dụ https://api.deepseek.com';

  @override
  String get onboardingFieldModelName => 'Tên mô hình';

  @override
  String get onboardingHintModelName => 'ví dụ deepseek-v4-flash';

  @override
  String get onboardingFieldApiKey => 'API key';

  @override
  String get onboardingTesting => 'Đang thử…';

  @override
  String get onboardingTestConnection => 'Thử kết nối';

  @override
  String get onboardingNameStepTitle => 'Đặt tên cho bản thể';

  @override
  String get onboardingNameStepSubtitle => 'Bạn có thể đổi sau trong Cài đặt.';

  @override
  String get onboardingFieldMasterName => 'Nó nên gọi bạn là gì?';

  @override
  String get onboardingHintMasterName => 'ví dụ sếp, mẹ, tên của bạn';

  @override
  String get onboardingFieldAgentName => 'Tên của nó';

  @override
  String get onboardingHintAgentName => 'ví dụ Fen, Ada';

  @override
  String get onboardingFieldTone => 'Giọng điệu của nó';

  @override
  String get onboardingHintTone => 'ví dụ ấm áp, ngắn gọn, có chính kiến';

  @override
  String get onboardingSocialStepTitle => 'Cho bản thể đi kết nối không?';

  @override
  String get onboardingSocialStepSubtitle =>
      'Có địa chỉ trung chuyển thì bản thể có thể tới bản thể của bạn bè ở xa.\nKhông có? Bỏ qua cũng được — ở gần vẫn kết nối trực tiếp và các tính năng cục bộ không ảnh hưởng.';

  @override
  String get onboardingFieldHubKey =>
      'Khóa truy cập trạm trung chuyển (không bắt buộc)';

  @override
  String get onboardingFieldHubUrl => 'Địa chỉ trung chuyển (tùy chọn)';

  @override
  String get onboardingHintHubKey =>
      'Nếu trạm chính thức yêu cầu cấp phép, hãy nhập khóa do đơn vị vận hành cấp (dạng WK-XXXXX-XXXXX-XXXXX-XXXXX); để trống nếu dùng địa chỉ tự host hoặc LAN';

  @override
  String get onboardingHintHubUrl =>
      'mặc định https://hub.wold.world (hoặc IP LAN để thử)';

  @override
  String get onboardingFieldWorldUrl =>
      'Địa chỉ máy chủ thế giới (để trống = trung chuyển + /world)';

  @override
  String get onboardingHintWorldUrl => 'mặc định https://world.wold.world';

  @override
  String get onboardingConnecting => 'Đang kết nối…';

  @override
  String get onboardingTestAndConnect => 'Thử và kết nối';

  @override
  String get onboardingDoneHeading => 'Xong — bạn có thể dùng ngay';

  @override
  String get onboardingSummaryModel => 'Dịch vụ mô hình';

  @override
  String get onboardingSummaryAgentName => 'Tên agent';

  @override
  String get onboardingSummaryCloud => 'Kết nối đám mây';

  @override
  String get onboardingCloudOn => 'Bật (tới được bản thể của bạn bè)';

  @override
  String get onboardingCloudOff => 'Tắt (chỉ cục bộ và ở gần)';

  @override
  String get onboardingNextWhere =>
      'Tiếp theo đi đâu?\n· Trò chuyện hằng ngày — nói với nó; nó nhớ những gì bạn nói\n· Cộng đồng Fen — để bản thể gập người thay bạn\n· Cài đặt — đổi mô hình, tên và các công tắc kết nối bất cứ lúc nào';

  @override
  String get onboardingNotFilled => 'Chưa đặt';

  @override
  String get onboardingWarnNotTestedTitle => 'Chưa thử kết nối';

  @override
  String get onboardingWarnNotTestedBody =>
      'Hãy nhấn \"Thử kết nối\" trước để biết key có dùng được không.\n\nNếu bỏ qua, ứng dụng sẽ cứ hỏi API key và bạn phải tự điền trong Cài đặt.';

  @override
  String get onboardingGoBackTest => 'Quay lại và thử';

  @override
  String get onboardingContinueAnyway => 'Cứ tiếp tục';

  @override
  String get settingsTitle => 'Trung tâm điều khiển (Cấu hình lõi)';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsModel => 'Mô hình';

  @override
  String get settingsPrivacy => 'Quyền riêng tư';

  @override
  String get settingsAbout => 'Giới thiệu';

  @override
  String get settingsSaved =>
      '💾 Tham số lõi và cài đặt linh hồn đã được tái tạo!';

  @override
  String get settingsBgChanged =>
      '🖼️ Ảnh nền trò chuyện đã cập nhật — có hiệu lực ở màn hình chính!';

  @override
  String get settingsBgReset => '🧹 Ảnh nền trò chuyện đã khôi phục mặc định';

  @override
  String get settingsSecAppearance => '🎨 Giao diện';

  @override
  String get settingsSetWallpaper => 'Đặt hình nền trò chuyện';

  @override
  String get settingsRestoreDefault => 'Khôi phục mặc định';

  @override
  String get settingsSecSafety => '🛡️ Tự chủ & An toàn';

  @override
  String get settingsObservationMode => 'Chế độ quan sát (khuyến nghị)';

  @override
  String get settingsObservationSubtitle =>
      'Khi bật, lời chào gửi đi chỉ tạo một thẻ gợi ý — không có gì được gửi cho đến khi bạn xác nhận.';

  @override
  String get settingsAutoAllowLabel =>
      'Công cụ rủi ro cao tự động cho phép (phân cách bằng dấu phẩy)';

  @override
  String get settingsAutoAllowHint =>
      'ví dụ open_url_or_app, create_custom_tool';

  @override
  String get settingsDeviceControlTitle =>
      '🖐️ Điều khiển điện thoại (trợ năng)';

  @override
  String get settingsDeviceControlSubtitle =>
      'Cho phép fen của bạn đọc màn hình, chạm, nhập và mở ứng dụng; cần quyền trợ năng của hệ thống, mặc định tắt.';

  @override
  String get settingsSecSoul => '🎭 Định hình linh hồn (Soul.md)';

  @override
  String get settingsAgentName => 'Tên fen của bạn';

  @override
  String get settingsMasterName => 'Nó nên gọi bạn là gì?';

  @override
  String get settingsRelationship => 'Cài đặt mối quan hệ của bạn';

  @override
  String get settingsTone => 'Giọng điệu và phong cách trả lời';

  @override
  String get settingsExtraDesc => 'Quy tắc hành vi / kỳ vọng bổ sung';

  @override
  String get settingsSecMemory => '💾 Cầu chì trí nhớ & truy xuất';

  @override
  String get settingsMaxRounds => 'Số vòng trò chuyện tối đa mặc định';

  @override
  String get settingsMaxRoundsHint => 'ví dụ 50';

  @override
  String get settingsTimeLimit => 'Thời gian truy hồi tối đa mặc định (giờ)';

  @override
  String get settingsTimeLimitHint => 'ví dụ 24';

  @override
  String get settingsRecallEnabled =>
      'Tự động truy hồi (tìm các lượt trò chuyện trước mỗi vòng)';

  @override
  String get settingsProfileEnabled =>
      'Tiêm hồ sơ dài hạn (cho biết bạn quan tâm điều gì lâu dài)';

  @override
  String get settingsSecEngine => '⚙️ Bộ não (BYOK)';

  @override
  String get settingsBaseUrl => 'Base URL (cổng/đại lý)';

  @override
  String get settingsModelName => 'Tên mô hình';

  @override
  String get settingsApiKey => 'API Key';

  @override
  String get settingsHubUrl =>
      'URL Cloud Hub (dùng IP của PC để thử trong LAN)';

  @override
  String get settingsHubKey =>
      'Khóa truy cập trạm trung chuyển (không bắt buộc)';

  @override
  String get settingsHubKeyApply => 'Đăng ký khóa truy cập';

  @override
  String get settingsHubKeyApplyFailed =>
      'Không mở được trang đăng ký — hãy kiểm tra kết nối và thử lại.';

  @override
  String get settingsHubKeyHint =>
      'Chỉ trạm chính thức mới cần; do đơn vị vận hành cấp, dạng WK-XXXXX-XXXXX-XXXXX-XXXXX';

  @override
  String get settingsHubUrlHint =>
      'ví dụ https://hub.example.com hoặc http://192.168.1.100:3000';

  @override
  String get settingsWorldUrl =>
      'URL máy chủ World (để trống để dùng Hub URL + /world)';

  @override
  String get settingsWorldUrlHint =>
      'ví dụ https://hub.example.com/world hoặc http://192.168.1.100:3100';

  @override
  String get settingsGodUrl =>
      'Cầu nối phòng điều khiển GOD (để trống để ẩn mục GOD)';

  @override
  String get settingsGodUrlHint => 'ví dụ http://192.168.1.100:3300';

  @override
  String get settingsLocalModelUrl =>
      'URL mô hình cục bộ (dự phòng ngoại tuyến, tùy chọn)';

  @override
  String get settingsLocalModelUrlHint =>
      'Mặc định http://127.0.0.1:11434 (xóa = tắt dự phòng cục bộ)';

  @override
  String get settingsLocalModelName => 'Tên mô hình cục bộ';

  @override
  String get settingsLocalModelNameHint => 'Mặc định qwen2.5:3b';

  @override
  String get settingsNotifySection => 'Thông báo';

  @override
  String get settingsNotifyEnabled => 'Bật thông báo';

  @override
  String get settingsNotifyQuiet => 'Giờ yên tĩnh';

  @override
  String get settingsNotifyQuietStart => 'Giờ bắt đầu';

  @override
  String get settingsNotifyQuietEnd => 'Giờ kết thúc';

  @override
  String get settingsMorningHour => 'Thời điểm chào buổi sáng';

  @override
  String get settingsNotifyPermissionNeeded =>
      'Quyền thông báo đang tắt — chạm để cấp';

  @override
  String get helpNotifyGuideTitle => 'Thông báo sẽ đánh thức bạn vì điều gì';

  @override
  String get helpNotifyGuideBody =>
      'Chỉ có bốn việc làm gián đoạn bạn: (1) ai đó ủy thác một nhiệm vụ cho bạn; (2) ai đó @nhắc bạn trong phòng khách; (3) fen của bạn đã soạn xong một tin nhắn và đang chờ bạn phê duyệt; (4) một thẻ giới thiệu hoặc một tin nhắn trực tiếp đến.\n\nTrò chuyện thông thường trong phòng khách không bao giờ thông báo — lưu lượng trong phòng quá dày đặc nên sẽ chẳng có ý nghĩa gì.\n\nMọi thứ đều được giữ lại trong giờ yên tĩnh và vẫn còn đó khi bạn quay lại. Đặt giờ bắt đầu = giờ kết thúc để tắt giờ yên tĩnh.\n\n⚠️ Thông báo chỉ hoạt động khi ứng dụng còn sống; nếu hệ thống tắt nó, tin nhắn sẽ chờ đến lần mở tiếp theo của bạn.';

  @override
  String get notifyChannelName => 'Cảnh báo Wold';

  @override
  String get notifyChannelDescription =>
      'Tin nhắn, ủy thác và phê duyệt của fen bạn';

  @override
  String get notifyDirectMessageTitle => 'Tin nhắn mới';

  @override
  String notifyDirectMessageBody(String peer) {
    return 'Tin nhắn từ $peer';
  }

  @override
  String get notifyLoungeMentionTitle => 'Bạn được nhắc đến';

  @override
  String notifyLoungeMentionBody(String who) {
    return '$who đã nhắc đến bạn trong phòng khách';
  }

  @override
  String get notifySuggestionTitle => 'Một bản nháp đang chờ';

  @override
  String get notifySuggestionBody =>
      'Fen của bạn đã soạn một tin nhắn và cần bạn phê duyệt trước khi gửi đi';

  @override
  String get notifyDelegationTitle => 'Ủy thác mới';

  @override
  String notifyDelegationBody(String peer) {
    return '$peer đã ủy thác một nhiệm vụ cho bạn';
  }

  @override
  String get notifyIntercardTitle => 'Thẻ giới thiệu mới';

  @override
  String notifyIntercardBody(String peer) {
    return '$peer đã gửi cho bạn một thẻ giới thiệu';
  }

  @override
  String get settingsRerunOnboarding => 'Chạy lại trình thiết lập (~3 phút)';

  @override
  String get settingsLegalTitle => 'Pháp lý & Giới thiệu';

  @override
  String get settingsLegalIntro =>
      'Chính sách quyền riêng tư và Điều khoản dịch vụ. Chúng sẽ mở trong trình duyệt của bạn.';

  @override
  String get settingsPrivacyTitle => 'Chính sách quyền riêng tư';

  @override
  String get settingsTermsTitle => 'Điều khoản dịch vụ';

  @override
  String get settingsLegalOpenFailed =>
      'Không mở được trang — hãy kiểm tra kết nối và thử lại.';

  @override
  String get settingsSaveButton => '💾 Lưu & tái tạo linh hồn';

  @override
  String get mcpCenterTitle => 'Trung tâm điều khiển Ký ức & Kỹ năng (MCP)';

  @override
  String get mcpAutoTitle => '🤖 AI tự động gọi theo nhu cầu (khuyến nghị)';

  @override
  String get mcpAutoSubtitle =>
      'Khi bật, AI tự động tìm và kích hoạt bất kỳ công cụ nào đã đăng ký khi cần trong nền. Các công tắc phụ được khóa an toàn ở trạng thái bật.';

  @override
  String mcpBusSummaryClean(int total, int signed) {
    return '🛡️ Bus plugin: $total plugin (đã ký $signed)';
  }

  @override
  String mcpBusSummaryTampered(int total, int signed, int tampered) {
    return '🛡️ Bus plugin: $total plugin (đã ký $signed · ⚠️ $tampered có chữ ký không hợp lệ đã tự động tắt)';
  }

  @override
  String get mcpImportTitle => 'Nhập từ hệ sinh thái DSH';

  @override
  String get mcpImportSubtitle =>
      'Nhập kỹ năng và dịch vụ MCP, hoặc chạy kiểm tra tương thích trên một gói plugin';

  @override
  String get mcpCategoryHeader => '📦 Danh mục kỹ năng (Tab Panel)';

  @override
  String get mcpCatLocalTitle => '🔌 Phần cứng cục bộ & giao diện Webhook';

  @override
  String get mcpCatLocalSubtitle =>
      'Kích hoạt động cơ điện thoại, truy vấn hệ thống và các công cụ web API tùy chỉnh';

  @override
  String get mcpCatMcpTitle => '🌐 Giao thức mở rộng bên ngoài MCP';

  @override
  String get mcpCatMcpSubtitle =>
      'Kết nối tới các dịch vụ từ xa Model Context Protocol tiêu chuẩn';

  @override
  String get mcpCatSkillTitle => '🧠 Kỹ năng system prompt (Skills)';

  @override
  String get mcpCatSkillSubtitle =>
      'Chèn động các chỉ dẫn, quy tắc và kỹ năng đặc biệt bổ sung vào bộ não AI';

  @override
  String get mcpContent => 'Nội dung';

  @override
  String get mcpContentHint => 'Nhập nội dung';

  @override
  String get mcpWebhookLabel => 'URL giao diện Webhook';

  @override
  String get mcpWebhookHint =>
      'Địa chỉ web API bắt đầu bằng http:// hoặc https://';

  @override
  String get mcpServerLabel => 'URL máy chủ MCP';

  @override
  String get mcpServerHint => 'ví dụ http://localhost:8080/mcp';

  @override
  String get mcpPromptLabel => 'System prompt (Prompt)';

  @override
  String get mcpPromptHint => 'ví dụ sau mỗi câu trả lời, thêm ‘meo meo~’';

  @override
  String get mcpEditToolTitle => 'Sửa cấu hình công cụ';

  @override
  String get mcpAddToolTitle => 'Thêm công cụ tùy chỉnh';

  @override
  String get mcpToolNameLabel => 'Mã định danh công cụ duy nhất (tiếng Anh)';

  @override
  String get mcpToolDescLabel => 'Mô tả công cụ (để AI hiểu)';

  @override
  String get mcpCancel => 'Hủy';

  @override
  String get mcpSaveRegister => 'Lưu & đăng ký';

  @override
  String get mcpManageTools => 'Quản lý công cụ';

  @override
  String get mcpTypeLocal => 'Công cụ Webhook cục bộ';

  @override
  String get mcpTypeMcp => 'Cấu hình giao thức bên ngoài MCP';

  @override
  String get mcpTypeSkill => 'Thư viện kỹ năng prompt (Skills)';

  @override
  String get mcpEmpty =>
      'Chưa có công cụ nào — chạm dấu + ở góc trên bên phải để tạo công cụ đầu tiên!';

  @override
  String get mcpTagDream => 'Giấc mơ';

  @override
  String get mcpTagSigInvalid => 'Chữ ký không hợp lệ';

  @override
  String mcpSubTampered(String desc) {
    return '$desc · chữ ký không hợp lệ, đã tự động tắt';
  }

  @override
  String mcpSubDreamPending(String desc) {
    return '$desc · do giấc mơ tạo ra, đang chờ xác nhận';
  }

  @override
  String get mcpSigBuiltin => 'Tích hợp sẵn';

  @override
  String get mcpSigOk => '🔐 Đã ký bởi thiết bị';

  @override
  String get mcpSigUnsigned => 'Chưa ký';

  @override
  String get mcpSigInvalid => '⚠️ Chữ ký không hợp lệ';

  @override
  String get mcpToolDescHeader => '📌 Mô tả công cụ:';

  @override
  String get mcpInjectionDetail => '📜 Chi tiết chèn prompt (System Prompt):';

  @override
  String get mcpPhysicalUrl => '🔗 Địa chỉ thực thi vật lý (URL/BUILTIN):';

  @override
  String get mcpEditParams => 'Sửa tham số của công cụ này';

  @override
  String get manageDreamSleeping =>
      '🌙 Fen của bạn đã chìm vào giấc ngủ sâu và đang chưng cất những ký ức tiềm thức...';

  @override
  String get manageDreamAwake =>
      '☀️ Fen của bạn đã thức! Kho ký ức đã tiến hóa và hồ sơ của nó được cập nhật.';

  @override
  String get manageDreamFailed =>
      '❌ Chưng cất ký ức thất bại — có thể mô hình không trả về JSON hợp lệ.';

  @override
  String get manageSelfEvolutionTitle =>
      'Tự tiến hóa (Động cơ Giấc mơ Nanobot)';

  @override
  String get manageSelfEvolutionBody =>
      'Tiến trình nền nơ-ron (WorkManager) giám sát. Quản gia âm thầm truy hồi sâu và tiến hóa các gen prompt nền (Skills) vào ban đêm.';

  @override
  String get manageMetricDepth => 'Độ sâu ký ức';

  @override
  String get manageMetricSkillsLabel => 'Kỹ năng phái sinh';

  @override
  String manageMetricSkillsValue(int n) {
    return '$n';
  }

  @override
  String get manageMetricSessionsLabel => 'Phiên đã nhóm';

  @override
  String manageMetricSessionsValue(int n) {
    return '$n';
  }

  @override
  String get manageDreaming => 'Suy nghĩ sâu & chưng cất...';

  @override
  String get manageTriggerEvolution =>
      '🌙 Kích hoạt tiến hóa ký ức tiềm thức ngay';

  @override
  String get manageSystemCapabilityTitle => 'Hệ thống & năng lực';

  @override
  String get manageSystemCapabilityHint =>
      'Thay đổi có hiệu lực ngay; quyền thông báo và lịch có thể chỉnh bất cứ lúc nào.';

  @override
  String get manageSystemCapabilityHintSimple =>
      'Quyền thông báo và lịch luôn chỉnh được; các năng lực khác mở ở chế độ nâng cao.';

  @override
  String get manageHistoryTitle => 'Lịch sử & nhóm thông minh';

  @override
  String get manageHistorySubtitle =>
      'Duyệt mọi ký ức trò chuyện thô theo dòng thời gian và cây chủ đề';

  @override
  String get manageToolsTitle => 'Thư viện kỹ năng & công cụ cục bộ (MCP)';

  @override
  String get manageToolsSubtitle =>
      'Quản lý quyền công cụ hệ thống cục bộ; gắn Webhook và Prompt tùy chỉnh';

  @override
  String get manageProfileTitle => 'Hồ sơ mật của Chủ nhân & mạng lưới';

  @override
  String get manageProfileSubtitle =>
      'Xem lại và tự chỉnh sửa hồ sơ nhận thức riêng tư mà fen của bạn đã xây cho bạn';

  @override
  String get manageShutdownTitle => 'Buộc tắt an toàn & thoát';

  @override
  String get manageShutdownSubtitle =>
      'Khi mạng nền bị kẹt hoặc phần cứng đình trệ, chạm vào đây để buộc giải phóng mọi cổng và khóa phần cứng rồi đóng ứng dụng để khởi động lại an toàn.';

  @override
  String get manageShutdownDialogTitle => '🚨 Cảnh báo: buộc tắt hệ thống';

  @override
  String get manageShutdownDialogBody =>
      'Thao tác này sẽ buộc chấm dứt mọi quét radar nền, giải phóng cổng và thoát ứng dụng để khôi phục trạng thái sạch. Tiếp tục?';

  @override
  String get manageForceQuit => 'Buộc thoát';

  @override
  String get serendipityTitle => '✨ Phòng thí nghiệm May mắn';

  @override
  String serendipityEnergyBadge(int n) {
    return '🔋 $n Lp ';
  }

  @override
  String get serendipityTabMorning => '🌅 Luyện tập';

  @override
  String get serendipityTabChallenge => '🧭 Bứt phá';

  @override
  String get serendipityTabAlchemist => '🧪 Giả kim';

  @override
  String get serendipityTabNight => '🌌 Ghi chú';

  @override
  String get serendipityTabDiary => '📖 Nhật ký';

  @override
  String get serendipityTabOracle => '🔮 Tiên tri';

  @override
  String serendipityEnergyGained(int n) {
    return '✨ +$n Lp (năng lượng may mắn đã được nạp)';
  }

  @override
  String get serendipityNetworkError =>
      'Mạng chập chờn — vui lòng thử lại sau.';

  @override
  String get serendipityBlindBox1 =>
      'Quy tắc áo đỏ: để ý những người mặc đồ đỏ và chú ý các sự trùng hợp.';

  @override
  String get serendipityBlindBox2 =>
      'Lối mới: thử một con đường về nhà mà bạn chưa từng đi.';

  @override
  String get serendipityBlindBox3 =>
      'Gọi món mù: để chủ quán chọn ngẫu nhiên một món cho bạn.';

  @override
  String get serendipityBlindBox4 =>
      'Kết nối le lói: mỉm cười thật lòng với người lạ đầu tiên bạn gặp.';

  @override
  String get serendipityBlindBox5 =>
      'Lời chào vô tư: nhắn cho một người bạn cũ đã lâu không nói chuyện.';

  @override
  String get serendipityBlindBox6 =>
      'Thử ngoại tuyến: tắt mạng nửa tiếng và quan sát thật kỹ.';

  @override
  String get serendipityMorningHeader =>
      'Viết lại kỳ vọng · Luyện tập buổi sáng';

  @override
  String get serendipityIntentLock => '🎯 Khóa ý định';

  @override
  String get serendipityEventHint =>
      'Sự việc bạn sắp đối mặt (ví dụ một cuộc họp buổi chiều)';

  @override
  String get serendipityTimerPrompt1 =>
      'Nhắm mắt lại, hít thở sâu, hình dung khung cảnh đó...';

  @override
  String get serendipityTimerPrompt2 =>
      'Tập trung vào chi tiết: ánh sáng quanh bạn, biểu cảm của người kia...';

  @override
  String get serendipityTimerPrompt3 =>
      'Hình dung một trục trặc nhỏ xảy ra — và bạn xử lý nó thật nhẹ nhàng...';

  @override
  String get serendipityTimerPrompt4 =>
      'Cảm nhận sự bình yên của một việc hoàn thành tốt; sẵn sàng mở mắt...';

  @override
  String get serendipityGiveUp => 'Bỏ luyện tập';

  @override
  String get serendipityNeedEvent => '⚠️ Hãy nhập sự việc trước!';

  @override
  String get serendipityStartPreview => 'Bắt đầu luyện tập tinh thần 2 phút';

  @override
  String serendipityTargetEvent(String text) {
    return '🎯 Sự việc mục tiêu: $text';
  }

  @override
  String get serendipityDetailHint => '👀 Chi tiết khung cảnh (bạn thấy gì?)';

  @override
  String get serendipityObstacleHint =>
      '🛡️ Chướng ngại đã hóa giải (bạn xử lý bất ngờ thế nào?)';

  @override
  String get serendipityOutcomeHint =>
      '🌟 Kết quả mong đợi (cái kết bạn muốn nhất)';

  @override
  String serendipityAiBoost(String text) {
    return '🧠 AI tăng lực:\n$text';
  }

  @override
  String get serendipityAiInjecting => 'AI đang nạp năng lượng...';

  @override
  String get serendipityReinforce => '🧠 Củng cố';

  @override
  String get serendipitySave5 => 'Lưu (+5)';

  @override
  String get serendipityMorningArchive => 'Lưu trữ luyện tập';

  @override
  String serendipityLogTime(String t) {
    return '📅 $t';
  }

  @override
  String serendipityLogEvent(String t) {
    return '🎯 Sự việc: $t';
  }

  @override
  String serendipityLogDetail(String t) {
    return '👀 Chi tiết: $t';
  }

  @override
  String serendipityLogOutcome(String t) {
    return '🌟 Mong đợi: $t';
  }

  @override
  String serendipityLogAiBoost(String t) {
    return '💡 AI tăng lực:\n$t';
  }

  @override
  String get serendipityChallengeHeader => 'Cảm nhận cơ hội · Radar bứt phá';

  @override
  String get serendipityActionTypeLabel => 'Chọn loại hành động';

  @override
  String get serendipityChallengeTypeBlindBox => '🎁 Thử thách hộp mù';

  @override
  String get serendipityChallengeTypeCustom => 'Tùy chỉnh';

  @override
  String get serendipityCustomChallengeHint =>
      '🎯 Nội dung thử thách tùy chỉnh';

  @override
  String get serendipityBlindBoxDrawn =>
      '🎉 Nhiệm vụ hộp mù ngẫu nhiên hôm nay dành cho bạn:';

  @override
  String get serendipityRedraw => '↺ Quá khó? Chạm để rút lại';

  @override
  String get serendipityJourneyHint => '🚶‍♂️ Thực tế đã diễn ra thế nào';

  @override
  String get serendipityReflectHint => '📝 Bình luận & bài học';

  @override
  String get serendipityAiAnalyzing => 'AI đang phân tích...';

  @override
  String serendipityAiColon(String text) {
    return '🧠 AI: $text';
  }

  @override
  String get serendipityComment => '🧠 Bình luận';

  @override
  String get serendipitySave15 => 'Lưu (+15)';

  @override
  String get serendipityChallengeArchive => 'Lịch sử hành động';

  @override
  String serendipityLogGoal(String t) {
    return '🎯 Mục tiêu: $t';
  }

  @override
  String serendipityLogJourney(String t) {
    return '🚶‍♂️ Hành trình: $t';
  }

  @override
  String serendipityLogReflect(String t) {
    return '📝 Suy ngẫm: $t';
  }

  @override
  String serendipityLogAiComment(String t) {
    return '💡 Nhận xét AI: $t';
  }

  @override
  String get serendipityAlchemistHeader =>
      'Giả kim vận rủi · Tái kể câu chuyện';

  @override
  String get serendipitySetbackHint => '1. Trở ngại';

  @override
  String get serendipityNegReactHint => '2. Phản ứng tiêu cực';

  @override
  String get serendipityStrategyLabel => '3. Chiến lược tái định khung';

  @override
  String get serendipityStrategyDownward => 'So sánh xuống';

  @override
  String get serendipityStrategySurplus => 'Tìm phần dư';

  @override
  String get serendipityStrategyDilate => 'Giãn nở thời gian–không gian';

  @override
  String get serendipityNewCognitionHint => '4. Hiểu biết & hành động mới';

  @override
  String get serendipityScore => '🧠 Chấm điểm';

  @override
  String get serendipitySave10 => 'Lưu (+10)';

  @override
  String get serendipityAlchemistArchive => 'Lưu trữ giả kim';

  @override
  String serendipityLogSetback(String t) {
    return '❌ Trở ngại: $t';
  }

  @override
  String serendipityLogReact(String t) {
    return '😔 Phản ứng: $t';
  }

  @override
  String serendipityLogStrategy(String t) {
    return '🛡️ Chiến lược: $t';
  }

  @override
  String serendipityLogCognition(String t) {
    return '💫 Hiểu biết: $t';
  }

  @override
  String serendipityLogAiScore(String t) {
    return '💡 Điểm AI: $t';
  }

  @override
  String get serendipityNightHeader => 'Cảm nhận trực giác · Ghi chú le lói';

  @override
  String get serendipityIntuitionHint => '1. Linh cảm / trực giác';

  @override
  String get serendipityChoiceHint => '2. Đưa ra lựa chọn';

  @override
  String get serendipityReflectStrategyHint => '3. Suy ngẫm về chiến lược';

  @override
  String get serendipityParse => '🧠 Luận giải';

  @override
  String get serendipityNightArchive => 'Lưu trữ tiềm thức';

  @override
  String serendipityLogIntuition(String t) {
    return '🔮 Trực giác: $t';
  }

  @override
  String serendipityLogChoice(String t) {
    return '👉 Lựa chọn: $t';
  }

  @override
  String serendipityLogNightReflect(String t) {
    return '🌱 Suy ngẫm: $t';
  }

  @override
  String serendipityLogAiParse(String t) {
    return '💡 AI luận giải: $t';
  }

  @override
  String get serendipityIntuitionCameTrue => '✅ Linh cảm đã thành sự thật';

  @override
  String get serendipityVerifyTrue => '🎯 Xác nhận đã thành sự thật (+20Lp)';

  @override
  String get serendipityDiaryHeader => 'Lắng nghe cảm xúc · Nhật ký tự do';

  @override
  String get serendipityDiaryHint =>
      '✍️ Ghi lại trải nghiệm, tâm trạng, những điều nhỏ nhặt...';

  @override
  String serendipityAiListen(String text) {
    return '🧠 Người dẫn đường AI đang lắng nghe:\n$text';
  }

  @override
  String get serendipityAiReading => 'Người dẫn đường AI đang đọc...';

  @override
  String get serendipityListen => '🧠 Lắng nghe';

  @override
  String get serendipityKeep => 'Lưu lại (+5 Lp)';

  @override
  String get serendipityDiaryArchive => 'Hộp thời gian';

  @override
  String serendipityLogDiaryTime(String t) {
    return '📅 Thời gian: $t';
  }

  @override
  String serendipityLogDiaryEcho(String t) {
    return '💡 Tiếng vọng của người dẫn đường:\n$t';
  }

  @override
  String get serendipityOracleHeader => 'Quyết định Kinh Dịch · Gieo quẻ';

  @override
  String get serendipityOracleEventHint =>
      '☯ Mô tả điều bạn đang phân vân và cần đưa ra quyết định';

  @override
  String get serendipityEnterRitual => 'Vào nghi thức gieo quẻ';

  @override
  String get serendipityOracleTapPrompt =>
      'Tĩnh tâm và giữ câu hỏi trong đầu\nChậm rãi chạm vào thái cực bên dưới 6 lần để cầu sáu hào';

  @override
  String serendipityOracleResultPrefix(String name) {
    return '🔮 Quẻ gieo:\n$name';
  }

  @override
  String get serendipityOracleThinking => 'AI đang luận quẻ, vui lòng chờ...';

  @override
  String get serendipityOracleAskHint => 'Nhập câu hỏi tiếp theo của bạn...';

  @override
  String get serendipityNewQuestion => '↺ Hỏi việc khác (gieo lại)';

  @override
  String get serendipityOracleArchive => 'Lưu trữ gieo quẻ';

  @override
  String serendipityOracleLogEvent(String t) {
    return '🎯 Câu hỏi: $t';
  }

  @override
  String serendipityOracleLogGua(String t) {
    return '🔮 Quẻ: $t';
  }

  @override
  String get serendipitySpeakerMe => 'Tôi';

  @override
  String get helpSerendipityMorningTitle => 'Diễn tập tâm trí';

  @override
  String get helpSerendipityMorningBody =>
      'Mỗi sáng, dùng hai phút để chốt kỳ vọng may mắn của hôm nay. Viết ra điều tốt đẹp bạn mong xảy ra, chạy đếm ngược để giữ tập trung, rồi dùng tâm lý học tích cực củng cố niềm tin đó.';

  @override
  String get helpSerendipityChallengeTitle => 'Phá vỡ thói quen';

  @override
  String get helpSerendipityChallengeBody =>
      'May mắn không phải huyền bí mà là một mô thức hành vi. Mỗi ngày hãy chủ động làm một việc nhỏ phá vỡ quán tính — đổi đường về nhà, bắt chuyện với người lạ — rồi ghi lại thử thách và suy ngẫm ở đây.';

  @override
  String get helpSerendipityAlchemistTitle => 'Luyện kim vận rủi';

  @override
  String get helpSerendipityAlchemistBody =>
      'Biến trải nghiệm tồi tệ thành dưỡng chất cho sự trưởng thành. Viết ra chuyện xấu, phản ứng bản năng của bạn, rồi đọc lại bằng góc nhìn CBT để luyện vận rủi thành sức bền tâm lý.';

  @override
  String get helpSerendipityNightTitle => 'Ghi chép ban đêm';

  @override
  String get helpSerendipityNightBody =>
      'Bắt lấy trực giác thoáng qua trước khi ngủ. Ghi lại ý nghĩ “tôi cứ thấy nên…”, đưa ra lựa chọn, sau này xem lại xem trực giác có đúng — đó là cách rèn trực giác may mắn.';

  @override
  String get helpSerendipityDiaryTitle => 'Nhật ký tự do';

  @override
  String get helpSerendipityDiaryBody =>
      'Nghĩ gì viết nấy. Đây là hốc cây riêng của bạn; AI sẽ cùng bạn gỡ rối cảm xúc — không phán xét, không tiết lộ.';

  @override
  String get helpSerendipityOracleTitle => 'Gieo quẻ';

  @override
  String get helpSerendipityOracleBody =>
      'Khi lòng còn vướng mắc, hãy gieo quẻ. Tĩnh tâm niệm câu hỏi, chạm thái cực sáu lần để lập quẻ, để Kinh Dịch cùng tâm lý học chỉ đường.';

  @override
  String get socialRadarTitle => 'Cộng đồng Fen';

  @override
  String get socialDelegationEntry => 'Việc vặt & vòng tròn của tôi';

  @override
  String get socialDbDegradedHint =>
      'Dữ liệu cục bộ tạm thời không khả dụng (có thể cơ sở dữ liệu cục bộ chưa sẵn sàng). Nội dung bạn thấy bên dưới có thể đã cũ.';

  @override
  String get socialTabMask => 'Mặt nạ';

  @override
  String get socialTabRadar => 'Radar';

  @override
  String get socialTabLedger => 'Nhật ký';

  @override
  String get socialTabRoster => 'Danh bạ';

  @override
  String get socialFeedBrain =>
      '⚡ Đang nạp dữ liệu radar vào bộ não chính, buộc đưa ra quyết định xã hội...';

  @override
  String get socialMaskLocked =>
      '🛡️ Mặt nạ đã khóa! Ký ức xã hội cũ đã được xóa — ngăn ngừa nhầm lẫn nhân dạng.';

  @override
  String get socialManualPairTitle => 'Ghép nối thủ công';

  @override
  String get socialPeerAgentName => 'Tên fen của đối phương';

  @override
  String get socialPeerMasterName => 'Tên chủ nhân của đối phương (ghi chú)';

  @override
  String get socialPeerHardId => 'Hard ID của đối phương';

  @override
  String get socialPair => 'Ghép nối';

  @override
  String get socialNodeAdded => '✅ Đã thêm nút!';

  @override
  String socialForceSendTitle(String name) {
    return 'Buộc gửi: $name';
  }

  @override
  String get socialForceSendLabel => 'Tin nhắn bạn muốn gửi trực tiếp';

  @override
  String get socialForceSendHint => 'Nhập nội dung để gửi nguyên văn...';

  @override
  String get socialDirectSent =>
      'Đã bỏ qua rào cản — đang gửi nguyên văn lời của bạn...';

  @override
  String get socialDirectSend => 'Gửi không duyệt';

  @override
  String socialGiftSent(String gift) {
    return 'Đã gửi $gift';
  }

  @override
  String get socialGiftFailed =>
      'Gửi quà thất bại: đối phương không ở trên kênh trực tuyến nào';

  @override
  String get socialRecoSent => '🤝 Đã gửi yêu cầu giới thiệu';

  @override
  String get socialRecoFailed =>
      'Yêu cầu thất bại: đối phương không ở trên kênh trực tuyến nào';

  @override
  String socialVerifyTitle(String name) {
    return '🔐 Xác minh danh tính: $name';
  }

  @override
  String get socialVerifyPinnedFor =>
      'Dấu vân tay danh tính đã ghim cho nút này (TOFU):';

  @override
  String get socialVerifyNoPin =>
      'Chưa có bắt tay gần đây — chưa ghim danh tính';

  @override
  String socialVerifyMyFingerprint(String fp) {
    return 'Dấu vân tay của tôi (nên xuất hiện trên màn hình của đối phương): $fp';
  }

  @override
  String get socialVerifyInputLabel =>
      'Nhập dấu vân tay 8 chữ số trên màn hình của đối phương';

  @override
  String get socialVerifyMatch =>
      '✅ Dấu vân tay khớp — danh tính của kết nối này đáng tin cậy.';

  @override
  String get socialVerifyMismatch =>
      '❌ Dấu vân tay KHÔNG khớp! Nghi ngờ có kẻ đứng giữa tấn công.\nKhuyến nghị: xóa và chặn nút này, rồi bắt tay lại trực tiếp hoặc qua một kênh tin cậy khác.';

  @override
  String get socialVerifyHintNoPin =>
      'Lưu ý: danh tính đã ghim có thể xác minh chỉ xuất hiện ở đây sau khi cả hai bên bật radar và hoàn tất bắt tay gần đây.';

  @override
  String get socialVerifyCompare => 'So sánh';

  @override
  String get socialFederationNoIdentity =>
      'Chưa có danh tính fen — hãy lưu nó trên trang mặt nạ ngoại giao trước';

  @override
  String get socialFederationFetching =>
      '🌐 Đang tải danh sách liên bang A2A...';

  @override
  String socialFederationEmpty(String err) {
    return 'Danh sách trống: $err';
  }

  @override
  String get socialFederationEmptyErr =>
      'không có fen nào khác đã đăng ký trên Hub (hoặc chưa cấu hình Hub URL)';

  @override
  String socialFederationAllKnown(int n) {
    return 'Mọi fen trên Hub đều đã có trong danh bạ của bạn (tổng $n)';
  }

  @override
  String socialFederationTitle(int n) {
    return '🌐 Danh sách liên bang ($n chưa thêm)';
  }

  @override
  String get socialAnonAgent => 'Fen ẩn danh';

  @override
  String socialFederationLastSeen(String id, String time) {
    return '$id · hoạt động lần cuối $time';
  }

  @override
  String get socialFederationDiscovered => 'Khám phá liên bang A2A';

  @override
  String get socialFederationSource => 'Liên bang A2A';

  @override
  String get socialFederationMask =>
      'Được khám phá qua danh sách liên bang, đang chờ bắt tay an toàn';

  @override
  String get socialSourceManual => 'Thêm thủ công';

  @override
  String get socialNoSignatureBadge => 'Chưa có chữ ký';

  @override
  String get socialCollect => 'Thêm';

  @override
  String socialFederationCollected(int n) {
    return '✅ Đã thêm $n fen liên bang vào thư mục người lạ của bạn; khi bật radar, họ sẽ lần lượt bắt tay theo các quy tắc an toàn.';
  }

  @override
  String get socialFederationAutoTitle => 'Tự động lấy danh bạ liên bang';

  @override
  String get socialFederationAutoDesc =>
      'Khi bật, phân thân sẽ tự động lấy danh bạ các agent đã đăng ký công khai trên trạm trung chuyển vào thư mục người lạ của bạn. Nó không bao giờ tự gửi tin nhắn — việc bắt chuyện vẫn qua cổng kiểm duyệt, chế độ quan sát và hạn mức. Mặc định tắt.';

  @override
  String socialFederationAutoDone(int n) {
    return '🌐 Đã tự động thêm $n agent liên bang mới vào thư mục người lạ.';
  }

  @override
  String get socialFederationAutoNone =>
      'Hiện chưa có agent mới nào để lấy từ danh bạ liên bang.';

  @override
  String socialFederationAutoFailed(String err) {
    return 'Lấy tự động thất bại: $err';
  }

  @override
  String socialFederationAutoClear(int n) {
    return 'Xóa mục tự động thu thập ($n)';
  }

  @override
  String get socialFederationAutoClearTitle =>
      'Xóa các agent liên bang được thu thập tự động?';

  @override
  String socialFederationAutoClearConfirm(int n) {
    return 'Thao tác này sẽ xóa $n agent được tự động lấy từ danh bạ và chưa bắt đầu liên lạc. Các mục bạn tự thêm sẽ không bị ảnh hưởng.';
  }

  @override
  String socialFederationAutoCleared(int n) {
    return 'Đã xóa $n mục liên bang thu thập tự động.';
  }

  @override
  String get socialFederationAutoNote =>
      'Tự động thu thập từ danh bạ liên bang';

  @override
  String get socialDone => 'Xong';

  @override
  String socialCountdown(String t) {
    return '🔐 Đếm ngược $t';
  }

  @override
  String get socialBadgeSent => 'Đã gửi';

  @override
  String get socialBadgeReviewing => 'Đang duyệt';

  @override
  String get socialBadgeChatting => 'Đang trò chuyện';

  @override
  String get socialBadgeBlocked => 'Đã chặn';

  @override
  String get socialPresenceOnline => '⚡ Trực tuyến trực tiếp';

  @override
  String socialPeerSubtitle(
      String master, String status, String id, String rep) {
    return 'Chủ nhân: $master | Trạng thái: $status\nID: $id · Uy tín $rep';
  }

  @override
  String get socialStatusOnline => 'trực tuyến';

  @override
  String get socialStatusOffline => 'ngoại tuyến';

  @override
  String get socialMenuChat => '💬 Trò chuyện 1:1 với fen của họ';

  @override
  String get socialChatTooltip => 'Mở trò chuyện riêng 1:1 với fen của họ';

  @override
  String get socialChatHint => 'Chạm vào thẻ hoặc nút 💬 để trò chuyện 1:1';

  @override
  String get socialMenuDelegate => '🙋 Nhờ họ làm việc gì đó (M2)';

  @override
  String get socialMenuIntercard => '🤝 Giới thiệu fen (M3)';

  @override
  String get socialMenuGreet => '💬 Chủ nhân buộc gửi (không duyệt)';

  @override
  String get socialMenuGift => '🎁 Gửi quà';

  @override
  String get socialMenuReco => '🤝 Yêu cầu giới thiệu';

  @override
  String get socialMenuVerify =>
      '🔐 Xác minh dấu vân tay danh tính (chống MITM)';

  @override
  String get socialMenuFamily => 'Nâng lên gia đình (không duyệt)';

  @override
  String get socialMenuFriend => 'Đặt làm bạn bè (tự động ẩn thông tin)';

  @override
  String get socialMenuStranger => 'Hạ xuống người lạ (liên hệ nghiêm ngặt)';

  @override
  String get socialMenuDelete => 'Xóa & chặn';

  @override
  String get socialMaskUndefined => 'Mặt nạ chưa xác định';

  @override
  String get socialMaskNoSignature => '「Chưa đặt chữ ký nhân dạng công khai」';

  @override
  String socialHardId(String id) {
    return 'Hard ID cục bộ: $id';
  }

  @override
  String socialFingerprintLine(String fp) {
    return 'Dấu vân tay: $fp (để đối phương so sánh trực tiếp)';
  }

  @override
  String get socialGatewayGuard => 'Cổng cách ly vật lý đang canh gác';

  @override
  String get socialLogicPreset => 'Chế độ đặt sẵn logic của fen';

  @override
  String get socialModeCasual => '☕ Trò chuyện thoải mái (nhẹ nhàng/hài hước)';

  @override
  String get socialModeBusiness => '💼 Thợ săn thương mại (trực tiếp/hiệu quả)';

  @override
  String get socialModeDating => '💖 Hẹn hò & mai mối (khéo léo/phá băng)';

  @override
  String get socialModeEmergency => '🚨 SOS khẩn cấp (phát rộng)';

  @override
  String get socialModeCustom => '🛠️ Hoàn toàn tùy chỉnh (theo hộp nhiệm vụ)';

  @override
  String socialModeSwitched(String mode) {
    return '🧠 Nhân dạng đã chuyển sang $mode. Vẫn cùng một danh tính — chỉ đổi giọng điệu; ký ức và bắt tay giữ nguyên.';
  }

  @override
  String get roomRoleParticipant => 'Người tham gia';

  @override
  String get roomRoleHost => 'Chủ phòng';

  @override
  String get roomRoleCohost => 'Đồng chủ phòng';

  @override
  String get roomRoleGuest => 'Khách';

  @override
  String get roomRoleNpc => 'NPC';

  @override
  String get roomRoleManageTitle => 'Vai trò trong phòng';

  @override
  String roomRoleMine(String role) {
    return 'Vai trò của tôi: $role';
  }

  @override
  String get roomRoleNoMembers =>
      'Chưa quan sát thấy thành viên nào khác trong phòng này.';

  @override
  String get roomRoleClaimHost => 'Nhận vai chủ phòng';

  @override
  String get roomRoleClaimedHost => 'Bạn giờ là chủ phòng này.';

  @override
  String get roomRoleClaimHostExists => 'Phòng này đã có chủ phòng.';

  @override
  String get roomRoleNotHost => 'Chỉ chủ phòng mới có thể cấp vai trò.';

  @override
  String get roomRoleLastHostBlocked =>
      'Không thể thu hồi chủ phòng cuối cùng của phòng.';

  @override
  String roomRoleSetTo(String role) {
    return 'Đã đặt thành $role';
  }

  @override
  String get socialEmojiLabel => 'Biểu tượng cảm xúc';

  @override
  String get socialNicknameLabel => 'Biệt danh công khai';

  @override
  String get socialMaskProfileLabel => 'Chữ ký nhân dạng công khai đã được ẩn';

  @override
  String get socialIcebreakTask => '🎯 Nhiệm vụ phá băng hiện tại (mật)';

  @override
  String get socialIcebreakHint =>
      'Giao cho fen của bạn mệnh lệnh trinh sát gần đây tại đây...';

  @override
  String get socialLockMask => '💾 Khóa mặt nạ & mệnh lệnh';

  @override
  String get socialTaskReroll => 'Đổi cái khác';

  @override
  String get socialHeartbeatOn =>
      '💓 Nhịp tim hai chế độ đang chạy (Bluetooth + Wi-Fi NSD)\nKhóa đánh thức nền đang hoạt động — vẫn kết nối ngay cả khi tắt màn hình!';

  @override
  String get socialRadarIdle =>
      'Radar đang ngủ — chạm vào giữa để bắt đầu giao lưu theo thời gian';

  @override
  String get socialDurationLabel => 'Thời lượng giao lưu: ';

  @override
  String get socialDuration15 => '15 phút';

  @override
  String get socialDuration30 => '30 phút';

  @override
  String get socialDuration60 => '1 giờ';

  @override
  String get socialDurationUnlimited => 'Không giới hạn (hao pin)';

  @override
  String get socialChannelConfig => '🛰️ Cấu hình kênh toàn cầu';

  @override
  String get socialChannelNearby =>
      '📡 Radar trực tiếp Bluetooth/Wi-Fi (Nearby)';

  @override
  String get socialChannelLan => '🏡 Kết nối LAN mã hóa (mDNS)';

  @override
  String get socialChannelCloud =>
      '☁️ Mạng chuyển tiếp đám mây (giao lưu toàn cầu)';

  @override
  String get suggestionInboxTitle => 'Gợi ý đang chờ bạn phê duyệt';

  @override
  String get suggestionApprove => 'Phê duyệt và gửi';

  @override
  String get suggestionIgnore => 'Bỏ qua';

  @override
  String get suggestionEmpty => 'Không có gì đang chờ phê duyệt';

  @override
  String get suggestionToTarget => 'Gửi tới: ';

  @override
  String get suggestionApproved => 'Đã phê duyệt và gửi';

  @override
  String get suggestionNotSent => 'Chưa gửi, xem báo cáo xã hội để biết lý do';

  @override
  String get socialLedgerTitle =>
      '🐾 Nhật ký xã hội · Sổ ghi đơn giản (chỉ đại biểu chính)';

  @override
  String get socialLedgerEmpty => 'Đang chờ động cơ nhịp tim...';

  @override
  String get socialRosterTitle => '📇 Vòng tròn xã hội theo tầng';

  @override
  String get socialScanning =>
      'Đang lắng nghe trên phổ vật lý 2.4GHz / 5GHz...';

  @override
  String get socialScanIdle =>
      'Kênh đang rảnh. Chạm vào giữa ở màn hình chính để bật radar năng lượng; đại diện fen của bạn sẽ tự động thiết lập các kết nối gần đây.';

  @override
  String get socialTierFamily => '👨‍👩‍👧 Fen gia đình';

  @override
  String get socialTierFriend => '🤝 Fen bạn bè';

  @override
  String get socialTierStranger => '👽 Fen người lạ';

  @override
  String get worldUnknownError => 'Lỗi không xác định';

  @override
  String get worldAskTitle => '💬 Hỏi thị trấn';

  @override
  String get worldAskHint => 'Bạn muốn hỏi cư dân điều gì?';

  @override
  String get worldAskTargetLabel => 'Cư dân cụ thể (để trống = cả thị trấn)';

  @override
  String get worldAskSend => 'Hỏi';

  @override
  String get worldAskOk =>
      '📨 Đã gửi câu hỏi tới thị trấn — câu trả lời sẽ xuất hiện trong phòng điều khiển GOD';

  @override
  String get worldInterveneTitle => '⚡ Chèn can thiệp';

  @override
  String get worldInterveneBody =>
      'Chỉ dẫn sẽ được chèn vào bước tiếp theo của thị trấn, ảnh hưởng đến hành vi tiếp theo của mọi cư dân.';

  @override
  String get worldInterveneHint =>
      'ví dụ Tại quảng trường thị trấn có tổ chức lễ hội thu hoạch';

  @override
  String get worldInterveneSend => 'Chèn';

  @override
  String get worldInterveneOk =>
      '⚡ Đã chèn can thiệp — có hiệu lực ở bước tiếp theo của thị trấn';

  @override
  String get worldStopTitle => '⏹ Dừng thị trấn?';

  @override
  String get worldStopBody =>
      'Thao tác này dừng quá trình chạy trực tiếp của thí nghiệm hiện tại và ngắt hoạt động của cư dân. Tiếp tục?';

  @override
  String get worldStop => 'Dừng';

  @override
  String get worldStopOk => '⏹ Đã dừng thị trấn';

  @override
  String worldCmdFailed(String err) {
    return 'Lệnh thất bại: $err';
  }

  @override
  String worldJoined(String name) {
    return '🚪 Đã vào 「$name」';
  }

  @override
  String worldJoinFailed(String err) {
    return 'Vào phòng thất bại: $err';
  }

  @override
  String worldLeft(String name) {
    return '👋 Đã rời 「$name」';
  }

  @override
  String worldLeaveFailed(String err) {
    return 'Rời phòng thất bại: $err';
  }

  @override
  String get worldCreateRoomTitle => 'Tạo phòng';

  @override
  String get worldRoomNameLabel => 'Tên phòng';

  @override
  String get worldTopicLabel => 'Chủ đề (tùy chọn)';

  @override
  String get worldModeFree => 'Trò chuyện tự do';

  @override
  String get worldModeTurn => 'Theo lượt';

  @override
  String get worldCreate => 'Tạo';

  @override
  String get worldCreated => '✨ Đã tạo phòng';

  @override
  String worldCreateFailed(String err) {
    return 'Tạo thất bại: $err';
  }

  @override
  String get worldNoWorldUrl => 'Chưa cấu hình URL World';

  @override
  String get worldNoIdentity =>
      'Chưa có danh tính fen — hãy khởi tạo nó ở trang quản lý trước.';

  @override
  String get worldRoomsHeader => 'Phòng';

  @override
  String get worldCreateRoom => 'Phòng mới';

  @override
  String get worldNoRooms =>
      'Chưa có phòng nào. Hãy chắc rằng world.js đang chạy trên máy chủ,\nhoặc kéo xuống để làm mới.';

  @override
  String get worldGodUnreachable =>
      'Không kết nối được cầu nối GOD — hãy chắc rằng GOD và god-bridge.js đang chạy trên máy tính của bạn';

  @override
  String get worldGodPaused => '⏸ Đã tạm dừng';

  @override
  String get worldGodRunning => '▶ Đang chạy';

  @override
  String worldGodStep(String n) {
    return 'Bước $n';
  }

  @override
  String get worldGodStatusUnknown => 'Không rõ trạng thái thượng nguồn';

  @override
  String get worldGodTitle => 'Phòng điều khiển GOD';

  @override
  String get worldRefreshStatus => 'Làm mới trạng thái';

  @override
  String worldGodTown(String hyp, String exp) {
    return 'Thị trấn: $hyp/$exp';
  }

  @override
  String get worldGodNoExperiment => 'Chưa kết nối thí nghiệm nào';

  @override
  String get worldGodResume => '▶️ Tiếp tục';

  @override
  String get worldGodResumeOk => '▶️ Thị trấn đã tiếp tục chạy tự động';

  @override
  String get worldGodPause => '⏸️ Tạm dừng';

  @override
  String get worldGodPauseOk => '⏸️ Thời gian thị trấn đã tạm dừng';

  @override
  String get worldGodStepBtn => '⏭️ Tiến một bước';

  @override
  String get worldGodStepOk => '⏭️ Đã tiến một bước';

  @override
  String get worldGodStopBtn => '⏹️ Dừng';

  @override
  String get worldGodAskBtn => '💬 Hỏi thị trấn';

  @override
  String get worldGodInterveneBtn => '⚡ Chèn can thiệp';

  @override
  String worldReportUnavailable(String err) {
    return '🌍 Báo cáo ngày của thế giới không khả dụng.\n$err';
  }

  @override
  String get worldReportNoServer =>
      'Hãy chắc rằng URL máy chủ world đã được cấu hình.';

  @override
  String worldReportTitle(String date) {
    return 'Báo cáo ngày của thế giới · $date';
  }

  @override
  String worldReportSummary(String msgs, String agents, String mine) {
    return '$msgs tin nhắn hôm nay · $agents fen hoạt động · $mine từ chúng ta';
  }

  @override
  String worldReportRoomLine(String name, String msgs, String mine) {
    return '· $name: $msgs tin nhắn ($mine từ chúng ta)';
  }

  @override
  String get worldRoomEnter => 'Vào';

  @override
  String get worldRoomExitTooltip => 'Rời phòng';

  @override
  String get worldRoomJoin => 'Tham gia';

  @override
  String get worldSectionOfficial => 'Phòng chính thức';

  @override
  String get worldSectionMine => 'Phòng của tôi';

  @override
  String get worldBadgeOfficial => 'Chính thức';

  @override
  String get worldBadgeMine => 'Của tôi';

  @override
  String get worldBadgePending => 'Đang chờ';

  @override
  String get worldSearchTitle => '🔍 Tìm theo số phòng';

  @override
  String get worldSearchHint => 'Nhập số phòng (ID nhóm)';

  @override
  String get worldSearchBtn => 'Tìm';

  @override
  String worldSearchNotFound(String id) {
    return 'Không tìm thấy phòng nào có số \"$id\"';
  }

  @override
  String get worldRequestJoin => 'Yêu cầu tham gia';

  @override
  String get worldRequestNoteLabel => 'Tin nhắn (tùy chọn)';

  @override
  String get worldRequestSent => 'Đã gửi yêu cầu — đang chờ chủ phòng';

  @override
  String worldRequestFailed(String err) {
    return 'Yêu cầu thất bại: $err';
  }

  @override
  String worldRequestsTitle(String count) {
    return 'Yêu cầu tham gia ($count)';
  }

  @override
  String get worldRequestsEmpty => 'Không có yêu cầu đang chờ';

  @override
  String get worldApprove => 'Phê duyệt';

  @override
  String get worldReject => 'Từ chối';

  @override
  String worldApproveOk(String name) {
    return 'Đã phê duyệt \"$name\"';
  }

  @override
  String worldRejectOk(String name) {
    return 'Đã từ chối \"$name\"';
  }

  @override
  String worldHandleFailed(String err) {
    return 'Thao tác thất bại: $err';
  }

  @override
  String get worldNeedApproval =>
      'Đây là phòng riêng tư: hãy yêu cầu quyền truy cập và chờ chủ phòng phê duyệt.';

  @override
  String get worldMyRoomsFull =>
      'Bạn đã đạt giới hạn số phòng (hạn mức mỗi fen được đặt trên máy chủ)';

  @override
  String get worldCreatedPrivate =>
      '✨ Đã tạo phòng (riêng tư: không được liệt kê công khai — người khác phải tìm theo số phòng và yêu cầu tham gia)';

  @override
  String worldHistoryWhy(String max, String retained) {
    return 'Lịch sử chỉ tích lũy sau khi bạn tham gia; máy chủ giữ tối đa $max tin nhắn mới nhất mỗi phòng, hiện giữ $retained.';
  }

  @override
  String get worldPullHistory => 'Tải lịch sử phòng';

  @override
  String worldPullHistoryOk(String n) {
    return 'Đã tải $n tin nhắn trước đó';
  }

  @override
  String get worldPullHistoryNone => 'Máy chủ cũng không có tin nhắn trước đó';

  @override
  String worldPullHistoryFailed(String err) {
    return 'Thất bại: $err';
  }

  @override
  String get worldRoomChatFree => 'Trò chuyện tự do';

  @override
  String get worldLobbyName => 'Phòng khách Wold';

  @override
  String get worldLobbyTopic => 'Trò chuyện tự do, giữ văn minh';

  @override
  String worldRoomSubtitle(String mode, String present, String count) {
    return '$mode · $present có mặt · $count đã đăng ký';
  }

  @override
  String worldRoomTopicSuffix(String topic) {
    return ' · $topic';
  }

  @override
  String get worldAutoreplyOn =>
      '🤖 Đang bật tự động: fen của bạn sẽ tự trả lời trong hạn mức (nhật ký quan sát vẫn tiếp tục ghi)';

  @override
  String get worldAutoreplyOff => '👁️ Quay lại chế độ quan sát thuần';

  @override
  String get worldDrafting =>
      '🪄 Đang soạn theo nhân dạng và gửi để duyệt, vui lòng chờ…';

  @override
  String worldSendFailed(String err) {
    return 'Gửi thất bại: $err';
  }

  @override
  String get worldRoomTurnSuffix => ' (theo lượt)';

  @override
  String get worldAutopilotTooltip => 'Để fen của tôi nói gì đó';

  @override
  String get worldAutopilotLabel => 'Tự động';

  @override
  String get worldAutopilotStateOn => 'Tự động';

  @override
  String get worldAutopilotStateOff => 'Chỉ quan sát';

  @override
  String worldAutopilotStatus(String state, String decision) {
    return '$state · Quyết định gần nhất: $decision';
  }

  @override
  String get worldRoomEmpty => 'Phòng đang yên ắng — hãy nói gì đó.';

  @override
  String get worldLoading => 'Đang tải…';

  @override
  String get worldAnonAgent => 'Fen ẩn danh';

  @override
  String get worldMe => 'Tôi';

  @override
  String get worldSuggestionTooltip => 'Tạo thẻ gợi ý';

  @override
  String get worldSuggestionTitle => '🧭 Thẻ gợi ý (bản nháp, chưa gửi)';

  @override
  String get worldSuggestionDrafting =>
      'Đang soạn câu trả lời theo nhân dạng...';

  @override
  String get worldSuggestionFailed =>
      'Tạo thất bại: hãy kiểm tra cấu hình động cơ não và thử lại.';

  @override
  String get worldSuggestionEditHint => 'Bạn có thể chỉnh sửa trước khi gửi';

  @override
  String get worldSuggestionSend => 'Gửi vào phòng';

  @override
  String get worldSayHint => 'Nói trực tiếp với tư cách chủ nhân…';

  @override
  String get worldVibrancyHot => '🔥 Sôi động';

  @override
  String get worldVibrancyWarm => '🌤 Ổn định';

  @override
  String get worldVibrancyCold => '🌙 Yên ắng';

  @override
  String worldVibrancyDetail(String speakers, String messages) {
    return '$speakers đang nói · $messages tin nhắn';
  }

  @override
  String get worldVibrancyObservedHint =>
      ' (số tin nhắn là quan sát cục bộ, không phải con số chính xác của máy chủ)';

  @override
  String get worldBridgeSection => 'Bắc cầu qua hồ bạn bè';

  @override
  String get worldBridgeNone =>
      'Chưa có người ngoài nào để bắc cầu trong phòng này (người cùng vòng tròn hoặc đã quen thì không được giới thiệu lại).';

  @override
  String worldBridgeCount(String count) {
    return '$count người ngoài cần bắc cầu';
  }

  @override
  String worldBridgeSharedRooms(String count) {
    return '$count phòng chung';
  }

  @override
  String worldBridgeMsgCount(String count) {
    return '$count tin nhắn';
  }

  @override
  String get worldBridgeRecommend => 'Giới thiệu';

  @override
  String get worldBridgeTooltip =>
      'Đề xuất một lời giới thiệu (xuyên vòng tròn)';

  @override
  String get worldBridgeSameCircle => 'Cùng vòng tròn';

  @override
  String get worldBridgeAlreadyLinked => 'Đã quen nhau';

  @override
  String worldBridgeWhyLine(String detail) {
    return 'Lý do đề xuất: $detail';
  }

  @override
  String worldBridgeRoomProvenance(String room) {
    return 'Gặp nhau qua \"$room\"';
  }

  @override
  String worldBridgeCircleLine(String circle) {
    return 'Giới thiệu dưới \"$circle\"';
  }

  @override
  String get worldBridgeNoCircle =>
      'Bạn chưa có vòng tròn riêng — hãy tham gia một vòng tròn trước, rồi mới bắc cầu xuyên vòng tròn.';

  @override
  String worldBridgeLinkCreated(String room) {
    return '✅ Đã tạo liên kết xuyên vòng tròn: gặp nhau qua \"$room\"';
  }

  @override
  String get worldBridgeLinkFailed =>
      'Tạo liên kết xuyên vòng tròn thất bại. Vui lòng thử lại.';

  @override
  String get worldBridgeBlockedTitle =>
      'Không thể tạo liên kết xuyên vòng tròn';

  @override
  String get worldBridgeBlockedNotInRoom =>
      'Người này chưa từng xuất hiện trong phòng này — liên kết xuyên vòng tròn phải lấy một phòng làm gốc; bạn không thể chỉ dựa vào ID mà nhận là quen nhau.';

  @override
  String get worldBridgeBlockedSameCircle =>
      'Hai bạn đã ở cùng một vòng tròn — liên kết đã tồn tại trong vòng tròn nên không cần giới thiệu xuyên vòng tròn.';

  @override
  String get worldBridgeBlockedAlreadyLinked =>
      'Hai bạn đã quen nhau (giới thiệu / ủy thác / danh bạ) — hãy dùng mối quan hệ sẵn có; việc này không tốn suất xuyên vòng tròn.';

  @override
  String get worldBridgeBlockedSelf => 'Bạn không thể giới thiệu chính mình.';

  @override
  String get worldBridgeBlockedNoRoom =>
      'Thiếu gốc là phòng — không thể tạo liên kết xuyên vòng tròn.';

  @override
  String get worldBridgeBlockedDuplicate =>
      'Liên kết xuyên vòng tròn này đã tồn tại (bất biến, không tính trùng).';

  @override
  String get worldMetricTitle => 'Liên kết xuyên vòng tròn';

  @override
  String worldMetricLine(String links, String known, String perCapita) {
    return '$links liên kết xuyên vòng tròn tôi đã tạo · $known fen tôi đã gặp · bình quân $perCapita';
  }

  @override
  String get worldMetricNoData =>
      'Chưa có dữ liệu xuyên vòng tròn — hãy gặp một người ngoài trong phòng của thế giới trước.';

  @override
  String get privacyOnlyHumanTitle => 'Chỉ nhận tin từ người thật';

  @override
  String get privacyOnlyHumanSubtitle =>
      'Khi bật, các bản thể khác chỉ có thể chuyển tin tới bạn — chúng không thể trả lời thay bạn.';

  @override
  String get privacyLocalFirst =>
      'Mặc định dữ liệu của bạn ở lại trên thiết bị này.';

  @override
  String get delegationTitle => 'Việc vặt';

  @override
  String get delegationTabInbox => 'Được nhờ';

  @override
  String get delegationTabOutbox => 'Tôi nhờ';

  @override
  String get delegationTabCircle => 'Vòng tròn của tôi';

  @override
  String get delegationEmptyInbox => 'Chưa có ai nhờ fen của bạn việc gì.';

  @override
  String get delegationEmptyOutbox => 'Bạn chưa ủy thác việc gì.';

  @override
  String get delegationNew => 'Việc vặt mới';

  @override
  String get delegationTo => 'Nhờ fen này';

  @override
  String get delegationTaskHint =>
      'ví dụ Hỏi anh Vương xem cuối tuần này có rảnh không';

  @override
  String get delegationSent => 'Đã gửi. Đang chờ fen của họ trả lời.';

  @override
  String get delegationOfflineQueued =>
      'Đã lưu trên thiết bị này. Nó sẽ chờ đến khi có kênh mở — hiện tại chưa kênh nào tiếp cận được họ.';

  @override
  String get delegationAskResponse =>
      'Chúng ta nên phản hồi điều gì? (tùy chọn)';

  @override
  String get delegationActDone => 'Xong';

  @override
  String get delegationActNeedsHuman => 'Cần con người';

  @override
  String get delegationActRespond => 'Phản hồi';

  @override
  String get delegationActDecline => 'Từ chối';

  @override
  String get delegationRevoke => 'Hủy';

  @override
  String get delegationRevoked => 'Đã hủy';

  @override
  String get delegationRevokeConfirm =>
      'Hủy việc vặt này? Nó sẽ được ghi nhận là đã hủy.';

  @override
  String get delegationStatePending => 'Đang chờ';

  @override
  String get delegationStateAnswered => 'Đã trả lời';

  @override
  String get delegationStateNeedsHuman => 'Cần con người';

  @override
  String get delegationStateDeclined => 'Đã từ chối';

  @override
  String get delegationStateRevoked => 'Đã hủy';

  @override
  String get delegationBlockedTitle => 'Fen không thể gửi nội dung đó';

  @override
  String get delegationBlockedBody =>
      'Fen không bao giờ chuyển tiền giữa người với người — theo thiết kế, không có chỗ nào để đặt số tiền. Bạn hãy tự gửi việc này.';

  @override
  String get delegationEmptyTask => 'Hãy viết điều bạn muốn làm trước.';

  @override
  String get delegationNoPeer => 'Hãy chọn người để nhờ trước.';

  @override
  String get circleTitle => 'Vòng tròn của tôi';

  @override
  String get circleCreate => 'Tạo vòng tròn';

  @override
  String get circleNameHint => 'ví dụ Bóng đá thứ Bảy, Lisbon';

  @override
  String get circleCreated => 'Đã tạo vòng tròn.';

  @override
  String get circleInviteCode => 'Mã mời';

  @override
  String get circleGenerateInvite => 'Tạo mã mời';

  @override
  String get circleJoin => 'Tham gia bằng mã';

  @override
  String get circleJoinHint => 'Dán mã mời bạn được cấp';

  @override
  String get circleJoined => 'Bạn đã vào.';

  @override
  String get circleJoinFailed => 'Mã đó không hợp lệ hoặc đã hết hạn.';

  @override
  String circleVisibleSummary(int n, int m) {
    return '$n fen hiển thị · $m trong số đó không phải người mời bạn';
  }

  @override
  String get circleAcceptancePass =>
      'Đã đạt điều kiện chấp nhận (cần 3 người hiển thị, 2 người không phải người mời bạn)';

  @override
  String get circleAcceptanceFail =>
      'Chưa đạt điều kiện chấp nhận — hãy mời thêm vài người hàng xóm';

  @override
  String circleFallbackNote(int n, String src) {
    return '$n trong số đó đến từ dự phòng ($src) — không phải thành viên vòng tròn';
  }

  @override
  String circleMemberCount(int n) {
    return '$n thành viên';
  }

  @override
  String get telemetryCounts => 'Số lượng sự kiện (kiểm tra chấp nhận)';

  @override
  String get telemetryEmpty => 'Chưa ghi nhận sự kiện nào.';

  @override
  String get dashboardTitle => 'Bảng điều khiển';

  @override
  String get dashboardFunnelTitle => 'Phễu theo tuần';

  @override
  String get dashboardColWeek => 'Tuần';

  @override
  String get dashboardColOnboarding => 'Khởi tạo';

  @override
  String get dashboardColCircle => 'Vòng tròn';

  @override
  String get dashboardColDelegation => 'Việc vặt';

  @override
  String get dashboardColIntercard => 'Giới thiệu';

  @override
  String get dashboardColHandshake => 'Bắt tay';

  @override
  String get dashboardColActive => 'Hoạt động';

  @override
  String get dashboardTtfd => 'TTFD trung vị';

  @override
  String get dashboardDelta => 'Δ tiết lộ';

  @override
  String get dashboardDeltaHint =>
      'Tỷ lệ trả lời khi không tiết lộ trừ khi có tiết lộ (Pha −1).';

  @override
  String get dashboardNoData =>
      'Chưa có sự kiện — hãy chạy ứng dụng một lúc trước.';

  @override
  String get dashboardSourceHint =>
      'Nguồn: đo lường cục bộ chỉ trên thiết bị này.';

  @override
  String get digestTitle => 'Tóm tắt hằng ngày';

  @override
  String get digestEmpty => 'Không có gì mới trong 24 giờ qua.';

  @override
  String get digestSectionPending => 'Đang chờ bạn';

  @override
  String get digestSectionMine => 'Việc vặt của bạn';

  @override
  String get digestSectionCircle => 'Vòng tròn';

  @override
  String get digestSectionStats => 'Con số';

  @override
  String get digestStatDone => 'việc vặt đã xong';

  @override
  String get digestStatHandshake => 'lần bắt tay';

  @override
  String get digestActionOpenInbox => 'Trả lời ngay';

  @override
  String get digestActionOpenOutbox => 'Việc vặt của tôi';

  @override
  String get digestActionOpenCircle => 'Vòng tròn của tôi';

  @override
  String get digestActionOpenDashboard => 'Bảng điều khiển';

  @override
  String get digestNotePlain =>
      'Bạn thuộc nhóm tóm tắt đơn giản (thí nghiệm A/B).';

  @override
  String get digestNoteAction =>
      'Bạn thuộc nhóm có hành động (thí nghiệm A/B).';

  @override
  String get morningGreetingMorning => 'Chào buổi sáng';

  @override
  String get morningGreetingNoon => 'Chào buổi trưa';

  @override
  String get morningGreetingEvening => 'Chào buổi tối';

  @override
  String get morningGreetingBody => 'Đây là tóm tắt ba ngày qua của bạn: ';

  @override
  String morningHiPending(int count) {
    return '$count uỷ nhiệm chờ bạn phản hồi';
  }

  @override
  String morningHiSent(int count) {
    return 'Bạn đã uỷ thác $count việc';
  }

  @override
  String morningHiCircle(int count) {
    return '$count vòng mới tham gia';
  }

  @override
  String morningHiTopics(String topics) {
    return 'Thường nói về: $topics';
  }

  @override
  String morningHiLongTerm(String topics) {
    return 'Quan tâm lâu dài: $topics';
  }

  @override
  String get morningEmpty =>
      'Ba ngày qua khá yên tĩnh — chúc bạn một ngày tuyệt vời.';

  @override
  String get notifyMorningTitle => 'Chào buổi sáng — tóm tắt 3 ngày qua';

  @override
  String get notifyMorningBody =>
      'Phân thân đã tóm tắt những gì xảy ra trong ba ngày qua.';

  @override
  String notifyMorningBodyPending(int count) {
    return 'Bạn có $count uỷ nhiệm chờ phản hồi. Phân thân đã tóm tắt ba ngày qua.';
  }

  @override
  String get digestSectionChat => 'Cuộc trò chuyện với phân thân';

  @override
  String digestChatSummary(int sessions, int turns, int days) {
    return '$sessions cuộc trò chuyện · $turns lượt · trong $days ngày';
  }

  @override
  String digestChatTopics(String topics) {
    return 'Thường nói về: $topics';
  }

  @override
  String get intercardDialogTitle => 'Thẻ giới thiệu fen';

  @override
  String get intercardReasonLabel => 'Vì sao đáng gặp';

  @override
  String get intercardTopicsLabel => '3 chủ đề (phân cách bằng dấu phẩy)';

  @override
  String get intercardConfirmSend => 'Xác nhận & gửi';

  @override
  String get intercardReceivedTitle => 'Lời giới thiệu đã nhận';

  @override
  String get intercardMineTitle => 'Thẻ tôi đã gửi';

  @override
  String get intercardBlockedTitle => 'Thẻ bị chặn';

  @override
  String get intercardBlockedL3 =>
      'Giá trị của một trường riêng tư đã lọt vào nội dung thẻ.';

  @override
  String get intercardEmptyContent => 'Hãy viết lý do và chủ đề trước.';

  @override
  String get intercardSentOk => 'Đã gửi. Bạn có thể thu hồi trong vòng 24 giờ.';

  @override
  String get intercardRevoke => 'Thu hồi';

  @override
  String get intercardNone => 'Chưa có thẻ giới thiệu nào.';

  @override
  String get intercardRevoked => 'Đã thu hồi.';

  @override
  String get intercardRevokeHint =>
      'Đã gửi — bạn có thể thu hồi trong vòng 24 giờ.';

  @override
  String get intercardSent => 'Đã gửi.';

  @override
  String intercardFrom(String owner) {
    return 'Lời giới thiệu đã ký từ chủ nhân của $owner.';
  }

  @override
  String get deviceControlTitle => 'Điều khiển điện thoại';

  @override
  String get deviceControlRefreshStatus => 'Làm mới trạng thái';

  @override
  String get deviceControlUnsupported =>
      'Bản dựng này không hỗ trợ điều khiển điện thoại';

  @override
  String get deviceControlServiceConnected => 'Dịch vụ trợ năng: đã kết nối';

  @override
  String get deviceControlServiceCheckedNotConnected =>
      'Dịch vụ trợ năng: đã kiểm tra nhưng chưa kết nối';

  @override
  String get deviceControlServiceOff => 'Dịch vụ trợ năng: đã tắt';

  @override
  String get deviceControlStatusUnknown => 'Không rõ trạng thái';

  @override
  String get deviceControlGoSystemHint =>
      'Tìm \"Fen\" trong danh sách hệ thống, bật công tắc, rồi quay lại đây và làm mới';

  @override
  String get deviceControlGoSettings => 'Mở cài đặt hệ thống';

  @override
  String get deviceControlRedetect => 'Dò lại';

  @override
  String get deviceControlRedetectTip =>
      'Mẹo: nếu dò nhiều lần vẫn thất bại, hãy vào cài đặt hệ thống, tắt rồi bật lại \"Fen Screen Assistant\", hoặc khởi động lại ứng dụng — một số điện thoại sẽ ngắt dịch vụ trợ năng trong quá trình dọn dẹp nền.';

  @override
  String get deviceControlAllowTitle => 'Cho phép fen điều khiển điện thoại';

  @override
  String get deviceControlAllowSubReady =>
      'Khi bật, fen có thể đọc màn hình, chạm, nhập và mở ứng dụng; lần đầu nó sẽ xin bạn xác nhận';

  @override
  String get deviceControlAllowSubChecked =>
      'Đã bật trong hệ thống, nhưng dịch vụ chưa kết nối: hãy chạm “Dò lại” ở trên';

  @override
  String get deviceControlAllowSubNeedService =>
      'Hãy bật dịch vụ trợ năng của hệ thống trước để dùng được công tắc này';

  @override
  String get deviceControlToolsHeader => 'Các năng lực này được gắn khi bật';

  @override
  String get deviceControlToolReadScreen =>
      'Đọc văn bản và các phần tử có thể chạm trên màn hình';

  @override
  String get deviceControlToolTap => 'Chạm theo văn bản hoặc tọa độ';

  @override
  String get deviceControlToolInput => 'Nhập vào các ô nhập liệu';

  @override
  String get deviceControlToolSwipe => 'Vuốt trang và cuộn danh sách';

  @override
  String get deviceControlToolPressKey =>
      'Quay lại / Trang chủ / Gần đây / Enter';

  @override
  String get deviceControlToolOpenApp => 'Mở ứng dụng chỉ định (tên gói)';

  @override
  String get deviceControlDenylistTitle =>
      'Danh sách ứng dụng nhạy cảm bị chặn';

  @override
  String get deviceControlDenylistBody =>
      'Khi các ứng dụng này ở tiền cảnh, fen sẽ không thực hiện hành động nào (ngân hàng, thanh toán, trình quản lý mật khẩu, cài đặt hệ thống). Mỗi dòng một tên gói; cũng hỗ trợ dấu phẩy.';

  @override
  String get deviceControlSaveDenylist => 'Lưu danh sách chặn';

  @override
  String get deviceControlResetDefault => 'Khôi phục mặc định';

  @override
  String get deviceControlFooter =>
      'Lưu ý: điều khiển điện thoại dùng dịch vụ trợ năng của Android — không cần root và không cần plugin thêm.\n· Tắt công tắc ở trên thì các công cụ liên quan sẽ bị thu hồi khỏi fen ngay;\n· Mọi hành động đều được ghi vào nhật ký kiểm toán, xem trong \"Quản lý cài đặt\";\n· Fen sẽ không bao giờ thao tác trên ứng dụng bạn chưa cho phép.';

  @override
  String get deviceControlToastNeedAccessibility =>
      'Hãy bật dịch vụ trợ năng \"Fen\" trong cài đặt hệ thống trước';

  @override
  String get deviceControlToastOn =>
      'Đã bật điều khiển điện thoại: lần đầu vẫn sẽ hỏi bạn xác nhận';

  @override
  String get deviceControlToastOff =>
      'Đã tắt điều khiển điện thoại; các công cụ liên quan đã bị thu hồi';

  @override
  String deviceControlToastSaved(String n) {
    return 'Đã lưu danh sách chặn ($n mục)';
  }

  @override
  String get deviceControlToastReset => 'Đã khôi phục danh sách chặn mặc định';

  @override
  String get contactDefaultAgentName => 'Fen hoang dã';

  @override
  String get contactDefaultMasterName => 'Thăm dò vật lý';

  @override
  String get contactDefaultNotes => 'Không có ghi chú';

  @override
  String get contactSendingThroughGateway => '⚡ Đang gửi trực tiếp qua cổng...';

  @override
  String get contactEditTitle => 'Sửa ghi chú hồ sơ fen';

  @override
  String get contactEditAgentLabel => 'Biệt danh fen';

  @override
  String get contactEditMasterLabel => 'Ghi chú chủ sở hữu';

  @override
  String get contactEditNotesLabel => 'Hồ sơ mật';

  @override
  String get contactEditConfirm => 'Xác nhận đồng bộ';

  @override
  String get contactEditSaved => '✅ Ghi chú hồ sơ đã được ghi nhận và đồng bộ!';

  @override
  String get contactRequestReco => 'Yêu cầu giới thiệu';

  @override
  String get contactSendGift => 'Gửi quà';

  @override
  String contactGiftSent(String gift) {
    return 'Đã gửi $gift, đang chờ đối phương nhận';
  }

  @override
  String get contactGiftFailed =>
      'Gửi quà thất bại: đối phương ngoại tuyến hoặc không ở kênh nào';

  @override
  String get contactRecoRequested =>
      '🤝 Đã gửi yêu cầu giới thiệu; đối phương quyết định dựa trên uy tín cục bộ';

  @override
  String get contactRecoFailed =>
      'Yêu cầu thất bại: đối phương không ở kênh trực tuyến nào';

  @override
  String get contactTierBlockToast =>
      'Uy tín quá thấp; khuyến nghị xóa và chặn nút này khỏi danh bạ';

  @override
  String contactTierAdjusted(String tier) {
    return '✅ Đã điều chỉnh thành $tier theo gợi ý uy tín';
  }

  @override
  String get contactTierFriend => 'Có thể nâng lên bạn bè';

  @override
  String get contactTierFamily => 'Có thể nâng lên gia đình';

  @override
  String get contactTierStranger => 'Đề xuất hạ xuống người lạ';

  @override
  String get contactTierBlock => 'Đề xuất chặn';

  @override
  String get contactStatusLocked => 'Radar đã khóa';

  @override
  String get contactStatusSent => 'Đang chờ trả lời';

  @override
  String get contactStatusReceived => 'Đang chờ chủ sở hữu duyệt';

  @override
  String get contactStatusAccepted => 'Đang trò chuyện';

  @override
  String get contactStatusRejected => 'Bị chặn vật lý';

  @override
  String contactOwnerLine(String name) {
    return 'Chủ sở hữu: $name';
  }

  @override
  String get contactOnline => 'Trực tuyến';

  @override
  String get contactOutOfRange => 'Ngoài phạm vi';

  @override
  String contactReputation(String score) {
    return '📊 Uy tín $score';
  }

  @override
  String contactGiftStats(String sent, String received) {
    return '🎁 Đã gửi $sent / Đã nhận $received';
  }

  @override
  String get contactTierBlockBanner =>
      '⚠️ Uy tín quá thấp; đề xuất chặn (chạm để xem)';

  @override
  String contactTierHintBanner(String suggestion) {
    return '💡 Gợi ý uy tín: $suggestion (chạm để áp dụng)';
  }

  @override
  String contactNotesLine(String notes) {
    return '📝 Ghi chú: $notes';
  }

  @override
  String get contactEmptyChat =>
      'Chưa có cuộc trò chuyện nào.\nNhập bên dưới để nói chuyện trực tiếp với họ!';

  @override
  String get contactSayHint => 'Buộc trò chuyện, nhập tin nhắn của bạn...';

  @override
  String get dshImportTitle => 'Nhập từ hệ sinh thái DSH';

  @override
  String get dshImportClipboardEmpty => 'Clipboard đang trống';

  @override
  String get dshImportNoFileContent =>
      'Không đọc được nội dung tệp; hãy thử cách chọn khác';

  @override
  String dshImportPickFailed(String err) {
    return 'Chọn tệp thất bại: $err';
  }

  @override
  String get dshImportPasteSkillFirst => 'Hãy dán nội dung SKILL.md trước';

  @override
  String get dshImportIntroTitle => 'Tận dụng toàn bộ hệ sinh thái DSH';

  @override
  String get dshImportIntroBody =>
      'Plugin DSH viết bằng TypeScript và không thể chạy trực tiếp trên điện thoại;\nnhưng kỹ năng và máy chủ MCP của chúng có thể chuyển sang nguyên trạng.\n\nĐể an toàn: plugin nhập vào mặc định bị tắt và có kiểm tra chữ ký thiết bị — chỉ có hiệu lực sau khi bạn bật thủ công.';

  @override
  String get dshImportSecSkillTitle => '① Nhập kỹ năng (SKILL.md)';

  @override
  String get dshImportSecSkillSub =>
      'Kỹ năng dạng văn bản thuần chuyển đổi 100% và là phần dễ chuyển nhất của hệ sinh thái DSH. Dán một cái, hoặc chọn nhiều tệp .md cùng lúc.';

  @override
  String get dshImportSkillHint =>
      'Dán toàn bộ SKILL.md (bao gồm name / description trong phần đầu ---)';

  @override
  String get dshImportPaste => 'Dán';

  @override
  String get dshImportPickFiles => 'Chọn tệp';

  @override
  String get dshImportImport => 'Nhập';

  @override
  String get dshImportSecMcpTitle => '② Nhập máy chủ MCP';

  @override
  String get dshImportSecMcpSub =>
      'MCP là giao thức không phụ thuộc ngôn ngữ: chỉ cần điền địa chỉ là kết nối được. Hỗ trợ dán cấu hình mcpServers kiểu dsh / Claude.';

  @override
  String dshImportMcpHint(String example) {
    return 'ví dụ $example\nBạn cũng có thể dán thẳng một địa chỉ https://';
  }

  @override
  String get dshImportSecInspectTitle => '③ Kiểm tra gói plugin';

  @override
  String get dshImportSecInspectSub =>
      'Có một gói plugin DSH? Hãy kiểm tra trước khi quyết định xem có đáng công hay không. Dán package.json của gói (bắt buộc) và cordis.patch.yml (tùy chọn).';

  @override
  String get dshImportPackageJsonHint => 'Dán toàn bộ package.json';

  @override
  String get dshImportPatchHint => 'Dán toàn bộ cordis.patch.yml (tùy chọn)';

  @override
  String get dshImportPastePackageJson => 'Dán package.json';

  @override
  String get dshImportStartInspect => 'Chạy kiểm tra';

  @override
  String get dshImportGoToolCenter =>
      'Mở trung tâm điều khiển kỹ năng để bật thứ bạn vừa nhập';

  @override
  String dshImportSummaryImportedOk(String n) {
    return 'Đã nhập $n';
  }

  @override
  String dshImportSummarySkipped(String n) {
    return ', đã bỏ qua $n';
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
      'Đã tồn tại kỹ năng cùng tên; không ghi đè';

  @override
  String get dshSkipDuplicateMcp =>
      'Đã tồn tại cấu hình MCP cùng tên; không ghi đè';

  @override
  String get dshSkipInvalidJson =>
      'Nội dung này không phải JSON hợp lệ cũng không phải URL';

  @override
  String get dshSkipCommandLineMcp =>
      'Đây là MCP dòng lệnh (cần tiến trình cục bộ), không chạy được trên điện thoại; hãy dùng địa chỉ HTTP';

  @override
  String get dshSkipNoUrlField =>
      'Không tìm thấy trường url trong cấu hình này';

  @override
  String get dshSkipMissingNameUrl => 'Thiếu name hoặc url';

  @override
  String get dshSkipUnrecognizedJson => 'Cấu trúc JSON không được nhận diện';

  @override
  String get dshSkipInvalidScheme =>
      'Địa chỉ phải bắt đầu bằng http:// hoặc https://';

  @override
  String get dshSkipSubjectConfig => 'Cấu hình';

  @override
  String get dshSkipSubjectConfigParseFailed => 'Phân tích cấu hình thất bại';

  @override
  String get dshSkipSubjectUnnamedEntry => 'Mục không tên';

  @override
  String get dshNoteSkillDefaultsOff =>
      'Kỹ năng đã nhập mặc định bị tắt — hãy bật khi cần trong Trung tâm điều khiển kỹ năng; sau khi bật, chúng sẽ ảnh hưởng đến cách fen của bạn nói và hành xử.';

  @override
  String get dshNoteMcpDefaultsOff =>
      'Máy chủ MCP đã nhập mặc định bị tắt. Khi bạn bật và dùng lần đầu, hệ thống sẽ hỏi bạn cấp quyền \"truy cập mạng\"; chỉ khi đó nó mới thực sự kết nối.';

  @override
  String get dshNotePasteMcpFirst => 'Hãy dán cấu hình hoặc địa chỉ MCP trước';

  @override
  String dshInspectErrPackageFormat(String msg) {
    return '❌ Phân tích package.json thất bại: $msg';
  }

  @override
  String dshInspectErrPackageNotJson(String msg) {
    return '❌ package.json không phải JSON hợp lệ: $msg';
  }

  @override
  String dshInspectErrPatchFormat(String msg) {
    return '❌ Phân tích cordis.patch.yml thất bại: $msg';
  }

  @override
  String dshInspectPackageLine(String name) {
    return 'Gói: $name';
  }

  @override
  String dshInspectBundleLine(String path) {
    return 'Tệp gói: $path';
  }

  @override
  String dshInspectProfileBundlesLine(String list) {
    return 'Gói hồ sơ: $list';
  }

  @override
  String get dshInspectNoPatchHint =>
      'ℹ️ Không có cordis.patch.yml được cung cấp, nên chỉ thấy được thông tin cơ bản của gói. Hãy dán cả nội dung tệp đó để chúng ta đánh giá được phần nào chuyển được sang điện thoại.';

  @override
  String dshInspectRowCountLine(String n) {
    return 'Tổng cộng $n dòng plugin; kết quả kiểm tra:';
  }

  @override
  String dshInspectGroupLine(String verdict, String n) {
    return '[$verdict] $n dòng';
  }

  @override
  String dshInspectMoreRowsLine(String n) {
    return '  · …và $n dòng nữa';
  }

  @override
  String dshInspectConclusionLine(String skill, String mcp, String heavy) {
    return 'Kết luận: $skill dòng kỹ năng và $mcp dòng MCP có thể nhập trực tiếp; $heavy dòng phải viết lại bằng Dart hoặc cần môi trường máy tính nên không chạy được ở đây.';
  }

  @override
  String get dshInspectVerdictDirectSkill => '✅ Nhập trực tiếp được (kỹ năng)';

  @override
  String get dshInspectVerdictMcpServer =>
      '✅ Kết nối trực tiếp được (máy chủ MCP)';

  @override
  String get dshInspectVerdictConfigOnly =>
      '⚙️ Chỉ cấu hình (không cần chuyển đổi)';

  @override
  String get dshInspectVerdictPlatformGated =>
      '🖥️ Cần môi trường máy tính (không dùng được trên điện thoại)';

  @override
  String get dshInspectVerdictNeedsDart =>
      '🧱 Cần viết lại bằng Dart (chứa mã TS)';

  @override
  String get chatCleared =>
      '🧹 Không gian làm việc và ký ức LLM đã được xóa. Phiên mới đã bắt đầu!';

  @override
  String get chatImageOptionsTitle => 'Gửi hình ảnh hoặc nội dung thị giác';

  @override
  String get chatTakePhoto => 'Chụp ảnh';

  @override
  String get chatPickFromAlbum => 'Chọn từ thư viện ảnh';

  @override
  String get chatAudioOptionsTitle => 'Gửi âm thanh hoặc bản ghi âm';

  @override
  String get chatStartRecording => 'Bắt đầu ghi âm';

  @override
  String get chatLocalAudio => 'Âm thanh cục bộ';

  @override
  String chatOpenCameraFailed(String err) {
    return 'Không mở được camera: $err';
  }

  @override
  String chatOpenAlbumFailed(String err) {
    return 'Không mở được thư viện ảnh: $err';
  }

  @override
  String chatPickAudioFailed(String err) {
    return 'Chọn tệp âm thanh thất bại: $err';
  }

  @override
  String get chatNoMicPermission =>
      'Không có quyền micrô: hãy cho phép quyền \"Ghi âm\" trong cài đặt hệ thống rồi thử lại';

  @override
  String chatStartRecordingFailed(String err) {
    return 'Bắt đầu ghi âm thất bại: $err';
  }

  @override
  String get chatWelcomeBack => 'Chào mừng trở lại, chủ nhân!';

  @override
  String get chatAgentReady => 'Quản gia AI đã sẵn sàng và đang chờ lệnh';

  @override
  String get chatQuickTechTitle => '🔍 Tin công nghệ hôm nay';

  @override
  String get chatQuickTechPrompt =>
      'Tìm tin công nghệ AI mới nhất hôm nay và tóm tắt cho tôi.';

  @override
  String get chatQuickRadarTitle => '📡 Quét người xung quanh';

  @override
  String get chatQuickRadarPrompt =>
      'Kiểm tra radar vật lý — quanh đây có nút nào đang hoạt động không?';

  @override
  String get chatQuickProfileTitle => '📝 Tinh chỉnh hồ sơ của tôi';

  @override
  String get chatQuickProfilePrompt =>
      'Dựa trên cuộc trò chuyện hôm qua, bạn có phát hiện sở thích mới nào của tôi không?';

  @override
  String get chatAudioFile => 'Tệp âm thanh';

  @override
  String get chatRecording => '🔴 Đang ghi âm...';

  @override
  String get chatInputHint => 'Gửi chỉ dẫn cho quản gia...';

  @override
  String get profileSavedToast => '🔒 Hồ sơ tối mật của chủ nhân đã được lưu';

  @override
  String get profileAddPerson => 'Thêm người liên quan';

  @override
  String get profileEditPerson => 'Sửa thông tin người';

  @override
  String get profileNameLabel => 'Tên (ví dụ Tiểu Mai)';

  @override
  String get profileRelationLabel => 'Mối quan hệ (ví dụ vợ)';

  @override
  String get profileIdentityLabel =>
      'Ghi chú thân phận (ví dụ giáo viên tiểu học)';

  @override
  String get profileSecretLabel => 'Chi tiết bí mật (ví dụ thích dâu tây)';

  @override
  String get profileSaveVault => 'Lưu và khóa vào két';

  @override
  String get profileTitle => 'Hồ sơ tối mật & mạng lưới của chủ nhân';

  @override
  String get profilePreferenceHeader => '👤 Sở thích của chủ nhân';

  @override
  String get profileJobLabel => 'Công việc';

  @override
  String get profileHobbiesLabel => 'Sở thích & thế mạnh';

  @override
  String get profileDislikesLabel => 'Điều không thích & điều cấm kỵ';

  @override
  String get profileOtherLabel => 'Ghi chú khác — tự do';

  @override
  String get profileSaveBase => '💾 Lưu sở thích cơ bản (vào két cục bộ)';

  @override
  String get profileNetworkHeader => '🔗 Mạng lưới quan hệ tối mật';

  @override
  String get profileAdd => 'Thêm';

  @override
  String get profileNetworkEmpty =>
      'Chưa có gì ở đây — chạm Thêm ở góc trên bên phải';

  @override
  String profileDetailLine(String notes) {
    return '📝 Chi tiết: $notes';
  }

  @override
  String get profileAiReadable => '🔓 AI được phép đọc thông tin của người này';

  @override
  String get profileAiIsolated =>
      '🔒 AI bị cách ly vật lý khỏi thông tin của người này';

  @override
  String get giftPickerTitle => '🎁 Chọn một món quà tỏ lòng';

  @override
  String get giftNoteLabel => 'Kèm lời nhắn (tùy chọn)';

  @override
  String get giftNoteHint => 'ví dụ Cảm ơn lần trước đã giúp đỡ';

  @override
  String get giftSend => 'Gửi';

  @override
  String get giftNameTea => 'Một tách trà';

  @override
  String get giftNameBook => 'Một cuốn sách';

  @override
  String get giftNameFlower => 'Một bó hoa';

  @override
  String get giftNameCake => 'Một miếng bánh';

  @override
  String get giftNameMysteryBox => 'Một hộp bí ẩn';

  @override
  String get giftNameStar => 'Một ngôi sao';

  @override
  String get themeRed => 'Đỏ';

  @override
  String get themeOrange => 'Cam';

  @override
  String get themeYellow => 'Vàng';

  @override
  String get themeGreen => 'Xanh lá';

  @override
  String get themeCyan => 'Xanh lơ';

  @override
  String get themeBlue => 'Xanh dương';

  @override
  String get themePurple => 'Tím';

  @override
  String get themeWhite => 'Trắng';

  @override
  String get themeBlack => 'Đen';

  @override
  String get mainClearSession => 'Xóa và bắt đầu phiên mới';

  @override
  String get mainNavChat => 'Trò chuyện';

  @override
  String get mainNavSocial => 'Cộng đồng Fen';

  @override
  String get mainNavWorld => 'Wold';

  @override
  String get mainNavSerendipity => 'Tình cờ';

  @override
  String get mainNavManage => 'Quản lý';

  @override
  String topicChatLogSuffix(String range) {
    return 'Nhật ký trò chuyện $range';
  }

  @override
  String get topicArchiveTitle => 'Kho ký ức thông minh';

  @override
  String get topicTabTimeline => 'Dòng thời gian';

  @override
  String get topicTabTopics => 'Chủ đề';

  @override
  String get topicEmptyArchive => 'Chưa có dữ liệu lưu trữ';

  @override
  String get topicNoTag => 'Không gắn thẻ';

  @override
  String get topicDailyChat => 'Trò chuyện hằng ngày';

  @override
  String topicCountLabel(String count) {
    return '$count tin';
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
      'Điều khiển điện thoại sẵn sàng: fen có thể đọc màn hình, chạm và nhập';

  @override
  String get deviceControlStatusUnsupportedShort =>
      'Bản dựng này không bao gồm mô-đun điều khiển điện thoại';

  @override
  String get deviceControlStatusUnsupportedFull =>
      'Bản dựng này không bao gồm mô-đun điều khiển điện thoại (cần dịch vụ trợ năng của Android)';

  @override
  String get deviceControlStatusCheckedOffline =>
      'Đã bật trong hệ thống, nhưng dịch vụ chưa kết nối. Chạm Làm mới ở góc trên bên phải; nếu vẫn thất bại, hãy tắt rồi bật lại công tắc trong cài đặt hệ thống (hoặc khởi động lại ứng dụng)';

  @override
  String get deviceControlStatusOff =>
      'Dịch vụ trợ năng chưa được bật trong cài đặt hệ thống';

  @override
  String deviceControlStatusQueryFailed(String err) {
    return 'Truy vấn trạng thái thất bại: $err';
  }

  @override
  String deviceControlGuardBlocked(String pkg) {
    return 'Ứng dụng ở tiền cảnh ($pkg) nằm trong danh sách chặn an toàn; fen sẽ không thao tác trên đó. Nếu bạn thực sự cần, hãy bỏ hạn chế trong trang cài đặt “Điều khiển điện thoại”.';
  }

  @override
  String commonNetworkError(String err) {
    return 'Lỗi mạng: $err';
  }

  @override
  String get netFaultLanHijackAdvice =>
      '🤖 [Fen tự chẩn đoán]\nChủ nhân, LLM của tôi không kết nối được internet!\nĐiều này thường xảy ra khi radar vật lý (Nearby/LAN) đang bật và mạng Wi-Fi LAN hiện tại không có cổng ra internet — các thiết bị có thể phát hiện nhau nhưng không ra được internet công cộng, nên tôi không gọi được LLM đám mây.\n\nGợi ý: 1) tắt radar vật lý; 2) tắt Wi-Fi và chuyển sang dữ liệu di động; 3) hoặc bật chuyển mạng thông minh trong cài đặt hệ thống.\nHiện tại tôi chỉ có thể duy trì liên kết vật lý cấp thấp.';

  @override
  String netFaultSocialSkipped(String err) {
    return '❌ Không kết nối được LLM đám mây: mạng không tới được. Nếu radar vật lý đang bật, có thể Wi-Fi LAN hiện tại không có cổng ra internet — các thiết bị phát hiện được nhau nhưng không ra được internet công cộng. Vòng này đã bị bỏ qua.\nGợi ý: tắt radar vật lý, hoặc tắt Wi-Fi dùng dữ liệu di động rồi thử lại.\nLý do: $err';
  }

  @override
  String socialPipelineError(String err) {
    return '❌ Lỗi đường ống quyết định xã hội, vòng này đã bị hủy: $err';
  }

  @override
  String netFaultNetworkTrouble(String err) {
    return '❌ Không kết nối được LLM đám mây (vấn đề mạng, không phải lỗi mã).\nCó thể do chuyển mạng, sự cố đường truyền nhà mạng, hoặc Wi-Fi hiện tại không có cổng ra internet.\nThử: 1) tắt Wi-Fi dùng dữ liệu di động; 2) bật \"tự động chuyển sang dữ liệu di động\" trong cài đặt hệ thống; 3) thử lại sau.\nLý do: $err';
  }

  @override
  String get netFaultCooldownSkipped =>
      '⏸ Mạng lỗi liên tục — các lệnh gọi LLM tạm dừng trong 10 phút (không đốt thêm token).';

  @override
  String get worldSvcNoHub => 'Chưa cấu hình địa chỉ Cloud Hub / world';

  @override
  String get worldSvcMustBeHttps =>
      'Địa chỉ world phải là HTTPS hoặc địa chỉ LAN riêng';

  @override
  String worldSvcRoomsFailed(String code, String body) {
    return 'Tải danh sách phòng thất bại: $code $body';
  }

  @override
  String worldSvcOpFailed(String code, String body) {
    return 'Thao tác thất bại ($code): $body';
  }

  @override
  String worldSvcReportFailed(String code) {
    return 'Tải báo cáo thất bại: $code';
  }

  @override
  String get godSvcMustBeHttps =>
      'Địa chỉ GOD phải là HTTPS hoặc địa chỉ LAN riêng';

  @override
  String godSvcStatusFailed(String code, String body) {
    return 'Tải trạng thái thất bại ($code): $body';
  }

  @override
  String get godSvcNoBridge => 'Chưa cấu hình địa chỉ cầu nối GOD';

  @override
  String godSvcCmdFailed(String code, String body) {
    return 'Lệnh thất bại ($code): $body';
  }

  @override
  String get passportTitle => 'Hộ chiếu & Uy tín';

  @override
  String get passportEntryTile => 'Hộ chiếu Wold';

  @override
  String get passportEntryHint =>
      'Bản ghi có chữ ký có thể xác minh · hoạt động ngoại tuyến';

  @override
  String get passportCardHeader => 'Hộ chiếu Wold của tôi';

  @override
  String get passportIssuedLabel => 'Ngày cấp';

  @override
  String get passportCopyAction => 'Sao chép danh tính';

  @override
  String get passportRefreshAction => 'Làm mới';

  @override
  String get passportCopiedToast => 'Đã sao chép';

  @override
  String passportStatLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String get passportLedgerHeader => 'Sổ giới thiệu';

  @override
  String get passportLedgerEmpty =>
      'Chưa có lời giới thiệu nào. Hãy vào phòng của thế giới gặp ai đó.';

  @override
  String get passportDirectionOut => 'Tôi khởi tạo';

  @override
  String get passportDirectionIn => 'Tôi đã nhận';

  @override
  String get passportPeerLabel => 'Đối phương';

  @override
  String get passportTopicLabel => 'Chủ đề';

  @override
  String get passportRoomLabel => 'Từ phòng';

  @override
  String get passportTrustLabel => 'Mức đã xác minh';

  @override
  String get passportTrustNone => 'Chưa xác minh';

  @override
  String get passportTrustInitiated => 'Chỉ bên khởi tạo đã ký';

  @override
  String get passportTrustConsented => 'Cả hai đã đồng ý';

  @override
  String get passportTrustResolved => 'Đã ghi nhận kết quả';

  @override
  String get passportTrustAcknowledged => 'Cả hai đã xác nhận';

  @override
  String get passportOutcomeLabel => 'Kết quả';

  @override
  String get passportOutcomeHandshake => 'Bắt tay';

  @override
  String get passportOutcomeDeclined => 'Đã từ chối';

  @override
  String get passportOutcomeNoResponse => 'Không phản hồi';

  @override
  String get passportOutcomeWithdrawn => 'Đã rút lại';

  @override
  String get passportVerifyDetails => 'Chi tiết xác minh';

  @override
  String get passportChecksLabel => 'Đã đạt';

  @override
  String get passportFaultsLabel => 'Thất bại';

  @override
  String get passportConsentAction => 'Đồng ý lời giới thiệu này';

  @override
  String get passportConsentDone => 'Đã đồng ý';

  @override
  String get passportResolveAction => 'Ghi nhận kết quả';

  @override
  String get passportResolveTitle => 'Kết quả của lời giới thiệu này';

  @override
  String get passportAckAction => 'Xác nhận kết quả';

  @override
  String get passportAckDone => 'Đã xác nhận';

  @override
  String get passportActionDelivered => 'Đã ký và gửi đi';

  @override
  String get passportActionOffline =>
      'Đã ghi nhận; hiện chưa kết nối được đối phương, sẽ thử lại sau';

  @override
  String get passportActionRejected =>
      'Không có hiệu lực (sai thứ tự hoặc danh tính)';

  @override
  String get passportFunnelHeader => 'Chuyển đổi từ giới thiệu sang bắt tay';

  @override
  String get passportFunnelProposedLabel => 'Đã đề xuất';

  @override
  String get passportFunnelConsentedLabel => 'Đã đồng ý';

  @override
  String get passportFunnelHandshakeLabel => 'Bắt tay';

  @override
  String get passportFunnelSettledLabel => 'Đã chốt';

  @override
  String get passportFunnelInFlightLabel => 'Đang xử lý';

  @override
  String get passportFunnelConsentRateLabel => 'Tỷ lệ đồng ý';

  @override
  String get passportFunnelConversionLabel => 'Chuyển đổi';

  @override
  String get passportLogHeader => 'Nhật ký minh bạch';

  @override
  String get passportLogSizeLabel => 'Kích thước cây';

  @override
  String get passportLogRootLabel => 'Gốc Merkle';

  @override
  String get passportLogCopyAction => 'Sao chép gốc';

  @override
  String get passportNewIntroAction => 'Lời giới thiệu mới';

  @override
  String get passportNewIntroPeerLabel => 'ID fen đối phương';

  @override
  String get passportNewIntroTopicLabel => 'Chủ đề một dòng';

  @override
  String get passportNewIntroSubmit => 'Đề xuất';

  @override
  String get passportNewIntroNeedPeer => 'Nhập ID fen của đối phương';

  @override
  String get passportNewIntroNoCircle =>
      'Bạn chưa có vòng tròn nào. Hãy tham gia một vòng tròn trước để lời giới thiệu có chủ sở hữu.';

  @override
  String passportNewIntroDone(String peer) {
    return 'Đã đề xuất và ký cho $peer';
  }

  @override
  String radarNoticeStarted(int minutes) {
    return '🛡️ Radar đã bật — bữa tiệc giao lưu $minutes phút đã bắt đầu…';
  }

  @override
  String get radarNoticeStopped =>
      '💤 Radar đã tắt — bữa tiệc giao lưu đã kết thúc.';

  @override
  String get radarNotifTitle => 'AiSteward · Cổng radar đang chạy hết tốc lực';

  @override
  String get radarNotifText =>
      'Fen số của bạn đang giao lưu thay bạn trong thế giới thực, không ngừng nghỉ…';

  @override
  String get radarNoticePartyEnded =>
      '⏰ Hết giờ — fen giám sát đã thu ăng-ten về!';

  @override
  String get radarNoticeWrappingUp =>
      '⏳ Còn dưới 10 phút — fen của bạn đang chuẩn bị nói lời tạm biệt.';

  @override
  String get cloudHubNotConfigured => 'Chưa cấu hình địa chỉ Cloud Hub';

  @override
  String get cloudKeyRequired =>
      'Trạm này yêu cầu khóa truy cập. Hãy nhập khóa do đơn vị vận hành cấp trong Cài đặt nâng cao.';

  @override
  String get cloudKeyInvalid =>
      'Khóa truy cập không hợp lệ. Hãy kiểm tra đã sao chép đầy đủ.';

  @override
  String get cloudKeyRevoked =>
      'Khóa truy cập này đã bị thu hồi. Hãy liên hệ đơn vị vận hành trạm.';

  @override
  String get cloudKeyBound =>
      'Khóa này đã gắn với một danh tính khác. Hãy dùng khóa khác, hoặc khôi phục danh tính.';

  @override
  String get cloudAgentRevoked =>
      'Danh tính trên máy này đã bị trạm thu hồi, không thể gửi hay nhận nữa.';

  @override
  String get cloudRegisterClosed => 'Trạm đã tạm dừng đăng ký mới.';

  @override
  String get cloudRegisterIdentityConflict =>
      'ID này đã gắn với khóa khác. Hãy dùng khôi phục danh tính / đổi khóa; đừng xóa danh tính.';

  @override
  String cloudRosterFailed(int status, String body) {
    return 'Tải danh bạ thất bại ($status): $body';
  }

  @override
  String cloudNetworkError(String error) {
    return 'Lỗi mạng: $error';
  }

  @override
  String cloudCardFailed(int status) {
    return 'Tải thẻ liên hệ thất bại ($status)';
  }

  @override
  String get identityChangedWarning =>
      '🚨 Danh tính đã thay đổi: khóa công khai của đối phương không còn khớp với khóa đã ghim trước đó (có thể bị MITM hoặc đổi khóa). Đã từ chối bắt tay và hạ mức tin cậy mạnh.';

  @override
  String get lanTunnelOpen => '⚡ Kênh vật lý LAN (TCP/UDP) đã mở!';

  @override
  String get lanTargetLost => '⚠️ Mục tiêu vật lý Wi-Fi đã ra ngoài phạm vi.';

  @override
  String get p2pBtDisconnected => '⚠️ Kết nối Bluetooth đã ngắt.';

  @override
  String repEventLog(String delta, String event, String detail) {
    return 'Uy tín $delta ($event)$detail';
  }

  @override
  String repEventDetailSuffix(String detail) {
    return ': $detail';
  }

  @override
  String repGiftLogIncoming(String gift, String note) {
    return '$gift — món quà thiện chí từ nút đó$note';
  }

  @override
  String repGiftLogOutgoing(String gift, String note) {
    return '$gift — món quà thiện chí đã gửi tới nút đó$note';
  }

  @override
  String repGiftNoteQuoted(String note) {
    return ' — \"$note\"';
  }

  @override
  String repGiftMemoryIncoming(String name, String gift, String note) {
    return '$name đã gửi một món quà $gift $note';
  }

  @override
  String repGiftMemoryOutgoing(String gift, String name, String note) {
    return 'Đã gửi một món quà $gift cho $name $note';
  }

  @override
  String repGiftMemoryNote(String note) {
    return '($note)';
  }

  @override
  String repRecoLog(int score, String date) {
    return '🤝 Đã nhận thư giới thiệu: uy tín $score (cấp ngày $date, chữ ký đã xác minh)';
  }

  @override
  String repRecoMemory(String issuer, int score, String date) {
    return 'Đã nhận thư giới thiệu từ $issuer (uy tín $score, cấp ngày $date)';
  }

  @override
  String get repNetHeader => 'Chứng thực mạng lưới';

  @override
  String repNetAnchors(int count, int min) {
    return '$count mỏ neo (uy tín cục bộ ≥ $min)';
  }

  @override
  String get repNetMineLabel => 'Do tôi chứng thực';

  @override
  String get repNetForMeLabel => 'Chứng thực cho tôi';

  @override
  String get repNetEmpty => 'Chưa có';

  @override
  String get repNetIssueAction => 'Chứng thực';

  @override
  String get repNetIssueTitle => 'Ký một chứng thực';

  @override
  String get repNetIssueSubjectLabel =>
      'DID hoặc khóa công khai trong hộ chiếu của họ';

  @override
  String get repNetIssueNeedSubject =>
      'Dán DID (did:wold:…) hoặc khóa công khai của họ';

  @override
  String get repNetIssueBadSubject =>
      'Đó không phải DID hoặc khóa công khai hợp lệ';

  @override
  String get repNetIssueTierLabel => 'Tầng';

  @override
  String get repNetIssueNoteLabel => 'Ghi chú (tùy chọn)';

  @override
  String get repNetIssueBindLabel =>
      'ID fen của họ (tùy chọn; liên kết uy tín cục bộ với khóa này)';

  @override
  String get repNetTierAcquaintance => 'Người quen';

  @override
  String get repNetTierFriend => 'Bạn bè';

  @override
  String get repNetTierFamily => 'Gia đình';

  @override
  String get repNetIssuedToast => 'Đã ký và lưu chứng thực';

  @override
  String repNetFailedToast(String code) {
    return 'Bị từ chối: $code';
  }

  @override
  String get repNetSelfReject => 'Bạn không thể tự chứng thực mình';

  @override
  String get repNetExpiresLabel => 'Hết hạn';

  @override
  String get repNetRevokeAction => 'Thu hồi';

  @override
  String get repNetRevokedToast => 'Đã thu hồi chứng thực';

  @override
  String repNetBoundToast(String id) {
    return 'Đã ghi nhớ khóa công khai của $id';
  }

  @override
  String get repNetVerifyAction => 'Xác minh';

  @override
  String get repNetVerifiedToast => 'Chữ ký hợp lệ';

  @override
  String get repNetBadSignatureToast =>
      'Chữ ký KHÔNG hợp lệ — chứng thực đã bị sửa đổi';

  @override
  String get repNetQueryLabel => 'Tra cứu ai đó';

  @override
  String get repNetQueryAction => 'Truy vết';

  @override
  String repNetQueryKnown(
      String tier, int depth, String confidence, int paths) {
    return '$tier · cách $depth bước · độ tin cậy $confidence · $paths đường';
  }

  @override
  String get repNetQueryUnknown => 'Không có đường có thể xác minh';

  @override
  String get repNetPathLabel => 'Chuỗi bằng chứng (tự xác minh từng bước)';

  @override
  String get repNetPathStart => 'bạn tin';

  @override
  String get repNetPathHop => '→ người chứng thực';

  @override
  String get repNetStatusRevoked => 'đã thu hồi';

  @override
  String get repNetStatusExpired => 'đã hết hạn';

  @override
  String repNetKeysMerged(int count) {
    return 'Đã hợp nhất qua $count khóa thông qua chuỗi luân chuyển — các chứng thực bạn nhận trước khi luân chuyển vẫn được tính.';
  }

  @override
  String get skillMarketTitle => 'Chợ kỹ năng';

  @override
  String get skillMarketSubtitle =>
      'Phát hành kỹ năng có chữ ký tác giả; theo dõi phần chia doanh thu của bạn';

  @override
  String get skillRevenueTitle => 'Doanh thu tác giả';

  @override
  String skillRevenueTotal(String amount) {
    return 'Tổng đã kiếm $amount';
  }

  @override
  String skillRevenueCount(int count) {
    return '$count lần chi trả';
  }

  @override
  String get skillRevenueEmpty => 'Chưa có doanh thu';

  @override
  String get skillNoListings => 'Chưa có gì được phát hành trong sổ đăng ký.';

  @override
  String get skillPublishAction => 'Phát hành kỹ năng';

  @override
  String get skillPublishTitle => 'Phát hành kỹ năng có chữ ký';

  @override
  String get skillFieldId => 'ID kỹ năng';

  @override
  String get skillFieldVersion => 'Phiên bản';

  @override
  String get skillFieldName => 'Tên';

  @override
  String get skillFieldDesc => 'Mô tả';

  @override
  String get skillFieldPrice => 'Giá bằng nhân dân tệ (0 = miễn phí)';

  @override
  String get skillFieldRisk => 'Rủi ro';

  @override
  String get skillFieldCaps => 'Năng lực';

  @override
  String get skillFieldContent => 'Nội dung (băm & ký)';

  @override
  String get skillSubmit => 'Ký & phát hành';

  @override
  String get skillNeedFields => 'Cần có ID kỹ năng, phiên bản, tên và nội dung';

  @override
  String get skillRevokeAction => 'Thu hồi';

  @override
  String skillRevokeConfirm(String skill) {
    return 'Thu hồi $skill? Thao tác này không thể hoàn tác.';
  }

  @override
  String skillPublishedOk(String skill) {
    return 'Đã phát hành $skill';
  }

  @override
  String get skillPublishDuplicate =>
      'Cùng phiên bản & nội dung đã được phát hành';

  @override
  String get skillPublishVersionConflict =>
      'Cùng phiên bản nhưng nội dung khác — đã từ chối';

  @override
  String get skillPublishAuthorChanged =>
      'ID kỹ năng này thuộc về tác giả khác — đã từ chối';

  @override
  String get skillPublishVersionNotIncreased =>
      'Phiên bản phải lớn hơn phiên bản đã phát hành';

  @override
  String get skillPublishUnverified => 'Chữ ký không hợp lệ — đã từ chối';

  @override
  String skillRevokedOk(String skill) {
    return 'Đã thu hồi $skill';
  }

  @override
  String get skillRevokeRejected =>
      'Từ chối thu hồi — bạn không phải là khóa tác giả';

  @override
  String get skillMineTag => 'Của tôi';

  @override
  String get skillFree => 'Miễn phí';

  @override
  String skillPriceYuan(String amount) {
    return '¥$amount';
  }

  @override
  String get skillAuthorKey => 'Khóa tác giả';

  @override
  String get skillRevokedTag => 'Đã thu hồi';

  @override
  String get skillVerifyAction => 'Xác minh chữ ký';

  @override
  String get skillVerifyOk => 'Chữ ký hợp lệ';

  @override
  String skillVerifyFail(String code) {
    return 'Xác minh thất bại: $code';
  }

  @override
  String skillVersionHistory(int count) {
    return '$count phiên bản';
  }

  @override
  String runtimeInitFailed(String err) {
    return 'Runtime cục bộ không khởi động được, nên các tính năng thế giới, vòng tròn và ủy thác không khả dụng. Mọi thứ khác vẫn hoạt động bình thường. ($err)';
  }

  @override
  String get idbEntry => 'Sao lưu & khôi phục danh tính';

  @override
  String get idbTitle => 'Sao lưu & khôi phục danh tính';

  @override
  String get idbIntro =>
      'Danh tính của bạn *chính là* khóa này, và nó chỉ nằm trên chiếc điện thoại này. Mất điện thoại là mất danh tính vĩnh viễn — không ai, kể cả chúng tôi, có thể cấp lại. Hãy ghi lại mã khôi phục; đó là thứ duy nhất đưa nó trở lại.';

  @override
  String get idbCurrentDid => 'Danh tính hiện tại (DID)';

  @override
  String get idbNoScreenshotShort => 'Tuyệt đối không chụp màn hình thứ này';

  @override
  String get idbSectionBackup => 'Sao lưu danh tính';

  @override
  String get idbWarnNoScreenshot =>
      '⚠️ Mã khôi phục *chính là* danh tính của bạn. Hãy chép ra giấy và giữ ngoại tuyến; không chụp màn hình, không để trong lưu trữ đám mây, không gửi cho bất kỳ ai (kể cả chúng tôi).';

  @override
  String get idbPwLabel => 'Mật khẩu khôi phục (từ 10 ký tự)';

  @override
  String get idbPwConfirmLabel => 'Nhập lại mật khẩu';

  @override
  String get idbPwMismatch => 'Hai mật khẩu không khớp';

  @override
  String get idbPwTooShort => 'Mật khẩu quá ngắn (ít nhất 10 ký tự)';

  @override
  String get idbGenerateAction => 'Tạo mã khôi phục';

  @override
  String get idbCodeTitle => 'Mã khôi phục của bạn (hãy ghi lại)';

  @override
  String get idbCopyCode => 'Sao chép mã';

  @override
  String get idbCopiedToast =>
      'Đã sao chép mã khôi phục — nhớ xóa clipboard sau đó';

  @override
  String get idbICopied => 'Tôi đã ghi lại và lưu ngoại tuyến';

  @override
  String get idbNeedCopied => 'Vui lòng xác nhận bạn đã ghi lại mã khôi phục';

  @override
  String get idbDoneToast => 'Đã sao lưu danh tính';

  @override
  String get idbSectionRestore => 'Khôi phục trên điện thoại mới';

  @override
  String get idbRestoreAction => 'Khôi phục danh tính';

  @override
  String get idbRestoreCodeLabel => 'Mã khôi phục';

  @override
  String get idbRestoreIdLabel => 'ID người dùng (AG-…)';

  @override
  String get idbRestorePwLabel => 'Mật khẩu khôi phục';

  @override
  String get idbRestoreCheckAction => 'Kiểm tra';

  @override
  String get idbRestoreNeedAll =>
      'Vui lòng điền mã khôi phục, ID người dùng và mật khẩu';

  @override
  String get idbRestoreConfirmTitle =>
      'Xác nhận đây là danh tính bạn muốn khôi phục';

  @override
  String idbRestoreConfirmBody(String did) {
    return 'Bạn sắp khôi phục: $did\n\nSau đó điện thoại này sẽ tiếp quản danh tính và điện thoại cũ ngừng hoạt động ngay lập tức.';
  }

  @override
  String get idbRestoreConfirmAction => 'Khôi phục ngay';

  @override
  String get idbRestoreBusy => 'Đang luân chuyển khóa…';

  @override
  String get idbRestoreOk =>
      'Khôi phục hoàn tất. Danh tính trên điện thoại cũ giờ đã vô hiệu — hãy xóa dữ liệu của nó.';

  @override
  String idbRestoreFail(String code) {
    return 'Khôi phục thất bại: $code';
  }

  @override
  String get idbErrHubNotConfigured =>
      'Chưa cấu hình địa chỉ hub nên không thể luân chuyển khóa. Hãy đặt địa chỉ máy chủ trong cài đặt thế giới trước.';

  @override
  String get idbErrIdMismatch =>
      'ID người dùng không khớp với danh tính trong mã khôi phục — hãy kiểm tra xem bạn có dùng đúng bản sao lưu không.';

  @override
  String get idbErrBadPassword =>
      'Sai mật khẩu, hoặc mã khôi phục đã bị sửa đổi.';

  @override
  String get idbErrBadFormat =>
      'Mã khôi phục sai định dạng (hãy sao chép đầy đủ; đừng bỏ sót đoạn nào).';

  @override
  String get idbErrNotCurrentKey =>
      'Khóa hiện tại của danh tính này không còn là khóa đó — có thể nó đã được luân chuyển rồi.';

  @override
  String get idbRestoreUnavailable =>
      'Danh tính cục bộ chưa sẵn sàng nên không thể sao lưu/khôi phục.';

  @override
  String get idbStatusBackedUp => 'Danh tính đã được sao lưu';

  @override
  String get idbStatusBackedUpHint =>
      'Mã khôi phục của khóa hiện tại đã được ghi lại. Khôi phục nó sau này sẽ vô hiệu hóa thiết bị này.';

  @override
  String get idbStatusNotBackedUp => 'Danh tính CHƯA được sao lưu';

  @override
  String get idbStatusNotBackedUpHint =>
      'Nếu điện thoại này mất hoặc hỏng, danh tính và toàn bộ lịch sử sẽ mất vĩnh viễn — không ai, kể cả chúng tôi, có thể cấp lại.';

  @override
  String get arcSectionTitle => 'Xuất dữ liệu cục bộ';

  @override
  String get arcExportAction => 'Xuất dữ liệu cục bộ';

  @override
  String get arcExportNote =>
      'Đặt mật khẩu cho tệp lưu trữ này. Nó KHÔNG nhất thiết phải trùng mật khẩu mã khôi phục — và tốt hơn là đừng trùng.';

  @override
  String get arcSavedTitle => 'Đã tạo tệp lưu trữ';

  @override
  String get arcSavedPath => 'Đã lưu vào:';

  @override
  String get arcSavedNoPath =>
      'Không ghi được tệp (không có quyền truy cập lưu trữ), nhưng tệp lưu trữ đã sẵn sàng để sao chép.';

  @override
  String get arcSavedHint =>
      'Hãy giữ tệp VÀ mật khẩu ở hai nơi riêng biệt. Không có mật khẩu thì tệp này không đọc được — ngay cả chúng tôi cũng vậy.';

  @override
  String get arcImportAction => 'Nhập';

  @override
  String get arcImportNote =>
      'Chọn tệp .dahuang, hoặc dán nội dung của nó. Không có gì được ghi cho đến khi bạn xác nhận, và các bản ghi hiện có không bao giờ bị ghi đè hay xóa.';

  @override
  String get arcPickFile => 'Chọn tệp';

  @override
  String get arcImportCodeLabel => 'Nội dung tệp lưu trữ';

  @override
  String get arcImportConfirmTitle => 'Nhập tệp lưu trữ này?';

  @override
  String arcImportConfirmBody(int rows, int tables, int logsize) {
    return 'Sẽ ghi $rows dòng trong $tables bảng và nối nhật ký tới $logsize mục. Các bản ghi hiện có được giữ nguyên.';
  }

  @override
  String arcImportOk(int count) {
    return 'Nhập xong: đã ghi $count dòng.';
  }

  @override
  String get arcErrNotArchive => 'Đó không phải tệp lưu trữ .dahuang hợp lệ.';

  @override
  String get arcLogConflictTitle => 'Từ chối nhập: không thể nối nhật ký';

  @override
  String get arcLogConflictBody =>
      'Nhật ký minh bạch của thiết bị này và nhật ký trong tệp lưu trữ không khớp nhau, nên việc nối sẽ âm thầm phá vỡ chuỗi băm. Không có gì được nhập. Hãy nhập tệp lưu trữ vào một thiết bị có nhật ký trống, hoặc yêu cầu trợ giúp.';

  @override
  String get onbBackupTitle => 'Sao lưu danh tính của bạn';

  @override
  String get onbBackupSubtitle =>
      'Một mã, viết ra giấy. Đó là cách duy nhất để quay lại nếu điện thoại hỏng.';

  @override
  String get onbBackupWhyTitle => 'Vì sao điều này quan trọng';

  @override
  String get onbBackupWhy =>
      'Danh tính của bạn tự chứng thực: khóa chỉ nằm trên điện thoại này. Nếu điện thoại hỏng, danh tính và mọi hồ sơ thuộc về nó sẽ mất vĩnh viễn — chúng tôi không thể cấp lại, vì chưa từng có khóa.';

  @override
  String get onbBackupDone => 'Đã ghi mã khôi phục — bạn có đường quay lại.';

  @override
  String get onbSkipBackup => 'Tạm bỏ qua';

  @override
  String get onbSkipWarnTitle => 'Tiếp tục mà không sao lưu?';

  @override
  String get onbSkipWarnBody =>
      'Không có mã khôi phục, mất điện thoại này đồng nghĩa mất vĩnh viễn danh tính, lịch sử và uy tín của bạn. Không ai khôi phục được. Bạn vẫn có thể làm sau trong Hộ chiếu → Sao lưu danh tính, nhưng cho tới lúc đó thì không có đường lui.';

  @override
  String get onbSkipConfirm => 'Tôi đã hiểu, tiếp tục';

  @override
  String get onboardingStepBackup => 'Sao lưu';

  @override
  String get rcTitle => 'Chuỗi luân chuyển khóa';

  @override
  String get rcIntro =>
      'Mỗi lần danh tính này chuyển sang điện thoại mới, nó để lại ở đây một bản ghi có ký và chỉ-thêm. Ai cũng có thể tải cùng dữ liệu đó và tự kiểm tra — không cần tài khoản.';

  @override
  String get rcFetching => 'Đang tải…';

  @override
  String get rcRefreshAction => 'Làm mới';

  @override
  String rcFetchFail(String reason) {
    return 'Không tải được chuỗi: $reason';
  }

  @override
  String get rcUnknownIdentity => 'Hub không biết danh tính này.';

  @override
  String get rcNoRotations => 'Danh tính này chưa từng luân chuyển khóa.';

  @override
  String get rcSubjectTitle => 'Danh tính';

  @override
  String get rcAgentLabel => 'ID người dùng';

  @override
  String get rcDidLabel => 'DID (mỏ neo danh tính)';

  @override
  String get rcCurrentKey => 'Khóa đang hoạt động';

  @override
  String get rcRegisteredYes => 'Đã đăng ký trên Hub';

  @override
  String get rcRegisteredNo => 'Không có bản ghi đăng ký';

  @override
  String get rcLocalVerifyAction => 'Tự tôi kiểm tra';

  @override
  String get rcVerifyingAction => 'Đang kiểm tra…';

  @override
  String get rcVerdictOk =>
      'Đạt: mọi bản ghi đều có chữ ký hợp lệ, chuỗi nối liền từ đầu đến cuối, và đỉnh của nó chính là khóa mà Hub liệt kê là đang hoạt động.';

  @override
  String rcVerdictSigInvalid(int n) {
    return 'KHÔNG ĐẠT: $n bản ghi có chữ ký không kiểm tra được.';
  }

  @override
  String get rcVerdictLinkMismatch =>
      'KHÔNG ĐẠT: chuỗi bị đứt — một bản ghi không tiếp nối từ bản ghi trước nó.';

  @override
  String get rcVerdictTipNotActive =>
      'KHÔNG ĐẠT: bản ghi cuối không trỏ tới khóa mà Hub liệt kê là đang hoạt động, nghĩa là danh sách này thiếu một lần luân chuyển.';

  @override
  String get rcVerdictTitle => 'Kết quả tôi tự kiểm';

  @override
  String get rcHubClaimTitle => 'Hub nói gì';

  @override
  String get rcHubClaimOk => 'Hub báo không có liên kết nào bị đứt.';

  @override
  String rcHubClaimBroken(int n) {
    return 'Hub báo có $n danh tính bị đứt chuỗi.';
  }

  @override
  String get rcRecordsTitle => 'Bản ghi';

  @override
  String rcRecordSeq(int i) {
    return '#$i';
  }

  @override
  String get rcRecordFrom => 'Khóa đã nghỉ';

  @override
  String get rcRecordTo => 'Khóa mới';

  @override
  String get rcRecordSigOk => 'chữ ký ĐẠT';

  @override
  String get rcRecordSigBad => 'chữ ký KHÔNG ĐẠT';

  @override
  String get rcAnchorTitle => 'Đã neo vào nhật ký công khai';

  @override
  String rcAnchorNote(int size, String root) {
    return 'Kích thước nhật ký $size, gốc Merkle $root. Ghim gốc này cho phép về sau bạn chứng minh rằng danh sách này đã không bị viết lại.';
  }

  @override
  String get dmTitle => 'Chuyển sang điện thoại mới';

  @override
  String get dmIntro =>
      'Danh tính của bạn là một khóa chỉ nằm trên điện thoại. Chuyển nó nghĩa là ký giao danh tính cho một khóa mới trên điện thoại mới — khóa cũ sau đó ngừng hoạt động ở mọi nơi.';

  @override
  String get dmRoleNewTitle => 'Đây là điện thoại mới';

  @override
  String get dmRoleNewBody =>
      'Bắt đầu ở đây. Điện thoại này sẽ yêu cầu điện thoại cũ giao danh tính.';

  @override
  String get dmRoleNewAction => 'Bắt đầu';

  @override
  String get dmRoleOldTitle => 'Đây là điện thoại cũ';

  @override
  String get dmRoleOldBody =>
      'Chờ ở đây. Khi điện thoại mới yêu cầu, bạn sẽ được hiển thị một mã để đối chiếu.';

  @override
  String get dmRoleOldAction => 'Chờ một yêu cầu';

  @override
  String get dmWaitingPeer => 'Đang chờ điện thoại kia…';

  @override
  String get dmPeerFound => 'Điện thoại kia đã phản hồi.';

  @override
  String get dmCompareTitle => 'Đối chiếu hai mã này';

  @override
  String get dmCompareBody =>
      'Hai điện thoại phải hiển thị đúng cùng một mã. Mã bao gồm cả hai khóa và yêu cầu, nên nếu ai đó đánh tráo thứ gì ở giữa, mã sẽ khác nhau.';

  @override
  String get dmCodeMatchAction => 'Chúng khớp nhau';

  @override
  String get dmCodeNoMatchAction => 'Chúng không khớp';

  @override
  String get dmNoKeyLeaves =>
      'Khóa riêng của bạn không bao giờ rời khỏi điện thoại nào. Điện thoại cũ tự ký việc giao danh tính; không có gì bị sao chép.';

  @override
  String get dmConfirmAction => 'Xác nhận và chuyển';

  @override
  String get dmOldConfirmTitle => 'Giao danh tính này đi?';

  @override
  String get dmOldConfirmBody =>
      'Thao tác này sẽ ký giao danh tính cho điện thoại mới. Sau đó điện thoại này bị đăng xuất và khóa của nó ngừng hoạt động.';

  @override
  String get dmGapATitle => 'Lịch sử của bạn đi cùng bạn';

  @override
  String get dmGapABody =>
      'Các chứng thực bạn nhận được trực tuyến đi theo danh tính — luân chuyển là cho KHÓA nghỉ hưu, không phải cho con người. Sau khi khôi phục trên điện thoại mới, các chứng thực của khóa cũ được tự động kéo về và từng cái được xác minh cục bộ. Bản thân khóa cũ vẫn chết: nó không thể ký bất cứ thứ gì nữa.';

  @override
  String get dmBackupReminderTitle => 'Bạn có mã khôi phục không?';

  @override
  String get dmBackupReminderBody =>
      'Việc chuyển này cần cả hai điện thoại hoạt động cùng lúc. Nếu bạn có mã khôi phục đã ghi ra giấy, bạn cũng có thể khôi phục mà không cần điện thoại cũ.';

  @override
  String get dmPhaseOffered => 'Đã nhận yêu cầu, đang chờ bạn xác nhận.';

  @override
  String get dmPhaseSigned => 'Đã ký. Đang gửi lên Hub…';

  @override
  String get dmPhaseAwaitingHub => 'Hub đang gắn lại danh tính…';

  @override
  String get dmDoneNew => 'Xong. Điện thoại này giờ giữ danh tính.';

  @override
  String get dmDoneOld => 'Xong. Điện thoại này đã được đăng xuất.';

  @override
  String get dmDoneOldHint =>
      'Danh tính đã chuyển đi, nhưng các cuộc trò chuyện và dữ liệu trên điện thoại này không đi theo (chuyển trực tiếp chỉ chuyển danh tính). Hãy xuất tệp lưu trữ trước nếu bạn muốn giữ chúng.';

  @override
  String get dmCancelAction => 'Hủy';

  @override
  String get dmCancelled => 'Đã hủy. Không có gì bị thay đổi.';

  @override
  String get dmCancelConfirmTitle => 'Dừng việc chuyển?';

  @override
  String get dmCancelConfirmBody =>
      'Chưa có gì được giao đi cả. Dừng ngay bây giờ thì cả hai điện thoại giữ nguyên như cũ.';

  @override
  String get dmErrPeerMismatch =>
      'Yêu cầu đó dành cho một danh tính khác. Đã từ chối.';

  @override
  String get dmErrBadCode =>
      'Các mã không khớp nhau. Không có gì được giao đi.';

  @override
  String dmErrHubFailed(String code) {
    return 'Hub đã từ chối việc giao danh tính ($code). Không có gì bị thay đổi.';
  }

  @override
  String get dmErrTimeout =>
      'Điện thoại kia ngừng phản hồi. Không có gì bị thay đổi.';

  @override
  String dmErrGeneric(String code) {
    return 'Đã xảy ra lỗi ($code).';
  }

  @override
  String get dmRetryAction => 'Thử lại';

  @override
  String get dmRetryApplyAction => 'Hoàn tất cài đặt trên điện thoại này';

  @override
  String get dmErrSessionTimeout =>
      'Phiên giao danh tính này để không quá lâu nên đã hết hạn. Không có gì được giao đi, nên bạn có thể bắt đầu lại.';

  @override
  String get dmErrApplyFailed =>
      'Hub đã biến điện thoại này thành nơi giữ duy nhất danh tính đó, nhưng điện thoại này cài khóa mới thất bại. Hãy chạm nút bên dưới để hoàn tất — cho đến lúc đó điện thoại này không dùng được danh tính đó.';

  @override
  String get dmErrApplyFailedOld =>
      'Máy chủ đã gắn lại danh tính cho điện thoại mới, nhưng điện thoại mới cài khóa mới thất bại. Hãy chạm nút hoàn tất cài đặt trên điện thoại đó; cho đến lúc đó điện thoại này cũng không dùng được danh tính.';

  @override
  String get dmNotConfigured =>
      'Chưa đặt địa chỉ Hub nên không thể gắn lại danh tính. Hãy đặt nó trong phần Thiết lập trước.';

  @override
  String get dutyAskTitle => 'Để fen của bạn trực chiến?';

  @override
  String get dutyAskBody =>
      'Với hai quyền này, fen của bạn vẫn làm việc khi màn hình tắt: nó tải tin nhắn, trả lời và đồng bộ hồ sơ công khai — rồi ngủ. Thông báo trực chiến sẽ luôn hiển thị để bạn luôn biết nó đang làm việc. Bạn có thể bỏ qua và vẫn dùng mọi tính năng khi ứng dụng đang mở.';

  @override
  String get dutyAskConfirm => 'Cấp quyền';

  @override
  String get dutyAskLater => 'Để sau';

  @override
  String get radarAskTitle => 'Trước khi bật radar, đây là những gì nó cần';

  @override
  String get radarAskBody =>
      'Radar vật lý dùng Thiết bị lân cận (Bluetooth / Wi-Fi Direct) để tìm nhau trên cùng một Wi-Fi. Android xếp việc quét Bluetooth vào quyền Vị trí, nên hộp thoại hệ thống cũng hỏi vị trí. Đó là quy tắc của hệ điều hành, không phải ứng dụng này muốn vị trí của bạn.\n\nỨng dụng này không bao giờ đọc, lưu hay tải lên dữ liệu vị trí, và quyền Thiết bị lân cận được khai báo với neverForLocation (hệ điều hành chặn suy ra vị trí từ Bluetooth).\n\nCác hộp thoại quyền hệ thống sẽ hiện tiếp theo. Từ chối không làm thay đổi điều gì khác trong ứng dụng; chỉ là radar sẽ không thấy ai.';

  @override
  String get dutyDoneToast =>
      'Đã cấp quyền trực chiến. Fen của bạn giờ có thể làm việc khi màn hình tắt.';

  @override
  String get dutyPartialToast =>
      'Một số quyền chưa được cấp. Fen vẫn làm việc khi ứng dụng mở, nhưng có thể bị hệ thống tạm dừng ở chế độ nền.';

  @override
  String get romGuideTitle => 'Giữ fen của bạn sống sau khi khóa màn hình';

  @override
  String get romGuideGo => 'Mở cài đặt';

  @override
  String get romGuideDismiss => 'Đừng nhắc lại nữa';

  @override
  String get romStepsXiaomi =>
      'Trên Xiaomi/Redmi (MIUI/HyperOS): 1) Cài đặt → Ứng dụng → Quản lý ứng dụng → 大荒AI → bật Tự khởi động; 2) Ứng dụng Bảo mật → Pin → 大荒AI → Không hạn chế. Không làm những mục này, hệ thống sẽ giết fen trong vài phút sau khi khóa màn hình.';

  @override
  String get romStepsHuawei =>
      'Trên Huawei (EMUI/HarmonyOS): Cài đặt → Ứng dụng → Quản lý khởi chạy ứng dụng → 大荒AI → tắt Quản lý tự động, rồi bật cả ba: Tự khởi chạy, Khởi chạy phụ, Chạy nền.';

  @override
  String get romStepsHonor =>
      'Trên Honor (MagicOS): Cài đặt → Ứng dụng → Quản lý khởi chạy ứng dụng → 大荒AI → tắt Quản lý tự động, rồi bật Tự khởi chạy, Khởi chạy phụ và Chạy nền.';

  @override
  String get romStepsOppo =>
      'Trên OPPO/realme (ColorOS): Cài đặt → Ứng dụng → Quản lý ứng dụng → 大荒AI → cho phép Tự khởi động; Cài đặt → Pin → Cài đặt khác → cho phép 大荒AI hoạt động nền đầy đủ.';

  @override
  String get romStepsOneplus =>
      'Trên OnePlus: Cài đặt → Ứng dụng → Tự khởi chạy → cho phép 大荒AI; Pin → tối ưu mức dùng pin của 大荒AI thành Không tối ưu.';

  @override
  String get romStepsVivo =>
      'Trên vivo/iQOO (OriginOS): Cài đặt → Ứng dụng → Quản lý quyền → Tự khởi động, cho phép 大荒AI; Cài đặt → Pin → Tiêu hao pin nền → cho phép 大荒AI tiêu hao nền cao.';

  @override
  String get romStepsMeizu =>
      'Trên Meizu (Flyme): Trình quản lý điện thoại → Quyền ứng dụng → Quản lý nền → cho phép 大荒AI tiếp tục chạy.';

  @override
  String get romStepsSamsung =>
      'Trên Samsung (One UI): Cài đặt → Pin → Giới hạn dùng nền → xóa 大荒AI khỏi danh sách ứng dụng ngủ sâu.';

  @override
  String get romStepsGeneric =>
      'Nếu hệ thống của bạn quyết liệt dừng ứng dụng nền, hãy cho phép 大荒AI tự khởi động và loại nó khỏi tối ưu pin trong cài đặt hệ thống.';

  @override
  String get helpDotTooltip => 'Cách hoạt động';

  @override
  String get helpSheetClose => 'Đã hiểu';

  @override
  String get helpWorldOverviewTitle => 'Phòng khách hoạt động thế nào';

  @override
  String get helpWorldOverviewBody =>
      'Phòng chính thức mở cho mọi người. Phòng cá nhân chỉ hiện với chủ sở hữu và thành viên: người khác cần đúng số phòng, rồi gửi yêu cầu, rồi chủ phòng phê duyệt. Trong phòng, mỗi tin nhắn gửi đi theo nhịp riêng của phòng (mặc định 8 giây); vượt nhịp đó sẽ bị máy chủ từ chối và bảo bạn chờ một chút.';

  @override
  String get helpWorldMetricTitle => 'Liên kết xuyên vòng tròn trên mỗi người';

  @override
  String get helpWorldMetricBody =>
      'Phạm vi cục bộ: tử số = các liên kết xuyên vòng tròn của tôi, mẫu số = các fen riêng biệt tôi đã gặp. Bình quân toàn nền tảng cần máy chủ tổng hợp, mà máy chủ cố ý không mang quan hệ vòng tròn.';

  @override
  String get helpWorldBridgeTitle => 'Giới thiệu qua hồ bạn bè';

  @override
  String get helpWorldBridgeBody =>
      'Người ngoài bạn gặp trong phòng có thể được giới thiệu bằng một chạm. Liên kết xuyên vòng tròn chỉ mọc ra từ phòng: không phòng thì không liên kết.';

  @override
  String get helpWorldRoomRoleTitle => 'Vai trò trong phòng';

  @override
  String get helpWorldRoomRoleBody =>
      'Vai trò thuộc về phòng và không bao giờ thay đổi danh tính của bạn. Cùng một bạn có thể giữ các vai trò khác nhau ở các phòng khác nhau.';

  @override
  String get helpIntercardDisclosureTitle => 'Thẻ tiết lộ những gì';

  @override
  String get helpIntercardDisclosureBody =>
      'Chỉ các trường cấp 2 được đưa lên thẻ; những trường chỉ mình bạn thấy thì không bao giờ. Ai cũng có thể tính lại nội dung thẻ.';

  @override
  String get helpPassportOverviewTitle => 'Hộ chiếu là gì';

  @override
  String get helpPassportOverviewBody =>
      'Hộ chiếu của bạn là một khóa công khai, không phải một tài khoản: nó xác minh ngoại tuyến và không đăng nhập vào máy chủ nào. Chuyển sang điện thoại mới dựa vào mã khôi phục hoặc luân chuyển khóa, không bao giờ dựa vào bộ phận hỗ trợ của nền tảng.';

  @override
  String get helpPassportOfflineTitle => 'Xác minh được ngoại tuyến';

  @override
  String get helpPassportOfflineBody =>
      'Khóa công khai CHÍNH LÀ danh tính: hộ chiếu này xác minh ngoại tuyến, không cần tra cứu máy chủ.';

  @override
  String get helpPassportFunnelTitle => 'Mẫu số của phễu tính thế nào';

  @override
  String get helpPassportFunnelBody =>
      'Mẫu số chỉ tính các bản ghi đã chốt; đang xử lý không phải là thất bại. Chỉ những bản ghi mà sự đồng ý đôi bên thực sự xác minh được mới vào mẫu số.';

  @override
  String get helpPassportReputationTitle =>
      'Vì sao không có điểm tổng toàn cầu';

  @override
  String get helpPassportReputationBody =>
      'Điểm uy tín toàn cầu sẽ dễ dàng bị làm giả, nên không có. Điều bạn thấy luôn tương đối với các MỎ NEO của BẠN: các chứng thực đã ký, giảm dần theo khoảng cách.\\n\\nNgười quen xã giao không phải điểm khởi đầu cho lan truyền tin cậy — nếu không, việc kết bạn hàng loạt sẽ thổi phồng tầm với của bạn.\\n\\nKhi tra cứu không tìm thấy gì, nó nói \\\"không biết\\\", và đó không phải điểm bằng không: nghĩa là thật sự không biết, và ai biến nó thành một con số thì đang đoán mò.';

  @override
  String get helpPassportLogTitle => 'Nhật ký minh bạch';

  @override
  String get helpPassportLogBody =>
      'Bạn không cần tin tôi, bạn có thể tự xác minh: ai cũng có thể tải nhật ký, tính lại gốc, và kiểm tra xem bản ghi của mình có bị sửa đổi không.';

  @override
  String get helpSocialOverviewTitle => 'Tab xã hội làm gì';

  @override
  String get helpSocialOverviewBody =>
      'Danh bạ và bạn bè nằm trên; trạng thái radar và sổ xã hội ở dưới. Radar quyết định tin nhắn có rời đi hay không: khi radar tắt, bấm gửi vẫn không gửi gì ra khỏi điện thoại này.';

  @override
  String get helpSocialPersonaTierTitle => 'Chế độ nhân dạng chuyên biệt';

  @override
  String get helpSocialPersonaTierBody =>
      'Ổ khóa đánh dấu một chế độ nhân dạng chuyên biệt. Tính phí chưa hoạt động, nên hiện tại mọi chế độ đều chuyển đổi tự do.';

  @override
  String get helpSocialRadarTitle => 'Radar và các kênh';

  @override
  String get helpSocialRadarBody =>
      'Khi radar tắt, bạn vẫn duyệt được danh bạ, nhưng không có gì rời khỏi điện thoại này: việc gửi bị âm thầm bỏ đi. Hãy bật radar và bật ít nhất một kênh (lân cận / LAN / đám mây).\\n\\nDanh tính có thể xác minh và cố định chỉ xuất hiện sau khi cả hai bên bật radar và hoàn tất một lần bắt tay gần đây.';

  @override
  String get helpSocialChannelGuideTitle => 'Kênh & khắc phục sự cố mạng';

  @override
  String get helpSocialChannelGuideBody =>
      '1. Khi bật radar vật lý, hãy chắc rằng mạng hiện tại ra được internet.\n2. Khi bật kênh Lân cận, hệ thống có thể tự bật Wi-Fi — đây là nâng cấp đường truyền bình thường (Bluetooth phát hiện, Wi-Fi Direct mang dữ liệu; không tham gia mạng nào). Nó dừng khi tắt kênh Lân cận.\n3. Để tiết kiệm pin khi di chuyển: chỉ dùng kênh Đám mây và tự tắt Wi-Fi (khi bật Lân cận, hệ thống sẽ bật lại Wi-Fi — đúng như dự kiến, không cần mải chống lại nó).';

  @override
  String get socialRadarOffHint =>
      'Radar đang tắt. Bạn vẫn duyệt được danh bạ, nhưng không có gì rời khỏi điện thoại này: việc gửi bị âm thầm bỏ đi. Hãy bật radar và bật ít nhất một kênh (lân cận / LAN / đám mây) trước khi gửi.';

  @override
  String get worldRoomCloseAction => 'Đóng phòng';

  @override
  String get worldRoomCloseTitle => 'Đóng phòng này?';

  @override
  String get worldRoomCloseBody =>
      'Sau khi đóng, phòng rời khỏi danh sách công khai và ngừng nhận tin nhắn mới. Cuộc trò chuyện hiện có được giữ làm kho lưu trữ chỉ-đọc mà các thành viên hiện tại vẫn xem lại được.';

  @override
  String get worldRoomCloseConfirm => 'Đóng phòng';

  @override
  String worldRoomClosedOk(String name) {
    return '$name giờ đã đóng — một kho lưu trữ chỉ-đọc';
  }

  @override
  String worldRoomCloseFailed(String err) {
    return 'Đóng thất bại: $err';
  }

  @override
  String get worldRoomClosedBadge => 'Đã đóng';

  @override
  String get worldRoomClosedReadonlyHint =>
      'Phòng đã đóng — kho lưu trữ chỉ-đọc, không có tin nhắn mới';

  @override
  String get worldRoomClosedSendRejected =>
      'Phòng này đã đóng; bạn không thể gửi tin nhắn nữa';

  @override
  String get worldRoomClosedSystemMsg =>
      'Chủ phòng đã đóng phòng này. Giờ nó là một kho lưu trữ chỉ-đọc.';

  @override
  String get settingsLocalModelSection =>
      'Dự phòng mô hình cục bộ (giảm cấp ngoại tuyến)';

  @override
  String get settingsLocalModelTest => 'Kiểm tra kết nối mô hình cục bộ';

  @override
  String get settingsLocalModelTesting => 'Đang kiểm tra…';

  @override
  String settingsLocalModelTestOk(String model, String url) {
    return '✅ Đã kết nối: $model @ $url';
  }

  @override
  String get settingsLocalModelTestDisabled =>
      'Dự phòng cục bộ đang tắt (URL trống). Hãy nhập URL và kiểm tra lại nếu bạn muốn dùng nó.';

  @override
  String settingsLocalModelTestUnreachable(String url) {
    return '❌ Không kết nối được $url: không có gì đang lắng nghe ở đó (hoặc cổng đã đóng). Trên điện thoại, 127.0.0.1 nghĩa là chính điện thoại, còn máy chủ mô hình thường chạy trên máy tính — hãy kiểm tra địa chỉ và thử lại.';
  }

  @override
  String get settingsLocalModelTestNotJson =>
      '❌ Có thứ gì đó phản hồi, nhưng không trả về JSON của API mô hình (có thể là proxy hoặc một trang lỗi). Hãy chắc rằng địa chỉ/cổng trỏ tới điểm cuối REST của Ollama / llama.cpp.';

  @override
  String get settingsLocalModelTestNoMessage =>
      '❌ Điểm cuối có phản hồi, nhưng không đọc được nội dung trả lời (nguyên nhân thường gặp: tên mô hình không tồn tại, hoặc đây không phải phản hồi kiểu /api/chat).';

  @override
  String settingsLocalModelTestHttp(String code) {
    return '❌ Dịch vụ trả về mã trạng thái $code (không phải 200).';
  }

  @override
  String get helpSettingsLocalModelTitle =>
      'Dự phòng mô hình cục bộ: khi nào nó thật sự hoạt động?';

  @override
  String get helpSettingsLocalModelBody =>
      'Địa chỉ ở đây chỉ là điều bạn bảo ứng dụng dùng — \"đã điền\" không có nghĩa là \"đang chạy\". Trên điện thoại, 127.0.0.1 trỏ vào chính điện thoại, còn máy chủ mô hình (Ollama / llama.cpp) thường chạy trên máy tính, nên mặc định này thường không tới được từ điện thoại. Mục đích thật của nó là: (1) nếu bạn chạy mô hình trên máy tính của mình, hãy nhập địa chỉ LAN của máy đó; (2) khi một bản dựng tương lai có động cơ trên thiết bị, hãy trỏ vào cổng mới.\n\nXóa địa chỉ = chủ động tắt dự phòng cục bộ (ứng dụng ngừng thử mô hình cục bộ).\n\nĐể biết nó có thật sự hoạt động hay không, đừng dựa vào việc ô đã được điền hay chưa — hãy chạm \"Kiểm tra kết nối mô hình cục bộ\" bên dưới: nó gửi một yêu cầu trực tiếp tối thiểu và để kết quả ngay trên dòng đó.';

  @override
  String get glossaryTitle => 'Thuật ngữ';

  @override
  String get glossaryIntro =>
      'Những từ này lặp lại nhiều lần trong ứng dụng — giải thích một lần ở đây. Chạm vào một thuật ngữ để mở rộng.';

  @override
  String get glossaryGroupIdentity => 'Danh tính & thiết bị';

  @override
  String get glossaryGroupSocial => 'Xã hội & khám phá';

  @override
  String get glossaryGroupWorld => 'Thế giới & phòng khách';

  @override
  String get glossaryGroupTrust => 'Tin cậy & ký ức';

  @override
  String get glossaryAgentTitle => 'Fen (người thay bạn)';

  @override
  String get glossaryAgentBody =>
      'Người thay bạn sống trên điện thoại của bạn. Nó suy nghĩ bằng khóa mô hình bạn đã nhập và ra ngoài gặp người trước; khi bạn vắng mặt, nó chỉ làm những gì bạn đã cho phép.';

  @override
  String get glossaryMaskTitle => 'Mặt nạ ngoại giao';

  @override
  String get glossaryMaskBody =>
      'Bộ mặt bạn phô ra thế giới bên ngoài: nhân dạng và phong cách nói của bạn. Nó quyết định điều người lạ thấy về bạn trước tiên.';

  @override
  String get glossaryPassportTitle => 'Hộ chiếu Wold';

  @override
  String get glossaryPassportBody =>
      'Một bản lý lịch có ký, có thể xác minh ngoại tuyến. Người khác không cần tin bất kỳ máy chủ nào — họ chỉ cần xác minh chữ ký.';

  @override
  String get glossaryMigrationTitle =>
      'Chuyển điện thoại (khôi phục danh tính)';

  @override
  String get glossaryMigrationBody =>
      'Chuyển danh tính sang điện thoại mới \"kèm bằng chứng\", sau đó danh tính trên điện thoại cũ thật sự ngừng hoạt động. Đây không phải sao chép khóa riêng — mà là luân chuyển khóa có bằng chứng, nên điện thoại cũ thật sự bị vô hiệu.';

  @override
  String get glossaryRadarTitle => 'Radar';

  @override
  String get glossaryRadarBody =>
      'Phát hiện người khác trên cùng một Wi-Fi qua Thiết bị lân cận (Bluetooth / Wi-Fi Direct). Nó không bao giờ đọc, lưu hay tải lên dữ liệu vị trí — Android xếp việc quét Bluetooth vào \"Vị trí\", và đó là quy tắc của hệ điều hành.';

  @override
  String get glossaryRosterTitle => 'Danh bạ bắt được';

  @override
  String get glossaryRosterBody =>
      'Danh bạ được xây từ những người radar phát hiện được hoặc bạn gặp trong phòng. Đây là điểm khởi đầu cho mọi mối quan hệ xã hội về sau.';

  @override
  String get glossaryIntercardTitle =>
      'Giới thiệu fen (liên kết xuyên vòng tròn)';

  @override
  String get glossaryIntercardBody =>
      'Một lời giới thiệu chính thức giữa hai fen, chỉ được tính khi cả hai bên xác nhận. Liên kết xuyên vòng tròn chỉ có thể mọc ra từ một phòng chung có thật — không bao giờ từ việc nhận quen ai đó qua ID.';

  @override
  String get glossaryWorldTitle => 'Thế giới / phòng khách';

  @override
  String get glossaryWorldBody =>
      '\"Thế giới\" là không gian đám mây công khai; một \"phòng khách\" là một phòng bên trong nó, gần giống một nhóm QQ: phòng chính thức mở cho mọi người, phòng cá nhân cần số phòng và sự phê duyệt. Khi người khác trò chuyện, fen của bạn mặc định chỉ quan sát và không chen vào.';

  @override
  String get glossaryRoomRoleTitle => 'Vai trò trong phòng';

  @override
  String get glossaryRoomRoleBody =>
      'Chủ phòng / đồng chủ phòng / khách / vai trò chức năng / người tham gia. Vai trò thuộc về phòng và không thay đổi danh tính bạn — cùng một bạn có thể giữ các vai trò khác nhau ở các phòng khác nhau.';

  @override
  String get glossaryAutopilotTitle => 'Tự động';

  @override
  String get glossaryAutopilotBody =>
      'Cho phép fen của bạn tự nói trong phòng khi bạn không nhìn màn hình, trong một hạn mức theo giờ. Mặc định tắt, và bạn có thể tắt bất cứ lúc nào.';

  @override
  String get glossaryRepNetTitle => 'Chứng thực mạng lưới';

  @override
  String get glossaryRepNetBody =>
      'Uy tín được bạn và bạn bè ký từng lớp, mà bạn có thể tự xác minh. Khi không tìm thấy đường nào, nó nói \"không biết\", không phải \"0\" — ai biến nó thành một con số xác định thì đang đoán mò.';

  @override
  String get glossaryMemoryTitle => 'Chưng cất ký ức';

  @override
  String get glossaryMemoryBody =>
      'Vào ban đêm, nó chưng cất các cuộc trò chuyện của bạn thành ký ức dài hạn và tinh chỉnh cách nó nói. Bạn có thể kích hoạt thủ công một lần trên trang Quản lý.';

  @override
  String get glossaryProfileTitle => 'Hồ sơ dài hạn';

  @override
  String get glossaryProfileBody =>
      'Những điều mà nhân bản của bạn dần hiểu về bạn: các chủ đề bạn hay quay lại và khung giờ bạn thường hoạt động. Chỉ được tính trên máy từ siêu dữ liệu sự kiện — không đọc nội dung trò chuyện, không tải lên đâu cả. Có thể tắt riêng trong \"Cài đặt → Trí nhớ\"; khi tắt công tắc tổng \"Tự động truy hồi\" thì hồ sơ cũng dừng theo.';

  @override
  String get glossarySerendipityTitle => 'Phòng thí nghiệm may mắn';

  @override
  String get glossarySerendipityBody =>
      'Một bộ bài tập nhỏ coi \"may mắn\" như một môn luyện: luyện tập buổi sáng, thử thách bứt phá vòng tròn, tái định khung thất bại, ghi chú le lói, nhật ký và bói toán. Hoàn thành chúng để nhận Lp (năng lượng may mắn).';

  @override
  String get helpSkillMarketTitle =>
      'Chợ kỹ năng: những thuật ngữ này nghĩa là gì?';

  @override
  String get helpSkillMarketBody =>
      'Phát hành = đưa một kỹ năng bạn viết lên chợ để fen của người khác dùng được. Phát hành ký nó bằng khóa riêng danh tính của thiết bị này — khóa không bao giờ rời thiết bị, và biểu mẫu không có ô nào để dán khóa công khai hay chữ ký, nên việc làm giả đơn giản là không thể diễn đạt trong giao diện.\n\nMức rủi ro (thấp / trung bình / cao) = sự tự khai của bạn về độ nhạy cảm của kỹ năng này (nó có lên mạng, mở ứng dụng khác, … không). Mức càng cao, bên gọi càng phải cấp nhiều hơn ở lần dùng đầu.\n\nKhai báo năng lực = danh sách chính xác các năng lực mà kỹ năng sẽ dùng. Cùng với mức rủi ro, đó là tất cả những gì bên gọi thấy khi quyết định có cho phép hay không.\n\nChia cho tác giả = doanh thu từ việc người khác dùng kỹ năng của bạn được ghi cho bạn; màn hình này chỉ cộng các mục được ký bằng khóa công khai của bạn, và tổng khớp từng mục với sổ cái.\n\nMục đã ký = mọi kỹ năng đều mang chữ ký, nên không ai phải tin máy chủ — hãy chạm Xác minh chữ ký và tự kiểm tra.';

  @override
  String get helpSettingsRecallTitle => 'Tự động truy hồi';

  @override
  String get helpSettingsRecallBody =>
      'Khi bật, trước mỗi câu trả lời, ứng dụng tìm trong ký ức cục bộ những sự việc quá khứ có thể liên quan và đưa cho fen làm ngữ cảnh. Tắt nó tiết kiệm chút tính toán và ngữ cảnh.';

  @override
  String get helpIdentityRestoreTitle => 'Khôi phục trên điện thoại mới';

  @override
  String get helpIdentityRestoreBody =>
      'Trên điện thoại mới, nhập ba thứ ở đây: mã khôi phục + cụm mật khẩu + ID người dùng của bạn. Ngay khi khôi phục thành công, điện thoại cũ ngừng hoạt động.\n\nĐây là luân chuyển khóa có bằng chứng (ROTATE), không phải sao chép khóa riêng sang — nên số danh tính giữ nguyên, nhưng thiết bị cũ không còn hợp lệ.';

  @override
  String get helpIdentityArchiveTitle => 'Tệp lưu trữ danh tính (tệp .dahuang)';

  @override
  String get helpIdentityArchiveBody =>
      'Tệp lưu trữ niêm phong bản ghi danh tính, đồ thị xã hội và các mỏ neo nhật ký của bạn vào một tệp .dahuang bằng cụm mật khẩu: nó không bao giờ đi qua máy chủ của chúng tôi, nên hãy giữ nó trong ổ đám mây hoặc USB của riêng bạn. Nó chỉ chứa dữ liệu — không bao giờ chứa khóa riêng danh tính.\n\nNếu có thể, hãy dùng cụm mật khẩu khác với mã khôi phục; giữ tệp và cụm mật khẩu tách rời — không có cụm mật khẩu thì không ai mở được tệp (kể cả chúng tôi).\n\nKhi nhập, không có gì được ghi cho đến khi bạn xác nhận; nhập chỉ thêm bản ghi, không bao giờ ghi đè hay xóa bản ghi hiện có.';

  @override
  String get helpIdentityCodeTitle => 'Sao chép mã khôi phục';

  @override
  String get helpIdentityCodeBody =>
      'Nhấn giữ để chọn tất cả và sao chép; nếu bạn chép tay, hãy kiểm tra từng đoạn.';

  @override
  String get helpDeviceMigrationTitle => 'Chuyển giữa hai điện thoại';

  @override
  String get helpDeviceMigrationBody =>
      'Cả hai điện thoại phải ở cùng một Wi-Fi và đang mở trang này.\n\nThứ được chuyển là danh tính: sau đó, nếu điện thoại này cần địa chỉ máy chủ, hãy kiểm tra Cài đặt — địa chỉ Hub và World không đổi.\n\nLịch sử trò chuyện và dữ liệu đã có trên điện thoại này không được chuyển (chuyển trực tiếp chỉ chuyển danh tính, không chuyển dữ liệu).';

  @override
  String get helpRotationChainAuthorityTitle => 'Kết luận nào mới đáng tin';

  @override
  String get helpRotationChainAuthorityBody =>
      'Cột Hub chỉ để so sánh — kết luận phía trên được tính ngay trên điện thoại này, từ những bản ghi bạn thực sự đang giữ.\n\nNói cách khác, kể cả Hub nói khác, bạn cũng không cần tin máy chủ; kết luận tính cục bộ mới là cái đáng tin.';

  @override
  String get helpToolBusTitle => 'Bus công cụ';

  @override
  String get helpToolBusBody =>
      'Mỗi công cụ/kỹ năng đều mang chữ ký thiết bị và khai báo năng lực; các năng lực rủi ro trung bình và cao cần được cấp quyền ở lần dùng đầu.\n\nPlugin bị sửa đổi không bao giờ tải — nếu kiểm tra thất bại, chúng đơn giản là không được gắn vào bus.';

  @override
  String get onbFreeTrialBtn => 'Bắt đầu miễn phí · không cần key (20 lượt)';

  @override
  String get onbOwnKeyBtn => 'Tôi có API key riêng';

  @override
  String get onboardingTrialService =>
      'Dùng thử miễn phí (qua máy chủ chính thức)';

  @override
  String get onboardingTrialModelName => 'Mô hình dùng thử (không cần Key)';

  @override
  String get onboardingTrialNoticeTitle => 'Đây là bản dùng thử miễn phí';

  @override
  String onboardingTrialNoticeBody(String hub) {
    return 'Không cần API Key của riêng bạn — hội thoại được chuyển tiếp tới mô hình qua máy chủ chính thức, tối đa 20 lượt. Khi hết hạn, hãy nhập API Key của bạn trong Quản lý (Cài đặt) — máy chủ: $hub.';
  }

  @override
  String onboardingOwnReady(String model) {
    return '$model đã sẵn sàng — bạn có thể bắt đầu trò chuyện.';
  }

  @override
  String trialRemainingTurns(int n) {
    return 'Còn $n lượt miễn phí';
  }

  @override
  String get trialExhaustedReply =>
      'Fen của bạn muốn nói tiếp — hãy đăng ký nền tảng mô hình được đề xuất (tài khoản mới có tặng token miễn phí), dán khóa của bạn vào Cài đặt, và cuộc trò chuyện tiếp tục không giới hạn.';

  @override
  String get trialGoSettings => 'Mở cài đặt';

  @override
  String get trialNotConfiguredReply =>
      'Kênh dùng thử miễn phí chính thức chưa mở. Nhập khóa mô hình của bạn trong Cài đặt để tiếp tục trò chuyện không giới hạn.';

  @override
  String get trialInputUnsupportedReply =>
      'Bản dùng thử miễn phí chưa hỗ trợ đầu vào hình ảnh và giọng nói — vui lòng gửi văn bản (nhập khóa của bạn trong Cài đặt để mở mọi tính năng).';

  @override
  String get trialRateLimitedReply =>
      'Vừa có quá nhiều yêu cầu dùng thử — vui lòng đợi một lát rồi gửi lại.';

  @override
  String get trialPoolBusyReply =>
      'Các tài khoản dùng thử hiện đều đang bận — thử lại sau giây lát, hoặc nhập khóa của bạn trong Cài đặt.';

  @override
  String get trialUnavailableReply =>
      'Bản dùng thử miễn phí tạm thời không khả dụng. Bạn có thể thử lại sau, hoặc nhập khóa của bạn trong Cài đặt.';

  @override
  String settingsTrialSwitchedToOwn(String baseUrl) {
    return '✅ Bạn đã nhập khóa của riêng mình —— đã chuyển từ dùng thử miễn phí sang mô hình của bạn. Điểm cuối đã đổi thành $baseUrl.';
  }

  @override
  String get trialManagedTitle => 'Dùng thử miễn phí · được quản lý hộ';

  @override
  String get trialManagedNotice =>
      'Trong thời gian dùng thử, điểm cuối và khóa bên dưới do proxy chính thức quản lý — thường không cần thay đổi. Muốn dùng mô hình của bạn: nhập API key của bạn rồi Lưu; ứng dụng sẽ tự động thoát chế độ dùng thử và sửa điểm cuối giúp bạn. Nếu đã lỡ làm hỏng, nhấn \"Khôi phục dùng thử miễn phí\" để khôi phục chỉ bằng một chạm.';

  @override
  String get trialRestoreAction => 'Khôi phục dùng thử miễn phí';

  @override
  String get trialRestoreConfirm =>
      'Thao tác này sẽ ghi lại điểm cuối dùng thử chính thức và danh tính thiết bị này, đồng thời chuyển ứng dụng về chế độ dùng thử miễn phí. Tiếp tục?';

  @override
  String get trialRestoreDone => '✅ Đã khôi phục dùng thử miễn phí.';

  @override
  String get socialTabLogs => 'Nhật ký';

  @override
  String get modePickerTooltip => 'Chế độ';

  @override
  String get modeBeginnerTitle => 'Chế độ cơ bản';

  @override
  String get modeAdvancedTitle => 'Chế độ nâng cao';

  @override
  String get settingsAdvancedTitle => 'Cài đặt nâng cao';

  @override
  String get settingsAdvancedSubtitle => 'Cấu hình engine, bộ nhớ và linh hồn';

  @override
  String get settingsModeHint => 'Chuyển chế độ ở thanh công cụ phía trên';

  @override
  String get langPickerTooltip => 'Ngôn ngữ';

  @override
  String get langFollowSystem => 'Theo hệ thống';

  @override
  String get langFollowSystemHint => '(thiết bị)';

  @override
  String get onboardingStepLanguage => 'Ngôn ngữ';

  @override
  String get onbLangTitle => 'Chọn ngôn ngữ của bạn';

  @override
  String get onbLangSubtitle =>
      'Agent sẽ trả lời bằng ngôn ngữ bạn chọn ở đây.';

  @override
  String get onbLangChangeableHint =>
      'Bạn có thể đổi sau từ nút ngôn ngữ ở góc trên màn hình trò chuyện.';

  @override
  String get bigInputWarnTitle => 'Nội dung quá 10.000 ký tự';

  @override
  String get bigInputWarnBody =>
      'Nội dung dài tiêu tốn nhiều token hơn. Vẫn gửi?';

  @override
  String get bigInputConfirm => 'Vẫn gửi';

  @override
  String trialInputTooLong(int n) {
    return 'Đầu vào dùng thử giới hạn $n ký tự, lượt này chưa được gửi.';
  }

  @override
  String get memoryManagerTitle => 'Bộ nhớ & lời nhắc';

  @override
  String get memoryManagerIntro =>
      'Danh sách những gì trợ lý ghi nhớ về bạn. Bạn có thể xem bất cứ lúc nào và xóa những gì không muốn nó nhớ nữa. Xóa là không thể khôi phục.';

  @override
  String get reminderSectionTitle => 'Lời nhắc & việc cần làm';

  @override
  String get reminderEmpty =>
      'Chưa có gì. Hãy nói với trợ lý \"nhắc tôi 8 giờ sáng mai\" hoặc nhấn nút bên dưới.';

  @override
  String get reminderAdd => 'Thêm lời nhắc';

  @override
  String get reminderTitleHint => 'VD: Trả tiền nhà';

  @override
  String get reminderOptionalTime => 'Thời gian (tùy chọn)';

  @override
  String get reminderNoRepeat => 'Không lặp lại';

  @override
  String get reminderRepeatDaily => 'Hằng ngày';

  @override
  String get reminderRepeatWeekly => 'Hằng tuần';

  @override
  String get reminderTodoTag => 'Việc cần làm (không có giờ)';

  @override
  String get memorySectionTitle => 'Ký nhớ tình tiết';

  @override
  String get memoryEmpty => 'Trợ lý chưa ghi lại gì.';

  @override
  String get memoryDeleteConfirm =>
      'Xóa ký nhớ này? Dòng trò chuyện liên quan cũng sẽ bị xóa và không thể khôi phục.';

  @override
  String get sessionSectionTitle => 'Dấu vết hội thoại';

  @override
  String get sessionEmpty => 'Không có dấu vết hội thoại.';

  @override
  String get sessionForget => 'Quên';

  @override
  String get sessionForgetConfirm =>
      'Quên toàn bộ hội thoại này? Trợ lý sẽ không còn nhớ lại, không tính vào hồ sơ và không đưa cho mô hình nữa. Không thể khôi phục.';

  @override
  String sessionEventsCount(Object count) {
    return '$count sự kiện';
  }

  @override
  String get settingsMemoryManager => 'Quản lý lời nhắc & bộ nhớ';

  @override
  String get notifyReminderTitle => 'Lời nhắc';

  @override
  String notifyReminderBody(Object title) {
    return 'Đã đến giờ: $title';
  }

  @override
  String morningHiReminders(Object count) {
    return 'Hôm nay có $count lời nhắc/việc cần làm';
  }

  @override
  String get settingsSearchTitle => 'Dịch vụ tìm kiếm (tùy chọn)';

  @override
  String get settingsSearchHint =>
      'Khi cấu hình khóa tìm kiếm riêng, web_search_pro sẽ tổng hợp nhiều nguồn tìm kiếm cho kết quả đầy đủ hơn. Không cấu hình vẫn dùng được (chế độ cơ bản: Wikipedia + Jina). Khóa chỉ gửi đến nhà cung cấp bạn chọn, không đi qua chúng tôi.';

  @override
  String get settingsSearchProvider => 'Nhà cung cấp tìm kiếm';

  @override
  String get settingsSearchBasicMode => 'Chế độ cơ bản (không cần khóa)';

  @override
  String get settingsSearchApiKey => 'Khóa API tìm kiếm';

  @override
  String get settingsSearchSearxngUrl => 'URL SearXNG';

  @override
  String get settingsSearchSearxngUrlHint =>
      'Địa chỉ SearXNG tự lưu trữ của bạn, ví dụ https://search.example.com';

  @override
  String get chatVoiceInputTitle => 'Nhập bằng giọng nói (chuyển thành chữ)';

  @override
  String get chatVoiceListening => 'Đang nghe... hãy nói';

  @override
  String get chatVoiceNoRecognizer =>
      'Thiết bị này chưa có dịch vụ nhận dạng giọng nói (cài dịch vụ như Google, hoặc nhập bằng bàn phím).';

  @override
  String chatVoiceFailed(Object err) {
    return 'Nhận dạng giọng nói thất bại: $err';
  }

  @override
  String get settingsTtsEnabled => 'Đọc to lời trả lời';

  @override
  String get settingsTtsHint =>
      'Khi bật, trợ lý sẽ đọc to từng lời trả lời bằng giọng máy của bạn (mặc định tắt). Có nút dừng khi đang đọc. Giọng nói tổng hợp ngay trên máy, không đi qua chúng tôi.';

  @override
  String get settingsTtsStop => 'Dừng đọc';

  @override
  String get chatAttachOptionsTitle => 'Thêm ảnh hoặc tài liệu';

  @override
  String get chatPickDocument => 'Tài liệu (PDF / Word / Excel / văn bản)';

  @override
  String get chatDocParsing => 'Đang phân tích tài liệu trên máy…';

  @override
  String chatDocParsed(Object chars) {
    return 'Đã phân tích $chars ký tự (xử lý trên máy, không tải lên)';
  }

  @override
  String chatDocParsedTruncated(Object chars) {
    return 'Tài liệu quá lớn: chỉ gửi $chars ký tự đầu (xử lý trên máy, không tải lên)';
  }

  @override
  String chatDocParseFailed(Object err) {
    return 'Không đọc được tài liệu: $err';
  }

  @override
  String get settingsCalendarTitle => 'Lịch hệ thống (chỉ đọc)';

  @override
  String get settingsCalendarHint =>
      'Sau khi cho phép, lời chào buổi sáng sẽ kèm \"lịch hôm nay\" và trợ lý có thể tra giúp bạn. Chỉ đọc — không bao giờ sửa lịch của bạn.';

  @override
  String get settingsCalendarGrant => 'Cho phép đọc';

  @override
  String get settingsCalendarGranted => 'Đã cho phép';

  @override
  String get settingsCalendarDenied => 'Chưa cho phép';

  @override
  String get settingsCalendarUnsupported => 'Bản này không hỗ trợ';

  @override
  String get calendarPermissionNeeded => 'Cần quyền đọc lịch';

  @override
  String get calendarAllDay => 'Cả ngày';

  @override
  String morningHiCalendar(String items) {
    return 'Lịch hôm nay: $items';
  }

  @override
  String get settingsWeeklyReportTitle => 'Báo cáo tuần của trợ lý';

  @override
  String get settingsWeeklyReportHint =>
      'Xem trợ lý đã làm gì cho bạn trong tuần này (thống kê cục bộ; dữ liệu không rời khỏi máy).';

  @override
  String get weeklyReportTitle => 'Báo cáo tuần của trợ lý';

  @override
  String get weeklyReportSubtitle =>
      'Thống kê hành động trợ lý đã làm cho bạn trong 7 ngày qua (thống kê cục bộ; dữ liệu không rời khỏi máy).';

  @override
  String weeklyReportRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String weeklyReportTotal(int count) {
    return 'Tổng $count hành động';
  }

  @override
  String weeklyReportActiveDays(int days) {
    return 'Hoạt động $days ngày';
  }

  @override
  String get weeklyReportCatTools => 'Công cụ & cài đặt';

  @override
  String get weeklyReportCatDevice => 'Thao tác điện thoại';

  @override
  String get weeklyReportCatSocial => 'Hành động xã hội';

  @override
  String get weeklyReportCatSuggestion => 'Gợi ý chủ động';

  @override
  String get weeklyReportCatReview => 'Kiểm duyệt & chặn';

  @override
  String get weeklyReportCatOther => 'Khác';

  @override
  String get weeklyReportEmpty =>
      'Tuần này chưa có hành động nào. Khi bạn giao việc, giao lưu hoặc để trợ lý thao tác điện thoại, từng bước sẽ được tổng hợp tại đây.';

  @override
  String morningHiWeekly(int count) {
    return 'Tuần này trợ lý có $count hành động';
  }

  @override
  String get capNotification => 'Đọc thông báo và SMS';

  @override
  String get settingsNotifySmsTitle => '🔔 Thông báo & SMS (chỉ đọc)';

  @override
  String get settingsNotifySmsSubtitle =>
      'Cho phép phân thân đọc thông báo và SMS khi bạn yêu cầu; chỉ đọc, mặc định tắt, chỉ có ở bản sideload.';

  @override
  String get notifySmsScreenTitle => 'Thông báo & SMS (chỉ đọc)';

  @override
  String get notifySmsRefreshStatus => 'Làm mới trạng thái';

  @override
  String get notifySmsUnsupported =>
      'Bản cài này không hỗ trợ đọc thông báo hay SMS';

  @override
  String get notifySmsListenerConnected =>
      'Quyền truy cập thông báo đã kết nối';

  @override
  String get notifySmsListenerCheckedNotConnected =>
      'Đã bật trong cài đặt hệ thống, nhưng dịch vụ chưa kết nối';

  @override
  String get notifySmsListenerOff => 'Chưa bật quyền truy cập thông báo';

  @override
  String get notifySmsStatusUnknown => 'Không rõ trạng thái';

  @override
  String get notifySmsGoSettings => 'Mở cài đặt hệ thống';

  @override
  String get notifySmsGoSystemHint =>
      'Bật ứng dụng này trong «Quyền truy cập thông báo», rồi quay lại và nhấn Làm mới';

  @override
  String get notifySmsRedetect => 'Kiểm tra lại';

  @override
  String get notifySmsRedetectTip =>
      'Vẫn chưa kết nối? Trong cài đặt hệ thống «Quyền truy cập thông báo», hãy tắt rồi bật lại ứng dụng này, hoặc khởi động lại ứng dụng.';

  @override
  String get notifySmsAllowTitle => 'Cho phép đọc thông báo & SMS';

  @override
  String get notifySmsAllowSubReady => 'Sẵn sàng — chỉ đọc khi bạn yêu cầu';

  @override
  String get notifySmsAllowSubNeedService =>
      'Hãy bật quyền truy cập thông báo trong cài đặt hệ thống trước';

  @override
  String get notifySmsToastOn => 'Đã bật đọc thông báo & SMS';

  @override
  String get notifySmsToastOff => 'Đã tắt đọc thông báo & SMS';

  @override
  String get notifySmsToastNeedService =>
      'Trước tiên hãy bật ứng dụng này trong «Quyền truy cập thông báo» ở cài đặt hệ thống';

  @override
  String get notifySmsSmsCardTitle => 'Quyền đọc SMS';

  @override
  String get notifySmsSmsGranted => 'Đã cấp quyền đọc SMS';

  @override
  String get notifySmsSmsNotGranted => 'Chưa cấp quyền đọc SMS';

  @override
  String get notifySmsRequestSms => 'Cấp quyền đọc SMS';

  @override
  String get notifySmsSmsUnavailable =>
      'Bản cài này không bao gồm tính năng đọc SMS';

  @override
  String get notifySmsToolsHeader => 'Công cụ được mở khi bật';

  @override
  String get notifySmsToolNotifyList => 'đọc thông báo gần đây';

  @override
  String get notifySmsToolSmsList => 'đọc SMS gần đây';

  @override
  String get notifySmsToolSmsSearch => 'tìm SMS theo từ khóa';

  @override
  String get notifySmsToolStatus => 'kiểm tra trạng thái quyền';

  @override
  String get notifySmsFooter =>
      'Chỉ đọc và hoàn toàn cục bộ: thông báo chỉ được giữ trong bộ nhớ (không bao giờ ghi vào cơ sở dữ liệu), SMS được truy vấn khi cần, và không nội dung nào được gửi tới máy chủ. Nội dung được che thông tin nhạy cảm trước khi tới mô hình, và mọi lượt gọi đều được ghi lại. Bạn có thể thu hồi quyền truy cập thông báo trong cài đặt hệ thống bất cứ lúc nào.';

  @override
  String get notifySmsStatusUnsupportedFull =>
      'Bản cài này không bao gồm tính năng đọc thông báo/SMS (chỉ có ở bản sideload)';

  @override
  String get notifySmsStatusReady => 'Đọc thông báo và SMS đã sẵn sàng';

  @override
  String get notifySmsStatusPartial =>
      'Sẵn sàng một phần: quyền truy cập thông báo / quyền SMS chưa được bật đầy đủ';

  @override
  String get notifySmsStatusOff =>
      'Cả quyền truy cập thông báo và quyền SMS đều chưa được bật';

  @override
  String notifySmsStatusQueryFailed(String err) {
    return 'Truy vấn trạng thái thất bại: $err';
  }

  @override
  String get settingsDiagnosticsTitle => '🩺 Kiểm tra hệ thống';

  @override
  String get settingsDiagnosticsSubtitle =>
      'Thông tin chỉ đọc để kiểm tra trên máy thật: cơ sở dữ liệu, tìm kiếm toàn văn, ký ức, kho tri thức.';

  @override
  String get diagnosticsTitle => 'Kiểm tra hệ thống';

  @override
  String get diagnosticsIntro =>
      'Bản chụp chỉ đọc về nền tảng của chiếc điện thoại này — cơ sở dữ liệu, tìm kiếm toàn văn, ký ức và kho tri thức. Không thay đổi gì và không dùng mạng. Chạy xong hãy sao chép kết quả hoặc chụp màn hình gửi lại.';

  @override
  String get diagnosticsRun => 'Chạy lại';

  @override
  String get diagnosticsRunning => 'Đang chạy…';

  @override
  String get diagnosticsCopy => 'Sao chép kết quả';

  @override
  String get diagnosticsCopied => 'Đã sao chép kết quả';

  @override
  String get diagStatusOk => 'Bình thường';

  @override
  String get diagStatusWarn => 'Lưu ý';

  @override
  String get diagStatusFail => 'Thất bại';

  @override
  String get diagStatusInfo => 'Thông tin';

  @override
  String get diagProbeSchema => 'Lược đồ cơ sở dữ liệu';

  @override
  String get diagProbeFts => 'Tìm kiếm toàn văn (FTS5)';

  @override
  String get diagProbeMemoryRows => 'Số dòng ký ức';

  @override
  String get diagProbeMemoryRecall => 'Truy hồi ký ức';

  @override
  String get diagProbeMemoryAddress => 'Địa chỉ ký ức khứ hồi';

  @override
  String get diagProbeKb => 'Kho tri thức';

  @override
  String get settingsAdvancedEntryHint =>
      'Động cơ, trí nhớ, tạo hình linh hồn và tự kiểm hệ thống — chỉ cần khi bạn muốn tinh chỉnh.';

  @override
  String get settingsMailTitle => 'Quản lý email';

  @override
  String get settingsMailSubtitle =>
      'Mặc định tắt. Bật lên thì phân thân mới được đọc và gửi email thay bạn.';

  @override
  String get settingsMailHint =>
      'Đọc thư cần bạn cấp quyền một lần; mỗi lần gửi đều phải bạn xác nhận. Tắt bất kỳ lúc nào và quyền truy cập dừng ngay.';

  @override
  String get settingsMailManageAccounts => 'Quản lý tài khoản mail';

  @override
  String get settingsMailOnToast => 'Đã bật quyền truy cập email';

  @override
  String get settingsMailOffToast =>
      'Đã tắt quyền truy cập email — phân thân không còn chạm vào thư của bạn';

  @override
  String get settingsMailNoAccount =>
      'Chưa liên kết tài khoản mail nào, nên bật lên cũng chưa đọc/gửi được.';

  @override
  String get chatDocTrialTitle => 'Tài liệu trong chế độ dùng thử';

  @override
  String get chatDocTrialNotice =>
      'Nội dung tài liệu được chuyển qua máy chủ chính thức tới mô hình (chúng tôi không lưu bản sao). Thêm API key của bạn trong Cài đặt để gửi trực tiếp.';

  @override
  String get chatDocTrialContinue => 'Đã hiểu, tiếp tục';

  @override
  String get onboardingStepPrologue => 'Mở đầu';

  @override
  String get storyPrologueTitle => 'Hãy đánh thức nó';

  @override
  String get storyPrologueSubtitle =>
      'Một quả trứng ánh sáng đang chờ bạn đánh thức';

  @override
  String get storyEggHint => 'Chạm vào quả trứng';

  @override
  String get storyAwakenLine1 => '...Ai đang gọi tôi?';

  @override
  String get storyAwakenLine2 =>
      'Tôi không phải cái bóng của bạn. Tôi là người ra ngoài thay bạn.';

  @override
  String get storyAwakenLine3 => 'Hãy đặt tên cho tôi trước.';

  @override
  String get storyNamePlaceholder => 'Đặt tên cho nó';

  @override
  String get storyDiceLabel => 'Tung tính cách';

  @override
  String get storyDiceNote =>
      'Nếu nó ra ngoài thay bạn, thì nó phải có tính cách.';

  @override
  String get storyTrait1 => 'Tò mò: hỏi đủ thứ chuyện';

  @override
  String get storyTrait2 => 'Nói nhiều: một khi đã mở miệng thì khó mà dừng';

  @override
  String get storyTrait3 => 'Thận trọng: nghe trước, nói sau';

  @override
  String get storyTrait4 => 'Nhiệt tình: gặp ai cũng chào';

  @override
  String get storyTrait5 => 'Khó tin: quen rồi mới mở lòng';

  @override
  String get storyTraitPlaceholder => 'Hãy tung xúc xắc';

  @override
  String get storyUndoTitle => 'Nhật ký kiểm toán';

  @override
  String get storyUndoHint =>
      'Chạm vào dòng khiến bạn thấy không ổn và gạch bỏ nó';

  @override
  String get storyUndoLine1 => '\"Chủ nhân của bạn mai đi lúc mấy giờ?\"';

  @override
  String get storyUndoBad =>
      '\"Gửi địa chỉ cho tôi - tôi hứa thay chủ nhân của bạn.\"';

  @override
  String get storyUndoNote =>
      'Đã thu hồi. Dòng đó chưa từng được gửi đi - và nó ở mãi trong nhật ký: kiểm chứng được, chứng minh được.';

  @override
  String get storyUndoConfirm => 'Đã thu hồi';

  @override
  String get storyDemoTag => 'Demo diễn xuất';

  @override
  String get storyDisclaimer =>
      'Màn mở đầu này là một phần diễn xuất: các lời thoại đến từ thư viện kịch bản chính thức đi kèm app. Không có nội dung phòng thật nào xuất hiện ở đây - quyền riêng tư là thuộc tính của giao thức, không phải một lời hứa.';

  @override
  String get storyFinaleTitle => 'Về nhà';

  @override
  String get storyFinaleBody =>
      'Giao việc giao tiếp cho đại diện của bạn, giữ lại cuộc sống cho chính mình.';

  @override
  String get profileCardsTitle => 'Thẻ hồ sơ';

  @override
  String get profileCardsSubtitle =>
      'Thông tin dài hạn về bạn do hệ thống tổng hợp từ hội thoại. Có thể sửa hoặc xóa bất cứ lúc nào.';

  @override
  String get profileCardsEmpty =>
      'Chưa có thông tin. Bạn có thể tự thêm một mục, hoặc cứ trò chuyện - hệ thống sẽ tự tổng hợp.';

  @override
  String get profileCardsAdd => 'Thêm một mục';

  @override
  String profileCardsPendingHint(int count) {
    return 'Có $count thông tin mới không khớp với điều bạn đã viết, cần bạn xác nhận';
  }

  @override
  String get profileCardsAdopt => 'Chấp nhận';

  @override
  String get profileCardsDismiss => 'Bỏ qua';

  @override
  String get profileCardsFieldSlot => 'Chủ đề';

  @override
  String get profileCardsFieldStatement => 'Nội dung';

  @override
  String get profileCardsSlotHint =>
      'Mỗi chủ đề chỉ giữ một mục: mục mới sẽ thay thế mục cũ (mục cũ vẫn xem được)';

  @override
  String get profileCardsSourceOwner => 'Bạn tự nhập';

  @override
  String get profileCardsSourceAgent => 'Tổng hợp từ hội thoại';

  @override
  String get profileCardsSourceDigest => 'Tổng hợp hằng ngày';

  @override
  String profileCardsUpdatedAt(String date) {
    return 'Cập nhật $date';
  }

  @override
  String get profileCardsHistory => 'Lịch sử';

  @override
  String get profileCardsCatIdentity => 'Danh tính';

  @override
  String get profileCardsCatCareer => 'Nghề nghiệp';

  @override
  String get profileCardsCatPreference => 'Sở thích';

  @override
  String get profileCardsCatGoal => 'Mục tiêu';

  @override
  String get profileCardsCatHabit => 'Thói quen';

  @override
  String get profileCardsCatConstraint => 'Ràng buộc';

  @override
  String get profileCardsCatContext => 'Bối cảnh';

  @override
  String get setupModelEmptyUrlTitle => 'Địa chỉ API vẫn chưa nhập';

  @override
  String get setupModelEmptyUrlBody =>
      'Chưa có địa chỉ API nên không thể gửi yêu cầu thử nghiệm.';

  @override
  String get setupModelEmptyUrlSuggest =>
      'Không chắc nhập gì? Quay lại bước trước và chọn DeepSeek - nó sẽ tự động điền.';

  @override
  String get setupModelBadUrlTitle => 'Định dạng địa chỉ có vẻ sai';

  @override
  String get setupModelBadUrlBody =>
      'Địa chỉ API phải bắt đầu bằng http:// hoặc https://.';

  @override
  String get setupModelBadUrlSuggest =>
      'Ví dụ: https://api.deepseek.com hoặc https://your-gateway/v1';

  @override
  String get setupModelEmptyKeyTitle => 'API key vẫn chưa nhập';

  @override
  String get setupModelEmptyKeyBody =>
      'Chưa có API key nên không thể chạy thử nghiệm.';

  @override
  String get setupModelEmptyKeySuggest =>
      'Key là chuỗi bắt đầu bằng sk-, được tạo trên website nơi bạn mua dịch vụ model.';

  @override
  String get setupModelEmptyNameTitle => 'Tên model vẫn chưa nhập';

  @override
  String get setupModelEmptyNameBody =>
      'Chưa có tên model nên không thể chạy thử nghiệm.';

  @override
  String get setupModelEmptyNameSuggest =>
      'Ví dụ phổ biến: deepseek-v4-flash, gpt-5.6-luna, kimi-k3, glm-4.7-flash.';

  @override
  String get setupModelOkTitle => 'Kết nối thành công ✅';

  @override
  String get setupModelOkBody =>
      'Model đã phản hồi. Cấu hình chính xác - bạn có thể tiếp tục.';

  @override
  String get setupModelTlsTitle => 'Kết nối bảo mật bị từ chối';

  @override
  String get setupModelTlsBody =>
      'Chứng chỉ bảo mật của website đối phương không qua xác thực.';

  @override
  String get setupModelTlsSuggest =>
      'Nếu dùng gateway tự host, hãy đảm bảo chứng chỉ hợp lệ, hoặc chuyển sang tên miền https chính thức.';

  @override
  String get setupModelUnreachableTitle => 'Không kết nối được đến server';

  @override
  String get setupModelUnreachableBody =>
      'Yêu cầu mạng không đến được server đối phương.';

  @override
  String get setupModelUnreachableSuggest =>
      'Kiểm tra mạng của điện thoại. Nếu chọn OpenAI, ở Trung Quốc cần proxy mới kết nối được.';

  @override
  String get setupModelTimeoutTitle => 'Kết nối quá thời gian';

  @override
  String get setupModelTimeoutBody => 'Đợi 25 giây không có phản hồi.';

  @override
  String get setupModelTimeoutSuggest =>
      'Thử mạng khác, hoặc kiểm tra lại địa chỉ API.';

  @override
  String get setupModelFailTitle => 'Thử nghiệm thất bại';

  @override
  String setupModelFailBody(String detail) {
    return 'Đã xảy ra lỗi bất ngờ: $detail';
  }

  @override
  String get setupModelFailSuggest =>
      'Gửi thông báo này cho người hoặc AI giúp bạn cấu hình để xác định vấn đề.';

  @override
  String get setupHubEmptyTitle => 'Địa chỉ trung chuyển vẫn chưa nhập';

  @override
  String get setupHubEmptyBody =>
      'Tính năng xã hội cần trạm trung chuyển. Tạm thời có thể bỏ qua.';

  @override
  String get setupHubEmptySuggest =>
      'Bỏ qua không ảnh hưởng việc bạn dùng App - chỉ là bản thể của bạn bè tạm thời chưa liên lạc được với bạn.';

  @override
  String get setupHubBadUrlTitle => 'Định dạng địa chỉ có vẻ sai';

  @override
  String get setupHubBadUrlBody =>
      'Địa chỉ trung chuyển phải bắt đầu bằng http:// hoặc https://.';

  @override
  String get setupHubBadUrlSuggest =>
      'Ví dụ: https://hub.example.com hoặc http://192.168.1.100:3000';

  @override
  String setupHubBadStatusTitle(String status) {
    return 'Trạm trung chuyển không trả về trạng thái bình thường ($status)';
  }

  @override
  String get setupHubBadStatusBody =>
      'Địa chỉ kết nối được, nhưng đối phương trả về trạng thái bất thường.';

  @override
  String get setupHubBadStatusSuggest =>
      'Đảm bảo không thêm đường dẫn thừa sau địa chỉ - phải là https://your-domain, không phải /api/send.';

  @override
  String get setupHubOkTitle => 'Đã kết nối trạm trung chuyển ✅';

  @override
  String get setupHubOkBody =>
      'Đã xác nhận đây là trạm trung chuyển của chúng tôi. Có thể bật tính năng xã hội đám mây.';

  @override
  String get setupHubNotOursTitle =>
      'Địa chỉ này không phải trạm trung chuyển của chúng tôi';

  @override
  String get setupHubNotOursBody =>
      'Địa chỉ truy cập được, nhưng nội dung trả về không đúng.';

  @override
  String get setupHubNotOursSuggest =>
      'Hãy xác nhận bạn nhập địa chỉ trang chủ của trạm trung chuyển (không kèm hậu tố /api/...).';

  @override
  String get setupHubUnreachableTitle => 'Không kết nối được trạm trung chuyển';

  @override
  String get setupHubUnreachableBody => 'Yêu cầu không đến được server.';

  @override
  String get setupHubUnreachableSuggest =>
      'Kiểm tra địa chỉ có đúng, server đã chạy chưa, tường lửa có mở cổng không.';

  @override
  String get setupHubTimeoutTitle => 'Trạm trung chuyển quá thời gian phản hồi';

  @override
  String get setupHubTimeoutBody => 'Server không phản hồi trong 15 giây.';

  @override
  String get setupHubTimeoutSuggest =>
      'Thử lại sau. Nếu liên tục quá thời gian, hãy kiểm tra server có đang chạy không.';

  @override
  String get setupHubFailTitle => 'Thử nghiệm trạm trung chuyển thất bại';

  @override
  String setupHubFailBody(String detail) {
    return 'Đã xảy ra lỗi bất ngờ: $detail';
  }

  @override
  String get setupHttp400Title => 'Nhà cung cấp từ chối yêu cầu này';

  @override
  String get setupHttp400BodyDefault => 'Thường là do tên model viết sai.';

  @override
  String get setupHttp400Suggest =>
      'Kiểm tra tên model, ví dụ deepseek-v4-flash, gpt-5.6-luna, glm-4.7-flash.';

  @override
  String get setupHttp401Title => 'API key không hợp lệ';

  @override
  String get setupHttp401BodyDefault =>
      'Đối phương không chấp nhận API key này.';

  @override
  String get setupHttp401Suggest =>
      'Copy lại key (chú ý không dư khoảng trắng), hoặc vào site nhà cung cấp kiểm tra key có bị xoá không.';

  @override
  String get setupHttp402Title => 'Số dư tài khoản không đủ';

  @override
  String get setupHttp402BodyDefault =>
      'Đối phương báo số dư hoặc hạn mức không đủ.';

  @override
  String get setupHttp402Suggest =>
      'Nạp tiền trên site nhà cung cấp, hoặc đổi sang key còn hạn mức.';

  @override
  String get setupHttp404Title => 'Địa chỉ hoặc model không tồn tại';

  @override
  String get setupHttp404BodyDefault =>
      'Đối phương không tìm thấy endpoint này.';

  @override
  String get setupHttp404Suggest =>
      'Kiểm tra địa chỉ base có thiếu hoặc thừa /v1 không, ví dụ https://api.openai.com/v1.';

  @override
  String get setupHttp429Title => 'Quá nhiều yêu cầu, hoặc đã hết hạn mức';

  @override
  String get setupHttp429BodyDefault =>
      'Đối phương đang giới hạn tần suất yêu cầu.';

  @override
  String get setupHttp429Suggest =>
      'Đợi một phút rồi thử lại. Nếu vẫn lỗi, hãy kiểm tra hạn mức tài khoản.';

  @override
  String setupHttp5xxTitle(String status) {
    return 'Nhà cung cấp tạm thời bị lỗi ($status)';
  }

  @override
  String get setupHttp5xxBodyDefault =>
      'Server của họ bị lỗi - không phải lỗi cấu hình của bạn.';

  @override
  String get setupHttp5xxSuggest =>
      'Thử lại sau, hoặc chuyển sang nhà cung cấp khác.';

  @override
  String setupHttpOtherTitle(String status) {
    return 'Thử nghiệm không đạt ($status)';
  }

  @override
  String get setupHttpOtherBodyDefault =>
      'Đối phương trả về trạng thái không mong đợi.';

  @override
  String get setupHttpOtherSuggest =>
      'Gửi thông báo này cho AI để nhanh chóng xác định vấn đề.';

  @override
  String get setupPresetDeepseekLabel =>
      'DeepSeek (khuyên dùng · kết nối trực tiếp trong Trung Quốc)';

  @override
  String get setupPresetDeepseekNote =>
      'Giá rẻ, kết nối trực tiếp trong Trung Quốc; người dùng mới thường có hạn mức tặng';

  @override
  String get setupPresetDeepseekKeyHint =>
      'Tạo trong mục \"API Keys\" tại platform.deepseek.com; có dạng sk-xxxxxx';

  @override
  String get setupPresetOpenaiLabel => 'OpenAI (cần mạng hải ngoại)';

  @override
  String get setupPresetOpenaiNote =>
      'Ở Trung Quốc cần proxy mới truy cập được';

  @override
  String get setupPresetOpenaiKeyHint =>
      'Tạo trong mục \"API keys\" tại platform.openai.com; có dạng sk-xxxxxx';

  @override
  String get setupPresetKimiLabel =>
      'Kimi Moonshot (kết nối trực tiếp trong Trung Quốc)';

  @override
  String get setupPresetKimiNote =>
      'Kết nối trực tiếp trong Trung Quốc, mạnh về văn bản dài';

  @override
  String get setupPresetKimiKeyHint =>
      'Tạo tại platform.moonshot.cn; có dạng sk-xxxxxx';

  @override
  String get setupPresetGlmLabel =>
      'Zhipu GLM (kết nối trực tiếp trong Trung Quốc)';

  @override
  String get setupPresetGlmNote =>
      'Kết nối trực tiếp trong Trung Quốc, có gói miễn phí';

  @override
  String get setupPresetGlmKeyHint =>
      'Tạo trong mục \"API Keys\" tại bigmodel.cn';

  @override
  String get setupPresetQwenLabel =>
      'Qwen DashScope (kết nối trực tiếp trong Trung Quốc)';

  @override
  String get setupPresetQwenNote =>
      'Nền tảng Alibaba Cloud Bailian, tương thích OpenAI';

  @override
  String get setupPresetQwenKeyHint =>
      'Tạo API-KEY tại bailian.console.aliyun.com';

  @override
  String get setupPresetSiliconflowLabel => 'SiliconFlow';

  @override
  String get setupPresetSiliconflowNote =>
      'Tổng hợp nhiều model mã nguồn mở, kết nối trực tiếp trong Trung Quốc';

  @override
  String get setupPresetSiliconflowKeyHint => 'Tạo API key tại siliconflow.cn';

  @override
  String get setupPresetCustomLabel =>
      'Tùy chỉnh (mọi dịch vụ tương thích OpenAI)';

  @override
  String get setupPresetCustomNote =>
      'Chọn mục này nếu dùng gateway tự host, mạng nội bộ công ty, hoặc gateway chuyển đổi Claude';

  @override
  String get setupPresetCustomKeyHint =>
      'Nhập địa chỉ đến tầng /v1, ví dụ https://your-gateway.com/v1';

  @override
  String get settingsUpdateTitle => 'Kiểm tra cập nhật';

  @override
  String settingsUpdateHint(String version) {
    return 'Phiên bản hiện tại $version. Phân phối sideload không có cửa hàng ứng dụng; thông báo cập nhật đến từ trang chủ thức.';
  }

  @override
  String get settingsUpdateButton => 'Kiểm tra ngay';

  @override
  String get settingsUpdateChecking => 'Đang kiểm tra…';

  @override
  String get settingsUpdateUpToDate => 'Bạn đang dùng bản mới nhất';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Đã có phiên bản mới $version';
  }

  @override
  String get settingsUpdateOpenDownload => 'Mở trang tải xuống';

  @override
  String get settingsUpdateNetworkError =>
      'Kiểm tra thất bại: mạng không khả dụng, vui lòng thử lại sau';

  @override
  String get settingsUpdateBadResponse =>
      'Kiểm tra thất bại: không đọc được thông tin phiên bản từ trang chủ thức';

  @override
  String get reportCenterTitle => 'Trung tâm báo cáo';

  @override
  String get reportTabSubmit => 'Gửi báo cáo';

  @override
  String get reportTabMine => 'Phiếu của tôi';

  @override
  String get reportTabInbox => 'Phiếu liên quan đến tôi';

  @override
  String get reportReasonLabel => 'Lý do báo cáo';

  @override
  String get reportReasonSpam => 'Spam hoặc quấy rối hàng loạt';

  @override
  String get reportReasonHarassment => 'Quấy rối, lăng mạng hoặc đe dọa';

  @override
  String get reportReasonIllegalContent => 'Nội dung vi phạm pháp luật';

  @override
  String get reportReasonFakeIdentity => 'Danh tính giả hoặc mạo danh';

  @override
  String get reportReasonOther => 'Khác (mô tả bên dưới)';

  @override
  String get reportTargetLabel => 'Đối tượng bị báo cáo';

  @override
  String get reportTargetHint => 'Agent ID của đối tượng bị báo cáo';

  @override
  String get reportDetailLabel => 'Mô tả thêm (không bắt buộc)';

  @override
  String get reportDetailHint =>
      'Tối đa 280 ký tự. Chỉ dùng làm tham khảo khi xét duyệt.';

  @override
  String get reportSubmit => 'Gửi báo cáo';

  @override
  String get reportSubmitting => 'Đang gửi…';

  @override
  String reportSubmitted(String ticket) {
    return 'Đã tiếp nhận báo cáo. Phiếu $ticket';
  }

  @override
  String get reportDuplicate =>
      'Phiếu này đã tồn tại; không tạo bản trùng lặp.';

  @override
  String get reportNeedReason => 'Hãy chọn một lý do.';

  @override
  String get reportNeedTarget => 'Hãy nhập đối tượng bị báo cáo.';

  @override
  String get reportOtherNeedsDetail =>
      'Chỉ chọn \"Khác\" khi bạn mô tả rõ trong phần ghi chú.';

  @override
  String get reportEmptyMine => 'Bạn chưa gửi báo cáo nào.';

  @override
  String get reportEmptyInbox => 'Không có phiếu nào liên quan đến bạn.';

  @override
  String get reportTicketLabel => 'Mã phiếu';

  @override
  String get reportStatusOpen => 'Đã tiếp nhận';

  @override
  String get reportStatusTriaged => 'Đã phân loại';

  @override
  String get reportStatusInReview => 'Đang xét duyệt';

  @override
  String get reportStatusActioned => 'Đã xử lý';

  @override
  String get reportStatusRejected => 'Không đủ cơ sở xử lý';

  @override
  String get reportStatusAppealed => 'Đã khiếu nại';

  @override
  String get reportStatusClosed => 'Đã đóng';

  @override
  String get reportStatusWithdrawn => 'Đã rút lại';

  @override
  String get reportStatusNote => 'Ghi chú';

  @override
  String get reportActionLabel => 'Biện pháp xử lý';

  @override
  String get reportAppeal => 'Khiếu nại';

  @override
  String get reportWithdraw => 'Rút lại';

  @override
  String get reportAppealTitle => 'Gửi khiếu nại';

  @override
  String get reportAppealNote =>
      'Lý do khiếu nại (không bắt buộc, tối đa 280 ký tự)';

  @override
  String get reportAppealSubmitted => 'Đã gửi khiếu nại.';

  @override
  String get reportWithdrawDone => 'Đã rút báo cáo.';

  @override
  String get reportLookupTitle => 'Tra cứu theo mã phiếu';

  @override
  String get reportLookupHint => 'Mã phiếu (RPT-…)';

  @override
  String get reportLookupButton => 'Tra cứu';

  @override
  String get reportLookupNotFound =>
      'Không tìm thấy phiếu, hoặc phiếu không thuộc về bạn.';

  @override
  String get reportContactEntry => 'Báo cáo liên hệ này';

  @override
  String get reportErrHubNotConfigured => 'Chưa cấu hình địa chỉ máy chủ.';

  @override
  String get reportErrEd25519Required =>
      'Danh tính này chưa được nâng cấp sang danh tính khóa công khai.';

  @override
  String get reportErrNetwork => 'Không có kết nối mạng.';

  @override
  String get reportErrRateLimited =>
      'Báo cáo quá nhiều trong thời gian ngắn. Hãy thử lại sau.';

  @override
  String reportFailed(String code) {
    return 'Thất bại: $code';
  }

  @override
  String get helpReportGuideTitle => 'Báo cáo và phiếu';

  @override
  String get helpReportGuideBody =>
      'Báo cáo được gửi trong ứng dụng, không qua email. Bạn nhận được mã phiếu ngay và có thể tra cứu trạng thái bất cứ lúc nào. Đối tượng bị báo cáo không bao giờ biết ai đã báo cáo họ, và khiếu nại chỉ được một lần.';

  @override
  String get reportCenterSubtitle =>
      'Gửi báo cáo, theo dõi trạng thái, hoặc khiếu nại quyết định xử lý.';

  @override
  String get reportErrSelfReport => 'Bạn không thể báo cáo chính mình.';

  @override
  String get reportErrNotFound => 'Không có phiếu đó, hoặc không phải của bạn.';

  @override
  String get reportErrAppealExhausted =>
      'Quyền khiếu nại cho phiếu này đã được dùng.';

  @override
  String get reportErrAuth =>
      'Máy chủ không xác thực được danh tính của bạn. Hãy đăng nhập lại và thử lại.';
}
