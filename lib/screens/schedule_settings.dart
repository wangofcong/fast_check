import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/work_schedule.dart';

/// 排班设置页面
///
/// 管理用户的上下班排班规则，支持：
/// - 上班打卡时间范围 (punch_in_start ~ punch_in_end)
/// - 下班打卡时间范围 (punch_out_start ~ punch_out_end)
/// - 适用星期
/// - 关联公司地点（可选）
class ScheduleSettingsScreen extends StatelessWidget {
  const ScheduleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.scheduleTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: L10n.scheduleAdd,
            onPressed: () => _showScheduleEditDialog(context, provider, null),
          ),
        ],
      ),
      body: provider.schedules.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(L10n.scheduleNoData,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(L10n.scheduleAdd),
                    onPressed: () =>
                        _showScheduleEditDialog(context, provider, null),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.schedules.length,
              itemBuilder: (context, index) {
                final schedule = provider.schedules[index];
                return _ScheduleCard(
                  schedule: schedule,
                  onEdit: () => _showScheduleEditDialog(
                      context, provider, schedule),
                  onToggle: () {
                    final updated = schedule.copyWith(
                        isEnabled: schedule.isEnabled == 1 ? 0 : 1);
                    provider.updateSchedule(updated);
                  },
                  onDelete: () => _confirmDelete(context, provider, schedule),
                );
              },
            ),
    );
  }

  void _confirmDelete(
      BuildContext context, SettingsProvider provider, WorkSchedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.scheduleDeleteTitle),
        content: Text(L10n.scheduleDeleteMsg(schedule.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteSchedule(schedule.id!);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(L10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showScheduleEditDialog(BuildContext context,
      SettingsProvider provider, WorkSchedule? existing) async {
    final isEditing = existing != null;
    final nameCtrl =
        TextEditingController(text: isEditing ? existing.name : '');
    final inStartCtrl =
        TextEditingController(text: isEditing ? existing.punchInStart : '09:00');
    final inEndCtrl =
        TextEditingController(text: isEditing ? existing.punchInEnd : '11:00');
    final outStartCtrl =
        TextEditingController(text: isEditing ? existing.punchOutStart : '17:00');
    final outEndCtrl =
        TextEditingController(text: isEditing ? existing.punchOutEnd : '19:00');

    List<int> selectedDays =
        isEditing ? List.from(existing.weekDays) : [1, 2, 3, 4, 5];
    int? selectedLocationId = isEditing ? existing.companyLocationId : null;

    final locations = provider.locations;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(isEditing ? L10n.scheduleEdit : L10n.scheduleAdd),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: L10n.scheduleName,
                        hintText: L10n.tr('例如：工作日排班', 'e.g. Workday Schedule'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 上班打卡时间范围
                    Text(L10n.schedulePunchInRange,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TimePickerField(
                            controller: inStartCtrl,
                            label: L10n.tr('开始', 'Start'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: _TimePickerField(
                            controller: inEndCtrl,
                            label: L10n.tr('截止', 'End'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 下班打卡时间范围
                    Text(L10n.schedulePunchOutRange,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TimePickerField(
                            controller: outStartCtrl,
                            label: L10n.tr('开始', 'Start'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: _TimePickerField(
                            controller: outEndCtrl,
                            label: L10n.tr('截止', 'End'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 适用星期
                    Text(L10n.scheduleApplyWeekDays,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: List.generate(7, (i) {
                        final day = i + 1;
                        final labels = [
                          L10n.scheduleMon, L10n.scheduleTue, L10n.scheduleWed,
                          L10n.scheduleThu, L10n.scheduleFri, L10n.scheduleSat,
                          L10n.scheduleSun
                        ];
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(labels[i]),
                          selected: isSelected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // 关联公司地点（可选）
                    if (locations.isNotEmpty) ...[
                      Text(L10n.scheduleLinkLocation,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int?>(
                        value: selectedLocationId,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: L10n.scheduleNoLink,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(L10n.scheduleNoLink),
                          ),
                          ...locations.map((loc) => DropdownMenuItem(
                                value: loc.id,
                                child: Text(
                                    '${loc.name} · ${loc.geofenceRadius}m'),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => selectedLocationId = v),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(L10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    if (selectedDays.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(L10n.scheduleSelectWeekday)),
                      );
                      return;
                    }
                    if (!_isValidTime(inStartCtrl.text) ||
                        !_isValidTime(inEndCtrl.text) ||
                        !_isValidTime(outStartCtrl.text) ||
                        !_isValidTime(outEndCtrl.text)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(L10n.scheduleInvalidTime)),
                      );
                      return;
                    }

                    final schedule = WorkSchedule(
                      id: isEditing ? existing.id : null,
                      name: nameCtrl.text.trim(),
                      punchInStart: inStartCtrl.text.trim(),
                      punchInEnd: inEndCtrl.text.trim(),
                      punchOutStart: outStartCtrl.text.trim(),
                      punchOutEnd: outEndCtrl.text.trim(),
                      weekDays: selectedDays,
                      companyLocationId: selectedLocationId,
                      sortOrder: isEditing ? existing.sortOrder : 0,
                    );

                    if (isEditing) {
                      provider.updateSchedule(schedule);
                    } else {
                      provider.addSchedule(schedule);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(L10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isValidTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }
}

/// 时间选择输入框组件
class _TimePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TimePickerField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:mm',
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: IconButton(
          icon: const Icon(Icons.access_time, size: 20),
          onPressed: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _parseTime(controller.text),
            );
            if (time != null) {
              controller.text =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            }
          },
        ),
      ),
      keyboardType: TextInputType.datetime,
    );
  }

  TimeOfDay _parseTime(String text) {
    final parts = text.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 9;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }
}

/// 排班卡片组件
class _ScheduleCard extends StatelessWidget {
  final WorkSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dayLabels = [
      L10n.scheduleMon, L10n.scheduleTue, L10n.scheduleWed,
      L10n.scheduleThu, L10n.scheduleFri, L10n.scheduleSat,
      L10n.scheduleSun
    ];
    final daysStr =
        schedule.weekDays.map((d) => dayLabels[d - 1]).join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  schedule.isEnabled == 1
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 20,
                  color: schedule.isEnabled == 1 ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    schedule.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20,
                      color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.wb_sunny, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text('${L10n.schedulePunchInLabel}${schedule.punchInStart}~${schedule.punchInEnd}'),
                const SizedBox(width: 16),
                const Icon(Icons.nights_stay, size: 16, color: Colors.indigo),
                const SizedBox(width: 4),
                Text('${L10n.schedulePunchOutLabel}${schedule.punchOutStart}~${schedule.punchOutEnd}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_view_week,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${L10n.scheduleWeekly}$daysStr',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
