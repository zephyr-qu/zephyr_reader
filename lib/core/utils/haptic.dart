/// 触觉反馈工具。
///
/// 封装系统 [HapticFeedback]，集中管理振动反馈。
/// 使用 [hapticFeedback] 函数而非直接调用 [HapticFeedback] 方法。
library;

import 'package:flutter/services.dart';

/// 触觉反馈类型枚举。
///
/// 可选值：[light]（轻触）、[medium]（中）、[heavy]（重）、[selection]（选择点击）。
enum HapticType { light, medium, heavy, selection }

/// 触发指定类型的触觉反馈。
///
/// [type] 指定振动强度类型。
/// 示例：`hapticFeedback(HapticType.light);`
void hapticFeedback(HapticType type) {
  switch (type) {
    case HapticType.light:
      HapticFeedback.lightImpact();
    case HapticType.medium:
      HapticFeedback.mediumImpact();
    case HapticType.heavy:
      HapticFeedback.heavyImpact();
    case HapticType.selection:
      HapticFeedback.selectionClick();
  }
}
