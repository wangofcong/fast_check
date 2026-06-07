/// AI 总结与建议服务
///
/// 基于打卡数据分析结果，调用 DeepSeek API 生成：
/// - 工作习惯总结
/// - 异常行为分析
/// - 个性化改进建议
/// - 出勤评分
///
/// 🔒 隐私保护：
/// - 所有打卡数据在发送前进行脱敏处理（去除具体日期、公司名称）
/// - API Key 由用户自行填入，仅存于本地数据库
/// - 支持完全离线使用（用户可选择不配置 API）

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/punch_analysis.dart';
import '../models/ai_report.dart';
import '../models/app_settings.dart';
import 'database_service.dart';
import 'punch_analysis_service.dart';

/// AI 总结服务
class AiSummaryService {
  final DatabaseService _db = DatabaseService();

  /// 默认 API 配置
  static const String defaultModelName = 'deepseek-v4-flash';
  static const String defaultApiBaseUrl = 'https://api.deepseek.com/v1';

  // ==================================================================
  //  配置管理
  // ==================================================================

  /// 加载 AI 配置
  Future<AiConfig> loadConfig() async {
    final apiKey = await _db.getSetting(AppSettingKeys.aiApiKey) ?? '';
    final modelName =
        await _db.getSettingWithDefault(AppSettingKeys.aiModelName);
    final apiBaseUrl =
        await _db.getSettingWithDefault(AppSettingKeys.aiApiBaseUrl);
    final anonymizeDataStr =
        await _db.getSettingWithDefault(AppSettingKeys.aiAnonymizeData);

    return AiConfig(
      apiKey: apiKey,
      modelName: modelName,
      apiBaseUrl: apiBaseUrl,
      anonymizeData: anonymizeDataStr == 'true',
    );
  }

  /// 保存 AI 配置
  Future<void> saveConfig(AiConfig config) async {
    await _db.setSetting(AppSettingKeys.aiApiKey, config.apiKey);
    await _db.setSetting(AppSettingKeys.aiModelName, config.modelName);
    await _db.setSetting(AppSettingKeys.aiApiBaseUrl, config.apiBaseUrl);
    await _db.setSetting(AppSettingKeys.aiAnonymizeData,
        config.anonymizeData ? 'true' : 'false');
  }

  /// 检查是否已配置 API Key
  Future<bool> isConfigured() async {
    final config = await loadConfig();
    return config.isConfigured;
  }

  // ==================================================================
  //  数据脱敏（隐私保护）
  // ==================================================================

  /// 对打卡数据进行脱敏处理
  ///
  /// 🔒 脱敏规则：
  /// - 日期 → 相对天数（第 N 个工作日）
  /// - 具体时间 → 相对时间（距上班开始分钟数）
  /// - 公司名称 → 移除
  /// - 地址信息 → 移除
  Map<String, dynamic> _anonymizeData(
      MonthlySummary summary, OvertimeAnalysis? overtime) {
    final anonymizedDaily = <Map<String, dynamic>>[];
    int workDayIndex = 0;

    final weekDayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    for (final day in summary.dailyRecords) {
      if (day.isMissing) continue;
      workDayIndex++;

      final date = DateTime.tryParse(day.date);
      final weekDayName =
          date != null && date.weekday >= 1 && date.weekday <= 7
              ? weekDayNames[date.weekday - 1]
              : '未知';

      // 计算打卡时间偏移（相对日期开始）
      int? arrivalOffsetMin; // 到岗时间距离 0:00 的分钟数
      int? departureOffsetMin; // 离岗时间距离 0:00 的分钟数

      if (day.punchInTime != null) {
        arrivalOffsetMin =
            day.punchInTime!.hour * 60 + day.punchInTime!.minute;
      }
      if (day.punchOutTime != null) {
        departureOffsetMin =
            day.punchOutTime!.hour * 60 + day.punchOutTime!.minute;
      }

      anonymizedDaily.add({
        'workDay': '第$workDayIndex个工作日',
        'weekDay': weekDayName,
        'arrivalMinute': arrivalOffsetMin,
        'departureMinute': departureOffsetMin,
        'workMinutes': day.workDurationMinutes,
        'overtimeMinutes': day.overtimeMinutes,
        'isLate': day.isLate,
        'isEarlyLeave': day.isEarlyLeave,
        'punchInType': day.punchInType,
        'punchOutType': day.punchOutType,
      });
    }

    final result = <String, dynamic>{
      'period':
          '${summary.year}年${summary.month}月（已脱敏）',
      'totalWorkDays': summary.totalWorkDays,
      'attendedDays': summary.attendedDays,
      'onTimeDays': summary.onTimeDays,
      'lateDays': summary.lateDays,
      'earlyLeaveDays': summary.earlyLeaveDays,
      'avgWorkMinutes': summary.avgWorkMinutes,
      'totalOvertimeMinutes': summary.totalOvertimeMinutes,
      'fullDays': summary.fullDays,
      'dailyRecords': anonymizedDaily,
    };

    // 如果加班分析可用，添加汇总数据
    if (overtime != null) {
      result['overtimeAnalysis'] = {
        'totalOvertimeMinutes': overtime.totalOvertimeMinutes,
        'weekdayOvertimeMinutes': overtime.weekdayOvertimeMinutes,
        'weekendOvertimeMinutes': overtime.weekendOvertimeMinutes,
        'overtimeDaysCount': overtime.overtimeDaysCount,
        'maxOvertimeMinutes': overtime.maxOvertimeMinutes,
      };
    }

    return result;
  }

  // ==================================================================
  //  AI 报告生成
  // ==================================================================

  /// 生成月度 AI 分析报告
  Future<AiReport> generateMonthlyReport(int year, int month) async {
    final config = await loadConfig();

    if (!config.isConfigured) {
      return AiReport.error(
        'monthly',
        '${year}年${month}月',
        '请先在「AI 设置」中填入 API Key 以启用 AI 分析功能。',
      );
    }

    // 加载分析数据
    final analysisService = PunchAnalysisService();
    final summary = await analysisService.getMonthlySummary(year, month);
    final overtime = await analysisService.analyzeOvertime(year, month);
    final anomalies = await analysisService.detectAnomalies(year, month);

    // 脱敏（如果开启）
    final dataForAnalysis = config.anonymizeData
        ? _anonymizeData(summary, overtime)
        : _buildRawData(summary, overtime);

    // 构建提示词
    final prompt = _buildPrompt(summary, overtime, anomalies, dataForAnalysis);

    // 调用 API
    try {
      final response = await _callDeepSeekApi(config, prompt);
      final report = _parseAiResponse(
        'monthly',
        '${year}年${month}月',
        response,
        summary,
        overtime,
        anomalies,
      );
      // 缓存到本地
      await saveReport(report);
      return report;
    } catch (e) {
      return AiReport.error(
        'monthly',
        '${year}年${month}月',
        'AI 分析请求失败: $e\n\n请检查 API Key 是否正确以及网络连接是否正常。',
      );
    }
  }

  /// 构建非脱敏的原始数据（当用户关闭脱敏时使用）
  Map<String, dynamic> _buildRawData(
      MonthlySummary summary, OvertimeAnalysis? overtime) {
    final result = <String, dynamic>{
      'period': '${summary.year}年${summary.month}月',
      'totalWorkDays': summary.totalWorkDays,
      'attendedDays': summary.attendedDays,
      'onTimeDays': summary.onTimeDays,
      'lateDays': summary.lateDays,
      'earlyLeaveDays': summary.earlyLeaveDays,
      'avgWorkMinutes': summary.avgWorkMinutes,
      'totalOvertimeMinutes': summary.totalOvertimeMinutes,
      'fullDays': summary.fullDays,
    };

    // 包含完整日期信息（未脱敏）
    final dailyList = <Map<String, dynamic>>[];
    for (final day in summary.dailyRecords) {
      if (day.isMissing) continue;
      dailyList.add({
        'date': day.date,
        'punchInTime': day.punchInTime?.toIso8601String(),
        'punchOutTime': day.punchOutTime?.toIso8601String(),
        'workMinutes': day.workDurationMinutes,
        'overtimeMinutes': day.overtimeMinutes,
        'isLate': day.isLate,
        'isEarlyLeave': day.isEarlyLeave,
      });
    }
    result['dailyRecords'] = dailyList;

    if (overtime != null) {
      result['overtimeAnalysis'] = {
        'totalOvertimeMinutes': overtime.totalOvertimeMinutes,
        'weekdayOvertimeMinutes': overtime.weekdayOvertimeMinutes,
        'weekendOvertimeMinutes': overtime.weekendOvertimeMinutes,
        'overtimeDaysCount': overtime.overtimeDaysCount,
      };
    }

    return result;
  }

  // ==================================================================
  //  提示词构建
  // ==================================================================

  String _buildPrompt(MonthlySummary summary, OvertimeAnalysis overtime,
      AnomalyDetection anomalies, Map<String, dynamic> data) {
    final jsonData = const JsonEncoder.withIndent('  ').convert(data);

    return '''你是一个专业的考勤数据分析助手。请根据以下打卡数据分析结果，生成一份详细的月度和工作习惯分析报告。

## 打卡数据

```json
$jsonData
```

## 异常检测

${anomalies.hasAnomalies ? _formatAnomalies(anomalies) : '本月未检测到异常打卡行为。'}

## 要求

请生成包含以下内容的 JSON 格式报告（不要包含 Markdown 代码块标记，只返回纯 JSON）：

```json
{
  "overview": {
    "summary": "一段 2-3 句话的月度工作概况总结",
    "attendedDays": ${summary.attendedDays},
    "totalWorkDays": ${summary.totalWorkDays},
    "lateCount": ${summary.lateDays},
    "overtimeDays": ${overtime.overtimeDaysCount},
    "avgArrival": "平均到岗时间（如 09:12）",
    "avgDeparture": "平均离岗时间（如 18:30）",
    "avgWorkDuration": "${summary.formattedAvgWorkDuration}",
    "totalOvertime": "${summary.formattedOvertime}"
  },
  "findings": [
    {
      "type": "positive|negative|info",
      "title": "发现标题",
      "description": "详细描述，50-100字"
    }
  ],
  "suggestions": [
    {
      "priority": 1-5,
      "title": "建议标题",
      "description": "具体建议内容，50-100字"
    }
  ],
  "scores": [
    {
      "name": "出勤",
      "value": 0.0-5.0,
      "label": "出勤评分说明"
    }
  ]
}
```

注意事项：
1. findings 至少包含 2 条，最多 5 条
2. suggestions 至少包含 2 条，最多 4 条
3. scores 包含 3-4 个评分维度（如：出勤、准时、效率、平衡）
4. 所有描述使用中文，语气专业且友好
5. 基于实际数据给出具体、可操作的建议
6. 如果加班时间较多，请重点关注工作生活平衡
7. 如果迟到较多，请给出具体的通勤优化建议
''';
  }

  String _formatAnomalies(AnomalyDetection anomalies) {
    final parts = <String>[];
    if (anomalies.consecutiveLateDates.length >= 3) {
      parts.add(
          '- 连续迟到：${anomalies.consecutiveLateDates.length} 天（最近 ${anomalies.consecutiveLateStreak} 天连续）');
    }
    if (anomalies.excessiveOvertimeDates.isNotEmpty) {
      parts.add('- 过度加班：${anomalies.excessiveOvertimeDates.length} 天');
    }
    if (anomalies.missingPunchDates.isNotEmpty) {
      parts.add('- 缺卡：${anomalies.missingPunchDates.length} 天');
    }
    if (anomalies.earlyLeaveDates.isNotEmpty) {
      parts.add('- 早退：${anomalies.earlyLeaveDates.length} 次');
    }
    return parts.join('\n');
  }

  // ==================================================================
  //  DeepSeek API 调用
  // ==================================================================

  /// 调用 DeepSeek Chat API
  Future<String> _callDeepSeekApi(AiConfig config, String prompt) async {
    final uri = Uri.parse('${config.apiBaseUrl}/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
    };

    final body = jsonEncode({
      'model': config.modelName,
      'messages': [
        {
          'role': 'system',
          'content':
              '你是一个专业的考勤数据分析助手。你擅长分析上下班打卡数据，发现工作习惯规律，并提供可操作的时间管理建议。请始终用中文回复，保持专业且友好的语气。',
        },
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 2048,
    });

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AiApiException(
        'API 返回错误 (${response.statusCode}): ${response.body}',
        response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw AiApiException('API 返回结果为空', 0);
    }

    final message = choices[0] as Map<String, dynamic>;
    final content = message['message'] as Map<String, dynamic>?;
    final text = content?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw AiApiException('API 返回内容为空', 0);
    }

    return text;
  }

  // ==================================================================
  //  响应解析
  // ==================================================================

  /// 解析 AI 返回的 JSON 文本为 AiReport
  AiReport _parseAiResponse(
    String type,
    String periodLabel,
    String rawText,
    MonthlySummary summary,
    OvertimeAnalysis overtime,
    AnomalyDetection anomalies,
  ) {
    try {
      // 尝试提取 JSON（AI 可能返回包含 Markdown 代码块的内容）
      final jsonStr = _extractJson(rawText);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 解析 overview
      AiOverview? overview;
      if (json['overview'] != null) {
        final ov = json['overview'] as Map<String, dynamic>;
        overview = AiOverview(
          summary: ov['summary'] as String? ?? '',
          attendedDays: (ov['attendedDays'] as num?)?.toInt() ??
              summary.attendedDays,
          totalWorkDays: (ov['totalWorkDays'] as num?)?.toInt() ??
              summary.totalWorkDays,
          lateCount:
              (ov['lateCount'] as num?)?.toInt() ?? summary.lateDays,
          overtimeDays: (ov['overtimeDays'] as num?)?.toInt() ??
              overtime.overtimeDaysCount,
          avgArrival: ov['avgArrival'] as String? ?? '--:--',
          avgDeparture: ov['avgDeparture'] as String? ?? '--:--',
          avgWorkDuration: ov['avgWorkDuration'] as String? ??
              summary.formattedAvgWorkDuration,
          totalOvertime: ov['totalOvertime'] as String? ??
              summary.formattedOvertime,
        );
      }

      // 解析 findings
      final findings = <AiFinding>[];
      if (json['findings'] != null) {
        for (final f in json['findings'] as List<dynamic>) {
          final fm = f as Map<String, dynamic>;
          findings.add(AiFinding(
            type: fm['type'] as String? ?? 'info',
            title: fm['title'] as String? ?? '',
            description: fm['description'] as String? ?? '',
          ));
        }
      }

      // 解析 suggestions
      final suggestions = <AiSuggestion>[];
      if (json['suggestions'] != null) {
        for (final s in json['suggestions'] as List<dynamic>) {
          final sm = s as Map<String, dynamic>;
          suggestions.add(AiSuggestion(
            priority: (sm['priority'] as num?)?.toInt() ?? 3,
            title: sm['title'] as String? ?? '',
            description: sm['description'] as String? ?? '',
          ));
        }
      }

      // 解析 scores
      final scores = <AiScore>[];
      if (json['scores'] != null) {
        for (final s in json['scores'] as List<dynamic>) {
          final sm = s as Map<String, dynamic>;
          scores.add(AiScore(
            name: sm['name'] as String? ?? '',
            value: (sm['value'] as num?)?.toDouble() ?? 0.0,
            label: sm['label'] as String? ?? '',
          ));
        }
      }

      return AiReport(
        type: type,
        periodLabel: periodLabel,
        generatedAt: DateTime.now().toIso8601String(),
        overview: overview,
        findings: findings,
        suggestions: suggestions,
        scores: scores,
        rawText: rawText,
        isSuccess: true,
      );
    } catch (e) {
      // 如果解析失败，返回包含原始文本的报告
      return AiReport(
        type: type,
        periodLabel: periodLabel,
        generatedAt: DateTime.now().toIso8601String(),
        rawText: rawText,
        isSuccess: false,
        error: '报告解析失败: $e',
      );
    }
  }

  /// 从 AI 返回文本中提取 JSON
  String _extractJson(String text) {
    // 尝试查找 ```json 代码块
    final jsonBlockRegExp = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)```');
    final match = jsonBlockRegExp.firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }

    // 尝试直接解析整个文本
    final trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    // 尝试查找第一个 { 到最后一个 }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }

    throw FormatException('无法从 AI 响应中提取 JSON: $text');
  }

  // ==================================================================
  //  日期范围 AI 报告生成
  // ==================================================================

  /// 对日期范围数据进行脱敏处理
  Map<String, dynamic> _anonymizePeriodData(
      PeriodSummary summary, OvertimeAnalysis? overtime) {
    final anonymizedDaily = <Map<String, dynamic>>[];
    int workDayIndex = 0;
    final weekDayNames = [
      '周一', '周二', '周三', '周四', '周五', '周六', '周日'
    ];

    for (final day in summary.dailyRecords) {
      if (day.isMissing) continue;
      workDayIndex++;

      final date = DateTime.tryParse(day.date);
      final weekDayName =
          date != null && date.weekday >= 1 && date.weekday <= 7
              ? weekDayNames[date.weekday - 1]
              : '未知';

      int? arrivalOffsetMin;
      int? departureOffsetMin;

      if (day.punchInTime != null) {
        arrivalOffsetMin =
            day.punchInTime!.hour * 60 + day.punchInTime!.minute;
      }
      if (day.punchOutTime != null) {
        departureOffsetMin =
            day.punchOutTime!.hour * 60 + day.punchOutTime!.minute;
      }

      anonymizedDaily.add({
        'workDay': '第$workDayIndex个工作日',
        'weekDay': weekDayName,
        'arrivalMinute': arrivalOffsetMin,
        'departureMinute': departureOffsetMin,
        'workMinutes': day.workDurationMinutes,
        'overtimeMinutes': day.overtimeMinutes,
        'isLate': day.isLate,
        'isEarlyLeave': day.isEarlyLeave,
        'punchInType': day.punchInType,
        'punchOutType': day.punchOutType,
      });
    }

    final result = <String, dynamic>{
      'period':
          '${summary.startDate} ~ ${summary.endDate}（已脱敏）',
      'totalDays': summary.totalDays,
      'attendedDays': summary.attendedDays,
      'onTimeDays': summary.onTimeDays,
      'lateDays': summary.lateDays,
      'earlyLeaveDays': summary.earlyLeaveDays,
      'avgWorkMinutes': summary.avgWorkMinutes,
      'totalOvertimeMinutes': summary.totalOvertimeMinutes,
      'fullDays': summary.fullDays,
      'dailyRecords': anonymizedDaily,
    };

    if (overtime != null) {
      result['overtimeAnalysis'] = {
        'totalOvertimeMinutes': overtime.totalOvertimeMinutes,
        'weekdayOvertimeMinutes': overtime.weekdayOvertimeMinutes,
        'weekendOvertimeMinutes': overtime.weekendOvertimeMinutes,
        'overtimeDaysCount': overtime.overtimeDaysCount,
        'maxOvertimeMinutes': overtime.maxOvertimeMinutes,
      };
    }

    return result;
  }

  /// 构建日期范围非脱敏数据
  Map<String, dynamic> _buildPeriodRawData(
      PeriodSummary summary, OvertimeAnalysis? overtime) {
    final result = <String, dynamic>{
      'period': '${summary.startDate} ~ ${summary.endDate}',
      'totalDays': summary.totalDays,
      'attendedDays': summary.attendedDays,
      'onTimeDays': summary.onTimeDays,
      'lateDays': summary.lateDays,
      'earlyLeaveDays': summary.earlyLeaveDays,
      'avgWorkMinutes': summary.avgWorkMinutes,
      'totalOvertimeMinutes': summary.totalOvertimeMinutes,
      'fullDays': summary.fullDays,
    };

    final dailyList = <Map<String, dynamic>>[];
    for (final day in summary.dailyRecords) {
      if (day.isMissing) continue;
      dailyList.add({
        'date': day.date,
        'punchInTime': day.punchInTime?.toIso8601String(),
        'punchOutTime': day.punchOutTime?.toIso8601String(),
        'workMinutes': day.workDurationMinutes,
        'overtimeMinutes': day.overtimeMinutes,
        'isLate': day.isLate,
        'isEarlyLeave': day.isEarlyLeave,
      });
    }
    result['dailyRecords'] = dailyList;

    if (overtime != null) {
      result['overtimeAnalysis'] = {
        'totalOvertimeMinutes': overtime.totalOvertimeMinutes,
        'weekdayOvertimeMinutes': overtime.weekdayOvertimeMinutes,
        'weekendOvertimeMinutes': overtime.weekendOvertimeMinutes,
        'overtimeDaysCount': overtime.overtimeDaysCount,
      };
    }

    return result;
  }

  /// 构建日期范围的提示词
  String _buildPeriodPrompt(PeriodSummary summary, OvertimeAnalysis overtime,
      AnomalyDetection anomalies, Map<String, dynamic> data) {
    final jsonData =
        const JsonEncoder.withIndent('  ').convert(data);

    return '''你是一个专业的考勤数据分析助手。请根据以下打卡数据分析结果，生成一份详细的工作习惯分析报告。

## 打卡数据

```json
$jsonData
```

## 异常检测

${anomalies.hasAnomalies ? _formatAnomalies(anomalies) : '该时间段未检测到异常打卡行为。'}

## 要求

请生成包含以下内容的 JSON 格式报告（不要包含 Markdown 代码块标记，只返回纯 JSON）：

```json
{
  "overview": {
    "summary": "一段 2-3 句话的工作概况总结",
    "attendedDays": ${summary.attendedDays},
    "totalWorkDays": ${summary.totalDays},
    "lateCount": ${summary.lateDays},
    "overtimeDays": ${overtime.overtimeDaysCount},
    "avgArrival": "平均到岗时间（如 09:12）",
    "avgDeparture": "平均离岗时间（如 18:30）",
    "avgWorkDuration": "${summary.formattedAvgWorkDuration}",
    "totalOvertime": "${summary.formattedOvertime}"
  },
  "findings": [
    {
      "type": "positive|negative|info",
      "title": "发现标题",
      "description": "详细描述，50-100字"
    }
  ],
  "suggestions": [
    {
      "priority": 1-5,
      "title": "建议标题",
      "description": "具体建议内容，50-100字"
    }
  ],
  "scores": [
    {
      "name": "出勤",
      "value": 0.0-5.0,
      "label": "出勤评分说明"
    }
  ]
}
```

注意事项：
1. findings 至少包含 2 条，最多 5 条
2. suggestions 至少包含 2 条，最多 4 条
3. scores 包含 3-4 个评分维度（如：出勤、准时、效率、平衡）
4. 所有描述使用中文，语气专业且友好
5. 基于实际数据给出具体、可操作的建议
6. 如果加班时间较多，请重点关注工作生活平衡
7. 如果迟到较多，请给出具体的通勤优化建议
''';
  }

  /// 生成日期范围 AI 分析报告
  Future<AiReport> generatePeriodReport(
      String startDate, String endDate) async {
    final config = await loadConfig();

    if (!config.isConfigured) {
      return AiReport.error(
        'period',
        '$startDate ~ $endDate',
        '请先在「AI 设置」中填入 API Key 以启用 AI 分析功能。',
      );
    }

    // 加载分析数据
    final analysisService = PunchAnalysisService();
    final summary =
        await analysisService.getPeriodSummary(startDate, endDate);
    final overtime = await analysisService.analyzeOvertimeByRange(
        startDate, endDate);
    final anomalies = await analysisService.detectAnomaliesByRange(
        startDate, endDate);

    // 脱敏（如果开启）
    final dataForAnalysis = config.anonymizeData
        ? _anonymizePeriodData(summary, overtime)
        : _buildPeriodRawData(summary, overtime);

    // 构建提示词
    final prompt = _buildPeriodPrompt(
        summary, overtime, anomalies, dataForAnalysis);
    final periodLabel = '$startDate ~ $endDate';

    // 调用 API
    try {
      final response = await _callDeepSeekApi(config, prompt);
      final report = _parseAiResponse(
        'period',
        periodLabel,
        response,
        // 构造一个虚拟的 MonthlySummary 传给 _parseAiResponse
        // 因为解析器只需要其中的几个字段
        MonthlySummary(
          year: int.tryParse(startDate.substring(0, 4)) ??
              DateTime.now().year,
          month: int.tryParse(startDate.substring(5, 7)) ??
              DateTime.now().month,
          attendedDays: summary.attendedDays,
          onTimeDays: summary.onTimeDays,
          lateDays: summary.lateDays,
          totalOvertimeMinutes: summary.totalOvertimeMinutes,
          dailyRecords: summary.dailyRecords,
        ),
        overtime,
        anomalies,
      );
      // 缓存到本地
      await saveReport(report);
      return report;
    } catch (e) {
      return AiReport.error(
        'period',
        periodLabel,
        'AI 分析请求失败: $e\n\n请检查 API Key 是否正确以及网络连接是否正常。',
      );
    }
  }

  // ==================================================================
  //  快捷方法
  // ==================================================================

  // ==================================================================
  //  报告缓存管理
  // ==================================================================

  /// 生成报告缓存键
  String _reportCacheKey(String type, String periodLabel) {
    return 'ai_report_${type}_$periodLabel';
  }

  /// 保存 AI 报告到本地缓存
  Future<void> saveReport(AiReport report) async {
    final key = _reportCacheKey(report.type, report.periodLabel);
    final json = jsonEncode(report.toJson());
    await _db.setSetting(key, json);
  }

  /// 从本地缓存加载 AI 报告
  Future<AiReport?> loadCachedReport(String type, String periodLabel) async {
    final key = _reportCacheKey(type, periodLabel);
    final json = await _db.getSetting(key);
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return AiReport.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// 获取报告的最后生成时间
  Future<DateTime?> getCachedReportTime(String type, String periodLabel) async {
    final report = await loadCachedReport(type, periodLabel);
    return report?.generatedDateTime;
  }

  /// 检查指定时间段是否已有缓存报告
  Future<bool> hasCachedReport(String type, String periodLabel) async {
    return await loadCachedReport(type, periodLabel) != null;
  }

  /// 检查 API Key 是否可用（发送一次简单请求验证）
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final config = AiConfig(apiKey: apiKey);
      final uri = Uri.parse('${config.apiBaseUrl}/models');

      final headers = {
        'Authorization': 'Bearer ${apiKey}',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// AI API 调用异常
class AiApiException implements Exception {
  final String message;
  final int statusCode;

  AiApiException(this.message, this.statusCode);

  @override
  String toString() => 'AiApiException($statusCode): $message';
}
