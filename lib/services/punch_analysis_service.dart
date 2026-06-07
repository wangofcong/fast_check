/// 打卡数据分析引擎
///
/// 负责：
/// - 工作时长计算与统计
/// - 月度汇总
/// - 加班分析（工作日/周末/异常加班）
/// - 异常检测（连续迟到/过度加班/缺卡）

import '../models/punch_record.dart';
import '../models/punch_analysis.dart';
import 'database_service.dart';

/// 工作时长判定配置
class AnalysisConfig {
  /// 下班开始时间（HH:mm），用于判定是否加班
  final String punchOutStart;

  /// 迟到阈值（分钟），超过此值判定为迟到
  final int lateThresholdMinutes;

  /// 异常加班阈值（分钟），超过此值判定为异常加班
  final int excessiveOvertimeThreshold;

  /// 连续迟到天数阈值，超过此值触发连续迟到预警
  final int consecutiveLateThreshold;

  const AnalysisConfig({
    this.punchOutStart = '17:00',
    this.lateThresholdMinutes = 15,
    this.excessiveOvertimeThreshold = 720, // 12小时
    this.consecutiveLateThreshold = 3,
  });
}

/// 打卡数据分析服务
class PunchAnalysisService {
  final DatabaseService _db = DatabaseService();
  final AnalysisConfig config;

  PunchAnalysisService({this.config = const AnalysisConfig()});

  // ==================================================================
  //  1. 月度汇总
  // ==================================================================

  /// 获取某个月的打卡汇总
  Future<MonthlySummary> getMonthlySummary(int year, int month) async {
    final records = await _db.getPunchRecordsByMonth(year, month);
    return _buildMonthlySummary(year, month, records);
  }

  /// 获取多个连续的月度汇总（用于趋势图）
  Future<List<MonthlySummary>> getMonthlySummaries(
      int startYear, int startMonth, int endYear, int endMonth) async {
    final summaries = <MonthlySummary>[];
    int y = startYear;
    int m = startMonth;

    while (y < endYear || (y == endYear && m <= endMonth)) {
      final summary = await getMonthlySummary(y, m);
      summaries.add(summary);

      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return summaries;
  }

  MonthlySummary _buildMonthlySummary(
      int year, int month, List<PunchRecord> records) {
    final dailyList = records.map((r) => DailyAnalysis.fromRecord(r)).toList();
    dailyList.sort((a, b) => a.date.compareTo(b.date));

    // 计算该月工作日（周一到周五）
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int workDays = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final wd = DateTime(year, month, d).weekday;
      if (wd >= DateTime.monday && wd <= DateTime.friday) {
        workDays++;
      }
    }

    int attended = 0;
    int onTime = 0;
    int late = 0;
    int earlyLeave = 0;
    int totalMins = 0;
    int overtimeMins = 0;

    for (final d in dailyList) {
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
      totalWorkDays: workDays,
      attendedDays: attended,
      onTimeDays: onTime,
      lateDays: late,
      earlyLeaveDays: earlyLeave,
      totalWorkMinutes: totalMins,
      totalOvertimeMinutes: overtimeMins,
      dailyRecords: dailyList,
    );
  }

  // ==================================================================
  //  2. 加班分析
  // ==================================================================

  /// 分析某个月的加班情况
  Future<OvertimeAnalysis> analyzeOvertime(int year, int month) async {
    final records = await _db.getPunchRecordsByMonth(year, month);
    return _buildOvertimeAnalysis(year, month, records);
  }

  OvertimeAnalysis _buildOvertimeAnalysis(
      int year, int month, List<PunchRecord> records) {
    final overtimeDays = <OvertimeDay>[];
    int total = 0;
    int weekday = 0;
    int weekend = 0;
    int holiday = 0;
    int maxOvertime = 0;
    String? maxDate;

    for (final r in records) {
      if (r.overtimeMinutes <= 0) continue;

      final date = DateTime.tryParse(r.date);
      if (date == null) continue;

      final wd = date.weekday;
      final isWeekend = wd == DateTime.saturday || wd == DateTime.sunday;

      OvertimeType type;
      if (r.overtimeMinutes > config.excessiveOvertimeThreshold) {
        type = OvertimeType.excessive;
      } else if (isWeekend) {
        type = OvertimeType.weekend;
      } else {
        type = OvertimeType.weekday;
      }

      overtimeDays.add(OvertimeDay(
        date: r.date,
        overtimeMinutes: r.overtimeMinutes,
        type: type,
        weekday: wd,
      ));

      total += r.overtimeMinutes;
      if (type == OvertimeType.weekday || type == OvertimeType.excessive) {
        if (!isWeekend) weekday += r.overtimeMinutes;
      }
      if (isWeekend) weekend += r.overtimeMinutes;

      if (r.overtimeMinutes > maxOvertime) {
        maxOvertime = r.overtimeMinutes;
        maxDate = r.date;
      }
    }

    return OvertimeAnalysis(
      year: year,
      month: month,
      totalOvertimeMinutes: total,
      weekdayOvertimeMinutes: weekday,
      weekendOvertimeMinutes: weekend,
      holidayOvertimeMinutes: holiday,
      overtimeDaysCount: overtimeDays.length,
      maxOvertimeMinutes: maxOvertime,
      maxOvertimeDate: maxDate,
      overtimeDays: overtimeDays,
    );
  }

  // ==================================================================
  //  3. 异常检测
  // ==================================================================

  /// 检测某个月的打卡异常
  Future<AnomalyDetection> detectAnomalies(int year, int month) async {
    final records = await _db.getPunchRecordsByMonth(year, month);
    return _buildAnomalyDetection(records);
  }

  AnomalyDetection _buildAnomalyDetection(List<PunchRecord> records) {
    records.sort((a, b) => a.date.compareTo(b.date));

    final consecutiveLateDates = <String>[];
    final excessiveOvertimeDates = <String>[];
    final missingPunchDates = <String>[];
    final earlyLeaveDates = <String>[];

    // 连续迟到检测
    int lateStreak = 0;
    for (final r in records) {
      if (r.isLate == 1) {
        lateStreak++;
        consecutiveLateDates.add(r.date);
      } else if (r.punchInTime != null) {
        // 有打卡但没迟到，中断连续
        if (lateStreak >= config.consecutiveLateThreshold) {
          // 已经记录在列表中了
        }
        lateStreak = 0;
      }
    }

    // 过期加班检测
    for (final r in records) {
      if (r.overtimeMinutes > config.excessiveOvertimeThreshold) {
        excessiveOvertimeDates.add(r.date);
      }
    }

    // 缺卡检测（上班日但没有打卡）
    for (final r in records) {
      if (r.punchInTime == null && r.punchOutTime == null) {
        missingPunchDates.add(r.date);
      }
    }

    // 早退检测
    for (final r in records) {
      if (r.isEarlyLeave == 1) {
        earlyLeaveDates.add(r.date);
      }
    }

    return AnomalyDetection(
      consecutiveLateDates: consecutiveLateDates,
      consecutiveLateStreak: lateStreak,
      excessiveOvertimeDates: excessiveOvertimeDates,
      missingPunchDates: missingPunchDates,
      earlyLeaveDates: earlyLeaveDates,
    );
  }

  // ==================================================================
  //  4. 自定义日期范围分析
  // ==================================================================

  /// 获取指定日期范围内的打卡汇总
  Future<PeriodSummary> getPeriodSummary(
      String startDate, String endDate) async {
    final records =
        await _db.getPunchRecordsByDateRange(startDate, endDate);
    return _buildPeriodSummary(startDate, endDate, records);
  }

  PeriodSummary _buildPeriodSummary(
      String startDate, String endDate, List<PunchRecord> records) {
    final dailyList = records.map((r) => DailyAnalysis.fromRecord(r)).toList();
    dailyList.sort((a, b) => a.date.compareTo(b.date));

    // 计算范围内的总天数
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    int totalDays = 0;
    if (start != null && end != null) {
      totalDays = end.difference(start).inDays + 1;
    }

    int attended = 0;
    int onTime = 0;
    int late = 0;
    int earlyLeave = 0;
    int totalMins = 0;
    int overtimeMins = 0;

    for (final d in dailyList) {
      if (!d.isMissing) attended++;
      if (!d.isLate && d.punchInTime != null) onTime++;
      if (d.isLate) late++;
      if (d.isEarlyLeave) earlyLeave++;
      totalMins += d.workDurationMinutes;
      overtimeMins += d.overtimeMinutes;
    }

    return PeriodSummary(
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      attendedDays: attended,
      onTimeDays: onTime,
      lateDays: late,
      earlyLeaveDays: earlyLeave,
      totalWorkMinutes: totalMins,
      totalOvertimeMinutes: overtimeMins,
      dailyRecords: dailyList,
    );
  }

  /// 分析指定日期范围内的加班情况
  Future<OvertimeAnalysis> analyzeOvertimeByRange(
      String startDate, String endDate) async {
    final records =
        await _db.getPunchRecordsByDateRange(startDate, endDate);
    // 从 startDate 提取年份月份（用于标签）
    final start = DateTime.tryParse(startDate);
    final year = start?.year ?? DateTime.now().year;
    final month = start?.month ?? DateTime.now().month;
    return _buildOvertimeAnalysis(year, month, records);
  }

  /// 检测指定日期范围内的打卡异常
  Future<AnomalyDetection> detectAnomaliesByRange(
      String startDate, String endDate) async {
    final records =
        await _db.getPunchRecordsByDateRange(startDate, endDate);
    return _buildAnomalyDetection(records);
  }

  // ==================================================================
  //  5. 工具方法
  // ==================================================================

  /// 获取数据库统计信息
  Future<Map<String, dynamic>> getDatabaseStats() async {
    return await _db.getDatabaseStats();
  }

  /// 清理过期打卡记录
  Future<int> cleanOldRecords(int retentionDays) async {
    return await _db.cleanOldPunchRecords(retentionDays);
  }

  /// 获取所有打卡记录总数
  Future<int> getTotalRecordCount() async {
    return await _db.getPunchRecordCount();
  }
}
