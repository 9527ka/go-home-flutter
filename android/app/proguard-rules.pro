# =============================================================================
# TUICallKit / 腾讯云 TRTC / IM — keep 规则
# 参考：https://cloud.tencent.com/document/product/647/82985
# =============================================================================

# 腾讯所有 Java 代码（com.tencent.* / io.trtc.*）
-keep class com.tencent.** { *; }
-dontwarn com.tencent.**
-keep class io.trtc.** { *; }
-dontwarn io.trtc.**

# TUICallKit Flutter plugin 的 method channel bridge
-keep class com.tencent.cloud.tuikit.flutter.** { *; }
-keep class com.tencent.cloud.tuikit.engine.** { *; }
-keep class com.tencent.cloud.tuikit.** { *; }

# TRTC / LiteAV native JNI
-keep class com.tencent.liteav.** { *; }
-keep class com.tencent.rtmp.** { *; }
-keep class com.tencent.trtc.** { *; }
-keep class com.tencent.xmagic.** { *; }

# TIM SDK 的反射 / 序列化
-keep class com.tencent.imsdk.** { *; }
-keep class com.tencent.wcdb.** { *; }
-keep class com.tencent.tim.** { *; }
-keep class com.tencent.android.tpush.** { *; }
-keep class com.tencent.bugly.** { *; }
-keep class com.tencent.mm.opensdk.** { *; }

# atomic_x_core 的 Dart↔Kotlin 反射入口
-keep class com.tencent.atomicxcore.** { *; }

# Flutter plugin 注册表（release 构建偶尔被 R8 误杀导致插件不加载）
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# 反射属性（Gson 等 JSON 反序列化需要）
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations

# Serializable 反序列化
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# JNI native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# okhttp / okio（腾讯 IM / HTTP 回调栈）
-dontwarn okio.**
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# kotlinx.coroutines（TUICallKit 内部可能异步调用）
-keepclassmembernames class kotlinx.** { volatile <fields>; }
-dontwarn kotlinx.**
