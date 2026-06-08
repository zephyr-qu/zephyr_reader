/// 时间格式化工具。
///
/// 提供相对时间（如"3分钟前"）、绝对时间、时长的可读格式化输出。
/// 所有用户面向的格式化函数均依赖 [AppLocalizations] 实现 i18n。
library;

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
  } else if (difference.inDays < 30) {
    return l10n.timeDaysAgo(difference.inDays);
  } else {
    return l10n.timeMonthsAgo((difference.inDays / 30).floor());
  }
}

/// 格式化为 `YYYY-MM-DD` 字符串。
///
/// 不依赖 l10n，适用于文件命名、数据库键等固定格式场景。
String formatDateYYYYMMDD(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 将秒数格式化为人类可读的时长字符串
///
///   - < 60秒  → "N{secondsUnit}"
///   - < 3600秒 → "N{minutes}"
///   - ≥ 3600秒 → "X{hoursUnit}Y{minutes}"
String formatDuration(int seconds, AppLocalizations l10n) {
  if (seconds < 60) return '$seconds${l10n.secondsUnit}';
  if (seconds < 3600) return '${seconds ~/ 60}${l10n.minutes}';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '$h${l10n.hoursUnit}$m${l10n.minutes}';
}
