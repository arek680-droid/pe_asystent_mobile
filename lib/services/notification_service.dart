import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'log_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      LogService().addLog('NotificationService: Starting initialization...');
      // Android Initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      final result = await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          LogService().addLog('NotificationService: Notification clicked payload=${details.payload}');
        },
      );

      LogService().addLog('NotificationService: Plugin initialize() result = $result');

      // Request permissions for Android 13+ (API level 33+)
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          LogService().addLog('NotificationService: Android permission request result: $granted');
        } else {
          LogService().addLog('NotificationService: Could not obtain Android implementation of local notifications plugin');
        }
      } else {
        LogService().addLog('NotificationService: Skipping permissions (Platform is not Android)');
      }

      _initialized = true;
      LogService().addLog('NotificationService: Initialized successfully');
    } catch (e) {
      LogService().addLog('NotificationService: ERROR during initialization: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      LogService().addLog('NotificationService: showNotification called but not initialized. Initializing now...');
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pe_asystent_notifications', // Channel ID
        'Powiadomienia PE Asystent', // Channel Name
        channelDescription: 'Kanał do powiadomień o zadaniach i komentarzach',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      LogService().addLog('NotificationService: Sending local show() request for ID: $id, Title: "$title"');
      await _localNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );

      LogService().addLog('NotificationService: Notification successfully shown on system.');
    } catch (e) {
      LogService().addLog('NotificationService: ERROR showing notification: $e');
    }
  }
}
