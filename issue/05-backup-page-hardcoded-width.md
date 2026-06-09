# P4.1: 备份页面硬编码 600px 宽度

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P4（一致性）
- **文件**: `lib/features/backup/page/backup_page.dart:47`

## 问题

```dart
ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600)),
```

未使用断点系统。桌面端窗口上也强制 600px 宽度内容。虽然看起来没问题，但与其他页面（如首页使用断点感知的最大宽度）不一致。

## 建议

使用 `LayoutBreakpoints.getDeviceType(context)` 选择合适的最大宽度，或保持现状（此页面内容较少，600px 足够）。
