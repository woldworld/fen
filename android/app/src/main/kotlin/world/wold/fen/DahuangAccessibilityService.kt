package world.wold.fen

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 大荒AI 屏幕助手：无障碍通道。
 *
 * 职责边界（刻意做窄）：只提供读屏 / 点击 / 输入 / 滑动 / 按键 / 打开应用
 * 六件事；授权、黑名单、审计全部由 Dart 侧负责，本类不做任何联网与存储。
 */
class DahuangAccessibilityService : AccessibilityService() {

    companion object {
        const val CHANNEL = "dahuang/device_control"

        @Volatile
        private var instance: DahuangAccessibilityService? = null

        fun get(): DahuangAccessibilityService? = instance
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    /** 由 MainActivity 的通道转发（服务未连接时不会被调用） */
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dumpUi" -> result.success(dumpUi())
            "tap" -> result.success(
                tap(call.argument<Int>("x") ?: -1, call.argument<Int>("y") ?: -1)
            )
            "swipe" -> result.success(
                swipe(
                    call.argument<Int>("x1") ?: -1,
                    call.argument<Int>("y1") ?: -1,
                    call.argument<Int>("x2") ?: -1,
                    call.argument<Int>("y2") ?: -1,
                    call.argument<Int>("durationMs") ?: 300
                )
            )
            "inputText" -> result.success(inputText(call.argument<String>("text") ?: ""))
            "pressKey" -> result.success(pressKey(call.argument<String>("key") ?: ""))
            "launchApp" -> result.success(launchApp(call.argument<String>("package") ?: ""))
            "currentPackage" -> result.success(currentPackage())
            else -> result.notImplemented()
        }
    }

    private fun dumpUi(): List<Map<String, Any?>> {
        val root = rootInActiveWindow ?: return emptyList()
        val out = ArrayList<Map<String, Any?>>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 500 && out.size < 200) {
            val node = queue.removeFirst()
            visited++
            val text = (node.text?.toString()
                ?: node.contentDescription?.toString()
                ?: "").trim()
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (text.isNotEmpty() || node.isClickable) {
                out.add(
                    mapOf(
                        "text" to text,
                        "className" to (node.className?.toString() ?: ""),
                        "x1" to rect.left,
                        "y1" to rect.top,
                        "x2" to rect.right,
                        "y2" to rect.bottom,
                        "clickable" to node.isClickable,
                        "editable" to node.isEditable
                    )
                )
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                queue.add(child)
            }
        }
        return out
    }

    private fun tap(x: Int, y: Int): Boolean {
        if (x < 0 || y < 0) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        val path = Path()
        path.moveTo(x.toFloat(), y.toFloat())
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0L, 60L))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    private fun swipe(x1: Int, y1: Int, x2: Int, y2: Int, durationMs: Int): Boolean {
        if (x1 < 0 || y1 < 0 || x2 < 0 || y2 < 0) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        val path = Path()
        path.moveTo(x1.toFloat(), y1.toFloat())
        path.lineTo(x2.toFloat(), y2.toFloat())
        val safeDuration = durationMs.toLong().coerceIn(50L, 3000L)
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0L, safeDuration))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    private fun inputText(text: String): Boolean {
        if (text.isEmpty()) return false
        val node = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    /**
     * 只支持三个全局按键：返回 / 主页 / 最近任务。
     *
     * 微信类的"回车发送"不在这里做——无障碍 API 没有跨版本可靠的注入方式
     * （ACTION_IME_ENTER 需要更高的 compileSdk，且在国产 ROM 上行为不一致），
     * Dart 侧已同步把 "enter" 从参数白名单里移除。
     */
    private fun pressKey(key: String): Boolean {
        return when (key.lowercase()) {
            "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
            "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
            "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
            else -> false
        }
    }

    private fun launchApp(pkg: String): Boolean {
        if (pkg.isEmpty()) return false
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun currentPackage(): String {
        return rootInActiveWindow?.packageName?.toString() ?: ""
    }
}

