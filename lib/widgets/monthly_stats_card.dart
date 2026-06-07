/// 月度统计卡片组件
///
/// 展示指定月份的打卡统计数据：
/// - 出勤天数 / 总工作日
/// - 准时率（未迟到天数占比）
/// - 平均工作时长
/// - 加班总时长

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/punch_record.dart';

/// 月度统计数据模型
class MonthlyStats {
  final int year;
  final int month;
  final int totalWorkDays;
  final int attendedDays; // 有打卡记录的天数
  final int onTimeDays; // 未迟到天数
  final int lateDays; // 迟到天数
  final int earlyLeaveDays; // 早退天数
  final int totalWorkMinutes;
  final int totalOvertimeMinutes;
  final int fullDays; // 同时有上下班打卡的天数

  MonthlyStats({
    required this.year,
    required this.month,
    this.totalWorkDays = 0,
    this.attendedDays = 0,
    this.onTimeDays = 0,
    this.lateDays = 0,
    this.earlyLeaveDays = 0,
    this.totalWorkMinutes = 0,
    this.totalOvertimeMinutes = 0,
    this.fullDays = 0,
  });

  /// 平均工作时长（分钟）
  int get avgWorkMinutes =>
      fullDays > 0 ? totalWorkMinutes ~/ fullDays : 0;

  /// 平均工作时长文本
  String get formattedAvgWorkDuration {
    final mins = avgWorkMinutes;
    if (mins <= 0) return '--';
    return L10n.detailFormattedDuration(mins);
  }

  /// 总加班时长文本
  String get formattedOvertime {
    final mins = totalOvertimeMinutes;
    if (mins <= 0) return '0';
    return L10n.detailFormattedDuration(mins);
  }

  /// 出勤率
  double get attendanceRate =>
      totalWorkDays > 0 ? attendedDays / totalWorkDays : 0;

  /// 准时率
  double get punctualityRate =>
      attendedDays > 0 ? onTimeDays / attendedDays : 0;

  /// 月名称
  String get monthName {
    if (L10n.languageCode == 'zh') {
      const names = [
        '1月', '2月', '3月', '4月', '5月', '6月',
        '7月', '8月', '9月', '10月', '11月', '12月'
      ];
      return names[month - 1];
    }
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }

  /// 从打卡记录列表构建统计
  static MonthlyStats fromRecords({
    required int year,
    required int month,
    required List<PunchRecord> records,
    int totalWorkDays = 20, // 默认估计的工作日数
  }) {
    int attended = 0;
    int onTime = 0;
    int late = 0;
    int earlyLeave = 0;
    int totalMins = 0;
    int overtimeMins = 0;
    int full = 0;

    for (final r in records) {
      if (r.punchInTime != null || r.punchOutTime != null) {
        attended++;
      }
      if (r.punchInTime != null && r.punchOutTime != null) {
        full++;
      }
      if (r.isLate == 0 && r.punchInTime != null) {
        onTime++;
      }
      if (r.isLate == 1) late++;
      if (r.isEarlyLeave == 1) earlyLeave++;
      totalMins += r.workDurationMinutes;
      overtimeMins += r.overtimeMinutes;
    }

    return MonthlyStats(
      year: year,
      month: month,
      totalWorkDays: totalWorkDays,
      attendedDays: attended,
      onTimeDays: onTime,
      lateDays: late,
      earlyLeaveDays: earlyLeave,
      totalWorkMinutes: totalMins,
      totalOvertimeMinutes: overtimeMins,
      fullDays: full,
    );
  }
}

/// 月度统计卡片
class MonthlyStatsCard extends StatelessWidget {
  final MonthlyStats stats;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  const MonthlyStatsCard({
    super.key,
    required this.stats,
    this.onPrevMonth,
    this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份切换头
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevMonth,
                ),
                Text(
                  L10n.statsMonthYear(stats.year, stats.monthName),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNextMonth,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 统计行 — 出勤 / 准时率
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.calendar_today,
                    label: L10n.statsAttendance,
                    value: L10n.statsAttendanceDays(stats.attendedDays, stats.totalWorkDays),
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    label: L10n.statsPunctuality,
                    value: L10n.statsPercent(stats.punctualityRate),
                    color: stats.punctualityRate >= 0.8
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 统计行 — 工作时长 / 加班
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.timer,
                    label: L10n.statsAvgWork,
                    value: stats.formattedAvgWorkDuration,
                    color: Colors.indigo,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.access_time_filled,
                    label: L10n.statsOvertime,
                    value: stats.formattedOvertime,
                    color: stats.totalOvertimeMinutes > 0
                        ? Colors.deepOrange
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 考勤质量指示
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.warning_amber,
                    label: L10n.statsLate,
                    value: L10n.statsTimes(stats.lateDays),
                    color: stats.lateDays > 0 ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.exit_to_app,
                    label: L10n.statsEarlyLeave,
                    value: L10n.statsTimes(stats.earlyLeaveDays),
                    color: stats.earlyLeaveDays > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[600])),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: color)),
          ],
        ),
      ],
    );
  }
}
