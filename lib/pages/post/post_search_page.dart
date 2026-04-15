import 'package:flutter/material.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
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
                        hintText: AppLocalizations.of(context)!.get('search_input_hint'),
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
                    child: Text(
                      AppLocalizations.of(context)!.get('search'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
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
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.search_rounded, size: 32, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(l.get('search'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l.get('search_hint'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResult() {
    final l = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
        child: Column(
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
          Text(l.get('no_results_found'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(l.get('try_other_keywords'), style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.postCreate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                child: Text(l.get('publish_post'), style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
