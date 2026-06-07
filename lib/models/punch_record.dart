/// 打卡记录模型
///
/// 对应数据库表 `punch_records`
/// 存储每一次上下班打卡的详细信息
class PunchRecord {
  final int? id;
  final String date; // 日期 'YYYY-MM-DD'
  final String? punchInTime; // 上班打卡时间 'yyyy-MM-dd HH:mm:ss'
  final String? punchOutTime; // 下班打卡时间 'yyyy-MM-dd HH:mm:ss'
  final String? punchInType; // 'manual' | 'auto_jump' | 'auto_location'
  final String? punchOutType; // 'manual' | 'auto_jump' | 'auto_location'
  final int isLate; // 0/1 是否迟到
  final int isEarlyLeave; // 0/1 是否早退
  final int overtimeMinutes; // 加班分钟数
  final int workDurationMinutes; // 实际工作时长（分钟）
  final String? notes; // 用户备注
  final int? scheduleGroupId; // 关联的排班 ID
  final String createdAt; // 创建时间
  final String updatedAt; // 更新时间

  PunchRecord({
    this.id,
    required this.date,
    this.punchInTime,
    this.punchOutTime,
    this.punchInType,
    this.punchOutType,
    this.isLate = 0,
    this.isEarlyLeave = 0,
    this.overtimeMinutes = 0,
    this.workDurationMinutes = 0,
    this.notes,
    this.scheduleGroupId,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// 从数据库 Map 构造
  factory PunchRecord.fromMap(Map<String, dynamic> map) {
    return PunchRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      punchInTime: map['punch_in_time'] as String?,
      punchOutTime: map['punch_out_time'] as String?,
      punchInType: map['punch_in_type'] as String?,
      punchOutType: map['punch_out_type'] as String?,
      isLate: (map['is_late'] as int?) ?? 0,
      isEarlyLeave: (map['is_early_leave'] as int?) ?? 0,
      overtimeMinutes: (map['overtime_minutes'] as int?) ?? 0,
      workDurationMinutes: (map['work_duration_minutes'] as int?) ?? 0,
      notes: map['notes'] as String?,
      scheduleGroupId: map['schedule_group_id'] as int?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'punch_in_time': punchInTime,
      'punch_out_time': punchOutTime,
      'punch_in_type': punchInType,
      'punch_out_type': punchOutType,
      'is_late': isLate,
      'is_early_leave': isEarlyLeave,
      'overtime_minutes': overtimeMinutes,
      'work_duration_minutes': workDurationMinutes,
      'notes': notes,
      'schedule_group_id': scheduleGroupId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 创建副本并更新字段
  PunchRecord copyWith({
    int? id,
    String? date,
    String? punchInTime,
    String? punchOutTime,
    String? punchInType,
    String? punchOutType,
    int? isLate,
    int? isEarlyLeave,
    int? overtimeMinutes,
    int? workDurationMinutes,
    String? notes,
    int? scheduleGroupId,
    String? createdAt,
    String? updatedAt,
  }) {
    return PunchRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      punchInType: punchInType ?? this.punchInType,
      punchOutType: punchOutType ?? this.punchOutType,
      isLate: isLate ?? this.isLate,
      isEarlyLeave: isEarlyLeave ?? this.isEarlyLeave,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      workDurationMinutes: workDurationMinutes ?? this.workDurationMinutes,
      notes: notes ?? this.notes,
      scheduleGroupId: scheduleGroupId ?? this.scheduleGroupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  @override
  String toString() =>
      'PunchRecord(id: $id, date: $date, punchIn: $punchInTime, punchOut: $punchOutTime)';
}
