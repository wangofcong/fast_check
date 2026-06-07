/// Phase 10 — 图表组件渲染测试
///
/// 测试范围：
/// - BarChartWidget 柱状图组件
/// - LineChartWidget 折线图组件
/// - PieChartWidget 饼图组件
/// - ChartLegend 图例组件
/// - StatCard 统计卡片组件

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fast_check/models/punch_analysis.dart';
import 'package:fast_check/widgets/chart_components.dart';

void main() {
  // ====================================================================
  //  BarChartWidget 测试
  // ====================================================================

  group('BarChartWidget', () {
    testWidgets('渲染柱状图', (tester) async {
      final chart = BarChartWidget(
        data: BarChartData(
          labels: ['01', '02', '03'],
          values: [8.0, 9.0, 7.5],
          title: '测试柱状图',
          unit: '小时',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      // 柱状图容器应存在
      expect(find.byType(BarChartWidget), findsOneWidget);
      // 标题未直接显示（在 CustomPaint 内），但容器存在
    });

    testWidgets('空数据柱状图', (tester) async {
      final chart = BarChartWidget(
        data: BarChartData(
          labels: [],
          values: [],
          title: '空',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.byType(BarChartWidget), findsOneWidget);
    });

    testWidgets('自定义高度', (tester) async {
      final chart = BarChartWidget(
        data: BarChartData(
          labels: ['01'],
          values: [5.0],
          title: '测试',
        ),
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.byType(BarChartWidget), findsOneWidget);
    });

    testWidgets('隐藏数值标签', (tester) async {
      final chart = BarChartWidget(
        data: BarChartData(
          labels: ['01'],
          values: [5.0],
          title: '测试',
        ),
        showValue: false,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.byType(BarChartWidget), findsOneWidget);
    });

    testWidgets('自定义背景色', (tester) async {
      final chart = BarChartWidget(
        data: BarChartData(
          labels: ['01'],
          values: [5.0],
          title: '测试',
        ),
        backgroundColor: Colors.grey[100],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.byType(BarChartWidget), findsOneWidget);
    });

    testWidgets('单条数据', (tester) async {
      final chart = BarChartWidget(
        data: BarChartData(
          labels: ['01'],
          values: [10.0],
          title: '单条数据',
          unit: '小时',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(BarChartWidget), findsOneWidget);
    });

    testWidgets('大量数据不崩溃', (tester) async {
      final labels = List.generate(31, (i) => '${i + 1}');
      final values = List.generate(31, (i) => (7.0 + (i % 5) * 0.5));

      final chart = BarChartWidget(
        data: BarChartData(
          labels: labels,
          values: values,
          title: '月度数据',
          unit: '小时',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(BarChartWidget), findsOneWidget);
    });
  });

  // ====================================================================
  //  LineChartWidget 测试
  // ====================================================================

  group('LineChartWidget', () {
    testWidgets('渲染折线图', (tester) async {
      final chart = LineChartWidget(
        data: LineChartData(
          labels: ['01', '02', '03'],
          values: [9.0, 9.5, 8.5],
          title: '趋势图',
          unit: '时',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.byType(LineChartWidget), findsOneWidget);
    });

    testWidgets('单数据点折线图', (tester) async {
      final chart = LineChartWidget(
        data: LineChartData(
          labels: ['01'],
          values: [9.0],
          title: '单点',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(LineChartWidget), findsOneWidget);
    });

    testWidgets('自定义折线颜色', (tester) async {
      final chart = LineChartWidget(
        data: LineChartData(
          labels: ['01', '02'],
          values: [9.0, 8.5],
          title: '测试',
        ),
        lineColor: Colors.green,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(LineChartWidget), findsOneWidget);
    });

    testWidgets('多个数据点', (tester) async {
      final labels = List.generate(10, (i) => '${i + 1}');
      final values = List.generate(10, (i) => 9.0 + (i % 3) * 0.5);

      final chart = LineChartWidget(
        data: LineChartData(
          labels: labels,
          values: values,
          title: '10天趋势',
          unit: '时',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(LineChartWidget), findsOneWidget);
    });

    testWidgets('自定义高度', (tester) async {
      final chart = LineChartWidget(
        data: LineChartData(
          labels: ['01', '02'],
          values: [9.0, 8.5],
          title: '测试',
        ),
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(LineChartWidget), findsOneWidget);
    });
  });

  // ====================================================================
  //  PieChartWidget 测试
  // ====================================================================

  group('PieChartWidget', () {
    testWidgets('渲染饼图', (tester) async {
      final chart = PieChartWidget(
        data: PieChartData(
          title: '出勤质量',
          segments: [
            PieChartSegment(
                label: '正常', value: 18, color: Colors.green),
            PieChartSegment(
                label: '迟到', value: 2, color: Colors.orange),
          ],
          total: 20,
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.byType(PieChartWidget), findsOneWidget);
      // 图例显示
      expect(find.text('正常 90%'), findsOneWidget);
      expect(find.text('迟到 10%'), findsOneWidget);
    });

    testWidgets('空数据饼图', (tester) async {
      final chart = PieChartWidget(
        data: PieChartData(
          title: '空',
          segments: [],
          total: 0,
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(PieChartWidget), findsOneWidget);
    });

    testWidgets('单段饼图', (tester) async {
      final chart = PieChartWidget(
        data: PieChartData(
          title: '全部正常',
          segments: [
            PieChartSegment(
                label: '正常', value: 22, color: Colors.green),
          ],
          total: 22,
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.text('正常 100%'), findsOneWidget);
    });

    testWidgets('多段饼图正确计算百分比', (tester) async {
      final chart = PieChartWidget(
        data: PieChartData(
          title: '测试',
          segments: [
            PieChartSegment(
                label: 'A', value: 10, color: Colors.red),
            PieChartSegment(
                label: 'B', value: 20, color: Colors.blue),
            PieChartSegment(
                label: 'C', value: 30, color: Colors.green),
          ],
          total: 60,
        ),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));

      expect(find.text('A 17%'), findsOneWidget);
      expect(find.text('B 33%'), findsOneWidget);
      expect(find.text('C 50%'), findsOneWidget);
    });

    testWidgets('自定义尺寸', (tester) async {
      final chart = PieChartWidget(
        data: PieChartData(
          title: '测试',
          segments: [
            PieChartSegment(
                label: '正常', value: 10, color: Colors.green),
          ],
          total: 10,
        ),
        size: 250,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: chart)));
      expect(find.byType(PieChartWidget), findsOneWidget);
    });
  });

  // ====================================================================
  //  ChartLegend 测试
  // ====================================================================

  group('ChartLegend', () {
    testWidgets('渲染图例', (tester) async {
      final legend = ChartLegend(
        segments: [
          PieChartSegment(
              label: '正常', value: 18, color: Colors.green),
          PieChartSegment(
              label: '迟到', value: 2, color: Colors.orange),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: legend)));

      expect(find.text('正常 90%'), findsOneWidget);
      expect(find.text('迟到 10%'), findsOneWidget);
    });

    testWidgets('空图例列表', (tester) async {
      final legend = ChartLegend(segments: []);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: legend)));
      // 空 Wrap 组件
      expect(find.byType(ChartLegend), findsOneWidget);
    });

    testWidgets('单条图例', (tester) async {
      final legend = ChartLegend(
        segments: [
          PieChartSegment(
              label: '正常', value: 22, color: Colors.green),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: legend)));

      expect(find.text('正常 100%'), findsOneWidget);
    });

    testWidgets('多条图例正确换行', (tester) async {
      final legend = ChartLegend(
        segments: List.generate(6, (i) {
          return PieChartSegment(
            label: '类型${i + 1}',
            value: (i + 1) * 10.0,
            color: Colors.primaries[i % Colors.primaries.length],
          );
        }),
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: legend)));
      expect(find.text('类型1 5%'), findsOneWidget);
      expect(find.text('类型6 29%'), findsOneWidget);
    });
  });

  // ====================================================================
  //  StatCard 测试
  // ====================================================================

  group('StatCard', () {
    testWidgets('渲染统计卡片', (tester) async {
      final card = StatCard(
        label: '出勤天数',
        value: '20',
        icon: Icons.calendar_today,
        color: Colors.blue,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

      expect(find.text('出勤天数'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('显示副标题', (tester) async {
      final card = StatCard(
        label: '准时率',
        value: '90%',
        icon: Icons.check_circle,
        color: Colors.green,
        subtitle: '较上月提升5%',
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

      expect(find.text('准时率'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('较上月提升5%'), findsOneWidget);
    });

    testWidgets('无副标题', (tester) async {
      final card = StatCard(
        label: '测试',
        value: '0',
        icon: Icons.timer,
        color: Colors.grey,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

      expect(find.text('测试'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('长标签不溢出', (tester) async {
      final card = StatCard(
        label: '这是一个很长很长的统计标签',
        value: '999',
        icon: Icons.info,
        color: Colors.blue,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
      expect(find.byType(StatCard), findsOneWidget);
    });

    testWidgets('多个 StatCard 同时渲染', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: StatCard(
                  label: '出勤',
                  value: '20',
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: '准时',
                  value: '90%',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ));

      expect(find.text('出勤'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('准时'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
    });
  });
}
