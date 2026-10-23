# 🚀 保护后台任务管理器 (WorkManager) 不被混淆删除
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }

# 🚀 保护底层 Room 数据库核心组件
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class *

# 忽略它们产生的无害警告
-dontwarn androidx.work.**
-dontwarn androidx.room.**