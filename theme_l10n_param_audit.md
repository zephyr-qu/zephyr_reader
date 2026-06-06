# Theme / l10n / colorScheme 参数审计

Flutter 的 `Theme.of(context)`、`AppLocalizations.of(context)`、`Theme.of(context).colorScheme` 都是 InheritedWidget 查询，任何 Widget 都可以自行读取。**父组件传参是多余的**——它增加了构造函数参数、调用方样板代码，却不改变任何行为。

## 规则

- Widget 内部直接调用 `Theme.of(context)`、`AppLocalizations.of(context)!`、`colorScheme` 即可
- 只有**非 Widget 上下文**（extension 方法、纯工具函数）才需要传参

---

## 一、有问题的公开 Widget 构造参数

### 1. Vocab 系列（4 个 Widget）

| 文件 | 多余参数 |
|------|---------|
| `lib/features/vocabulary/page/widgets/vocab_list_item_tile.dart` | `theme`、`l10n` |
| `lib/features/vocabulary/page/widgets/vocab_stats_row.dart` | `theme`、`l10n` |
| `lib/features/vocabulary/page/widgets/vocab_status_chip.dart` | `theme`、`l10n` |
| `lib/features/vocabulary/page/widgets/vocab_word_list_view.dart` | `theme`、`l10n` |

**调用方**：`vocabulary_page.dart`、`vocab_word_list_view.dart`（内部创建 `VocabListItemTile`）

### 2. Core Presentation 系列（5 个 Widget）

| 文件 | 多余参数 |
|------|---------|
| `lib/core/presentation/widgets/empty_state_widget.dart` | `colorScheme` |
| `lib/core/presentation/widgets/selection_chip.dart` | `colorScheme` |
| `lib/core/presentation/widgets/settings/section_label.dart` | `colorScheme` |
| `lib/core/presentation/widgets/settings/settings_card.dart` | `colorScheme` |
| `lib/core/presentation/widgets/settings/settings_slider_tile.dart` | `colorScheme` |

**调用方**：散布在 10+ 个页面

### 3. Learning Notes 系列（2 个 Widget）

| 文件 | 多余参数 |
|------|---------|
| `lib/features/learning_notes/page/widgets/note_item_card.dart` | `colorScheme` |
| `lib/features/learning_notes/page/widgets/stat_dashboard_widget.dart` | `colorScheme` |

### 4. 其他

| 文件 | 多余参数 |
|------|---------|
| `lib/features/profile/page/about_page.dart` — `_LinksSection` | `l10n` |

---

## 二、私有 `_buildXxx` 方法传参（数值众多，影响较小）

这些是页面内部方法互相传递 theme/l10n，不是公开 API。虽然多余，但重构收益低于公开 Widget。代表性文件：

| 文件 | 模式 |
|------|------|
| `reading_sessions_page.dart` | 6 个 `_build*` 方法都传 `l10n` + `theme` |
| `book_detail_info_section.dart` | `_infoRow(theme, key, value)` |
| `book_detail_note_stats.dart` | `_noteStatCard(theme, count, label, color)` |
| `book_detail_progress_card.dart` | `_statItem(theme, value, label)` |
| `cache_manage_page.dart` | 4 个 `_build*` 方法传 `theme` |
| `book_search_page.dart` | `_buildBody(theme, l10n, ...)` |
| `search_page.dart` | 2 个 `_build*` 方法传 `theme` |
| `theme_brightness_page.dart` | `_*` 传 `l10n` |
| `chapter_list_widget.dart` | `_*` 传 `l10n` |
| `reader_settings_panel.dart` | 5 个 `_build*` 方法传 `l10n` |
| `storage_sync_page.dart` | `_*` 传 `l10n` |

---

## 三、正确的用法（不需要改）

Extension 方法、纯函数——它们没有 `context`，必须传参：

- `ReaderThemeX.l10nLabel(AppLocalizations l10n)`
- `ReaderFontSizeX.l10nLabel(AppLocalizations l10n)`
- `TapLayoutX.l10nLabel(AppLocalizations l10n)`
- `ThemeTimePresetX.l10nLabel(AppLocalizations l10n)`
- `AppThemeTypeX.l10nLabel(AppLocalizations l10n)`
- `BookshelfSortTypeX.l10nLabel(AppLocalizations l10n)`
- `formatRelativeTime(DateTime, AppLocalizations)`
- `_backupSubtitle(DateTime?, AppLocalizations)`
- `vocabStatusColor(VocabStatus, ThemeData)` — 纯函数，无 context

---

## 四、优先级建议

| 优先级 | 范围 | 估算改动量 |
|--------|------|-----------|
| **P0** | Vocab 系列 4 个 Widget（刚改过 + 调用方集中） | ~8 个文件 |
| **P1** | Core Presentation 5 个 Widget（调用方多，但每个改动小） | ~15 个文件 |
| **P2** | Learning Notes 2 个 Widget | ~4 个文件 |
| **P3** | `_LinksSection` + 私有 `_buildXxx` 方法（收益低，代码多） | 20+ 文件 |

**建议只改 P0-P2（公开 Widget 构造参数），私有方法暂不动。**
