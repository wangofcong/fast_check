import 'dart:convert';

/// 上下班排班模型
///
/// 对应数据库表 `work_schedules`
/// 支持多组打卡时间段（轮班制/多办公地点）
class WorkSchedule {
  final int? id;
  final String name; // 排班名称，如 "工作日", "周末排班"
  final int isEnabled; // 0/1 是否启用
  final String punchInStart; // 上班开始时间 'HH:mm'
  final String punchInEnd; // 上班结束时间 'HH:mm'
  final String punchOutStart; // 下班开始时间 'HH:mm'
  final String punchOutEnd; // 下班结束时间 'HH:mm'
  final int? companyLocationId; // 关联的公司地点 ID
  final List<int> weekDays; // 适用星期 [1(周一)~7(周日)]
  final int sortOrder; // 排序
  final String createdAt;
  final String updatedAt;

  WorkSchedule({
    this.id,
    required this.name,
    this.isEnabled = 1,
    required this.punchInStart,
    required this.punchInEnd,
    required this.punchOutStart,
    required this.punchOutEnd,
    this.companyLocationId,
    this.weekDays = const [1, 2, 3, 4, 5],
    this.sortOrder = 0,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// 从数据库 Map 构造
  factory WorkSchedule.fromMap(Map<String, dynamic> map) {
    List<int> parsedDays = [];
    if (map['week_days'] != null && (map['week_days'] as String).isNotEmpty) {
      final list = jsonDecode(map['week_days'] as String) as List;
      parsedDays = list.map((e) => e as int).toList();
    }

    return WorkSchedule(
      id: map['id'] as int?,
      name: map['name'] as String,
      isEnabled: (map['is_enabled'] as int?) ?? 1,
      punchInStart: map['punch_in_start'] as String,
      punchInEnd: map['punch_in_end'] as String,
      punchOutStart: map['punch_out_start'] as String,
      punchOutEnd: map['punch_out_end'] as String,
      companyLocationId: map['company_location_id'] as int?,
      weekDays: parsedDays,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_enabled': isEnabled,
      'punch_in_start': punchInStart,
      'punch_in_end': punchInEnd,
      'punch_out_start': punchOutStart,
      'punch_out_end': punchOutEnd,
      'company_location_id': companyLocationId,
      'week_days': jsonEncode(weekDays),
      'sort_order': sortOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 判断今天是否适用此排班
  bool isTodayApplicable() {
    final today = DateTime.now().weekday;
    // DateTime.weekday: 1 (Mon) ~ 7 (Sun)
    return weekDays.contains(today);
  }

  WorkSchedule copyWith({
    int? id,
    String? name,
    int? isEnabled,
    String? punchInStart,
    String? punchInEnd,
    String? punchOutStart,
    String? punchOutEnd,
    int? companyLocationId,
    List<int>? weekDays,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) {
    return WorkSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      punchInStart: punchInStart ?? this.punchInStart,
      punchInEnd: punchInEnd ?? this.punchInEnd,
      punchOutStart: punchOutStart ?? this.punchOutStart,
      punchOutEnd: punchOutEnd ?? this.punchOutEnd,
      companyLocationId: companyLocationId ?? this.companyLocationId,
      weekDays: weekDays ?? this.weekDays,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  @override
  String toString() => 'WorkSchedule(id: $id, name: $name, '
      'in: $punchInStart~$punchInEnd, out: $punchOutStart~$punchOutEnd)';
}
