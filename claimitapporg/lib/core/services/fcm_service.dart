// ─────────────────────────────────────────────────────────────────────────────
// FcmService
//
// Wraps Firebase Cloud Messaging + flutter_local_notifications so the app can:
//   1. Ask the user for notification permission (Android 13+ / iOS).
//   2. Fetch the device's FCM token (send this to YOUR backend so it can push
//      notifications to this specific device).
//   3. Show a system "popup" (heads-up) notification when:
//        - a push arrives while the app is in the FOREGROUND (FCM alone does
//          NOT show a banner in foreground — flutter_local_notifications does)
//        - we want to show a LOCAL notification ourselves, e.g. right after a
//          successful login/OTP verification ("Login successful").
//
// SETUP REQUIRED BEFORE THIS WORKS (see FIREBASE_FCM_SETUP.md in repo root):
//   - android/app/google-services.json   (download from Firebase console)
//   - ios/Runner/GoogleService-Info.plist (download from Firebase console)
//   - android/build.gradle.kts            -> add google-services classpath
//   - android/app/build.gradle.kts        -> apply google-services plugin
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart' show rootNavigatorKey;

/// Must be a TOP-LEVEL (or static) function — handles pushes that arrive
/// while the app is completely killed / in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase.initializeApp() must be called again here because this runs
  // in a separate isolate.
  await Firebase.initializeApp();
  // No UI work here — the OS shows the notification automatically for
  // "notification" payloads when the app is backgrounded/terminated.
  debugPrint('📩 [FCM-Background] ${message.messageId}: ${message.notification?.title}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'claimit_default_channel', // id — must match the one used when showing notifications
    'Claimit Notifications', // user-visible name (Settings > Apps > Claimit > Notifications)
    description: 'Login alerts, offers, reminders and claim updates',
    importance: Importance.high,
  );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  /// Call this once, early in main(), AFTER Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Local notifications (the part that actually draws the popup/banner
    //    while the app is open — FCM "foreground" pushes are silent by default).
    await _initLocalNotifications();

    // 2. Ask the user for permission (required on iOS and Android 13+).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 FCM permission status: ${settings.authorizationStatus}');

    // 3. iOS: make sure foreground notifications are actually displayed.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Grab the device token — SEND THIS TO YOUR BACKEND.
    //    The backend stores it against the logged-in user and uses it (via the
    //    Firebase Admin SDK / HTTP v1 API) to target push notifications at
    //    this specific device.
    _fcmToken = await _messaging.getToken();
    debugPrint('🔑 FCM device token: $_fcmToken');
    // TODO: POST _fcmToken to your backend, e.g.:
    //   await ApiClient().post('/users/fcm-token', data: {'token': _fcmToken});

    // Token can rotate (app reinstall, data clear, etc.) — re-send when it does.
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('🔄 FCM token refreshed: $newToken');
      // TODO: POST newToken to your backend again.
    });

    // 5. FOREGROUND pushes: FCM delivers the data but does NOT show a banner —
    //    we draw it ourselves with flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // 6. User taps a push that arrived while app was backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('👉 Notification opened app: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // 7. App was launched BY tapping a push (was fully terminated).
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App launched from terminated state via push: ${initialMessage.data}');
      _handleNotificationTap(initialMessage.data);
    }
  }

  /// Routes the user to the right screen when they tap a notification —
  /// for now everything opens the in-app Notifications page (more
  /// notification-type-specific routing can be added later via the
  /// `type` field carried in `data`).
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        debugPrint('⚠️ FcmService: no navigator context yet, cannot route tap');
        return;
      }
      context.push('/notifications');
    } catch (e) {
      debugPrint('⚠️ FcmService: failed to navigate on notification tap: $e');
    }
  }

  /// Parses the `payload` string set on local notifications (format:
  /// a Dart Map's toString(), e.g. "{type: bill_review_approved, ...}")
  /// back into routing — for now always opens the Notifications page,
  /// except for the special 'login_success' payload which has nowhere to go.
  void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty || payload == 'login_success') return;
    try {
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        debugPrint('⚠️ FcmService: no navigator context yet, cannot route tap');
        return;
      }
      context.push('/notifications');
    } catch (e) {
      debugPrint('⚠️ FcmService: failed to navigate on local notification tap: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('🖱️ Local notification tapped, payload: ${response.payload}');
        _handleLocalNotificationTap(response.payload);
      },
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Draws a heads-up banner for a push that arrived while the app is open.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await showLocalNotification(
      title: notification.title ?? 'Claimit',
      body: notification.body ?? '',
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  /// Public helper to pop a notification banner directly from app code —
  /// e.g. right after a successful OTP/login, with no server round-trip.
  /// This is what powers the "✅ Login successful" popup the user asked for.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Convenience wrapper used by the OTP screen after a successful login.
  Future<void> showLoginSuccessNotification({String? userLabel}) {
    return showLocalNotification(
      title: '✅ Login Successful',
      body: userLabel != null && userLabel.isNotEmpty
          ? 'Welcome back, $userLabel! You are now logged in to Claimit.'
          : 'You are now logged in to Claimit.',
      payload: 'login_success',
    );
  }
}
