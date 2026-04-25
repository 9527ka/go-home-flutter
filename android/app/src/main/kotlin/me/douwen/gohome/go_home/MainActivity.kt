package me.douwen.gohome.go_home

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 继承 FlutterFragmentActivity 而非 FlutterActivity：
// TUICallKit 的来电 / 通话页会用 DialogFragment 做悬浮/覆盖 UI，要求宿主 Activity 是 FragmentActivity。
// 用普通 FlutterActivity 时，通话 UI 可能不弹或崩溃。
class MainActivity : FlutterFragmentActivity() {
    private val soundChannelName = "com.gohome/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 与 iOS 保持一致的通道名：com.gohome/sound
        // playMessageSound: 播放系统通知铃声（受静音键和通知权限约束）
        // showLocalNotification: Android 侧暂不实现系统横幅（依赖 Flutter 侧 InAppNotifier 前台兜底）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, soundChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playMessageSound" -> {
                        try {
                            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                            ringtone?.play()
                            result.success(null)
                        } catch (e: Exception) {
                            result.success(null) // 静默失败，不影响主流程
                        }
                    }
                    "showLocalNotification" -> {
                        // Android 前台横幅走 Flutter 侧 InAppNotifier；后台通知需要配合 FCM，此处 no-op
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
