import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../providers/settings_provider.dart';
import '../providers/location_provider.dart';
import '../providers/reminder_provider.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final location = context.watch<LocationProvider>();
    final reminder = context.watch<ReminderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.statusTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 引擎状态卡片 ----
          _buildMonitoringCard(context, settings, location, reminder),
          const SizedBox(height: 16),

          // ---- 功能启用情况 ----
          _buildFeatureCard(context, settings),
          const SizedBox(height: 16),

          // ---- 距离详情 ----
          if (location.state == LocationState.available &&
              location.distances.isNotEmpty)
            _buildDistanceCard(context, location),
        ],
      ),
    );
  }

  // ==================================================================
  //  监测状态卡片
  // ==================================================================

  Widget _buildMonitoringCard(BuildContext context, SettingsProvider settings,
      LocationProvider location, ReminderProvider reminder) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(L10n.statusEngineCard,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              context,
              Icons.bedtime,
              L10n.statusEngineCard,
              reminder.isEngineRunning
                  ? L10n.statusEngineRunning
                  : L10n.statusEngineStopped,
              reminder.isEngineRunning ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.schedule,
              L10n.statusCheckInterval,
              L10n.statusEveryNMinutes(settings.intervalMinutes),
              Colors.grey,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.location_on,
              L10n.statusCompanyLocation,
              settings.defaultLocation != null
                  ? '${settings.defaultLocation!.name}（${settings.defaultLocation!.geofenceRadius}m）'
                  : L10n.statusNotSet,
              Colors.red,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.satellite_alt,
              L10n.statusLocation,
              location.statusText,
              location.isInsideGeofence ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.notifications,
              L10n.statusTodayNotifications,
              L10n.statusNTimes(reminder.notificationCount),
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              context,
              Icons.refresh,
              L10n.statusLastCheck,
              reminder.lastCheckTime,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  //  功能启用卡片
  // ==================================================================

  Widget _buildFeatureCard(BuildContext context, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.toggle_on, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(L10n.statusFeatureStatus,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
                context, L10n.settingsReminder, settings.reminderEnabled,
                Icons.notifications_active),
            _buildFeatureRow(context, L10n.settingsAutoPunch,
                settings.autoPunchEnabled, Icons.open_in_new),
            _buildFeatureRow(context, L10n.settingsAutoLocation,
                settings.autoLocationPunchEnabled, Icons.my_location),
            _buildFeatureRow(context, L10n.settingsDelayPunch,
                settings.delayPunchEnabled, Icons.timer),
            _buildFeatureRow(context, L10n.analysisAiButton,
                settings.aiSummaryEnabled, Icons.auto_awesome),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  //  距离详情卡片
  // ==================================================================

  Widget _buildDistanceCard(
      BuildContext context, LocationProvider location) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Text(L10n.statusDistanceDetails,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...location.distances.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        d.isInside
                            ? Icons.check_circle
                            : Icons.location_off,
                        size: 16,
                        color: d.isInside ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.location.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        d.formattedDistance,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: d.isInside ? Colors.green : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  //  工具方法
  // ==================================================================

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

  Widget _buildFeatureRow(
      BuildContext context, String label, bool enabled, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: enabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
