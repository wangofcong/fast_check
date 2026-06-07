library location_provider;

/// 定位状态管理
///
/// 管理定位服务与地理围栏的状态，为 UI 层提供统一的定位相关数据。
/// 整合 [LocationService] 与 [GeofenceService]，通过 Provider 模式
/// 供整个应用消费。

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/location_service.dart';
import '../services/geofence_service.dart';
import '../services/database_service.dart';

/// 定位状态枚举
enum LocationState {
  /// 初始化中
  initializing,

  /// 定位可用
  available,

  /// 定位不可用（权限/服务问题）
  unavailable,

  /// 定位出错
  error,
}

/// 定位 Provider
///
/// 向 UI 提供：
/// - 当前位置信息
/// - 地理围栏状态（是否在公司范围内）
/// - 与各公司地点的实时距离
/// - 围栏事件通知
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  final GeofenceService _geofenceService;
  final DatabaseService _db = DatabaseService();

  // ===== 公开状态 =====

  LocationState _state = LocationState.initializing;
  LocationState get state => _state;

  /// 当前用户位置
  LocationResult? get currentLocation =>
      _geofenceService.currentLocation ?? _locationService.lastKnownLocation;

  /// 与所有地点的实时距离
  List<LocationDistanceStatus> get distances => _geofenceService.distances;

  /// 最近的围栏状态
  LocationDistanceStatus? get nearestStatus =>
      _geofenceService.nearestStatus;

  /// 是否在公司围栏范围内
  bool get isInsideGeofence => _geofenceService.isInsideAnyGeofence;

  /// 是否正在监测
  bool get isMonitoring => _geofenceService.isMonitoring;

  /// 定位服务是否可用
  bool get isLocationServiceEnabled =>
      _locationService.isLocationServiceEnabled;

  /// 定位权限状态
  LocationPermissionStatus get permissionStatus =>
      _locationService.permissionStatus;

  /// 围栏事件流
  Stream<GeofenceEvent> get eventStream => _geofenceService.eventStream;

  // ===== 错误/状态信息 =====

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  GeofenceEvent? _lastEvent;
  GeofenceEvent? get lastEvent => _lastEvent;

  // ===== 内部控制 =====

  StreamSubscription<GeofenceEvent>? _eventSub;

  // ===== 构造函数 =====

  LocationProvider({
    LocationService? locationService,
    GeofenceService? geofenceService,
  })  : _locationService =
            locationService ?? MockLocationService(),
        _geofenceService = geofenceService ??
            GeofenceService(
              locationService:
                  locationService ?? MockLocationService(),
            );

  // ===== 生命周期 =====

  @override
  void dispose() {
    _eventSub?.cancel();
    _geofenceService.dispose();
    _locationService.dispose();
    super.dispose();
  }

  // ===== 初始化 =====

  /// 初始化定位服务并开始监测
  Future<void> initialize() async {
    _state = LocationState.initializing;
    notifyListeners();

    try {
      // 1. 初始化定位服务
      await _locationService.initialize();

      // 2. 检查权限
      if (_locationService.permissionStatus != LocationPermissionStatus.granted) {
        final permission = await _locationService.requestPermission();
        if (permission != LocationPermissionStatus.granted) {
          _state = LocationState.unavailable;
          _lastErrorMessage = '定位权限被拒绝，无法获取位置信息';
          notifyListeners();
          return;
        }
      }

      // 3. 检查定位服务是否可用
      if (!_locationService.isLocationServiceEnabled) {
        _state = LocationState.unavailable;
        _lastErrorMessage = '定位服务未开启，请在系统设置中打开';
        notifyListeners();
        return;
      }

      // 4. 加载公司地点并开始监测
      final locations = await _db.getAllCompanyLocations();
      if (locations.isNotEmpty) {
        await _geofenceService.startMonitoring(locations);

        // 订阅围栏事件
        _eventSub?.cancel();
        _eventSub = _geofenceService.eventStream.listen(_onGeofenceEvent);
      }

      _state = LocationState.available;
      notifyListeners();
    } catch (e) {
      _state = LocationState.error;
      _lastErrorMessage = '定位初始化失败: $e';
      debugPrint('[LocationProvider] 初始化错误: $e');
      notifyListeners();
    }
  }

  // ===== 围栏事件处理 =====

  void _onGeofenceEvent(GeofenceEvent event) {
    _lastEvent = event;
    debugPrint('[LocationProvider] 围栏事件: ${event.type.name} - ${event.location.name}');
    notifyListeners();
  }

  // ===== 用户操作 =====

  /// 请求定位权限
  Future<LocationPermissionStatus> requestPermission() async {
    final result = await _locationService.requestPermission();
    notifyListeners();
    return result;
  }

  /// 打开定位设置
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// 重新加载地点并重启监测
  Future<void> reloadLocations() async {
    final locations = await _db.getAllCompanyLocations();
    await _geofenceService.updateMonitoredLocations(locations);
    notifyListeners();
  }

  /// 手动获取一次当前位置
  Future<LocationResult?> refreshLocation() async {
    final loc = await _locationService.getCurrentLocation();
    if (loc != null && _geofenceService.isMonitoring) {
      // 触发围栏重新评估
    }
    notifyListeners();
    return loc;
  }

  /// 开始监测
  Future<void> startMonitoring() async {
    final locations = await _db.getAllCompanyLocations();
    if (locations.isNotEmpty) {
      await _geofenceService.startMonitoring(locations);
      notifyListeners();
    }
  }

  /// 停止监测
  Future<void> stopMonitoring() async {
    await _geofenceService.stopMonitoring();
    notifyListeners();
  }

  // ===== 便捷查询 =====

  /// 获取到默认地点的距离
  double? get distanceToDefault =>
      _geofenceService.getDistanceToDefaultLocation();

  /// 获取格式化后的到默认地点的距离文本
  String get formattedDistanceToDefault {
    final dist = distanceToDefault;
    if (dist == null) return '未知';
    if (dist >= 1000) {
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
    return '${dist.toStringAsFixed(0)} m';
  }

  /// 获取状态描述文本
  String get statusText {
    switch (_state) {
      case LocationState.initializing:
        return '定位初始化中...';
      case LocationState.available:
        if (isInsideGeofence) {
          return '📍 在公司范围内';
        } else {
          final dist = distanceToDefault;
          if (dist != null) {
            return '🚶 距公司 ${formattedDistanceToDefault}';
          }
          return '📍 定位可用';
        }
      case LocationState.unavailable:
        return '⚠️ 定位不可用';
      case LocationState.error:
        return '❌ 定位出错: ${_lastErrorMessage ?? "未知错误"}';
    }
  }

  /// 获取状态颜色（用于 UI 指示）
  String get statusColorHex {
    switch (_state) {
      case LocationState.initializing:
        return 'FF9C27B0'; // 紫色
      case LocationState.available:
        return isInsideGeofence ? 'FF4CAF50' : 'FFFF9800'; // 绿/橙
      case LocationState.unavailable:
        return 'FF9E9E9E'; // 灰色
      case LocationState.error:
        return 'FFF44336'; // 红色
    }
  }
}
