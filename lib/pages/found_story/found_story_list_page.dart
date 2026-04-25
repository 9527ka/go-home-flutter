import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/api_response.dart';
import '../../models/found_story.dart';
import '../../services/found_story_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/vip_decoration.dart';

/// 找回故事公开列表页（信任驱动：成功案例展示）
class FoundStoryListPage extends StatefulWidget {
  const FoundStoryListPage({super.key});

  @override
  State<FoundStoryListPage> createState() => _FoundStoryListPageState();
}

class _FoundStoryListPageState extends State<FoundStoryListPage> {
  final _service = FoundStoryService();
  final _scroll = ScrollController();
  final List<FoundStoryModel> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200
        && !_loading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    await _fetch();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    _page++;
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final PageData<FoundStoryModel> data = await _service.publicList(page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(data.list);
        _hasMore = data.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('找回故事'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _FoundStoryCard(story: _items[i]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_outlined, size: 56, color: AppTheme.textHint),
          const SizedBox(height: 8),
          const Text('暂无找回故事', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: _reload, child: const Text('刷新')),
        ],
      ),
    );
  }
}

class _FoundStoryCard extends StatelessWidget {
  final FoundStoryModel story;

  const _FoundStoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VipAvatarFrame(
                vip: story.userVip,
                child: AvatarWidget(
                  avatarPath: story.userAvatar,
                  name: story.userNickname,
                  size: 36,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: VipNickname(
                            vip: story.userVip,
                            text: story.userNickname,
                            baseStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        VipLevelBadge(vip: story.userVip, fontSize: 9),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '找回「${story.postName}」',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '已找回',
                  style: TextStyle(
                    fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            story.content,
            style: const TextStyle(
              fontSize: 14, height: 1.5, color: AppTheme.textPrimary,
            ),
          ),
          if (story.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: story.images.length.clamp(0, 3),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: UrlHelper.ensureAbsolute(story.images[i]),
                    width: 80, height: 80, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 80, height: 80,
                      color: AppTheme.dividerColor,
                      child: const Icon(Icons.broken_image_outlined, color: AppTheme.textHint),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textHint),
              const SizedBox(width: 3),
              Text(
                story.postLostCity.isNotEmpty ? story.postLostCity : '-',
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
              const Spacer(),
              Text(
                story.createdAt.length >= 10 ? story.createdAt.substring(0, 10) : story.createdAt,
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
