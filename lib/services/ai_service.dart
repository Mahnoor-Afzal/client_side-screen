import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_analysis.dart';
import '../utils/client_app_config.dart';

class AiService {
  final String _apiKey = AppConfig.openRouterApiKey;

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

  Future<AiAnalysis> analyzeLegalQuery(String text) async {
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
          "max_tokens": 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['choices'] == null || data['choices'].isEmpty) {
          throw Exception("AI ne koi jawab nahi diya.");
        }

        String aiResponse = data['choices'][0]['message']['content'];
        
        Map<String, dynamic>? decodedData;
        try {
          RegExp jsonRegExp = RegExp(r'\{[\s\S]*\}');
          Match? match = jsonRegExp.firstMatch(aiResponse);
          
          if (match != null) {
            String cleanedJson = match.group(0)!;
            decodedData = jsonDecode(cleanedJson);
          } else {
            decodedData = jsonDecode(aiResponse.trim());
          }
        } catch (e) {
           throw Exception("Failed to parse AI response");
        }

        if (decodedData != null) {
          return AiAnalysis.fromJson(decodedData);
        } else {
          throw Exception("AI response was empty");
        }
      } else {
        Map<String, dynamic> errorBody = {};
        try { errorBody = jsonDecode(response.body); } catch (_) {}
        String msg = errorBody['error']?['message'] ?? "Error: ${response.statusCode}";
        throw Exception(msg);
      }
    } catch (e) {
      rethrow;
    }
  }
}
