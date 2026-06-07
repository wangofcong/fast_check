import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/utils/distance_calculator.dart';

void main() {
  group('DistanceCalculator', () {
    // ===== Haversine 公式测试 =====

    test('相同点距离为 0', () {
      final p = GeoPoint(39.9042, 116.4074);
      final result = DistanceCalculator.calculate(p, p);
      expect(result.meters, closeTo(0, 0.01));
      expect(result.roundedMeters, 0);
    });

    test('北京到上海的大致距离', () {
      final beijing = GeoPoint(39.9042, 116.4074);
      final shanghai = GeoPoint(31.2304, 121.4737);
      final result = DistanceCalculator.calculate(beijing, shanghai);
      // 北京到上海约 1068 km
      expect(result.kilometers, closeTo(1068, 50));
      expect(result.formatted, contains('km'));
    });

    test('两点间短距离计算', () {
      final p1 = GeoPoint(39.9042, 116.4074);
      final p2 = GeoPoint(39.9060, 116.4100);
      final result = DistanceCalculator.calculate(p1, p2);
      // 约 200~300 米
      expect(result.meters, greaterThan(150));
      expect(result.meters, lessThan(400));
    });

    test('经纬度零点的邻居点', () {
      final origin = GeoPoint(0, 0);
      // 赤道上1度约111km
      final near = GeoPoint(0.01, 0);
      final result = DistanceCalculator.calculate(origin, near);
      expect(result.meters, closeTo(1112, 50)); // 约1.1km
    });

    // ===== calculateAdaptiveInterval 测试 =====

    test('距离 12000 米时间隔为 60 分钟', () {
      expect(DistanceCalculator.calculateAdaptiveInterval(12000), 60);
    });

    test('距离 6000 米时间隔为 30 分钟', () {
      expect(DistanceCalculator.calculateAdaptiveInterval(6000), 30);
    });

    test('距离 3000 米时间隔为 15 分钟', () {
      expect(DistanceCalculator.calculateAdaptiveInterval(3000), 15);
    });

    test('距离 1000 米时间隔为 5 分钟', () {
      expect(DistanceCalculator.calculateAdaptiveInterval(1000), 5);
    });

    test('距离 500 米时间隔至少 5 分钟', () {
      expect(DistanceCalculator.calculateAdaptiveInterval(500), 5);
    });

    test('距离 0 米时间隔至少 5 分钟', () {
      expect(DistanceCalculator.calculateAdaptiveInterval(0), 5);
    });

    // ===== isWithinGeofence 测试 =====

    test('距离小于围栏半径时返回 true', () {
      expect(DistanceCalculator.isWithinGeofence(100, 200), true);
    });

    test('距离等于围栏半径时返回 true', () {
      expect(DistanceCalculator.isWithinGeofence(200, 200), true);
    });

    test('距离大于围栏半径时返回 false', () {
      expect(DistanceCalculator.isWithinGeofence(300, 200), false);
    });

    // ===== formatDistance 测试 =====

    test('小于1千米显示米', () {
      expect(DistanceCalculator.formatDistance(500), '500 m');
    });

    test('大于1千米显示千米', () {
      expect(DistanceCalculator.formatDistance(1500), '1.5 km');
    });

    test('1千米整数显示千米', () {
      expect(DistanceCalculator.formatDistance(1000), '1.0 km');
    });
  });

  group('AdaptiveIntervalCalculator', () {
    // ===== 分级计算测试 =====

    test('极远距离(>10km)返回60分钟', () {
      expect(AdaptiveIntervalCalculator.calculate(12000, 200), 60);
    });

    test('较远距离(5-10km)返回30分钟', () {
      expect(AdaptiveIntervalCalculator.calculate(7000, 200), 30);
    });

    test('中等距离(1-5km)返回15分钟', () {
      expect(AdaptiveIntervalCalculator.calculate(3000, 200), 15);
    });

    test('较近距离(500m-1km)返回5分钟', () {
      expect(AdaptiveIntervalCalculator.calculate(800, 200), 5);
    });

    test('在围栏范围内返回0（立即触发）', () {
      expect(AdaptiveIntervalCalculator.calculate(100, 200), 0);
    });

    // ===== 公式计算测试 =====

    test('公式计算 12000 米 = 60', () {
      expect(AdaptiveIntervalCalculator.calculateByFormula(12000), 60);
    });

    test('公式计算 0 米 = 5', () {
      expect(AdaptiveIntervalCalculator.calculateByFormula(0), 5);
    });

    test('公式计算结果与分级结果在合理范围内', () {
      // 3000米时，公式: 3000/200 = 15
      expect(AdaptiveIntervalCalculator.calculateByFormula(3000), 15);
      // 分级: 15
      expect(AdaptiveIntervalCalculator.calculate(3000, 200), 15);
    });
  });

  group('GeoPoint', () {
    test('toString 格式正确', () {
      final p = GeoPoint(39.904200, 116.407400);
      expect(p.toString(), contains('39.904200'));
      expect(p.toString(), contains('116.407400'));
    });
  });

  group('DistanceResult', () {
    test('formatted 小于 1km 显示米', () {
      final r = DistanceResult(meters: 500, kilometers: 0.5);
      expect(r.formatted, '500 m');
    });

    test('formatted 大于 1km 显示千米', () {
      final r = DistanceResult(meters: 1500, kilometers: 1.5);
      expect(r.formatted, '1.5 km');
    });
  });
}
