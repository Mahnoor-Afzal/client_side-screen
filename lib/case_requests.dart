import 'package:flutter/material.dart';
import 'firestore_service.dart';

class CaseRequests extends StatelessWidget {
  const CaseRequests({super.key});

  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: navyBackground,
      appBar: AppBar(
        backgroundColor: cardNavy,
        title: Text("Case Requests", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: goldAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreService.getCaseRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }
          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return const Center(child: Text("No case requests found", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                color: cardNavy,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(req['caseType'] ?? 'Unknown Case', 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Icon(Icons.description, color: goldAccent, size: 20),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      _infoRow(Icons.person, "Client: ", req['clientName'] ?? 'N/A'),
                      _infoRow(Icons.gavel, "Lawyer ID: ", req['lawyerid'] ?? 'N/A'),
                      const SizedBox(height: 10),
                      const Text("Description:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      Text(req['description'] ?? 'No description.', style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: goldAccent),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
