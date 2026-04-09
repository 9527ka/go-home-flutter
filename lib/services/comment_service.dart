import '../config/api.dart';
import '../models/api_response.dart';
import '../models/comment.dart';
import 'http_client.dart';

class CommentService {
  final _http = HttpClient();

  /// 发表评论
  Future<Map<String, dynamic>> create({
    required int postId,
    required String content,
    int? parentId,
    int? replyToUserId,
  }) async {
    final data = <String, dynamic>{
      'post_id': postId,
      'content': content,
    };
    if (parentId != null) data['parent_id'] = parentId;
    if (replyToUserId != null) data['reply_to_user_id'] = replyToUserId;

    return await _http.post(ApiConfig.commentCreate, data: data);
  }

  /// 评论列表
  Future<PageData<CommentModel>> getList({
    required int postId,
    String sort = 'hot',
    int page = 1,
  }) async {
    final res = await _http.get(ApiConfig.commentList, params: {
      'post_id': postId,
      'sort': sort,
      'page': page,
    });

    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => CommentModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 回复列表
  Future<PageData<CommentModel>> getReplies({
    required int commentId,
    int page = 1,
  }) async {
    final res = await _http.get(ApiConfig.commentReplies, params: {
      'comment_id': commentId,
      'page': page,
    });

    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => CommentModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 删除评论
  Future<Map<String, dynamic>> delete(int commentId) async {
    return await _http.post(ApiConfig.commentDelete, data: {
      'comment_id': commentId,
    });
  }
}
