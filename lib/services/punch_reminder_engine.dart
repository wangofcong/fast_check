library punch_reminder_engine;

/// 打卡提醒引擎
///
/// 核心业务引擎，整合时间排班、地理围栏、通知推送和打卡记录。
/// 以固定间隔（[intervalMinutes]）运行检查循环：
///
/// **检查流程：**
/// 1. 获取今天的日期和当前时间
/// 2. 确定今天适用的排班（基于 weekDays 匹配）
/// 3. 检查当前位于哪个时间窗口：
///    - 上班窗口 [punchInStart ~ punchInEnd]
///    - 下班窗口 [punchOutStart ~ punchOutEnd]（含延迟）
///    - 窗口外（工作中间/非工作时间）
/// 4. 查询今日打卡记录，判断是否已打卡
/// 5. 根据功能开关决定触发动作：
///    - 上下班提醒 → 发送通知
///    - 自动打卡（位置触发）→ 检查围栏 → 自动记录 + 跳转App
///    - 下班打卡延迟 → 扩展下班窗口
/// 6. 更新打卡记录到数据库

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'location_service.dart';
import '../models/punch_record.dart';
import '../models/work_schedule.dart';
import '../models/company_location.dart';
import '../models/delay_record.dart';
import '../models/third_app_config.dart';
import '../services/database_service.dart';

// =============================================================================
// 数据模型
// =============================================================================

/// 每日打卡状态
enum DailyPunchStatus {
  /// 未打卡（无记录）
  none,

  /// 已打上班卡
  punchedIn,

  /// 已完成全天打卡（上下班都打了）
  completed,
}

/// 当前时间窗口
enum TimeWindow {
  /// 上班前（早于上班窗口）
  beforeWork,

  /// 上班窗口内 [punchInStart ~ punchInEnd]
  punchIn,

  /// 工作时间内（上下班窗口之间）
  working,

  /// 下班窗口内 [punchOutStart ~ punchOutEnd]（含延迟）
  punchOut,

  /// 下班后（晚于下班窗口）
  afterWork,
}

/// 检查结果
class ReminderCheckResult {
  /// 当前适用的排班（可能为 null）
  final WorkSchedule? schedule;

  /// 当前时间窗口
  final TimeWindow window;

  /// 今日打卡状态
  final DailyPunchStatus punchStatus;

  /// 是否已发送过提醒（防止重复）
  final bool reminderAlreadySent;

  /// 检查时间
  final DateTime checkTime;

  /// 当前时间字符串（HH:mm）
  final String currentTimeStr;

  /// 今日日期（yyyy-MM-dd）
  final String todayDate;

  const ReminderCheckResult({
    this.schedule,
    required this.window,
    required this.punchStatus,
    this.reminderAlreadySent = false,
    required this.checkTime,
    required this.currentTimeStr,
    required this.todayDate,
  });

  /// 是否需要发出提醒
  bool get shouldRemind =>
      !reminderAlreadySent &&
      (window == TimeWindow.punchIn || window == TimeWindow.punchOut) &&
      punchStatus != DailyPunchStatus.completed;

  /// 是否为上班提醒
  bool get isPunchInTime =>
      window == TimeWindow.punchIn && punchStatus != DailyPunchStatus.punchedIn;

  /// 是否为下班提醒
  bool get isPunchOutTime =>
      window == TimeWindow.punchOut && punchStatus != DailyPunchStatus.completed;

  @override
  String toString() =>
      'CheckResult(schedule: ${schedule?.name ?? "无"}, '
      'window: ${window.name}, punch: ${punchStatus.name})';
}

// =============================================================================
// 引擎
// =============================================================================

/// 打卡提醒引擎
///
/// 核心引擎。通过 [start]/[stop] 控制运行周期。
/// 依赖 [SettingsProvider] 提供配置，[LocationProvider] 提供围栏状态。
///
/// 使用方式：
/// ```dart
/// final engine = PunchReminderEngine(notificationService: service);
/// await engine.start();
/// // ...
/// await engine.stop();
/// ```
class PunchReminderEngine extends ChangeNotifier {
  // ===== 依赖 =====

  final NotificationService _notificationService;
  final DatabaseService _db;

  // ===== 配置 =====

  int _intervalMinutes = 5;
  bool _reminderEnabled = true;
  bool _autoPunchEnabled = false;
  bool _autoLocationPunchEnabled = false;
  bool _delayPunchEnabled = false;

  // ===== 运行时状态 =====

  Timer? _tickTimer;
  bool _isRunning = false;
  DateTime? _lastCheckTime;

  /// 当前检查结果
  ReminderCheckResult? _lastCheckResult;
  ReminderCheckResult? get lastCheckResult => _lastCheckResult;

  /// 上次检查时间
  DateTime? get lastCheckTime => _lastCheckTime;

  /// 今日打卡记录
  PunchRecord? _todayRecord;
  PunchRecord? get todayRecord => _todayRecord;

  /// 是否已释放
  bool _isDisposed = false;

  /// 自上次检查以来发送过的提醒（避免重复）
  final Set<String> _sentReminders = {};

  /// 当前排班列表（外部注入）
  List<WorkSchedule> _schedules = [];

  /// 当前公司地点（围栏检查用，外部注入）
  List<CompanyLocation> _locations = [];

  /// 当前位置（外部注入）
  LocationResult? _currentLocation;

  /// 上班目标 App
  ThirdAppConfig? _punchInTargetApp;

  /// 下班目标 App
  ThirdAppConfig? _punchOutTargetApp;

  /// 上班目标 App
  ThirdAppConfig? get punchInTargetApp => _punchInTargetApp;

  /// 下班目标 App
  ThirdAppConfig? get punchOutTargetApp => _punchOutTargetApp;

  // ===== 公开状态 =====

  /// 引擎是否正在运行
  bool get isRunning => _isRunning;

  /// 检查间隔（分钟）
  int get intervalMinutes => _intervalMinutes;

  /// 今日打卡状态
  DailyPunchStatus get todayStatus {
    if (_todayRecord == null) return DailyPunchStatus.none;
    if (_todayRecord!.punchInTime != null &&
        _todayRecord!.punchOutTime != null) {
      return DailyPunchStatus.completed;
    }
    if (_todayRecord!.punchInTime != null) {
      return DailyPunchStatus.punchedIn;
    }
    return DailyPunchStatus.none;
  }

  /// 是否已打上班卡
  bool get hasPunchedIn => _todayRecord?.punchInTime != null;

  /// 是否已打下班卡
  bool get hasPunchedOut => _todayRecord?.punchOutTime != null;

  /// 今日总工作时长（分钟）
  int get todayWorkMinutes => _todayRecord?.workDurationMinutes ?? 0;

  // ===== 构造函数 =====

  PunchReminderEngine({
    NotificationService? notificationService,
    DatabaseService? databaseService,
  })  : _notificationService =
            notificationService ?? MockNotificationService(),
        _db = databaseService ?? DatabaseService();

  // ===== 生命周期 =====

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    stop();
    _notificationService.dispose();
    super.dispose();
  }

  // ===== 控制方法 =====

  /// 启动引擎
  ///
  /// [intervalMinutes] 检查间隔（分钟）
  /// [schedules] 排班列表
  /// [locations] 公司地点列表
  /// [currentLocation] 当前位置
  Future<void> start({
    int intervalMinutes = 5,
    List<WorkSchedule> schedules = const [],
    List<CompanyLocation> locations = const [],
    LocationResult? currentLocation,
    ThirdAppConfig? punchInTargetApp,
    ThirdAppConfig? punchOutTargetApp,
  }) async {
    if (_isRunning) await stop();

    _intervalMinutes = intervalMinutes;
    _schedules = schedules;
    _locations = locations;
    _currentLocation = currentLocation;
    _punchInTargetApp = punchInTargetApp;
    _punchOutTargetApp = punchOutTargetApp;

    // 初始化通知服务
    await _notificationService.initialize();

    _isRunning = true;

    // 立即执行第一次检查
    await _executeCheck();

    // 启动定时器（固定间隔）
    _tickTimer = Timer.periodic(
      Duration(minutes: _intervalMinutes),
      (_) => _executeCheck(),
    );

    notifyListeners();
    debugPrint('[PunchReminderEngine] 已启动，间隔=${intervalMinutes}分钟');
  }

  /// 停止引擎
  Future<void> stop() async {
    _isRunning = false;
    _tickTimer?.cancel();
    _tickTimer = null;
    debugPrint('[PunchReminderEngine] 已停止');
    notifyListeners();
  }

  /// 更新配置（不重启引擎）
  Future<void> updateConfig({
    int? intervalMinutes,
    List<WorkSchedule>? schedules,
    List<CompanyLocation>? locations,
    LocationResult? currentLocation,
    bool? reminderEnabled,
    bool? autoPunchEnabled,
    bool? autoLocationPunchEnabled,
    bool? delayPunchEnabled,
    ThirdAppConfig? punchInTargetApp,
    ThirdAppConfig? punchOutTargetApp,
  }) async {
    if (intervalMinutes != null) _intervalMinutes = intervalMinutes;
    if (schedules != null) _schedules = schedules;
    if (locations != null) _locations = locations;
    if (currentLocation != null) _currentLocation = currentLocation;
    if (reminderEnabled != null) _reminderEnabled = reminderEnabled;
    if (autoPunchEnabled != null) _autoPunchEnabled = autoPunchEnabled;
    if (autoLocationPunchEnabled != null) {
      _autoLocationPunchEnabled = autoLocationPunchEnabled;
    }
    if (delayPunchEnabled != null) _delayPunchEnabled = delayPunchEnabled;
    if (punchInTargetApp != null) _punchInTargetApp = punchInTargetApp;
    if (punchOutTargetApp != null) _punchOutTargetApp = punchOutTargetApp;

    // 如果引擎在运行，调整定时器间隔
    if (_isRunning && intervalMinutes != null) {
      _tickTimer?.cancel();
      _tickTimer = Timer.periodic(
        Duration(minutes: _intervalMinutes),
        (_) => _executeCheck(),
      );
    }

    notifyListeners();
  }

  /// 手动立即触发检查
  Future<ReminderCheckResult> forceCheck() async {
    await _executeCheck();
    return _lastCheckResult!;
  }

  /// 重置当天提醒状态（如用户手动打卡后调用）
  void resetSentReminders() {
    _sentReminders.clear();
  }

  // ===== 核心检查逻辑 =====

  Future<void> _executeCheck() async {
    if (!_isRunning) return;

    try {
      final now = DateTime.now();
      final today = _formatDate(now);
      final currentTime = _formatTime(now);

      // 1. 查找今天适用的排班
      final schedule = _findTodaySchedule();

      // 2. 确定时间窗口
      final window = _determineTimeWindow(currentTime, schedule);

      // 3. 获取今日打卡记录
      _todayRecord = await _db.getPunchRecordByDate(today);

      // 4. 确定打卡状态
      final punchStatus = _getPunchStatus();

      // 5. 检查是否已发送提醒
      final reminderKey = '$today-${window.name}';
      final alreadySent = _sentReminders.contains(reminderKey);

      // 6. 构建结果
      _lastCheckResult = ReminderCheckResult(
        schedule: schedule,
        window: window,
        punchStatus: punchStatus,
        reminderAlreadySent: alreadySent,
        checkTime: now,
        currentTimeStr: currentTime,
        todayDate: today,
      );

      // 7. 执行提醒/动作
      if (_reminderEnabled && _lastCheckResult!.shouldRemind) {
        await _processReminder(_lastCheckResult!, reminderKey);
      }

      _lastCheckTime = now;
      notifyListeners();
    } catch (e) {
      debugPrint('[PunchReminderEngine] 检查出错: $e');
    }
  }

  /// 处理提醒动作
  Future<void> _processReminder(
    ReminderCheckResult result,
    String reminderKey,
  ) async {
    final schedule = result.schedule;
    if (schedule == null) return;

    if (result.isPunchInTime) {
      // ===== 上班提醒 =====
      await _notificationService.showNotification(NotificationContent(
        id: 1000,
        title: '⏰ 上班打卡提醒',
        body: '现在是上班时间（${schedule.punchInStart}~${schedule.punchInEnd}），'
            '请及时打卡！',
        priority: NotificationPriority.high,
        channelId: 'punch_reminder',
        channelName: '打卡提醒',
        payload: {'type': 'punch_in', 'schedule_id': '${schedule.id}'},
      ));

      // 标记已发送
      _sentReminders.add(reminderKey);

      // 如果启用了位置触发自动打卡，检查围栏
      if (_autoLocationPunchEnabled && _currentLocation != null) {
        await _tryAutoLocationPunch(schedule, result.todayDate);
      }

      debugPrint('[PunchReminderEngine] 发送上班提醒');
    }

    if (result.isPunchOutTime) {
      // ===== 下班提醒 =====
      String body;
      if (_delayPunchEnabled) {
        body = '现在是下班时间（${schedule.punchOutStart}~${schedule.punchOutEnd}），'
            '如需延迟打卡可稍后操作。';
      } else {
        body = '现在是下班时间（${schedule.punchOutStart}~${schedule.punchOutEnd}），'
            '请及时打卡！';
      }

      await _notificationService.showNotification(NotificationContent(
        id: 1001,
        title: '⏰ 下班打卡提醒',
        body: body,
        priority: NotificationPriority.high,
        channelId: 'punch_reminder',
        channelName: '打卡提醒',
        payload: {'type': 'punch_out', 'schedule_id': '${schedule.id}'},
      ));

      _sentReminders.add(reminderKey);
      debugPrint('[PunchReminderEngine] 发送下班提醒');
    }
  }

  /// 尝试自动位置打卡
  Future<void> _tryAutoLocationPunch(
    WorkSchedule schedule,
    String today,
  ) async {
    // 检查是否在围栏内
    for (final loc in _locations) {
      if (schedule.companyLocationId != null &&
          schedule.companyLocationId != loc.id) {
        continue;
      }

      if (_currentLocation == null) continue;

      // 使用 LocationResult 的 distanceTo 检查距离
      final companyLoc = LocationResult(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      final distance = _currentLocation!.distanceTo(companyLoc);

      if (distance <= loc.geofenceRadius) {
        // 在围栏内！自动记录打卡
        await _autoRecordPunch(schedule, today, 'auto_location');

        // 如果启用了自动跳转，发送跳转通知
        if (_autoPunchEnabled) {
          final targetApp = _punchInTargetApp;
          if (targetApp != null) {
            await _notificationService.showNotification(NotificationContent(
              id: 2000,
              title: '🔄 自动跳转打卡',
              body: '您已到达${loc.name}，正在为您跳转到${targetApp.name}打卡...',
              priority: NotificationPriority.urgent,
              channelId: 'auto_punch',
              channelName: '自动打卡',
              payload: {
                'type': 'auto_jump',
                'app_name': targetApp.name,
                'package_name': targetApp.packageName ?? '',
              },
            ));
          }
        }

        debugPrint('[PunchReminderEngine] 自动位置打卡成功: ${loc.name}');
        break;
      }
    }
  }

  /// 自动记录打卡
  Future<void> _autoRecordPunch(
    WorkSchedule schedule,
    String today,
    String punchType,
  ) async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    // 判断是否迟到
    final punchInEnd = _parseTime(schedule.punchInEnd);
    final isLate = punchInEnd != null && now.isAfter(punchInEnd) ? 1 : 0;

    if (_todayRecord == null) {
      // 没有记录，创建新的
      final record = PunchRecord(
        date: today,
        punchInTime: nowStr,
        punchInType: punchType,
        isLate: isLate,
        scheduleGroupId: schedule.id,
      );
      await _db.upsertPunchRecordByDate(record);
    } else if (_todayRecord!.punchInTime == null) {
      // 已有记录但没有上班打卡，更新
      final updated = _todayRecord!.copyWith(
        punchInTime: nowStr,
        punchInType: punchType,
        isLate: isLate,
      );
      await _db.upsertPunchRecordByDate(updated);
    } else if (_todayRecord!.punchOutTime == null &&
        punchType != 'auto_location') {
      // 已打上班卡，现在是下班打卡
      final workDuration = _todayRecord!.punchInTime != null
          ? now.difference(DateTime.parse(_todayRecord!.punchInTime!)).inMinutes
          : 0;

      final punchOutEnd = _parseTime(schedule.punchOutEnd);
      final isEarlyLeave =
          punchOutEnd != null && now.isBefore(punchOutEnd) ? 1 : 0;

      final updated = _todayRecord!.copyWith(
        punchOutTime: nowStr,
        punchOutType: punchType,
        isEarlyLeave: isEarlyLeave,
        workDurationMinutes: workDuration,
      );
      await _db.upsertPunchRecordByDate(updated);
    }

    // 刷新记录
    _todayRecord = await _db.getPunchRecordByDate(today);
    notifyListeners();
  }

  /// 手动记录打卡（用户主动操作）
  Future<PunchRecord> manualPunchIn({
    required String type, // 'manual' | 'auto_jump'
    WorkSchedule? schedule,
  }) async {
    final now = DateTime.now();
    final today = _formatDate(now);
    final nowStr = now.toIso8601String();

    final activeSchedule = schedule ?? _findTodaySchedule();
    final punchInEnd = activeSchedule != null
        ? _parseTime(activeSchedule.punchInEnd)
        : null;
    final isLate =
        punchInEnd != null && now.isAfter(punchInEnd) ? 1 : 0;

    // 更新或创建记录
    _todayRecord = await _db.getPunchRecordByDate(today);

    if (_todayRecord == null) {
      _todayRecord = PunchRecord(
        date: today,
        punchInTime: nowStr,
        punchInType: type,
        isLate: isLate,
        scheduleGroupId: activeSchedule?.id,
      );
    } else {
      _todayRecord = _todayRecord!.copyWith(
        punchInTime: nowStr,
        punchInType: type,
        isLate: isLate,
        scheduleGroupId: activeSchedule?.id,
      );
    }

    await _db.upsertPunchRecordByDate(_todayRecord!);
    _sentReminders.add('$today-${TimeWindow.punchIn.name}');

    notifyListeners();
    return _todayRecord!;
  }

  /// 手动记录下班打卡
  Future<PunchRecord> manualPunchOut({
    required String type, // 'manual' | 'auto_jump'
    WorkSchedule? schedule,
    int? delayMinutes,
  }) async {
    final now = DateTime.now();
    final today = _formatDate(now);
    final nowStr = now.toIso8601String();

    final activeSchedule = schedule ?? _findTodaySchedule();

    _todayRecord = await _db.getPunchRecordByDate(today);

    if (_todayRecord == null) {
      // 没有上班记录就直接下班打卡
      _todayRecord = PunchRecord(
        date: today,
        punchOutTime: nowStr,
        punchOutType: type,
        scheduleGroupId: activeSchedule?.id,
        workDurationMinutes: 0,
      );
    } else {
      final punchInTime = _todayRecord!.punchInTime;
      final workDuration = punchInTime != null
          ? now.difference(DateTime.parse(punchInTime)).inMinutes
          : 0;

      final punchOutEnd = activeSchedule != null
          ? _parseTime(activeSchedule.punchOutEnd)
          : null;
      final isEarlyLeave =
          punchOutEnd != null && now.isBefore(punchOutEnd) ? 1 : 0;

      _todayRecord = _todayRecord!.copyWith(
        punchOutTime: nowStr,
        punchOutType: type,
        isEarlyLeave: isEarlyLeave,
        workDurationMinutes: workDuration,
      );
    }

    await _db.upsertPunchRecordByDate(_todayRecord!);
    _sentReminders.add('$today-${TimeWindow.punchOut.name}');

    // 如果使用了延迟打卡，记录延迟记录
    if (delayMinutes != null && delayMinutes > 0) {
      await _db.insertDelayRecord(DelayRecord(
        date: today,
        scheduleGroupId: activeSchedule?.id,
        delayMinutes: delayMinutes,
      ));
    }

    notifyListeners();
    return _todayRecord!;
  }

  // ===== 辅助方法 =====

  /// 查找今天适用的排班
  WorkSchedule? _findTodaySchedule() {
    final today = DateTime.now().weekday;
    for (final s in _schedules) {
      if (s.isEnabled == 1 && s.weekDays.contains(today)) {
        return s;
      }
    }
    return null;
  }

  /// 确定当前时间窗口
  TimeWindow _determineTimeWindow(String currentTime, WorkSchedule? schedule) {
    if (schedule == null) return TimeWindow.beforeWork;

    final now = _parseTime(currentTime);
    if (now == null) return TimeWindow.working;

    final inStart = _parseTime(schedule.punchInStart);
    final inEnd = _parseTime(schedule.punchInEnd);
    final outStart = _parseTime(schedule.punchOutStart);
    final outEnd = _parseTime(schedule.punchOutEnd);

    if (inStart == null || inEnd == null || outStart == null || outEnd == null) {
      return TimeWindow.working;
    }

    if (now.isBefore(inStart)) {
      return TimeWindow.beforeWork;
    } else if (!now.isAfter(inEnd)) {
      // now <= inEnd (considering seconds granularity)
      return TimeWindow.punchIn;
    } else if (now.isBefore(outStart)) {
      return TimeWindow.working;
    } else if (!now.isAfter(outEnd)) {
      return TimeWindow.punchOut;
    } else {
      return TimeWindow.afterWork;
    }
  }

  /// 获取今日打卡状态
  DailyPunchStatus _getPunchStatus() {
    if (_todayRecord == null) return DailyPunchStatus.none;
    if (_todayRecord!.punchInTime != null &&
        _todayRecord!.punchOutTime != null) {
      return DailyPunchStatus.completed;
    }
    if (_todayRecord!.punchInTime != null) {
      return DailyPunchStatus.punchedIn;
    }
    return DailyPunchStatus.none;
  }

  /// 格式化日期为 yyyy-MM-dd
  static String _formatDate(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  }

  /// 格式化时间为 HH:mm
  static String _formatTime(DateTime dt) {
    return '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  /// 解析 HH:mm 字符串为当天 DateTime
  static DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

// =============================================================================
// 工厂方法 — 创建带默认服务的引擎
// =============================================================================

/// 创建默认配置的打卡提醒引擎
PunchReminderEngine createDefaultEngine() {
  return PunchReminderEngine(
    notificationService: MockNotificationService(),
    databaseService: DatabaseService(),
  );
}
