/// 第三方 App 打卡跳转配置模型
///
/// 对应数据库表 `third_app_configs`
/// 存储企业微信、飞书等第三方打卡应用的跳转信息
class ThirdAppConfig {
  final int? id;
  final String name; // 显示名称，如 "企业微信", "飞书"
  final String? packageName; // Android 包名
  final String? urlScheme; // URL Scheme，如 'weixin://'
  final String? iosUniversalLink; // iOS Universal Link
  final int isWorkPunchIn; // 0/1 是否作为上班打卡目标
  final int isWorkPunchOut; // 0/1 是否作为下班打卡目标
  final String createdAt;
  final String updatedAt;

  ThirdAppConfig({
    this.id,
    required this.name,
    this.packageName,
    this.urlScheme,
    this.iosUniversalLink,
    this.isWorkPunchIn = 0,
    this.isWorkPunchOut = 0,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// 从数据库 Map 构造
  factory ThirdAppConfig.fromMap(Map<String, dynamic> map) {
    return ThirdAppConfig(
      id: map['id'] as int?,
      name: map['name'] as String,
      packageName: map['package_name'] as String?,
      urlScheme: map['url_scheme'] as String?,
      iosUniversalLink: map['ios_universal_link'] as String?,
      isWorkPunchIn: (map['is_work_punch_in'] as int?) ?? 0,
      isWorkPunchOut: (map['is_work_punch_out'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'package_name': packageName,
      'url_scheme': urlScheme,
      'ios_universal_link': iosUniversalLink,
      'is_work_punch_in': isWorkPunchIn,
      'is_work_punch_out': isWorkPunchOut,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ThirdAppConfig copyWith({
    int? id,
    String? name,
    String? packageName,
    String? urlScheme,
    String? iosUniversalLink,
    int? isWorkPunchIn,
    int? isWorkPunchOut,
    String? createdAt,
    String? updatedAt,
  }) {
    return ThirdAppConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      urlScheme: urlScheme ?? this.urlScheme,
      iosUniversalLink: iosUniversalLink ?? this.iosUniversalLink,
      isWorkPunchIn: isWorkPunchIn ?? this.isWorkPunchIn,
      isWorkPunchOut: isWorkPunchOut ?? this.isWorkPunchOut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  @override
  String toString() =>
      'ThirdAppConfig(id: $id, name: $name, scheme: $urlScheme)';
}
