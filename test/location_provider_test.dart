import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/services/location_service.dart';
import 'package:fast_check/services/geofence_service.dart';
import 'package:fast_check/providers/location_provider.dart';

void main() {
  group('LocationProvider', () {
    late MockLocationService mockLocation;
    late GeofenceService geofenceService;
    late LocationProvider provider;

    setUp(() {
      mockLocation = MockLocationService(
        simulateMovement: false,
      );
      geofenceService = GeofenceService(
        locationService: mockLocation,
        minIntervalMs: 50,
        distanceFilterMeters: 1,
      );
      provider = LocationProvider(
        locationService: mockLocation,
        geofenceService: geofenceService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('初始状态为 initializing', () {
      expect(provider.state, LocationState.initializing);
    });

    test('initialize 后状态变为 available', () async {
      await provider.initialize();
      expect(provider.state, LocationState.available);
      expect(provider.isMonitoring, isTrue);
    });

    test('initialize 后有当前位置信息', () async {
      await provider.initialize();
      expect(provider.currentLocation, isNotNull);
      expect(provider.currentLocation!.latitude,
          MockLocationService.defaultLatitude);
    });

    test('没有公司地点时仍可初始化', () async {
      // 注意：数据库中没有地点，所以监控不会开始
      await provider.initialize();
      expect(provider.state, LocationState.available);
    });

    test('statusText 在围栏内正确', () async {
      mockLocation.setMockPosition(LocationResult(
        latitude: MockLocationService.defaultLatitude,
        longitude: MockLocationService.defaultLongitude,
      ));
      await provider.initialize();
      // 因为没有公司地点，所以距离为空
      expect(provider.statusText, contains('定位可用'));
    });

    test('formattedDistanceToDefault 返回未知', () {
      expect(provider.formattedDistanceToDefault, '未知');
    });

    test('requestPermission 返回 granted', () async {
      final result = await provider.requestPermission();
      expect(result, LocationPermissionStatus.granted);
    });

    test('refreshLocation 返回位置', () async {
      final loc = await provider.refreshLocation();
      expect(loc, isNotNull);
    });

    test('stopMonitoring 停止监控', () async {
      await provider.initialize();
      expect(provider.isMonitoring, isTrue);

      await provider.stopMonitoring();
      expect(provider.isMonitoring, isFalse);
    });

    test('startMonitoring 在停止后重新开始', () async {
      await provider.initialize();
      await provider.stopMonitoring();
      expect(provider.isMonitoring, isFalse);

      await provider.startMonitoring();
      expect(provider.isMonitoring, isTrue);
    });

    test('dispose 后不会抛出异常', () {
      provider.dispose();
      // 再次调用不应抛出
      provider.dispose();
    });
  });
}
