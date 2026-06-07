/// 距离计算工具
///
/// 提供:
/// - 基于 Haversine 公式的两点间直线距离计算
/// - 智能定位间隔计算（自适应距离）
/// - 距离单位转换和格式化

import 'dart:math';

/// 地理坐标（经纬度）
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';
}

/// 距离计算结果
class DistanceResult {
  final double meters;
  final double kilometers;

  const DistanceResult({required this.meters, required this.kilometers});

  /// 格式化输出（智能选择单位）
  String get formatted {
    if (kilometers >= 1) {
      return '${kilometers.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  /// 以米为单位的整数（用于围栏判定）
  int get roundedMeters => meters.round();
}

/// 距离计算器
class DistanceCalculator {
  DistanceCalculator._();

  /// 地球平均半径（米）
  static const double earthRadius = 6_371_000;

  /// 使用 Haversine 公式计算两点间的直线距离
  ///
  /// [p1] 起点坐标
  /// [p2] 终点坐标
  /// 返回 [DistanceResult] 包含米和千米
  static DistanceResult calculate(GeoPoint p1, GeoPoint p2) {
    final lat1 = _toRadians(p1.latitude);
    final lat2 = _toRadians(p2.latitude);
    final dlat = _toRadians(p2.latitude - p1.latitude);
    final dlon = _toRadians(p2.longitude - p1.longitude);

    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final meters = earthRadius * c;
    return DistanceResult(
      meters: meters,
      kilometers: meters / 1000,
    );
  }

  /// 计算自适应定位检查间隔（分钟）
  ///
  /// 根据用户与公司的距离动态调整定位频率：
  /// | 距离范围          | 间隔    |
  /// |-----------------|---------|
  /// | > 10 km         | 60 min  |
  /// | 5 km ~ 10 km    | 30 min  |
  /// | 1 km ~ 5 km     | 15 min  |
  /// | 500 m ~ 1 km    | 5 min   |
  /// | ≤ 围栏半径 R     | 立即触发 |
  ///
  /// 计算公式: interval = max(5, min(60, distanceMeters / 200))
  static int calculateAdaptiveInterval(double distanceMeters) {
    final computed = (distanceMeters / 200).round();
    return computed.clamp(5, 60);
  }

  /// 判断是否在公司范围内
  ///
  /// [distanceMeters] 用户与公司的距离
  /// [geofenceRadius] 地理围栏半径（米）
  static bool isWithinGeofence(double distanceMeters, int geofenceRadius) {
    return distanceMeters <= geofenceRadius;
  }

  /// 格式化距离为可读字符串
  ///
  /// 示例: 1500 → "1.5 km", 200 → "200 m"
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}

/// 智能定位间隔计算
///
/// 用于上班自动打卡（位置触发）功能的省电策略
class AdaptiveIntervalCalculator {
  AdaptiveIntervalCalculator._();

  /// 计算定位检查间隔（分钟）
  ///
  /// 遵循 README 4.3 节的规则：
  /// - 极远（> 10 km）→ 60 min
  /// - 较远（5-10 km）→ 30 min
  /// - 中等（1-5 km）→ 15 min
  /// - 较近（500 m-1 km）→ 5 min
  /// - 附近（≤ 围栏半径 R）→ 立即 (0)
  static int calculate(double distanceMeters, int geofenceRadius) {
    // 如果在围栏范围内，立即触发
    if (distanceMeters <= geofenceRadius) {
      return 0;
    }

    // 分级计算
    if (distanceMeters > 10000) {
      return 60;
    } else if (distanceMeters > 5000) {
      return 30;
    } else if (distanceMeters > 1000) {
      return 15;
    } else {
      // 500m ~ 1km
      return 5;
    }
  }

  /// 使用公式定位间隔(分钟) = max(5, min(60, 距离(米) / 200))
  static int calculateByFormula(double distanceMeters) {
    final computed = (distanceMeters / 200).round();
    return computed.clamp(5, 60);
  }
}
