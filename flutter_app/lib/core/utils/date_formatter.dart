import 'package:intl/intl.dart';

/// Date formatting utilities for the ERP.
class DateFormatter {
  DateFormatter._();

  static final _displayFormat = DateFormat('dd MMM yyyy');
  static final _shortFormat = DateFormat('dd/MM/yyyy');
  static final _apiFormat = DateFormat('yyyy-MM-dd');
  static final _monthYear = DateFormat('MMM yyyy');
  static final _fullMonth = DateFormat('MMMM yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// Display format: "11 Apr 2026"
  static String display(DateTime date) => _displayFormat.format(date);

  /// Short format: "11/04/2026"
  static String short(DateTime date) => _shortFormat.format(date);

  /// API format: "2026-04-11"
  static String api(DateTime date) => _apiFormat.format(date);

  /// Month-year: "Apr 2026"
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// Full month: "April 2026"
  static String fullMonth(DateTime date) => _fullMonth.format(date);

  /// Time only: "02:30 PM"
  static String time(DateTime date) => _timeFormat.format(date);

  /// Full datetime: "11 Apr 2026, 02:30 PM"
  static String dateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Parse from API format.
  static DateTime parse(String dateStr) => DateTime.parse(dateStr);

  /// Relative time: "2 days ago", "just now", etc.
  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  /// "Due in 5 days" or "Overdue by 3 days"
  static String dueStatus(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now);

    if (diff.isNegative) {
      return 'Overdue by ${-diff.inDays} days';
    } else if (diff.inDays == 0) {
      return 'Due today';
    } else {
      return 'Due in ${diff.inDays} days';
    }
  }
}
