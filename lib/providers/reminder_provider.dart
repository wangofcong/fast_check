import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/punch_reminder_engine.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../models/punch_record.dart';
import '../services/database_service.dart';
import 'settings_provider.dart';
import 'location_provider.dart';

/// 提醒 Provider
class ReminderProvider extends ChangeNotifier {
  final PunchReminderEngine _engine;
  final DatabaseService _db = DatabaseService();

  // ===== 依赖的 Provider（通过 setter 注入） =====

  SettingsProvider? _settingsProvider;
  LocationProvider? _locationProvider;

  // ===== 公开状态 =====

  /// 引擎是否运行中
  bool get isEngineRunning => _engine.isRunning;

  /// 今日打卡记录
  PunchRecord? get todayRecord => _engine.todayRecord;

  /// 今日打卡状态
  DailyPunchStatus get todayStatus => _engine.todayStatus;

  /// 最近一次检查结果
  ReminderCheckResult? get lastCheckResult => _engine.lastCheckResult;

  /// 引擎检查间隔
  int get intervalMinutes => _engine.intervalMinutes;

  /// 是否已打上班卡
  bool get hasPunchedIn => _engine.hasPunchedIn;

  /// 是否已打下班卡
  bool get hasPunchedOut => _engine.hasPunchedOut;

  /// 今日工作时长（分钟）
  int get todayWorkMinutes => _engine.todayWorkMinutes;

  /// 格式化的工作时长
  String get formattedWorkDuration {
    final mins = todayWorkMinutes;
    if (mins <= 0) return '--';
    final hours = mins ~/ 60;
    final minutes = mins % 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }

  /// 上次检查时间的格式化字符串（HH:mm:ss）
  String get lastCheckTime {
    final result = _engine.lastCheckResult;
    if (result == null) return '尚未检查';
    final dt = result.checkTime;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  /// 今日检查次数
  int _checkCount = 0;
  int get checkCount => _checkCount;

  /// 今日通知发送次数
  int _notificationCount = 0;
  int get notificationCount => _notificationCount;

  /// 当前排班名称
  String get todayScheduleName {
    final r = _engine.lastCheckResult;
    return r?.schedule?.name ?? '无可用排班';
  }

  /// 当前时间窗口描述
  String get currentWindowDescription {
    final r = _engine.lastCheckResult;
    if (r == null) return '待检查';
    switch (r.window) {
      case TimeWindow.beforeWork:
        return '上班前';
      case TimeWindow.punchIn:
        return '⏰ 上班打卡时间';
      case TimeWindow.working:
        return '💼 工作时间';
      case TimeWindow.punchOut:
        return '⏰ 下班打卡时间';
      case TimeWindow.afterWork:
        return '✅ 下班休息';
    }
  }

  // ===== 内部状态 =====

  StreamSubscription<NotificationContent>? _notifSub;

  // ===== 构造函数 =====

  ReminderProvider({
    PunchReminderEngine? engine,
  }) : _engine = engine ?? PunchReminderEngine();

  /// 注入外部 Provider 依赖
  void injectDependencies({
    SettingsProvider? settingsProvider,
    LocationProvider? locationProvider,
  }) {
    _settingsProvider = settingsProvider;
    _locationProvider = locationProvider;

    if (settingsProvider != null) {
      settingsProvider.addListener(_onSettingsChanged);
    }

    notifyListeners();
  }

  // ===== 生命周期 =====

  @override
  void dispose() {
    _settingsProvider?.removeListener(_onSettingsChanged);
    _engine.dispose();
    _notifSub?.cancel();
    super.dispose();
  }

  // ===== 启动/停止 =====

  /// 启动提醒引擎
  Future<void> start() async {
    if (_engine.isRunning) return;

    final settings = _settingsProvider;
    final location = _locationProvider;

    // 收集当前配置
    await _engine.start(
      intervalMinutes: settings?.intervalMinutes ?? 5,
      schedules: settings?.schedules ?? [],
      locations: settings?.locations ?? [],
      currentLocation: location?.currentLocation,
      punchInTargetApp: settings?.punchInTarget,
      punchOutTargetApp: settings?.punchOutTarget,
    );

    // 更新引擎的开关状态
    await _engine.updateConfig(
      reminderEnabled: settings?.reminderEnabled ?? true,
      autoPunchEnabled: settings?.autoPunchEnabled ?? false,
      autoLocationPunchEnabled: settings?.autoLocationPunchEnabled ?? false,
      delayPunchEnabled: settings?.delayPunchEnabled ?? false,
    );

    _checkCount = 0;
    _notificationCount = 0;

    notifyListeners();
    debugPrint('[ReminderProvider] 引擎已启动');
  }

  /// 停止提醒引擎
  Future<void> stop() async {
    await _engine.stop();
    notifyListeners();
  }

  /// 重启引擎（配置变更后调用）
  Future<void> restart() async {
    await stop();
    await start();
  }

  // ===== 设置变化监听 =====

  void _onSettingsChanged() {
    // 如果引擎运行中，推送新配置
    if (_engine.isRunning) {
      final settings = _settingsProvider;
      if (settings != null) {
        _engine.updateConfig(
          intervalMinutes: settings.intervalMinutes,
          schedules: settings.schedules,
          locations: settings.locations,
          reminderEnabled: settings.reminderEnabled,
          autoPunchEnabled: settings.autoPunchEnabled,
          autoLocationPunchEnabled: settings.autoLocationPunchEnabled,
          delayPunchEnabled: settings.delayPunchEnabled,
          punchInTargetApp: settings.punchInTarget,
          punchOutTargetApp: settings.punchOutTarget,
        );
      }
    }
  }

  /// 更新位置信息
  void updateCurrentLocation(LocationResult? location) {
    if (_engine.isRunning && location != null) {
      _engine.updateConfig(currentLocation: location);
    }
  }

  // ===== 手动打卡操作 =====

  /// 手动上班打卡
  Future<PunchRecord?> manualPunchIn({
    String type = 'manual',
  }) async {
    final schedule = _engine.lastCheckResult?.schedule;
    final record = await _engine.manualPunchIn(
      type: type,
      schedule: schedule,
    );
    notifyListeners();
    return record;
  }

  /// 手动下班打卡
  Future<PunchRecord?> manualPunchOut({
    String type = 'manual',
    int? delayMinutes,
  }) async {
    final schedule = _engine.lastCheckResult?.schedule;
    final record = await _engine.manualPunchOut(
      type: type,
      schedule: schedule,
      delayMinutes: delayMinutes,
    );
    notifyListeners();
    return record;
  }

  /// 强制立即检查
  Future<void> forceCheck() async {
    await _engine.forceCheck();
    _checkCount++;
    notifyListeners();
  }

  /// 重置提醒状态
  void resetReminders() {
    _engine.resetSentReminders();
    notifyListeners();
  }

  // ===== 查询方法 =====

  /// 获取某个日期的打卡记录
  Future<PunchRecord?> getRecordByDate(String date) async {
    return await _db.getPunchRecordByDate(date);
  }

  /// 获取某个月的打卡记录
  Future<List<PunchRecord>> getRecordsByMonth(int year, int month) async {
    return await _db.getPunchRecordsByMonth(year, month);
  }

  /// 获取日期范围内的打卡记录
  Future<List<PunchRecord>> getRecordsByDateRange(
      String startDate, String endDate) async {
    return await _db.getPunchRecordsByDateRange(startDate, endDate);
  }
}
