# P2: 子页面使用窗口宽度而非内容区域宽度

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P2（低严重度边界 bug）
- **文件**: `lib/features/main_layout.dart`、`lib/features/home/page/home_page.dart`、`lib/features/bookshelf/page/bookshelf_page.dart`、`lib/features/backup/page/backup_page.dart`

## 问题

`MainLayout` 在平板/桌面端渲染 `Row(children: [sidebar, Expanded(child: child)])`。侧边栏在平板端占 72px，桌面端占 200px。但子页面调用 `MediaQuery.sizeOf(context).width` 获取的是**窗口**宽度，不是侧边栏之后剩余的宽度。

**边界问题：** 窗口 620px 宽时：
- `MediaQuery.sizeOf` → 620
- `getDeviceType()` → `DeviceType.tablet`（600 ≤ 620 < 840）
- `isTabletOrDesktop = true` → 显示侧边栏（72px）+ 内容（548px）
- 但实际上 548px 的内容区域属于手机宽度

影响有限：`home_page.dart` 使用 `Center` + `ConstrainedBox(maxWidth: 600)` 约束了内容，不会溢出。但侧边栏在手机级宽度下占用了不必要的空间。

## 建议

对需要精确了解可用宽度的子页面改用 `LayoutBuilder`，或接受当前边界轻微偏差（影响范围仅 600-672px 窗口宽度）。
