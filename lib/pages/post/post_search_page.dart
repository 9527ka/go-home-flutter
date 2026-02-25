import 'package:flutter/material.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';

class PostSearchPage extends StatefulWidget {
  const PostSearchPage({super.key});

  @override
  State<PostSearchPage> createState() => _PostSearchPageState();
}

class _PostSearchPageState extends State<PostSearchPage> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _postService = PostService();
  List<PostModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // 自动弹出键盘
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;

    _focusNode.unfocus();
    setState(() { _isLoading = true; _hasSearched = true; });

    try {
      final data = await _postService.getList(keyword: keyword);
      setState(() => _results = data.list);
    } catch (e) {
      // 搜索失败
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // 返回按钮
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(width: 10),

                // 搜索框
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '搜索名字、特征、地点...',
                        hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textHint),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() { _results.clear(); _hasSearched = false; });
                                },
                                child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textHint),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _search(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 搜索按钮
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '搜索',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _hasSearched && _results.isEmpty
              ? _buildEmptyResult()
              : !_hasSearched
                  ? _buildSearchHint()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: _results.length,
                      itemBuilder: (_, index) {
                        return PostCard(
                          post: _results[index],
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.postDetail, arguments: _results[index].id);
                          },
                        );
                      },
                    ),
    );
  }

  Widget _buildSearchHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 56, color: AppTheme.textHint.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('输入关键词搜索', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('支持搜索姓名、特征、城市等', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _buildEmptyResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.search_off_rounded, size: 36, color: AppTheme.textHint.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          const Text('未找到相关结果', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('试试换个关键词', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}
