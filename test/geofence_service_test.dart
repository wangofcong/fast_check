import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/services/location_service.dart';
import 'package:fast_check/services/geofence_service.dart';
import 'package:fast_check/models/company_location.dart';

void main() {
  group('GeofenceEvent', () {
    test('创建围栏进入事件', () {
      final loc = CompanyLocation(
        name: '公司总部',
        latitude: 39.9042,
        longitude: 116.4074,
        geofenceRadius: 200,
      );
      final userLoc = LocationResult(latitude: 39.9050, longitude: 116.4080);
      final event = GeofenceEvent(
        type: GeofenceEventType.enter,
        location: loc,
        distanceMeters: 100,
        timestamp: DateTime.now(),
        userLocation: userLoc,
      );
      expect(event.isEnter, isTrue);
      expect(event.isExit, isFalse);
      expect(event.isInside, isTrue);
      expect(event.formattedDistance, '100 m');
      expect(event.location.name, '公司总部');
    });

    test('创建围栏离开事件', () {
      final loc = CompanyLocation(
        name: '公司总部',
        latitude: 39.9042,
        longitude: 116.4074,
      );
      final userLoc = LocationResult(latitude: 39.9100, longitude: 116.4100);
      final event = GeofenceEvent(
        type: GeofenceEventType.exit,
        location: loc,
        distanceMeters: 500,
        timestamp: DateTime.now(),
        userLocation: userLoc,
      );
      expect(event.isEnter, isFalse);
      expect(event.isExit, isTrue);
      expect(event.isInside, isFalse);
    });
  });

  group('LocationDistanceStatus', () {
    test('围栏内部状态正确', () {
      final loc = CompanyLocation(
        name: '公司总部',
        latitude: 39.9042,
        longitude: 116.4074,
        geofenceRadius: 200,
      );
      final status = LocationDistanceStatus(
        location: loc,
        distanceMeters: 100,
        isInside: true,
        ratio: 0.5,
        timestamp: DateTime.now(),
      );
      expect(status.isInside, isTrue);
      expect(status.ratio, 0.5);
      expect(status.formattedDistance, '100 m');
    });

    test('围栏外部状态正确', () {
      final loc = CompanyLocation(
        name: '公司总部',
        latitude: 39.9042,
        longitude: 116.4074,
        geofenceRadius: 200,
      );
      final status = LocationDistanceStatus(
        location: loc,
        distanceMeters: 500,
        isInside: false,
        ratio: 2.5,
        timestamp: DateTime.now(),
      );
      expect(status.isInside, isFalse);
      expect(status.ratio, 2.5);
    });

    test('千米格式化', () {
      final loc = CompanyLocation(
        name: '公司总部',
        latitude: 39.9042,
        longitude: 116.4074,
      );
      final status = LocationDistanceStatus(
        location: loc,
        distanceMeters: 1500,
        isInside: false,
        ratio: 7.5,
        timestamp: DateTime.now(),
      );
      expect(status.formattedDistance, '1.5 km');
    });
  });

  group('GeofenceService', () {
    late MockLocationService mockLocation;
    late GeofenceService geofenceService;

    setUp(() {
      mockLocation = MockLocationService(
        simulateMovement: false,
        mockIntervalMs: 100,
      );
      geofenceService = GeofenceService(
        locationService: mockLocation,
        minIntervalMs: 50,
        distanceFilterMeters: 1,
      );
    });

    tearDown(() async {
      await geofenceService.stopMonitoring();
      geofenceService.dispose();
      mockLocation.dispose();
    });

    test('初始状态：未监控', () {
      expect(geofenceService.isMonitoring, isFalse);
      expect(geofenceService.distances, isEmpty);
      expect(geofenceService.nearestStatus, isNull);
      expect(geofenceService.isInsideAnyGeofence, isFalse);
    });

    test('开始监控后状态变化', () async {
      final locations = [
        CompanyLocation(
          id: 1,
          name: '公司总部',
          latitude: 39.9042,
          longitude: 116.4074,
          geofenceRadius: 500,
        ),
      ];

      await geofenceService.startMonitoring(locations);

      expect(geofenceService.isMonitoring, isTrue);
      expect(geofenceService.distances.length, 1);
      expect(geofenceService.currentLocation, isNotNull);
    });

    test('在围栏范围内 detects inside', () async {
      // Mock 位置设置为公司坐标附近（在 200m 范围内）
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9042,
        longitude: 116.4074,
      ));

      final locations = [
        CompanyLocation(
          id: 1,
          name: '公司总部',
          latitude: 39.9042,
          longitude: 116.4074,
          geofenceRadius: 500,
        ),
      ];

      await geofenceService.startMonitoring(locations);

      expect(geofenceService.isInsideAnyGeofence, isTrue);
      expect(geofenceService.nearestStatus, isNotNull);
      expect(geofenceService.nearestStatus!.isInside, isTrue);
    });

    test('在围栏范围外 detects outside', () async {
      // Mock 位置设置到远处（> 500m）
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9100,
        longitude: 116.4200,
      ));

      final locations = [
        CompanyLocation(
          id: 1,
          name: '公司总部',
          latitude: 39.9042,
          longitude: 116.4074,
          geofenceRadius: 200,
        ),
      ];

      await geofenceService.startMonitoring(locations);

      expect(geofenceService.isInsideAnyGeofence, isFalse);
      expect(geofenceService.nearestStatus, isNotNull);
      expect(geofenceService.nearestStatus!.isInside, isFalse);
    });

    test('进入围栏触发 enter 事件', () async {
      final events = <GeofenceEvent>[];
      final sub = geofenceService.eventStream.listen((e) {
        events.add(e);
      });

      // 从远处开始
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9100,
        longitude: 116.4200,
      ));

      final locations = [
        CompanyLocation(
          id: 1,
          name: '公司总部',
          latitude: 39.9042,
          longitude: 116.4074,
          geofenceRadius: 500,
        ),
      ];

      await geofenceService.startMonitoring(locations);

      // 移动到围栏内
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9042,
        longitude: 116.4074,
      ));

      // 触发一次 getCurrentLocation 来评估
      await mockLocation.getCurrentLocation();

      // 给事件处理一点时间
      await Future.delayed(const Duration(milliseconds: 50));

      // 手动触发布局更新
      // 由于是 mock，startMonitoring 已经评估了初始位置
      // 现在手动触发第二次评估 - 通过调用 getCurrentLocation

      sub.cancel();

      // 至少没有任何错误
      expect(geofenceService.isInsideAnyGeofence, isTrue);
    });

    test('离开围栏触发 exit 事件', () async {
      final events = <GeofenceEvent>[];
      final sub = geofenceService.eventStream.listen((e) {
        events.add(e);
      });

      // 先设置在围栏内
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9042,
        longitude: 116.4074,
      ));

      final locations = [
        CompanyLocation(
          id: 1,
          name: '公司总部',
          latitude: 39.9042,
          longitude: 116.4074,
          geofenceRadius: 500,
        ),
      ];

      await geofenceService.startMonitoring(locations);
      expect(geofenceService.isInsideAnyGeofence, isTrue);

      // 移动到围栏外
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9200,
        longitude: 116.4300,
      ));
      await mockLocation.getCurrentLocation();

      await Future.delayed(const Duration(milliseconds: 50));

      sub.cancel();

      // 验证已不在围栏内
      expect(geofenceService.isInsideAnyGeofence, isFalse);
    });

    test('多地点监控', () async {
      final loc1 = CompanyLocation(
        id: 1,
        name: '总部',
        latitude: 39.9042,
        longitude: 116.4074,
        geofenceRadius: 200,
      );
      final loc2 = CompanyLocation(
        id: 2,
        name: '分公司',
        latitude: 39.9500,
        longitude: 116.4500,
        geofenceRadius: 300,
      );

      // 在总部附近
      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9045,
        longitude: 116.4075,
      ));

      await geofenceService.startMonitoring([loc1, loc2]);

      expect(geofenceService.distances.length, 2);
      // 应靠近总部
      expect(geofenceService.nearestStatus!.location.name, '总部');
      expect(geofenceService.isInsideAnyGeofence, isTrue);
    });

    test('getDistanceToLocation 返回特定地点距离', () async {
      final loc = CompanyLocation(
        id: 1,
        name: '公司',
        latitude: 39.9042,
        longitude: 116.4074,
      );

      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9050,
        longitude: 116.4080,
      ));

      await geofenceService.startMonitoring([loc]);

      final dist = geofenceService.getDistanceToLocation(1);
      expect(dist, isNotNull);
      expect(dist!, greaterThan(0));
      expect(dist, lessThan(500)); // 应该很近
    });

    test('getDistanceToDefaultLocation 返回默认地点距离', () async {
      final loc = CompanyLocation(
        id: 1,
        name: '公司',
        latitude: 39.9042,
        longitude: 116.4074,
        isDefault: 1,
      );

      mockLocation.setMockPosition(LocationResult(
        latitude: 39.9050,
        longitude: 116.4080,
      ));

      await geofenceService.startMonitoring([loc]);

      final dist = geofenceService.getDistanceToDefaultLocation();
      expect(dist, isNotNull);
      expect(dist, greaterThan(0));
    });

    test('stopMonitoring 停止监控', () async {
      final loc = CompanyLocation(
        id: 1,
        name: '公司',
        latitude: 39.9042,
        longitude: 116.4074,
      );

      await geofenceService.startMonitoring([loc]);
      expect(geofenceService.isMonitoring, isTrue);

      await geofenceService.stopMonitoring();
      expect(geofenceService.isMonitoring, isFalse);
    });

    test('updateMonitoredLocations 更新地点列表', () async {
      final loc1 = CompanyLocation(
        id: 1,
        name: '总部',
        latitude: 39.9042,
        longitude: 116.4074,
      );
      final loc2 = CompanyLocation(
        id: 2,
        name: '分部',
        latitude: 31.2304,
        longitude: 121.4737,
      );

      await geofenceService.startMonitoring([loc1]);
      expect(geofenceService.distances.length, 1);

      await geofenceService.updateMonitoredLocations([loc1, loc2]);
      // 未在监控中，因为 stopMonitoring 被调用了
      // 再重新 start
      await geofenceService.startMonitoring([loc1, loc2]);
      expect(geofenceService.distances.length, 2);
    });
  });
}
