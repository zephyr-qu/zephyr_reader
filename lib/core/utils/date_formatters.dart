import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 格式化相对时间，使用 l10n
String formatRelativeTime(DateTime dateTime, AppLocalizations l10n) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return l10n.timeJustNow;
  } else if (difference.inHours < 1) {
    return l10n.timeMinutesAgo(difference.inMinutes);
  } else if (difference.inDays < 1) {
    return l10n.timeHoursAgo(difference.inHours);
  } else {
    return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

String formatDateYYYYMMDD(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
