/// 打卡提醒 App 入口
///
/// 应用根节点，包含：
/// - Provider 依赖注入
/// - 底部导航（首页 / 记录 / 分析 / 设置）
/// - 主题配置

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/location_provider.dart';
import 'providers/reminder_provider.dart';
import 'services/database_service.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'screens/punch_history_screen.dart';
import 'screens/punch_analysis_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/status_screen.dart';
import 'screens/ai_report_screen.dart';
import 'screens/ai_settings_screen.dart';
import 'screens/data_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库（首次运行时自动建表和插入默认数据）
  final dbService = DatabaseService();
  await dbService.database;

  runApp(const FastCheckApp());
}

class FastCheckApp extends StatelessWidget {
  const FastCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadAll()),
        ChangeNotifierProvider(create: (_) => LocationProvider()..initialize()),
        ChangeNotifierProvider(
          create: (ctx) {
            final provider = ReminderProvider();
            provider.injectDependencies(
              settingsProvider: ctx.read<SettingsProvider>(),
              locationProvider: ctx.read<LocationProvider>(),
            );
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            key: ValueKey(settings.languageCode),
            title: L10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
            ),
            home: const MainScaffold(),
          );
        },
      ),
    );
  }
}

/// 主脚手架 — 底部导航 + 侧边抽屉
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  /// 外部 Scaffold 的 Key，供子页面打开抽屉
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    PunchHistoryScreen(),
    PunchAnalysisScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      key: MainScaffold.scaffoldKey,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: L10n.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: L10n.navRecords,
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: L10n.navAnalysis,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: L10n.navSettings,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
                              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.access_time, size: 40, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      L10n.appShortTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${now.year}${L10n.year}${now.month}${L10n.months}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // ---- 导航 ----
              _drawerSectionHeader(L10n.drawerNavigation),
              _drawerItem(
                icon: Icons.home,
                label: L10n.drawerHome,
                selected: _currentIndex == 0,
                onTap: () => _switchTab(0),
              ),
              _drawerItem(
                icon: Icons.history,
                label: L10n.drawerRecords,
                selected: _currentIndex == 1,
                onTap: () => _switchTab(1),
              ),
              _drawerItem(
                icon: Icons.analytics,
                label: L10n.drawerAnalysis,
                selected: _currentIndex == 2,
                onTap: () => _switchTab(2),
              ),
              const Divider(),
              // ---- 工具 ----
              _drawerSectionHeader(L10n.drawerTools),
              _drawerItem(
                icon: Icons.monitor_heart,
                label: L10n.drawerStatus,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatusScreen()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.auto_awesome,
                label: L10n.drawerAiReport,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiReportScreen(
                        year: now.year,
                        month: now.month,
                      ),
                    ),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.smart_toy,
                label: L10n.drawerAiSettings,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AiSettingsScreen()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.storage,
                label: L10n.drawerDataManagement,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DataSettingsScreen()),
                  );
                },
              ),
              const Divider(),
              // ---- 其他 ----
              _drawerSectionHeader(L10n.drawerOther),
              _drawerItem(
                icon: Icons.settings,
                label: L10n.drawerAppSettings,
                selected: _currentIndex == 3,
                onTap: () => _switchTab(3),
              ),
          ],
        ),
      ),
    );
  }

  void _switchTab(int index) {
    Navigator.pop(context); // 关闭抽屉
    setState(() => _currentIndex = index);
  }

  Widget _drawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
