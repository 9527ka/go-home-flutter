import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/theme.dart';
import '../../models/api_response.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';
import '../post/post_detail_page.dart';

/// 附近启事页
class NearbyPostsPage extends StatefulWidget {
  const NearbyPostsPage({super.key});

  @override
  State<NearbyPostsPage> createState() => _NearbyPostsPageState();
}

class _NearbyPostsPageState extends State<NearbyPostsPage> {
  static const _radiusOptions = [10.0, 50.0, 100.0, 200.0];

  final _service = PostService();
  final _scroll = ScrollController();

  double _radius = 50;
  double? _lat;
  double? _lng;
  String? _locationError;
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  final List<PostModel> _items = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _initLocation();
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

  Future<void> _initLocation() async {
    setState(() {
      _loading = true;
      _locationError = null;
    });
    try {
      // 权限请求
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // 未授权：依赖服务端 last_*_location 兜底
        _lat = null;
        _lng = null;
        _locationError = permission == LocationPermission.deniedForever
            ? '定位权限被永久拒绝，请在 系统设置 → 隐私 → 定位服务 中允许'
            : '未授权定位，附近启事需要位置权限';
      } else {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        _lat = pos.latitude;
        _lng = pos.longitude;
        // 上报给服务端
        _service.updateLocation(pos.latitude, pos.longitude);
      }
    } catch (e) {
      _locationError = '定位失败：$e';
    }
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    await _fetchPage();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);
    _page++;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      final PageData<PostModel> data = await _service.getNearby(
        lat: _lat,
        lng: _lng,
        radiusKm: _radius,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(data.list);
        _hasMore = data.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
        _locationError = _locationError ?? '加载失败：$e';
      });
    }
  }

  void _onRadiusChanged(double r) {
    if (r == _radius) return;
    setState(() => _radius = r);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近启事'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initLocation,
            tooltip: '刷新定位',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRadiusSelector(),
          if (_locationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppTheme.warningColor.withOpacity(0.1),
              child: Text(_locationError!,
                  style: const TextStyle(color: AppTheme.warningColor, fontSize: 13)),
            ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildRadiusSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.cardBg,
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          const Text('半径:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: _radiusOptions.map((r) {
                final selected = r == _radius;
                return ChoiceChip(
                  label: Text('${r.toInt()}km'),
                  selected: selected,
                  onSelected: (_) => _onRadiusChanged(r),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                  selectedColor: AppTheme.primaryColor,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 8),
            const Text('附近暂无启事', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _reload, child: const Text('刷新')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final post = _items[i];
          return PostCard(
            post: post,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailPage(postId: post.id)),
            ),
          );
        },
      ),
    );
  }
}
