import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ai_analysis.dart';
import '../services/ai_service.dart';

class ChatbotViewModel extends ChangeNotifier {
  final AiService _aiService = AiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatbotViewModel() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('chatbot_history')
          .doc(user.uid)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      _messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['role'] == 'ai') {
          _messages.add({
            "id": doc.id,
            "role": data['role'],
            "content": AiAnalysis.fromJson(data['content']),
            "timestamp": data['timestamp'],
          });
        } else {
          _messages.add({
            "id": doc.id,
            "role": data['role'],
            "content": data['content'],
            "timestamp": data['timestamp'],
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final userMsg = {
      "role": "user",
      "content": text,
      "timestamp": FieldValue.serverTimestamp()
    };
    
    // Add to UI immediately
    _messages.add({"role": "user", "content": text});
    _isLoading = true;
    notifyListeners();

    try {
      // Save user message to Firestore
      await _firestore
          .collection('chatbot_history')
          .doc(user.uid)
          .collection('messages')
          .add(userMsg);

      final analysis = await _aiService.analyzeLegalQuery(text);

      Map<String, dynamic> aiMsg;
      if (analysis.isLegal == false) {
        aiMsg = {
          "role": "ai_text",
          "content": analysis.message ?? "I'm sorry, I can only assist with legal-related queries.",
          "timestamp": FieldValue.serverTimestamp()
        };
        _messages.add({
          "role": "ai_text",
          "content": aiMsg['content']
        });
      } else {
        aiMsg = {
          "role": "ai",
          "content": analysis.toJson(),
          "timestamp": FieldValue.serverTimestamp()
        };
        _messages.add({"role": "ai", "content": analysis});
      }

      // Save AI response to Firestore
      await _firestore
          .collection('chatbot_history')
          .doc(user.uid)
          .collection('messages')
          .add(aiMsg);

    } catch (e) {
      String errorMsg = e.toString().replaceAll("Exception:", "");
      if (errorMsg.contains("XMLHttpRequest")) {
        errorMsg = "Browser (CORS) Blocked! \nWeb par security ki wajah se API block hai. \n\nHal: Android Emulator par chalayein.";
      }
      _messages.add({"role": "error", "content": errorMsg});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMessage(int index) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // If we have an ID (loaded from Firestore), delete it there too
      final msg = _messages[index];
      if (msg.containsKey('id')) {
        await _firestore
            .collection('chatbot_history')
            .doc(user.uid)
            .collection('messages')
            .doc(msg['id'])
            .delete();
      }
      
      _messages.removeAt(index);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting message: $e");
    }
  }
}
