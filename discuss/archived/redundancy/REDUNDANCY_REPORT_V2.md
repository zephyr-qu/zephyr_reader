# 冗余代码审查报告 V2（重构后复查）

> 生成日期：2026-08（session: pi）
> 分支：`feature/mvp-readium-only` · 基准：V1 报告（`REDUNDANCY_REPORT.md`，基线 c1932bfb，2026-08-02）
> 状态：**仅报告，未删除任何文件**。删除动作由用户裁决后执行。
> 方法：dart analyze（全绿）+ import 引用图脚本 + 符号级 grep 交叉验证 + SettingsKeys/ARB key 使用率统计 + pubspec 依赖引用核对 + 旧报告项执行状态追踪。

---

## 统计一览

| 类别 | 条目 | 估算规模 |
| ---- | ---- | -------- |
| A. 死代码/未使用文件 | 3 文件 | ~300 行 |
| B. 未使用的 pub 依赖 | 10 个 runtime + 5 个 dev | pubspec + lock |
| C. 重复/遗留键 | 248 个 l10n key + 2 个 SettingsKeys | ~40% ARB |
| D. 废弃封装层/死链 | 翻译适配器链路 + WiFi 传书子系统 | ~900 行 + 资产 |

**旧报告执行状态**：A/B/C 类（12 FRB API + 11 仓储函数 + anyhow）✅ 已删；E5 生词本 ✅ 已删；E1 全文搜索 ✅ 已删。**未执行**：WiFi 传书子系统（REPORT 旧 E 区）、wordlist JSON 死资产（旧 F 区）、D 类 8+1 个未用依赖。

---

## A. 死代码 / 未使用文件

| # | 文件 | 证据 | 建议 |
| -- | ---- | ---- | ---- |
| A1 | `lib/core/presentation/widgets/go_reading_empty_state.dart` | import 引用图：lib/test/integration_test 全零引用；无 `part of` | 删除 |
| A2 | `lib/core/presentation/widgets/selection_chip.dart` | 同上，全零引用 | 删除 |
| A3 | `lib/core/theme/theme_extension.dart`（`AppThemeExtension`） | 全仓库零消费（reader 侧用的是 `reader_theme_extension.dart` 的 `ReaderThemeExtension`，活跃） | 删除 |

> 注：第一轮 import 扫描因 `package:` 前缀解析 bug 曾误报 ~150 文件，修复后仅剩上述 3 个。`lib/src/rust/` 生成区（11 个 freezed 文件 + frb_generated.web.dart 等）均被引用，无死文件。

---

## B. 未使用的 pub 依赖（全仓库零 import + 符号零引用）

### runtime（10 个）

| # | 依赖 | 证据 |
| -- | ---- | ---- |
| B1 | `flutter_tts` | TTS 已由 Readium（flureadium）接管（e2d82a7c）；零 import，符号 `FlutterTts` 零引用 |
| B2 | `audioplayers` | 同上，零 import/符号 |
| B3 | `line_icons` | 图标已迁移到 `phosphoricons_flutter`；零 import/符号 |
| B4 | `battery_plus` | 零 import；`showBattery` 仅存于 l10n（见 C 类死键） |
| B5 | `json_annotation` | 模型全走 freezed（`freezed_annotation`）；全仓库零 import |
| B6 | `uuid` | ID 生成全在 Rust 侧；零 import |
| B7 | `flutter_widget_from_html_core` | 词典 HTML 渲染未接线；零 import |
| B8 | `flutter_svg` | **V2 新增**（V1 未列）；零 import/符号 |
| B9 | `async` | **V2 新增**；零 import/符号 |
| B10 | `shimmer` | 骨架屏用 flutter_animate；零 import |

### dev（5 个）

| # | 依赖 | 证据 |
| -- | ---- | ---- |
| B11 | `ffigen` | 无 ffigen 配置、无 C 互操作（frb_generated 头部注释是 FRB 生成物） |
| B12 | `flutter_driver` | 零 import（integration_test 用 flutter_test 即可） |
| B13 | `flutter_launcher_icons` | 声明但无 `flutter_launcher_icons.yaml` 配置 |
| B14 | `dart_mcp` | 声明但无使用/配置 |
| B15 | `test` | 测试全走 `flutter_test`；`package:test/test` 零引用 |

> 保留项（核实过活跃）：`freezed`/`freezed_annotation`/`json_serializable`/`build_runner`/`injectable`/`injectable_generator`（DI codegen）、`mocktail`（测试）、`dio`、`webdav_client`（WebDAV 链路活）、`fl_chart`、`flutter_animate`、`file_picker`、`url_launcher`、`package_info_plus`、`phosphoricons_flutter`、`flureadium`、`intl`、`logger`、`go_router`、`signals_*`、`flutter_hooks`、`get_it`、`flutter_secure_storage`、`path_provider`、`path`、`shared_preferences`、`flutter_rust_bridge`、`rust_lib_zephyr_reader`。

---

## C. 重复 / 遗留键

### C1. l10n 死键 — 248 / 604（41%）

对 `app_en.arb` 全量 key 在 lib/（排除 l10n 目录）做 `\bkey\b` 引用统计，248 个 key 零引用。主要簇：

- **翻译 API 簇**（20+）：`translationApi*` `translationTest*` `translationRetry` `translationManualPaste` `pasteTranslation*` `translating` `translationFailed` 等 —— 对应 D1 翻译适配器死链
- **笔记/高亮/书签管理簇**（30+）：`addNote` `editNote` `notesAndHighlights` `highlightBlue/Green/Pink/Purple/Yellow` `saveHighlightFailed` `bookmarkManage` `clearAllBookmarks` 等 —— 对应已删的 notes/annotations 系统
- **生词本簇**（15+）：`statusLearning` `statusMastered` `statusUnlearned` `wordListCet4/Cet6/Ielts/Toefl` `newWord` `known` `confirmDeleteWord` 等 —— 对应 E5 已删
- **全文搜索簇**（15+）：`noResults` `resultSummary` `searchMode*` `wordSegmentation` `fromBook` 等 —— 对应 E1 已删
- **旧排版参数簇**（25+）：`autoSpaceRatio` `baselineAlign` `firstLineIndent` `punctuationSqueeze` `cjkOptimization` `enableHyphenation` `typesetLanguage*` `readerFontSizeSmall/Medium/Large/XLarge` `advancedTypography` 等 —— 对应 3be5b7ec 剪掉的 Readium-unsupported 字段
- **TTS 旧簇**（部分）：`ttsEngine` `ttsChineseVoice` `ttsEnglishVoice` `ttsAutoRefresh` 等
- **统计/主页旧簇**（部分）：`annualReport` `readingFootprint` `consecutiveDays` `weekday*` `weeklyOverview` `readingRhythm` 等

### C2. SettingsKeys 死键 — 2 个

| key | 证据 |
| --- | ---- |
| `dictMddPath` | 全仓库零引用（词典 mdd 资源未接线） |
| `currentFont` | 全仓库零引用（自定义字体功能未接线） |

> 其余 44 个 key 均有 1+ 引用（含仅被死链 DictionaryConfig 消费的 translation.* 8 个，随 D1 一并处置）。

### C3. 无重复实现的类名冲突

全库顶层 class/mixin/enum 名无跨文件重复（排除 FRB 生成区 io/web 平台双文件，属 FRB 正常结构）。`time_formatters.dart` / `format_utils.dart` 职责分明，无重叠。

---

## D. 废弃封装层 / 死链

### D1. 翻译适配器链路 — 整链零调用（死链）

```
DictionaryConfig (lib/features/dictionary/dictionary_config.dart, 8 persisted signals)
  → DictionaryModule.dictionaryService (dictionary_module.dart)
  → CustomDictionaryTranslator (providers/custom_dictionary.dart)
  → OpenAIDictionaryTranslator (providers/openai_dictionary.dart)
```

- `DictionaryConfig` 仅被 DI 注册 + module 引用；`dictionaryService()` 及两个 Translator **全仓库无调用方**。
- 真正活跃的词典功能走 **Rust `dict_api`（mdict）**：`dictionary_settings_page.dart` → `DictionarySettingsViewModel` → `src/rust/api/dictionary.dart`（lookup/suggest 已由 E4 裁决保留）。
- 连带：`DictionaryModule` 整个模块 + `translation.*` 8 个 SettingsKeys + C1 翻译簇 l10n key。

**决策项**：翻译 API 功能（provider/apiUrl/apiKey/model）是否有产品计划？若短期无，整链可删（约 150 行 + 8 key + 20 l10n key）；若保留待接线，则标记为"待接入"而非死代码。

### D2. WiFi 传书子系统 — 空壳（V1 旧 E 区，未执行）

| 项 | 证据 |
| --- | ---- |
| `lib/core/network/wifi_transfer_service.dart`（267 行） | `start()` 空实现；`ignore_for_file: unused_*`；HTTP 服务永不启动 |
| `lib/features/bookshelf/page/wifi_transfer_page.dart`（332 行） | 调用空壳服务；路由 `AppRoute.wifiTransfer` 仍注册 |
| `assets/html/wifi_upload_page.html`（4.1K） | 从未被加载（`_htmlContent=''`）；pubspec `assets/html/` 声明只为此文件 |
| `SettingsKeys.wifiTransferPort` | 仅空壳服务引用 |
| DI 注册 | `service_locator.config.dart` 注册 WifiTransferService |

删除需联动：路由 + 页面 + 服务 + DI 注册 + 资产 + pubspec assets 声明 + settings key（V1 已列全）。若未来恢复 WiFi 传书，建议在功能真实实现前不保留空壳（V1 结论不变）。

### D3. 死资产 — wordlist JSON（V1 旧 F 区，未执行）

`assets/wordlists/cet4.json` / `cet6.json` / `ielts.json` / `toefl.json`（约 60KB，git 已跟踪）零加载代码。若生词本功能（E5 已删）不再回归，整目录删除；注意 V2 确认 pubspec 未声明该目录（仅 dictionary.mdx、html/、fonts/）。

---

## 已核实为健康的部分（V2 排除项）

- **Rust API 面**：book/backup/bookmark/category/cover/dictionary/engine_position/progress/session/stats 全部有活跃调用方（V1 的 A 类 12 个零调用 API 已删）。
- **Rust parser/epub**：导入元数据 + 封面提取活跃（V1 结论不变）。
- **阅读器设置面板**：`ReaderSettingsOverlay` 三面板（typesetting/display/assist）全部被 `readium_reader_shell` 消费；`settings_widgets.dart` 被三面板共享，是正常复用非冗余。
- **主题系统**：`reader_theme_extension.dart`（9 个消费方）活跃；`menu_colors` / `theme_constants` 职责分明。
- **WebDAV 链路**：`webdav_config_service` / `webdav_sync_service` → `data_management_view_model` → `data_management_page` 活跃。
- **词典 mdict 链路**：设置页 ↔ Rust dict_api 活跃（区别于 D1 翻译适配器死链）。
- **TTS**：`tts_settings_page` 有路由；设置被 `readium_reader_shell` 消费（Readium TTS）。
- **统计/主页 widget**：statistics 两页有路由；home 7 个 widget 各自被 home_page 引用。
- `dart analyze --fatal-infos`：No issues found。

---

## 建议执行顺序（供用户裁决）

1. **A 类**（3 死文件，~300 行）→ 直接删，无联动。
2. **B 类**（15 依赖）→ pubspec 删除 + `flutter pub get`；B8/B9 为 V2 新增，优先。D1 若裁决删除，翻译相关依赖一并确认（dio 保留）。
3. **C1 l10n 死键** → 需谨慎：部分 key（如 `appName` 类）虽当前零引用，但删除前需确认无「通过字符串索引访问」的用法；建议用 `dart run intl` 生成前验证 `AppLocalizations` getter 集合。删除时同步 `app_localizations*.dart` 生成物（重新 `flutter gen-l10n`）。
4. **C2 SettingsKeys** 2 死键 → 随 D1 决策一并处理。
5. **D2 WiFi 传书** → 用户决策：整删（联动 5 处）或恢复实现。
6. **D3 wordlist JSON** → 随生词本功能裁决（大概率删除）。

每步门禁：`dart analyze --fatal-infos` → `flutter gen-l10n`（若动 ARB）→ `flutter test`。

## 约束遵守

- 仅报告，未改动任何生产代码。
- 未触碰 FRB 生成区（`frb_generated.*` / `lib/src/rust/`）。
- 未执行任何 git 破坏性命令。
- 待确认项（D1 翻译链路的产品意图）已在文中标注，未臆断删除。
