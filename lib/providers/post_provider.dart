import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../utils/storage.dart';

class PostProvider extends ChangeNotifier {
  final PostService _postService = PostService();

  // 列表状态
  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  // 筛选条件
  // filterCategory: null=全部, 2=亲人, 1=宠物, 4=物品
  int? _filterCategory;
  String? _filterCity;
  String? _filterKeyword;
  int? _filterDays;

  /// 从本地缓存加载文章列表（用于 app 启动时瞬间显示）
  Future<void> loadFromCache() async {
    if (_posts.isNotEmpty) return;
    try {
      final cached = await StorageUtil.getPostsCache();
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cached);
        _posts = list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('[PostProvider] loadFromCache error: $e');
      debugPrint('[PostProvider] $stackTrace');
    }
  }

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int? get filterCategory => _filterCategory;

  /// 设置分类筛选
  /// null=全部, 2=亲人, 1=宠物, 4=物品
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
        debugPrint('[PostProvider] loaded ${_posts.length} posts: ${_posts.map((p) => "id=${p.id} reward=${p.rewardAmount}").join(", ")}');
        // 仅缓存无筛选条件的首页数据
        if (_filterCategory == null && _filterCity == null &&
            _filterKeyword == null && _filterDays == null) {
          _saveCacheAsync();
        }
      } else {
        _posts.addAll(pageData.list);
      }

      _hasMore = pageData.hasMore;
    } catch (e, stackTrace) {
      debugPrint('[PostProvider] _loadPosts error: $e');
      debugPrint('[PostProvider] $stackTrace');
      if (!isRefresh) _currentPage--;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _saveCacheAsync() {
    try {
      final jsonStr = jsonEncode(_posts.map((p) => p.toJson()).toList());
      StorageUtil.savePostsCache(jsonStr);
    } catch (e) {
      // 忽略缓存保存错误
    }
  }
}
