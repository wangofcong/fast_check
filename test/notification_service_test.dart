import 'package:flutter_test/flutter_test.dart';
import 'package:fast_check/services/notification_service.dart';

void main() {
  group('NotificationContent', () {
    test('创建基本通知', () {
      final n = NotificationContent(
        title: '测试标题',
        body: '测试内容',
      );
      expect(n.title, '测试标题');
      expect(n.body, '测试内容');
      expect(n.id, 0);
      expect(n.priority, NotificationPriority.normal);
      expect(n.vibrate, isTrue);
    });

    test('创建带自定义参数的通知', () {
      final n = NotificationContent(
        title: '上班提醒',
        body: '请打卡',
        id: 1001,
        priority: NotificationPriority.high,
        channelId: 'punch',
        channelName: '打卡提醒',
        payload: {'type': 'punch_in'},
        vibrate: true,
      );
      expect(n.id, 1001);
      expect(n.priority, NotificationPriority.high);
      expect(n.channelId, 'punch');
      expect(n.payload, {'type': 'punch_in'});
    });

    test('toString 格式', () {
      final n = NotificationContent(title: 'T', body: 'B', id: 5);
      expect(n.toString(), contains('id=5'));
      expect(n.toString(), contains('T'));
      expect(n.toString(), contains('B'));
    });
  });

  group('NotificationPriority', () {
    test('枚举值定义正确', () {
      expect(NotificationPriority.values.length, 4);
      expect(NotificationPriority.values,
          contains(NotificationPriority.low));
      expect(NotificationPriority.values,
          contains(NotificationPriority.normal));
      expect(NotificationPriority.values,
          contains(NotificationPriority.high));
      expect(NotificationPriority.values,
          contains(NotificationPriority.urgent));
    });
  });

  group('MockNotificationService', () {
    late MockNotificationService service;

    setUp(() {
      service = MockNotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('初始化后状态正确', () async {
      await service.initialize();
      expect(service.notificationCount, 0);
      expect(service.history, isEmpty);
      expect(service.lastNotification, isNull);
    });

    test('showNotification 记录通知', () async {
      final content = NotificationContent(title: '测试', body: '内容');
      await service.showNotification(content);

      expect(service.notificationCount, 1);
      expect(service.lastNotification, content);
      expect(service.history.first, content);
    });

    test('多次发送通知累积历史', () async {
      await service.showNotification(
          NotificationContent(title: 'A', body: '1', id: 1));
      await service.showNotification(
          NotificationContent(title: 'B', body: '2', id: 2));
      await service.showNotification(
          NotificationContent(title: 'C', body: '3', id: 3));

      expect(service.notificationCount, 3);
      expect(service.history.length, 3);
    });

    test('findNotificationById 按 ID 查找', () async {
      await service.showNotification(
          NotificationContent(title: 'A', body: '1', id: 10));
      await service.showNotification(
          NotificationContent(title: 'B', body: '2', id: 20));

      final found = service.findNotificationById(10);
      expect(found, isNotNull);
      expect(found!.title, 'A');

      final notFound = service.findNotificationById(999);
      expect(notFound, isNull);
    });

    test('updateNotification 记录更新', () async {
      final content = NotificationContent(title: '更新', body: '内容', id: 1);
      await service.updateNotification(content);

      expect(service.notificationCount, 1);
      expect(service.lastNotification, content);
    });

    test('clearHistory 清空历史', () async {
      await service.showNotification(NotificationContent(title: 'A', body: '1'));
      expect(service.notificationCount, 1);

      service.clearHistory();
      expect(service.notificationCount, 0);
      expect(service.lastNotification, isNull);
    });

    test('onNotification 回调触发', () async {
      NotificationContent? captured;
      service.onNotification = (n) {
        captured = n;
      };

      final content = NotificationContent(title: '回调', body: '测试');
      await service.showNotification(content);

      expect(captured, isNotNull);
      expect(captured!.title, '回调');
    });

    test('cancelAll 不报错', () async {
      await service.cancelAll();
    });

    test('cancelNotification 不报错', () async {
      await service.cancelNotification(123);
    });

    test('dispose 不报错', () async {
      await service.dispose();
    });
  });
}
