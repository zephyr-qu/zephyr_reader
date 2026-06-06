/// 颜色计算工具函数。
///
/// 提供 [contrastingTextColor] 等与主题无关的纯色值计算。
library;

import 'package:flutter/material.dart';

/// 根据背景色亮度返回白色或深色前景文字颜色。
///
/// 使用 WCAG 相对亮度公式计算，适用于按钮/标签等需保证可读性的场景。
Color contrastingTextColor(Color bg) {
  final luminance = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b;
  return luminance > 0.5 ? const Color(0xFF1A1C1E) : Colors.white;
}
