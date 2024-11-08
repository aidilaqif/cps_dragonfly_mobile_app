import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDateTime(String dateTime) {
    try {
      // Parse the input datetime string
      DateTime dt = DateTime.parse(dateTime);

      // Convert to Malaysia timezone (UTC+8)
      dt = dt.toLocal();

      // Create formatter with Malaysia locale
      final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm', 'en_MY');

      return formatter.format(dt);
    } catch (e) {
      return dateTime; // Return original string if parsing fails
    }
  }
}
