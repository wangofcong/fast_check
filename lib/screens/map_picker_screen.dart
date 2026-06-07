import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';
import '../services/geocoding_service.dart';

/// 地图选点页面
///
/// 功能：
/// 1. 在地图上点击选择经纬度
/// 2. 搜索地址自动定位
/// 3. 拖动标记微调位置
/// 4. 显示选中位置的地址信息
///
/// 返回：选中的经纬度 (latitude, longitude)，或 null（取消）
class MapPickerScreen extends StatefulWidget {
  /// 初始经纬度（编辑已有地点时传入）
  final double? initialLatitude;
  final double? initialLongitude;

  /// 初始地址
  final String? initialAddress;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late MapController _mapController;
  late LatLng _selectedLatLng;
  String _selectedAddress = '';
  bool _isSearching = false;

  // 搜索结果
  final List<GeocodingResult> _searchResults = [];

  // 搜索文本控制器
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // 初始化位置：优先使用传入的坐标，否则用北京天安门作为默认中心
    final initLat = widget.initialLatitude ?? 39.9042;
    final initLng = widget.initialLongitude ?? 116.4074;
    _selectedLatLng = LatLng(initLat, initLng);

    // 反向地理编码获取地址
    _reverseGeocode();

    // 如果有初始地址，设置搜索框
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _searchController.text = widget.initialAddress!;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 反向地理编码：根据坐标获取地址
  Future<void> _reverseGeocode() async {
    final result = await GeocodingService.reverseGeocode(
      _selectedLatLng.latitude,
      _selectedLatLng.longitude,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result.displayName;
      });
    }
  }

  /// 搜索地址
  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      final results = await GeocodingService.searchAddress(query);
      if (mounted) {
        setState(() {
          _searchResults.addAll(results);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.tr('搜索失败: $e', 'Search failed: $e'))),
        );
      }
    }
  }

  /// 选择搜索结果，跳转到该位置
  void _selectSearchResult(GeocodingResult result) {
    setState(() {
      _selectedLatLng = LatLng(result.latitude, result.longitude);
      _selectedAddress = result.displayName;
      _searchResults.clear();
      _searchController.text = '';
    });

    _mapController.move(_selectedLatLng, 16.0);
    _searchFocusNode.unfocus();
  }

  /// 地图点击事件
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
      _selectedAddress = '';
    });
    _mapController.move(latLng, _mapController.camera.zoom);
    _reverseGeocode();
  }

  /// 确认选择
  void _confirmSelection() {
    Navigator.of(context).pop({
      'latitude': _selectedLatLng.latitude,
      'longitude': _selectedLatLng.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.tr('选择地点', 'Pick Location')),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 确认按钮
          TextButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check),
            label: Text(L10n.confirm),
          ),
        ],
      ),
      body: Column(
        children: [
          // ========== 搜索栏 ==========
          _buildSearchBar(),

          // ========== 搜索结果列表 ==========
          if (_searchResults.isNotEmpty) _buildSearchResults(),

          // ========== 地图区域 ==========
          Expanded(
            child: Stack(
              children: [
                // 地图
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLatLng,
                    initialZoom: widget.initialLatitude != null ? 16.0 : 12.0,
                    onTap: _onMapTap,
                    minZoom: 3,
                    maxZoom: 19,
                  ),
                  children: [
                    // 瓦片图层（OpenStreetMap）
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.fast_check',
                    ),

                    // 标记图层
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 加载中（搜索时显示）
                if (_isSearching)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),

          // ========== 底部信息栏 ==========
          _buildBottomInfo(),
        ],
      ),
    );
  }

  /// 搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: L10n.tr('搜索地点名称或地址...', 'Search place name or address...'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        onSubmitted: (value) => _searchAddress(value),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  /// 搜索结果列表
  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.red),
                    title: Text(
                      result.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    dense: true,
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),
          // 收起按钮
          TextButton(
            onPressed: () => setState(() => _searchResults.clear()),
            child: Text(L10n.close),
          ),
        ],
      ),
    );
  }

  /// 底部信息栏
  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 坐标信息
                  Text(
                    '${_selectedLatLng.latitude.toStringAsFixed(6)}, '
                    '${_selectedLatLng.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  // 地址信息
                  if (_selectedAddress.isNotEmpty)
                    Text(
                      _selectedAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    )
                  else
                    Text(
                      L10n.tr('点击地图选择位置...', 'Tap on the map to pick a location...'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 确认按钮（小屏幕备用）
            FilledButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check, size: 18),
              label: Text(L10n.confirm),
            ),
          ],
        ),
      ),
    );
  }
}
