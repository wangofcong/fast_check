/// 打卡历史记录页面

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../models/punch_record.dart';
import '../l10n/l10n.dart';
import '../widgets/monthly_stats_card.dart';
import '../widgets/record_list_item.dart';
import 'punch_detail_screen.dart';

class PunchHistoryScreen extends StatefulWidget {
  const PunchHistoryScreen({super.key});

  @override
  State<PunchHistoryScreen> createState() => _PunchHistoryScreenState();
}

class _PunchHistoryScreenState extends State<PunchHistoryScreen> {
  late int _currentYear;
  late int _currentMonth;
  List<PunchRecord> _records = [];
  MonthlyStats? _stats;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reminder = context.read<ReminderProvider>();
      final records = await reminder.getRecordsByMonth(
          _currentYear, _currentMonth);

      records.sort((a, b) => b.date.compareTo(a.date));

      final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;
      int workDays = 0;
      for (int d = 1; d <= daysInMonth; d++) {
        final weekday = DateTime(_currentYear, _currentMonth, d).weekday;
        if (weekday >= 1 && weekday <= 5) workDays++;
      }

      if (mounted) {
        setState(() {
          _records = records;
          _stats = MonthlyStats.fromRecords(
            year: _currentYear,
            month: _currentMonth,
            records: records,
            totalWorkDays: workDays,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${L10n.analysisLoadingFailed}: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _goToPrevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
    _loadRecords();
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    if (_currentYear >= now.year && _currentMonth >= now.month) return;

    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
    _loadRecords();
  }

  bool get _isCurrentMonth =>
      _currentYear == DateTime.now().year &&
      _currentMonth == DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.historyTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_stats != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_stats!.attendedDays} ${L10n.days}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _loadRecords,
              icon: const Icon(Icons.refresh),
              label: Text(L10n.retry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          if (_stats != null)
            MonthlyStatsCard(
              stats: _stats!,
              onPrevMonth: _goToPrevMonth,
              onNextMonth: _goToNextMonth,
            ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  L10n.historyAllRecords,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${L10n.tr('共 ', 'Total: ')}${_records.length} ${L10n.tr('条', '')}',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          if (_records.isEmpty)
            _buildEmptyState()
          else
            ..._records.map((record) => RecordListItem(
                  record: record,
                  showDate: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PunchDetailScreen(record: record),
                      ),
                    );
                  },
                )),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.event_note, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _isCurrentMonth ? L10n.tr('本月暂无打卡记录', 'No records this month') : L10n.tr('该月暂无打卡记录', 'No records for this month'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCurrentMonth ? L10n.tr('开始打卡吧！', 'Start punching!') : L10n.tr('切换月份查看历史记录', 'Switch month to view history'),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
