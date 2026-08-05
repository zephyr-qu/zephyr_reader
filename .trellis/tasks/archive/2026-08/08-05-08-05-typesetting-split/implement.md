# 实施计划：排版设置分工（阅读页精简 + 设置页补齐）

## Step 1 — 阅读页排版面板精简

文件：`lib/features/reader/settings/typesetting_panel.dart`

- `build()` 的 Column 中删除三个 sliderTile：`l10n.letterSpacing`、`l10n.paragraphSpacing`、`l10n.paragraphIndent`
- 保留：fontSize、pageMargin、lineHeight、文本对齐平铺选择器、阅读模式选择器
- 检查删除后是否残留未使用 import（`ReaderTypographyDefaults` 仍被 minPadding/maxPadding 等使用，应保留）

## Step 2 — 设置页补齐完整排版项

文件：`lib/features/profile/page/typography/typography_settings_page.dart`

- `_buildTypographySection` 现有三个 SettingsSliderTile（fontSize/fontWeight/pageMargin）之后，追加：
  - lineHeight（min 1.0, max 2.0, step 0.1，显示 'x' 后缀，参考阅读页 divisions 10）
  - letterSpacing（min/max 参考 ReaderTypographyDefaults，step 0.05，'em' 后缀）
  - paragraphSpacing（min 0, max 参考 defaults，'em' 后缀）
  - paragraphIndent（min 0, max 参考 defaults，'em' 后缀）
  - textAlign 平铺选择器（复用阅读页三选项：跟随原书/左对齐/两端对齐，图标 textAa/textAlignLeft/textAlignJustify）
- 注意 settings 页用 `SettingsSliderTile`（core/presentation/widgets/settings/），阅读页用 `sliderTile`（reader settings_widgets）——保持各自页面既有控件风格
- textAlign 平铺控件：设置页没有 `readerTheme`（用的是 colorScheme），需要适配设置页样式（参考 `_buildReadingModeSection` 的 colorScheme 风格），或引入与阅读页一致的实现

## Step 3 — 测试

- `test/features/reader/settings/typesetting_panel_test.dart`：字间距/段间距/首行缩进相关断言删除或改为 findsNothing（若存在）
- `test/features/profile/page/typography_settings_page_test.dart`：若存在，补充新项断言；若无则评估是否需要新建
- 确认阅读页 display_panel 相关测试不回归

## Step 4 — 验证

1. `dart analyze --fatal-infos` 0 issue
2. `flutter test` 全绿
3. 手动/真机：阅读页排版面板只有常用项；设置页含全部排版项

## 质量门禁

- `dart analyze --fatal-infos` 0
- `flutter test` 全绿
- 无越界改动（只动 typesetting_panel.dart、typography_settings_page.dart 及对应测试）
