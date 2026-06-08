/// 数值格式化工具。
///
/// 提供文件大小、字符数等常见数据的可读格式化输出。
/// 用户面向的格式化函数依赖 [AppLocalizations] 实现 i18n。
library;

import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 格式化字节数为可读字符串
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// 将字符数格式化为人类可读的字符串
///
///   - < 1000 → "N{charsUnit}"
///   - ≥ 1000 → "N.N{thousandCharsUnit}{charsUnit}"
String formatChars(int chars, AppLocalizations l10n) {
  if (chars < 1000) return '$chars${l10n.charsUnit}';
  return '${(chars / 1000).toStringAsFixed(1)}${l10n.thousandCharsUnit}${l10n.charsUnit}';
}
