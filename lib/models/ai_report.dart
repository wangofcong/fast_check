/// AI 报告数据模型
///
/// 包含 AI 生成的各类报告数据结构：
/// - [AiReport] 完整 AI 报告
/// - [AiFinding] 关键发现
/// - [AiSuggestion] 改进建议
/// - [AiScore] 评分项

/// AI 生成的完整报告
class AiReport {
  /// 报告类型：daily / weekly / monthly / manual
  final String type;

  /// 报告覆盖的时间范围
  final String periodLabel;

  /// 报告生成时间
  final String generatedAt;

  /// 月度概况
  final AiOverview? overview;

  /// 关键发现列表
  final List<AiFinding> findings;

  /// 改进建议列表
  final List<AiSuggestion> suggestions;

  /// 各项评分
  final List<AiScore> scores;

  /// 原始 AI 返回文本（用于调试）
  final String rawText;

  /// 是否成功生成
  final bool isSuccess;

  /// 错误信息（如果有）
  final String? error;

  AiReport({
    required this.type,
    required this.periodLabel,
    required this.generatedAt,
    this.overview,
    this.findings = const [],
    this.suggestions = const [],
    this.scores = const [],
    this.rawText = '',
    this.isSuccess = true,
    this.error,
  });

  /// 创建一个错误报告
  factory AiReport.error(String type, String periodLabel, String errorMsg) {
    return AiReport(
      type: type,
      periodLabel: periodLabel,
      generatedAt: DateTime.now().toIso8601String(),
      isSuccess: false,
      error: errorMsg,
    );
  }

  /// 解析 generatedAt 为 DateTime
  DateTime get generatedDateTime => DateTime.tryParse(generatedAt) ?? DateTime.now();

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'type': type,
        'periodLabel': periodLabel,
        'generatedAt': generatedAt,
        'overview': overview?.toJson(),
        'findings': findings.map((f) => f.toJson()).toList(),
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
        'scores': scores.map((s) => s.toJson()).toList(),
        'rawText': rawText,
        'isSuccess': isSuccess,
        'error': error,
      };

  /// 从 JSON 反序列化
  factory AiReport.fromJson(Map<String, dynamic> json) => AiReport(
        type: json['type'] as String? ?? '',
        periodLabel: json['periodLabel'] as String? ?? '',
        generatedAt: json['generatedAt'] as String? ?? '',
        overview: json['overview'] != null
            ? AiOverview.fromJson(json['overview'] as Map<String, dynamic>)
            : null,
        findings: (json['findings'] as List<dynamic>?)
                ?.map((f) =>
                    AiFinding.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
        suggestions: (json['suggestions'] as List<dynamic>?)
                ?.map((s) =>
                    AiSuggestion.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        scores: (json['scores'] as List<dynamic>?)
                ?.map(
                    (s) => AiScore.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        rawText: json['rawText'] as String? ?? '',
        isSuccess: json['isSuccess'] as bool? ?? true,
        error: json['error'] as String?,
      );
}

/// AI 报告中的概况
class AiOverview {
  final String summary;
  final int attendedDays;
  final int totalWorkDays;
  final int lateCount;
  final int overtimeDays;
  final String avgArrival;
  final String avgDeparture;
  final String avgWorkDuration;
  final String totalOvertime;

  AiOverview({
    required this.summary,
    this.attendedDays = 0,
    this.totalWorkDays = 0,
    this.lateCount = 0,
    this.overtimeDays = 0,
    this.avgArrival = '--:--',
    this.avgDeparture = '--:--',
    this.avgWorkDuration = '0h',
    this.totalOvertime = '0h',
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'attendedDays': attendedDays,
        'totalWorkDays': totalWorkDays,
        'lateCount': lateCount,
        'overtimeDays': overtimeDays,
        'avgArrival': avgArrival,
        'avgDeparture': avgDeparture,
        'avgWorkDuration': avgWorkDuration,
        'totalOvertime': totalOvertime,
      };

  factory AiOverview.fromJson(Map<String, dynamic> json) => AiOverview(
        summary: json['summary'] as String? ?? '',
        attendedDays: (json['attendedDays'] as num?)?.toInt() ?? 0,
        totalWorkDays: (json['totalWorkDays'] as num?)?.toInt() ?? 0,
        lateCount: (json['lateCount'] as num?)?.toInt() ?? 0,
        overtimeDays: (json['overtimeDays'] as num?)?.toInt() ?? 0,
        avgArrival: json['avgArrival'] as String? ?? '--:--',
        avgDeparture: json['avgDeparture'] as String? ?? '--:--',
        avgWorkDuration: json['avgWorkDuration'] as String? ?? '0h',
        totalOvertime: json['totalOvertime'] as String? ?? '0h',
      );
}

/// 关键发现
class AiFinding {
  final String type; // positive / negative / info
  final String title;
  final String description;
  final String? iconEmoji;

  AiFinding({
    required this.type,
    required this.title,
    required this.description,
    this.iconEmoji,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'description': description,
        'iconEmoji': iconEmoji,
      };

  factory AiFinding.fromJson(Map<String, dynamic> json) => AiFinding(
        type: json['type'] as String? ?? 'info',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconEmoji: json['iconEmoji'] as String?,
      );
}

/// 改进建议
class AiSuggestion {
  final int priority; // 1~5, 1=最高
  final String title;
  final String description;
  final String? iconEmoji;

  AiSuggestion({
    this.priority = 3,
    required this.title,
    required this.description,
    this.iconEmoji,
  });

  Map<String, dynamic> toJson() => {
        'priority': priority,
        'title': title,
        'description': description,
        'iconEmoji': iconEmoji,
      };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        priority: (json['priority'] as num?)?.toInt() ?? 3,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconEmoji: json['iconEmoji'] as String?,
      );
}

/// 评分项
class AiScore {
  final String name;
  final double value; // 0.0 ~ 5.0
  final String label;

  AiScore({
    required this.name,
    required this.value,
    required this.label,
  });

  /// 星级显示（满星 5）
  int get starCount => value.round().clamp(0, 5);

  /// 评分百分比
  double get percentage => (value / 5.0).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'label': label,
      };

  factory AiScore.fromJson(Map<String, dynamic> json) => AiScore(
        name: json['name'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        label: json['label'] as String? ?? '',
      );
}

/// AI 配置信息（本地存储，不包含 API Key 明文）
class AiConfig {
  final String modelName;
  final String apiBaseUrl;
  final bool anonymizeData;

  /// API Key（仅内存中持有，不持久化明文）
  final String apiKey;

  AiConfig({
    this.modelName = 'deepseek-v4-flash',
    this.apiBaseUrl = 'https://api.deepseek.com/v1',
    this.anonymizeData = true,
    this.apiKey = '',
  });

  /// 是否已配置有效的 API Key
  bool get isConfigured => apiKey.isNotEmpty;

  /// 复制并修改
  AiConfig copyWith({
    String? modelName,
    String? apiBaseUrl,
    bool? anonymizeData,
    String? apiKey,
  }) {
    return AiConfig(
      modelName: modelName ?? this.modelName,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      anonymizeData: anonymizeData ?? this.anonymizeData,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
