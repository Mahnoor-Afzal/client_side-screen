import 'package:flutter/material.dart';
import 'firestore_service.dart';

class VerifiedLawyers extends StatelessWidget {
  const VerifiedLawyers({super.key});

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
        title: Text("Verified Lawyers", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: goldAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreService.getVerifiedLawyers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }
          final lawyers = snapshot.data ?? [];

          if (lawyers.isEmpty) {
            return const Center(child: Text("No verified lawyers found", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: lawyers.length,
            itemBuilder: (context, index) {
              final lawyer = lawyers[index];
              
              // Flexible key checking for Name (Checking all common possibilities)
              String name = (lawyer['name'] ?? 
                             lawyer['Name'] ?? 
                             lawyer['fullName'] ?? 
                             lawyer['FullName'] ?? 
                             lawyer['userName'] ?? 
                             'Verified Lawyer').toString();

              // Flexible key checking for Experience
              String experience = (lawyer['experience'] ?? 
                                   lawyer['Experience'] ?? 
                                   lawyer['exp'] ?? 
                                   lawyer['Exp'] ?? 
                                   lawyer['years'] ?? 
                                   '0').toString();

              // Email and Specialization
              String email = (lawyer['email'] ?? lawyer['Email'] ?? 'N/A').toString();
              String specialization = (lawyer['specialization'] ?? 
                                       lawyer['speciality'] ?? 
                                       lawyer['category'] ?? 
                                       'Legal Consultant').toString();

              return Card(
                color: cardNavy,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: goldAccent.withAlpha(50),
                    child: Icon(Icons.verified, color: Colors.blue),
                  ),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("Email: $email\nExperience: $experience Years\nSpec: $specialization",
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      firestoreService.deleteUser(lawyer['id'], 'Lawyer', true);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
