import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDateTime(String dateTime) {
    try {
      // Parse the UTC datetime string
      DateTime utcDt = DateTime.parse(dateTime);

      // Convert to local time (which should be Malaysia time)
      DateTime localDt = utcDt.toLocal();

      // Create formatter with AM/PM format
      final DateFormat formatter = DateFormat('dd/MM/yyyy hh:mm a', 'en_US');

      return formatter.format(localDt);
    } catch (e) {
      print('Error formatting date: $e');
      print('Problematic datetime string: $dateTime');
      return dateTime;
    }
  }

  // Add a method for formatting date only
  static String formatDate(String dateTime) {
    try {
      DateTime utcDt = DateTime.parse(dateTime);
      DateTime localDt = utcDt.toLocal();
      final DateFormat formatter = DateFormat('dd/MM/yyyy', 'en_US');
      return formatter.format(localDt);
    } catch (e) {
      print('Error formatting date: $e');
      print('Problematic datetime string: $dateTime');
      return dateTime;
    }
  }

  // Add a method for formatting time only
  static String formatTime(String dateTime) {
    try {
      DateTime utcDt = DateTime.parse(dateTime);
      DateTime localDt = utcDt.toLocal();
      final DateFormat formatter = DateFormat('hh:mm a', 'en_US');
      return formatter.format(localDt);
    } catch (e) {
      print('Error formatting time: $e');
      print('Problematic datetime string: $dateTime');
      return dateTime;
    }
  }

  // Get current date time
  static String getCurrentDateTime() {
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('dd/MM/yyyy hh:mm a', 'en_US');
    return formatter.format(now);
  }

  // Debug method to check incoming time
  static void debugDateTime(String dateTime) {
    try {
      DateTime utcDt = DateTime.parse(dateTime);
      DateTime localDt = utcDt.toLocal();

      print('Original string: $dateTime');
      print('Parsed UTC DateTime: $utcDt');
      print('Local DateTime: $localDt');
      print('Formatted: ${formatDateTime(dateTime)}');
    } catch (e) {
      print('Debug Error: $e');
      print('Problematic datetime string: $dateTime');
    }
  }
}
