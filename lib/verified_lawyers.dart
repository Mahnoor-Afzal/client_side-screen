import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verify_lawyers.dart'; // To reuse the LawyerProfileView

class VerifiedLawyers extends StatelessWidget {
  const VerifiedLawyers({super.key});

  @override
  Widget build(BuildContext context) {
    const Color navyBackground = Color(0xFF0F172A);
    const Color goldAccent = Color(0xFFC7A15E);
    const Color cardNavy = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: navyBackground,
      appBar: AppBar(
        backgroundColor: cardNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: goldAccent),
        title: const Text("Verified Lawyers", 
          style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
      ),
      body: _buildLawyerList(context),
    );
  }

  Widget _buildLawyerList(BuildContext context) {
    const String collection = 'verified_lawyers';
    const Color goldAccent = Color(0xFFC7A15E);
    const Color cardNavy = Color(0xFF1E293B);
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true) 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: goldAccent));
        }
        
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('index')) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(20.0),
               child: Text("Sorting error: Please create a Firestore index for 'createdAt' in $collection collection.\n\n${snapshot.error}", 
               style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
             ));
          }
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No verified lawyers found", 
            style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; 

            return Card(
              color: cardNavy,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: goldAccent.withOpacity(0.1), 
                  child: const Icon(Icons.verified, color: Colors.blue)
                ),
                title: Text((data['name'] ?? data['fullName'] ?? 'Unknown').toString(), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text((data['specialization'] ?? 'Legal Consultant').toString(), 
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: goldAccent, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LawyerProfileView(lawyer: data, isVerified: true)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
