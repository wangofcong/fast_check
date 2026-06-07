import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/location_provider.dart';
import '../providers/reminder_provider.dart';
import '../models/punch_record.dart';
import '../l10n/l10n.dart';
import '../main.dart' as app;
import 'settings_screen.dart';
import 'status_screen.dart';

/// 首页仪表盘
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PunchRecord> _weeklyRecords = [];
  bool _loadingRecords = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadAll();
      final settings = context.read<SettingsProvider>();
      if (settings.reminderEnabled) {
        context.read<ReminderProvider>().start();
      }
      _loadWeeklyRecords();
    });
  }

  Future<void> _loadWeeklyRecords() async {
    setState(() => _loadingRecords = true);
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));
      final startDate =
          '${sevenDaysAgo.year}-${sevenDaysAgo.month.toString().padLeft(2, '0')}-${sevenDaysAgo.day.toString().padLeft(2, '0')}';
      final endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final records =
          await context.read<ReminderProvider>().getRecordsByDateRange(startDate, endDate);
      if (mounted) {
        setState(() {
          _weeklyRecords = records;
          _loadingRecords = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final reminder = context.watch<ReminderProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: L10n.homeTooltipMenu,
          onPressed: () {
            app.MainScaffold.scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(L10n.homeTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart),
            tooltip: L10n.homeTooltipStatus,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatusScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              reminder.isEngineRunning
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: reminder.isEngineRunning ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              location.isInsideGeofence
                  ? Icons.my_location
                  : Icons.location_searching,
              color: location.isInsideGeofence ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: L10n.homeTooltipSettings,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ReminderProvider>().forceCheck();
          await _loadWeeklyRecords();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodayPunchCard(context, reminder),
              const SizedBox(height: 16),
              _buildWeeklyRecordsSection(context, reminder),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayPunchCard(BuildContext context, ReminderProvider reminder) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.today, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(L10n.homeTodayPunch,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                Switch(
                  value: reminder.isEngineRunning,
                  onChanged: (v) {
                    if (v) {
                      context.read<ReminderProvider>().start();
                    } else {
                      context.read<ReminderProvider>().stop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow(context, Icons.schedule, L10n.homeCurrentPeriod,
                reminder.currentWindowDescription, Colors.blue),
            const SizedBox(height: 8),
            _buildStatusRow(context, Icons.calendar_today, L10n.homeScheduleName,
                reminder.todayScheduleName, Colors.teal),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.check_circle,
              L10n.homePunchIn,
              reminder.hasPunchedIn
                  ? '${L10n.homeAlreadyPunchedIn} (${_formatTime(reminder.todayRecord?.punchInTime)})'
                  : L10n.homeNotPunchedIn,
              reminder.hasPunchedIn ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.check_circle,
              L10n.homePunchOut,
              reminder.hasPunchedOut
                  ? '${L10n.homeAlreadyPunchedOut} (${_formatTime(reminder.todayRecord?.punchOutTime)})'
                  : L10n.homeNotPunchedOut,
              reminder.hasPunchedOut ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(context, Icons.timer, L10n.homeWorkDuration,
                reminder.formattedWorkDuration, Colors.indigo),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: reminder.hasPunchedIn
                        ? null
                        : () =>
                            context.read<ReminderProvider>().manualPunchIn(),
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(L10n.homePunchIn),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !reminder.hasPunchedIn || reminder.hasPunchedOut
                        ? null
                        : () =>
                            context.read<ReminderProvider>().manualPunchOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(L10n.homePunchOut),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyRecordsSection(
      BuildContext context, ReminderProvider reminder) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(L10n.homeWeeklyRecords,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (!_loadingRecords)
                  TextButton.icon(
                    onPressed: _loadWeeklyRecords,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(L10n.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingRecords)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_weeklyRecords.isEmpty)
              _buildEmptyRecords(context)
            else
              ..._weeklyRecords.map((r) => _buildRecordRow(context, r)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecords(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(L10n.homeNoRecords,
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordRow(BuildContext context, PunchRecord record) {
    String displayDate = record.date;
    String weekday = '';
    try {
      final dt = DateTime.parse(record.date);
      final now = DateTime.now();
      bool isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      weekday = isToday ? L10n.homeTodayLabel : L10n.homeDayOfWeek(dt.weekday);
    } catch (_) {}

    final hasIn = record.punchInTime != null;
    final hasOut = record.punchOutTime != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hasOut
                  ? Colors.green.withValues(alpha: 0.1)
                  : hasIn
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasOut
                  ? Icons.check_circle
                  : hasIn
                      ? Icons.access_time
                      : Icons.cancel,
              size: 20,
              color: hasOut
                  ? Colors.green
                  : hasIn
                      ? Colors.orange
                      : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayDate.substring(5),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(weekday,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            child: Text(
              hasIn ? _formatTime(record.punchInTime) : '--:--',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasIn ? Colors.black87 : Colors.grey,
                fontWeight: hasIn ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Text('→',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          Expanded(
            child: Text(
              hasOut ? _formatTime(record.punchOutTime) : '--:--',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasOut ? Colors.black87 : Colors.grey,
                fontWeight: hasOut ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              hasOut
                  ? L10n.homeElapsedMinutes(record.workDurationMinutes)
                  : hasIn
                      ? L10n.homeInProgress
                      : L10n.homeNotPunchedShort,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: hasOut
                    ? Colors.teal
                    : hasIn
                        ? Colors.orange
                        : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.monitor_heart,
            label: L10n.homeQuickStatus,
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatusScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.schedule,
            label: L10n.homeQuickSchedule,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.location_on,
            label: L10n.homeQuickLocation,
            color: Colors.red,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '--:--';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  Widget _buildStatusRow(BuildContext context, IconData icon, String label,
      String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text('$label：', style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
