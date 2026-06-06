/// 触觉反馈类型枚举。
///
/// 包装 [HapticFeedback] 的轻/中/重/选择 四类系统振动。
///
/// 使用示例：`hapticFeedback(HapticType.light);`
///
/// 与 Raw [HapticFeedback] 的区别：集中在一处管理，未来可加条件开关（如静音模式跳过振动）。
library;

import 'package:flutter/services.dart';

enum HapticType { light, medium, heavy, selection }

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
