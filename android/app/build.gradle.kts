import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 🔐 正式签名密钥：有 android/key.properties 就用它，没有就回退调试签名。
// 密钥文件（*.jks）与 key.properties 已在 android/.gitignore 中排除，绝不入库。
// ⚠️ 必须用 import（不能写全限定名 java.util.Properties()）——
// 在 Gradle Kotlin DSL 的 Project 作用域里，`java` 会被解析成 Java 插件扩展，遮蔽同名包。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// ⚠️ 缺失密钥时**不得静默回退 debug 签名**（2026-09-28 改）。
// 为什么：debug 签名的包既不能覆盖升级、也不能上架，而"构建成功"会让人
// 以为发布包已经好了 —— 这类错误只有到用户装不上时才暴露，代价最大。
// 所以 release 构建缺密钥一律**显式失败**；非 release 构建（debug）不受影响。
//
// 判据用任务名而不是"当前是不是 release"：Gradle 在配置期就执行这段代码，
// 那时还没有 variant 概念。`assembleRelease` / `bundleRelease` 含 "Release"，
// 而 `flutter build apk --debug` 产出的是 `assembleDebug`，不会命中。
val wantsReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

// 🔓 F-Droid 通道（0.113.0）：F-Droid 构建服务器会用**仓库密钥自行签名**，
// 所以它要的是**未签名**的 release 包。显式环境变量 WOLD_UNSIGNED_RELEASE=1
// 才允许「无 key.properties 也继续构建 release」——不设这个变量时，缺密钥
// 仍然**显式失败**（禁止静默回退 debug 签名的纪律一字不让，见文件头注释）。
// 为什么用环境变量而不是 -P gradle property：F-Droid 的构建脚本只能设环境变量。
// 产物名随之带 -unsigned 后缀（AGP 惯例），F-Droid 的 metadata 配方按这个名字取包。
val wantsUnsignedRelease = System.getenv("WOLD_UNSIGNED_RELEASE") == "1"

android {
    // ★ 0.50.0：namespace 与 applicationId 对齐为 world.wold.fen（体检 P2「namespace 仍是
    //   com.example.mydoubao」）。★ namespace 只影响生成的 R / BuildConfig 与 manifest 里
    //   `.MainActivity` 这类**相对名**的解析，**不影响应用身份**（applicationId 早已是
    //   world.wold.fen，签名与覆盖升级关系一字未变）。同批把 Kotlin 源搬到
    //   `src/main/kotlin/world/wold/fen/` 并改各自的 `package` 声明 —— 三者必须一起动。
    namespace = "world.wold.fen"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 🔔 flutter_local_notifications 用到 java.time（Java 8+ 时间 API），
        // 在低版本 Android 上必须靠「核心库反糖」把它们脱糖成可用实现。
        // 不开这一项，release 打包会在 D8 阶段直接报 desugaring 缺失而失败。
        isCoreLibraryDesugaringEnabled = true
    }

    // 🚀 彻底移除了原先会导致报错的 android.kotlinOptions 闭包

    defaultConfig {
        applicationId = "world.wold.fen"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
       // 🚀 新增：跳过打包时的 Lint 安全合规分析，防止由于文件锁死导致打包崩溃
      lint {
        checkReleaseBuilds = false
        abortOnError = false
      }
    }

    // ==============================================================
    // 🧩 分发渠道 flavor 隔离（0.75.0 W6/G9 通知监听 + 短信）
    //
    // 为什么需要隔离：短信读取会用到 Google Play 的**受限权限**
    //   （READ_SMS / RECEIVE_SMS 属"SMS 与通话记录"政策，上架须申报、
    //    且对非"默认短信应用"基本必拒）。本 App 的定位是"侧载自用"，
    //   因此把受限能力收进一个只在**侧载构建**里出现的源集：
    //     · store    —— 公开分发/上架用：**零受限权限**，连通知监听服务
    //                   也一并留空（上架构建对用户零额外权限面）；
    //     · sideload —— 自己侧载安装用：额外声明 READ_SMS / RECEIVE_SMS
    //                   与 NotificationListenerService。
    //
    // ★★ 两个 flavor **必须共用同一 applicationId**（下面显式写死同一个值）——
    //    否则侧载包在系统眼里是"另一个应用"，**无法覆盖升级**既有 0.74.0 安装
    //    （既有的身份 private key / DB / 授权全部留在旧包名下，用户等于重装）。
    //    代价仅是 store / sideload 不能同时安装 —— 本来也只需要装一个。
    //
    // ★ 一旦声明了 flavor，`flutter build apk` / `flutter run` **必须显式带
    //   `--flavor store|sideload`**，否则 Flutter CLI 当场报错（不是警告）。
    //   侧载出包命令因此变成：
    //       flutter build apk --release --no-pub --flavor sideload
    //   产物名随之变为 `app-sideload-release.apk`（不再是 app-release.apk）。
    // ==============================================================
    flavorDimensions += "dist"
    productFlavors {
        create("store") {
            dimension = "dist"
            applicationId = "world.wold.fen"
        }
        create("sideload") {
            dimension = "dist"
            // 同一身份 ⇒ 可覆盖升级既有安装；受限权限只在 src/sideload 里声明
            applicationId = "world.wold.fen"
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties → 用正式密钥；没有且正在构建 release → 直接失败（见文件头注释）。
            // ★ 0.113.0 例外：显式 WOLD_UNSIGNED_RELEASE=1 时放行——产出**未签名**包，
            //   供 F-Droid 构建服务器用仓库密钥自签（它那边没有、也不该有我们的密钥）。
            //   这个例外**只认环境变量**：手敲 flutter build 忘带变量 = 照旧炸，纪律不变。
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (wantsReleaseBuild && !wantsUnsignedRelease) {
                throw GradleException(
                    "缺少 android/key.properties —— release 构建必须使用正式签名，不" +
                        "允许回退 debug 签名（那种包装不上、也上不了架）。放置方法见 " +
                        "lib/hub/deploy 下的部署说明；key.properties 与 .jks 均不入库。" +
                        "（确需未签名包给 F-Droid 自签时，显式设 WOLD_UNSIGNED_RELEASE=1。）"
                )
            }
            // wantsUnsignedRelease ⇒ 不设 signingConfig ⇒ AGP 产出 *-unsigned.apk

            // 开启混淆与资源压缩
            isMinifyEnabled = true
            isShrinkResources = true 
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 🔧 0.120.0：本机 AGP 的 stripStoreReleaseDebugSymbols 会撞 Windows 文件锁
    //   （llvm-strip: Permission denied），而失败只报 warn、不中断构建 ⇒
    //   未 strip 的副本被打进 APK（verify_apk_artifact.js ③ 会抓住）。
    //   处置：libdartjni.so 改由发布脚本在 merged_native_libs 里预先
    //   llvm-strip --strip-unneeded，这里声明保留符号以阻止 AGP 再调一次
    //   llvm-strip（那次必然失败）。打包取的就是已 strip 的那份。
    packaging {
        jniLibs {
            keepDebugSymbols += "**/libdartjni.so"
        }
    }
}

// 🔧 0.120.0：打包前对即将入包的 .so 补一刀 llvm-strip。
//   背景：本机 AGP 的 stripStoreReleaseDebugSymbols 会撞 Windows 文件锁
//   （llvm-strip: Permission denied），而失败只报 warn、不中断构建
//   ⇒ 未 strip 的副本被打进 APK（verify_apk_artifact.js ③ 会抓住）。
//   libdartjni.so 由 jni 插件 CMake(RelWithDebInfo) 产出，每次 merge 都会重拷，
//   所以只能在打包这一步前装配（android{} 里已对它声明
//   keepDebugSymbols，避开那次必失败的 strip）。
val woldNdkStrip: File = run {
    val winHost = System.getProperty("os.name").lowercase().contains("win")
    val host = if (winHost) "windows-x86_64" else "linux-x86_64"
    val bin = if (winHost) "llvm-strip.exe" else "llvm-strip"
    File("${android.ndkDirectory}/toolchains/llvm/prebuilt/${host}/bin/${bin}")
}

project.tasks.matching { it.name.startsWith("package") && it.name.endsWith("Release") }.configureEach {
    doFirst {
        val root = project.layout.buildDirectory.dir("intermediates/stripped_native_libs").get().asFile
        if (!woldNdkStrip.exists()) {
            logger.warn("[wold] llvm-strip 不存在：${woldNdkStrip.absolutePath}（跳过补 strip）")
        } else if (root.isDirectory) {
            var done = 0
            root.walkTopDown().filter { it.isFile && it.name.endsWith(".so") }.forEach { so ->
                val sizeBefore = so.length()
                try {
                    val p = ProcessBuilder(woldNdkStrip.absolutePath, "--strip-unneeded", so.absolutePath)
                        .redirectErrorStream(true)
                        .start()
                    p.inputStream.readBytes()
                    p.waitFor()
                    if (so.length() != sizeBefore) done++
                } catch (e: Exception) {
                    logger.warn("[wold] 补 strip 失败（守卫会复核）：${so.name} - ${e.message}")
                }
            }
            logger.lifecycle("[wold] 打包前补 strip 完成，体积变化文件数=${done}")
        }
    }
}

// 🚀 2026 现代 Kotlin 2.2 编译器选项规范（彻底解决 jvmTarget 报错）
// 将编译配置从 android 闭包中抽离到最外层，并使用标准的 compilerOptions.jvmTarget
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔔 核心库反糖实现（与上面 isCoreLibraryDesugaringEnabled 成对出现；
    //    缺了它 Gradle 会报 "core library desugaring is enabled but no
    //    desugar_jdk_libs dependency was found"）。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
