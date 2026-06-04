/// 将秒数格式化为人类可读的时长字符串
///
///   - < 60秒  → "N秒"
///   - < 3600秒 → "N分钟"
///   - ≥ 3600秒 → "X小时Y分钟"
String formatDuration(int seconds) {
  if (seconds < 60) return '$seconds秒';
  if (seconds < 3600) return '${seconds ~/ 60}分钟';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '$h小时$m分钟';
}

/// 将字符数格式化为人类可读的字符串
///
///   - < 1000 → "N字"
///   - ≥ 1000 → "N.N千字"
String formatChars(int chars) {
  if (chars < 1000) return '$chars字';
  return '${(chars / 1000).toStringAsFixed(1)}千字';
}
