import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'client_lawyer_list_screen.dart';

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
Your job is ONLY to identify legal case details.
If the user's question is NOT related to legal issues, law, or cases, you MUST set "is_legal" to false and provide a sorry message in "message".
Otherwise, set "is_legal" to true and fill other fields.
IMPORTANT: Reply ONLY with a valid JSON object. No conversational text.

JSON Response Format (for legal issues):
{
  "is_legal": true,
  "case_type": "...",
  "category": "...",
  "best_lawyer": "...",
  "reason": "...",
  "priority_level": "...",
  "next_step": "..."
}

JSON Response Format (for out-of-scope):
{
  "is_legal": false,
  "message": "I'm sorry, but I can only assist with legal-related questions and case analysis."
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
          "max_tokens": 1000, // Credits bachane aur error fix karne ke liye
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['choices'] == null || data['choices'].isEmpty) {
          throw Exception("AI ne koi jawab nahi diya.");
        }

        String aiResponse = data['choices'][0]['message']['content'];
        
        // Robust JSON extraction and parsing
        Map<String, dynamic>? decodedData;
        try {
          RegExp jsonRegExp = RegExp(r'\{[\s\S]*\}');
          Match? match = jsonRegExp.firstMatch(aiResponse);
          
          if (match != null) {
            String cleanedJson = match.group(0)!;
            decodedData = jsonDecode(cleanedJson);
          } else {
            // Fallback: try parsing the whole thing if RegExp fails
            decodedData = jsonDecode(aiResponse.trim());
          }
        } catch (e) {
          debugPrint("JSON Parsing Error: $e | RAW: $aiResponse");
        }

        if (decodedData != null) {
          if (decodedData['is_legal'] == false) {
            setState(() {
              _messages.add({
                "role": "ai_text",
                "content": decodedData!['message'] ?? "I'm sorry, I can only assist with legal-related queries."
              });
            });
          } else {
            // Ensure all required fields exist for the AI card to avoid crashes
            final requiredFields = ['case_type', 'category', 'best_lawyer', 'reason', 'priority_level', 'next_step'];
            for (var field in requiredFields) {
              decodedData![field] ??= "Not specified";
            }
            setState(() {
              _messages.add({"role": "ai", "content": decodedData});
            });
          }
        } else {
          // If JSON parsing failed completely, show the raw response as text if it's not too long, 
          // or a fallback message if it's clearly malformed.
          setState(() {
            _messages.add({
              "role": "ai_text",
              "content": aiResponse.length < 300 && !aiResponse.contains('{') 
                  ? aiResponse 
                  : "I've analyzed your query but had trouble formatting the result. Please try asking in a different way or contact a lawyer directly."
            });
          });
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

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete message?"),
        content: const Text("Are you sure you want to delete this message?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                return GestureDetector(
                  onLongPress: () => _showDeleteDialog(index),
                  child: _buildAiResponseCard(msg['content'], gold, navyBlue),
                );
              }

              bool isAiText = msg['role'] == 'ai_text';

              return GestureDetector(
                onLongPress: () => _showDeleteDialog(index),
                child: Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? navyBlue
                          : (isAiText ? Colors.grey.shade200 : Colors.redAccent.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      msg['content'].toString(),
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                      softWrap: true,
                    ),
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
                  minLines: 1,
                  maxLines: 5, // Input box ko multi-line banane ke liye
                  decoration: InputDecoration(
                    hintText: "Describe your legal issue...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: navyBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data['case_type'] ?? "Legal Analysis", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: navyBlue)),
                ),
                _priorityBadge(data['priority_level'] ?? "Low"),
              ],
            ),
            const Divider(height: 24),
            _infoRow("Category:", data['category']),
            _infoRow("Best Lawyer:", data['best_lawyer']),
            _infoRow("Reason:", data['reason']),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20, color: Colors.brown),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Next Step: ${data['next_step']}", 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4)
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LawyerListScreen(
                        specializationFilter: data['category'],
                        aiAnalysis: data,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_search, size: 18),
                label: const Text("CONSULT RECOMMENDED LAWYERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  foregroundColor: gold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
