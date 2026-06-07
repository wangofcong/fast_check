/// 图表数据聚合服务
///
/// 将 [PunchAnalysisService] 的分析结果转换为图表可消费的数据结构
/// 支持：柱状图、折线图、饼图、热力图

import 'package:flutter/material.dart';
import '../models/punch_analysis.dart';

class ChartDataService {
  // ==================================================================
  //  柱状图 — 每日工作时长
  // ==================================================================

  /// 生成每日工作时长柱状图数据
  BarChartData dailyWorkDurationChart(MonthlySummary summary) {
    final records = summary.dailyRecords;
    final labels = <String>[];
    final values = <double>[];

    for (final r in records) {
      if (r.isComplete) {
        // 取日期中的日
        final day = _extractDay(r.date);
        labels.add(day);
        values.add(r.workDurationMinutes / 60.0); // 转换为小时
      }
    }

    return BarChartData(
      labels: labels,
      values: values,
      title: '${summary.year}年${summary.monthName} 每日工作时长',
      unit: '小时',
      barColor: Colors.blue,
    );
  }

  /// 每周平均工作时长柱状图
  BarChartData weeklyAvgWorkDurationChart(List<MonthlySummary> summaries) {
    final labels = <String>[];
    final values = <double>[];

    for (final s in summaries) {
      labels.add(s.monthName);
      values.add(s.avgWorkMinutes / 60.0);
    }

    return BarChartData(
      labels: labels,
      values: values,
      title: '月平均工作时长趋势',
      unit: '小时',
      barColor: Colors.teal,
    );
  }

  // ==================================================================
  //  折线图 — 上下班时间趋势
  // ==================================================================

  /// 上班时间趋势折线图（只显示上班时间的小时+分钟/60）
  LineChartData punchInTrendChart(MonthlySummary summary) {
    final labels = <String>[];
    final values = <double>[];

    for (final r in summary.dailyRecords) {
      if (r.punchInTime != null) {
        final day = _extractDay(r.date);
        labels.add(day);
        // 转换为小时小数，如 9:30 → 9.5
        values.add(r.punchInTime!.hour + r.punchInTime!.minute / 60.0);
      }
    }

    return LineChartData(
      labels: labels,
      values: values,
      title: '${summary.year}年${summary.monthName} 上班时间趋势',
      unit: '时',
    );
  }

  /// 下班时间趋势折线图
  LineChartData punchOutTrendChart(MonthlySummary summary) {
    final labels = <String>[];
    final values = <double>[];

    for (final r in summary.dailyRecords) {
      if (r.punchOutTime != null) {
        final day = _extractDay(r.date);
        labels.add(day);
        values.add(r.punchOutTime!.hour + r.punchOutTime!.minute / 60.0);
      }
    }

    return LineChartData(
      labels: labels,
      values: values,
      title: '${summary.year}年${summary.monthName} 下班时间趋势',
      unit: '时',
    );
  }

  /// 月度加班时长趋势（多个月）
  LineChartData monthlyOvertimeTrendChart(List<MonthlySummary> summaries) {
    final labels = <String>[];
    final values = <double>[];

    for (final s in summaries) {
      labels.add(s.monthName);
      values.add(s.totalOvertimeMinutes / 60.0);
    }

    return LineChartData(
      labels: labels,
      values: values,
      title: '月度加班时长趋势',
      unit: '小时',
    );
  }

  // ==================================================================
  //  饼图 — 出勤质量分布
  // ==================================================================

  /// 出勤质量饼图（正常 / 迟到 / 早退 / 缺卡 / 加班）
  PieChartData attendanceQualityPie(MonthlySummary summary) {
    final segments = <PieChartSegment>[
      PieChartSegment(
        label: '正常出勤',
        value: summary.onTimeDays.toDouble(),
        color: Colors.green,
      ),
      PieChartSegment(
        label: '迟到',
        value: summary.lateDays.toDouble(),
        color: Colors.orange,
      ),
      PieChartSegment(
        label: '早退',
        value: summary.earlyLeaveDays.toDouble(),
        color: Colors.deepOrange,
      ),
      PieChartSegment(
        label: '缺卡',
        value: summary.missingDays.toDouble(),
        color: Colors.red[300]!,
      ),
    ];

    // 过滤掉值为 0 的段
    final filtered =
        segments.where((s) => s.value > 0).toList();

    final total = filtered.fold<double>(
        0, (sum, s) => sum + s.value);

    return PieChartData(
      title: '${summary.year}年${summary.monthName} 出勤质量',
      segments: filtered,
      total: total,
    );
  }

  /// 加班类型饼图
  PieChartData overtimeTypePie(OvertimeAnalysis analysis) {
    final segments = <PieChartSegment>[
      PieChartSegment(
        label: '工作日加班',
        value: analysis.weekdayOvertimeMinutes.toDouble(),
        color: Colors.indigo,
      ),
      PieChartSegment(
        label: '周末加班',
        value: analysis.weekendOvertimeMinutes.toDouble(),
        color: Colors.purple,
      ),
      PieChartSegment(
        label: '异常加班',
        value: (analysis.totalOvertimeMinutes -
                analysis.weekdayOvertimeMinutes -
                analysis.weekendOvertimeMinutes)
            .toDouble(),
        color: Colors.red,
      ),
    ];

    final filtered =
        segments.where((s) => s.value > 0).toList();
    final total = filtered.fold<double>(
        0, (sum, s) => sum + s.value);

    return PieChartData(
      title: '加班类型分布',
      segments: filtered,
      total: total,
    );
  }

  // ==================================================================
  //  热力图 — 打卡密集度
  // ==================================================================

  /// 生成打卡热力图数据（星期 × 小时）
  HeatmapData punchHeatmap(List<MonthlySummary> summaries) {
    // 统计每个(weekday, hour)的出现次数
    final Map<String, int> countMap = {};

    for (final s in summaries) {
      for (final r in s.dailyRecords) {
        if (r.punchInTime != null) {
          final key = '${r.punchInTime!.weekday}_${r.punchInTime!.hour}';
          countMap[key] = (countMap[key] ?? 0) + 1;
        }
        if (r.punchOutTime != null) {
          final key = '${r.punchOutTime!.weekday}_${r.punchOutTime!.hour}';
          countMap[key] = (countMap[key] ?? 0) + 1;
        }
      }
    }

    final cells = <HeatmapCell>[];
    for (final entry in countMap.entries) {
      final parts = entry.key.split('_');
      if (parts.length == 2) {
        cells.add(HeatmapCell(
          weekday: int.parse(parts[0]),
          hour: int.parse(parts[1]),
          count: entry.value,
        ));
      }
    }

    return HeatmapData(
      title: '打卡时间分布热力图',
      cells: cells,
    );
  }

  // ==================================================================
  //  日期范围（PeriodSummary）图表方法
  // ==================================================================

  /// 日期范围 — 每日工作时长柱状图
  BarChartData dailyWorkDurationChartForPeriod(PeriodSummary summary) {
    final records = summary.dailyRecords;
    final labels = <String>[];
    final values = <double>[];

    for (final r in records) {
      if (r.isComplete) {
        labels.add(_extractDay(r.date));
        values.add(r.workDurationMinutes / 60.0);
      }
    }

    return BarChartData(
      labels: labels,
      values: values,
      title: '${summary.periodLabel} 每日工作时长',
      unit: '小时',
      barColor: Colors.blue,
    );
  }

  /// 日期范围 — 上班时间趋势折线图
  LineChartData punchInTrendChartForPeriod(PeriodSummary summary) {
    final labels = <String>[];
    final values = <double>[];

    for (final r in summary.dailyRecords) {
      if (r.punchInTime != null) {
        labels.add(_extractDay(r.date));
        values.add(r.punchInTime!.hour + r.punchInTime!.minute / 60.0);
      }
    }

    return LineChartData(
      labels: labels,
      values: values,
      title: '${summary.periodLabel} 上班时间趋势',
      unit: '时',
    );
  }

  /// 日期范围 — 下班时间趋势折线图
  LineChartData punchOutTrendChartForPeriod(PeriodSummary summary) {
    final labels = <String>[];
    final values = <double>[];

    for (final r in summary.dailyRecords) {
      if (r.punchOutTime != null) {
        labels.add(_extractDay(r.date));
        values.add(r.punchOutTime!.hour + r.punchOutTime!.minute / 60.0);
      }
    }

    return LineChartData(
      labels: labels,
      values: values,
      title: '${summary.periodLabel} 下班时间趋势',
      unit: '时',
    );
  }

  /// 日期范围 — 出勤质量饼图
  PieChartData attendanceQualityPieForPeriod(PeriodSummary summary) {
    final segments = <PieChartSegment>[
      PieChartSegment(
        label: '正常出勤',
        value: summary.onTimeDays.toDouble(),
        color: Colors.green,
      ),
      PieChartSegment(
        label: '迟到',
        value: summary.lateDays.toDouble(),
        color: Colors.orange,
      ),
      PieChartSegment(
        label: '早退',
        value: summary.earlyLeaveDays.toDouble(),
        color: Colors.deepOrange,
      ),
      PieChartSegment(
        label: '缺卡',
        value: summary.missingDays.toDouble(),
        color: Colors.red[300]!,
      ),
    ];

    final filtered = segments.where((s) => s.value > 0).toList();
    final total =
        filtered.fold<double>(0, (sum, s) => sum + s.value);

    return PieChartData(
      title: '${summary.periodLabel} 出勤质量',
      segments: filtered,
      total: total,
    );
  }

  // ==================================================================
  //  工具方法
  // ==================================================================

  String _extractDay(String date) {
    try {
      return DateTime.parse(date).day.toString();
    } catch (_) {
      return date;
    }
  }
}
