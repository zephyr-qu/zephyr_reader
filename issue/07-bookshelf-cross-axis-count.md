# P4.3: 书架页面重新实现了列数逻辑

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P4（一致性）
- **文件**: `lib/features/bookshelf/page/bookshelf_page.dart:38-42`

## 问题

```dart
final crossAxisCount = deviceType == DeviceType.desktop
    ? 4
    : deviceType == DeviceType.tablet
    ? 4
    : 3;
```

而 `LayoutBreakpoints.getGridCrossAxisCount(context)` 返回 `{phone: 2, tablet: 4, desktop: 6}`。页面使用的是自己的值（phone: 3 而非 2，desktop: 4 而非 6），这可能是有意为之（书架需要更高的密度），但绕过了集中配置。

## 建议

考虑复用 `LayoutBreakpoints.getGridCrossAxisCount` 或调整集中配置的值来同时满足书架需求。
