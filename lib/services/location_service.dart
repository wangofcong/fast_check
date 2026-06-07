library location_service;

/// 定位服务
///
/// 提供统一的定位抽象接口与 Mock 实现。
/// - [LocationService] 抽象基类，定义定位服务接口
/// - [LocationResult] 定位结果数据模型
/// - [MockLocationService] 模拟定位实现（开发/测试/桌面环境使用）
///
/// 生产环境可替换为 [GpsLocationService]（需 geolocator 插件）：
/// ```dart
/// final service = LocationService.create(); // mock
/// // 真机替换为：
/// final service = GpsLocationService();
/// ```

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// =============================================================================
// 数据模型
// =============================================================================

/// 定位精度等级
enum LocationAccuracy {
  /// 低精度（省电，~500m）
  low,

  /// 中等精度（平衡，~100m）
  medium,

  /// 高精度（GPS，~10m）
  high,

  /// 最高精度（GPS+网络辅助，~3m）
  best,
}

/// 定位权限状态
enum LocationPermissionStatus {
  /// 已授权
  granted,

  /// 已拒绝
  denied,

  /// 永久拒绝
  deniedForever,

  /// 服务未开启（如 GPS 关闭）
  serviceDisabled,

  /// 尚未请求
  unknown,
}

/// 定位结果
class LocationResult {
  /// 纬度
  final double latitude;

  /// 经度
  final double longitude;

  /// 精度（米），null 表示未知
  final double? accuracy;

  /// 海拔（米），null 表示未知
  final double? altitude;

  /// 速度（米/秒），null 表示未知
  final double? speed;

  /// 获取时间戳（毫秒）
  final int timestamp;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// 从数据库/JSON Map 构造
  factory LocationResult.fromMap(Map<String, dynamic> map) {
    return LocationResult(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      timestamp: (map['timestamp'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'timestamp': timestamp,
    };
  }

  /// 两个位置之间的距离（使用 Haversine 公式，米）
  double distanceTo(LocationResult other) {
    const earthRadius = 6_371_000.0;
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);
    final dlat = _toRadians(other.latitude - latitude);
    final dlon = _toRadians(other.longitude - longitude);

    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 与另一个位置相比是否发生显著位移
  bool hasSignificantMove(LocationResult other, double thresholdMeters) {
    return distanceTo(other) > thresholdMeters;
  }

  /// 位置时效性检查（是否在指定秒数内）
  bool isFresh(int maxAgeSeconds) {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age <= maxAgeSeconds * 1000;
  }

  /// 格式化坐标字符串
  String get coordinateString =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  @override
  String toString() =>
      'LocationResult($coordinateString, acc: ${accuracy?.toStringAsFixed(0) ?? "?"}m)';

  static double _toRadians(double degrees) => degrees * pi / 180;
}

// =============================================================================
// 定位服务接口
// =============================================================================

/// 定位服务抽象基类
///
/// 定义定位服务的统一接口，支持 Mock 和真机实现。
abstract class LocationService {
  // ===== 生命周期 =====

  /// 初始化服务（请求权限等）
  Future<void> initialize();

  /// 释放资源
  Future<void> dispose();

  // ===== 权限 =====

  /// 当前权限状态
  LocationPermissionStatus get permissionStatus;

  /// 请求定位权限
  Future<LocationPermissionStatus> requestPermission();

  /// 打开系统定位设置（用于被永久拒绝后引导用户）
  Future<void> openLocationSettings();

  // ===== 单次定位 =====

  /// 获取当前定位
  ///
  /// [accuracy] 期望的精度等级
  /// [timeoutSeconds] 超时时间
  Future<LocationResult?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    int timeoutSeconds = 30,
  });

  // ===== 连续定位 =====

  /// 获取定位流（连续监听位置变化）
  ///
  /// [accuracy] 期望的精度等级
  /// [distanceFilterMeters] 距离过滤，仅当位移超过此值时才更新
  Stream<LocationResult> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    double distanceFilterMeters = 10,
  });

  // ===== 状态查询 =====

  /// 定位服务是否可用
  bool get isLocationServiceEnabled;

  /// 上次成功定位结果
  LocationResult? get lastKnownLocation;
}

// =============================================================================
// Mock 定位服务实现（开发/测试/桌面环境使用）
// =============================================================================

/// 模拟定位服务
///
/// 提供模拟的定位数据，用于开发调试和桌面环境。
/// 可配置默认位置、模拟移动轨迹。
class MockLocationService extends ChangeNotifier implements LocationService {
  // ===== 配置参数 =====

  /// 模拟定位的默认坐标（默认：北京市中心）
  static const double defaultLatitude = 39.9042;
  static const double defaultLongitude = 116.4074;

  /// 模拟定位精度（米）
  static const double defaultAccuracy = 10.0;

  /// 定位间隔（毫秒）
  final int mockIntervalMs;

  /// 是否启用模拟移动（添加随机漂移）
  final bool simulateMovement;

  /// 随机漂移范围（米）
  final double driftRadiusMeters;

  // ===== 内部状态 =====

  LocationPermissionStatus _permission = LocationPermissionStatus.granted;
  LocationResult? _lastKnown;
  bool _isEnabled = true;
  StreamController<LocationResult>? _streamController;
  Timer? _simulationTimer;

  /// 模拟的当前位置（可外部设置）
  LocationResult _mockPosition;

  // ===== 构造函数 =====

  MockLocationService({
    LocationResult? initialPosition,
    this.mockIntervalMs = 5000,
    this.simulateMovement = false,
    this.driftRadiusMeters = 5,
  }) : _mockPosition = initialPosition ??
            LocationResult(
              latitude: defaultLatitude,
              longitude: defaultLongitude,
              accuracy: defaultAccuracy,
            );

  // ===== 接口实现 =====

  @override
  LocationPermissionStatus get permissionStatus => _permission;

  @override
  bool get isLocationServiceEnabled => _isEnabled;

  @override
  LocationResult? get lastKnownLocation => _lastKnown ?? _mockPosition;

  @override
  Future<void> initialize() async {
    _lastKnown = _mockPosition;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _simulationTimer?.cancel();
    await _streamController?.close();
    _streamController = null;
    super.dispose();
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    // Mock：总是授权成功
    _permission = LocationPermissionStatus.granted;
    notifyListeners();
    return _permission;
  }

  @override
  Future<void> openLocationSettings() async {
    // Mock：无操作
  }

  @override
  Future<LocationResult?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    int timeoutSeconds = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _lastKnown = _addDrift(_mockPosition);
    notifyListeners();
    return _lastKnown;
  }

  @override
  Stream<LocationResult> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    double distanceFilterMeters = 10,
  }) {
    _streamController?.close();
    _streamController = StreamController<LocationResult>.broadcast(
      onListen: () {
        _startSimulation(distanceFilterMeters);
      },
      onCancel: () {
        _simulationTimer?.cancel();
        _simulationTimer = null;
      },
    );
    return _streamController!.stream;
  }

  // ===== 辅助方法 =====

  /// 设置模拟位置
  void setMockPosition(LocationResult position) {
    _mockPosition = position;
    _lastKnown = position;
    notifyListeners();
  }

  /// 设置模拟权限状态
  void setMockPermission(LocationPermissionStatus status) {
    _permission = status;
    notifyListeners();
  }

  /// 启用/禁用定位服务
  void setMockServiceEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// 添加随机漂移
  LocationResult _addDrift(LocationResult base) {
    if (!simulateMovement) return base;

    final rng = Random();
    // 约 0.00001 度 ≈ 1 米
    final latDrift = (rng.nextDouble() - 0.5) * 2 * driftRadiusMeters * 0.00001;
    final lngDrift =
        (rng.nextDouble() - 0.5) * 2 * driftRadiusMeters * 0.00001;

    return LocationResult(
      latitude: base.latitude + latDrift,
      longitude: base.longitude + lngDrift,
      accuracy: base.accuracy,
      altitude: base.altitude,
      speed: base.speed,
    );
  }

  /// 启动模拟定位流
  void _startSimulation(double distanceFilterMeters) {
    _simulationTimer?.cancel();

    LocationResult lastEmitted = _mockPosition;

    _simulationTimer = Timer.periodic(Duration(milliseconds: mockIntervalMs), (_) {
      if (_streamController == null || _streamController!.isClosed) {
        _simulationTimer?.cancel();
        return;
      }

      final newPos = _addDrift(_mockPosition);
      _mockPosition = newPos;
      _lastKnown = newPos;

      // 应用距离过滤
      if (newPos.distanceTo(lastEmitted) >= distanceFilterMeters) {
        lastEmitted = newPos;
        _streamController!.add(newPos);
      }

      notifyListeners();
    });
  }
}
