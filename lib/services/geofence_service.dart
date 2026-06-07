library geofence_service;

/// 地理围栏服务
///
/// 基于定位流实时监测用户与公司地点的距离，
/// 检测进出围栏事件，并支持多地点、多半径监控。
///
/// 核心能力：
/// - 监测用户进入/离开公司地理围栏
/// - 实时计算与所有配置地点的距离
/// - 自适应定位间隔（省电策略）
/// - 事件回调（进入/离开/距离更新）

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'location_service.dart';
import '../models/company_location.dart';
import '../utils/distance_calculator.dart';

// =============================================================================
// 数据模型
// =============================================================================

/// 围栏事件类型
enum GeofenceEventType {
  /// 进入围栏（从外部进入围栏范围）
  enter,

  /// 离开围栏（从内部离开围栏范围）
  exit,

  /// 停留在围栏内部（周期性报告）
  dwellInside,

  /// 停留在围栏外部（周期性报告）
  dwellOutside,
}

/// 围栏事件
class GeofenceEvent {
  /// 事件类型
  final GeofenceEventType type;

  /// 关联的公司地点
  final CompanyLocation location;

  /// 当前距离（米）
  final double distanceMeters;

  /// 事件发生时间
  final DateTime timestamp;

  /// 用户当前位置
  final LocationResult userLocation;

  const GeofenceEvent({
    required this.type,
    required this.location,
    required this.distanceMeters,
    required this.timestamp,
    required this.userLocation,
  });

  /// 是否为进入事件
  bool get isEnter => type == GeofenceEventType.enter;

  /// 是否为离开事件
  bool get isExit => type == GeofenceEventType.exit;

  /// 是否在围栏内
  bool get isInside =>
      type == GeofenceEventType.enter ||
      type == GeofenceEventType.dwellInside;

  /// 格式化距离
  String get formattedDistance => DistanceCalculator.formatDistance(distanceMeters);

  @override
  String toString() =>
      'GeofenceEvent(${type.name}, ${location.name}, '
      'dist: ${formattedDistance})';
}

/// 地点距离状态（当前时刻与某个地点的关系）
class LocationDistanceStatus {
  /// 公司地点
  final CompanyLocation location;

  /// 用户到该地点的距离（米）
  final double distanceMeters;

  /// 是否在围栏范围内
  final bool isInside;

  /// 距离/围栏半径比值（<1 表示在内部）
  final double ratio;

  /// 定位时间
  final DateTime timestamp;

  const LocationDistanceStatus({
    required this.location,
    required this.distanceMeters,
    required this.isInside,
    required this.ratio,
    required this.timestamp,
  });

  /// 格式化距离
  String get formattedDistance => DistanceCalculator.formatDistance(distanceMeters);

  @override
  String toString() =>
      '${location.name}: ${formattedDistance} (${isInside ? "内部" : "外部"}, '
      'ratio: ${ratio.toStringAsFixed(2)})';
}

// =============================================================================
// 围栏服务
// =============================================================================

/// 地理围栏服务
///
/// 持续监控用户位置与公司地点集合的距离关系，
/// 通过流产生 [GeofenceEvent] 供外部消费。
class GeofenceService extends ChangeNotifier {
  // ===== 依赖 =====

  final LocationService _locationService;

  // ===== 配置 =====

  /// 连续监测时两次定位的最小间隔（毫秒）
  final int minIntervalMs;

  /// 距离更新阈值（米），超过此值才触发位置更新
  final double distanceFilterMeters;

  /// 默认围栏检查间隔（秒），当距离较远时使用
  final int defaultCheckIntervalSeconds;

  // ===== 内部状态 =====

  StreamSubscription<LocationResult>? _locationSub;
  Timer? _adaptiveTimer;
  bool _isMonitoring = false;
  LocationResult? _currentLocation;

  /// 当前监控的公司地点列表
  List<CompanyLocation> _monitoredLocations = [];

  /// 上次围栏状态（地点ID -> 是否在围栏内），用于检测进出
  final Map<int, bool> _previousInsideState = {};

  // ===== 公开状态 =====

  /// 当前实时距离状态（按地点索引）
  List<LocationDistanceStatus> _distances = [];
  List<LocationDistanceStatus> get distances => List.unmodifiable(_distances);

  /// 当前最近的围栏状态
  LocationDistanceStatus? get nearestStatus {
    if (_distances.isEmpty) return null;
    return _distances.reduce(
      (a, b) => a.distanceMeters < b.distanceMeters ? a : b,
    );
  }

  /// 是否在任何地点的围栏范围内
  bool get isInsideAnyGeofence =>
      _distances.any((d) => d.isInside);

  /// 当前是否在监控中
  bool get isMonitoring => _isMonitoring;

  /// 当前定位
  LocationResult? get currentLocation => _currentLocation;

  // ===== 事件流 =====

  final StreamController<GeofenceEvent> _eventController =
      StreamController<GeofenceEvent>.broadcast();

  /// 围栏事件流（进入/离开）
  Stream<GeofenceEvent> get eventStream => _eventController.stream;

  // ===== 构造函数 =====

  GeofenceService({
    required LocationService locationService,
    this.minIntervalMs = 5000,
    this.distanceFilterMeters = 10,
    this.defaultCheckIntervalSeconds = 60,
  }) : _locationService = locationService;

  // ===== 生命周期 =====

  @override
  void dispose() {
    stopMonitoring();
    _eventController.close();
    super.dispose();
  }

  // ===== 监控控制 =====

  /// 开始监测指定地点列表
  ///
  /// [locations] 要监测的公司地点列表（通常传全部已配置地点）
  Future<void> startMonitoring(List<CompanyLocation> locations) async {
    if (_isMonitoring) await stopMonitoring();

    _monitoredLocations = List.from(locations);
    _previousInsideState.clear();
    for (final loc in locations) {
      _previousInsideState[loc.id ?? -1] = false;
    }

    _isMonitoring = true;

    // 获取初始位置
    final initial = await _locationService.getCurrentLocation();
    if (initial != null) {
      _currentLocation = initial;
      _evaluateAllLocations(initial, isInitial: true);
    }

    // 订阅定位流
    _locationSub = _locationService
        .getLocationStream(distanceFilterMeters: distanceFilterMeters)
        .listen(_onLocationUpdate, onError: _onLocationError);

    // 启动自适应定时器作为后备（防止流更新不及时）
    _startAdaptiveTimer();

    notifyListeners();
  }

  /// 停止监测
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _locationSub?.cancel();
    _locationSub = null;
    _adaptiveTimer?.cancel();
    _adaptiveTimer = null;
    notifyListeners();
  }

  /// 更新监测地点列表（如用户在设置页面增删地点后调用）
  Future<void> updateMonitoredLocations(List<CompanyLocation> locations) async {
    final wasMonitoring = _isMonitoring;
    if (wasMonitoring) {
      await stopMonitoring();
    }
    if (wasMonitoring) {
      await startMonitoring(locations);
    } else {
      _monitoredLocations = List.from(locations);
    }
  }

  // ===== 核心逻辑 =====

  /// 处理定位更新
  void _onLocationUpdate(LocationResult location) {
    _currentLocation = location;
    _evaluateAllLocations(location);
    _resetAdaptiveTimer(location);
    notifyListeners();
  }

  /// 处理定位错误
  void _onLocationError(Object error) {
    debugPrint('[GeofenceService] 定位错误: $error');
  }

  /// 评估所有地点
  void _evaluateAllLocations(
    LocationResult location, {
    bool isInitial = false,
  }) {
    final newDistances = <LocationDistanceStatus>[];
    final now = DateTime.now();

    for (final loc in _monitoredLocations) {
      final companyPoint = GeoPoint(loc.latitude, loc.longitude);
      final userPoint = GeoPoint(location.latitude, location.longitude);
      final result = DistanceCalculator.calculate(userPoint, companyPoint);

      final distanceMeters = result.meters;
      final isInside = distanceMeters <= loc.geofenceRadius;
      final ratio = distanceMeters / loc.geofenceRadius;

      newDistances.add(LocationDistanceStatus(
        location: loc,
        distanceMeters: distanceMeters,
        isInside: isInside,
        ratio: ratio,
        timestamp: now,
      ));

      // 检测进出事件（初始状态不触发）
      if (!isInitial) {
        _detectTransition(loc, distanceMeters, isInside, location);
      }

      // 更新上次状态
      _previousInsideState[loc.id ?? -1] = isInside;
    }

    _distances = newDistances;
  }

  /// 检测围栏进出事件
  void _detectTransition(
    CompanyLocation loc,
    double distanceMeters,
    bool isInside,
    LocationResult userLocation,
  ) {
    final locId = loc.id ?? -1;
    final wasInside = _previousInsideState[locId] ?? false;

    if (isInside && !wasInside) {
      // 进入围栏
      _eventController.add(GeofenceEvent(
        type: GeofenceEventType.enter,
        location: loc,
        distanceMeters: distanceMeters,
        timestamp: DateTime.now(),
        userLocation: userLocation,
      ));
    } else if (!isInside && wasInside) {
      // 离开围栏
      _eventController.add(GeofenceEvent(
        type: GeofenceEventType.exit,
        location: loc,
        distanceMeters: distanceMeters,
        timestamp: DateTime.now(),
        userLocation: userLocation,
      ));
    }
    // 内部/外部停留事件通过定时 dwell 检查触发
  }

  // ===== 自适应定时器 =====

  /// 启动自适应定时器（后备监测）
  void _startAdaptiveTimer() {
    _adaptiveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _adaptiveCheck(),
    );
  }

  /// 自适应检查：根据当前最近距离调整下次检查间隔
  void _adaptiveCheck() async {
    if (!_isMonitoring) return;

    final loc = await _locationService.getCurrentLocation();
    if (loc != null) {
      _currentLocation = loc;
      _evaluateAllLocations(loc);
      notifyListeners();
    }
  }

  /// 重置自适应定时器（根据距离调整频率）
  void _resetAdaptiveTimer(LocationResult location) {
    // 找一个最近的围栏半径来计算自适应间隔
    if (_monitoredLocations.isEmpty) return;

    double minDistance = double.infinity;
    for (final loc in _monitoredLocations) {
      final companyPoint = GeoPoint(loc.latitude, loc.longitude);
      final userPoint = GeoPoint(location.latitude, location.longitude);
      final result = DistanceCalculator.calculate(userPoint, companyPoint);
      minDistance = min(minDistance, result.meters);
    }

    final intervalMinutes = max(
      1,
      AdaptiveIntervalCalculator.calculate(minDistance, 200),
    );

    // 只在间隔变化较大时才重置（避免频繁创建/销毁 Timer）
    _adaptiveTimer?.cancel();
    _adaptiveTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _adaptiveCheck(),
    );
  }

  // ===== 便捷查询 =====

  /// 获取到指定地点的距离
  double? getDistanceToLocation(int locationId) {
    final status = _distances.where((d) => d.location.id == locationId);
    return status.isNotEmpty ? status.first.distanceMeters : null;
  }

  /// 获取到默认地点的距离
  double? getDistanceToDefaultLocation() {
    final defaults = _distances.where((d) => d.location.isDefault == 1);
    return defaults.isNotEmpty ? defaults.first.distanceMeters : null;
  }

  /// 检查是否在指定地点的围栏内
  bool? isInsideLocation(int locationId) {
    final status = _distances.where((d) => d.location.id == locationId);
    return status.isNotEmpty ? status.first.isInside : null;
  }
}
