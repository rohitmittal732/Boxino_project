import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Notification Service ────────────────────────────────────────────────────
//
// This is the notification layer for Boxino.
// Firebase Messaging integration is stubbed here. Once you:
//   1. Create a Firebase project at console.firebase.google.com
//   2. Add Android: download google-services.json → android/app/
//   3. Run: flutter pub add firebase_core firebase_messaging
//   4. In main.dart: await Firebase.initializeApp()
// ... then uncomment the firebase_messaging lines below.
//
// For now, logging functions are in place so the rest of the app can call
// NotificationService.notifyOrderPlaced() etc. without compile errors.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  Future<void> init() async {
    // Step 1: Firebase not yet configured — skipping init
    debugPrint('[NotificationService] Firebase not yet configured. Skipping init.');
    
    // Uncomment after Firebase setup:
    // await Firebase.initializeApp();
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission(alert: true, badge: true, sound: true);
    // final token = await messaging.getToken();
    // debugPrint('[NotificationService] FCM Token: $token');
    // FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    // FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  Future<void> saveUserFcmToken(String userId) async {
    // Save FCM token to Supabase `users` table for targeted push delivery
    // After firebase setup:
    // final token = await FirebaseMessaging.instance.getToken();
    // await Supabase.instance.client.from('users').update({'fcm_token': token}).eq('id', userId);
    debugPrint('[NotificationService] saveFcmToken — not yet configured.');
  }

  static void notifyOrderPlaced(String deliveryBoyName) {
    // Triggered in SupabaseService.assignDelivery()
    // After firebase setup: push local notification to delivery boy's device
    debugPrint('[NotificationService] ORDER PLACED — notifying $deliveryBoyName');
  }

  static void notifyOrderAccepted(String userName) {
    debugPrint('[NotificationService] ORDER ACCEPTED — notifying user $userName');
  }

  static void notifyOrderDelivered(String userName) {
    debugPrint('[NotificationService] ORDER DELIVERED — notifying user $userName');
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
