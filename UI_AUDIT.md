# Zephyr Reader — UI Audit & Improvement Plan

> **Design Direction: "Scholarly Retreat"** — Warm paper tones, literary serif typography, gentle atmospheric depth. The app should feel like stepping into a well-lit personal library, not an app. Surfaces reference paper and parchment; motion is unhurried and organic; the reader page is a sanctuary.

---

## Overview

| Item | Status |
|------|--------|
| Structural foundation | Strong (DesignTokens, ThemeExtension, ReaderThemeExtension, ThemeManager) |
| Visual execution | Flat — lacking atmosphere, texture, and typographic character |
| Core problem | A reading app whose UI doesn't evoke reading |
| Fix scope | Incremental — all changes build on existing tokens/architecture |
| Est. effort | ~4–6 hours total across 10 categories |

---

## 1. Typography — The #1 Opportunity

### Current state
- No custom fonts in `pubspec.yaml`
- Falls back to system defaults: Noto Sans SC (Chinese), Roboto (English)
- Text theme defines sizes/weights but no `fontFamily`
- A **reading app** with no typographic identity

### Recommendation

```yaml
# pubspec.yaml
fonts:
  - family: LXGW WenKai      # 霞鹜文楷 — warm, handwritten-style serif
    fonts:
      - asset: assets/fonts/LXGWWenKai-Regular.ttf
      - asset: assets/fonts/LXGWWenKai-Bold.ttf
        weight: 700
  - family: Noto Serif SC     # Literary serif for body text
    fonts:
      - asset: assets/fonts/NotoSerifSC-Regular.otf
      - asset: assets/fonts/NotoSerifSC-Bold.otf
        weight: 700
```

**Wiring plan:**

| Location | Font | Rationale |
|----------|------|-----------|
| `bodyLarge` / `bodyMedium` in `_textTheme()` | Noto Serif SC | Serifs aid horizontal reading flow in Chinese |
| Reading body (reader page content) | Noto Serif SC | Default reading font |
| Quote cards (home page) | LXGW WenKai | Literary/artistic flair |
| Chapter titles, display text | LXGW WenKai Bold | Warm, distinctive heading |
| UI labels (small, navigation) | System font | Legibility at small sizes |
| Reader font picker | Add both as options | User choice |

**File affected:** `pubspec.yaml`, `lib/core/theme/app_theme.dart`, `lib/features/reader/page/widgets/reader_settings_panel.dart`

---

## 2. Surfaces — Warm Paper Palette

### Current state

| Token | Light | Dark |
|-------|-------|------|
| `background` | `#FAFAFA` | `#0A0A0A` |
| `surface` | `#FFFFFF` | `#111111` |

Too cold and clinical for a reading app. The `ReaderThemeExtension` already has warm tones (`#F8F6F0`, `#FFFDF7`) — the app chrome should harmonize with them.

### Recommendation

All values (`background`/`surface`, both light and dark) **kept as-is** — warm paper tones are reserved for the reader theme (`ReaderThemeExtension`). Dark mode uses `#000000` / `#080808` for OLED power efficiency.

### Additional surface improvements

```dart
// AppThemeExtension — card shadows (currently transparent/zero)
static BoxShadow cardShadow = BoxShadow(
  color: Color(0xFFD4A373).withValues(alpha: 0.08),
  blurRadius: 8,
  offset: Offset(0, 2),
);
```

- Quote card and recent-reading cards: `0.5px` border in `warmAccent` with subtle shadow
- `dividerSubtle`: warm-tinted `#D4A373` at 12% instead of neutral gray
- Remove explicit `shadowColor: Colors.transparent` from `CardTheme` / `PopupMenuTheme`

**Files affected:** `lib/core/theme/theme_constants.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/theme_extension.dart`

---

## 3. Hero Gradient — Let Warmth Bleed

### Current state
`_heroGradient` defined as `LinearGradient` and used only inside a single card on home page.

### Recommendation
Add a **decorative warm wash** behind the home page header — a large radial gradient in the top-left quadrant that gives the page a sense of place without overwhelming content.

```dart
// Behind the CustomScrollView in _buildContent
Stack(
  children: [
    Positioned(
      top: -60,
      left: -40,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              DesignTokens.warmAccent.withValues(alpha: 0.07),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
    // Existing CustomScrollView...
  ],
)
```

**Same pattern** could extend to:
- Profile page header avatar area
- Bookshelf page title area
- Reader page when showing catalog/bookmarks

**Files affected:** `lib/features/home/page/home_page.dart`, optionally `lib/features/profile/page/profile_page.dart`, `lib/features/reader/page/reader_page.dart`

---

## 4. Page Transitions — Book-Like

### Current state
- iOS: `CupertinoPageTransitionsBuilder`
- Android/others: `FadeUpwardsPageTransitionsBuilder`
- ReaderPage: standard push

### Recommendation

**Bookshelf → Reader transition ("open book")**

```dart
// In router configuration
CustomTransitionPage<void>(
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1).animate(animation),
        child: child,
      ),
    );
  },
)
```

**Reader → Bookshelf ("close book")**

```dart
// Reverse: slight scale-down + fade
ScaleTransition(
  scale: Tween<double>(begin: 1, end: 0.96)
    .chain(CurveTween(curve: Curves.easeInCubic))
    .animate(secondaryAnimation),
  child: FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.4).animate(secondaryAnimation),
    child: child,
  ),
)
```

**Files affected:** Router config — `lib/core/routing/app_router.dart`

---

## 5. Motion — Staggered Delight

### Current state
- `flutter_animate` in `pubspec.yaml` but used ONLY in ProfilePage
- Reader page uses basic `AnimatedSlide` / `AnimatedContainer`
- No entrance animations elsewhere

### Recommendation

**Home page staggered entrance (already a `CustomScrollView` — perfect for this)**

```dart
// Each sliver section gets staggered delay
_buildHeaderSliver(...)
  .animate(delay: 0.ms)
  .fadeIn(duration: 400.ms);

_buildDailyQuote(...)
  .animate(delay: 150.ms)
  .fadeIn(duration: 400.ms)
  .slideY(begin: 8, end: 0, curve: Curves.easeOutCubic);

_buildHero(...)
  .animate(delay: 300.ms)
  .fadeIn(duration: 500.ms)
  .slideY(begin: 12, end: 0, curve: Curves.easeOutCubic);

_buildReadingTrend(...)
  .animate(delay: 450.ms)
  .fadeIn(duration: 400.ms);
```

**Bookshelf page**: Cards fade in with staggered delay based on grid index.

**Bottom navigation active state**: Scale transition `0.9 → 1.0` with spring curve when switching tabs.

**Reader settings panel**: Change from `Curves.easeOutCubic` to `Curves.easeOutBack` for a tactile "snap" feel on close.

**Reader toolbar auto-hide**: Currently linear opacity fade. Use `easeInOutSine` for a more organic feel.

**Files affected:** `lib/features/home/page/home_page.dart`, `lib/features/bookshelf/page/bookshelf_page.dart`, `lib/features/main_layout.dart`, `lib/features/reader/page/reader_page.dart`

---

## 6. Bookshelf Page — Card & Grid Refinements

### Current state
- Flat rectangular cover placeholders with book icon
- Tight grid gap
- Reading progress: not visually shown on cards
- Category chips: flat bordered

### Recommendation

**Book card design**

```dart
// Cover area with "book spine" visual instead of generic icon
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        theme.colorScheme.primary.withValues(alpha: 0.3),  // spine shade
        theme.colorScheme.primaryContainer,                 // cover face
      ],
      stops: const [0.08, 0.12],
    ),
  ),
  // ...
  // Progress ribbon at bottom
  if (progress > 0)
    Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 3,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    ),
)
```

**Grid spacing**

```diff
- crossAxisCount: 3 (phone)
+ crossAxisCount: 2 (phone — larger, more book-like cards)
```

Or keep 3 but increase `childAspectRatio` to `0.7` (taller, more book-like).

**Category chips**: Warm-filled active chip

```dart
// When selected
BoxDecoration(
  color: DesignTokens.warmAccent.withValues(alpha: 0.15),
  border: Border.all(color: DesignTokens.warmAccent, width: 0.5),
  borderRadius: BorderRadius.circular(20),
)
```

**Files affected:** `lib/features/bookshelf/page/widgets/bookshelf_book_content.dart`, `lib/features/bookshelf/page/widgets/bookshelf_category_chips.dart`

---

## 7. Color Palette — Fine-Tuning

### Current
| Token | Value | Comment |
|-------|-------|---------|
| Primary | `#F59E0B` | Amber — ✅ strong choice |
| Warm accent | `#D4A373` | Clay — ✅ good secondary |
| Error | `#D32F2F` | Material red — ❌ clinical |
| Success | `#2E7D32` | Material green — ❌ clinical |

### Recommendation

```diff
- static const Color error = Color(0xFFD32F2F);
+ static const Color error = Color(0xFFD1453B);     // warmer red

- static const Color success = Color(0xFF2E7D32);
+ static const Color success = Color(0xFF3B8B5E);   // muted green

- static const Color warmAccent = Color(0xFFD4A373);
+ // keep warmAccent as-is — good color

- static const Color primaryContainer = Color(0xFFFFF3E0);
+ static const Color primaryContainer = Color(0xFFFEF0D6);  // warmer amber tint

- static const Color onPrimaryContainer = Color(0xFF3E2723);
+ // keep — warm brown, reads well
```

### Color harmony principle
All accent colors should **tilt warm** — even the blues/greens used for semantic categories should shift slightly amber-ward rather than being pure sRGB primaries.

**Files affected:** `lib/core/theme/theme_constants.dart`

---

## 8. Reader Page — Ambiance

### Current state
- Background: solid color from `ReaderBgColors.presets[b.bgIndex]`
- Dark overlay: `RadialGradient` for brightness — good mechanic
- No texture, no atmosphere on the reading surface

### Recommendation

**Sepia/warm parchment default**

```dart
// In ReaderBgColors or reader_page.dart
// When reading Chinese literature, default to warm parchment:
static const List<Color> presets = [
  Color(0xFFF5E6C8),  // warm parchment (was #F8F6F0)
  Color(0xFFE8DFD0),  // aged paper
  Color(0xFFF0EDE4),  // cream
  // ...rest unchanged
];
```

**Text color for warm backgrounds**
When `bgIndex` selects a warm preset, text should be `#3D3026` (warm dark brown) instead of pure `#2C2C2C`.

```dart
// In ReaderThemeExtension or reader binding
Color get effectiveTextColor {
  if (isWarmBg) return const Color(0xFF3D3026);
  return textColor;
}
```

**Paper grain noise overlay** (optional, high-impact)

A 1% opacity noise PNG overlay over the reader content gives an unmistakable "paper" feel without distracting from reading. Applied only in light/warm modes:

```dart
if (b.readerTheme != ReaderTheme.dark) {
  IgnorePointer(
    child: Opacity(
      opacity: 0.015,
      child: Image.asset('assets/noise.png', repeat: ImageRepeat.repeat),
    ),
  );
}
```

**Files affected:** `lib/core/theme/reader_theme_extension.dart`, `lib/features/reader/page/widgets/reader_render_config.dart`, `lib/features/reader/page/reader_page.dart`

---

## 9. Main Layout — Bottom Navigation

### Current state
Standard M3 `NavigationBar` with Phosphor icons + `DesignTokens.primary` for active state.

### Recommendation
Replace with a custom bottom bar with **active underline indicator** that slides between tabs.

```dart
Container(
  decoration: BoxDecoration(
    color: surf,
    border: Border(top: BorderSide(color: dividerSubtle)),
  ),
  child: SafeArea(
    child: Row(
      children: BottomNavItem.values.map((item) {
        final isSelected = item.matchesRoute(currentRoute);
        return Expanded(
          child: GestureDetector(
            onTap: () => _onNavTap(item),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? item.activeIcon : item.icon,
                    size: 22,
                    color: isSelected ? DesignTokens.primary : textSec,
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.label(context),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? DesignTokens.primary : textSec,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  // Sliding underline
                  Container(
                    height: 2,
                    margin: EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? DesignTokens.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  ),
)
```

Alternative (simpler): Keep `NavigationBar` but add a custom `indicator` shape via `NavigationBarThemeData.indicatorShape` — a thin underline `_BottomNavIndicator` extends `ShapeBorder`.

**Files affected:** `lib/features/main_layout.dart`

---

## 10. Minor But High-Impact Refinements

| # | Change | Where | Impact |
|---|--------|-------|--------|
| 1 | **Quote card**: use LXGW WenKai for quote text | `home_page.dart` _buildDailyQuote | High |
| 2 | **Reading progress** bar on bookshelf cards | `bookshelf_book_content.dart` | High |
| 3 | **Skeleton shimmer** with warm tone | `skeleton_widget.dart` | Medium |
| 4 | **Settings panel** spring curve on close | `reader_page.dart` AnimatedSlide | Medium |
| 5 | **Page turn** haptic + mini-animation | `reader_page.dart` `onTapUp` | Medium |
| 6 | **Empty state** illustrations instead of text | All empty states | High |
| 7 | **Search bar** warm accent cursor + underline | `bookshelf_page.dart`, `reader_search_bar.dart` | Low |
| 8 | **NavRail** (desktop/tablet) active tab warm indicator | `adaptive_layout.dart` | Medium |
| 9 | **App icon/splash** coordination | `pubspec.yaml` flutter_launcher_icons | Branding |
| 10 | **Dictionary panel** warmer card styling | `reader_dictionary_panel.dart` | Low |

---

## Implementation Priority

### Phase 1 — Quick Wins (1 session)
1. Warm paper background tint (`theme_constants.dart`)
2. Noto Serif SC for reading body (`app_theme.dart`)
3. Staggered home page entrance (`home_page.dart`)
4. Quote card uses WenKai (`home_page.dart`)
5. Reading progress bar on bookshelf cards (`bookshelf_book_content.dart`)
6. Settings panel spring curve (`reader_page.dart`)

### Phase 2 — Atmospheric Depth (1 session)
7. Decorative warm wash behind home header (`home_page.dart`)
8. Card shadows enabled (`app_theme.dart`)
9. Bookshelf card visual refresh (`bookshelf_book_content.dart`)
10. Warm grain overlay on reader page (`reader_page.dart`)
11. Custom bottom nav underline (`main_layout.dart`)

### Phase 3 — Premium Polish (1 session)
12. Custom "open book" transition → reader (`app_router.dart`)
13. Sepia reader default + warm text (`reader_render_config.dart`)
14. Color fine-tuning (`theme_constants.dart`)
15. LXGW WenKai font asset + wiring (multiple files)
16. Category chip warm styling (`bookshelf_category_chips.dart`)

---

## Design Principles Summary

```
           Before                    After
           ──────                    ─────
Font       System sans               Serif reading + literary serif accent
Bg color   #FAFAFA (neutral)         #F5F0EB (warm paper)
Cards      #FFFFFF (white)           #FAF6F1 (warm card)
Shadows    explicit transparent       warm-tinted subtle depth
Hero       ±1 linear gradient card    bleeds into page atmosphere
Motion     minimal                    staggered entrance + tactile curves
Nav bar    M3 default                 custom underline indicator
Detail     flat icons                 book-like visual metaphors
```

The existing architecture (`DesignTokens`, `AppThemeExtension`, `ReaderThemeExtension`) already supports all of these changes — no structural refactoring needed, only value updates and targeted widget enhancements.

---

## 11. 待办事项 (2026-06-02 审查)

> ✅ = 已完成 | 🟡 = 部分完成/待评估 | ❌ = 未完成 | 🔴 = 已放弃

### 1. Typography

- ✅ `app_theme.dart` `_textTheme()` 注入 `fontFamily` — 已为 bodyLarge/bodyMedium/displayLarge/displayMedium/headlineLarge 等注入 `Noto Serif SC`
- ✅ Reader 正文 → `Noto Serif SC` — `reader_render_config.dart:37` `chineseFont = 'Noto Serif SC'`
- ✅ 引用 / 标题 → `LXGW WenKai` — `home_page.dart` 引用区和作者已注入 `fontFamily: 'LXGW WenKai'`
- 🔴 字体选择器暴露两种 — 已实现；Typography 设置使用 `fontRepo.availableFonts` 列出 built-in 字体
- 🔴 字体 Bold 变体注册 — `LXGWWenKai-Bold.ttf` / `NotoSerifSC-Bold.ttf` 不存在于 `assets/fonts/`

### 2. Surfaces — Warm Paper Palette

| `cardShadow` 暖色 0.08 | `#D4A373 @ 8% blur 8 y2` | `DesignTokens.cardShadow` | ✅ `theme_constants.dart` 已定义；`app_theme.dart` 已从透明 shadow 切换为 `DesignTokens.cardShadow` |
| `dividerSubtle` 暖色 12% | `#D4A373 @ 12%` | `DesignTokens.dividerSubtle` | ✅ `theme_constants.dart` 已定义；`app_theme.dart` 已替换中性灰为 `DesignTokens.dividerSubtle` |

### 3. Hero Gradient

- ✅ 复用至 `Profile` / `Bookshelf` — bookshelf_page.dart 和 profile_page.dart 已添加 warm wash
- ❌ Reader 页面 — 阅读器背景使用独立 ReaderBgColors 系统，不适用

### 4. Page Transitions

- ✅ 书架 → 阅读器 "open book" 自定义过渡 — `app_router.dart` 已改用 `CustomTransitionPage` + slide+fade
- ❌ 阅读器 → 书架 scale-down + fade

### 5. Motion

- ✅ Home staggered 入场 — `home_page.dart` 各 section 已添加 `.animate(delay:...).fadeIn(...)` 递增延迟
- ❌ Bookshelf 卡片 stagger — 待确认 flutter_animate 是否已使用
- ❌ 底部 nav 切换 spring — `main_layout.dart` 仍为标准 M3 `NavigationBar`

### 6. Bookshelf

- 🔴 "书脊"渐变封面 — 决定不实现（撤回改动）
- ✅ Category chips 暖色 active — `bookshelf_category_chips.dart` 已用 `DesignTokens.warmAccent`

### 7. Color Palette

| Token | 建议 | 实际 | 状态 |
|-------|------|------|------|
| `error` | `#D1453B` | `#D1453B` | ✅ |
| `success` | `#3B8B5E` | `#3B8B5E` | ✅ |
| `primaryContainer` | `#FEF0D6` | `#FEF0D6` | ✅ |

### 8. Reader Page Ambiance

（无未完成项）

### 9. Main Layout — Bottom Nav

- ❌ 自定义下划线 indicator — `main_layout.dart` 仍为标准 `NavigationBar`，未改为自定义 Row
- ✅ 侧栏 nav 暖色高亮 + 下划线 — `main_layout.dart` 已添加选中态下划线指示器

### 10. Minor Refinements

- ✅ 1. 引用 WenKai — `home_page.dart` `_buildDailyQuote` 已注入 `LXGW WenKai`
- ✅ 2. 进度条 — `bookshelf_book_content.dart` 已添加底部 progress bar
- ✅ 3. Skeleton 暖色 — `skeleton_widget.dart` 已使用 `DesignTokens.warmAccent` shimmer
- 🟡 4. Settings panel spring curve — 待评估
- 🟡 5. Page turn haptic — 待评估
- 🔴 6. Empty state 插画 — 需插画资源，非代码工作范畴
- ❌ 7. 搜索栏暖色 cursor — 未实现
- ❌ 8. NavRail 暖色 indicator — 同 §9
- ✅ 10. 字典面板暖色 — `reader_dictionary_panel.dart` handle 已用 warmAccent

### Phase 剩余项

| Phase | 编号 | 项 | 状态 |
|-------|------|----|------|
| 1 | 2 | Noto Serif SC 正文 | ✅ |
| 1 | 3 | Home 入场 stagger | ✅ |
| 1 | 4 | 引用 WenKai | ✅ |
| 2 | 7 | Home header 暖色 wash | ✅ |
| 2 | 8 | Card shadow | ✅ 已接入 |
| 2 | 9 | 书架卡片视觉刷新 | 🟡 |
| 2 | 11 | 自定义下划线 nav | ❌ |
| 3 | 12 | "open book" 过渡 | ✅ |
| 3 | 14 | 颜色微调（error/success/primaryContainer） | ✅ |
| 3 | 16 | Category chip 暖色 | ✅ |

### 最关键 4 项 (Phase 1 内)

1. ~~`_textTheme()` 注入 `Noto Serif SC` — 资源已就绪~~ ✅
2. ~~`ReaderRenderConfig.chineseFont` 切到 `Noto Serif SC`~~ ✅
3. ~~`home_page.dart` 引用区注入 `LXGW WenKai`~~ ✅

---

## 12. 放弃项

以下项经评估确定不实现：

| # | 项 | 原因 |
|---|-----|------|
| 1 | Paper grain noise overlay | 需 `assets/noise.png`，无设计师/素材来源；生成噪点纹理引入额外复杂度 |
| 2 | Empty state illustrations | 需插画资源，非代码工作范畴；可后续委托设计师 |
| 3 | 字体 Bold 变体注册 | `LXGWWenKai-Bold.ttf` / `NotoSerifSC-Bold.ttf` 不存在于 `assets/fonts/` |
| 4 | 书架书脊渐变封面 | 决定不实现（已撤回改动） |