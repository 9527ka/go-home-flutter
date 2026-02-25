import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final _service = NotificationService();
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  /// 从服务端拉取未读数量
  Future<void> fetchUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  /// 标记全部已读后清零
  void clearUnread() {
    if (_unreadCount != 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  /// 读了一条，数量减一
  void decrementUnread() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }
}
