/// 打卡记录列表项组件
///
/// 用于在打卡历史列表中展示单条记录

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/punch_record.dart';

class RecordListItem extends StatelessWidget {
  final PunchRecord record;
  final VoidCallback? onTap;
  final bool showDate;

  const RecordListItem({
    super.key,
    required this.record,
    this.onTap,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasPunchIn = record.punchInTime != null;
    final hasPunchOut = record.punchOutTime != null;
    final isComplete = hasPunchIn && hasPunchOut;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 状态图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(isComplete).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComplete
                      ? Icons.check_circle
                      : hasPunchIn
                          ? Icons.info_outline
                          : Icons.cancel_outlined,
                  color: _statusColor(isComplete),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // 日期 + 时间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDate)
                      Text(
                        _formatDate(record.date),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    if (showDate) const SizedBox(height: 4),
                    Row(
                      children: [
                        _TimeChip(
                          icon: Icons.login,
                          label: hasPunchIn
                              ? _formatTime(record.punchInTime!)
                              : L10n.listNotPunched,
                          color: hasPunchIn ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        _TimeChip(
                          icon: Icons.logout,
                          label: hasPunchOut
                              ? _formatTime(record.punchOutTime!)
                              : L10n.listNotPunched,
                          color: hasPunchOut ? Colors.indigo : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 右侧：工作时长 + 考勤状态
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (record.workDurationMinutes > 0)
                    Text(
                      _formatDuration(record.workDurationMinutes),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  const SizedBox(height: 2),
                  if (record.isLate == 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(L10n.listLate,
                          style: TextStyle(
                              fontSize: 10, color: Colors.red)),
                    ),
                  if (record.isEarlyLeave == 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(L10n.listEarlyLeave,
                          style: TextStyle(
                              fontSize: 10, color: Colors.orange)),
                    ),
                ],
              ),

              // 箭头
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(bool isComplete) {
    if (isComplete) return Colors.green;
    return Colors.orange;
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final weekday = L10n.homeDayOfWeek(dt.weekday);
      if (L10n.languageCode == 'zh') {
        return '${dt.month}月${dt.day}日 $weekday';
      }
      return '$weekday ${dt.month}/${dt.day}';
    } catch (_) {
      return date;
    }
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  String _formatDuration(int minutes) {
    return L10n.detailFormattedDuration(minutes);
  }
}

/// 时间标签
class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(label,
            style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}
