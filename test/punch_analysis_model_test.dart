/// Phase 10 — 打卡数据分析模型测试
///
/// 测试范围：
/// - DailyAnalysis 模型
/// - MonthlySummary 模型
/// - OvertimeAnalysis / OvertimeDay 模型
/// - AnomalyDetection 模型
/// - 图表数据模型 (BarChartData, LineChartData, PieChartData, HeatmapData)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fast_check/models/punch_record.dart';
import 'package:fast_check/models/punch_analysis.dart';

void main() {
  // ====================================================================
  //  DailyAnalysis 模型测试
  // ====================================================================

  group('DailyAnalysis', () {
    test('默认值正确', () {
      final analysis = DailyAnalysis(date: '2026-06-01');
      expect(analysis.date, '2026-06-01');
      expect(analysis.punchInTime, isNull);
      expect(analysis.punchOutTime, isNull);
      expect(analysis.workDurationMinutes, 0);
      expect(analysis.isLate, false);
      expect(analysis.isEarlyLeave, false);
      expect(analysis.overtimeMinutes, 0);
      expect(analysis.punchInType, isNull);
      expect(analysis.punchOutType, isNull);
    });

    test('isComplete 同时有上下班打卡时返回 true', () {
      final analysis = DailyAnalysis(
        date: '2026-06-01',
        punchInTime: DateTime(2026, 6, 1, 9, 0),
        punchOutTime: DateTime(2026, 6, 1, 18, 0),
      );
      expect(analysis.isComplete, isTrue);
    });

    test('isComplete 只有上班打卡时返回 false', () {
      final analysis = DailyAnalysis(
        date: '2026-06-01',
        punchInTime: DateTime(2026, 6, 1, 9, 0),
      );
      expect(analysis.isComplete, isFalse);
    });

    test('isComplete 无打卡时返回 false', () {
      final analysis = DailyAnalysis(date: '2026-06-01');
      expect(analysis.isComplete, isFalse);
    });

    test('isMissing 无打卡时返回 true', () {
      final analysis = DailyAnalysis(date: '2026-06-01');
      expect(analysis.isMissing, isTrue);
    });

    test('isMissing 有上班打卡时返回 false', () {
      final analysis = DailyAnalysis(
        date: '2026-06-01',
        punchInTime: DateTime(2026, 6, 1, 9, 0),
      );
      expect(analysis.isMissing, isFalse);
    });

    test('formattedWorkDuration 正确格式化', () {
      final analysis = DailyAnalysis(
        date: '2026-06-01',
        workDurationMinutes: 540,
      );
      expect(analysis.formattedWorkDuration, '9h0m');
    });

    test('formattedWorkDuration 0 分钟返回 --', () {
      final analysis = DailyAnalysis(date: '2026-06-01');
      expect(analysis.formattedWorkDuration, '--');
    });

    test('formattedWorkDuration 负值返回 --', () {
      final analysis = DailyAnalysis(
        date: '2026-06-01',
        workDurationMinutes: -1,
      );
      expect(analysis.formattedWorkDuration, '--');
    });

    test('formattedWorkDuration 正确显示小时和分钟', () {
      final analysis = DailyAnalysis(
        date: '2026-06-01',
        workDurationMinutes: 485, // 8h5m
      );
      expect(analysis.formattedWorkDuration, '8h5m');
    });

    test('fromRecord 正确构造（完整记录）', () {
      final record = PunchRecord(
        id: 1,
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
        punchInType: 'manual',
        punchOutType: 'manual',
        isLate: 0,
        isEarlyLeave: 0,
        overtimeMinutes: 60,
        workDurationMinutes: 540,
      );

      final analysis = DailyAnalysis.fromRecord(record);
      expect(analysis.date, '2026-06-01');
      expect(analysis.punchInTime, DateTime(2026, 6, 1, 9, 0));
      expect(analysis.punchOutTime, DateTime(2026, 6, 1, 18, 0));
      expect(analysis.workDurationMinutes, 540);
      expect(analysis.isLate, false);
      expect(analysis.isEarlyLeave, false);
      expect(analysis.overtimeMinutes, 60);
      expect(analysis.punchInType, 'manual');
      expect(analysis.punchOutType, 'manual');
    });

    test('fromRecord 正确构造（迟到早退记录）', () {
      final record = PunchRecord(
        id: 2,
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:30:00',
        punchOutTime: '2026-06-02 17:00:00',
        isLate: 1,
        isEarlyLeave: 1,
        workDurationMinutes: 450,
      );

      final analysis = DailyAnalysis.fromRecord(record);
      expect(analysis.isLate, isTrue);
      expect(analysis.isEarlyLeave, isTrue);
    });

    test('fromRecord 处理空打卡时间', () {
      final record = PunchRecord(
        id: 3,
        date: '2026-06-03',
        isLate: 0,
        isEarlyLeave: 0,
      );

      final analysis = DailyAnalysis.fromRecord(record);
      expect(analysis.punchInTime, isNull);
      expect(analysis.punchOutTime, isNull);
      expect(analysis.isMissing, isTrue);
    });

    test('fromRecord 解析无效时间字符串返回 null', () {
      final record = PunchRecord(
        id: 4,
        date: '2026-06-04',
        punchInTime: 'invalid-time',
      );

      final analysis = DailyAnalysis.fromRecord(record);
      expect(analysis.punchInTime, isNull);
    });
  });

  // ====================================================================
  //  OvertimeType 枚举测试
  // ====================================================================

  group('OvertimeType', () {
    test('枚举值定义正确', () {
      expect(OvertimeType.values.length, 4);
      expect(OvertimeType.values, contains(OvertimeType.weekday));
      expect(OvertimeType.values, contains(OvertimeType.weekend));
      expect(OvertimeType.values, contains(OvertimeType.holiday));
      expect(OvertimeType.values, contains(OvertimeType.excessive));
    });

    test('枚举值名称正确', () {
      expect(OvertimeType.weekday.name, 'weekday');
      expect(OvertimeType.weekend.name, 'weekend');
      expect(OvertimeType.holiday.name, 'holiday');
      expect(OvertimeType.excessive.name, 'excessive');
    });
  });

  // ====================================================================
  //  MonthlySummary 模型测试
  // ====================================================================

  group('MonthlySummary', () {
    test('默认值正确', () {
      final summary = MonthlySummary(year: 2026, month: 6);
      expect(summary.year, 2026);
      expect(summary.month, 6);
      expect(summary.totalWorkDays, 0);
      expect(summary.attendedDays, 0);
      expect(summary.onTimeDays, 0);
      expect(summary.lateDays, 0);
      expect(summary.earlyLeaveDays, 0);
      expect(summary.totalWorkMinutes, 0);
      expect(summary.totalOvertimeMinutes, 0);
      expect(summary.dailyRecords, isEmpty);
    });

    test('avgWorkMinutes 计算正确', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        attendedDays: 20,
        totalWorkMinutes: 10800, // 180h
      );
      expect(summary.avgWorkMinutes, 540); // 9h
    });

    test('avgWorkMinutes 无出勤日返回 0', () {
      final summary = MonthlySummary(year: 2026, month: 6);
      expect(summary.avgWorkMinutes, 0);
    });

    test('attendanceRate 计算正确', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        totalWorkDays: 22,
        attendedDays: 20,
      );
      expect(summary.attendanceRate, 20 / 22);
    });

    test('attendanceRate 无工作日返回 0', () {
      final summary = MonthlySummary(year: 2026, month: 6);
      expect(summary.attendanceRate, 0);
    });

    test('punctualityRate 计算正确', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        attendedDays: 20,
        onTimeDays: 18,
      );
      expect(summary.punctualityRate, 18 / 20);
    });

    test('punctualityRate 无出勤日返回 0', () {
      final summary = MonthlySummary(year: 2026, month: 6);
      expect(summary.punctualityRate, 0);
    });

    test('fullDays 统计完整打卡天数', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        dailyRecords: [
          DailyAnalysis(
            date: '2026-06-01',
            punchInTime: DateTime(2026, 6, 1, 9, 0),
            punchOutTime: DateTime(2026, 6, 1, 18, 0),
          ),
          DailyAnalysis(
            date: '2026-06-02',
            punchInTime: DateTime(2026, 6, 2, 9, 0),
            // 无下班打卡
          ),
          DailyAnalysis(date: '2026-06-03'), // 无打卡
        ],
      );
      expect(summary.fullDays, 1);
    });

    test('missingDays 统计缺卡天数', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        dailyRecords: [
          DailyAnalysis(
            date: '2026-06-01',
            punchInTime: DateTime(2026, 6, 1, 9, 0),
          ),
          DailyAnalysis(date: '2026-06-02'), // 缺卡
          DailyAnalysis(date: '2026-06-03'), // 缺卡
        ],
      );
      expect(summary.missingDays, 2);
    });

    test('formattedAvgWorkDuration 格式化正确', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        attendedDays: 20,
        totalWorkMinutes: 10800,
      );
      expect(summary.formattedAvgWorkDuration, '9h0m');
    });

    test('formattedAvgWorkDuration 无数据返回 --', () {
      final summary = MonthlySummary(year: 2026, month: 6);
      expect(summary.formattedAvgWorkDuration, '--');
    });

    test('formattedOvertime 格式化正确', () {
      final summary = MonthlySummary(
        year: 2026,
        month: 6,
        totalOvertimeMinutes: 1200, // 20h
      );
      expect(summary.formattedOvertime, '20h0m');
    });

    test('formattedOvertime 无加班返回 0', () {
      final summary = MonthlySummary(year: 2026, month: 6);
      expect(summary.formattedOvertime, '0');
    });

    test('monthName 返回正确月份名称', () {
      expect(MonthlySummary(year: 2026, month: 1).monthName, '1月');
      expect(MonthlySummary(year: 2026, month: 6).monthName, '6月');
      expect(MonthlySummary(year: 2026, month: 12).monthName, '12月');
    });
  });

  // ====================================================================
  //  OvertimeDay 模型测试
  // ====================================================================

  group('OvertimeDay', () {
    test('默认构造正确', () {
      final day = OvertimeDay(
        date: '2026-06-05',
        overtimeMinutes: 120,
        type: OvertimeType.weekday,
        weekday: 5,
      );
      expect(day.date, '2026-06-05');
      expect(day.overtimeMinutes, 120);
      expect(day.type, OvertimeType.weekday);
      expect(day.weekday, 5);
    });

    test('formattedDuration 正确格式化', () {
      final day = OvertimeDay(
        date: '2026-06-05',
        overtimeMinutes: 150,
        type: OvertimeType.weekday,
        weekday: 5,
      );
      expect(day.formattedDuration, '2h30m');
    });

    test('formattedDuration 不足一小时', () {
      final day = OvertimeDay(
        date: '2026-06-05',
        overtimeMinutes: 45,
        type: OvertimeType.weekday,
        weekday: 5,
      );
      expect(day.formattedDuration, '0h45m');
    });
  });

  // ====================================================================
  //  OvertimeAnalysis 模型测试
  // ====================================================================

  group('OvertimeAnalysis', () {
    test('默认值正确', () {
      final analysis = OvertimeAnalysis(year: 2026, month: 6);
      expect(analysis.year, 2026);
      expect(analysis.month, 6);
      expect(analysis.totalOvertimeMinutes, 0);
      expect(analysis.weekdayOvertimeMinutes, 0);
      expect(analysis.weekendOvertimeMinutes, 0);
      expect(analysis.holidayOvertimeMinutes, 0);
      expect(analysis.overtimeDaysCount, 0);
      expect(analysis.maxOvertimeMinutes, 0);
      expect(analysis.maxOvertimeDate, isNull);
      expect(analysis.overtimeDays, isEmpty);
    });

    test('overtimeRate 计算正确', () {
      final analysis = OvertimeAnalysis(
        year: 2026,
        month: 6,
        overtimeDaysCount: 10,
      );
      expect(analysis.overtimeRate(20), 10 / 20);
    });

    test('overtimeRate 无出勤日返回 0', () {
      final analysis = OvertimeAnalysis(year: 2026, month: 6);
      expect(analysis.overtimeRate(0), 0);
    });

    test('formattedTotal 格式化正确', () {
      final analysis = OvertimeAnalysis(
        year: 2026,
        month: 6,
        totalOvertimeMinutes: 150,
      );
      expect(analysis.formattedTotal, '2h30m');
    });

    test('weekdayRatio 计算正确', () {
      final analysis = OvertimeAnalysis(
        year: 2026,
        month: 6,
        totalOvertimeMinutes: 1000,
        weekdayOvertimeMinutes: 700,
      );
      expect(analysis.weekdayRatio, 0.7);
    });

    test('weekdayRatio 无加班返回 0', () {
      final analysis = OvertimeAnalysis(year: 2026, month: 6);
      expect(analysis.weekdayRatio, 0);
    });

    test('overtimeDays 列表包含数据', () {
      final analysis = OvertimeAnalysis(
        year: 2026,
        month: 6,
        maxOvertimeMinutes: 180,
        maxOvertimeDate: '2026-06-10',
        overtimeDays: [
          OvertimeDay(
            date: '2026-06-10',
            overtimeMinutes: 180,
            type: OvertimeType.weekday,
            weekday: 3,
          ),
        ],
      );
      expect(analysis.overtimeDays.length, 1);
      expect(analysis.maxOvertimeDate, '2026-06-10');
      expect(analysis.maxOvertimeMinutes, 180);
    });
  });

  // ====================================================================
  //  AnomalyDetection 模型测试
  // ====================================================================

  group('AnomalyDetection', () {
    test('默认值无异常', () {
      final detection = AnomalyDetection();
      expect(detection.hasAnomalies, isFalse);
      expect(detection.totalAnomalies, 0);
      expect(detection.consecutiveLateStreak, 0);
      expect(detection.consecutiveLateDates, isEmpty);
      expect(detection.excessiveOvertimeDates, isEmpty);
      expect(detection.missingPunchDates, isEmpty);
      expect(detection.earlyLeaveDates, isEmpty);
    });

    test('hasAnomalies 检测到连续迟到时返回 true', () {
      final detection = AnomalyDetection(
        consecutiveLateDates: ['2026-06-01', '2026-06-02', '2026-06-03'],
      );
      expect(detection.hasAnomalies, isTrue);
    });

    test('hasAnomalies 检测到过度加班时返回 true', () {
      final detection = AnomalyDetection(
        excessiveOvertimeDates: ['2026-06-05'],
      );
      expect(detection.hasAnomalies, isTrue);
    });

    test('hasAnomalies 检测到缺卡时返回 true', () {
      final detection = AnomalyDetection(
        missingPunchDates: ['2026-06-06'],
      );
      expect(detection.hasAnomalies, isTrue);
    });

    test('hasAnomalies 检测到早退时返回 true', () {
      final detection = AnomalyDetection(
        earlyLeaveDates: ['2026-06-07'],
      );
      expect(detection.hasAnomalies, isTrue);
    });

    test('totalAnomalies 正确统计总数', () {
      final detection = AnomalyDetection(
        consecutiveLateDates: ['2026-06-01', '2026-06-02'],
        excessiveOvertimeDates: ['2026-06-03'],
        missingPunchDates: ['2026-06-04', '2026-06-05'],
        earlyLeaveDates: ['2026-06-06'],
      );
      expect(detection.totalAnomalies, 6);
    });

    test('consecutiveLateStreak 返回连续天数', () {
      final detection = AnomalyDetection(
        consecutiveLateStreak: 5,
        consecutiveLateDates: List.generate(5, (i) => '2026-06-${i + 1}'),
      );
      expect(detection.consecutiveLateStreak, 5);
    });
  });

  // ====================================================================
  //  图表数据模型测试
  // ====================================================================

  group('BarChartData', () {
    test('默认构造正确', () {
      final chart = BarChartData(
        labels: ['01', '02', '03'],
        values: [8.0, 9.0, 7.5],
        title: '测试柱状图',
        unit: '小时',
      );
      expect(chart.labels, ['01', '02', '03']);
      expect(chart.values, [8.0, 9.0, 7.5]);
      expect(chart.title, '测试柱状图');
      expect(chart.unit, '小时');
      expect(chart.barColor, Colors.blue);
    });

    test('maxValue 返回最大值', () {
      final chart = BarChartData(
        labels: ['01', '02', '03'],
        values: [8.0, 9.0, 7.5],
        title: '测试',
      );
      expect(chart.maxValue, 9.0);
    });

    test('maxValue 空列表返回 1', () {
      final chart = BarChartData(
        labels: [],
        values: [],
        title: '测试',
      );
      expect(chart.maxValue, 1);
    });

    test('minValue 返回最小值', () {
      final chart = BarChartData(
        labels: ['01', '02', '03'],
        values: [8.0, 9.0, 7.5],
        title: '测试',
      );
      expect(chart.minValue, 7.5);
    });

    test('minValue 空列表返回 0', () {
      final chart = BarChartData(
        labels: [],
        values: [],
        title: '测试',
      );
      expect(chart.minValue, 0);
    });

    test('自定义颜色', () {
      final chart = BarChartData(
        labels: ['01'],
        values: [5.0],
        title: '测试',
        barColor: Colors.teal,
      );
      expect(chart.barColor, Colors.teal);
    });
  });

  group('PieChartSegment', () {
    test('默认构造正确', () {
      final segment = PieChartSegment(
        label: '正常',
        value: 18,
        color: Colors.green,
      );
      expect(segment.label, '正常');
      expect(segment.value, 18);
      expect(segment.color, Colors.green);
    });

    test('percentage 默认返回 0', () {
      final segment = PieChartSegment(
        label: '测试',
        value: 10,
        color: Colors.blue,
      );
      expect(segment.percentage, 0.0);
    });
  });

  group('PieChartData', () {
    test('默认构造正确', () {
      final data = PieChartData(
        title: '出勤质量',
        segments: [
          PieChartSegment(label: '正常', value: 18, color: Colors.green),
          PieChartSegment(label: '迟到', value: 2, color: Colors.orange),
        ],
        total: 20,
      );
      expect(data.title, '出勤质量');
      expect(data.segments.length, 2);
      expect(data.total, 20);
    });

    test('空 segment 列表', () {
      final data = PieChartData(
        title: '测试',
        segments: [],
        total: 0,
      );
      expect(data.segments, isEmpty);
      expect(data.total, 0);
    });
  });

  group('LineChartData', () {
    test('默认构造正确', () {
      final data = LineChartData(
        labels: ['01', '02', '03'],
        values: [9.0, 9.5, 8.5],
        title: '上班时间趋势',
        unit: '时',
      );
      expect(data.labels, ['01', '02', '03']);
      expect(data.values, [9.0, 9.5, 8.5]);
      expect(data.title, '上班时间趋势');
      expect(data.unit, '时');
    });

    test('maxValue 返回最大值', () {
      final data = LineChartData(
        labels: ['01', '02'],
        values: [9.0, 10.5],
        title: '测试',
      );
      expect(data.maxValue, 10.5);
    });

    test('minValue 返回最小值', () {
      final data = LineChartData(
        labels: ['01', '02'],
        values: [9.0, 8.5],
        title: '测试',
      );
      expect(data.minValue, 8.5);
    });

    test('maxValue 空列表返回 1', () {
      final data = LineChartData(
        labels: [],
        values: [],
        title: '测试',
      );
      expect(data.maxValue, 1);
    });

    test('minValue 空列表返回 0', () {
      final data = LineChartData(
        labels: [],
        values: [],
        title: '测试',
      );
      expect(data.minValue, 0);
    });
  });

  group('HeatmapData / HeatmapCell', () {
    test('HeatmapData 默认构造正确', () {
      final data = HeatmapData(
        title: '打卡热力图',
        cells: [
          HeatmapCell(weekday: 1, hour: 9, count: 20),
          HeatmapCell(weekday: 5, hour: 18, count: 15),
        ],
      );
      expect(data.title, '打卡热力图');
      expect(data.cells.length, 2);
    });

    test('HeatmapCell 构造正确', () {
      final cell = HeatmapCell(weekday: 3, hour: 12, count: 5);
      expect(cell.weekday, 3);
      expect(cell.hour, 12);
      expect(cell.count, 5);
    });

    test('HeatmapCell 边界值', () {
      final cell1 = HeatmapCell(weekday: 1, hour: 0, count: 0);
      expect(cell1.weekday, 1);
      expect(cell1.hour, 0);
      expect(cell1.count, 0);

      final cell2 = HeatmapCell(weekday: 7, hour: 23, count: 100);
      expect(cell2.weekday, 7);
      expect(cell2.hour, 23);
      expect(cell2.count, 100);
    });

    test('HeatmapData 空列表', () {
      final data = HeatmapData(title: '空', cells: []);
      expect(data.cells, isEmpty);
    });
  });
}
