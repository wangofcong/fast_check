import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../l10n/l10n.dart';

/// 已安装 App 信息
class InstalledAppInfo {
  final String appName;
  final String packageName;
  final ImageProvider? icon;

  InstalledAppInfo({
    required this.appName,
    required this.packageName,
    this.icon,
  });
}

/// App 选择器对话框
///
/// 在 Android 上显示手机上所有已安装应用供用户选择，
/// 选中后自动填入名称和包名。
/// 在 iOS 上不支持（Apple 限制），会直接返回 null。
///
/// 返回选中的 [InstalledAppInfo]，或 null（取消 / 不支持）
class AppPickerDialog {
  /// 显示 App 选择器
  static Future<InstalledAppInfo?> show(BuildContext context) async {
    // iOS 不支持列出已安装应用
    if (!Platform.isAndroid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.thirdAppPickerNotSupported)),
        );
      }
      return null;
    }

    return showDialog<InstalledAppInfo>(
      context: context,
      useSafeArea: false,
      builder: (ctx) => const _AppPickerContent(),
    );
  }
}

/// App 选择器内容（全屏对话框）
class _AppPickerContent extends StatefulWidget {
  const _AppPickerContent();

  @override
  State<_AppPickerContent> createState() => _AppPickerContentState();
}

class _AppPickerContentState extends State<_AppPickerContent> {
  List<Application> _allApps = [];
  List<Application> _filteredApps = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      // 获取已安装的应用（仅显示可启动的应用，排除系统应用）
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        includeAppIcons: true,
        onlyAppsWithLaunchIntent: true,
      );

      // 按应用名称排序
      apps.sort((a, b) => a.appName.compareTo(b.appName));

      if (mounted) {
        setState(() {
          _allApps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.thirdAppPickerFailed),
          ),
        );
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        final q = query.toLowerCase();
        _filteredApps = _allApps.where((app) {
          return app.appName.toLowerCase().contains(q) ||
              app.packageName.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- 标题栏 ----
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inversePrimary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    L10n.thirdAppPickerTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ---- 搜索框 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: L10n.thirdAppPickerSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: _onSearch,
            ),
          ),

          // ---- App 列表 ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? L10n.thirdAppPickerNoMatch
                              : L10n.thirdAppPickerNoApps,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          return _AppItem(
                            app: app,
                            onTap: () {
                              Navigator.pop(
                                context,
                                InstalledAppInfo(
                                  appName: app.appName,
                                  packageName: app.packageName,
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),

          // ---- 底部计数 ----
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
            child: Text(
              L10n.tr(
                '共 ${_filteredApps.length} 个应用',
                '${_filteredApps.length} apps',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

/// App 列表项
class _AppItem extends StatelessWidget {
  final Application app;
  final VoidCallback onTap;

  const _AppItem({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: (app is ApplicationWithIcon)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                (app as ApplicationWithIcon).icon,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.apps, size: 20, color: Colors.grey[600]),
                ),
              ),
            )
          : Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.apps, size: 20, color: Colors.grey[600]),
            ),
      title: Text(
        app.appName,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        app.packageName,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
