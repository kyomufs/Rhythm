import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Provider for the local notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Payload нажатия: открыть журнал изменений расписания.
const String changesNotificationPayload = 'changes';

/// Wraps flutter_local_notifications: permission request + local notifications.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Обработчик нажатия по уведомлению. Ставит оболочка приложения:
  /// сервис не знает ни про навигатор, ни про вкладки.
  void Function(String? payload)? onTap;

  /// Все поддерживаемые платформы, кроме web. Плагин умеет Android, iOS,
  /// macOS, Linux (через org.freedesktop.Notifications) и Windows.
  static bool get _supported => !kIsWeb;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'rhythm_main',
    'Rhythm',
    channelDescription: 'Расписание, оценки и изменения',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// На Linux уведомление живёт в демоне рабочего стола, поэтому важность и
  /// категорию задаём явно: с `low` его сворачивают в «Не беспокоить».
  static const LinuxNotificationDetails _linuxDetails =
      LinuxNotificationDetails(
    urgency: LinuxNotificationUrgency.normal,
    category: LinuxNotificationCategory.im,
    defaultActionName: 'Открыть',
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
    linux: _linuxDetails,
  );

  /// Initialize the plugin (idempotent). Safe to call from `build`.
  Future<void> init() async {
    if (_initialized) return;
    if (!_supported) {
      _initialized = true;
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
      ),
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );
    _initialized = true;
  }

  /// Ask the OS for notification permission. Returns true when allowed.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      return await macos.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return true; // Desktop and other platforms: no runtime permission.
  }

  /// Current permission status (best effort).
  Future<bool> areNotificationsEnabled() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Show a local notification. [payload] is handed back to [onTap].
  Future<void> show(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    await init();
    if (!_supported) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: _details,
    );
  }
}
