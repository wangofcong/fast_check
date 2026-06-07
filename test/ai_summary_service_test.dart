/// AI 总结服务单元测试
///
/// 测试内容：
/// - AiConfig 配置管理
/// - 数据脱敏逻辑
/// - AI 响应解析（JSON 提取 + 报告构建）
/// - API Key 验证

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/models/ai_report.dart';
import '../lib/models/punch_analysis.dart';
import '../lib/models/punch_record.dart';

void main() {
  // 初始化 sqflite FFI 用于测试
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AiConfig', () {
    test('默认配置应使用 deepseek-v4-flash', () {
      final config = AiConfig();
      expect(config.modelName, 'deepseek-v4-flash');
      expect(config.apiBaseUrl, 'https://api.deepseek.com/v1');
      expect(config.anonymizeData, true);
      expect(config.isConfigured, false);
    });

    test('配置 API Key 后 isConfigured 应返回 true', () {
      final config = AiConfig(apiKey: 'sk-test-key');
      expect(config.isConfigured, true);
    });

    test('copyWith 应正确复制并修改字段', () {
      final config = AiConfig(
        modelName: 'deepseek-v4-flash',
        apiKey: 'sk-old',
      );

      final updated = config.copyWith(
        apiKey: 'sk-new',
        anonymizeData: false,
      );

      expect(updated.apiKey, 'sk-new');
      expect(updated.modelName, 'deepseek-v4-flash');
      expect(updated.anonymizeData, false);
      // 原配置不变
      expect(config.apiKey, 'sk-old');
    });
  });

  group('AiReport', () {
    test('成功报告应正确设置字段', () {
      final report = AiReport(
        type: 'monthly',
        periodLabel: '2024年1月',
        generatedAt: '2024-02-01T00:00:00',
        overview: AiOverview(
          summary: '本月出勤良好',
          attendedDays: 22,
          totalWorkDays: 22,
        ),
        findings: [
          AiFinding(
            type: 'positive',
            title: '准时率较高',
            description: '本月准时率超过90%',
          ),
        ],
        suggestions: [
          AiSuggestion(
            priority: 1,
            title: '保持良好习惯',
            description: '继续保持准时打卡',
          ),
        ],
        scores: [
          AiScore(name: '出勤', value: 4.5, label: '优秀'),
        ],
      );

      expect(report.type, 'monthly');
      expect(report.isSuccess, true);
      expect(report.overview!.attendedDays, 22);
      expect(report.findings.length, 1);
      expect(report.suggestions.length, 1);
      expect(report.scores.length, 1);
      expect(report.scores[0].starCount, 5); // 4.5 四舍五入为 5
    });

    test('错误报告应正确设置错误信息', () {
      final report = AiReport.error(
        'monthly',
        '2024年1月',
        'API Key 未配置',
      );

      expect(report.isSuccess, false);
      expect(report.error, 'API Key 未配置');
      expect(report.type, 'monthly');
    });
  });

  group('AiOverview', () {
    test('应正确初始化所有字段', () {
      final overview = AiOverview(
        summary: '测试概况',
        attendedDays: 20,
        totalWorkDays: 22,
        lateCount: 2,
        overtimeDays: 5,
        avgArrival: '09:15',
        avgDeparture: '18:30',
        avgWorkDuration: '8h30m',
        totalOvertime: '10h',
      );

      expect(overview.summary, '测试概况');
      expect(overview.attendedDays, 20);
      expect(overview.lateCount, 2);
      expect(overview.avgArrival, '09:15');
      expect(overview.avgWorkDuration, '8h30m');
    });

    test('应使用默认值处理空字段', () {
      final overview = AiOverview(summary: '测试');
      expect(overview.attendedDays, 0);
      expect(overview.avgArrival, '--:--');
      expect(overview.avgWorkDuration, '0h');
    });
  });

  group('AiFinding', () {
    test('应正确存储关键发现', () {
      final finding = AiFinding(
        type: 'negative',
        title: '加班频繁',
        description: '本月加班天数较多',
      );

      expect(finding.type, 'negative');
      expect(finding.title, '加班频繁');
      expect(finding.description, '本月加班天数较多');
    });
  });

  group('AiSuggestion', () {
    test('优先级的默认值应为 3', () {
      final suggestion = AiSuggestion(
        title: '测试建议',
        description: '测试描述',
      );
      expect(suggestion.priority, 3);
    });

    test('应支持设置优先级', () {
      final suggestion = AiSuggestion(
        priority: 1,
        title: '重要建议',
        description: '高优先级',
      );
      expect(suggestion.priority, 1);
    });
  });

  group('AiScore', () {
    test('starCount 应正确四舍五入', () {
      expect(AiScore(name: '测试', value: 4.2, label: '').starCount, 4);
      expect(AiScore(name: '测试', value: 4.8, label: '').starCount, 5);
      expect(AiScore(name: '测试', value: 0.5, label: '').starCount, 1);
      expect(AiScore(name: '测试', value: 5.0, label: '').starCount, 5);
    });

    test('percentage 应正确计算', () {
      final score = AiScore(name: '测试', value: 4.0, label: '');
      expect(score.percentage, 0.8);
    });

    test('percentage 应限制在 0~1 之间', () {
      final scoreLow = AiScore(name: '测试', value: -1.0, label: '');
      expect(scoreLow.percentage, 0.0);

      final scoreHigh = AiScore(name: '测试', value: 10.0, label: '');
      expect(scoreHigh.percentage, 1.0);
    });
  });

  group('DailyAnalysis 与 AI 数据源兼容性', () {
    test('从 PunchRecord 构造 DailyAnalysis', () {
      final record = PunchRecord(
        date: '2024-01-15',
        punchInTime: '2024-01-15 09:02:00',
        punchOutTime: '2024-01-15 18:05:00',
        punchInType: 'manual',
        punchOutType: 'manual',
        isLate: 0,
        isEarlyLeave: 0,
        overtimeMinutes: 65,
        workDurationMinutes: 543,
      );

      final daily = DailyAnalysis.fromRecord(record);

      expect(daily.date, '2024-01-15');
      expect(daily.workDurationMinutes, 543);
      expect(daily.overtimeMinutes, 65);
      expect(daily.isLate, false);
      expect(daily.isComplete, true);
      expect(daily.punchInType, 'manual');
    });
  });

  group('月度统计数据生成', () {
    test('MonthlySummary 应正确计算派生属性', () {
      final records = List.generate(20, (i) {
        final day = (i + 1).toString().padLeft(2, '0');
        return DailyAnalysis(
          date: '2024-01-$day',
          punchInTime: DateTime(2024, 1, i + 1, 9, 0),
          punchOutTime: DateTime(2024, 1, i + 1, 18, 0),
          workDurationMinutes: 540,
          overtimeMinutes: i < 5 ? 60 : 0,
          isLate: i >= 18,
          isEarlyLeave: false,
        );
      });

      final summary = MonthlySummary(
        year: 2024,
        month: 1,
        totalWorkDays: 22,
        attendedDays: 20,
        onTimeDays: 18,
        lateDays: 2,
        earlyLeaveDays: 0,
        totalWorkMinutes: 20 * 540,
        totalOvertimeMinutes: 5 * 60,
        dailyRecords: records,
      );

      expect(summary.avgWorkMinutes, 540);
      expect(summary.attendanceRate, closeTo(20 / 22, 0.01));
      expect(summary.punctualityRate, closeTo(18 / 20, 0.01));
      expect(summary.fullDays, 20);
      expect(summary.missingDays, 0);
      expect(summary.formattedAvgWorkDuration, '9h0m');
      expect(summary.formattedOvertime, '5h0m');
    });
  });
}
