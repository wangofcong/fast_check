/// Phase 10 — 图表数据聚合服务测试
///
/// 测试范围：
/// - 每日工作时长柱状图
/// - 月平均工作时长柱状图
/// - 上班/下班时间趋势折线图
/// - 月度加班时长趋势折线图
/// - 出勤质量饼图
/// - 加班类型饼图
/// - 打卡热力图
///
/// 所有测试使用纯数据模型，无需数据库

import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/models/punch_analysis.dart';
import 'package:fast_check/services/chart_data_service.dart';

void main() {
  late ChartDataService service;

  setUp(() {
    service = ChartDataService();
  });

  // ====================================================================
  //  辅助方法：创建测试数据
  // ====================================================================

  MonthlySummary _createSummary({
    int year = 2026,
    int month = 6,
    List<DailyAnalysis>? records,
  }) {
    final dailyRecords = records ?? [];
    int attended = 0, onTime = 0, late = 0, earlyLeave = 0;
    int totalMins = 0, overtimeMins = 0;

    for (final d in dailyRecords) {
      if (!d.isMissing) attended++;
      if (!d.isLate && d.punchInTime != null) onTime++;
      if (d.isLate) late++;
      if (d.isEarlyLeave) earlyLeave++;
      totalMins += d.workDurationMinutes;
      overtimeMins += d.overtimeMinutes;
    }

    return MonthlySummary(
      year: year,
      month: month,
      totalWorkDays: 22,
      attendedDays: attended,
      onTimeDays: onTime,
      lateDays: late,
      earlyLeaveDays: earlyLeave,
      totalWorkMinutes: totalMins,
      totalOvertimeMinutes: overtimeMins,
      dailyRecords: dailyRecords,
    );
  }

  OvertimeAnalysis _createOvertime({
    int total = 0,
    int weekday = 0,
    int weekend = 0,
    int holiday = 0,
  }) {
    return OvertimeAnalysis(
      year: 2026,
      month: 6,
      totalOvertimeMinutes: total,
      weekdayOvertimeMinutes: weekday,
      weekendOvertimeMinutes: weekend,
      holidayOvertimeMinutes: holiday,
      overtimeDaysCount: total > 0 ? 5 : 0,
      maxOvertimeMinutes: total > 0 ? 180 : 0,
      maxOvertimeDate: total > 0 ? '2026-06-10' : null,
    );
  }

  DailyAnalysis _daily({
    required String date,
    double workHours = 8,
    bool late = false,
    bool earlyLeave = false,
    double overtimeHours = 0,
    int punchInHour = 9,
    int punchInMinute = 0,
    int punchOutHour = 18,
    int punchOutMinute = 0,
    bool hasPunchIn = true,
    bool hasPunchOut = true,
  }) {
    return DailyAnalysis(
      date: date,
      punchInTime: hasPunchIn
          ? DateTime(2026, 6, int.parse(date.split('-').last), punchInHour,
              punchInMinute)
          : null,
      punchOutTime: hasPunchOut
          ? DateTime(2026, 6, int.parse(date.split('-').last), punchOutHour,
              punchOutMinute)
          : null,
      workDurationMinutes: (workHours * 60).round(),
      isLate: late,
      isEarlyLeave: earlyLeave,
      overtimeMinutes: (overtimeHours * 60).round(),
    );
  }

  // ====================================================================
  //  柱状图测试
  // ====================================================================

  group('dailyWorkDurationChart', () {
    test('生成每日工作时长柱状图', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', workHours: 8),
        _daily(date: '2026-06-02', workHours: 9.5),
        _daily(date: '2026-06-03', workHours: 7.5),
      ]);

      final chart = service.dailyWorkDurationChart(summary);

      expect(chart.title, contains('6月'));
      expect(chart.title, contains('每日工作时长'));
      expect(chart.labels, ['1', '2', '3']);
      expect(chart.values, [8.0, 9.5, 7.5]);
      expect(chart.unit, '小时');
    });

    test('不完整打卡记录不包含在图表中', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', workHours: 8, hasPunchOut: false),
        _daily(date: '2026-06-02', workHours: 9, hasPunchIn: false),
        _daily(date: '2026-06-03', workHours: 8),
      ]);

      final chart = service.dailyWorkDurationChart(summary);

      // 只有完整记录（同时有上下班）才在图表中
      expect(chart.values.length, 1);
      expect(chart.values.first, 8.0);
    });

    test('无完整记录返回空图表', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', workHours: 8, hasPunchOut: false),
      ]);

      final chart = service.dailyWorkDurationChart(summary);

      expect(chart.values, isEmpty);
      expect(chart.labels, isEmpty);
    });
  });

  group('weeklyAvgWorkDurationChart', () {
    test('生成月平均工作时长柱状图', () {
      final summaries = [
        _createSummary(year: 2026, month: 1, records: [
          _daily(date: '2026-01-01', workHours: 8),
        ]),
        _createSummary(year: 2026, month: 2, records: [
          _daily(date: '2026-02-01', workHours: 9),
        ]),
      ];

      final chart = service.weeklyAvgWorkDurationChart(summaries);

      expect(chart.labels, ['1月', '2月']);
      expect(chart.values, [8.0, 9.0]);
      expect(chart.title, '月平均工作时长趋势');
    });
  });

  // ====================================================================
  //  折线图测试
  // ====================================================================

  group('punchInTrendChart', () {
    test('生成上班时间趋势折线图', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', punchInHour: 9, punchInMinute: 0),
        _daily(date: '2026-06-02', punchInHour: 9, punchInMinute: 30),
        _daily(date: '2026-06-03', punchInHour: 8, punchInMinute: 45),
      ]);

      final chart = service.punchInTrendChart(summary);

      expect(chart.labels, ['1', '2', '3']);
      expect(chart.values, [9.0, 9.5, 8.75]);
      expect(chart.unit, '时');
    });

    test('缺卡记录不包含在趋势图中', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', punchInHour: 9, punchInMinute: 0),
        _daily(date: '2026-06-02', hasPunchIn: false),
      ]);

      final chart = service.punchInTrendChart(summary);

      expect(chart.values.length, 1);
      expect(chart.labels.first, '1');
    });
  });

  group('punchOutTrendChart', () {
    test('生成下班时间趋势折线图', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', punchOutHour: 18, punchOutMinute: 0),
        _daily(date: '2026-06-02', punchOutHour: 18, punchOutMinute: 30),
      ]);

      final chart = service.punchOutTrendChart(summary);

      expect(chart.labels, ['1', '2']);
      expect(chart.values, [18.0, 18.5]);
    });

    test('无下班记录不包含', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', hasPunchOut: false),
        _daily(date: '2026-06-02', punchOutHour: 18, punchOutMinute: 0),
      ]);

      final chart = service.punchOutTrendChart(summary);

      expect(chart.values.length, 1);
    });
  });

  group('monthlyOvertimeTrendChart', () {
    test('生成月度加班趋势折线图', () {
      final summaries = [
        _createSummary(year: 2026, month: 1, records: [
          _daily(date: '2026-01-01', overtimeHours: 2),
        ]),
        _createSummary(year: 2026, month: 2, records: [
          _daily(date: '2026-02-01', overtimeHours: 1.5),
        ]),
      ];

      final chart = service.monthlyOvertimeTrendChart(summaries);

      expect(chart.labels, ['1月', '2月']);
      expect(chart.values, [2.0, 1.5]);
      expect(chart.title, '月度加班时长趋势');
    });
  });

  // ====================================================================
  //  饼图测试
  // ====================================================================

  group('attendanceQualityPie', () {
    test('生成出勤质量饼图（含多种类型）', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', workHours: 8),
        _daily(date: '2026-06-02', workHours: 8, late: true),
        _daily(date: '2026-06-03', workHours: 8, earlyLeave: true),
        _daily(date: '2026-06-04', hasPunchIn: false, hasPunchOut: false),
      ]);

      final chart = service.attendanceQualityPie(summary);

      expect(chart.title, contains('出勤质量'));
      expect(chart.segments.length, greaterThan(0));
      expect(chart.total, greaterThan(0));

      // 找到对应 segments
      // 注意：早退记录（late=false, punchInTime!=null）也会被计入 onTime
      // 所以正常出勤 = 正常记录(06-01) + 早退记录(06-03) = 2
      final normalSeg =
          chart.segments.where((s) => s.label == '正常出勤').first;
      expect(normalSeg.value, 2);
    });

    test('过滤掉值为 0 的段', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', workHours: 8),
      ]);

      final chart = service.attendanceQualityPie(summary);

      // 只有正常出勤，其他的值为0被过滤
      expect(chart.segments.length, 1);
      expect(chart.segments.first.label, '正常出勤');
    });

    test('全缺卡时饼图只有缺卡段', () {
      final summary = _createSummary(records: [
        _daily(date: '2026-06-01', hasPunchIn: false, hasPunchOut: false),
        _daily(date: '2026-06-02', hasPunchIn: false, hasPunchOut: false),
      ]);

      final chart = service.attendanceQualityPie(summary);

      // 出勤为0，但有缺卡
      expect(chart.segments.where((s) => s.label == '缺卡').first.value, 2);
    });
  });

  group('overtimeTypePie', () {
    test('生成加班类型饼图', () {
      final analysis = _createOvertime(
        total: 1000,
        weekday: 700,
        weekend: 200,
        holiday: 100,
      );

      final chart = service.overtimeTypePie(analysis);

      expect(chart.title, '加班类型分布');
      expect(chart.segments.length, greaterThan(0));
      expect(chart.total, 1000);
    });

    test('过滤掉值为 0 的加班类型', () {
      final analysis = _createOvertime(total: 500, weekday: 500);

      final chart = service.overtimeTypePie(analysis);

      expect(chart.segments.length, 1);
      expect(chart.segments.first.label, '工作日加班');
    });

    test('全零加班返回空数据', () {
      final analysis = _createOvertime();

      final chart = service.overtimeTypePie(analysis);

      expect(chart.segments, isEmpty);
      expect(chart.total, 0);
    });
  });

  // ====================================================================
  //  热力图测试
  // ====================================================================

  group('punchHeatmap', () {
    test('生成打卡热力图', () {
      final summaries = [
        _createSummary(records: [
          _daily(
              date: '2026-06-01',
              punchInHour: 9,
              punchInMinute: 0,
              punchOutHour: 18,
              punchOutMinute: 0),
          _daily(
              date: '2026-06-02',
              punchInHour: 9,
              punchInMinute: 30,
              punchOutHour: 18,
              punchOutMinute: 30),
        ]),
      ];

      final heatmap = service.punchHeatmap(summaries);

      expect(heatmap.title, '打卡时间分布热力图');
      expect(heatmap.cells, isNotEmpty);
    });

    test('空数据返回空热力图', () {
      final heatmap = service.punchHeatmap([]);

      expect(heatmap.cells, isEmpty);
    });

    test('统计打卡次数正确', () {
      final summaries = [
        _createSummary(records: [
          _daily(
              date: '2026-06-01', // 周一 weekday=1
              punchInHour: 9,
              punchInMinute: 0,
              punchOutHour: 18,
              punchOutMinute: 0),
        ]),
      ];

      final heatmap = service.punchHeatmap(summaries);

      // 应该有两条记录：周一9点和周一18点
      expect(heatmap.cells.length, 2);
    });
  });
}
