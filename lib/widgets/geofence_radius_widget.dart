import 'package:flutter/material.dart';
import '../utils/geofence_validator.dart';

/// 地理围栏半径选择器组件
///
/// 提供:
/// - 滑块拖动选择半径 (50~5000米)
/// - 快捷推荐值按钮
/// - 半径范围提示
/// - 超过1000米的内联警告
/// - 独立的确认弹窗（用于保存时二次确认）
///
/// 使用方式:
/// ```dart
/// GeofenceRadiusPicker(
///   radius: _radius,
///   onChanged: (v) => setState(() => _radius = v),
/// )
/// ```
class GeofenceRadiusPicker extends StatelessWidget {
  final int radius;
  final ValueChanged<int> onChanged;

  const GeofenceRadiusPicker({
    super.key,
    required this.radius,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validation = GeofenceValidator.validate(radius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            const Icon(Icons.straighten, size: 20),
            const SizedBox(width: 8),
            const Text('地理围栏半径',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),

        // 滑块
        Row(
          children: [
            Expanded(
              child: Slider(
                value: radius.toDouble(),
                min: GeofenceValidator.minRadius.toDouble(),
                max: GeofenceValidator.maxRadius.toDouble(),
                divisions: (GeofenceValidator.maxRadius -
                        GeofenceValidator.minRadius) ~/
                    GeofenceValidator.sliderStep,
                label: '$radius 米',
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text('$radius m',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        // 范围提示
        Text(
          GeofenceValidator.getRadiusHint(radius),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),

        // 快捷推荐值
        const SizedBox(height: 8),
        _buildQuickSelectChips(context),

        // 超过 1000m 的内联警告
        if (validation.requiresConfirmation) ...[
          const SizedBox(height: 8),
          _buildInlineWarning(context, validation.message),
        ],

        // 小于 50m 的提示
        if (validation.requiresAdjustment &&
            validation.status == GeofenceValidationStatus.warningTooSmall) ...[
          const SizedBox(height: 8),
          _buildSmallRadiusHint(context, validation),
        ],
      ],
    );
  }

  /// 快捷选择推荐值
  Widget _buildQuickSelectChips(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: GeofenceValidator.recommendedValues.map((value) {
        final isSelected = radius == value;
        return ChoiceChip(
          label: Text(
            value >= 1000 ? '${value ~/ 1000}km' : '${value}m',
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : null,
            ),
          ),
          selected: isSelected,
          selectedColor: _getRadiusColor(value),
          onSelected: (_) => onChanged(value),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// 内联警告（> 1000m）
  Widget _buildInlineWarning(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 距离过小提示（< 50m）
  Widget _buildSmallRadiusHint(
      BuildContext context, GeofenceValidationResult validation) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              validation.message,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          if (validation.suggestedValue != null)
            TextButton(
              onPressed: () => onChanged(validation.suggestedValue!),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('设为 ${validation.suggestedValue}m'),
            ),
        ],
      ),
    );
  }

  Color _getRadiusColor(int value) {
    if (value <= 200) return Colors.green;
    if (value <= 500) return Colors.blue;
    if (value <= 1000) return Colors.orange;
    return Colors.red;
  }
}

/// 半径确认对话框组件
///
/// 当用户设置的半径超过 1000 米时，
/// 在保存前弹出此对话框要求二次确认
class GeofenceConfirmDialog {
  /// 显示半径确认对话框
  ///
  /// [context] 上下文
  /// [radius] 用户设置的半径值
  /// [onConfirm] 用户确认后的回调
  /// [onReject] 用户拒绝后的回调（点击重新设置）
  ///
  /// 返回 true 表示用户确认，false 表示拒绝
  static Future<bool> show({
    required BuildContext context,
    required int radius,
    VoidCallback? onConfirm,
    VoidCallback? onReject,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              const Expanded(child: Text('距离确认')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '您设置的地理围栏半径为 $radius 米，'
                '超过 1000 米。',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '提示：公司办公区域通常在较小范围内（50~1000米）。'
                        '如果您的办公地点分布较分散，可适当增大范围。',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                onReject?.call();
              },
              child: const Text('重新设置'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, true);
                onConfirm?.call();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('确认设置'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
