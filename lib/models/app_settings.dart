/// 应用设置模型（键值对存储）
///
/// 对应数据库表 `app_settings`
/// 以 key-value 方式存储所有应用配置项
class AppSetting {
  final String key;
  final String value;
  final String updatedAt;

  AppSetting({
    required this.key,
    required this.value,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// 从数据库 Map 构造
  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map['key'] as String,
      value: map['value'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() => 'AppSetting($key: $value)';
}

/// 预定义的设置键常量
class AppSettingKeys {
  AppSettingKeys._();

  /// 功能开关
  static const String reminderEnabled = 'reminder_enabled'; // 上下班打卡提醒
  static const String autoPunchEnabled = 'auto_punch_enabled'; // 自动打卡跳转
  static const String autoLocationPunchEnabled =
      'auto_location_punch_enabled'; // 上班自动打卡（位置触发）
  static const String delayPunchEnabled = 'delay_punch_enabled'; // 下班打卡延迟
  static const String aiSummaryEnabled = 'ai_summary_enabled'; // AI 总结

  /// 提醒配置
  static const String intervalMinutes = 'interval_minutes'; // 间隔提醒频率（分钟）
  static const String vibrationDuration =
      'vibration_duration'; // 震动持续时间（秒）

  /// 数据保留
  static const String dataRetentionDays = 'data_retention_days'; // 数据保留天数

  /// 首次启动
  static const String hasCompletedOnboarding =
      'has_completed_onboarding'; // 是否完成首次引导

  /// AI 配置
  static const String aiApiKey = 'ai_api_key'; // 用户自定义 API Key（加密存储）
  static const String aiModelName = 'ai_model_name'; // 模型名称
  static const String aiApiBaseUrl = 'ai_api_base_url'; // API 基础地址
  static const String aiAnonymizeData =
      'ai_anonymize_data'; // 是否脱敏数据（默认 true）

  /// 语言设置
  static const String appLanguage = 'app_language'; // 'zh' 或 'en'

  /// 数据导出
  static const String lastDataExportDate = 'last_data_export_date'; // 上次导出日期

  /// 默认值映射
  static const Map<String, String> defaults = {
    reminderEnabled: 'true',
    autoPunchEnabled: 'false',
    autoLocationPunchEnabled: 'false',
    delayPunchEnabled: 'false',
    aiSummaryEnabled: 'false',
    intervalMinutes: '5',
    vibrationDuration: '5',
    dataRetentionDays: '365',
    hasCompletedOnboarding: 'false',
    aiApiKey: '',
    aiModelName: 'deepseek-v4-flash',
    aiApiBaseUrl: 'https://api.deepseek.com/v1',
    aiAnonymizeData: 'true',
    appLanguage: '',
    lastDataExportDate: '',
  };
}
