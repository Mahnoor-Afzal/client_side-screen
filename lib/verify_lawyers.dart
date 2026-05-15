import 'package:flutter/material.dart';
import 'firestore_service.dart';

class VerifyLawyers extends StatelessWidget {
  VerifyLawyers({super.key});

  final FirestoreService _firestoreService = FirestoreService();

  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navyBackground,
      appBar: AppBar(
        backgroundColor: cardNavy,
        title: Text("Verify Lawyers", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: goldAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getPendingLawyers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }
          final lawyers = snapshot.data ?? [];

          if (lawyers.isEmpty) {
            return const Center(child: Text("No pending lawyer requests", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: lawyers.length,
            itemBuilder: (context, index) {
              final lawyer = lawyers[index];

              // Fix: Using .toString() to avoid type mismatch errors (int to string)
              String name = (lawyer['name'] ?? lawyer['fullName'] ?? 'No Name').toString();
              String experience = (lawyer['experience'] ?? lawyer['exp'] ?? lawyer['years'] ?? 'N/A').toString();
              String specialization = (lawyer['specialization'] ?? lawyer['speciality'] ?? 'N/A').toString();
              String email = (lawyer['email'] ?? 'N/A').toString();

              return Card(
                color: cardNavy,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(backgroundColor: goldAccent, child: const Icon(Icons.gavel, color: Colors.white)),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("Email: $email\nExperience: $experience Years\nSpecialization: $specialization", style: const TextStyle(color: Colors.white54)),
                      ),
                      const Divider(color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            icon: const Icon(Icons.check, color: Colors.white),
                            onPressed: () {
                              _firestoreService.approveLawyer(lawyer['id'], lawyer);
                              _showMsg(context, "Lawyer Verified Successfully!");
                            },
                            label: const Text("Accept", style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              _firestoreService.rejectLawyer(lawyer['id']);
                              _showMsg(context, "Lawyer Request Rejected.");
                            },
                            label: const Text("Reject", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
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

  void _showMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
