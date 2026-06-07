import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/providers/reminder_provider.dart';
import 'package:fast_check/services/punch_reminder_engine.dart';
import 'helpers/test_setup.dart';

void main() {
  setupTestDatabase();
  group('ReminderProvider', () {
    late ReminderProvider provider;

    setUp(() {
      provider = ReminderProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('初始状态', () {
      expect(provider.isEngineRunning, isFalse);
      expect(provider.todayRecord, isNull);
      expect(provider.todayStatus, DailyPunchStatus.none);
      expect(provider.hasPunchedIn, isFalse);
      expect(provider.hasPunchedOut, isFalse);
      expect(provider.todayWorkMinutes, 0);
      expect(provider.formattedWorkDuration, '--');
      expect(provider.checkCount, 0);
      expect(provider.notificationCount, 0);
    });

    test('start 后引擎运行', () async {
      await provider.start();
      expect(provider.isEngineRunning, isTrue);
    });

    test('stop 后引擎停止', () async {
      await provider.start();
      expect(provider.isEngineRunning, isTrue);

      await provider.stop();
      expect(provider.isEngineRunning, isFalse);
    });

    test('重复 start 不报错', () async {
      await provider.start();
      await provider.start();
      expect(provider.isEngineRunning, isTrue);
    });

    test('restart 重启引擎', () async {
      await provider.start();
      expect(provider.isEngineRunning, isTrue);

      await provider.restart();
      expect(provider.isEngineRunning, isTrue);
    });

    test('manualPunchIn 记录打卡', () async {
      await provider.start();
      final record = await provider.manualPunchIn();

      expect(record, isNotNull);
      expect(provider.hasPunchedIn, isTrue);
      expect(provider.todayStatus, DailyPunchStatus.punchedIn);
    });

    test('manualPunchOut 记录下班打卡', () async {
      await provider.start();
      await provider.manualPunchIn();
      final record = await provider.manualPunchOut();

      expect(record, isNotNull);
      expect(provider.hasPunchedOut, isTrue);
      expect(provider.todayStatus, DailyPunchStatus.completed);
    });

    test('manualPunchOut 带延迟参数', () async {
      await provider.start();
      await provider.manualPunchIn();
      final record = await provider.manualPunchOut(delayMinutes: 30);

      expect(record, isNotNull);
      expect(provider.hasPunchedOut, isTrue);
    });

    test('forceCheck 增加检查计数', () async {
      await provider.start();
      expect(provider.checkCount, 0);

      await provider.forceCheck();
      expect(provider.checkCount, 1);

      await provider.forceCheck();
      expect(provider.checkCount, 2);
    });

    test('resetReminders 不报错', () {
      provider.resetReminders();
    });

    test('currentWindowDescription 默认返回待检查', () {
      expect(provider.currentWindowDescription, '待检查');
    });

    test('todayScheduleName 默认返回无可用排班', () {
      expect(provider.todayScheduleName, '无可用排班');
    });

    test('dispose 清理资源', () {
      provider.dispose();
      // 再次调用不应报错
      provider.dispose();
    });

    test('getRecordByDate 查询记录', () async {
      // 先创建一个记录
      await provider.start();
      await provider.manualPunchIn();

      final today = _formatDate(DateTime.now());
      final record = await provider.getRecordByDate(today);
      expect(record, isNotNull);
      expect(record!.punchInTime, isNotNull);
    });

    test('getRecordsByMonth 查询月度记录', () async {
      final now = DateTime.now();
      final records = await provider.getRecordsByMonth(now.year, now.month);
      expect(records, isNotEmpty);
    });
  });
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
