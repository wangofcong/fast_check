import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../models/work_schedule.dart';
import '../models/company_location.dart';
import '../models/third_app_config.dart';
import '../models/app_settings.dart';
import '../l10n/l10n.dart';
import 'dart:ui' as ui;

/// 设置状态管理
///
/// 管理所有设置项的读取/更新，UI 通过 Provider 监听变化
class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // ===== 功能开关状态 =====
  bool _reminderEnabled = true;
  bool _autoPunchEnabled = false;
  bool _autoLocationPunchEnabled = false;
  bool _delayPunchEnabled = false;
  bool _aiSummaryEnabled = false;

  bool get reminderEnabled => _reminderEnabled;
  bool get autoPunchEnabled => _autoPunchEnabled;
  bool get autoLocationPunchEnabled => _autoLocationPunchEnabled;
  bool get delayPunchEnabled => _delayPunchEnabled;
  bool get aiSummaryEnabled => _aiSummaryEnabled;

  // ===== 语言设置 =====
  String _languageCode = 'zh';
  String get languageCode => _languageCode;

  // ===== 排班列表 =====
  List<WorkSchedule> _schedules = [];
  List<WorkSchedule> get schedules => _schedules;

  // ===== 公司地点列表 =====
  List<CompanyLocation> _locations = [];
  CompanyLocation? _defaultLocation;
  List<CompanyLocation> get locations => _locations;
  CompanyLocation? get defaultLocation => _defaultLocation;

  // ===== 第三方 App 配置 =====
  List<ThirdAppConfig> _thirdApps = [];
  ThirdAppConfig? _punchInTarget;
  ThirdAppConfig? _punchOutTarget;
  List<ThirdAppConfig> get thirdApps => _thirdApps;
  ThirdAppConfig? get punchInTarget => _punchInTarget;
  ThirdAppConfig? get punchOutTarget => _punchOutTarget;

  // ===== 其他设置 =====
  int _intervalMinutes = 5;
  int _vibrationDuration = 5;
  int _dataRetentionDays = 365;
  bool _hasCompletedOnboarding = false;

  int get intervalMinutes => _intervalMinutes;
  int get vibrationDuration => _vibrationDuration;
  int get dataRetentionDays => _dataRetentionDays;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  // ===== 初始化加载所有设置 =====
  Future<void> loadAll() async {
    await Future.wait([
      _loadToggleSettings(),
      _loadSchedules(),
      _loadLocations(),
      _loadThirdApps(),
      _loadOtherSettings(),
    ]);
    _applyLanguage();
    notifyListeners();
  }

  /// 根据系统语言和应用设置确定实际使用的语言
  void _applyLanguage() {
    String lang;
    if (_languageCode.isNotEmpty) {
      lang = _languageCode;
    } else {
      // 读取系统语言
      try {
        final locale = ui.PlatformDispatcher.instance.locale;
        lang = locale.languageCode == 'zh' ? 'zh' : 'en';
      } catch (_) {
        lang = 'zh';
      }
    }
    L10n.setLanguage(lang);
  }

  Future<void> _loadToggleSettings() async {
    _reminderEnabled = await _db.getBoolSetting(AppSettingKeys.reminderEnabled);
    _autoPunchEnabled =
        await _db.getBoolSetting(AppSettingKeys.autoPunchEnabled);
    _autoLocationPunchEnabled =
        await _db.getBoolSetting(AppSettingKeys.autoLocationPunchEnabled);
    _delayPunchEnabled =
        await _db.getBoolSetting(AppSettingKeys.delayPunchEnabled);
    _aiSummaryEnabled =
        await _db.getBoolSetting(AppSettingKeys.aiSummaryEnabled);
  }

  Future<void> _loadOtherSettings() async {
    _intervalMinutes =
        await _db.getIntSetting(AppSettingKeys.intervalMinutes);
    _vibrationDuration =
        await _db.getIntSetting(AppSettingKeys.vibrationDuration);
    _dataRetentionDays =
        await _db.getIntSetting(AppSettingKeys.dataRetentionDays);
    _hasCompletedOnboarding =
        await _db.getBoolSetting(AppSettingKeys.hasCompletedOnboarding);
    _languageCode =
        await _db.getSettingWithDefault(AppSettingKeys.appLanguage);
  }

  Future<void> _loadSchedules() async {
    _schedules = await _db.getAllWorkSchedules();
  }

  Future<void> _loadLocations() async {
    _locations = await _db.getAllCompanyLocations();
    _defaultLocation = await _db.getDefaultCompanyLocation();
  }

  Future<void> _loadThirdApps() async {
    _thirdApps = await _db.getAllThirdAppConfigs();
    _punchInTarget = await _db.getPunchInTargetApp();
    _punchOutTarget = await _db.getPunchOutTargetApp();
  }

  // ===== 功能开关切换 =====

  Future<void> toggleReminder(bool value) async {
    _reminderEnabled = value;
    await _db.setBoolSetting(AppSettingKeys.reminderEnabled, value);
    notifyListeners();
  }

  Future<void> toggleAutoPunch(bool value) async {
    _autoPunchEnabled = value;
    await _db.setBoolSetting(AppSettingKeys.autoPunchEnabled, value);
    notifyListeners();
  }

  Future<void> toggleAutoLocationPunch(bool value) async {
    _autoLocationPunchEnabled = value;
    await _db.setBoolSetting(AppSettingKeys.autoLocationPunchEnabled, value);
    notifyListeners();
  }

  Future<void> toggleDelayPunch(bool value) async {
    _delayPunchEnabled = value;
    await _db.setBoolSetting(AppSettingKeys.delayPunchEnabled, value);
    notifyListeners();
  }

  Future<void> toggleAiSummary(bool value) async {
    _aiSummaryEnabled = value;
    await _db.setBoolSetting(AppSettingKeys.aiSummaryEnabled, value);
    notifyListeners();
  }

  // ===== 排班操作 =====

  Future<void> addSchedule(WorkSchedule schedule) async {
    await _db.insertWorkSchedule(schedule);
    await _loadSchedules();
    notifyListeners();
  }

  Future<void> updateSchedule(WorkSchedule schedule) async {
    await _db.updateWorkSchedule(schedule);
    await _loadSchedules();
    notifyListeners();
  }

  Future<void> deleteSchedule(int id) async {
    await _db.deleteWorkSchedule(id);
    await _loadSchedules();
    notifyListeners();
  }

  // ===== 公司地点操作 =====

  Future<void> addLocation(CompanyLocation location) async {
    await _db.insertCompanyLocation(location);
    await _loadLocations();
    notifyListeners();
  }

  Future<void> updateLocation(CompanyLocation location) async {
    await _db.updateCompanyLocation(location);
    await _loadLocations();
    notifyListeners();
  }

  Future<void> setDefaultLocation(int id) async {
    await _db.setDefaultCompanyLocation(id);
    await _loadLocations();
    notifyListeners();
  }

  Future<void> deleteLocation(int id) async {
    await _db.deleteCompanyLocation(id);
    await _loadLocations();
    notifyListeners();
  }

  // ===== 第三方 App 操作 =====

  Future<void> addThirdApp(ThirdAppConfig config) async {
    await _db.insertThirdAppConfig(config);
    await _loadThirdApps();
    notifyListeners();
  }

  Future<void> updateThirdApp(ThirdAppConfig config) async {
    await _db.updateThirdAppConfig(config);
    await _loadThirdApps();
    notifyListeners();
  }

  Future<void> setPunchInTargetApp(int appId) async {
    await _db.setPunchInTarget(appId);
    await _loadThirdApps();
    notifyListeners();
  }

  Future<void> setPunchOutTargetApp(int appId) async {
    await _db.setPunchOutTarget(appId);
    await _loadThirdApps();
    notifyListeners();
  }

  Future<void> deleteThirdApp(int id) async {
    await _db.deleteThirdAppConfig(id);
    await _loadThirdApps();
    notifyListeners();
  }

  // ===== 其他设置 =====

  Future<void> setIntervalMinutes(int minutes) async {
    _intervalMinutes = minutes;
    await _db.setIntSetting(AppSettingKeys.intervalMinutes, minutes);
    notifyListeners();
  }

  Future<void> setDataRetentionDays(int days) async {
    _dataRetentionDays = days;
    await _db.setIntSetting(AppSettingKeys.dataRetentionDays, days);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _db.setBoolSetting(AppSettingKeys.hasCompletedOnboarding, true);
    notifyListeners();
  }

  // ===== 语言设置 =====

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await _db.setSetting(AppSettingKeys.appLanguage, code);
    _applyLanguage();
    notifyListeners();
  }

  // ===== AI 配置刷新 =====

  /// 刷新 AI 配置（当用户在 AI 设置页面保存后调用）
  void refreshAiConfig() {
    // AI 配置由 AiSummaryService 直接管理，
    // 此方法仅用于触发 UI 重建
    notifyListeners();
  }
}
