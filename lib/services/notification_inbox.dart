import 'package:flutter/services.dart';

/// 通知抓取：Android 端通过 NotificationListenerService 拿到
/// 微信 / 支付宝 / 银行的到账与支付通知文本，经 EventChannel 送到 Flutter，
/// 再由规则解析器自动成账。
class NotificationInbox {
  static const _event = EventChannel('auto_ledger/notification_events');
  static const _method = MethodChannel('auto_ledger/notification');

  Stream<String>? _stream;

  Stream<String> get texts {
    _stream ??= _event
        .receiveBroadcastStream()
        .map((e) => (e as Map)['text']?.toString() ?? '')
        .where((s) => s.isNotEmpty);
    return _stream!;
  }

  /// 跳转到系统「通知使用权」授权页
  Future<bool> openPermissionSettings() async {
    try {
      final r = await _method.invokeMethod<bool>('openListenerSettings');
      return r ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 是否已授权
  Future<bool> hasPermission() async {
    try {
      final r = await _method.invokeMethod<bool>('hasPermission');
      return r ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
