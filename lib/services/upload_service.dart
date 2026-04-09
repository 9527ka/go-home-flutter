import 'dart:io' show File;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api.dart';
import 'http_client.dart';

class UploadService {
  final _http = HttpClient();

  /// 规范化图片文件名，确保服务器能识别扩展名
  /// iOS 设备可能返回 HEIC/HEIF 格式，服务器只接受 jpg/jpeg/png/gif/webp
  static String _normalizeImageFileName(String originalName, List<int> bytes) {
    final ext = originalName.split('.').last.toLowerCase();
    const allowedExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};

    if (allowedExts.contains(ext)) return originalName;

    // 通过 magic bytes 检测实际格式
    final detectedExt = _detectImageExtension(bytes);
    final baseName = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    return '$baseName.$detectedExt';
  }

  /// 通过文件头魔术字节检测图片格式
  static String _detectImageExtension(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'gif';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      return 'webp';
    }
    // 默认作为 JPEG（iOS image_cropper / image_picker 转换后通常是 JPEG）
    return 'jpg';
  }

  /// 根据扩展名获取 MIME content type
  static MediaType _contentTypeForExt(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  /// 上传单张图片（XFile），返回 URL — 兼容 Web 和原生平台
  Future<String?> uploadXFile(XFile xFile) async {
    // 优先用 XFile.readAsBytes；iOS 裁剪后临时文件可能读取失败，降级用 dart:io File
    late final List<int> bytes;
    try {
      bytes = await xFile.readAsBytes();
    } catch (e) {
      debugPrint('[UploadService] XFile.readAsBytes failed, fallback to File: $e');
      if (kIsWeb) rethrow;
      bytes = await File(xFile.path).readAsBytes();
    }
    final fileName = _normalizeImageFileName(xFile.name, bytes);
    final contentType = _contentTypeForExt(fileName);

    debugPrint('[UploadService] uploading: $fileName (${bytes.length} bytes, '
        'original: ${xFile.name}, path: ${xFile.path}, contentType: $contentType)');

    // 统一用 bytes 上传，确保 fileName 和 contentType 正确
    // 避免 image_cropper 临时文件路径/扩展名不规范或 iOS 沙箱权限问题
    final res = await _http.uploadBytes(
      ApiConfig.uploadImage,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    debugPrint('[UploadService] response: $res');

    if (res['code'] == 0 && res['data'] != null) {
      final url = res['data']['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    // 抛出异常并携带服务端错误信息，方便 UI 层展示给用户
    throw Exception(res['msg'] ?? 'Upload failed (code: ${res['code']})');
  }

  /// 上传多张图片（XFile 列表），返回 URL 列表
  Future<List<String>> uploadXFiles(List<XFile> xFiles) async {
    final urls = <String>[];

    for (final xFile in xFiles) {
      try {
        final url = await uploadXFile(xFile);
        if (url != null) {
          urls.add(url);
        }
      } catch (e) {
        debugPrint('[UploadService] uploadXFiles: skip failed file: $e');
      }
    }

    return urls;
  }
}
