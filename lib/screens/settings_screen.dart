import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/l10n.dart';
import 'schedule_settings.dart';
import 'location_settings.dart';
import 'third_app_settings.dart';
import 'ai_settings_screen.dart';
import 'data_settings_screen.dart';

/// 设置页面
///
/// 功能总开关列表 + 各功能详细配置入口
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.settingsTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ---- 语言设置 ----
          _buildSectionHeader(context, L10n.settingsLanguage),
          _buildLanguageSelector(context, provider),
          const SizedBox(height: 8),

          // ---- 功能开关区域 ----
          _buildSectionHeader(context, L10n.settingsFeatureSettings),
          SwitchListTile(
            title: Text(L10n.settingsReminder),
            subtitle: Text(L10n.settingsReminderDesc),
            secondary: const Icon(Icons.notifications_active, color: Colors.blue),
            value: provider.reminderEnabled,
            onChanged: (v) => provider.toggleReminder(v),
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            title: Text(L10n.settingsAutoPunch),
            subtitle: Text(L10n.settingsAutoPunchDesc),
            secondary: const Icon(Icons.open_in_new, color: Colors.orange),
            value: provider.autoPunchEnabled,
            onChanged: (v) => provider.toggleAutoPunch(v),
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            title: Text(L10n.settingsAutoLocation),
            subtitle: Text(L10n.settingsAutoLocationDesc),
            secondary: const Icon(Icons.my_location, color: Colors.green),
            value: provider.autoLocationPunchEnabled,
            onChanged: (v) => provider.toggleAutoLocationPunch(v),
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            title: Text(L10n.settingsDelayPunch),
            subtitle: Text(L10n.settingsDelayPunchDesc),
            secondary: const Icon(Icons.timer, color: Colors.purple),
            value: provider.delayPunchEnabled,
            onChanged: (v) => provider.toggleDelayPunch(v),
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            title: Text(L10n.settingsAiSummary),
            subtitle: Text(L10n.settingsAiSummaryDesc),
            secondary: const Icon(Icons.auto_awesome, color: Colors.teal),
            value: provider.aiSummaryEnabled,
            onChanged: (v) => provider.toggleAiSummary(v),
          ),

          const SizedBox(height: 16),

          // ---- 详细配置入口 ----
          _buildSectionHeader(context, L10n.settingsGeneral),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.blue),
            title: Text(L10n.settingsSchedule),
            subtitle: Text(
              provider.schedules.isEmpty
                  ? '暂无排班，点击添加'
                  : '共 ${provider.schedules.length} 组排班',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(context, const ScheduleSettingsScreen()),
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.red),
            title: Text(L10n.settingsLocation),
            subtitle: Text(
              provider.defaultLocation != null
                  ? '${provider.defaultLocation!.name}（${provider.defaultLocation!.geofenceRadius}m）'
                  : '尚未设置公司地址',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(context, const LocationSettingsScreen()),
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: const Icon(Icons.phone_android, color: Colors.indigo),
            title: Text(L10n.settingsThirdApp),
            subtitle: Text(
              provider.thirdApps.isEmpty
                  ? '未配置第三方 App'
                  : '已配置 ${provider.thirdApps.length} 个应用',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(context, const ThirdAppSettingsScreen()),
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.teal),
            title: Text(L10n.settingsAiConfig),
            subtitle: const Text('配置 DeepSeek API Key 与隐私选项'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(context, const AiSettingsScreen()),
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: const Icon(Icons.storage, color: Colors.blueGrey),
            title: Text(L10n.settingsDataManagement),
            subtitle: Text(
              '保留 ${provider.dataRetentionDays > 0 ? '${provider.dataRetentionDays} 天' : '永久'} · 导出 · 清理',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigate(context, const DataSettingsScreen()),
          ),

          const SizedBox(height: 16),

          // ---- 提醒设置 ----
          _buildSectionHeader(context, L10n.settingsInterval),
          ListTile(
            leading: const Icon(Icons.timer_outlined, color: Colors.grey),
            title: Text(L10n.settingsInterval),
            subtitle: Text(L10n.tr(
              '用户拒绝后每 ${provider.intervalMinutes} 分钟提醒一次',
              'Remind every ${provider.intervalMinutes} min after dismissed',
            )),
            trailing: SizedBox(
              width: 120,
              child: DropdownButton<int>(
                value: provider.intervalMinutes,
                isExpanded: true,
                items: [3, 5, 10, 15, 30]
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(L10n.tr('$m 分钟', '$m min'))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) provider.setIntervalMinutes(v);
                },
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ---- 版本信息 ----
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${L10n.appShortTitle} v1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 语言选择器
  Widget _buildLanguageSelector(BuildContext context, SettingsProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.language, size: 20, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.settingsLanguage,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      L10n.settingsLanguageHint,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'zh',
                    label: Text(L10n.settingsLanguageZh, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(L10n.settingsLanguageEn, style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {provider.languageCode.isEmpty ? 'zh' : provider.languageCode},
                onSelectionChanged: (selected) {
                  provider.setLanguage(selected.first);
                },
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
