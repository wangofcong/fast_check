// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// 生成「打卡提醒」App 图标
///
/// 图标设计：蓝色圆形背景 + 白色时钟 + 对勾
/// 生成 1024x1024 PNG（flutter_launcher_icons 所需源图）
void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  // ---- 1. 背景渐变效果（从上到下浅蓝到深蓝） ----
  for (int y = 0; y < size; y++) {
    final t = y / size;
    final r = (30 + 70 * (1 - t)).round();
    final g = (100 + 80 * (1 - t)).round();
    final b = (200 + 55 * (1 - t)).round();
    final color = img.ColorRgba8(r, g, b, 255);
    for (int x = 0; x < size; x++) {
      image.setPixel(x, y, color);
    }
  }

  // ---- 2. 白色圆形内圈（半透明装饰） ----
  final cx = size / 2;
  final cy = size / 2;
  final innerRadius = size * 0.38;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist <= innerRadius) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        // 变亮 40%
        image.setPixel(x, y, img.ColorRgba8(
          (r + (255 - r) * 0.4).round(),
          (g + (255 - g) * 0.4).round(),
          (b + (255 - b) * 0.4).round(),
          255,
        ));
      }
    }
  }

  // ---- 3. 白色时钟圆环 ----
  final ringOuter = size * 0.35;
  final ringInner = size * 0.29;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist >= ringInner && dist <= ringOuter) {
        image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
      }
    }
  }

  // ---- 4. 时针（短粗，指向右上 10 点方向） ----
  _drawThickLine(image, cx, cy, cx + size * 0.12, cy - size * 0.18, size * 0.025, 255, 255, 255);

  // ---- 5. 分针（细长，指向 12 点方向） ----
  _drawThickLine(image, cx, cy, cx, cy - size * 0.26, size * 0.018, 255, 255, 255);

  // ---- 6. 圆心点 ----
  _drawFilledCircle(image, cx, cy, size * 0.025, 255, 255, 255);

  // ---- 7. 右下角对勾（绿色） ----
  // 对勾位置：时钟下方偏右
  final checkCx = cx + size * 0.15;
  final checkCy = cy + size * 0.15;
  final checkSize = size * 0.12;

  // 对勾的两笔
  _drawThickLine(
    image,
    checkCx - checkSize * 0.4,
    checkCy + checkSize * 0.1,
    checkCx - checkSize * 0.05,
    checkCy + checkSize * 0.35,
    size * 0.025,
    100, 220, 100,
  );
  _drawThickLine(
    image,
    checkCx - checkSize * 0.05,
    checkCy + checkSize * 0.35,
    checkCx + checkSize * 0.45,
    checkCy - checkSize * 0.3,
    size * 0.025,
    100, 220, 100,
  );

  // ---- 8. 底部文字微标区域（简约白色横条装饰） ----
  for (int y = (size * 0.78).round(); y < (size * 0.82).round(); y++) {
    for (int x = (size * 0.35).round(); x < (size * 0.65).round(); x++) {
      final pixel = image.getPixel(x, y);
      image.setPixel(x, y, img.ColorRgba8(
        (pixel.r * 0.7 + 255 * 0.3).round(),
        (pixel.g * 0.7 + 255 * 0.3).round(),
        (pixel.b * 0.7 + 255 * 0.3).round(),
        255,
      ));
    }
  }

  // ---- 输出文件 ----
  final pngBytes = img.encodePng(image);
  final outputDir = Directory('assets');
  if (!outputDir.existsSync()) {
    outputDir.createSync();
  }
  final outputFile = File('assets/app_icon.png');
  outputFile.writeAsBytesSync(pngBytes);
  print('✅ 图标已生成: assets/app_icon.png (${pngBytes.length} bytes)');
}

/// 绘制粗线
void _drawThickLine(
  img.Image image,
  double x1, double y1,
  double x2, double y2,
  double thickness,
  int r, int g, int b,
) {
  final steps = (x1 - x2).abs() > (y1 - y2).abs()
      ? (x1 - x2).abs().round()
      : (y1 - y2).abs().round();
  final stepsActual = steps < 1 ? 1 : steps;

  for (int i = 0; i <= stepsActual; i++) {
    final t = i / stepsActual;
    final x = x1 + (x2 - x1) * t;
    final y = y1 + (y2 - y1) * t;

    // 在点周围画圆
    for (int dy = -thickness.round(); dy <= thickness.round(); dy++) {
      for (int dx = -thickness.round(); dx <= thickness.round(); dx++) {
        final d = sqrt(dx * dx + dy * dy);
        if (d <= thickness) {
          final px = (x + dx).round();
          final py = (y + dy).round();
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            image.setPixel(px, py, img.ColorRgba8(r, g, b, 255));
          }
        }
      }
    }
  }
}

/// 绘制实心圆
void _drawFilledCircle(
  img.Image image,
  double cx, double cy,
  double radius,
  int r, int g, int b,
) {
  for (int dy = -radius.round(); dy <= radius.round(); dy++) {
    for (int dx = -radius.round(); dx <= radius.round(); dx++) {
      if (sqrt(dx * dx + dy * dy) <= radius) {
        final px = (cx + dx).round();
        final py = (cy + dy).round();
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, img.ColorRgba8(r, g, b, 255));
        }
      }
    }
  }
}
