class DateFormatter {
  // Format month to short form (e.g., "Jan", "Feb", etc.)
  static String formatMonthShort(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }
  
  // Format full date (e.g., "Jan 21, 2023")
  static String formatFullDate(DateTime date) {
    return '${formatMonthShort(date)} ${date.day}, ${date.year}';
  }
}
