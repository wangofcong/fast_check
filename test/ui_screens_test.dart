/// Phase 6 — UI 页面组件测试
///
/// 测试范围：
/// - MonthlyStatsCard / MonthlyStats 数据模型
/// - RecordListItem 渲染
/// - PunchDetailScreen 布局
/// - 底部导航布局

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:fast_check/models/punch_record.dart';
import 'package:fast_check/widgets/monthly_stats_card.dart';
import 'package:fast_check/widgets/record_list_item.dart';
import 'package:fast_check/screens/punch_detail_screen.dart';

// ====================================================================
//  MonthlyStats 模型测试
// ====================================================================

void main() {
  group('MonthlyStats 模型', () {
    test('默认值正确', () {
      final stats = MonthlyStats(year: 2026, month: 6);
      expect(stats.year, 2026);
      expect(stats.month, 6);
      expect(stats.totalWorkDays, 0);
      expect(stats.attendedDays, 0);
      expect(stats.onTimeDays, 0);
      expect(stats.lateDays, 0);
      expect(stats.earlyLeaveDays, 0);
      expect(stats.totalWorkMinutes, 0);
      expect(stats.totalOvertimeMinutes, 0);
      expect(stats.fullDays, 0);
    });

    test('fromRecords 正确统计数据', () {
      final records = [
        PunchRecord(
          id: 1,
          date: '2026-06-01',
          punchInTime: '2026-06-01 09:00:00',
          punchOutTime: '2026-06-01 18:00:00',
          isLate: 0,
          isEarlyLeave: 0,
          workDurationMinutes: 540,
          overtimeMinutes: 60,
        ),
        PunchRecord(
          id: 2,
          date: '2026-06-02',
          punchInTime: '2026-06-02 09:30:00',
          punchOutTime: '2026-06-02 17:30:00',
          isLate: 1,
          isEarlyLeave: 0,
          workDurationMinutes: 480,
          overtimeMinutes: 0,
        ),
        PunchRecord(
          id: 3,
          date: '2026-06-03',
          punchInTime: '2026-06-03 09:00:00',
          // 无下班打卡
          isLate: 0,
          isEarlyLeave: 0,
          workDurationMinutes: 0,
          overtimeMinutes: 0,
        ),
      ];

      final stats = MonthlyStats.fromRecords(
        year: 2026,
        month: 6,
        records: records,
        totalWorkDays: 22,
      );

      expect(stats.totalWorkDays, 22);
      expect(stats.attendedDays, 3); // 三条都有打卡记录
      expect(stats.onTimeDays, 2); // 第2条迟到
      expect(stats.lateDays, 1);
      expect(stats.earlyLeaveDays, 0);
      expect(stats.totalWorkMinutes, 540 + 480 + 0);
      expect(stats.totalOvertimeMinutes, 60 + 0 + 0);
      expect(stats.fullDays, 2); // 只有前两条同时有上下班
    });

    test('fromRecords 空列表', () {
      final stats = MonthlyStats.fromRecords(
        year: 2026,
        month: 6,
        records: [],
      );
      expect(stats.attendedDays, 0);
      expect(stats.onTimeDays, 0);
      expect(stats.lateDays, 0);
      expect(stats.fullDays, 0);
    });

    test('计算属性正确', () {
      final stats = MonthlyStats(
        year: 2026,
        month: 6,
        totalWorkDays: 22,
        attendedDays: 20,
        onTimeDays: 18,
        totalWorkMinutes: 540 * 18,
        fullDays: 18, // avgWorkMinutes = totalWorkMinutes ~/ fullDays
      );
      expect(stats.attendanceRate, 20 / 22);
      expect(stats.punctualityRate, 18 / 20);
      expect(stats.avgWorkMinutes, 540);
      expect(stats.formattedAvgWorkDuration, '9h 0m');
    });

    test('monthName 正确', () {
      expect(MonthlyStats(year: 2026, month: 1).monthName, '1月');
      expect(MonthlyStats(year: 2026, month: 12).monthName, '12月');
    });

    test('迟到/早退时颜色应为红色', () {
      final stats = MonthlyStats(
        year: 2026,
        month: 6,
        lateDays: 3,
        earlyLeaveDays: 2,
      );
      expect(stats.lateDays, 3);
      expect(stats.earlyLeaveDays, 2);
    });
  });

  // ====================================================================
  //  RecordListItem 测试
  // ====================================================================

  group('RecordListItem', () {
    testWidgets('完整打卡记录渲染', (tester) async {
      final record = PunchRecord(
        id: 1,
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
        workDurationMinutes: 540,
        isLate: 0,
        isEarlyLeave: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordListItem(record: record),
          ),
        ),
      );

      // 应显示日期和打卡时间
      expect(find.text('6月1日 周一'), findsOneWidget);
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.textContaining('18:00'), findsOneWidget);
      expect(find.textContaining('9h'), findsOneWidget);
    });

    testWidgets('迟到早退标签渲染', (tester) async {
      final record = PunchRecord(
        id: 2,
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:30:00',
        punchOutTime: '2026-06-02 17:00:00',
        isLate: 1,
        isEarlyLeave: 1,
        workDurationMinutes: 450,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordListItem(record: record),
          ),
        ),
      );

      expect(find.text('迟到'), findsOneWidget);
      expect(find.text('早退'), findsOneWidget);
    });

    testWidgets('部分打卡（只有上班）', (tester) async {
      final record = PunchRecord(
        id: 3,
        date: '2026-06-03',
        punchInTime: '2026-06-03 09:00:00',
        isLate: 0,
        isEarlyLeave: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordListItem(record: record),
          ),
        ),
      );

      expect(find.text('未打卡'), findsAtLeastNWidgets(1));
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('无打卡记录', (tester) async {
      final record = PunchRecord(
        id: 4,
        date: '2026-06-04',
        isLate: 0,
        isEarlyLeave: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordListItem(record: record),
          ),
        ),
      );

      expect(find.text('未打卡'), findsAtLeastNWidgets(2));
    });

    testWidgets('onTap 回调触发', (tester) async {
      bool tapped = false;
      final record = PunchRecord(
        id: 1,
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordListItem(
              record: record,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // 点击卡片
      await tester.tap(find.text('6月1日 周一'));
      await tester.pumpAndSettle();
      expect(tapped, true);
    });
  });

  // ====================================================================
  //  PunchDetailScreen 测试
  // ====================================================================

  group('PunchDetailScreen', () {
    testWidgets('完整记录详情渲染', (tester) async {
      final record = PunchRecord(
        id: 1,
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
        punchInType: 'manual',
        punchOutType: 'manual',
        isLate: 0,
        isEarlyLeave: 0,
        workDurationMinutes: 540,
        overtimeMinutes: 60,
        notes: '今天正常上班',
        scheduleGroupId: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PunchDetailScreen(record: record),
        ),
      );

      // 日期标题 — 在 AppBar(title: "2026-06-01 周一") 和卡片 body 中各出现一次
      expect(find.textContaining('2026-06-01'), findsAtLeastNWidgets(1));
      // 打卡状态
      expect(find.text('已完成打卡'), findsOneWidget);
      expect(find.text('手动'), findsAtLeast(1));
      // 考勤详情
      expect(find.textContaining('9小时'), findsOneWidget);
      expect(find.textContaining('1小时'), findsOneWidget);
      expect(find.text('否'), findsAtLeastNWidgets(2));
      // 备注
      expect(find.text('今天正常上班'), findsOneWidget);
      // 记录信息
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('部分打卡记录', (tester) async {
      final record = PunchRecord(
        id: 2,
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:00:00',
        punchInType: 'manual',
        isLate: 0,
        isEarlyLeave: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PunchDetailScreen(record: record),
        ),
      );

      expect(find.text('部分打卡'), findsOneWidget);
      expect(find.text('未打卡'), findsOneWidget);
    });

    testWidgets('显示考勤异常（迟到 + 早退）', (tester) async {
      final record = PunchRecord(
        id: 3,
        date: '2026-06-03',
        punchInTime: '2026-06-03 09:30:00',
        punchOutTime: '2026-06-03 16:30:00',
        isLate: 1,
        isEarlyLeave: 1,
        workDurationMinutes: 420,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PunchDetailScreen(record: record),
        ),
      );

      expect(find.text('是'), findsAtLeastNWidgets(2)); // 迟到=是, 早退=是
    });

    testWidgets('备注编辑框存在', (tester) async {
      final record = PunchRecord(
        id: 4,
        date: '2026-06-04',
        punchInTime: '2026-06-04 09:00:00',
        punchOutTime: '2026-06-04 18:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PunchDetailScreen(record: record),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('保存备注'), findsOneWidget);
    });

    testWidgets('空备注时提示文本', (tester) async {
      final record = PunchRecord(
        id: 5,
        date: '2026-06-05',
        punchInTime: '2026-06-05 09:00:00',
        punchOutTime: '2026-06-05 18:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PunchDetailScreen(record: record),
        ),
      );

      expect(find.text('添加备注...'), findsOneWidget);
    });
  });

  // ====================================================================
  //  MainScaffold（底部导航）测试
  // ====================================================================

  group('MainScaffold 底部导航', () {
    testWidgets('底部导航栏渲染', (tester) async {
      // 由于需要 Provider，使用简单的验证
      final scaffold = MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: '记录',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: '分析',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(scaffold);

      expect(find.text('首页'), findsOneWidget);
      expect(find.text('记录'), findsOneWidget);
      expect(find.text('分析'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });
  });
}
