plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "me.douwen.gohome.go_home"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "me.douwen.gohome.go_home"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 注意：不要在这里设 `ndk.abiFilters`，会与下面的 `splits.abi` 冲突报
        // "Conflicting configuration: 'ndk abiFilters' cannot be present when splits abi filters are set"
    }

    // 按 ABI 拆分。
    // 仅在 `flutter build apk --split-per-abi` 时启用（Flutter 会传 -Psplit-per-abi=true）。
    // 否则 Flutter 插件会把 armv7/arm64/x86_64 都塞进 ndk.abiFilters，与 splits 冲突。
    //
    // 命令对照：
    // - flutter build apk                              → 普通 universal APK（含 x86_64，约 134MB）
    // - flutter build apk --split-per-abi              → armv7 + arm64 两个独立 APK（本块生效）
    // - flutter build apk --target-platform=android-arm,android-arm64 --split-per-abi → 同上
    // - flutter build appbundle                        → AAB，Play 自动按设备分发
    val splitPerAbi = project.findProperty("split-per-abi")
        ?.toString()?.toBoolean() == true
    if (splitPerAbi) {
        splits {
            abi {
                isEnable = true
                reset()
                include("armeabi-v7a", "arm64-v8a")
                isUniversalApk = false
            }
        }
    }

    // 打包阶段去除一些腾讯 SDK 带的重复 META-INF 文件与 x86 架构 .so
    packaging {
        resources {
            excludes += listOf(
                "META-INF/*.kotlin_module",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/DEPENDENCIES",
                "META-INF/NOTICE*",
                "META-INF/LICENSE*",
                "META-INF/INDEX.LIST",
                "META-INF/io.netty.versions.properties",
            )
        }
        jniLibs {
            useLegacyPackaging = false
            // 显式剔除 x86/x86_64 .so。Flutter 插件对 ndk.abiFilters 的处理有点乱，
            // 改 abiFilters 有时 gradle 任务阶段已缓存，不如 jniLibs.excludes 干净。
            excludes += listOf("lib/x86/**", "lib/x86_64/**")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // TUICallKit / TRTC 的 ProGuard 要求（保留腾讯 SDK 所有 class）
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// 非 split-per-abi 模式下也把 x86/x86_64 从 ndk.abiFilters 剔掉，
// 与 packaging.jniLibs.excludes 互为保险（前者负责依赖 .aar 里的 .so 不被编链进来，
// 后者负责最终 APK 打包阶段剔除）。
project.afterEvaluate {
    val splitPerAbi = project.findProperty("split-per-abi")
        ?.toString()?.toBoolean() == true
    if (!splitPerAbi) {
        android.buildTypes.forEach { bt ->
            bt.ndk.abiFilters.remove("x86")
            bt.ndk.abiFilters.remove("x86_64")
        }
    }
}

flutter {
    source = "../.."
}
