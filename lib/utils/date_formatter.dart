import 'package:cloud_firestore/cloud_firestore.dart';

class DateFormatter {
  static String safeFormatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    if (dateVal is Timestamp) {
      DateTime dt = dateVal.toDate();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }
    return dateVal.toString();
  }
}
