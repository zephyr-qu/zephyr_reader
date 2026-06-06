/// 格式化工具函数。
///
/// 提供字节数、时长、字符数等数据的可读字符串格式化，
/// 以及列表错峰入场动画延迟计算。
/// 所有格式化函数均接收 [AppLocalizations] 实现 i18n。
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

/// 将字符数格式化为人类可读的字符串
///
///   - < 1000 → "N{charsUnit}"
///   - ≥ 1000 → "N.N{thousandCharsUnit}{charsUnit}"
String formatChars(int chars, AppLocalizations l10n) {
  if (chars < 1000) return '$chars${l10n.charsUnit}';
  return '${(chars / 1000).toStringAsFixed(1)}${l10n.thousandCharsUnit}${l10n.charsUnit}';
}

/// 计算列表项的错峰入场动画延迟
///
/// 生成 `50ms × index` 的阶梯延迟，上限 500ms（index 10+ 后不再增长）
Duration staggerDelay(int index) =>
    Duration(milliseconds: 50 * index.clamp(0, 10));
