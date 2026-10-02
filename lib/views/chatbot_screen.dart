import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/chatbot_view_model.dart';
import '../models/ai_analysis.dart';
import 'client_lawyer_list_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return ChangeNotifierProvider(
      create: (_) => ChatbotViewModel(),
      child: Consumer<ChatbotViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: viewModel.messages.length,
                  itemBuilder: (context, index) {
                    final msg = viewModel.messages[index];
                    bool isUser = msg['role'] == 'user';

                    if (msg['role'] == 'ai') {
                      return GestureDetector(
                        onLongPress: () => _showDeleteDialog(context, viewModel, index),
                        child: _buildAiResponseCard(context, msg['content'] as AiAnalysis, gold, navyBlue),
                      );
                    }

                    bool isAiText = msg['role'] == 'ai_text';

                    return GestureDetector(
                      onLongPress: () => _showDeleteDialog(context, viewModel, index),
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
              if (viewModel.isLoading) const LinearProgressIndicator(color: gold),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
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
                        onPressed: () {
                          viewModel.sendMessage(_controller.text);
                          _controller.clear();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatbotViewModel viewModel, int index) {
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
              viewModel.deleteMessage(index);
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResponseCard(BuildContext context, AiAnalysis data, Color gold, Color navyBlue) {
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
                  child: Text(data.caseType ?? "Legal Analysis", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: navyBlue)),
                ),
                _priorityBadge(data.priorityLevel ?? "Low"),
              ],
            ),
            const Divider(height: 24),
            _infoRow("Category:", data.category),
            _infoRow("Best Lawyer:", data.bestLawyer),
            _infoRow("Reason:", data.reason),
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
                      "Next Step: ${data.nextStep}", 
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
                        specializationFilter: data.category,
                        aiAnalysis: data.toJson(),
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
