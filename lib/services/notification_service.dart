library notification_service;

/// 通知服务
///
/// 提供本地推送通知的抽象接口与 Mock 实现。
/// - [NotificationService] 抽象基类
/// - [NotificationContent] 通知内容模型
/// - [MockNotificationService] 模拟实现（开发/测试/桌面环境）
///
/// 生产环境可替换为 [LocalNotificationService]（需 flutter_local_notifications）：
/// ```dart
/// final service = LocalNotificationService();
/// ```

import 'dart:async';
import 'package:flutter/foundation.dart';

// =============================================================================
// 数据模型
// =============================================================================

/// 通知优先级
enum NotificationPriority {
  /// 低优先级（静默通知）
  low,

  /// 默认优先级
  normal,

  /// 高优先级（提醒类）
  high,

  /// 最高优先级（警告类）
  urgent,
}

/// 通知内容
class NotificationContent {
  /// 通知标题
  final String title;

  /// 通知正文
  final String body;

  /// 可选的通知 ID（用于更新/取消特定通知）
  final int id;

  /// 优先级
  final NotificationPriority priority;

  /// 通知频道 ID
  final String channelId;

  /// 通知频道名称
  final String channelName;

  /// 附加数据（用于点击通知时传递）
  final Map<String, String>? payload;

  /// 是否震动
  final bool vibrate;

  const NotificationContent({
    required this.title,
    required this.body,
    this.id = 0,
    this.priority = NotificationPriority.normal,
    this.channelId = 'default_channel',
    this.channelName = '默认通知',
    this.payload,
    this.vibrate = true,
  });

  @override
  String toString() => 'Notification(id=$id, title=$title, body=$body)';
}

// =============================================================================
// 通知服务接口
// =============================================================================

/// 通知服务抽象基类
abstract class NotificationService {
  /// 初始化通知服务
  Future<void> initialize();

  /// 显示一条通知
  Future<void> showNotification(NotificationContent content);

  /// 取消指定通知
  Future<void> cancelNotification(int id);

  /// 取消所有通知
  Future<void> cancelAll();

  /// 更新已有通知（或创建新的）
  Future<void> updateNotification(NotificationContent content);

  /// 释放资源
  Future<void> dispose();
}

// =============================================================================
// Mock 通知服务实现
// =============================================================================

/// 模拟通知服务
///
/// 记录通知历史，支持回调监听，不实际发送通知。
class MockNotificationService extends ChangeNotifier
    implements NotificationService {
  // ===== 内部状态 =====

  /// 通知历史记录
  final List<NotificationContent> _notificationHistory = [];

  /// 最近一次通知
  NotificationContent? _lastNotification;

  // ===== 回调 =====

  /// 通知回调（每次发送通知时触发）
  void Function(NotificationContent notification)? onNotification;

  // ===== 公开状态 =====

  /// 通知历史（按时间顺序）
  List<NotificationContent> get history =>
      List.unmodifiable(_notificationHistory);

  /// 最近一条通知
  NotificationContent? get lastNotification => _lastNotification;

  /// 通知总数
  int get notificationCount => _notificationHistory.length;

  /// 根据 ID 查找通知
  NotificationContent? findNotificationById(int id) {
    try {
      return _notificationHistory.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 清空历史记录
  void clearHistory() {
    _notificationHistory.clear();
    _lastNotification = null;
    notifyListeners();
  }

  // ===== 接口实现 =====

  @override
  Future<void> initialize() async {
    debugPrint('[MockNotificationService] 已初始化');
  }

  @override
  Future<void> showNotification(NotificationContent content) async {
    _lastNotification = content;
    _notificationHistory.add(content);
    onNotification?.call(content);
    debugPrint('[MockNotificationService] 通知: $content');
    notifyListeners();
  }

  @override
  Future<void> cancelNotification(int id) async {
    debugPrint('[MockNotificationService] 取消通知: id=$id');
  }

  @override
  Future<void> cancelAll() async {
    debugPrint('[MockNotificationService] 取消所有通知');
  }

  @override
  Future<void> updateNotification(NotificationContent content) async {
    _lastNotification = content;
    _notificationHistory.add(content);
    onNotification?.call(content);
    debugPrint('[MockNotificationService] 更新通知: $content');
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    debugPrint('[MockNotificationService] 已释放');
    super.dispose();
  }
}
