/// 私聊语音/视频通话服务 — 跨平台入口
///
/// 底层使用腾讯云 TUICallKit（`tencent_calls_uikit`，含 UI + 信令 + 离线推送）。
/// 文档：https://cloud.tencent.com/document/product/647/82985
///
/// TUICallKit 仅支持 Android / iOS / macOS / Windows，不支持 Web。
/// 通过 Dart 条件导入：
/// - 原生平台 → [call_service_native.dart] 的真实实现
/// - Web 平台 → [call_service_web_stub.dart] 的 no-op stub（保证 `flutter build web` 通过）
library;

export 'call_service_native.dart'
    if (dart.library.html) 'call_service_web_stub.dart';
