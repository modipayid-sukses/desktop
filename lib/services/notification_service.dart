import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:gobank/home/notifications.dart';
import 'package:gobank/utils/string.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _navigateToNotificationPage();
      },
    );

    const channel = AndroidNotificationChannel(
      'transactions',
      'Transaction Notifications',
      description: 'Notifikasi transaksi berhasil',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) {
        return;
      }

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'transactions',
            'Transaction Notifications',
            channelDescription: 'Notifikasi transaksi berhasil',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToNotificationPage();
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _navigateToNotificationPage();
      }
    });

    _messaging.onTokenRefresh.listen((token) async {
      await syncTokenWithServer(token);
    });

    _initialized = true;
  }

  void _navigateToNotificationPage() {
    try {
      Future.delayed(const Duration(milliseconds: 500), () {
        Get.to(() => const Notificationindex(CustomStrings.notification));
      });
    } catch (e) {
      debugPrint('Error navigating to notification page: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Failed to get FCM token: $error');
      return null;
    }
  }

  Future<void> syncTokenWithServer([String? token]) async {
    final resolvedToken = token ?? await getToken();
    if (resolvedToken == null || ApiService.getToken() == null) {
      return;
    }

    try {
      await ApiService.updateFcmToken(resolvedToken);
    } catch (error) {
      debugPrint('Failed to sync FCM token: $error');
    }
  }
}
