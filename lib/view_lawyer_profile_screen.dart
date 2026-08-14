import 'package:flutter/material.dart';

class ViewLawyerProfileScreen extends StatelessWidget {
  final Map<String, dynamic> lawyerData;

  const ViewLawyerProfileScreen({super.key, required this.lawyerData});

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    // Helper method to extract values or return fallback strings
    String val(dynamic v, String fallback) {
      if (v == null) return fallback;
      if (v is List) return v.isEmpty ? fallback : v.join(", ");
      String strVal = v.toString().trim();
      return strVal.isEmpty ? fallback : strVal;
    }

    String name = val(lawyerData['fullName'] ?? lawyerData['name'], "Lawyer");
    String? profileImg = lawyerData['profileImageUrl'];
    String category = val(lawyerData['category'] ?? lawyerData['specialization'], "Legal Expert");
    String barCouncil = val(lawyerData['barCouncil'], "Bar Council Member");
    String location = val(lawyerData['location'] ?? lawyerData['area'] ?? lawyerData['province'], "N/A");
    String court = val(lawyerData['court'], "Supreme Court / High Court");
    String experience = val(lawyerData['experience'], "N/A");
    String bio = val(lawyerData['bio'] ?? lawyerData['about'], "No detailed bio available.");
    String email = val(lawyerData['email'], "N/A");
    String phone = val(lawyerData['phone'] ?? lawyerData['contact'], "N/A");

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Lawyer Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (profileImg != null && profileImg.isNotEmpty)
                          ? NetworkImage(profileImg)
                          : null,
                      child: (profileImg == null || profileImg.isEmpty)
                          ? const Icon(Icons.person, size: 50, color: navyBlue)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blue, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      barCouncil,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "About & Bio",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyBlue),
                    ),
                    const Divider(),
                    Text(
                      bio,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Professional Details",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyBlue),
                    ),
                    const Divider(),
                    _buildDetailRow(Icons.gavel_rounded, "Court Practice", court),
                    _buildDetailRow(Icons.access_time, "Experience", "$experience Years"),
                    _buildDetailRow(Icons.location_on_outlined, "Location / Area", location),
                    _buildDetailRow(Icons.email_outlined, "Email", email),
                    _buildDetailRow(Icons.phone_outlined, "Contact Phone", phone),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper to build detailed information rows
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC5A358)),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}