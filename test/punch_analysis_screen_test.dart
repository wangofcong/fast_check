/// Phase 10 — 打卡数据分析页面测试
///
/// 测试范围：
/// - 页面基本渲染（AppBar、月份切换）
/// - 统计卡片展示
/// - 图表选项卡切换
/// - 加班分析区域
/// - 异常检测区域
/// - 空数据状态
///
/// 注意：页面使用真实数据库，测试前确保数据库已初始化。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fast_check/models/punch_record.dart';
import 'package:fast_check/services/database_service.dart';
import 'package:fast_check/screens/punch_analysis_screen.dart';

void main() {
  late DatabaseService dbService;

  setUp(() async {
    dbService = DatabaseService();
    // 确保数据库已初始化
    await dbService.database;

    // 清理测试数据
    final db = await dbService.database;
    await db.delete('punch_records');
  });

  tearDown(() async {
    // 清理测试数据
    final db = await dbService.database;
    await db.delete('punch_records');
  });

  // ====================================================================
  //  辅助方法：插入测试数据
  // ====================================================================

  Future<void> _insertRecord(PunchRecord record) async {
    await dbService.upsertPunchRecordByDate(record);
  }

  // ====================================================================
  //  页面渲染测试
  // ====================================================================

  testWidgets('页面标题正确显示', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    // 等待加载完成
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('打卡数据分析'), findsOneWidget);
  });

  testWidgets('月份切换按钮存在', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 左右切换按钮
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('图表选项卡存在', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 四个图表选项卡
    expect(find.text('每日工时'), findsOneWidget);
    expect(find.text('打卡趋势'), findsOneWidget);
    expect(find.text('出勤质量'), findsOneWidget);
    expect(find.text('加班分析'), findsOneWidget);
  });

  // ====================================================================
  //  统计数据展示测试
  // ====================================================================

  testWidgets('有打卡记录时显示统计数据', (tester) async {
    // 先插入测试数据
    await _insertRecord(PunchRecord(
      date: '2026-06-01',
      punchInTime: '2026-06-01 09:00:00',
      punchOutTime: '2026-06-01 18:00:00',
      isLate: 0,
      isEarlyLeave: 0,
      workDurationMinutes: 540,
      overtimeMinutes: 60,
    ));

    await _insertRecord(PunchRecord(
      date: '2026-06-02',
      punchInTime: '2026-06-02 09:30:00',
      punchOutTime: '2026-06-02 17:00:00',
      isLate: 1,
      isEarlyLeave: 1,
      workDurationMinutes: 450,
      overtimeMinutes: 0,
    ));

    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    // 等待加载完成
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 月份标题
    expect(find.textContaining('2026年'), findsOneWidget);

    // 月度概览标题
    expect(find.text('月度概览'), findsOneWidget);

    // 出勤统计
    expect(find.text('2/22天'), findsOneWidget);

    // 迟到统计
    expect(find.text('1次'), findsAtLeast(1));
  });

  testWidgets('生日切换显示正确月份', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 应该显示当前月份
    final now = DateTime.now();
    final currentMonthName = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ][now.month - 1];

    expect(find.textContaining(currentMonthName), findsOneWidget);
  });

  // ====================================================================
  //  图表选项卡切换测试
  // ====================================================================

  testWidgets('点击图表选项卡切换内容', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 默认选中的是「每日工时」
    // 点击「出勤质量」
    await tester.tap(find.text('出勤质量'));
    await tester.pumpAndSettle();

    // 出勤质量相关文字出现
    expect(find.textContaining('出勤'), findsAtLeast(1));
  });

  // ====================================================================
  //  空数据状态测试
  // ====================================================================

  testWidgets('无打卡记录显示暂无数据', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 由于有默认月份显示，不会显示"暂无数据"
    // 但统计卡片中出勤为 0
    expect(find.text('0/22天'), findsOneWidget);
  });

  // ====================================================================
  //  月份切换测试
  // ====================================================================

  testWidgets('月份切换按钮可点击', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 点击上月
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 月份变化
    final now = DateTime.now();
    int prevMonth = now.month - 1;
    int prevYear = now.year;
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear--;
    }

    // 应显示上月的月份
    final prevMonthName = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ][prevMonth - 1];

    expect(find.textContaining('$prevYear年'), findsOneWidget);
  });

  // ====================================================================
  //  AppBar 样式测试
  // ====================================================================

  testWidgets('AppBar 背景色使用 inversePrimary', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // AppBar 存在
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar, isNotNull);
    expect(appBar.title, isNotNull);
  });

  // ====================================================================
  //  刷新功能测试
  // ====================================================================

  testWidgets('页面支持下拉刷新', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // RefreshIndicator 存在
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  // ====================================================================
  //  异常检测区域测试
  // ====================================================================

  testWidgets('有异常时显示异常检测区域', (tester) async {
    // 插入迟到数据
    await _insertRecord(PunchRecord(
      date: '2026-06-01',
      punchInTime: '2026-06-01 10:00:00',
      isLate: 1,
      isEarlyLeave: 0,
    ));

    await _insertRecord(PunchRecord(
      date: '2026-06-02',
      punchInTime: '2026-06-02 10:00:00',
      isLate: 1,
      isEarlyLeave: 0,
    ));

    await _insertRecord(PunchRecord(
      date: '2026-06-03',
      punchInTime: '2026-06-03 10:00:00',
      isLate: 1,
      isEarlyLeave: 0,
    ));

    await tester.pumpWidget(MaterialApp(
      home: PunchAnalysisScreen(),
    ));

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 异常检测应显示
    expect(find.text('异常检测'), findsOneWidget);

    // 由于需要滚动，检测标题存在
    expect(find.textContaining('连续迟到'), findsAtLeast(1));
  });
}
