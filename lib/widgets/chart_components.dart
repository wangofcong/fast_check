/// 图表组件
///
/// 使用 Flutter CustomPaint 实现的轻量级图表组件，
/// 无需额外依赖，支持：
/// - 柱状图 [BarChartWidget]
/// - 折线图 [LineChartWidget]
/// - 饼图 [PieChartWidget]
/// - 图例 [ChartLegend]

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/punch_analysis.dart';

// ====================================================================
//  柱状图
// ====================================================================

/// 柱状图组件
class BarChartWidget extends StatelessWidget {
  final BarChartData data;
  final double height;
  final bool showValue;
  final Color? backgroundColor;

  const BarChartWidget({
    super.key,
    required this.data,
    this.height = 200,
    this.showValue = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height + 40,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, double.infinity),
        painter: _BarChartPainter(data, showValue: showValue),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final BarChartData data;
  final bool showValue;

  _BarChartPainter(this.data, {this.showValue = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.values.isEmpty) return;

    final double padding = 40;
    final double chartWidth = size.width - padding - 16;
    final double chartHeight = size.height - padding;
    final double maxVal = data.maxValue > 0 ? data.maxValue : 1;

    // 绘制 Y 轴参考线
    final axisPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight * i / 4);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - 8, y),
        axisPaint,
      );
    }

    // 绘制柱子
    final barWidth =
        (chartWidth / data.values.length) * 0.6;
    final gap = (chartWidth / data.values.length) * 0.4;

    for (int i = 0; i < data.values.length; i++) {
      final x = padding +
          (barWidth + gap) * i +
          gap / 2;
      final barHeight =
          (data.values[i] / maxVal) * (chartHeight - 16);
      final y = chartHeight - barHeight;

      // 柱子
      final barPaint = Paint()
        ..color = data.barColor
        ..style = PaintingStyle.fill;

      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rRect, barPaint);

      // 值标签
      if (showValue) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: data.values[i].toStringAsFixed(1),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x + barWidth / 2 - textPainter.width / 2,
            y - textPainter.height - 2,
          ),
        );
      }

      // X 轴标签
      if (data.labels.length > i) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: data.labels[i],
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            x + barWidth / 2 - labelPainter.width / 2,
            chartHeight + 4,
          ),
        );
      }
    }

    // 单位标签
    if (data.unit.isNotEmpty) {
      final unitPainter = TextPainter(
        text: TextSpan(
          text: data.unit,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      unitPainter.layout();
      unitPainter.paint(
        canvas,
        Offset(4, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

// ====================================================================
//  折线图
// ====================================================================

/// 折线图组件
class LineChartWidget extends StatelessWidget {
  final LineChartData data;
  final double height;
  final Color? lineColor;

  const LineChartWidget({
    super.key,
    required this.data,
    this.height = 200,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height + 40,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, double.infinity),
        painter: _LineChartPainter(data, lineColor: lineColor),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final LineChartData data;
  final Color? lineColor;

  _LineChartPainter(this.data, {this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.values.isEmpty || data.labels.isEmpty) return;

    final double padding = 40;
    final double chartWidth = size.width - padding - 16;
    final double chartHeight = size.height - padding;

    final values = data.values;
    final maxVal = data.maxValue > 0 ? data.maxValue : 1;
    final minVal = data.minValue;
    final range = maxVal - minVal > 0 ? maxVal - minVal : 1.0;

    // 网格线
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight * i / 4);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - 8, y),
        gridPaint,
      );
    }

    // 计算点坐标
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = padding +
          (chartWidth / (values.length - 1 > 0 ? values.length - 1 : 1)) * i;
      final normalizedY = (values[i] - minVal) / range;
      final y = chartHeight - normalizedY * (chartHeight - 16) - 8;
      points.add(Offset(x, y));
    }

    // 绘制连线
    final linePaint = Paint()
      ..color = lineColor ?? Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    // 绘制数据点和标签
    for (int i = 0; i < points.length; i++) {
      // 点
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], 3.5, dotPaint);

      final borderPaint = Paint()
        ..color = lineColor ?? Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(points[i], 3.5, borderPaint);

      // 值标签
      final valPainter = TextPainter(
        text: TextSpan(
          text: values[i].toStringAsFixed(1),
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[700],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      valPainter.layout();
      valPainter.paint(
        canvas,
        Offset(
          points[i].dx - valPainter.width / 2,
          points[i].dy - valPainter.height - 6,
        ),
      );

      // X 轴标签（间隔显示防重叠）
      final labelInterval =
          (values.length / 10).ceil().clamp(1, values.length);
      if (i % labelInterval == 0 || i == values.length - 1) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: data.labels[i],
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            points[i].dx - labelPainter.width / 2,
            chartHeight + 4,
          ),
        );
      }
    }

    // 单位
    if (data.unit.isNotEmpty) {
      final unitPainter = TextPainter(
        text: TextSpan(
          text: data.unit,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      unitPainter.layout();
      unitPainter.paint(canvas, Offset(4, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

// ====================================================================
//  饼图
// ====================================================================

/// 饼图组件
class PieChartWidget extends StatelessWidget {
  final PieChartData data;
  final double size;

  const PieChartWidget({
    super.key,
    required this.data,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _PieChartPainter(data),
          ),
        ),
        const SizedBox(height: 12),
        ChartLegend(segments: data.segments),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final PieChartData data;

  _PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.segments.isEmpty || data.total <= 0) {
      // 绘制空状态
      final paint = Paint()
        ..color = Colors.grey[200]!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 3,
        paint,
      );
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    double startAngle = -90 * (3.1415927 / 180); // 从顶部开始
    for (final segment in data.segments) {
      final sweepAngle =
          (segment.value / data.total) * 360 * (3.1415927 / 180);

      final fillPaint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        fillPaint,
      );

      // 分割线
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        strokePaint,
      );

      startAngle += sweepAngle;
    }

    // 中心空白
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.45, centerPaint);

    // 百分比文字 — 用 L10n 替代硬编码
    if (data.total > 0) {
      final label = '${data.total.toStringAsFixed(0)}${L10n.chartMinutes}';
      final pctPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pctPainter.layout();
      pctPainter.paint(
        canvas,
        Offset(
          center.dx - pctPainter.width / 2,
          center.dy - pctPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => true;
}

// ====================================================================
//  图例
// ====================================================================

/// 图表图例组件
class ChartLegend extends StatelessWidget {
  final List<PieChartSegment> segments;

  const ChartLegend({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: segments.map((s) {
        final pct = s.value > 0 && segments.isNotEmpty
            ? (s.value /
                    segments.fold<double>(0, (sum, seg) => sum + seg.value))
                .clamp(0.0, 1.0)
            : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: s.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${s.label} ${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ====================================================================
//  统计卡片
// ====================================================================

/// 单个统计指标卡片
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
