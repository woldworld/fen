package world.wold.fen

import android.app.Notification
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * 大荒AI 通知读取服务（0.75.0 · W6/G9）。
 *
 * 职责边界（刻意做窄，与 DahuangAccessibilityService 同风格）：
 * 只把系统投递过来的通知**攒进一个进程内的小环缓冲**，供 App 内的
 * `notify_list` 工具按需读取。本类：
 *   · **不落库** —— 缓冲是纯内存的，进程被杀即清零（"按需读取、不留痕"）；
 *   · **不联网** —— 一个字节都不往外发；
 *   · **不回传历史** —— 只在服务已连接期间被动接收，装上之前的通知拿不到；
 *   · **不读自己的通知** —— 忽略本应用包名，避免自我循环。
 *
 * ★ 授权方式与无障碍不同：通知读取靠用户在系统设置「通知使用权」里手动勾选，
 *   **App 无法代开**。所以 [MainActivity] 只提供"跳转系统设置"这一条路。
 *
 * ★ 声明位置：`src/sideload/AndroidManifest.xml`。store 渠道不含该声明，
 *   本类虽会被编译进包，但不会被系统绑定、也不出现在通知使用权列表里。
 */
class DahuangNotificationListener : NotificationListenerService() {

    companion object {
        /** 内存环缓冲上限：够 `notify_list` 读最近一屏，却不至于把内存撑大。 */
        private const val MAX_BUFFER = 120

        private val lock = Any()
        private val buffer = ArrayDeque<Map<String, Any>>(MAX_BUFFER)

        @Volatile
        private var instance: DahuangNotificationListener? = null

        /** 包名 → 应用显示名 的小缓存（避免每条通知都走一次 PackageManager） */
        private val labelCache = HashMap<String, String>()

        /** 服务是否已连上系统（= 用户在系统设置里已勾选且未被系统回收） */
        fun isConnected(): Boolean = instance != null

        /**
         * 读取最近的通知（**只读快照**，不改变缓冲）。
         * @param sinceMs 只要 postTime ≥ 该毫秒值的（<=0 表示不限）
         * @param limit   最多返回多少条（按时间倒序取最新）
         */
        fun recent(sinceMs: Long, limit: Int): List<Map<String, Any>> {
            synchronized(lock) {
                val snapshot = buffer.toList()
                val filtered =
                    if (sinceMs > 0) snapshot.filter { (it["postTime"] as? Long ?: 0L) >= sinceMs }
                    else snapshot
                return filtered.takeLast(limit.coerceIn(1, MAX_BUFFER)).reversed()
            }
        }

        /** 清空缓冲（退出/关闭开关时调用，贯彻"不留痕"）。 */
        fun clear() = synchronized(lock) { buffer.clear() }

        private fun record(map: Map<String, Any>) {
            synchronized(lock) {
                buffer.addLast(map)
                while (buffer.size > MAX_BUFFER) buffer.removeFirst()
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
    }

    override fun onListenerDisconnected() {
        instance = null
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        // 忽略本应用自身的通知（避免"自己的提示又被自己读出来"的循环）
        if (n.packageName == packageName) return
        try {
            record(toMap(n))
        } catch (_: Exception) {
            // 单条通知解析失败（个别 ROM 的通知结构异常）绝不影响后续 —— 静默丢弃
        }
    }

    private fun toMap(sbn: StatusBarNotification): Map<String, Any> {
        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        val big = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
        val sub = extras?.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim() ?: ""
        return mapOf(
            "packageName" to sbn.packageName,
            "appLabel" to appLabel(sbn.packageName),
            "title" to title,
            "text" to (if (big.isNotEmpty()) big else text),
            "subText" to sub,
            "category" to (sbn.notification?.category ?: ""),
            "postTime" to sbn.postTime,
            "ongoing" to sbn.isOngoing,
        )
    }

    private fun appLabel(pkg: String): String {
        synchronized(lock) { labelCache[pkg]?.let { return it } }
        val label = try {
            val info: android.content.pm.ApplicationInfo =
                packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            pkg
        } catch (_: Exception) {
            pkg
        }
        synchronized(lock) { labelCache[pkg] = label }
        return label
    }
}
