# Zephyr Reader Theme System

> 规范文件 — 实际代码定义见 `lib/core/theme/`。
> 排版常量见 `app_theme.dart` 顶部 `const TextStyle`。

---

## 核心原则

1. **所有视觉属性走主题系统，不走字面值。**
2. **所有 widget 通过 `Theme.of(context).textTheme.xxx` 引用排版。**
3. **使用 `copyWith(color:)` 变颜色，不动 `fontSize`/`fontWeight`/`letterSpacing`。**
4. **不存在于本系统的值不应出现在代码中。**

---

## 1. 排版体系

### 1.1 7 档 Scale

| Size | Weight | Letter | M3 Slot | 角色 | 场景 |
|------|--------|--------|---------|------|------|
| **28** | 700 | -0.5 | `headlineMedium` | **hero** | 成就页大数字、空态大标题 |
| **24** | 700 | -0.3 | `headlineLarge` | **screen title** | 书架/统计页顶级标题 |
| **20** | 600 | -0.2 | `headlineSmall` | **section title** | profile 大字、区域头部 |
| **17** | 500 | -0.2 | `titleLarge` | **item title** | 列表项标题、"Zephyr Reader" |
| **14** | 400 | — | `bodyLarge` | **body** | 设置描述、正文内容 |
| **12** | 500 | 0.2 | `labelLarge` | **label** | 标签、统计数值、搜索结果 |
| **11** | 400 | — | `labelSmall` | **caption** | 版本号、元数据、footnote |

### 1.2 递进曲线

```
28 → 24 → 20 → 17 → 14 → 12 → 11
  4    4    3    3    2    1     (px step)
```

大档时步子大（4px），到阅读尺寸区收窄（2→1px），符合韦伯-费希纳定律——人对大字差距不敏感、小字差距敏感。

### 1.3 不覆盖的 M3 Slots

以下保持 M3 默认（`Typography.material2021()`）：

```
displayLarge(57)  displayMedium(45)  displaySmall(36)
titleMedium(16)   titleSmall(14)
bodyMedium(14)    bodySmall(12)
labelMedium(12)
```

### 1.4 引用规则

```dart
// ✅ 正确
style: Theme.of(context).textTheme.labelLarge
// ✅ 变色
style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)
// ❌ 禁止：直接写 fontSize
style: TextStyle(fontSize: 12, color: Colors.red)
```

---

## 2. 字族


```
iOS     → SF Pro (系统自带 CJK fallback)
Android → Roboto (HarfBuzz 渲染 CJK)
```

代码中在 `AppThemes.fontFamily` 常量声明，为 `null`。如需品牌字族，改此常量为已注册字体名称即可。

```dart
// app_theme.dart — 改 null 为字体名即全局生效
static const String? fontFamily = null;  // 系统默认
// static const String fontFamily = 'Noto Sans SC';  // 品牌字族（需 bundle）
```
---

## 3. 色彩体系

### 3.1 三层层级

```
Layer 1: DesignTokens（品牌色、语义色）
         静态 const Color，编译期常量

Layer 2: ThemeData.colorScheme（M3 色板）
         由 buildTheme() 从 seedColor 或手写计算

Layer 3: ThemeExtension（自定义语义色）
         AppThemeExtension    — 表面、覆盖层、分割线
         ReaderThemeExtension — 阅读器三套预设
```

### 3.2 色板定义

**品牌色 / 强调色**

| Token | 色值 | 用途 |
|-------|------|------|
| `DesignTokens.primary` | `#F59E0B` | 按钮、进度、选中态、链接 |
| `DesignTokens.secondary` | `#D4A373` | 辅助装饰 |
| `DesignTokens.warmAccent` | `#D4A373` | 品牌细节 |

**语义色**

| Token | 色值 | 用途 |
|-------|------|------|
| `DesignTokens.error` | `#D1453B` | 错误提示 |
| `DesignTokens.success` | `#3B8B5E` | 成功状态 |
| `DesignTokens.warning` | `#F57C00` | 警告状态 |

**亮/暗模式基底**

| Token | 亮色 | 深色 |
|-------|------|------|
| `scaffoldBg` | `#FAFAFA` | `#000000` |
| `surface` | `#FFFFFF` | `#080808` |
| `textPrimary` | `#1A1A1A` | `#F2F2F2` |
| `textSecondary` | `#8A8A8E` | `#6E6E73` |
| `divider` | `#E5E5EA` | `#1C1C1E` |

**阅读器主题（3 套 preset）**

| 角色 | 亮色 | 深色 | 护眼(sepia) |
|------|------|------|-------------|
| text | `#2C2C2C` | `#E8E6E1` | `#4A3F35` |
| muted | `#6B6B76` | `#8E8E99` | `#8B7E6E` |
| bg | `#F8F6F0` | `#111118` | `#F8F4EA` |
| surface | `#FFFDF7` | `#1A1A24` | `#EFE9DA` |
| divider | `#EDEBE4` | `#2A2A35` | `#D9D0BD` |
| accent | `#D4A373` | `#D4A373` | `#A0522D` |

**AppThemeExtension（自定义角色）**

| Token | 含义 |
|-------|------|
| `primaryContainer` | 选中项/标签强调背景 |
| `surfaceVariant` | 轻微替代背景 |
| `shadow` | 暖色装饰阴影 |
| `dividerSubtle` | 弱化分割线 |
| `overlayLight` / `overlayMedium` | 覆盖层 |

### 3.3 🔴 已知问题：`fromSeed` 矛盾

```dart
// 当前：override 了 fromSeed 的所有输出
ColorScheme.fromSeed(
  seedColor: primary,
  primary: primary,         // ← 覆盖
  onPrimary: onPrimary,     // ← 覆盖
  secondary: ...,           // ← 覆盖
  surface: ...,             // ← 覆盖
  ...
)
```

`fromSeed` 计算被全量覆盖，白算一遍。应改为：

```dart
// 方案 A：让 fromSeed 真正算
ColorScheme.fromSeed(seedColor: primary, brightness: brightness)

// 方案 B：手写完整色板
ColorScheme.light(
  primary: primary,
  onPrimary: onPrimary,
  secondary: DesignTokens.secondary,
  surface: _bgLight,
  ...
)
```

### 3.4 引用优先级

```
1. colorScheme.xxx        → M3 标准角色
2. AppThemeExtension.xxx  → 自定义角色（表面变体、覆盖层）
3. ReaderThemeExtension   → 阅读器内专用
4. DesignTokens.xxx       → 品牌色（仅在 ThemeData 构建中引用）
```

### 3.5 消费规则

```dart
// ✅ 正确
final cs = Theme.of(context).colorScheme;
style: TextStyle(color: cs.onSurface)

// ✅ 主题扩展
final ext = Theme.of(context).extension<AppThemeExtension>()!;
color: ext.dividerSubtle

// ❌ 禁止：widget 内直接 color: Color(0xFF1A1A1A)
```

---

## 4. 间距系统

### 4.1 Token 定义

```
xs(4)   sm(8)   md(16)   lg(24)   xl(32)   xxl(48)
```

引用方式：`DesignTokens.spacing(Spacing.md)`

### 4.2 已知硬编码残留

| 位置 | 当前 | 应为 |
|------|------|------|
| `appBarTheme`, `inputDecorationTheme`, `listTileTheme`, `chipTheme` | `EdgeInsets.all(16)` / `horizontal: 16` | `DesignTokens.spacing(Spacing.md)` |
| `elevatedButtonTheme.padding` | `horizontal: 24` | `DesignTokens.spacing(Spacing.lg)` |
| `cardTheme` padding | 未设置（走 M3 默认 16） | 一致化 |

### 4.3 页面边缘 padding

| 断点 | 水平 padding |
|------|-------------|
| > 600px | `Spacing.xl` (32) |
| ≤ 600px | `Spacing.md` (16) |

### 4.4 组件间 gap

| 场景 | 推荐 gap |
|------|---------|
| 列表项之间 | `Spacing.sm` (8) |
| 设置 section 之间 | `Spacing.lg` (24) |
| 图标与文字 | `Spacing.xs` (4) |
| 标签与内容 | `Spacing.sm` (8) |

---

## 5. 圆角系统

### 5.1 Token 定义

```
sm(6)    md(8)    lg(12)    xl(16)
```

引用方式：`DesignTokens.radius(RadiusSize.md)`

### 5.2 已知硬编码残留

| 位置 | 当前 | 应为 |
|------|------|------|
| `elevatedButtonTheme` | `BorderRadius.circular(8)` | `radius(RadiusSize.md)` |
| `outlinedButtonTheme` | `BorderRadius.circular(8)` | `radius(RadiusSize.md)` |
| `inputDecorationTheme` | `BorderRadius.circular(8)` | `radius(RadiusSize.md)` |
| `popupMenuTheme` | `BorderRadius.circular(8)` | `radius(RadiusSize.md)` |

### 5.3 典型映射

| 组件形态 | 圆角 |
|---------|------|
| 按钮、输入框 | `md` (8) |
### 6.1 Token 定义

```dart
// lib/core/theme/theme_constants.dart — class IconSize
IconSize.inline   = 16   // 与内联文字并排
IconSize.leading  = 20   // 列表/菜单引导图标
IconSize.nav      = 22   // 底部导航栏/侧边 Rail
IconSize.hero     = 48   // 空态/启动页大图标
```

### 6.2 场景映射

| 场景 | 大小 | Token |
|------|------|-------|
| 底部导航栏 / Rail | 22 | `IconSize.nav` |
| ListTile leading | 20 | `IconSize.leading` |
| 按钮内联图标 | 16 | `IconSize.inline` |
| 设置项图标 | 16 | `IconSize.inline` |
| 空态/大图 | 48 | `IconSize.hero` |
| **全局默认** | **22** | `IconThemeData(size: IconSize.nav)` |

### 6.3 库

`phosphoricons_flutter`（Phosphor Icons）是统一的图标源。不要混入其他图标集。

---

## 7. 阴影与层级

### 7.1 当前状态

所有组件 `elevation: 0`，全平面设计。

### 7.2 推荐层级

| 层级 | 用途 | 当前值 |
|------|------|--------|
| 0 | 卡片、按钮、surface | `elevation: 0` ✅ 已实现 |
| 1 | 弹出菜单 | `elevation: 0` → 可考虑 `elevation: 1-2` |
| 2 | Dialog / Snackbar | 未定义（M3 默认） |
| 3 | Bottom sheet | 未定义（M3 默认） |

暖色阴影代替 elevation 区分层次：`DesignTokens.cardShadow`（`D4A373 @ 8%`）。

---

## 8. 动效与动画

### 8.1 Token 定义

```dart
// lib/core/theme/anim_tokens.dart
class AnimTokens {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration persistent = Duration(seconds: 3);
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve emphasisCurve = Curves.easeOutBack;
}
```

### 8.2 典型映射

| 场景 | Duration | Curve |
|------|----------|-------|
| Button press | `fast` (150) | `easeInOut` |
| Panel show/hide | `normal` (250) | `easeInOut` |
| Page transition | 系统默认 | `Cupertino` / `FadeUpwards` |
| List item stagger | `stagger` (200) | `easeOut` |
| Shimmer | `shimmer` (3s) | — |

### 8.3 页面过渡

```dart
pageTransitionsTheme: PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
  },
)
```
---

## 9. 组件主题

### 9.1 已定义

| 组件 | 位置 | 状态 |
|------|------|------|
| AppBar | `appBarTheme` | ✅ |
| Card | `cardTheme` | ✅ |
| ElevatedButton | `elevatedButtonTheme` | ✅ |
| OutlinedButton | `outlinedButtonTheme` | ✅ |
| TextButton | `textButtonTheme` | ✅ |
| InputDecoration | `inputDecorationTheme` | ✅ |
| PopupMenu | `popupMenuTheme` | ✅ |
| ListTile | `listTileTheme` | ✅ |
| Icon | `iconTheme` | ✅ |
| Chip | `chipTheme` | ✅ |
| Divider | `dividerTheme` | ✅ |
| Slider | `sliderTheme` | ✅ |
| BottomNav | `navigationBarTheme` | ✅ |
| NavRail | `navigationRailTheme` | ✅ |

### 9.2 未定义（走 M3 默认）

| 组件 | 是否需自定义 | 理由 |
|------|-------------|------|
| Dialog | ⬜ 待定 | 弹窗不频繁，可默认 |
| SnackBar | ⬜ 待定 | 只读提示，可默认 |
| BottomSheet | ⬜ 待定 | 阅读器外不常用 |
| Tooltip | ⬜ 待定 | 触屏少 hover |
| Switch | ⬜ 待定 | 设置页少量使用 |
| Checkbox / Radio | ⬜ 待定 | 未出现在 UI 中 |

---

## 10. 排版 vs 组件内敛样式

当前 `buildTheme()` 中多处组件主题使用 `TextStyle(...)` 而非引用排版常量：

| 位置 | 当前 | 应为 |
|------|------|------|
| `appBarTheme.titleTextStyle` | `TextStyle(size:20, w600, ...)` | 无对应 slot，保持现状 |
| `listTileTheme.titleTextStyle` | `TextStyle(size:16, w400, ...)` | `textTheme.titleMedium`? 但不完全一致 |
| `listTileTheme.subtitleTextStyle` | `TextStyle(size:13, ...)` | 无对应 slot（13 已从系统移除）|
| `navigationBarTheme.labelTextStyle` | `TextStyle(size:12, ...)` | `textTheme.labelLarge` |
| `elevatedButtonTheme.textStyle` | `TextStyle(size:15, w500)` | 无对应 slot |

其中 `subtitleTextStyle`(13) 和 `textStyle`(15) 引用了已不在 7 档中的尺寸。需要决定：修正为已有 slot 还是新增。

---

## 11. 状态对照

### 维度总览

```
维度              当前                               目标                              状态
──────            ────                               ───                               ────
📐 排版          10→7 档 const TextStyle              7 档 + 预留                        ✅ 已实现
🔤 字族          平台默认                             待定（可不设）                      ⬜ 待决策
🎨 色板          DesignTokens + fromSeed + Extension  一致色板，修复 fromSeed 矛盾        ⚠️ P0
📏 间距          6 档 DesignTokens + 硬编码            统一引用 DesignTokens               ⚠️ P0
🏋️ 圆角          4 档 DesignTokens + 硬编码            统一引用 DesignTokens               ⚠️ P0
🎯 图标          phosphoricons + size:22              size 体系 + token                   ⚠️ P2
⬆️ 阴影          elevation:0 全平面                    保持现状 / 可加 elevation token     ⚠️ P3
🔄 动画          散落 duration                         全局 AnimTokens                     ⚠️ P2
🏗️ 组件          14 项定义 + 6 项默认                   补充缺失项                          ⚠️ P3
```

### 优先级

| 标签 | 含义 |
|------|------|
| ✅ 已实现 | 代码和规范一致 |
| ⚠️ P0 | 有已知问题需修复 |
| ⚠️ P1 | 有改进空间 |
| ⚠️ P2 | 值得做但不紧急 |
| ⚠️ P3 | 未来方向 |
| ⬜ 待决策 | 需要产品决策 |

---

## 12. 添加新 Token 的流程

1. 确定 token 类型（color/spacing/radius/textStyle/duration/iconSize）
2. 加到对应定义文件（`theme_constants.dart` / `app_theme.dart` 顶部 const / 新建文件）
3. 如果是个新的语义角色，加到对应的 `ThemeExtension`
4. 更新此文档
5. **新 widget 禁止 inline 值** — 必须走 token
