import 'package:image_picker/image_picker.dart';
import '../config/api.dart';
import 'http_client.dart';

class UploadService {
  final _http = HttpClient();

  /// 上传单张图片（XFile），返回 URL — 兼容 Web 和原生平台
  Future<String?> uploadXFile(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    final fileName = xFile.name;

    final res = await _http.uploadBytes(
      ApiConfig.uploadImage,
      bytes: bytes,
      fileName: fileName,
    );

    if (res['code'] == 0 && res['data'] != null) {
      return res['data']['url'] as String?;
    }
    return null;
  }

  /// 上传多张图片（XFile 列表），返回 URL 列表
  Future<List<String>> uploadXFiles(List<XFile> xFiles) async {
    final urls = <String>[];

    for (final xFile in xFiles) {
      final url = await uploadXFile(xFile);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }
}
