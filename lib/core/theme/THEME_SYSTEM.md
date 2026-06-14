# 主题系统

## 架构

```
widget
  │  Theme.of(context) / .extension<>()
  │
  ├── ThemeData ───────────────────────────────── AppThemes.buildTheme()
  │     ├── colorScheme ── Material 3 基础色板
  │     ├── textTheme ──── 7 档排版常量
  │     ├── 组件主题 ───── AppBar / Card / Button / Input / …
  │     └── extensions ─── AppThemeExtension（全局）
  │
  ├── ReaderThemeExtension ───── 阅读器主题（reader 子树内）
  │     ├── textColor
  │     ├── mutedColor
  │     ├── backgroundColor
  │     ├── surfaceColor
  │     ├── dividerColor
  │     ├── accentColor
  │     └── ttsActiveColor
  │
  ├── DesignTokens ────────────── 设计令牌（全局静态常量和函数）
  │     ├── 色板（primary / error / success / warning / warmAccent / …）
  │     ├── spacing(size) ── 8 档
  │     └── radius(size) ─── 6 档
  │
  ├── AnimTokens ──────────────── 动画 Token（全局静态常量）
  │     ├── fast / medium / normal / slow / scroll / persistent
  │     └── defaultCurve / emphasisCurve
  │
  └── IconSize ────────────────── 图标尺寸（全局静态常量）
        ├── inline=16 / leading=20 / nav=22 / hero=48
```

## 文件清单

| 文件 | 内容 |
|---|---|
| `app_theme.dart` | `AppThemes.buildTheme()` 工厂，排版 7 档 scale + 扩展 2 档，亮/深色基础色板 |
| `theme_constants.dart` | `DesignTokens`、`Spacing`、`RadiusSize`、`IconSize` |
| `theme_extension.dart` | `AppThemeExtension`（primaryContainer / surfaceVariant / shadow / dividerSubtle / overlay） |
| `reader_theme_extension.dart` | `ReaderThemeExtension`（.light / .dark / .sepia 三套预设） |
| `anim_tokens.dart` | `AnimTokens`（duration + curve） |
| `theme_manager.dart` | 主题切换、跟随系统 |
| `auto_theme_service.dart` | 按时间段自动切换亮/暗 |
| `menu_colors.dart` | 语义操作色映射表 |

## 排版常量（7 + 2 档 scale）

定义在 `app_theme.dart`，无 color（const 零开销），与 Material 3 TextTheme slot 映射：

| 名称 | fontSize | fontWeight | letterSpacing | 用途 | M3 slot |
|---|---|---|---|---|---|
| hero | 28 | w700 | -0.5 | 大 Banner、首页推荐标题 | `headlineMedium` |
| screenTitle | 24 | w700 | -0.3 | 页面大标题 | `headlineLarge` |
| sectionTitle | 20 | w600 | -0.2 | 区域/板块标题 | `headlineSmall` |
| itemTitle | 17 | w500 | -0.2 | 列表项标题、卡片标题 | `titleLarge` |
| **bodyLarge** | **15** | **w500** | — | 编号、副标题等稍大正文 | `AppThemes.bodyLarge` |
| body | 14 | w400 | — | 正文段落、列表副文本 | `bodyLarge` |
| label | 12 | w500 | 0.2 | 按钮、标签、Tab、辅助文字 | `labelLarge` |
| caption | 11 | w400 | — | 极小说明、时间戳、脚注 | `labelSmall` |
| **captionSmall** | **10** | **w400** | — | tag、徽章、紧凑场景 | `AppThemes.captionSmall` |

> `bodyLarge`(15) 和 `captionSmall`(10) 通过 `AppThemes.bodyLarge` / `AppThemes.captionSmall` 公开访问。

## 设计令牌

### 色板 `DesignTokens`

| 名称 | 值 | 用途 |
|---|---|---|
| primary | #F59E0B | 强调色（按钮、进度、选中、链接） |
| error | #D1453B | 错误 / 删除 |
| success | #3B8B5E | 成功状态 |
| warning | #F57C00 | 警告 |
| warmAccent | #D4A373 | 辅助装饰、品牌细节 |
| warmAccentLight | #FEF3E2 | 暖色浅底 |
| primaryContainer | #FEF0D6 | 选中项/标签背景 |
| secondary | #D4A373 | = warmAccent |
| tertiary | #8D6E63 | 三级色 |
| cardShadow | warmAccent@8% blur=8 offset=0,2 | 卡片/弹出菜单阴影 |
| dividerSubtle | warmAccent@12% | 弱化分割线 |

### 间距 `DesignTokens.spacing(Spacing size)`

| 档位 | 值 | 用途 |
|---|---|---|
| xs | 4 | 极微间距、icon 与文字间隙 |
| sm | 8 | 行内元素间距、chip padding |
| smMd | 12 | gap、chip/pill padding、选项间距 |
| md | 16 | 卡片内边距、列表项间距 |
| mdLg | 20 | ListView page 水平边距 |
| lg | 24 | 区域间距、section gap |
| xl | 32 | 页面大段间距 |
| xxl | 48 | 顶部大留白、hero 区域 |

### 圆角 `DesignTokens.radius(RadiusSize size)`

| 档位 | 值 | 用途 |
|---|---|---|
| xs | 4 | tag/badge/chip 圆角 |
| sm | 6 | 小型控件、tag/chip 选中态 |
| smMd | 10 | icon 容器、小型浮层 |
| md | 8 | 输入框、卡片 |
| lg | 12 | 弹窗、设置面板 |
| xl | 16 | 大型浮层 |

## 动画 Token `AnimTokens`

| 名称 | 值 | 典型用途 |
|---|---|---|
| fast | 150ms | 按钮反馈、选中态切换、小范围 fade |
| medium | 200ms | AnimatedContainer 选项按钮过渡、选择反馈 |
| normal | 250ms | AnimatedSwitcher、AnimatedCrossFade、面板显示隐藏 |
| slow | 300ms | 页面级切换、Tab 切换 |
| scroll | 500ms | scrollTo / scrollController.animateTo |
| persistent | 3s | 骨架屏 shimmer、Toast |
| stagger | 200ms | 列表 stagger 入场 delay |
| defaultCurve | easeInOut | 默认缓动 |
| emphasisCurve | easeOutBack | 弹跳感、缩放入场 |

## 图标尺寸 `IconSize`

| 名称 | 值 | 用途 |
|---|---|---|
| inline | 16 | 与内联文字并排的图标 |
| leading | 20 | 列表/菜单引导图标 |
| nav | 22 | 底部导航栏/侧边 Rail 图标 |
| hero | 48 | 空态/启动页大图标 |

## 阅读器主题 `ReaderThemeExtension`

`ReaderPage` 子树内通过 `Theme.of(context).extension<ReaderThemeExtension>()!` 获取。

### .light（亮色）

| Token | 值 |
|---|---|
| textColor | #2C2C2C |
| mutedColor | #6B6B76 |
| backgroundColor | #F8F6F0 |
| surfaceColor | #FFFDF7 |
| dividerColor | #EDEBE4 |
| accentColor | #D4A373 (warmAccent) |
| ttsActiveColor | #2E7D32 |

### .dark（深色）

| Token | 值 |
|---|---|
| textColor | #E8E6E1 |
| mutedColor | #8E8E99 |
| backgroundColor | #111118 |
| surfaceColor | #1A1A24 |
| dividerColor | #2A2A35 |
| accentColor | #D4A373 (warmAccent) |
| ttsActiveColor | #66BB6A |

### .sepia（护眼）

| Token | 值 |
|---|---|
| textColor | #4A3F35 |
| mutedColor | #8B7E6E |
| backgroundColor | #F8F4EA |
| surfaceColor | #EFE9DA |
| dividerColor | #D9D0BD |
| accentColor | #A0522D |
| ttsActiveColor | #2E7D32 |

## 使用规范

### ✅ 正确的做法

```dart
// 字体 — 用排版常量
style: _bodyLarge,
// 或从 Theme.of(context) 的 textTheme
style: Theme.of(context).textTheme.bodyMedium

// 圆角 — 用 DesignTokens
DesignTokens.radius(RadiusSize.md)

// 间距 — 用 DesignTokens
DesignTokens.spacing(Spacing.md)

// 动画 — 用 AnimTokens
duration: AnimTokens.normal

// 主题色 — 用 Theme.of(context) 的 extension
final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
readerTheme.textColor
```

### ❌ 禁止的做法

```dart
// 禁止 — 无魔法数字
fontSize: 16
const Duration(milliseconds: 250)
BorderRadius.circular(8)
padding: EdgeInsets.all(16)
Color(0xFFF59E0B)
```

## 已知 gap（审计 2026-06-14）

| 缺失 | 影响范围 | 状态 |
|---|---|---|
| radius 4px | tag / badge / chip ~8 处 | ✅ 已加 `RadiusSize.xs` |
| radius 10px | icon 容器 ~3 处 | ✅ 已加 `RadiusSize.smMd` |
| spacing 12px | gap / chip padding | ✅ 已加 `Spacing.smMd` |
| spacing 20px | ListView page margin | ✅ 已加 `Spacing.mdLg` |
| fontSize 15 / 10 | 散落值 | ✅ 已加 `AppThemes.bodyLarge`(15) / `captionSmall`(10) |
| fontSize 16 / 18 / 26 | 2/1/1 处 | 建议收敛到 17 / 20 / 28 |
| anim 500ms | chapter_list scrollTo | ✅ 已加 `AnimTokens.scroll` |
