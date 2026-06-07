import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/third_app_config.dart';

/// 第三方 App 配置页面
///
/// 功能：
/// - 添加/编辑第三方打卡 App 配置（包名、URL Scheme 等）
/// - 设置上班/下班打卡目标 App
/// - 提供预设模板快速添加
class ThirdAppSettingsScreen extends StatelessWidget {
  const ThirdAppSettingsScreen({super.key});

  /// 预设 App 模板
  static const List<Map<String, String>> _presetApps = [
    {
      'name': '企业微信',
      'package': 'com.tencent.wework',
      'scheme': 'weixin://',
    },
    {
      'name': '飞书',
      'package': 'com.ss.android.lark',
      'scheme': 'feishu://',
    },
    {
      'name': '钉钉',
      'package': 'com.alibaba.android.rimet',
      'scheme': 'dingtalk://',
    },
    {
      'name': '微信',
      'package': 'com.tencent.mm',
      'scheme': 'weixin://',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.thirdAppTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: L10n.thirdAppAdd,
            onSelected: (v) {
              if (v == 'custom') {
                _showAppEditDialog(context, provider, null);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'custom',
                child: ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(L10n.tr('自定义添加', 'Custom Add')),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              ..._presetApps.map((app) => PopupMenuItem(
                    value: app['name'],
                    child: ListTile(
                      leading: Icon(
                        _getAppIcon(app['name']!),
                        color: _getAppColor(app['name']!),
                      ),
                      title: Text(L10n.tr('添加 ', 'Add ') + app['name']!),
                      dense: true,
                    ),
                  )),
            ],
          ),
        ],
      ),
      body: provider.thirdApps.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(L10n.thirdAppNoData,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(L10n.tr('添加第三方打卡 App 以使用自动跳转功能',
                      'Add third-party apps for auto-jump feature'),
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(L10n.thirdAppAdd),
                    onPressed: () =>
                        _showAppEditDialog(context, provider, null),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- 上班打卡目标 ----
                _buildTargetSection(
                  context,
                  title: L10n.thirdAppPunchInTarget,
                  subtitle: L10n.tr('选择上班打卡时自动打开的 App', 'Select app for punch in'),
                  apps: provider.thirdApps,
                  targetApp: provider.punchInTarget,
                  onSelect: (appId) => provider.setPunchInTargetApp(appId),
                ),
                const SizedBox(height: 24),

                // ---- 下班打卡目标 ----
                _buildTargetSection(
                  context,
                  title: L10n.thirdAppPunchOutTarget,
                  subtitle: L10n.tr('选择下班打卡时自动打开的 App', 'Select app for punch out'),
                  apps: provider.thirdApps,
                  targetApp: provider.punchOutTarget,
                  onSelect: (appId) => provider.setPunchOutTargetApp(appId),
                ),
                const SizedBox(height: 24),

                // ---- App 配置列表 ----
                Text(L10n.tr('已配置的 App', 'Configured Apps'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...provider.thirdApps.map((app) => _AppConfigCard(
                      config: app,
                      isPunchInTarget: provider.punchInTarget?.id == app.id,
                      isPunchOutTarget: provider.punchOutTarget?.id == app.id,
                      onEdit: () =>
                          _showAppEditDialog(context, provider, app),
                      onDelete: () =>
                          _confirmDelete(context, provider, app),
                    )),
              ],
            ),
    );
  }

  Widget _buildTargetSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<ThirdAppConfig> apps,
    required ThirdAppConfig? targetApp,
    required Function(int) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),
        if (apps.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(L10n.thirdAppNoData),
            ),
          )
        else
          ...apps.map((app) {
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: RadioListTile<int>(
                title: Row(
                  children: [
                    Icon(_getAppIcon(app.name),
                        color: _getAppColor(app.name), size: 24),
                    const SizedBox(width: 8),
                    Text(app.name),
                  ],
                ),
                subtitle: Text(app.packageName ?? app.urlScheme ?? ''),
                value: app.id!,
                groupValue: targetApp?.id,
                onChanged: (v) {
                  if (v != null) onSelect(v);
                },
              ),
            );
          }),
      ],
    );
  }

  void _confirmDelete(BuildContext context, SettingsProvider provider,
      ThirdAppConfig app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.thirdAppDeleteConfirm),
        content: Text(L10n.tr('确定要删除「${app.name}」的配置吗？',
            'Are you sure to delete config for "${app.name}"?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteThirdApp(app.id!);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(L10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppEditDialog(BuildContext context,
      SettingsProvider provider, ThirdAppConfig? existing) async {
    final isEditing = existing != null;
    final nameCtrl =
        TextEditingController(text: isEditing ? existing.name : '');
    final packageCtrl =
        TextEditingController(text: isEditing ? existing.packageName ?? '' : '');
    final schemeCtrl =
        TextEditingController(text: isEditing ? existing.urlScheme ?? '' : '');
    final linkCtrl =
        TextEditingController(text: isEditing ? existing.iosUniversalLink ?? '' : '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? L10n.thirdAppEdit : L10n.thirdAppAdd),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: L10n.thirdAppName,
                    hintText: L10n.tr('例如：企业微信', 'e.g. WeCom'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: packageCtrl,
                  decoration: InputDecoration(
                    labelText: L10n.tr('Android 包名', 'Android Package'),
                    hintText: L10n.tr('例如：com.tencent.wework', 'e.g. com.tencent.wework'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: schemeCtrl,
                  decoration: InputDecoration(
                    labelText: 'URL Scheme',
                    hintText: L10n.tr('例如：weixin://', 'e.g. weixin://'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  decoration: InputDecoration(
                    labelText: L10n.tr('iOS Universal Link（可选）', 'iOS Universal Link (optional)'),
                    hintText: L10n.tr('例如：https://work.weixin.qq.com', 'e.g. https://work.weixin.qq.com'),
                    border: const OutlineInputBorder(),
                  ),
                ),
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
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(L10n.tr('请输入 App 名称', 'Please enter app name'))),
                  );
                  return;
                }
                if (packageCtrl.text.trim().isEmpty &&
                    schemeCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content:
                            Text(L10n.tr('请至少填写 Android 包名或 URL Scheme', 'Enter package name or URL Scheme'))),
                  );
                  return;
                }

                final config = ThirdAppConfig(
                  id: isEditing ? existing.id : null,
                  name: nameCtrl.text.trim(),
                  packageName: packageCtrl.text.trim().isEmpty
                      ? null
                      : packageCtrl.text.trim(),
                  urlScheme: schemeCtrl.text.trim().isEmpty
                      ? null
                      : schemeCtrl.text.trim(),
                  iosUniversalLink: linkCtrl.text.trim().isEmpty
                      ? null
                      : linkCtrl.text.trim(),
                  isWorkPunchIn:
                      isEditing ? existing.isWorkPunchIn : 0,
                  isWorkPunchOut:
                      isEditing ? existing.isWorkPunchOut : 0,
                );

                if (isEditing) {
                  provider.updateThirdApp(config);
                } else {
                  provider.addThirdApp(config);
                }
                Navigator.pop(ctx);
              },
              child: Text(L10n.save),
            ),
          ],
        );
      },
    );
  }

  static IconData _getAppIcon(String name) {
    if (name.contains('企业微信') || name.contains('微信')) {
      return Icons.chat;
    } else if (name.contains('飞书')) {
      return Icons.book;
    } else if (name.contains('钉钉')) {
      return Icons.notifications;
    }
    return Icons.apps;
  }

  static Color _getAppColor(String name) {
    if (name.contains('企业微信')) return Colors.green;
    if (name.contains('微信')) return Colors.green;
    if (name.contains('飞书')) return Colors.blue;
    if (name.contains('钉钉')) return Colors.blueGrey;
    return Colors.grey;
  }
}

/// App 配置卡片组件
class _AppConfigCard extends StatelessWidget {
  final ThirdAppConfig config;
  final bool isPunchInTarget;
  final bool isPunchOutTarget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AppConfigCard({
    required this.config,
    required this.isPunchInTarget,
    required this.isPunchOutTarget,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ThirdAppSettingsScreen._getAppColor(config.name)
              .withValues(alpha: 0.15),
          child: Icon(
            ThirdAppSettingsScreen._getAppIcon(config.name),
            color: ThirdAppSettingsScreen._getAppColor(config.name),
          ),
        ),
        title: Text(config.name),
        subtitle: Text(
          [
            if (config.packageName != null) config.packageName,
            if (config.urlScheme != null) config.urlScheme,
            if (isPunchInTarget) '🏢 ${L10n.thirdAppPunchInTarget}',
            if (isPunchOutTarget) '🏠 ${L10n.thirdAppPunchOutTarget}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      ),
    );
  }
}
