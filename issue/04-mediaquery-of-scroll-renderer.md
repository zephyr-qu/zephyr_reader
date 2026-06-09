# P3.2: `scroll_mode_renderer.dart` 使用已弃用的 `MediaQuery.of`

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P3（已弃用 API）
- **文件**: `lib/features/reader/presentation/widgets/scroll_mode_renderer.dart:360`

## 问题

```dart
(maxWidth * MediaQuery.of(context).devicePixelRatio).ceil()
```

Flutter 3.10+ 已弃用 `MediaQuery.of`，推荐使用基于函数的变体。

## 建议

改为：
```dart
(maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil()
```
