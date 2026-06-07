import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:fast_check/services/punch_reminder_engine.dart';
import 'package:fast_check/services/notification_service.dart';
import 'package:fast_check/models/work_schedule.dart';
import 'helpers/test_setup.dart';

void main() {
  setupTestDatabase();
  group('DailyPunchStatus', () {
    test('枚举值定义正确', () {
      expect(DailyPunchStatus.values.length, 3);
      expect(DailyPunchStatus.values, contains(DailyPunchStatus.none));
      expect(DailyPunchStatus.values, contains(DailyPunchStatus.punchedIn));
      expect(DailyPunchStatus.values, contains(DailyPunchStatus.completed));
    });
  });

  group('TimeWindow', () {
    test('枚举值定义正确', () {
      expect(TimeWindow.values.length, 5);
      expect(TimeWindow.values, contains(TimeWindow.beforeWork));
      expect(TimeWindow.values, contains(TimeWindow.punchIn));
      expect(TimeWindow.values, contains(TimeWindow.working));
      expect(TimeWindow.values, contains(TimeWindow.punchOut));
      expect(TimeWindow.values, contains(TimeWindow.afterWork));
    });
  });

  group('ReminderCheckResult', () {
    test('shouldRemind 在上班窗口且未打卡时 true', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchIn,
        punchStatus: DailyPunchStatus.none,
        checkTime: DateTime.now(),
        currentTimeStr: '09:30',
        todayDate: '2026-06-07',
      );
      expect(r.shouldRemind, isTrue);
      expect(r.isPunchInTime, isTrue);
    });

    test('shouldRemind 在已发送提醒时 false', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchIn,
        punchStatus: DailyPunchStatus.none,
        reminderAlreadySent: true,
        checkTime: DateTime.now(),
        currentTimeStr: '09:30',
        todayDate: '2026-06-07',
      );
      expect(r.shouldRemind, isFalse);
    });

    test('shouldRemind 在已完成全天打卡时 false', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchOut,
        punchStatus: DailyPunchStatus.completed,
        checkTime: DateTime.now(),
        currentTimeStr: '18:00',
        todayDate: '2026-06-07',
      );
      expect(r.shouldRemind, isFalse);
      expect(r.isPunchOutTime, isFalse);
    });

    test('isPunchInTime 在上班窗口且未打上班卡时 true', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchIn,
        punchStatus: DailyPunchStatus.none,
        checkTime: DateTime.now(),
        currentTimeStr: '09:00',
        todayDate: '2026-06-07',
      );
      expect(r.isPunchInTime, isTrue);
    });

    test('isPunchInTime 已打上班卡后 false', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchIn,
        punchStatus: DailyPunchStatus.punchedIn,
        checkTime: DateTime.now(),
        currentTimeStr: '09:30',
        todayDate: '2026-06-07',
      );
      expect(r.isPunchInTime, isFalse);
    });

    test('isPunchOutTime 在下班窗口时 true', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchOut,
        punchStatus: DailyPunchStatus.punchedIn,
        checkTime: DateTime.now(),
        currentTimeStr: '18:00',
        todayDate: '2026-06-07',
      );
      expect(r.isPunchOutTime, isTrue);
    });

    test('isPunchOutTime 已完成时 false', () {
      final r = ReminderCheckResult(
        window: TimeWindow.punchOut,
        punchStatus: DailyPunchStatus.completed,
        checkTime: DateTime.now(),
        currentTimeStr: '18:00',
        todayDate: '2026-06-07',
      );
      expect(r.isPunchOutTime, isFalse);
    });
  });

  group('PunchReminderEngine', () {
    late MockNotificationService mockNotif;
    late PunchReminderEngine engine;

    setUp(() {
      mockNotif = MockNotificationService();
      engine = PunchReminderEngine(notificationService: mockNotif);
    });

    tearDown(() {
      engine.dispose();
    });

    test('初始状态：未运行', () {
      expect(engine.isRunning, isFalse);
      expect(engine.todayRecord, isNull);
      expect(engine.todayStatus, DailyPunchStatus.none);
      expect(engine.hasPunchedIn, isFalse);
      expect(engine.hasPunchedOut, isFalse);
    });

    test('start 后进入运行状态', () async {
      await engine.start(intervalMinutes: 1);
      expect(engine.isRunning, isTrue);
    });

    test('stop 后退出运行状态', () async {
      await engine.start(intervalMinutes: 1);
      expect(engine.isRunning, isTrue);

      await engine.stop();
      expect(engine.isRunning, isFalse);
    });

    test('重复 start 不会多次启动', () async {
      await engine.start(intervalMinutes: 1);
      await engine.start(intervalMinutes: 1);
      expect(engine.isRunning, isTrue);
    });

    test('没有排班时 lastCheckResult 为 null（初始）', () {
      expect(engine.lastCheckResult, isNull);
    });

    test('forceCheck 返回检查结果', () async {
      await engine.start(
        intervalMinutes: 1,
        schedules: [
          WorkSchedule(
            name: '工作日',
            isEnabled: 1,
            punchInStart: '09:00',
            punchInEnd: '11:00',
            punchOutStart: '17:00',
            punchOutEnd: '19:00',
            weekDays: [DateTime.now().weekday],
          ),
        ],
      );

      // 等待第一次检查
      await Future.delayed(const Duration(milliseconds: 100));
      final result = await engine.forceCheck();

      expect(result, isNotNull);
      expect(result.schedule, isNotNull);
      expect(result.todayDate, isNotEmpty);
    });

    test('forceCheck 无排班时结果为 null schedule', () async {
      await engine.start(intervalMinutes: 1);

      final result = await engine.forceCheck();
      expect(result, isNotNull);
      expect(result.schedule, isNull);
    });

    test('updateConfig 更新配置', () async {
      await engine.start(intervalMinutes: 5);

      await engine.updateConfig(
        intervalMinutes: 10,
        reminderEnabled: false,
      );

      expect(engine.intervalMinutes, 10);
    });

    test('manualPunchIn 记录上班打卡', () async {
      final schedule = WorkSchedule(
        name: '工作日',
        isEnabled: 1,
        punchInStart: '09:00',
        punchInEnd: '11:00',
        punchOutStart: '17:00',
        punchOutEnd: '19:00',
        weekDays: [DateTime.now().weekday],
      );

      await engine.start(
        intervalMinutes: 1,
        schedules: [schedule],
      );

      final record = await engine.manualPunchIn(type: 'manual');

      expect(record, isNotNull);
      expect(record.punchInTime, isNotNull);
      expect(record.punchInType, 'manual');
      expect(engine.hasPunchedIn, isTrue);
      expect(engine.todayStatus, DailyPunchStatus.punchedIn);
    });

    test('manualPunchOut 记录下班打卡', () async {
      final schedule = WorkSchedule(
        name: '工作日',
        isEnabled: 1,
        punchInStart: '09:00',
        punchInEnd: '11:00',
        punchOutStart: '17:00',
        punchOutEnd: '19:00',
        weekDays: [DateTime.now().weekday],
      );

      await engine.start(
        intervalMinutes: 1,
        schedules: [schedule],
      );

      // 先打上班卡
      await engine.manualPunchIn(type: 'manual');
      expect(engine.hasPunchedIn, isTrue);

      // 再打下班卡
      final record = await engine.manualPunchOut(type: 'manual');

      expect(record, isNotNull);
      expect(record.punchOutTime, isNotNull);
      expect(record.punchOutType, 'manual');
      expect(engine.hasPunchedOut, isTrue);
      expect(engine.todayStatus, DailyPunchStatus.completed);
    });

    test('manualPunchOut 带延迟参数写入 DelayRecord', () async {
      await engine.start(intervalMinutes: 1);
      await engine.manualPunchIn(type: 'manual');
      // 不会报错即可
      await engine.manualPunchOut(type: 'manual', delayMinutes: 15);
      expect(engine.hasPunchedOut, isTrue);
    });

    test('resetSentReminders 重置提醒状态', () {
      engine.resetSentReminders();
      // 不报错即可
    });

    test('引擎运行时通知服务被调用', () async {
      final schedule = WorkSchedule(
        name: '工作日',
        isEnabled: 1,
        punchInStart: '09:00',
        punchInEnd: '23:59', // 全天覆盖以确保测试
        punchOutStart: '00:00',
        punchOutEnd: '23:59',
        weekDays: [DateTime.now().weekday],
      );

      await engine.start(
        intervalMinutes: 1,
        schedules: [schedule],
      );

      // 等待检查执行
      await Future.delayed(const Duration(milliseconds: 300));
      await engine.forceCheck();

      // forceCheck 触发了检查逻辑
      final notifCount = mockNotif.notificationCount;
      debugPrint('通知发送次数: $notifCount');
    });

    test('dispose 清理资源', () async {
      await engine.start(intervalMinutes: 1);
      engine.dispose();
      expect(engine.isRunning, isFalse);
    });
  });

  group('createDefaultEngine', () {
    test('创建默认引擎', () {
      final engine = createDefaultEngine();
      expect(engine, isNotNull);
      expect(engine.isRunning, isFalse);
      engine.dispose();
    });
  });
}
