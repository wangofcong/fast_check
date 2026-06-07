import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/utils/geofence_validator.dart';

void main() {
  group('GeofenceValidator', () {
    // ===== 常量测试 =====
    test('常量值正确', () {
      expect(GeofenceValidator.minRadius, 50);
      expect(GeofenceValidator.maxRadius, 5000);
      expect(GeofenceValidator.warningThreshold, 1000);
      expect(GeofenceValidator.defaultRadius, 200);
    });

    // ===== validate 测试 =====

    test('50~1000 米范围内返回 ok', () {
      final result = GeofenceValidator.validate(200);
      expect(result.status, GeofenceValidationStatus.ok);
      expect(result.isValid, true);
      expect(result.requiresConfirmation, false);
      expect(result.requiresAdjustment, false);
    });

    test('边界值 50 返回 ok', () {
      final result = GeofenceValidator.validate(50);
      expect(result.status, GeofenceValidationStatus.ok);
      expect(result.isValid, true);
    });

    test('边界值 1000 返回 ok', () {
      final result = GeofenceValidator.validate(1000);
      expect(result.status, GeofenceValidationStatus.ok);
      expect(result.isValid, true);
    });

    test('> 1000 米返回 warningTooLarge', () {
      final result = GeofenceValidator.validate(1500);
      expect(result.status, GeofenceValidationStatus.warningTooLarge);
      expect(result.isValid, false);
      expect(result.requiresConfirmation, true);
      expect(result.message, contains('1500'));
      expect(result.message, contains('1000'));
    });

    test('< 50 米返回 warningTooSmall', () {
      final result = GeofenceValidator.validate(30);
      expect(result.status, GeofenceValidationStatus.warningTooSmall);
      expect(result.isValid, false);
      expect(result.requiresAdjustment, true);
      expect(result.suggestedValue, 50);
      expect(result.message, contains('30'));
    });

    test('0 米返回 errorOutOfRange', () {
      final result = GeofenceValidator.validate(0);
      expect(result.status, GeofenceValidationStatus.errorOutOfRange);
      expect(result.isValid, false);
      expect(result.requiresAdjustment, true);
    });

    test('> 5000 米返回 errorOutOfRange', () {
      final result = GeofenceValidator.validate(6000);
      expect(result.status, GeofenceValidationStatus.errorOutOfRange);
      expect(result.isValid, false);
      expect(result.message, contains('5000'));
    });

    // ===== clampRadius 测试 =====

    test('clampRadius 将负值修正为 1', () {
      expect(GeofenceValidator.clampRadius(-10), 1);
    });

    test('clampRadius 保持合法值不变', () {
      expect(GeofenceValidator.clampRadius(200), 200);
    });

    test('clampRadius 将超大值修正为 maxRadius', () {
      expect(GeofenceValidator.clampRadius(10000), 5000);
    });

    // ===== isRecommended 测试 =====

    test('isRecommended 对 50~1000 返回 true', () {
      expect(GeofenceValidator.isRecommended(200), true);
      expect(GeofenceValidator.isRecommended(50), true);
      expect(GeofenceValidator.isRecommended(1000), true);
    });

    test('isRecommended 对 >1000 返回 false', () {
      expect(GeofenceValidator.isRecommended(1500), false);
    });

    test('isRecommended 对 <50 返回 false', () {
      expect(GeofenceValidator.isRecommended(30), false);
    });

    // ===== getRadiusHint 测试 =====

    test('getRadiusHint 返回正确的提示', () {
      expect(GeofenceValidator.getRadiusHint(30), contains('过小'));
      expect(GeofenceValidator.getRadiusHint(200), contains('标准'));
      expect(GeofenceValidator.getRadiusHint(500), contains('大型园区'));
      expect(GeofenceValidator.getRadiusHint(1000), contains('大面积'));
      expect(GeofenceValidator.getRadiusHint(2000), contains('超大'));
    });

    // ===== recommendedValues 测试 =====

    test('recommendedValues 包含关键推荐值', () {
      expect(GeofenceValidator.recommendedValues, contains(50));
      expect(GeofenceValidator.recommendedValues, contains(200));
      expect(GeofenceValidator.recommendedValues, contains(1000));
      expect(GeofenceValidator.recommendedValues, contains(5000));
    });
  });
}
