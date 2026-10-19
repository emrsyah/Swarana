import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class SharedCode {
  static String formatWaktu(DateTime dateTime) {
    initializeDateFormatting('id_ID', null);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToFormat = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('h.mm a', 'id_ID');
    final formattedTime = timeFormat.format(dateTime);

    if (dateToFormat == today) {
      return 'Hari ini, $formattedTime';
    } else if (dateToFormat == yesterday) {
      return 'Kemarin, $formattedTime';
    } else {
      final otherDayFormat = DateFormat('d MMM', 'id_ID');
      return '${otherDayFormat.format(dateTime)}, $formattedTime';
    }
  }
}
