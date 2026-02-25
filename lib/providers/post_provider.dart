import 'package:flutter/material.dart';
import '../models/api_response.dart';
import '../models/post.dart';
import '../services/post_service.dart';

class PostProvider extends ChangeNotifier {
  final PostService _postService = PostService();

  // 列表状态
  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  // 筛选条件
  // filterCategory: null=全部, 2=成年人, 3=儿童, -1=其它(宠物+其它物品)
  int? _filterCategory;
  String? _filterCity;
  String? _filterKeyword;
  int? _filterDays;

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int? get filterCategory => _filterCategory;

  /// 设置分类筛选
  /// null=全部, 2=成年人, 3=儿童, -1=其它(宠物+其它物品)
  void setCategory(int? category) {
    _filterCategory = category;
    refresh();
  }

  /// 设置城市筛选
  void setCity(String? city) {
    _filterCity = city;
    refresh();
  }

  /// 设置搜索关键词
  void setKeyword(String? keyword) {
    _filterKeyword = keyword;
    refresh();
  }

  /// 设置时间范围
  void setDays(int? days) {
    _filterDays = days;
    refresh();
  }

  /// 刷新（从第一页开始）
  Future<void> refresh() async {
    _currentPage = 1;
    _hasMore = true;
    await _loadPosts(isRefresh: true);
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    await _loadPosts(isRefresh: false);
  }

  /// 将 filterCategory 转换为 API 参数
  /// -1 → "1,4" (宠物+其它物品)
  /// 其他 → 直接传数字
  String? _getCategoryParam() {
    if (_filterCategory == null) return null;
    if (_filterCategory == -1) return '1,4'; // 其它分组
    return _filterCategory.toString();
  }

  /// 内部加载方法
  Future<void> _loadPosts({bool isRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final pageData = await _postService.getList(
        page: _currentPage,
        category: _getCategoryParam(),
        city: _filterCity,
        keyword: _filterKeyword,
        days: _filterDays,
      );

      if (isRefresh) {
        _posts = pageData.list;
      } else {
        _posts.addAll(pageData.list);
      }

      _hasMore = pageData.hasMore;
    } catch (e) {
      // 加载失败回退页码
      if (!isRefresh) _currentPage--;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
