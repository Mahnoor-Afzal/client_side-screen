import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request Permissions (iOS/Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Local Notifications for Foreground
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(initSettings);

    // 3. Create Notification Channel (Android)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'case_updates', 
      'Case Updates',
      description: 'Notifications for hearing date updates',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message, channel);
    });

    // 5. Handle Background Clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked! Case ID: ${message.data['caseId']}");
    });

    // 6. Initial Token Save
    saveTokenToFirestore();
  }

  static Future<void> saveTokenToFirestore() async {
    String? token = await _fcm.getToken();
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (token != null && uid != null) {
      // Update in 'users' collection
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      
      if (userDoc.exists) {
        await userRef.update({'fcmToken': token});
      } else {
        // Also check 'verified_lawyers'
        final lawyerRef = FirebaseFirestore.instance.collection('verified_lawyers').doc(uid);
        final lawyerDoc = await lawyerRef.get();
        if (lawyerDoc.exists) {
          await lawyerRef.update({'fcmToken': token});
        }
      }
    }
  }

  static void _showLocalNotification(RemoteMessage message, AndroidNotificationChannel channel) {
    RemoteNotification? notification = message.notification;
    
    // Extracting Title and Body from either notification object or data payload
    String title = notification?.title ?? message.data['title'] ?? 'Hearing Alert';
    String? body = notification?.body ?? message.data['message'] ?? message.data['body'];

    if (body != null) {
      _localNotifications.show(
        notification.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: message.notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }
}
