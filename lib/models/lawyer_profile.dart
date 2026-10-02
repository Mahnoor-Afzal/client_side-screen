import 'package:cloud_firestore/cloud_firestore.dart';

class LawyerProfile {
  final String id;
  final String fullName;
  final String? profileImageUrl;
  final String category;
  final String barCouncil;
  final String location;
  final String court;
  final String experience;
  final String bio;
  final bool isApproved;

  LawyerProfile({
    required this.id,
    required this.fullName,
    this.profileImageUrl,
    required this.category,
    required this.barCouncil,
    required this.location,
    required this.court,
    required this.experience,
    required this.bio,
    required this.isApproved,
  });

  factory LawyerProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Logic from coordination_screen.dart for isApproved
    bool approved = (data['isApproved'] == true) ||
        (data['isVerified'] == true) ||
        (data['verified'] == true) ||
        (!data.containsKey('isApproved') && !data.containsKey('isVerified'));

    return LawyerProfile(
      id: doc.id,
      fullName: data['fullName'] ?? data['name'] ?? "Lawyer",
      profileImageUrl: data['profileImageUrl'] ?? data['profilePic'] ?? data['cnicFrontUrl'],
      category: data['category'] ?? data['specialization'] ?? data['area'] ?? "Legal Expert",
      barCouncil: data['barCouncil'] ?? "Bar Council Name",
      location: data['location'] ?? data['city'] ?? data['area'] ?? "Location",
      court: data['court'] ?? "Supreme Court",
      experience: data['experience']?.toString() ?? "N/A",
      bio: data['description'] ?? data['bio'] ?? data['about'] ?? "I am a professional lawyer.",
      isApproved: approved,
    );
  }
}
