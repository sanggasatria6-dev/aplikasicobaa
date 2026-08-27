import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message if needed
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize(WidgetRef ref, BuildContext context) async {
    try {
      // 1. Request permission (Android 13+ / iOS)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Get FCM Token
        String? token = await _fcm.getToken();
        if (token != null) {
          debugPrint("FCM Device Token: $token");
          // Send token to backend
          await _registerTokenWithBackend(ref, token);
        }

        // Listen for token refresh
        _fcm.onTokenRefresh.listen((newToken) {
          _registerTokenWithBackend(ref, newToken);
        });

        // 3. Set background handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // 4. Foreground Message Listener (Saat aplikasi sedang dibuka)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint("Foreground FCM Message: ${message.notification?.title}");
          
          // Refresh list notifikasi di app
          ref.invalidate(notificationsProvider);

          // Tampilkan Banner In-App
          final title = message.notification?.title ?? "Sinyal AI Baru";
          final body = message.notification?.body ?? "";
          final type = message.data['type'] ?? 'BUY';

          Color bannerColor = const Color(0xFF059669);
          if (type == 'SELL' || type == 'STOP_LOSS') {
            bannerColor = const Color(0xFFDC2626);
          } else if (type == 'TAKE_PROFIT') {
            bannerColor = const Color(0xFFD97706);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: bannerColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint("Push notification init error: $e");
    }
  }

  static Future<void> _registerTokenWithBackend(WidgetRef ref, String token) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/notifications/fcm-token', data: {
        'fcm_token': token,
        'platform': 'android',
      });
      debugPrint("FCM Token successfully registered to AI Trading Backend");
    } catch (e) {
      debugPrint("Failed to register FCM token: $e");
    }
  }
}
