import Flutter
import UIKit
import AudioToolbox
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 设置通知代理
    UNUserNotificationCenter.current().delegate = self

    if let flutterVC = self.window?.rootViewController as? FlutterViewController {
      flutterVC.view.backgroundColor = UIColor(
        red: 0.357, green: 0.627, blue: 0.910, alpha: 1.0  // #5BA0E8
      )

      // 消息提示音 & 本地通知 MethodChannel
      let soundChannel = FlutterMethodChannel(name: "com.gohome/sound", binaryMessenger: flutterVC.binaryMessenger)
      soundChannel.setMethodCallHandler { (call, result) in
        if call.method == "playMessageSound" {
          AudioServicesPlaySystemSound(1007)
          result(nil)
        } else if call.method == "showLocalNotification" {
          // 前台本地通知横幅
          guard let args = call.arguments as? [String: Any] else {
            result(nil)
            return
          }
          let title = args["title"] as? String ?? ""
          let body = args["body"] as? String ?? ""
          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          content.sound = .default
          let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // 立即触发
          )
          UNUserNotificationCenter.current().add(request) { _ in }
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      // 推送通知 MethodChannel
      let push = FlutterMethodChannel(name: "com.gohome/push", binaryMessenger: flutterVC.binaryMessenger)
      self.pushChannel = push
      push.setMethodCallHandler { (call, result) in
        if call.method == "requestPermission" {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
              DispatchQueue.main.async {
                application.registerForRemoteNotifications()
              }
            }
            DispatchQueue.main.async {
              result(granted)
            }
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - APNs 注册回调

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod("onToken", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[APNs] Registration failed: \(error.localizedDescription)")
  }

  // MARK: - UNUserNotificationCenterDelegate

  // 前台收到通知：显示横幅和提示音（用户可能不在聊天页面）
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }

  // 用户点击通知：打开 APP（默认行为）
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
