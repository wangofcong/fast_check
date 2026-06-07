/// 地理围栏距离校验工具
///
/// 提供地理围栏半径的校验逻辑，遵循 README 1.1 节的规则：
///
/// | 用户输入值     | 系统行为                                         |
/// |--------------|--------------------------------------------------|
/// | 1~1000 米    | ✅ 正常接受，视为有效地理围栏半径                    |
/// | > 1000 米    | ⚠️ 弹出警告弹窗，用户需确认或重新设置              |
/// | < 50 米      | ⚠️ 提示距离过小，建议设为 50 米以上               |

/// 校验结果状态
enum GeofenceValidationStatus {
  /// 通过 — 值在 50~1000 米范围内
  ok,

  /// 警告 — 值 > 1000 米，需要用户确认
  warningTooLarge,

  /// 警告 — 值 < 50 米，距离过小
  warningTooSmall,

  /// 错误 — 值超出 1~5000 米的允许范围
  errorOutOfRange,
}

/// 校验结果
class GeofenceValidationResult {
  /// 校验状态
  final GeofenceValidationStatus status;

  /// 提示消息
  final String message;

  /// 建议的修正值（如果适用）
  final int? suggestedValue;

  const GeofenceValidationResult({
    required this.status,
    required this.message,
    this.suggestedValue,
  });

  /// 是否通过校验
  bool get isValid => status == GeofenceValidationStatus.ok;

  /// 是否需要用户确认
  bool get requiresConfirmation =>
      status == GeofenceValidationStatus.warningTooLarge;

  /// 是否建议修改
  bool get requiresAdjustment =>
      status == GeofenceValidationStatus.warningTooSmall ||
      status == GeofenceValidationStatus.errorOutOfRange;
}

/// 地理围栏校验器
class GeofenceValidator {
  GeofenceValidator._();

  // ===== 常量定义 =====

  /// 地理围栏半径最小值（米）
  static const int minRadius = 50;

  /// 地理围栏半径最大值（米）
  static const int maxRadius = 5000;

  /// 警告阈值（米）— 超过此值需用户确认
  static const int warningThreshold = 1000;

  /// 推荐的默认半径（米）
  static const int defaultRadius = 200;

  /// 滑块步进值（米）
  static const int sliderStep = 1;

  // ===== 校验方法 =====

  /// 校验地理围栏半径值
  ///
  /// [radius] 用户输入或选择的半径值（米）
  /// 返回 [GeofenceValidationResult]
  static GeofenceValidationResult validate(int radius) {
    // 范围错误
    if (radius < 1 || radius > maxRadius) {
      return GeofenceValidationResult(
        status: GeofenceValidationStatus.errorOutOfRange,
        message: radius < 1
            ? '半径不能小于 1 米'
            : '半径不能超过 $maxRadius 米',
        suggestedValue: radius.clamp(1, maxRadius),
      );
    }

    // 距离过小
    if (radius < minRadius) {
      return GeofenceValidationResult(
        status: GeofenceValidationStatus.warningTooSmall,
        message: '您设置的距离为 $radius 米，距离过小可能导致定位误差无法准确触发，建议设为 $minRadius 米以上。',
        suggestedValue: minRadius,
      );
    }

    // 超过警告阈值
    if (radius > warningThreshold) {
      return GeofenceValidationResult(
        status: GeofenceValidationStatus.warningTooLarge,
        message: '您设置的距离为 $radius 米，超过 $warningThreshold 米。'
            '公司通常应在较小范围内，请确认是否设置正确？',
      );
    }

    // 通过
    return GeofenceValidationResult(
      status: GeofenceValidationStatus.ok,
      message: radius <= 200
          ? '标准范围，适合写字楼/园区'
          : '较大范围，适合大型园区/校园',
    );
  }

  // ===== 便捷方法 =====

  /// 校验并将半径修正到合法范围
  static int clampRadius(int radius) {
    return radius.clamp(1, maxRadius);
  }

  /// 检查半径是否在推荐范围内（无需警告）
  static bool isRecommended(int radius) {
    return radius >= minRadius && radius <= warningThreshold;
  }

  /// 获取半径的范围提示文本
  static String getRadiusHint(int radius) {
    if (radius < minRadius) {
      return '距离过小，可能导致定位误差无法准确触发';
    } else if (radius <= 200) {
      return '标准范围，适合写字楼/园区';
    } else if (radius <= 500) {
      return '较大范围，适合大型园区';
    } else if (radius <= warningThreshold) {
      return '大范围，适合工厂/校园等大面积区域';
    } else {
      return '超大范围，请确认是否设置正确';
    }
  }

  /// 获取半径级别描述
  static String getRadiusLevel(int radius) {
    if (radius < minRadius) return '过小';
    if (radius <= 200) return '标准';
    if (radius <= 500) return '较大';
    if (radius <= warningThreshold) return '大';
    return '超大';
  }

  /// 获取滑块可选的推荐值列表
  static List<int> get recommendedValues =>
      [50, 100, 200, 300, 500, 1000, 2000, 3000, 5000];
}
