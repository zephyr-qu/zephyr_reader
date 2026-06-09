# P1: `DeviceType` 命名暗示硬件嗅探 — 应改用 ScreenSizeClass 语义

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P1（可能误导）
- **文件**: `lib/core/presentation/widgets/adaptive_layout.dart`

## 问题

```dart
enum DeviceType { phone, tablet, desktop }
class LayoutBreakpoints {
  static bool isPhone(BuildContext context) { ... }
  static bool isTablet(BuildContext context) { ... }
  static bool isDesktop(BuildContext context) { ... }
  static DeviceType getDeviceType(BuildContext context) { ... }
}
```

命名暗示检查硬件类型，违反 skill 规则："Do not check for hardware types (e.g., 'phone' vs. 'tablet')"。实际上实现完全基于 `MediaQuery.sizeOf(context).width` 的宽度检查，功能正确，但名称具有误导性——维护者可能认为 `DeviceType.phone` 意味着"这是一台手机"，而不是"窗口宽度 < 600px"。

## 建议

重命名为 `ScreenSizeClass` / `isCompact` / `isMedium` / `isExpanded`，与 Material 3 命名对齐。波及范围广（多个页面导入），可一次性重构。
