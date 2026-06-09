# P3.1: `reader_content.dart` 使用已弃用的 `MediaQuery.of`

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P3（已弃用 API）
- **文件**: `lib/core/reader/reader_content.dart:116`

## 问题

```dart
final disableAnim = MediaQuery.of(context).disableAnimations;
```

Flutter 3.10+ 已弃用 `MediaQuery.of`，推荐使用基于函数的变体。

## 建议

改为：
```dart
final disableAnim = MediaQuery.disableAnimationsOf(context);
```
