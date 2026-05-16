import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lawyer_list_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  // IMPORTANT: Replace with your actual OpenRouter API Key
  final String _apiKey = "YOUR_OPENROUTER_API_KEY";

  final String systemPrompt = """
You are an AI Legal Assistant in the Smart Legal Assistant App.
Your job is ONLY to identify case details.
IMPORTANT: Reply ONLY with a valid JSON object. No conversational text.
JSON Response Format:
{
  "case_type": "",
  "category": "",
  "best_lawyer": "",
  "reason": "",
  "priority_level": "",
  "next_step": ""
}
""";

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse("https://openrouter.ai/api/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
          "X-Title": "Smart Legal Assistant",
        },
        body: jsonEncode({
           "model": "openrouter/auto",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": text}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['choices'] == null || data['choices'].isEmpty) {
          throw Exception("AI ne koi jawab nahi diya.");
        }

        String aiResponse = data['choices'][0]['message']['content'];
        
        // JSON extract karne ka robust tarika
        RegExp jsonRegExp = RegExp(r'\{[\s\S]*\}');
        Match? match = jsonRegExp.firstMatch(aiResponse);
        
        if (match != null) {
          String cleanedJson = match.group(0)!;
          setState(() {
            _messages.add({"role": "ai", "content": jsonDecode(cleanedJson)});
          });
        } else {
          debugPrint("AI RAW: $aiResponse");
          throw Exception("AI response format error. Try again.");
        }
      } else {
        Map<String, dynamic> errorBody = {};
        try { errorBody = jsonDecode(response.body); } catch (_) {}
        String msg = errorBody['error']?['message'] ?? "Error: ${response.statusCode}";
        throw Exception(msg);
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll("Exception:", "");
      if (errorMsg.contains("XMLHttpRequest")) {
        errorMsg = "Browser (CORS) Blocked! \nWeb par security ki wajah se API block hai. \n\nHal: Android Emulator par chalayein.";
      }
      setState(() {
        _messages.add({"role": "error", "content": errorMsg});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              bool isUser = msg['role'] == 'user';

              if (msg['role'] == 'ai') {
                return _buildAiResponseCard(msg['content'], gold, navyBlue);
              }

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? navyBlue : Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    msg['content'].toString(),
                    style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(color: gold),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Describe your legal issue...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: navyBlue,
                child: IconButton(
                  icon: const Icon(Icons.send, color: gold),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiResponseCard(Map<String, dynamic> data, Color gold, Color navyBlue) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: gold, width: 1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, color: navyBlue),
                const SizedBox(width: 10),
                Text(data['case_type'] ?? "Legal Analysis", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue)),
                const Spacer(),
                _priorityBadge(data['priority_level'] ?? "Low"),
              ],
            ),
            const Divider(),
            _infoRow("Category:", data['category']),
            _infoRow("Best Lawyer:", data['best_lawyer']),
            _infoRow("Reason:", data['reason']),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.next_plan, size: 20, color: Colors.brown),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Next Step: ${data['next_step']}", style: const TextStyle(fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LawyerListScreen(
                        specializationFilter: data['category'],
                        aiAnalysis: data, // AI ki summary bhej rahe hain
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_search, size: 18),
                label: const Text("CONSULT RECOMMENDED LAWYERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  foregroundColor: gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: "$label ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? "N/A"),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String level) {
    Color color = Colors.green;
    if (level.toLowerCase() == 'high') color = Colors.red;
    if (level.toLowerCase() == 'medium') color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(level, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
