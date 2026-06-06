/// 日期时间格式化工具函数。
///
/// 提供相对时间（"几分钟前"）、固定格式（YYYY-MM-DD）等格式化能力。
/// 相对时间依赖 [AppLocalizations] 实现 i18n。
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
