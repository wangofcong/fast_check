import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/services/location_service.dart';

void main() {
  group('LocationResult', () {
    test('创建基本定位结果', () {
      final loc = LocationResult(latitude: 39.9042, longitude: 116.4074);
      expect(loc.latitude, 39.9042);
      expect(loc.longitude, 116.4074);
      expect(loc.accuracy, isNull);
      expect(loc.timestamp, greaterThan(0));
    });

    test('创建带精度的定位结果', () {
      final loc = LocationResult(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 10.0,
        altitude: 50.0,
        speed: 1.5,
      );
      expect(loc.accuracy, 10.0);
      expect(loc.altitude, 50.0);
      expect(loc.speed, 1.5);
    });

    test('fromMap 反序列化', () {
      final map = {
        'latitude': 39.9042,
        'longitude': 116.4074,
        'accuracy': 15.0,
        'altitude': 100.0,
        'speed': 0.0,
        'timestamp': 1700000000000,
      };
      final loc = LocationResult.fromMap(map);
      expect(loc.latitude, 39.9042);
      expect(loc.accuracy, 15.0);
      expect(loc.timestamp, 1700000000000);
    });

    test('toMap 序列化', () {
      final loc = LocationResult(
        latitude: 39.9042,
        longitude: 116.4074,
        accuracy: 8.0,
      );
      final map = loc.toMap();
      expect(map['latitude'], 39.9042);
      expect(map['longitude'], 116.4074);
      expect(map['accuracy'], 8.0);
      expect(map['timestamp'], isNotNull);
    });

    test('distanceTo 计算两点距离', () {
      final loc1 = LocationResult(latitude: 39.9042, longitude: 116.4074);
      final loc2 = LocationResult(latitude: 39.9060, longitude: 116.4100);
      final dist = loc1.distanceTo(loc2);
      // 约 200~300 米
      expect(dist, greaterThan(150));
      expect(dist, lessThan(400));
    });

    test('相同点距离为 0', () {
      final loc1 = LocationResult(latitude: 39.9042, longitude: 116.4074);
      final loc2 = LocationResult(latitude: 39.9042, longitude: 116.4074);
      expect(loc1.distanceTo(loc2), closeTo(0, 0.01));
    });

    test('hasSignificantMove 检测显著位移', () {
      final loc1 = LocationResult(latitude: 39.9042, longitude: 116.4074);
      final loc2 = LocationResult(latitude: 39.9060, longitude: 116.4100);
      expect(loc1.hasSignificantMove(loc2, 300), isFalse); // ~250m < 300
      expect(loc1.hasSignificantMove(loc2, 100), isTrue); // ~250m > 100
    });

    test('isFresh 检查时效性', () {
      final oldLoc = LocationResult(
        latitude: 39.9042,
        longitude: 116.4074,
        timestamp: DateTime.now().millisecondsSinceEpoch - 60000, // 60秒前
      );
      expect(oldLoc.isFresh(120), isTrue); // 120秒内
      expect(oldLoc.isFresh(30), isFalse); // 超过30秒
    });

    test('coordinateString 格式正确', () {
      final loc = LocationResult(latitude: 39.904200, longitude: 116.407400);
      expect(loc.coordinateString, '39.904200, 116.407400');
    });
  });

  group('MockLocationService', () {
    late MockLocationService service;

    setUp(() {
      service = MockLocationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('默认初始状态', () {
      expect(service.permissionStatus, LocationPermissionStatus.granted);
      expect(service.isLocationServiceEnabled, isTrue);
      expect(service.lastKnownLocation, isNotNull);
      expect(service.lastKnownLocation!.latitude,
          MockLocationService.defaultLatitude);
      expect(service.lastKnownLocation!.longitude,
          MockLocationService.defaultLongitude);
    });

    test('initialize 后保留初始位置', () async {
      await service.initialize();
      expect(service.lastKnownLocation, isNotNull);
    });

    test('requestPermission 返回 granted', () async {
      final result = await service.requestPermission();
      expect(result, LocationPermissionStatus.granted);
    });

    test('getCurrentLocation 返回位置', () async {
      final loc = await service.getCurrentLocation();
      expect(loc, isNotNull);
      expect(loc!.latitude, MockLocationService.defaultLatitude);
      expect(loc.longitude, MockLocationService.defaultLongitude);
    });

    test('setMockPosition 更新模拟位置', () {
      final newPos = LocationResult(latitude: 31.2304, longitude: 121.4737);
      service.setMockPosition(newPos);
      expect(service.lastKnownLocation!.latitude, 31.2304);
      expect(service.lastKnownLocation!.longitude, 121.4737);
    });

    test('setMockPermission 更改权限状态', () {
      service.setMockPermission(LocationPermissionStatus.denied);
      expect(service.permissionStatus, LocationPermissionStatus.denied);
    });

    test('setMockServiceEnabled 更改服务状态', () {
      service.setMockServiceEnabled(false);
      expect(service.isLocationServiceEnabled, isFalse);
    });

    test('getLocationStream 返回流并产生事件', () async {
      final stream = service.getLocationStream(distanceFilterMeters: 1);
      final events = <LocationResult>[];

      final sub = stream.listen((loc) {
        events.add(loc);
      });

      // 等待模拟定位产生事件
      await Future.delayed(const Duration(milliseconds: 200));

      sub.cancel();
      expect(events.length, greaterThanOrEqualTo(1));
      expect(events.first.latitude, closeTo(
          MockLocationService.defaultLatitude, 0.01));
    });

    test('getLocationStream 带模拟移动时产生漂移', () async {
      final movingService = MockLocationService(
        simulateMovement: true,
        driftRadiusMeters: 10,
        mockIntervalMs: 100,
      );

      final stream = movingService.getLocationStream(distanceFilterMeters: 1);
      final events = <LocationResult>[];

      final sub = stream.listen((loc) {
        events.add(loc);
      });

      await Future.delayed(const Duration(milliseconds: 350));

      sub.cancel();
      movingService.dispose();

      expect(events.length, greaterThanOrEqualTo(2));
      // 验证产生了漂移（坐标不完全相同）
      if (events.length >= 2) {
        final dist = events[0].distanceTo(events[1]);
        expect(dist, greaterThan(0));
      }
    });

    test('使用自定义初始位置', () {
      final customService = MockLocationService(
        initialPosition: LocationResult(
          latitude: 31.2304,
          longitude: 121.4737,
        ),
      );
      expect(customService.lastKnownLocation!.latitude, 31.2304);
      expect(customService.lastKnownLocation!.longitude, 121.4737);
      customService.dispose();
    });

    test('多次调用 dispose 不会报错', () async {
      await service.dispose();
      // 第二次调用不应抛出异常
      await service.dispose();
    });
  });

  group('LocationPermissionStatus', () {
    test('枚举值定义正确', () {
      expect(LocationPermissionStatus.values.length, 5);
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.granted));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.denied));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.deniedForever));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.serviceDisabled));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.unknown));
    });
  });

  group('LocationAccuracy', () {
    test('枚举值定义正确', () {
      expect(LocationAccuracy.values.length, 4);
      expect(LocationAccuracy.values, contains(LocationAccuracy.low));
      expect(LocationAccuracy.values, contains(LocationAccuracy.medium));
      expect(LocationAccuracy.values, contains(LocationAccuracy.high));
      expect(LocationAccuracy.values, contains(LocationAccuracy.best));
    });
  });
}
