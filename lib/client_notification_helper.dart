import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'client_app_config.dart';

class NotificationHelper {
  static Future<void> sendGlobalPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=${AppConfig.fcmServerKey}',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{
            'body': body,
            'title': title,
            'android_channel_id': 'high_importance_channel',
            'sound': 'default',
          },
          'priority': 'high',
          'data': data ?? <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'status': 'done',
          },
          'to': token,
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint("Notification sent successfully!");
      } else {
        debugPrint("Failed to send notification. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  static Future<void> sendPushNotification(String userId, String title, String body, [Map<String, dynamic>? data]) async {
    try {
      // Try fetching token from users collection
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      String? token = userDoc.data()?['fcmToken'];

      // If not found, try verified_lawyers
      if (token == null || token.isEmpty) {
        var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(userId).get();
        token = lawyerDoc.data()?['fcmToken'];
      }

      // If still not found, try lawyers
      if (token == null || token.isEmpty) {
        var lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(userId).get();
        token = lawyerDoc.data()?['fcmToken'];
      }

      if (token != null && token.isNotEmpty) {
        await sendGlobalPushNotification(
          token: token,
          title: title,
          body: body,
          data: data,
        );
      } else {
        debugPrint("No FCM token found for user $userId");
      }
    } catch (e) {
      debugPrint("Error in sendPushNotification: $e");
    }
  }
}
