/// 数据管理页面
///
/// 数据管理功能包含：
/// - 数据统计概览
/// - 数据保留天数设置
/// - 数据导出（CSV）
/// - 数据清理（按保留天数清理旧记录）
import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../services/punch_analysis_service.dart';
import '../models/app_settings.dart';

class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final PunchAnalysisService _analysisService = PunchAnalysisService();
  Map<String, dynamic> _dbStats = {};
  int _recordCount = 0;
  bool _isLoading = true;
  bool _isCleaning = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      _dbStats = await _analysisService.getDatabaseStats();
      _recordCount = await _analysisService.getTotalRecordCount();
    } catch (_) {
      // ignore
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ==================================================================
  //  数据清理
  // ==================================================================

  Future<void> _cleanOldData() async {
    final provider = context.read<SettingsProvider>();
    final retentionDays = provider.dataRetentionDays;

    if (retentionDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.tr('数据保留已设为永久保存，无需清理',
              'Data retention is set to permanent, no cleanup needed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 确认清理
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.tr('确认清理', 'Confirm Cleanup')),
        content: Text(
          L10n.tr(
            '将清理 $retentionDays 天之前的所有打卡记录。\n'
            '此操作不可恢复，请确认是否清理？',
            'Records older than $retentionDays days will be deleted.\n'
            'This cannot be undone. Confirm?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.tr('清理所有数据', 'Clear All Data')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCleaning = true);

    try {
      final deletedCount = await _analysisService.cleanOldRecords(retentionDays);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.tr(
                '已清理 $deletedCount 条记录', 'Cleaned $deletedCount records')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.tr('清理失败: ', 'Cleanup failed: ') + '$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _isCleaning = false);
  }

  // ==================================================================
  //  数据导出 (CSV)
  // ==================================================================

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final records = await _db.getPunchRecordsByDateRange(
        '2000-01-01',
        DateTime.now().toIso8601String().substring(0, 10),
      );

      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.tr('暂无打卡记录可导出', 'No records to export')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 生成 CSV 内容
      final csvBuffer = StringBuffer();

      // CSV 表头
      csvBuffer.writeln(
          L10n.tr('日期,上班时间,下班时间,打卡方式(上),打卡方式(下),迟到,早退,加班时长(分钟),工作时长,备注',
              'Date,Punch In,Punch Out,In Method,Out Method,Late,Early Leave,Overtime(min),Duration,Notes'));

      // CSV 数据行
      for (final r in records) {
        final date = r.date;
        final punchIn = r.punchInTime ?? '';
        final punchOut = r.punchOutTime ?? '';
        final inType = r.punchInType ?? '';
        final outType = r.punchOutType ?? '';
        final isLate = r.isLate == 1 ? '是' : '否';
        final isEarlyLeave = r.isEarlyLeave == 1 ? '是' : '否';
        final overtime = r.overtimeMinutes.toString();
        final duration = r.workDurationMinutes.toString();
        final notes = _escapeCsvField(r.notes ?? '');

        csvBuffer.writeln(
          '$date,$punchIn,$punchOut,$inType,$outType,$isLate,$isEarlyLeave,$overtime,$duration,$notes',
        );
      }

      // 保存文件
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '打卡记录_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvBuffer.toString());

      // 记录最后导出时间
      await _db.setSetting(
        AppSettingKeys.lastDataExportDate,
        DateTime.now().toIso8601String(),
      );

      if (mounted) {
        // 使用 share_plus 分享文件
        try {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: L10n.tr(
                '打卡记录导出 - ${records.length} 条记录',
                'Punch Records Export - ${records.length} records'),
          );
        } catch (_) {
          // 分享失败时提示文件路径
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.tr('文件已保存: ', 'File saved: ') + '${file.path}'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: L10n.ok,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.tr('导出失败: ', 'Export failed: ') + '$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _isExporting = false);
  }

  /// 转义 CSV 字段中的特殊字符
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ==================================================================
  //  UI
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final retentionDays = provider.dataRetentionDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.dataSettingsTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- 数据统计卡片 ----
                _buildStatsCard(),
                const SizedBox(height: 16),

                // ---- 保留天数 ----
                Text(
                  L10n.settingsDataRetention,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _buildRetentionOptions(provider),
                const SizedBox(height: 16),

                // ---- 数据操作 ----
                Text(
                  L10n.tr('操作', 'Actions'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download, color: Colors.blue),
                        title: Text(L10n.dataSettingsExport),
                        subtitle: Text(L10n.tr('导出为 CSV 格式，可用 Excel 打开',
                            'Export as CSV, openable in Excel')),
                        trailing: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isExporting ? null : _exportData,
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep, color: Colors.red),
                        title: Text(L10n.tr('清理旧数据', 'Clean Old Data')),
                        subtitle: Text(
                          retentionDays > 0
                              ? L10n.tr('保留 $retentionDays 天内的记录',
                                  'Keep records within $retentionDays days')
                              : L10n.tr('永久保存，不自动清理',
                                  'Permanent storage, no auto-cleanup'),
                        ),
                        trailing: _isCleaning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isCleaning ? null : _cleanOldData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- 数据说明 ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr('数据说明', 'About Data'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          L10n.tr(
                            '所有打卡数据存储在本地设备上，不会上传到任何服务器。\n'
                            '导出数据为 CSV 格式，可以用 Excel、WPS 等软件打开。\n'
                            '清理旧数据操作不可恢复，请谨慎操作。',
                            'All data is stored locally and never uploaded.\n'
                            'Exported data is in CSV format, openable with Excel.\n'
                            'Cleanup operation is irreversible, please use with caution.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.dataSettingsStats,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statItem(Icons.fact_check, L10n.dataSettingsRecordCount, '${_recordCount}'),
                _statItem(
                    Icons.schedule, L10n.dataSettingsScheduleLabel, '${_dbStats['work_schedules'] ?? 0}'),
                _statItem(Icons.location_on, L10n.dataSettingsLocationLabel,
                    '${_dbStats['company_locations'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statItem(Icons.timer, L10n.tr('延迟记录', 'Delay Records'),
                    '${_dbStats['delay_records'] ?? 0}'),
                _statItem(Icons.phone_android, L10n.dataSettingsAppConfigLabel,
                    '${_dbStats['third_app_configs'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRetentionOptions(SettingsProvider provider) {
    final options = [
      {'days': 30, 'label': '30 天'},
      {'days': 90, 'label': '3 个月'},
      {'days': 180, 'label': '6 个月'},
      {'days': 365, 'label': '1 年'},
      {'days': 730, 'label': '2 年'},
      {'days': -1, 'label': L10n.tr('永久保存', 'Keep Forever')},
    ];

    return Card(
      child: Column(
        children: options.map((opt) {
          final days = opt['days'] as int;
          final label = opt['label'] as String;

          return RadioListTile<int>(
            title: Text(label),
            subtitle: days > 0
                ? Text(L10n.tr('保留最近 $days 天的打卡记录',
                    'Keep records from the last $days days'))
                : null,
            value: days,
            groupValue: provider.dataRetentionDays,
            onChanged: (v) {
              if (v != null) {
                provider.setDataRetentionDays(v);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
