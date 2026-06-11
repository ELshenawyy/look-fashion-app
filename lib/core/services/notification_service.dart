import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenSub;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'high_importance_channel';
  static const _channelName = 'تحديثات الطلبات';

  // ─────────────────────────────────────────────────────────────────────────
  // init() — يُستدعى مرة واحدة في main()
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
        const InitializationSettings(android: androidSettings));

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
          playSound: true,
        ));

    // عرض الإشعارات وهو التطبيق مفتوح (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // initialize(uid) — يُستدعى عند تسجيل دخول مستخدم
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> initialize(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return;

      await _saveToken(uid);
      await _tokenSub?.cancel();
      _tokenSub = _messaging.onTokenRefresh
          .listen((token) => _saveToken(uid, token: token));
    } catch (e) {
      debugPrint('[NotificationService] initialize failed: $e');
    }
  }

  static Future<void> cleanup() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }

  static Future<void> _saveToken(String uid, {String? token}) async {
    try {
      token ??= await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[NotificationService] token save failed: $e');
    }
  }
}
