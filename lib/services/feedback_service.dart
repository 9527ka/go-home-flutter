import '../config/api.dart';
import 'http_client.dart';

class FeedbackService {
  final _http = HttpClient();

  /// 提交反馈
  Future<Map<String, dynamic>> submitFeedback({
    required String content,
    String? contact,
  }) async {
    final data = <String, dynamic>{
      'content': content,
    };
    if (contact != null && contact.isNotEmpty) {
      data['contact'] = contact;
    }
    return await _http.post(ApiConfig.feedbackCreate, data: data);
  }
}
