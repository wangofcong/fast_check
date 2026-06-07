/// Phase 10 — 打卡数据分析引擎测试
///
/// 测试范围：
/// - PunchAnalysisService 核心分析方法
/// - 月度汇总（含工作日计算、出勤统计）
/// - 加班分析（类型判定、时长汇总）
/// - 异常检测（连续迟到、过度加班、缺卡、早退）
/// - 工具方法（数据库统计、记录清理）
///
/// 注意事项：
/// - 使用真实 SQLite 数据库（DatabaseService 单例）
/// - 测试前先创建测试数据，测试后清理

import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/models/punch_record.dart';
import 'package:fast_check/models/punch_analysis.dart';
import 'package:fast_check/services/punch_analysis_service.dart';
import 'package:fast_check/services/database_service.dart';
import 'helpers/test_setup.dart';

void main() {
  setupTestDatabase();
  late PunchAnalysisService analysisService;
  late DatabaseService dbService;

  setUp(() async {
    dbService = DatabaseService();
    analysisService = PunchAnalysisService();

    // 确保数据库已初始化
    await dbService.database;

    // 清理已有的测试数据
    final db = await dbService.database;
    await db.delete('punch_records');
  });

  tearDown(() async {
    // 清理测试数据
    final db = await dbService.database;
    await db.delete('punch_records');
  });

  // ====================================================================
  //  辅助方法：创建测试打卡记录
  // ====================================================================

  Future<void> _insertRecord(PunchRecord record) async {
    await dbService.upsertPunchRecordByDate(record);
  }

  // ====================================================================
  //  1. 月度汇总测试
  // ====================================================================

  group('getMonthlySummary', () {
    test('无记录时返回正确默认值', () async {
      final summary = await analysisService.getMonthlySummary(2026, 6);

      expect(summary.year, 2026);
      expect(summary.month, 6);
      expect(summary.totalWorkDays, 22); // 2026年6月有22个工作日
      expect(summary.attendedDays, 0);
      expect(summary.onTimeDays, 0);
      expect(summary.lateDays, 0);
      expect(summary.earlyLeaveDays, 0);
      expect(summary.totalWorkMinutes, 0);
      expect(summary.totalOvertimeMinutes, 0);
      expect(summary.dailyRecords, isEmpty);
    });

    test('统计正常打卡记录', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01', // 周一
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
        isLate: 0,
        isEarlyLeave: 0,
        workDurationMinutes: 540,
        overtimeMinutes: 60,
      ));

      await _insertRecord(PunchRecord(
        date: '2026-06-02', // 周二
        punchInTime: '2026-06-02 09:00:00',
        punchOutTime: '2026-06-02 18:00:00',
        isLate: 0,
        isEarlyLeave: 0,
        workDurationMinutes: 540,
        overtimeMinutes: 0,
      ));

      final summary = await analysisService.getMonthlySummary(2026, 6);

      expect(summary.attendedDays, 2);
      expect(summary.onTimeDays, 2);
      expect(summary.lateDays, 0);
      expect(summary.earlyLeaveDays, 0);
      expect(summary.totalWorkMinutes, 1080);
      expect(summary.totalOvertimeMinutes, 60);
    });

    test('统计迟到记录', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:30:00',
        punchOutTime: '2026-06-01 18:00:00',
        isLate: 1,
        isEarlyLeave: 0,
        workDurationMinutes: 510,
        overtimeMinutes: 0,
      ));

      await _insertRecord(PunchRecord(
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:00:00',
        punchOutTime: '2026-06-02 18:00:00',
        isLate: 0,
        isEarlyLeave: 0,
        workDurationMinutes: 540,
        overtimeMinutes: 0,
      ));

      final summary = await analysisService.getMonthlySummary(2026, 6);

      expect(summary.attendedDays, 2);
      expect(summary.onTimeDays, 1);
      expect(summary.lateDays, 1);
    });

    test('统计早退记录', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 17:00:00',
        isLate: 0,
        isEarlyLeave: 1,
        workDurationMinutes: 480,
        overtimeMinutes: 0,
      ));

      final summary = await analysisService.getMonthlySummary(2026, 6);

      expect(summary.earlyLeaveDays, 1);
    });

    test('缺卡记录不计入出勤', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final summary = await analysisService.getMonthlySummary(2026, 6);

      expect(summary.attendedDays, 0);
      expect(summary.onTimeDays, 0);
      expect(summary.dailyRecords.length, 1);
      expect(summary.dailyRecords.first.isMissing, isTrue);
    });

    test('跨月查询', () async {
      // 6月记录
      await _insertRecord(PunchRecord(
        date: '2026-06-15',
        punchInTime: '2026-06-15 09:00:00',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      // 7月记录
      await _insertRecord(PunchRecord(
        date: '2026-07-01',
        punchInTime: '2026-07-01 09:00:00',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final juneSummary = await analysisService.getMonthlySummary(2026, 6);
      final julySummary = await analysisService.getMonthlySummary(2026, 7);

      expect(juneSummary.dailyRecords.length, 1);
      expect(julySummary.dailyRecords.length, 1);
      expect(juneSummary.dailyRecords.first.date, '2026-06-15');
      expect(julySummary.dailyRecords.first.date, '2026-07-01');
    });
  });

  group('getMonthlySummaries', () {
    test('获取连续多月汇总', () async {
      // 插入6月数据
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final summaries =
          await analysisService.getMonthlySummaries(2026, 6, 2026, 8);

      expect(summaries.length, 3);
      expect(summaries[0].year, 2026);
      expect(summaries[0].month, 6);
      expect(summaries[1].month, 7);
      expect(summaries[2].month, 8);
    });

    test('跨年查询', () async {
      final summaries =
          await analysisService.getMonthlySummaries(2025, 11, 2026, 2);

      expect(summaries.length, 4);
      expect(summaries[0].year, 2025);
      expect(summaries[0].month, 11);
      expect(summaries[1].month, 12);
      expect(summaries[2].year, 2026);
      expect(summaries[2].month, 1);
      expect(summaries[3].month, 2);
    });
  });

  // ====================================================================
  //  2. 加班分析测试
  // ====================================================================

  group('analyzeOvertime', () {
    test('无加班记录返回空结果', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
        overtimeMinutes: 0,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final overtime = await analysisService.analyzeOvertime(2026, 6);

      expect(overtime.overtimeDaysCount, 0);
      expect(overtime.totalOvertimeMinutes, 0);
      expect(overtime.maxOvertimeMinutes, 0);
      expect(overtime.maxOvertimeDate, isNull);
    });

    test('识别工作日加班', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01', // 周一
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 20:00:00',
        overtimeMinutes: 120,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final overtime = await analysisService.analyzeOvertime(2026, 6);

      expect(overtime.overtimeDaysCount, 1);
      expect(overtime.totalOvertimeMinutes, 120);
      expect(overtime.weekdayOvertimeMinutes, 120);
      expect(overtime.weekendOvertimeMinutes, 0);
    });

    test('识别周末加班', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-06', // 周六
        punchInTime: '2026-06-06 10:00:00',
        punchOutTime: '2026-06-06 15:00:00',
        overtimeMinutes: 180, // 周末也按加班算
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final overtime = await analysisService.analyzeOvertime(2026, 6);

      expect(overtime.overtimeDaysCount, 1);
      expect(overtime.weekendOvertimeMinutes, 180);
    });

    test('识别异常加班（超过阈值）', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-02', // 周二
        punchInTime: '2026-06-02 09:00:00',
        punchOutTime: '2026-06-02 22:00:00',
        overtimeMinutes: 780, // 13小时 > 12小时阈值
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final overtime = await analysisService.analyzeOvertime(2026, 6);

      expect(overtime.overtimeDaysCount, 1);
      expect(overtime.overtimeDays.first.type, OvertimeType.excessive);
    });

    test('记录最长加班日', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:00:00',
        punchOutTime: '2026-06-02 20:00:00',
        overtimeMinutes: 120,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      await _insertRecord(PunchRecord(
        date: '2026-06-03',
        punchInTime: '2026-06-03 09:00:00',
        punchOutTime: '2026-06-03 21:00:00',
        overtimeMinutes: 240,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final overtime = await analysisService.analyzeOvertime(2026, 6);

      expect(overtime.maxOvertimeMinutes, 240);
      expect(overtime.maxOvertimeDate, '2026-06-03');
    });

    test('处理无效日期格式', () async {
      await _insertRecord(PunchRecord(
        date: 'invalid-date',
        overtimeMinutes: 60,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final overtime = await analysisService.analyzeOvertime(2026, 6);
      expect(overtime.overtimeDaysCount, 0);
    });
  });

  // ====================================================================
  //  3. 异常检测测试
  // ====================================================================

  group('detectAnomalies', () {
    test('无异常时返回空结果', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 18:00:00',
        isLate: 0,
        isEarlyLeave: 0,
        overtimeMinutes: 0,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.hasAnomalies, isFalse);
      expect(anomalies.totalAnomalies, 0);
    });

    test('检测连续迟到', () async {
      // 连续3天迟到
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:30:00',
        isLate: 1,
        isEarlyLeave: 0,
      ));
      await _insertRecord(PunchRecord(
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:45:00',
        isLate: 1,
        isEarlyLeave: 0,
      ));
      await _insertRecord(PunchRecord(
        date: '2026-06-03',
        punchInTime: '2026-06-03 09:20:00',
        isLate: 1,
        isEarlyLeave: 0,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.consecutiveLateDates.length, 3);
      expect(anomalies.consecutiveLateStreak, 3);
    });

    test('检测过度加班', () async {
      // 默认阈值 720 分钟（12小时）
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        overtimeMinutes: 800,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.excessiveOvertimeDates.length, 1);
      expect(anomalies.excessiveOvertimeDates.first, '2026-06-01');
    });

    test('不标记正常加班为异常', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        overtimeMinutes: 60, // 1小时，正常加班
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.excessiveOvertimeDates, isEmpty);
    });

    test('检测缺卡记录', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        isLate: 0,
        isEarlyLeave: 0,
        // 无打卡时间
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.missingPunchDates.length, 1);
      expect(anomalies.missingPunchDates.first, '2026-06-01');
    });

    test('部分打卡不算缺卡', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        // 只有上班打卡
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.missingPunchDates, isEmpty);
    });

    test('检测早退', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:00:00',
        punchOutTime: '2026-06-01 16:00:00',
        isLate: 0,
        isEarlyLeave: 1,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.earlyLeaveDates.length, 1);
      expect(anomalies.earlyLeaveDates.first, '2026-06-01');
    });

    test('混合异常检测', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        punchInTime: '2026-06-01 09:30:00',
        isLate: 1,
        isEarlyLeave: 0,
        overtimeMinutes: 0,
      ));

      await _insertRecord(PunchRecord(
        date: '2026-06-02',
        punchInTime: '2026-06-02 09:45:00',
        isLate: 1,
        isEarlyLeave: 0,
        overtimeMinutes: 0,
      ));

      await _insertRecord(PunchRecord(
        date: '2026-06-03',
        overtimeMinutes: 800,
        isLate: 0,
        isEarlyLeave: 0,
      ));

      await _insertRecord(PunchRecord(
        date: '2026-06-04',
        punchInTime: '2026-06-04 09:00:00',
        punchOutTime: '2026-06-04 16:00:00',
        isLate: 0,
        isEarlyLeave: 1,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      expect(anomalies.consecutiveLateDates.length, 2);
      expect(anomalies.excessiveOvertimeDates.length, 1);
      expect(anomalies.earlyLeaveDates.length, 1);
      expect(anomalies.totalAnomalies, 4);
      expect(anomalies.hasAnomalies, isTrue);
    });

    test('记录按日期排序', () async {
      // 乱序插入
      await _insertRecord(PunchRecord(
        date: '2026-06-03',
        isLate: 1,
        isEarlyLeave: 0,
      ));
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        isLate: 1,
        isEarlyLeave: 0,
      ));

      final anomalies = await analysisService.detectAnomalies(2026, 6);

      // 按日期排序，06-01 应在 06-03 之前
      expect(anomalies.consecutiveLateDates[0], '2026-06-01');
      expect(anomalies.consecutiveLateDates[1], '2026-06-03');
    });
  });

  // ====================================================================
  //  4. 工具方法测试
  // ====================================================================

  group('工具方法', () {
    test('getDatabaseStats 返回统计数据', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final stats = await analysisService.getDatabaseStats();

      expect(stats, isNotEmpty);
      expect(stats['punch_records'], greaterThanOrEqualTo(1));
    });

    test('getTotalRecordCount 返回记录总数', () async {
      await _insertRecord(PunchRecord(
        date: '2026-06-01',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final count = await analysisService.getTotalRecordCount();
      expect(count, greaterThanOrEqualTo(1));
    });

    test('cleanOldRecords 清理旧记录', () async {
      // 插入一条"很旧"的记录（日期字符串手动构造）
      await _insertRecord(PunchRecord(
        date: '2020-01-01',
        isLate: 0,
        isEarlyLeave: 0,
      ));

      final deleted = await analysisService.cleanOldRecords(30);
      expect(deleted, greaterThanOrEqualTo(0));
    });
  });

  // ====================================================================
  //  5. AnalysisConfig 测试
  // ====================================================================

  group('AnalysisConfig', () {
    test('默认配置值正确', () {
      const config = AnalysisConfig();
      expect(config.punchOutStart, '17:00');
      expect(config.lateThresholdMinutes, 15);
      expect(config.excessiveOvertimeThreshold, 720);
      expect(config.consecutiveLateThreshold, 3);
    });

    test('自定义配置', () {
      const config = AnalysisConfig(
        punchOutStart: '18:00',
        lateThresholdMinutes: 30,
        excessiveOvertimeThreshold: 600,
        consecutiveLateThreshold: 5,
      );
      expect(config.punchOutStart, '18:00');
      expect(config.lateThresholdMinutes, 30);
      expect(config.excessiveOvertimeThreshold, 600);
      expect(config.consecutiveLateThreshold, 5);
    });
  });
}
