import Flutter
import UIKit
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 设置 Flutter 引擎加载期间的背景色，与 Splash 页面一致，避免白屏闪烁
    if let flutterVC = self.window?.rootViewController as? FlutterViewController {
      flutterVC.view.backgroundColor = UIColor(
        red: 0.357, green: 0.627, blue: 0.910, alpha: 1.0  // #5BA0E8
      )

      // 注册消息提示音 MethodChannel
      let channel = FlutterMethodChannel(name: "com.gohome/sound", binaryMessenger: flutterVC.binaryMessenger)
      channel.setMethodCallHandler { (call, result) in
        if call.method == "playMessageSound" {
          // 1007 = 经典收到消息提示音（三全音）
          AudioServicesPlaySystemSound(1007)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
