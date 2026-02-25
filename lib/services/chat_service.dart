import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../config/api.dart';
import 'http_client.dart';

class ChatService {
  final _http = HttpClient();

  /// 获取聊天历史记录
  Future<Map<String, dynamic>> getHistory({int? beforeId, int limit = 50}) async {
    final params = <String, dynamic>{
      'limit': limit,
    };
    if (beforeId != null) params['before_id'] = beforeId;

    final res = await _http.get(ApiConfig.chatHistory, params: params);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return {'list': [], 'has_more': false};
  }

  /// 上传聊天图片 — 接收 XFile，兼容 Web 和原生平台
  Future<Map<String, dynamic>?> uploadImage(XFile xFile) async {
    final res = await _uploadXFile(ApiConfig.uploadImage, xFile);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// 上传聊天视频 — 接收 XFile，兼容 Web 和原生平台
  Future<Map<String, dynamic>?> uploadVideo(XFile xFile) async {
    final res = await _uploadXFile(ApiConfig.uploadVideo, xFile);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// 上传语音（仅原生平台，路径上传）
  Future<Map<String, dynamic>?> uploadVoice(String filePath) async {
    final res = await _http.upload(ApiConfig.uploadVoice, filePath: filePath);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// 举报聊天消息
  Future<bool> reportMessage({
    required int messageId,
    required int userId,
    required int reason,
    String description = '',
  }) async {
    final res = await _http.post(ApiConfig.reportCreate, data: {
      'target_type': 4, // 4=聊天消息
      'target_id': messageId,
      'target_user_id': userId,
      'reason': reason,
      'description': description,
    });
    return res['code'] == 0;
  }

  /// 举报/屏蔽用户
  Future<bool> reportUser(int userId, {String reason = ''}) async {
    final res = await _http.post(ApiConfig.reportCreate, data: {
      'target_type': 3, // 3=用户
      'target_id': userId,
      'reason': 4, // 骚扰辱骂
      'description': reason,
    });
    return res['code'] == 0;
  }

  /// 统一上传 XFile — Web 用 bytes，原生用 filePath
  Future<Map<String, dynamic>> _uploadXFile(String path, XFile xFile) async {
    if (kIsWeb) {
      final bytes = await xFile.readAsBytes();
      return _http.uploadBytes(
        path,
        bytes: bytes,
        fileName: xFile.name,
      );
    } else {
      return _http.upload(path, filePath: xFile.path);
    }
  }
}
