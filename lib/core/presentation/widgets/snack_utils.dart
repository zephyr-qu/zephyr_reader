import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 显示成功 SnackBar
///
/// 使用 [DesignTokens.success] 作为背景色。
void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: DesignTokens.success,
    ),
  );
}

/// 显示错误 SnackBar
///
/// 使用主题 [ColorScheme.error] 作为背景色。

void showErrorSnack(BuildContext context, String message) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: cs.error,
    ),
  );
}

/// 显示信息提示 SnackBar
///
/// 使用默认主题背景色。

void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
