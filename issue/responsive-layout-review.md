# 响应式布局审查报告

审查日期：2026-06-09
审查范围：`lib/` 下所有响应式布局模式

---

## 概览

代码库使用集中式基于宽度的断点系统（`LayoutBreakpoints`，定义于 `adaptive_layout.dart`），配合 `MediaQuery.sizeOf(context).width` 进行判断。主布局（`MainLayout`）在 600px 断点处切换侧边栏/底部导航。整体策略正确，但存在命名误导、旧 API 残留及若干一致性缺失。

| 严重程度 | 数量 |
|---------|------|
| P1（可能误导） | 1 |
| P2（低严重度边界 bug） | 1 |
| P3（已弃用 API） | 2 |
| P4（一致性） | 2 |

---

## P1 — `DeviceType` 命名暗示硬件嗅探

**文件：** `lib/core/presentation/widgets/adaptive_layout.dart`

```dart
enum DeviceType { phone, tablet, desktop }
class LayoutBreakpoints {
  static bool isPhone(BuildContext context) { ... }
  static bool isTablet(BuildContext context) { ... }
  static bool isDesktop(BuildContext context) { ... }
  static DeviceType getDeviceType(BuildContext context) { ... }
}
```

**问题：** 命名暗示检查硬件类型，违反 skill 规则："Do not check for hardware types (e.g., 'phone' vs. 'tablet')"。实际上实现是完全基于 `MediaQuery.sizeOf(context).width` 的宽度检查，功能正确，但名称具有误导性——维护者可能认为 `DeviceType.phone` 意味着"这是一台手机"，而不是"窗口宽度 < 600px"。

**建议：** 重命名为 `ScreenSizeClass` / `isCompact` / `isMedium` / `isExpanded`，与 Material 3 命名对齐。波及范围广（多个页面导入），可一次性重构。

---

## P2 — 子页面使用窗口宽度而非内容区域宽度

**文件：** `lib/features/main_layout.dart`、`lib/features/home/page/home_page.dart`、`lib/features/bookshelf/page/bookshelf_page.dart`、`lib/features/backup/page/backup_page.dart`

**场景：** `MainLayout` 在平板/桌面端渲染 `Row(children: [sidebar, Expanded(child: child)])`。侧边栏在平板端占 72px，桌面端占 200px。但子页面调用 `MediaQuery.sizeOf(context).width` 获取的是**窗口**宽度，不是侧边栏之后剩余的宽度。

**边界问题：** 窗口 620px 宽时：
- `MediaQuery.sizeOf` → 620
- `getDeviceType()` → `DeviceType.tablet`（600 ≤ 620 < 840）
- `isTabletOrDesktop = true` → 显示侧边栏（72px）+ 内容（548px）
- 但实际上 548px 的内容区域属于手机宽度

影响有限：`home_page.dart` 使用 `Center` + `ConstrainedBox(maxWidth: 600)` 约束了内容，不会溢出。但侧边栏在手机级宽度下占用了不必要的空间。

**建议：** 对需要精确了解可用宽度的子页面改用 `LayoutBuilder`，或接受当前边界轻微偏差（影响范围仅 600-672px 窗口宽度）。

---

## P3 — 旧版 MediaQuery API（已弃用，2 处）

### 3.1 `reader_content.dart:116`

```dart
final disableAnim = MediaQuery.of(context).disableAnimations;
```

→ 应改为：

```dart
final disableAnim = MediaQuery.disableAnimationsOf(context);
```

（Flutter 3.10+ 引入基于函数的变体，`MediaQuery.of` 会导致不必要的子树重建）

### 3.2 `scroll_mode_renderer.dart:360`

```dart
(maxWidth * MediaQuery.of(context).devicePixelRatio).ceil()
```

→ 应改为：

```dart
(maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil()
```

---

## P4 — 一致性缺失

### 4.1 备份页面硬编码 600px

**文件：** `lib/features/backup/page/backup_page.dart:47`

```dart
ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600)),
```

未使用断点系统。桌面端窗口上也强制 600px 宽度内容。虽然看起来没问题，但与其他页面（如首页使用断点感知的最大宽度）不一致。

**建议：** 使用 `LayoutBreakpoints.getDeviceType(context)` 选择合适的最大宽度，或保持现状（此页面内容较少，600px 足够）。

### 4.2 书架页面网格缺少宽度约束

**文件：** `lib/features/bookshelf/page/shelf/bookshelf_book_content.dart`

网格（`GridView.builder`）直接渲染在 `Expanded` 中，没有 `Center` + `ConstrainedBox` 限制最大宽度。超宽显示器上，4 列书籍封面会拉伸到不切实际的大小。

**建议：** 参考 `home_page.dart` 的做法，在网格外包裹 `Center(child: ConstrainedBox(maxWidth: …))`。

### 4.3 书架页面重新实现了列数逻辑

**文件：** `lib/features/bookshelf/page/bookshelf_page.dart:38-42`

```dart
final crossAxisCount = deviceType == DeviceType.desktop
    ? 4
    : deviceType == DeviceType.tablet
    ? 4
    : 3;
```

而 `LayoutBreakpoints.getGridCrossAxisCount(context)` 返回 `{phone: 2, tablet: 4, desktop: 6}`。页面使用的是自己的值（phone: 3 而非 2，desktop: 4 而非 6），这可能是有意为之（书架需要更高的密度），但绕过了集中配置。

---

## 评分对照表

| 维度 | 评分 | 说明 |
|------|------|------|
| 断点使用 | ✅ | 统一 600/840 断点，使用 `MediaQuery.sizeOf` 而非 `MediaQuery.of` |
| Orientation 检查 | ✅ 无 | 代码库没有使用 `OrientationBuilder` 或 `MediaQuery.orientationOf` |
| Expanded/Flexible | ✅ | 广泛使用 `Expanded` 分配空间 |
| 宽度约束 | ⚠️ 部分 | 首页正确约束，备份页硬编码，书架页未约束 |
| LayoutBuilder | ❌ 大部分未用 | 仅 heatmap 使用；其他页面依赖 `MediaQuery.sizeOf` |
| 已弃用 API | ⚠️ 2 处 | `MediaQuery.of(context)` 应替换为 `MediaQuery.*Of(context)` |
| 可维护性 | ⚠️ | 命名误导 + 列数逻辑重复 + 硬编码值 |
