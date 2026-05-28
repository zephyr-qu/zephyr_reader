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
