/// 打卡数据分析模型
///
/// 包含数据分析结果的各类数据模型：
/// - [DailyAnalysis] 每日分析
/// - [MonthlySummary] 月度汇总
/// - [OvertimeAnalysis] 加班分析
/// - [AnomalyDetection] 异常检测

import 'package:flutter/material.dart';
import 'punch_record.dart';
import 'dart:math';

// ====================================================================
//  每日分析
// ====================================================================

/// 单日打卡分析结果
class DailyAnalysis {
  final String date;
  final DateTime? punchInTime;
  final DateTime? punchOutTime;
  final int workDurationMinutes;
  final bool isLate;
  final bool isEarlyLeave;
  final int overtimeMinutes;
  final String? punchInType;
  final String? punchOutType;

  DailyAnalysis({
    required this.date,
    this.punchInTime,
    this.punchOutTime,
    this.workDurationMinutes = 0,
    this.isLate = false,
    this.isEarlyLeave = false,
    this.overtimeMinutes = 0,
    this.punchInType,
    this.punchOutType,
  });

  /// 是否同时有上下班打卡
  bool get isComplete => punchInTime != null && punchOutTime != null;

  /// 是否缺卡（无任何打卡记录）
  bool get isMissing => punchInTime == null && punchOutTime == null;

  /// 格式化工作时长
  String get formattedWorkDuration {
    if (workDurationMinutes <= 0) return '--';
    return '${workDurationMinutes ~/ 60}h${workDurationMinutes % 60}m';
  }

  /// 从 PunchRecord 构造
  factory DailyAnalysis.fromRecord(PunchRecord record) {
    DateTime? parseTime(String? iso) {
      if (iso == null) return null;
      return DateTime.tryParse(iso);
    }

    return DailyAnalysis(
      date: record.date,
      punchInTime: parseTime(record.punchInTime),
      punchOutTime: parseTime(record.punchOutTime),
      workDurationMinutes: record.workDurationMinutes,
      isLate: record.isLate == 1,
      isEarlyLeave: record.isEarlyLeave == 1,
      overtimeMinutes: record.overtimeMinutes,
      punchInType: record.punchInType,
      punchOutType: record.punchOutType,
    );
  }
}

// ====================================================================
//  加班类型
// ====================================================================

/// 加班类型
enum OvertimeType {
  /// 工作日加班
  weekday,

  /// 周末加班
  weekend,

  /// 节假日加班
  holiday,

  /// 异常加班（单日 > 12h）
  excessive,
}

// ====================================================================
//  月度汇总
// ====================================================================

/// 月度打卡统计汇总
class MonthlySummary {
  final int year;
  final int month;
  final int totalWorkDays;
  final int attendedDays;
  final int onTimeDays;
  final int lateDays;
  final int earlyLeaveDays;
  final int totalWorkMinutes;
  final int totalOvertimeMinutes;
  final List<DailyAnalysis> dailyRecords;

  MonthlySummary({
    required this.year,
    required this.month,
    this.totalWorkDays = 0,
    this.attendedDays = 0,
    this.onTimeDays = 0,
    this.lateDays = 0,
    this.earlyLeaveDays = 0,
    this.totalWorkMinutes = 0,
    this.totalOvertimeMinutes = 0,
    this.dailyRecords = const [],
  });

  /// 平均工作时长（分钟）
  int get avgWorkMinutes =>
      attendedDays > 0 ? totalWorkMinutes ~/ attendedDays : 0;

  /// 出勤率
  double get attendanceRate =>
      totalWorkDays > 0 ? attendedDays / totalWorkDays : 0;

  /// 准时率
  double get punctualityRate =>
      attendedDays > 0 ? onTimeDays / attendedDays : 0;

  /// 完整打卡天数（同时有上下班）
  int get fullDays =>
      dailyRecords.where((d) => d.isComplete).length;

  /// 缺卡天数
  int get missingDays =>
      dailyRecords.where((d) => d.isMissing).length;

  /// 格式化平均工作时长
  String get formattedAvgWorkDuration {
    final m = avgWorkMinutes;
    if (m <= 0) return '--';
    return '${m ~/ 60}h${m % 60}m';
  }

  /// 格式化总加班时长
  String get formattedOvertime {
    final m = totalOvertimeMinutes;
    if (m <= 0) return '0';
    return '${m ~/ 60}h${m % 60}m';
  }

  /// 月名称
  String get monthName {
    const names = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ];
    return names[month - 1];
  }
}

// ====================================================================
//  加班分析
// ====================================================================

/// 加班分析结果
class OvertimeAnalysis {
  final int year;
  final int month;
  final int totalOvertimeMinutes;
  final int weekdayOvertimeMinutes;
  final int weekendOvertimeMinutes;
  final int holidayOvertimeMinutes;
  final int overtimeDaysCount;
  final int maxOvertimeMinutes;
  final String? maxOvertimeDate;
  final List<OvertimeDay> overtimeDays;

  OvertimeAnalysis({
    required this.year,
    required this.month,
    this.totalOvertimeMinutes = 0,
    this.weekdayOvertimeMinutes = 0,
    this.weekendOvertimeMinutes = 0,
    this.holidayOvertimeMinutes = 0,
    this.overtimeDaysCount = 0,
    this.maxOvertimeMinutes = 0,
    this.maxOvertimeDate,
    this.overtimeDays = const [],
  });

  /// 加班频率（加班天数 / 出勤天数）
  double overtimeRate(int attendedDays) =>
      attendedDays > 0 ? overtimeDaysCount / attendedDays : 0;

  /// 格式化总加班时长
  String get formattedTotal {
    final m = totalOvertimeMinutes;
    return '${m ~/ 60}h${m % 60}m';
  }

  /// 工作日加班占比
  double get weekdayRatio =>
      totalOvertimeMinutes > 0
          ? weekdayOvertimeMinutes / totalOvertimeMinutes
          : 0;
}

/// 某一天的加班记录
class OvertimeDay {
  final String date;
  final int overtimeMinutes;
  final OvertimeType type;
  final int weekday;

  OvertimeDay({
    required this.date,
    required this.overtimeMinutes,
    required this.type,
    required this.weekday,
  });

  String get formattedDuration {
    final m = overtimeMinutes;
    return '${m ~/ 60}h${m % 60}m';
  }
}

// ====================================================================
//  异常检测
// ====================================================================

/// 异常检测结果
class AnomalyDetection {
  final List<String> consecutiveLateDates;
  final List<String> excessiveOvertimeDates;
  final List<String> missingPunchDates;
  final List<String> earlyLeaveDates;
  final int consecutiveLateStreak;

  AnomalyDetection({
    this.consecutiveLateDates = const [],
    this.excessiveOvertimeDates = const [],
    this.missingPunchDates = const [],
    this.earlyLeaveDates = const [],
    this.consecutiveLateStreak = 0,
  });

  /// 是否有异常
  bool get hasAnomalies =>
      consecutiveLateDates.isNotEmpty ||
      excessiveOvertimeDates.isNotEmpty ||
      missingPunchDates.isNotEmpty ||
      earlyLeaveDates.isNotEmpty;

  /// 异常总数
  int get totalAnomalies =>
      consecutiveLateDates.length +
      excessiveOvertimeDates.length +
      missingPunchDates.length +
      earlyLeaveDates.length;
}

// ====================================================================
//  图表数据模型
// ====================================================================

/// 柱状图数据
class BarChartData {
  final List<String> labels;
  final List<double> values;
  final String title;
  final String unit;
  final Color barColor;

  BarChartData({
    required this.labels,
    required this.values,
    required this.title,
    this.unit = '',
    this.barColor = Colors.blue,
  });

  double get maxValue => values.isEmpty ? 1 : values.reduce(max);
  double get minValue => values.isEmpty ? 0 : values.reduce(min);
}

/// 饼图数据
class PieChartSegment {
  final String label;
  final double value;
  final Color color;

  PieChartSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  double get percentage => 0.0; // 由 service 计算
}

class PieChartData {
  final String title;
  final List<PieChartSegment> segments;
  final double total;

  PieChartData({
    required this.title,
    required this.segments,
    required this.total,
  });
}

/// 折线图数据
class LineChartData {
  final List<String> labels;
  final List<double> values;
  final String title;
  final String unit;

  LineChartData({
    required this.labels,
    required this.values,
    required this.title,
    this.unit = '',
  });

  double get maxValue => values.isEmpty ? 1 : values.reduce(max);
  double get minValue => values.isEmpty ? 0 : values.reduce(min);
}

// ====================================================================
//  时间段分析（自定义日期范围）
// ====================================================================

/// 自定义日期范围的打卡统计汇总
class PeriodSummary {
  final String startDate;
  final String endDate;
  final int totalDays;
  final int attendedDays;
  final int onTimeDays;
  final int lateDays;
  final int earlyLeaveDays;
  final int totalWorkMinutes;
  final int totalOvertimeMinutes;
  final List<DailyAnalysis> dailyRecords;

  PeriodSummary({
    required this.startDate,
    required this.endDate,
    this.totalDays = 0,
    this.attendedDays = 0,
    this.onTimeDays = 0,
    this.lateDays = 0,
    this.earlyLeaveDays = 0,
    this.totalWorkMinutes = 0,
    this.totalOvertimeMinutes = 0,
    this.dailyRecords = const [],
  });

  /// 平均工作时长（分钟）
  int get avgWorkMinutes =>
      attendedDays > 0 ? totalWorkMinutes ~/ attendedDays : 0;

  /// 出勤率
  double get attendanceRate =>
      totalDays > 0 ? attendedDays / totalDays : 0;

  /// 准时率
  double get punctualityRate =>
      attendedDays > 0 ? onTimeDays / attendedDays : 0;

  /// 完整打卡天数
  int get fullDays =>
      dailyRecords.where((d) => d.isComplete).length;

  /// 缺卡天数
  int get missingDays =>
      dailyRecords.where((d) => d.isMissing).length;

  /// 格式化平均工作时长
  String get formattedAvgWorkDuration {
    final m = avgWorkMinutes;
    if (m <= 0) return '--';
    return '${m ~/ 60}h${m % 60}m';
  }

  /// 格式化总加班时长
  String get formattedOvertime {
    final m = totalOvertimeMinutes;
    if (m <= 0) return '0';
    return '${m ~/ 60}h${m % 60}m';
  }

  /// 周期标签
  String get periodLabel => '$startDate ~ $endDate';
}

/// 热力图数据（星期 × 小时）
class HeatmapData {
  final String title;
  final List<HeatmapCell> cells;

  HeatmapData({
    required this.title,
    required this.cells,
  });
}

class HeatmapCell {
  final int weekday; // 1(周一)~7(周日)
  final int hour; // 0~23
  final int count;

  HeatmapCell({
    required this.weekday,
    required this.hour,
    required this.count,
  });
}
