package world.wold.fen

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationManager
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CalendarContract
import android.provider.Settings
import android.provider.Telephony
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /// 值班引导：ROM 识别 + 厂商自启动设置页跳转（层 2，见 rom_guide_service.dart）。
    private val romChannel = "dahuang/rom"

    /// 系统日历（只读）通道（0.74.0 W5/S6）：见 calendar_service.dart。
    /// 刻意只读 —— 只查 CalendarContract.Instances，永不做任何写入。
    /// ★ 授权也在这里自持（`status` / `request` 两个方法）—— 不用
    ///   permission_handler 的通用日历组：本仓锁定的 platform_interface 4.4.0
    ///   只剩 `calendar`(读写组)/`calendarWriteOnly`/`calendarFullAccess`，
    ///   没有"只读"枚举 ⇒ 用它等于连写权限一起请求，破坏只读红线。
    private val calendarChannel = "dahuang/calendar"
    private val calendarPermissionRequest = 7202
    private var pendingCalendarPermission: MethodChannel.Result? = null

    /// 语音转文字（0.72.0 W3/S4）：系统 SpeechRecognizer 的通道封装。
    /// 识别结果经 invokeMethod 回推 Dart（onPartial / onFinal / onError）。
    /// ★ SpeechRecognizer 必须在主线程创建与调用（configureFlutterEngine 即主线程）。
    private val voiceChannelName = "dahuang/voice"
    private var voiceChannel: MethodChannel? = null
    private var recognizer: SpeechRecognizer? = null

    /// 通知监听 + 短信（0.75.0 W6/G9）：只读通道。见 notification_sms_service.dart。
    /// ★ 受限权限（READ_SMS）与 NotificationListenerService 只在 **sideload** 渠道
    ///   声明（src/sideload/AndroidManifest.xml）⇒ store 渠道下 `supported=false`，
    ///   Dart 侧安全降级为"当前版本不支持"，绝不给出点了没反应的开关。
    /// ★ 只读：通知走内存环缓冲（不落库），短信只查 Telephony provider，
    ///   全程零发送、零写入。
    private val notifySmsChannel = "dahuang/notify_sms"
    private val smsPermissionRequest = 7203
    private var pendingSmsPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            romChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRomInfo" -> result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "brand" to Build.BRAND,
                        "model" to Build.MODEL
                    )
                )
                "openAutoStartSettings" -> result.success(openAutoStartSettings())
                else -> result.notImplemented()
            }
        }

        // ===== 系统日历（0.74.0 W5/S6）：只读读取当天日程 ====================
        // 只查 CalendarContract.Instances；未授权 / 无权限 ⇒ 返回空表，
        // Dart 侧用 CalendarService.status() 区分「没日程」与「读不到」。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            calendarChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "supported" to true,
                        "granted" to hasCalendarPermission()
                    )
                )
                "request" -> {
                    if (hasCalendarPermission()) {
                        result.success(true)
                    } else {
                        // 结果经 onRequestPermissionsResult 回推（异步）
                        pendingCalendarPermission = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CALENDAR),
                            calendarPermissionRequest
                        )
                    }
                }
                "listEvents" -> {
                    val startMs = call.argument<Long>("startMs") ?: 0L
                    val endMs = call.argument<Long>("endMs") ?: 0L
                    result.success(queryCalendarEvents(startMs, endMs))
                }
                else -> result.notImplemented()
            }
        }

        // ===== 通知监听 + 短信（0.75.0 W6/G9）：只读通道 ==================
        // 三个布尔各说一件事，避免"开了却没数据"的黑盒（同无障碍 status 的思路）：
        //   supported          —— 本安装包是否带这套能力（store 渠道 = false）
        //   listenerEnabled    —— 系统设置「通知使用权」里是否已勾选本应用
        //   listenerConnected  —— 服务是否已被系统绑定（能不能真的收到通知）
        // smsDeclared / smsGranted 同理拆开：前者是"装没装这套权限"（渠道决定），
        // 后者是"用户授没授权"——两者混在一起会让用户以为是自己没点对。
        //
        // ★ 全程**只读**：未声明 / 未授权 / 异常一律返回空表或 false，
        //   **绝不**抛异常给 Dart（增益功能不得带崩调用方）。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notifySmsChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "supported" to isNotifySmsSupported(),
                        "listenerDeclared" to isListenerDeclared(),
                        "listenerEnabled" to isListenerEnabled(),
                        "listenerConnected" to DahuangNotificationListener.isConnected(),
                        "smsDeclared" to isSmsDeclared(),
                        "smsGranted" to hasSmsPermission()
                    )
                )
                "openSettings" -> result.success(openNotificationListenerSettings())
                "requestSms" -> {
                    if (!isSmsDeclared()) {
                        result.success(false)
                    } else if (hasSmsPermission()) {
                        result.success(true)
                    } else {
                        // 结果经 onRequestPermissionsResult 回推（异步）
                        pendingSmsPermission = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS),
                            smsPermissionRequest
                        )
                    }
                }
                "listNotifications" -> {
                    val sinceMs = call.argument<Long>("sinceMs") ?: 0L
                    val limit = call.argument<Int>("limit") ?: 50
                    result.success(DahuangNotificationListener.recent(sinceMs, limit))
                }
                "clearNotifications" -> {
                    DahuangNotificationListener.clear()
                    result.success(true)
                }
                "listSms" -> {
                    val sinceMs = call.argument<Long>("sinceMs") ?: 0L
                    val limit = call.argument<Int>("limit") ?: 50
                    result.success(querySms(sinceMs, limit))
                }
                else -> result.notImplemented()
            }
        }

        // ===== 语音转文字（0.72.0 W3/S4）：系统 SpeechRecognizer ============
        // 结果回推三个方法名：onPartial（实时上屏）/ onFinal（停止后一次给全）/
        // onError（设备级失败：no_speech / no_match / busy / error_N）。
        voiceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            voiceChannelName
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(
                        SpeechRecognizer.isRecognitionAvailable(this)
                    )
                    "start" -> {
                        val started = startVoiceRecognition(
                            call.argument<String>("locale")
                        )
                        result.success(started)
                    }
                    "stop" -> {
                        try { recognizer?.stopListening() } catch (_: Exception) {}
                        result.success(true)
                    }
                    "cancel" -> {
                        try { recognizer?.cancel() } catch (_: Exception) {}
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DahuangAccessibilityService.CHANNEL
        ).setMethodCallHandler { call, result ->
            val service = DahuangAccessibilityService.get()
            when (call.method) {
                // 三个字段区分三种状态，避免"勾了却检测不到"的黑盒：
                //   supported     —— 安装包是否带无障碍模块
                //   enabled       —— 服务是否已真正连上（能不能干活）
                //   systemEnabled —— 系统设置里是否已勾选（排查用）
                "status" -> result.success(
                    mapOf(
                        "supported" to true,
                        "enabled" to (service != null),
                        "systemEnabled" to isAccessibilityServiceEnabled()
                    )
                )
                "openSettings" -> result.success(openAccessibilitySettings())
                else -> {
                    if (service == null) {
                        result.success(null)
                    } else {
                        service.handle(call, result)
                    }
                }
            }
        }
    }

    /**
     * 系统设置里是否已勾选本应用的无障碍服务。
     * 与"服务实例是否已连上"解耦：勾了但没连上时，UI 会给出针对性的排查提示。
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val expected = "$packageName/${DahuangAccessibilityService::class.java.name}"
            val manager =
                getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            if (manager != null) {
                @Suppress("DEPRECATION")
                val enabled = manager.getEnabledAccessibilityServiceList(
                    AccessibilityServiceInfo.FEEDBACK_ALL_MASK
                )
                for (info in enabled) {
                    val serviceInfo = info.resolveInfo?.serviceInfo ?: continue
                    val id = "${serviceInfo.packageName}/${serviceInfo.name}"
                    if (id.equals(expected, ignoreCase = true)) return true
                }
            }
            // 兜底：直接读系统设置字符串（个别 ROM 的列表接口不准）
            val raw = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return raw.split(':').any { it.equals(expected, ignoreCase = true) }
        } catch (e: Exception) {
            false
        }
    }

    private fun openAccessibilitySettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 打开厂商的"自启动管理"设置页（层 2 值班引导的核心跳转）。
     *
     * 各厂商组件名随 ROM 版本漂移，所以按当前厂商给一组候选、逐一尝试，
     * 全部失败再兜底到本应用的应用详情页（用户从那里手动进自启动）。
     * 每次尝试独立 try/catch：任何一个组件不存在都不能带崩调用。
     */
    private fun openAutoStartSettings(): Boolean {
        val candidates = autoStartComponents(
            Build.MANUFACTURER.lowercase(), Build.BRAND.lowercase()
        )
        for ((pkg, cls) in candidates) {
            try {
                val intent = Intent()
                    .setClassName(pkg, cls)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // 该 ROM 版本没有此页面 —— 试下一个候选
            }
        }
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /** 按厂商/品牌给出自启动设置页候选组件（顺序 = 尝试顺序）。 */
    private fun autoStartComponents(manufacturer: String, brand: String): List<Pair<String, String>> = when {
        manufacturer.contains("xiaomi") || brand.contains("xiaomi") || brand.contains("redmi") -> listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.miui.securitycenter" to "com.miui.permcenter.permissions.PermissionsEditorActivity"
        )
        manufacturer.contains("honor") || brand.contains("honor") -> listOf(
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
        )
        manufacturer.contains("huawei") || brand.contains("huawei") -> listOf(
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity"
        )
        manufacturer.contains("oppo") || brand.contains("realme") -> listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity"
        )
        manufacturer.contains("oneplus") || brand.contains("oneplus") -> listOf(
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity"
        )
        manufacturer.contains("vivo") || brand.contains("iqoo") -> listOf(
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
        )
        manufacturer.contains("meizu") || brand.contains("meizu") -> listOf(
            "com.meizu.safe" to "com.meizu.safe.permission.SmartBGActivity"
        )
        else -> emptyList()
    }

    /**
     * 启动一次语音识别（0.72.0 W3）。返回 false = 设备没有可用识别服务
     * （Dart 侧据此给出降级提示，红线：不静默失败）。
     * 每次都重建 recognizer：个别 ROM 的实例复用会第二次 start 直接 busy。
     */
    private fun startVoiceRecognition(localeTag: String?): Boolean {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return false
        try { recognizer?.destroy() } catch (_: Exception) {}
        val sr = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer = sr
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            if (!localeTag.isNullOrBlank()) {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            }
        }
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                val msg = when (error) {
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no_speech"
                    SpeechRecognizer.ERROR_NO_MATCH -> "no_match"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission"
                    else -> "error_$error"
                }
                voiceChannel?.invokeMethod("onError", msg)
            }

            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                voiceChannel?.invokeMethod("onFinal", text)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.lastOrNull() ?: ""
                if (text.isNotEmpty()) voiceChannel?.invokeMethod("onPartial", text)
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        sr.startListening(intent)
        return true
    }

    /**
     * 只读查询窗口 [startMs, endMs) 内的日历日程（0.74.0 W5/S6）。
     *
     * 未授权或参数非法 ⇒ 返回空表（Dart 侧用 status() 区分「没日程」与
     * 「读不到」，不静默失败）。任何查询异常都吞掉返回空表 —— 日历是增益，
     * 绝不能带崩调用方。
     */
    /** READ_CALENDAR 是否已授权（只读；从不申请写权限）。 */
    private fun hasCalendarPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    private fun queryCalendarEvents(startMs: Long, endMs: Long): List<Map<String, Any>> {
        if (startMs <= 0L || endMs <= startMs) return emptyList()
        if (!hasCalendarPermission()) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        try {
            val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            ContentUris.appendId(builder, startMs)
            ContentUris.appendId(builder, endMs)
            val projection = arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.CALENDAR_DISPLAY_NAME
            )
            val cursor = contentResolver.query(builder.build(), projection, null, null, null)
            cursor?.use { c ->
                val iTitle = c.getColumnIndex(CalendarContract.Instances.TITLE)
                val iBegin = c.getColumnIndex(CalendarContract.Instances.BEGIN)
                val iEnd = c.getColumnIndex(CalendarContract.Instances.END)
                val iAllDay = c.getColumnIndex(CalendarContract.Instances.ALL_DAY)
                val iCal = c.getColumnIndex(CalendarContract.Instances.CALENDAR_DISPLAY_NAME)
                while (c.moveToNext()) {
                    val title = if (iTitle >= 0) (c.getString(iTitle) ?: "") else ""
                    val begin = if (iBegin >= 0) c.getLong(iBegin) else 0L
                    val end = if (iEnd >= 0) c.getLong(iEnd) else 0L
                    val allDay = iAllDay >= 0 && c.getInt(iAllDay) == 1
                    val cal = if (iCal >= 0) (c.getString(iCal) ?: "") else ""
                    out.add(
                        mapOf(
                            "title" to title,
                            "beginMs" to begin,
                            "endMs" to end,
                            "allDay" to allDay,
                            "calendarName" to cal
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // 只读查询失败（个别 ROM 的 provider 异常）⇒ 降级为空表
        }
        return out
    }

    // ==================================================================
    // 通知监听 + 短信（0.75.0 W6/G9）—— 只读，全部带能力/授权双重判定
    // ==================================================================

    /**
     * 本安装包是否具备"通知监听 + 短信"能力（= 是不是 sideload 渠道构建）。
     *
     * 不靠 flavor 常量（那样 Kotlin 侧要引 BuildConfig.FLAVOR，且 store/sideload
     * 共用同一 applicationId 时更绕），而是**直接问系统**：本包声明了
     * 通知监听服务或 READ_SMS 吗？声明与否完全由 src/sideload/AndroidManifest.xml
     * 决定 ⇒ 这个判定与打包渠道天然一致，也不会因为改 Gradle 而失真。
     */
    private fun isNotifySmsSupported(): Boolean = isListenerDeclared() || isSmsDeclared()

    /** 通知监听服务是否在本包里声明（sideload=true / store=false）。 */
    private fun isListenerDeclared(): Boolean = try {
        @Suppress("DEPRECATION")
        val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SERVICES)
        info.services?.any {
            it.name == DahuangNotificationListener::class.java.name
        } == true
    } catch (_: Exception) {
        false
    }

    /** READ_SMS 是否在**清单里声明**（注意：不是"是否已授权"）。 */
    private fun isSmsDeclared(): Boolean = try {
        @Suppress("DEPRECATION")
        val info = packageManager.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
        info.requestedPermissions?.contains(Manifest.permission.READ_SMS) == true
    } catch (_: Exception) {
        false
    }

    /** READ_SMS 是否已获用户授权（未声明时必然为 false）。 */
    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    /** 系统设置「通知使用权」里是否已勾选本应用（勾了不代表服务一定连上）。 */
    private fun isListenerEnabled(): Boolean = try {
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
    } catch (_: Exception) {
        false
    }

    /**
     * 跳转系统「通知使用权」设置页。
     * ★ 这条权限**无法在 App 内代开**（系统强制用户手动勾选），
     *   所以 UI 只能提供跳转 + 回来自查，不能给"一键开启"。
     */
    private fun openNotificationListenerSettings(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (_: Exception) {
        false
    }

    /**
     * 只读查询短信（0.75.0 W6/G9）。
     *
     * 只查 `Telephony.Sms` provider，**零发送、零写入**；未授权 ⇒ 返回空表
     * （Dart 侧用 status() 区分「没有短信」与「读不到」，不静默失败）。
     * 取数用「按日期倒序 + 循环里计数截断」而**不是**在 sortOrder 里塞 LIMIT
     * —— 部分 ROM 的 Sms provider 不认 sortOrder 里的 LIMIT，会把整表返回。
     */
    private fun querySms(sinceMs: Long, limit: Int): List<Map<String, Any>> {
        if (!hasSmsPermission()) return emptyList()
        val cap = limit.coerceIn(1, 200)
        val out = ArrayList<Map<String, Any>>()
        try {
            val projection = arrayOf(
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.READ,
                Telephony.Sms.TYPE
            )
            val selection = if (sinceMs > 0) "${Telephony.Sms.DATE} >= ?" else null
            val selectionArgs = if (sinceMs > 0) arrayOf(sinceMs.toString()) else null
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${Telephony.Sms.DATE} DESC"
            )
            cursor?.use { c ->
                val iAddr = c.getColumnIndex(Telephony.Sms.ADDRESS)
                val iBody = c.getColumnIndex(Telephony.Sms.BODY)
                val iDate = c.getColumnIndex(Telephony.Sms.DATE)
                val iRead = c.getColumnIndex(Telephony.Sms.READ)
                val iType = c.getColumnIndex(Telephony.Sms.TYPE)
                while (c.moveToNext() && out.size < cap) {
                    out.add(
                        mapOf(
                            "address" to (if (iAddr >= 0) (c.getString(iAddr) ?: "") else ""),
                            "body" to (if (iBody >= 0) (c.getString(iBody) ?: "") else ""),
                            "dateMs" to (if (iDate >= 0) c.getLong(iDate) else 0L),
                            "read" to (iRead >= 0 && c.getInt(iRead) == 1),
                            "type" to (if (iType >= 0) c.getInt(iType) else 0)
                        )
                    )
                }
            }
        } catch (_: Exception) {
            // 只读查询失败（个别 ROM 的 provider 异常）⇒ 降级为空表
        }
        return out
    }

    /**
     * 日历权限回调（0.74.0 W5/S6）：把是否授权回推给 Dart 侧等待中的 `request`。
     * 无等待方（用户从系统设置返回等）时静默忽略。
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == calendarPermissionRequest) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingCalendarPermission?.success(granted)
            pendingCalendarPermission = null
        }
        if (requestCode == smsPermissionRequest) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSmsPermission?.success(granted)
            pendingSmsPermission = null
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        try { recognizer?.destroy() } catch (_: Exception) {}
        recognizer = null
        super.onDestroy()
    }
}
