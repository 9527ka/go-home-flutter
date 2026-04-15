import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/theme.dart';
import 'package:dio/dio.dart';

/// 地图选点返回结果
class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  AppleMapController? _mapController;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LatLng _selectedLocation = const LatLng(39.9042, 116.4074);
  String _address = '';
  bool _isLoadingLocation = true;
  bool _isLoadingAddress = false;
  String? _errorMsg;

  // 搜索相关
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _isLoadingLocation = false;
      _reverseGeocode(_selectedLocation);
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onMapCreated(AppleMapController controller) {
    _mapController = controller;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMsg = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMsg = '定位服务未开启，请在设置中开启';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMsg = '定位权限被拒绝';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMsg = '定位权限被永久拒绝，请在设置中开启';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = latLng;
        _isLoadingLocation = false;
      });

      _mapController?.moveCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));
      _reverseGeocode(latLng);
    } catch (e) {
      setState(() {
        _errorMsg = '获取定位失败，可手动点击地图选点';
        _isLoadingLocation = false;
      });
    }
  }

  // ============================================================
  //  搜索（Nominatim 正向地理编码）
  // ============================================================

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(query.trim());
    });
  }

  Future<void> _searchLocation(String query) async {
    setState(() => _isSearching = true);

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'accept-language': 'zh-CN',
          'limit': 8,
        },
        options: Options(
          headers: {'User-Agent': 'GoHomeApp/1.0'},
          receiveTimeout: const Duration(seconds: 5),
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = jsonDecode(response.data as String) as List;
        final results = list.map((item) => _SearchResult(
          displayName: item['display_name'] ?? '',
          lat: double.tryParse(item['lat']?.toString() ?? '') ?? 0,
          lon: double.tryParse(item['lon']?.toString() ?? '') ?? 0,
        )).where((r) => r.lat != 0 && r.lon != 0).toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
            _showResults = results.isNotEmpty;
          });
        }
      }
    } catch (_) {
      // 搜索失败不阻塞
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final latLng = LatLng(result.lat, result.lon);
    setState(() {
      _selectedLocation = latLng;
      _address = result.displayName;
      _showResults = false;
      _searchCtrl.clear();
    });
    _searchFocus.unfocus();
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));
  }

  // ============================================================
  //  反向地理编码
  // ============================================================

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() => _isLoadingAddress = true);

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': latLng.latitude,
          'lon': latLng.longitude,
          'format': 'json',
          'accept-language': 'zh-CN',
          'zoom': 18,
        },
        options: Options(
          headers: {'User-Agent': 'GoHomeApp/1.0'},
          receiveTimeout: const Duration(seconds: 5),
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = jsonDecode(response.data as String);
        final displayName = data['display_name'] ?? '';
        if (mounted) setState(() => _address = displayName);
      }
    } catch (_) {
      // 地理编码失败不阻塞
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() => _selectedLocation = latLng);
    _reverseGeocode(latLng);
  }

  void _confirm() {
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        address: _address,
      ),
    );
  }

  // ============================================================
  //  Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: '回到当前位置',
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          _buildSearchBar(),

          // 地图区域
          Expanded(
            child: Stack(
              children: [
                AppleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 16.0,
                  ),
                  onMapCreated: _onMapCreated,
                  onTap: _onMapTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  annotations: {
                    Annotation(
                      annotationId: AnnotationId('selected'),
                      position: _selectedLocation,
                      icon: BitmapDescriptor.markerAnnotationWithHue(BitmapDescriptor.hueRed),
                    ),
                  },
                ),

                // 搜索结果悬浮列表
                if (_showResults) _buildSearchResults(),

                // 加载中遮罩
                if (_isLoadingLocation)
                  Container(
                    color: Colors.white.withOpacity(0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('正在获取定位...'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 底部信息 + 确认
          _buildBottomPanel(),
        ],
      ),
    );
  }

  // ============================================================
  //  搜索框
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: '搜索地点',
          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textHint),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    _isSearching ? Icons.hourglass_top : Icons.close,
                    size: 18,
                    color: AppTheme.textHint,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchResults = [];
                      _showResults = false;
                    });
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) _searchLocation(v.trim());
        },
      ),
    );
  }

  // ============================================================
  //  搜索结果列表
  // ============================================================

  Widget _buildSearchResults() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
          itemBuilder: (context, index) {
            final r = _searchResults[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined, size: 20, color: AppTheme.primaryColor),
              title: Text(
                r.displayName,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _selectSearchResult(r),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  //  底部面板
  // ============================================================

  Widget _buildBottomPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 错误提示
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.dangerColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(fontSize: 12, color: AppTheme.dangerColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 坐标
          Row(
            children: [
              const Icon(Icons.pin_drop, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),

          // 地址
          if (_isLoadingAddress)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  SizedBox(width: 6),
                  Text('正在解析地址...', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            )
          else if (_address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),
          const Text(
            '点击地图或搜索地点可调整位置',
            style: TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),

          const SizedBox(height: 12),

          // 确认按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _confirm,
              child: const Text('确认位置', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索结果数据
class _SearchResult {
  final String displayName;
  final double lat;
  final double lon;

  const _SearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}
