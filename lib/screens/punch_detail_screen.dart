/// 打卡记录详情页面
///
/// 展示单条打卡记录的完整信息

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/punch_record.dart';
import '../services/database_service.dart';

class PunchDetailScreen extends StatefulWidget {
  final PunchRecord record;

  const PunchDetailScreen({super.key, required this.record});

  @override
  State<PunchDetailScreen> createState() => _PunchDetailScreenState();
}

class _PunchDetailScreenState extends State<PunchDetailScreen> {
  late PunchRecord _record;
  late TextEditingController _notesCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _notesCtrl = TextEditingController(text: _record.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      final updated = _record.copyWith(
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await db.updatePunchRecord(updated);
      setState(() {
        _record = updated;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.detailNotesSaved)),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.detailSaveFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    String weekdayStr = '--';
    try {
      final dt = DateTime.parse(r.date);
      weekdayStr = L10n.homeDayOfWeek(dt.weekday);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Text('${r.date} $weekdayStr'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 打卡状态总览 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _isComplete(r) ? Icons.check_circle : Icons.info_outline,
                    size: 56,
                    color: _isComplete(r) ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isComplete(r) ? L10n.detailComplete : L10n.detailPartial,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.date,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 打卡时间 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.detailPunchTimes,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Divider(),
                  _detailRow(
                    context,
                    Icons.login,
                    L10n.detailPunchInTime,
                    _formatTime(r.punchInTime),
                    r.punchInType ?? '--',
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    Icons.logout,
                    L10n.detailPunchOutTime,
                    _formatTime(r.punchOutTime),
                    r.punchOutType ?? '--',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- 考勤详情 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.detailAttendanceInfo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Divider(),
                  _statusRow(L10n.detailWorkDuration, _formatDuration(r.workDurationMinutes)),
                  const SizedBox(height: 8),
                  _statusRow(L10n.historyLate,
                      r.isLate == 1 ? L10n.detailYes : L10n.detailNo,
                      valueColor: r.isLate == 1 ? Colors.red : Colors.green),
                  const SizedBox(height: 8),
                  _statusRow(L10n.historyEarlyLeave,
                      r.isEarlyLeave == 1 ? L10n.detailYes : L10n.detailNo,
                      valueColor:
                          r.isEarlyLeave == 1 ? Colors.orange : Colors.green),
                  const SizedBox(height: 8),
                  _statusRow(L10n.detailOvertime, _formatDuration(r.overtimeMinutes)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- 备注 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(L10n.detailNotes,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (_isSaving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const Divider(),
                  TextField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(
                      hintText: L10n.detailAddNotes,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _isSaving ? null : _saveNotes,
                      icon: const Icon(Icons.save, size: 18),
                      label: Text(L10n.detailSaveNotes),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- 元数据 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.detailMetaInfo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Divider(),
                  _metaRow(L10n.detailRecordId, '${r.id ?? '--'}'),
                  _metaRow(L10n.detailScheduleId, '${r.scheduleGroupId ?? '--'}'),
                  _metaRow(L10n.detailCreatedAt, _formatIso(r.createdAt)),
                  _metaRow(L10n.detailUpdatedAt, _formatIso(r.updatedAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _isComplete(PunchRecord r) =>
      r.punchInTime != null && r.punchOutTime != null;

  String _formatTime(String? isoTime) {
    if (isoTime == null) return L10n.detailNotPunched;
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  String _formatDuration(int minutes) {
    return L10n.detailFormattedDuration(minutes);
  }

  String _formatIso(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, String time, String type) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text(time,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _typeLabel(type),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'manual':
        return L10n.detailManual;
      case 'auto_jump':
        return L10n.detailAutoJump;
      case 'auto_location':
        return L10n.detailAutoLocation;
      default:
        return type;
    }
  }

  Widget _statusRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            )),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
