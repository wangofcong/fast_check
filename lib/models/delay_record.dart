/// 下班打卡延迟记录模型
///
/// 对应数据库表 `delay_records`
/// 记录用户每次使用「下班打卡延迟」功能时的操作历史
class DelayRecord {
  final int? id;
  final String date; // 日期 'YYYY-MM-DD'
  final int? scheduleGroupId; // 关联的排班 ID
  final int delayMinutes; // 延迟的分钟数
  final String? reason; // 延迟原因（用户备注，可选）
  final String createdAt;

  DelayRecord({
    this.id,
    required this.date,
    this.scheduleGroupId,
    required this.delayMinutes,
    this.reason,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  /// 从数据库 Map 构造
  factory DelayRecord.fromMap(Map<String, dynamic> map) {
    return DelayRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      scheduleGroupId: map['schedule_group_id'] as int?,
      delayMinutes: map['delay_minutes'] as int,
      reason: map['reason'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'schedule_group_id': scheduleGroupId,
      'delay_minutes': delayMinutes,
      'reason': reason,
      'created_at': createdAt,
    };
  }

  @override
  String toString() =>
      'DelayRecord(id: $id, date: $date, delay: ${delayMinutes}min)';
}
