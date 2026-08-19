import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

const String _channelId = 'stock_updates';
const int _notificationId = 1;

/// Interface so the app can run with a fake push service in tests.
abstract class PushService {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> subscribeToTopic(String topic);
}

/// Real FCM implementation backed by firebase_messaging and
/// flutter_local_notifications.
class FcmService implements PushService {
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message) {
        StockNotificationDisplayer.show(
          title: message.notification?.title ?? 'Stock Updated!',
          body: message.notification?.body ?? 'The stock has changed.',
          imageUrl: firstImageUrlFromMessage(message),
        );
      });
    } catch (e) {
      // FCM is unavailable (e.g. missing google-services.json) — the app
      // still works, only push notifications are disabled.
      debugPrint('FCM unavailable: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    await _messaging?.subscribeToTopic(topic);
  }
}

/// Picks the first non-empty fruit image URL from the message's data payload.
String? firstImageUrlFromMessage(RemoteMessage message) {
  final raw = message.data['imageUrls'];
  if (raw == null) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in map.entries) {
      if (entry.value is String && (entry.value as String).isNotEmpty) {
        return entry.value as String;
      }
    }
  } catch (_) {
    // malformed data payload — fall back to no image
  }
  return null;
}

/// Shows stock-change notifications with a BigPictureStyle fruit image.
/// Kept free of firebase_messaging dependencies so it can run from the
/// background isolate handler.
class StockNotificationDisplayer {
  StockNotificationDisplayer._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  static Future<void> show({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    await ensureInitialized();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Stock Updates',
        description: 'Notifications when the Blox Fruits stock changes',
        importance: Importance.max,
      ),
    );

    String? imagePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        imagePath = await _downloadImage(imageUrl);
      } catch (_) {
        imagePath = null;
      }
    }

    final style = imagePath != null
        ? BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            hideExpandedLargeIcon: true,
            contentTitle: title,
            summaryText: body,
          )
        : null;

    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Stock Updates',
          channelDescription: 'Notifications when the Blox Fruits stock changes',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: style,
        ),
      ),
    );
  }

  /// Downloads the fruit image into a temp file so BigPictureStyle can use it.
  static Future<String> _downloadImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('image download failed: ${response.statusCode}');
    }
    final file = File('${Directory.systemTemp.path}/blox_notify_stock.img');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }
}

/// Runs when the app is terminated and a stock notification arrives.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await StockNotificationDisplayer.show(
    title: message.notification?.title ?? 'Stock Updated!',
    body: message.notification?.body ?? 'The stock has changed.',
    imageUrl: firstImageUrlFromMessage(message),
  );
}