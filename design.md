# Zephyr Reader — UI 设计语言

> 基于代码库实际实现提取的设计规范。所有值、颜色、间距、圆角均与 `lib/core/theme/` 和页面代码一致。

---

## 1. 设计哲学

**"Warm Minimal" — 温暖极简，内容优先。**

- 干净的版面 + 暖色点缀，不喧宾夺主。
- 纸本阅读感：阅读器支持米色护眼底（sepia），首页 Hero 卡片用暖棕渐变，分割线带暖色基调。
- Material 3 为基础，但通过大量自定义主题覆盖抹平了 M3 的圆角和阴影默认值，回归更克制的视觉节奏。
- 全部组件使用自定义设计令牌（`DesignTokens`），不允许字面值。

---

## 2. 色板

### 2.1 品牌色 / 强调色

| Token | 色值 | 用途 |
|-------|------|------|
| `DesignTokens.primary` | `#F59E0B` 暖橙 | 按钮、进度、选中态、链接、导航指示器 |
| `DesignTokens.warmAccent` | `#D4A373` 暖赭 | 辅助装饰、Hero 渐变、品牌细节 |
| `DesignTokens.warmAccentLight` | `#FEF3E2` | 浅色容器的暖调底衬 |
| `DesignTokens.primaryContainer` | `#FEF0D6` | 选中项背景、标签底色 |

### 2.2 语义色

| Token | 色值 | 用途 |
|-------|------|------|
| `DesignTokens.error` | `#D1453B` 暖红 | 错误、危险操作 |
| `DesignTokens.success` | `#3B8B5E` 哑绿 | 成功态 |
| `DesignTokens.warning` | `#F57C00` | 警告 |

### 2.3 亮色模式

| Token | 色值 |
|-------|------|
| 背景 `scaffoldBg` | `#FAFAFA` |
| 表面色 | `#FFFFFF` |
| 主文字 | `#1A1A1A` |
| 辅助文字 | `#8A8A8E` |
| 分割线 | `#E5E5EA` |

### 2.4 深色模式

| Token | 色值 |
|-------|------|
| 背景 `scaffoldBg` | `#000000` |
| 表面色 | `#080808` |
| 主文字 | `#F2F2F2` |
| 辅助文字 | `#6E6E73` |
| 分割线 | `#1C1C1E` |

### 2.5 阅读器主题（`ReaderThemeExtension`）

提供三套独立于系统主题的配色：

| 角色 | 亮色 | 深色 | 护眼（Sepia） |
|------|------|------|------|
| 文字色 | `#2C2C2C` | `#E8E6E1` | `#4A3F35` |
| 弱化文字 | `#6B6B76` | `#8E8E99` | `#8B7E6E` |
| 背景色 | `#F8F6F0` | `#111118` | `#F8F4EA` |
| 表面色 | `#FFFDF7` | `#1A1A24` | `#EFE9DA` |
| 分割线 | `#EDEBE4` | `#2A2A35` | `#D9D0BD` |
| 强调色 | `#D4A373` | `#D4A373` | `#A0522D` |
| TTS 高亮 | `#2E7D32` | `#66BB6A` | `#2E7D32` |

UI 工具栏使用玻璃拟态（`BackdropFilter` + `blur(16px)` + 70% 透明面），呼应阅读背景。

### 2.6 菜单项语义色

`MenuItemSemantic` 枚举统一管理设置列表各个条目的图标颜色，每个成员提供 `iconColor(Brightness)` 和 `iconBackground(Brightness)`，亮暗模式各自适配。

---

## 3. 间距系统

基于 `DesignTokens.spacing(Spacing)` 枚举，所有间距引用此系统。

| 令牌 | 尺寸 |
|------|------|
| `Spacing.xs` | 4px |
| `Spacing.sm` | 8px |
| `Spacing.md` | 16px |
| `Spacing.lg` | 24px |
| `Spacing.xl` | 32px |
| `Spacing.xxl` | 48px |

页面边缘 padding 根据 `LayoutBreakpoints` 自适应：

| 断点 | 水平 padding |
|------|-------------|
| compact (< 600px) | 16px |
| medium (600–840px) | 24px |
| expanded (≥ 840px) | 32px |

---

## 4. 圆角系统

基于 `DesignTokens.radius(RadiusSize)` 枚举：

| 令牌 | 尺寸 | 典型用途 |
|------|------|----------|
| `RadiusSize.sm` | 6px | 按钮、输入框、小元素 |
| `RadiusSize.md` | 8px | 卡片、图片封面、弹窗 |
| `RadiusSize.lg` | 12px | 设置卡片、弹出菜单 |
| `RadiusSize.xl` | 16px | 大容器 |

选择/标签 Chip 使用 16px 圆角（pill 形态）。

---

## 5. 排版

### 5.1 层级

| 样式 | fontSize | weight | letterSpacing | 用途 |
|------|----------|--------|---------------|------|
| `displayLarge` | 32px | 700 | -0.5 | 大标题 |
| `displayMedium` | 28px | 600 | -0.3 | 次级大标题 |
| `headlineLarge` | 24px | 700 | -0.3 | 页面主标题 |
| `headlineMedium` | 20px | 600 | -0.2 | AppBar 标题 / 章节标题 |
| `titleLarge` | 18px | 600 | -0.2 | 卡片标题 |
| `titleMedium` | 16px | 500 | — | 列表标题 |
| `bodyLarge` | 15px | 400 | 行高 1.6 | 正文 |
| `bodyMedium` | 13px | 400 | — | 辅助文字 |
| `labelLarge` | 12px | 500 | +0.2 | 标签 / 按钮文字 |
| `labelSmall` | 10px | 400 | — | 极小标签 |

### 5.2 通用模式

- **AppBar 标题**：22px / 700 weight / -0.5 letter spacing（由 `SettingsAppBar` 统一）。
- **页面标题**：home 页"继续阅读" 26px / 700 weight / -0.5 spacing。
- **Section 标签**：12px / 600 weight / +0.4 letter spacing / 60% 不透明度（`SectionLabel`）。
- **设置条目标题**：14px / 500 weight。
- **设置条目副标题**：11px / 400 weight。
- **装饰性小字**：11px 辅助色，用于版本号、页脚等。

---

## 6. 阴影与层级

- **默认无阴影**：卡片、按钮 elevation 统一为 0。
- **暖色装饰阴影**（仅局部使用）：
  ```
  offset: (0, 2), blur: 8, color: #D4A373 @ 8%
  ```
- **弹出菜单**：elevation 0，仅靠 0.5px 描边与背景区隔。
- **阅读器工具栏**：玻璃拟态（blur + 半透明背景）制造浮层感，无阴影。
- **封面阴影**：轻微偏移 + 暖色半透明（`book_detail_hero.dart`）。

---

## 7. 图标

- **图标库**：`phosphoricons_flutter`（Phosphor Icons）。
- **规范**：尺寸 22px（主题默认）或 16px（设置图标容器内），选中态用 Fill 变体，未选中用 Regular。
- **设置图标容器**：32×32px 方块，8px 圆角，使用语义色 `iconBackground`（12% 不透明度）。

---

## 8. 卡片与容器

### 8.1 设置卡片（`SettingsCard`）
- 纯色背景（`colorScheme.surface`）
- 12px 圆角
- 0.5px `outlineVariant` 描边（透明度 15–20%）
- 可选的 `showDividers`（item 之间 0.5px 分割线）
- 非分割模式：children 统一 16px 内 padding

### 8.2 内容卡片（书架/统计）
- 透明背景（依靠父级 surface）
- 仅用圆角 + 描边（或纯色底 + 圆角）= 极简
- 无 elevation，无阴影

### 8.3 Hero 卡片（首页）
- 暖棕渐变背景（`warmAccent` → 70% 同色）
- 白色文字 + 白色按钮
- 8px 圆角
- 暗色模式下加深 40%

---

## 9. 导航

### 9.1 移动端（底部导航栏）
- 4 项：首页 / 书架 / 统计 / 我的
- 无背景色 `NavigationBar`，自定义 `Container` + 顶部 0.5px 分割线
- 选中态：`AnimatedScale` (0.9 → 1.0, 300ms, `easeOutBack`)
- 底部指示器：2px 高 × 20px 宽的圆角条（选中时显示，未选中宽度归零）
- 触感反馈 `HapticType.light`

### 9.2 平板/桌面端（左侧 Rail）
- 宽度：collapsed 72px / expanded 200px
- 右侧 0.5px 分割线
- 无背景色
- 选中项：下方 2×18px 指示条
- 顶部 Logo：书图标 + 扩展时显示 "Zephyr"

---

## 10. 按钮

| 类型 | 样式 |
|------|------|
| `ElevatedButton` | 主色背景 + 白色文字；14px 垂直 padding + 24px 水平；8px 圆角；0 elevation；15px/500 weight 文字 |
| `OutlinedButton` | 8px 圆角；0.5px `#E5E5EA` 描边 |
| `FilledButton.tonalIcon` | 用于空态引导 |
| Hero 场景 | 白色按钮 + 暖色文字，覆盖在渐变背景上 |

---

## 11. 表单输入

- 填充背景 + 8px 圆角
- 0.5px 描边（默认），聚焦时 1px 主色描边
- 12px 垂直 + 16px 水平内边距
- 错误态：`#D1453B` 描边

---

## 12. 动画与过渡

### 12.1 页面过渡
- iOS：`CupertinoPageTransitionsBuilder`
- Android：`FadeUpwardsPageTransitionsBuilder`

### 12.2 列表出现动效
```
.animate(delay: (index * 80).ms)
  .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
  .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
```

### 12.3 区域出现动效
```
.animate()
  .fadeIn(duration: 400.ms)
  .slideY(begin: -0.04, end: 0)
```

### 12.4 设置区域
```
.animate()
  .fadeIn(duration: 300.ms, delay: 100.ms)
  .slideY(begin: 0.03, end: 0)
```

### 12.5 选择 Chip
`AnimatedContainer(duration: 200ms)` 切换背景和边框。

### 12.6 骨架屏
闪烁 shimmer 动画，`Duration(seconds: 3)` 后自动停止。

---

## 13. 空态 / 加载态 / 错误态

使用统一的 `AsyncState` 模式（`loading` / `data` / `error`）。

| 状态 | 呈现 |
|------|------|
| **loading** | `SkeletonWidget` / `SkeletonGrid`（闪烁占位） |
| **empty** | 48px 大图标（30% 不透明度）+ 提示文字 + `FilledButton.tonalIcon` |
| **error** | 居中文字 + `TextButton` 重试 |
| **data** | 正常内容 |

`GoReadingEmptyState` 是预置的空态组件，用于引导前往书架开始阅读。

---

## 14. 响应式布局

基于宽度断点，不依赖硬件类型：

| 分类 | 宽度范围 | 栅格列数 | 导航形式 |
|------|----------|----------|----------|
| `compact` | < 600px | 2–3 列 | 底部导航栏 |
| `medium` | 600–840px | 4 列 | 左侧栏（collapsed 72px） |
| `expanded` | ≥ 840px | 4–6 列 | 左侧栏（expanded 200px） |

页面内容使用 `ConstrainedBox` 限制最大宽度避免过宽：
- home：`min(expandedMin, compactMax)` 居中
- 书架 grid：`min(1200, expandedMin)` 居中

---

## 15. 设置页面规范

所有设置子页面遵循统一结构：

```
Scaffold
  └─ SettingsAppBar (22px · 700w · -0.5ls)
  └─ ListView (padding: 20h 0v 40b)
       ├─ Column
       │    ├─ SectionLabel (12px · 600w · +0.4ls · 60% opacity)
       │    └─ SettingsCard (12px radius · 0.5px border)
       │         ├─ SettingsNavigationTile → 32px icon box + title + subtitle + caret
       │         ├─ SettingsToggleTile    → 同上 + Switch.adaptive
       │         └─ SettingsSliderTile    → label + value badge + Slider
       ├─ SizedBox(height: 24)
       └─ ...
```

每个 section 包裹在 `.animate().fadeIn().slideY()` 中。

---

## 16. 代码约定

### 16.1 状态管理
- 使用 `signals` + `flutter_hooks` + `signals_hooks`
- `useSignalValue` 订阅信号
- `SignalBuilder` 用于树中子树的局部重建
- `useEffect` / `useMemoized` 管理生命周期

### 16.2 主题引用
- 组件通过 `Theme.of(context)` 取 `colorScheme`
- 自定义令牌通过 `DesignTokens.*` 或 `Theme.of(context).extension<AppThemeExtension>()`
- 阅读器独立主题通过 `Theme.of(context).extension<ReaderThemeExtension>()`

### 16.3 命名与组织
- feature 按 `page/` / `application/` / `data/` / `domain/` 分层
- 共享 UI 组件放在 `core/presentation/widgets/`
- 设置类组件放在 `core/presentation/widgets/settings/`

### 16.4 性能
- `RepaintBoundary` 包裹列表项（书架 grid 等）
- `ConstrainedBox` 限制内容宽度避免跨屏差距过大
- 骨架屏 `SkeletonWidget` 闪烁 3 秒后自动停止
- 图片 `cacheWidth` 限制解码大小（如书封 240px）

### 16.5 本地化
- 使用 `AppLocalizations.of(context)!` 获取当前语言
- 所有用户可见字符串必须经过 l10n，不允许硬编码

---

## 17. 设计决策记录

| 决策 | 理由 |
|------|------|
| 弃用 M3 默认阴影和 elevation | 更干净的表面层级，减少视觉噪声 |
| 暖色作为唯一强调色 | 区别于冷色系竞品，强调阅读的温暖感受 |
| 阅读器独立三套主题 | 阅读沉浸感优先，不受系统主题切换影响 |
| 玻璃拟态仅用于阅读器工具栏 | 保持功能层级清晰，不泛化特效 |
| 全部间距走 DesignTokens 枚举 | 确保跨页面一致性，方便全局调整 |
| 不使用 M3 NavigationBar，自建 Row | 便于自定义动画和指示器样式 |
| 设置页复用的 SectionLabel + SettingsCard 模式 | 统一的设置浏览体验，降低新增页面的决策成本 |
| Hero 卡片用渐变而非纯色 | 赋予首页视觉重心，区分内容区域 |
