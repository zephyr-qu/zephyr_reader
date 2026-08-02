# 实施：冗余清理 R2

## 检查点（每步门禁）

所有步骤完成后运行：

- `dart analyze --fatal-infos` → 0
- `flutter test` → 全绿
- `cargo clippy -D warnings` → 0
- `cargo test` → 全绿

## 步骤

### 1. A 类死文件

- [ ] 删除 `lib/core/presentation/widgets/go_reading_empty_state.dart`
- [ ] 删除 `lib/core/presentation/widgets/selection_chip.dart`
- [ ] 删除 `lib/core/theme/theme_extension.dart` + app_theme.dart 的 `extensions: [AppThemeExtension(...)]` 块
- [ ] 门禁：`dart analyze --fatal-infos`
- [ ] commit

### 2. D1 翻译链（先做，因涉及 DI 重新生成）

- [ ] 检查 dictionary_module.dart 是否有 `@module` 注解（决定 DI 重新生成方式）
- [ ] 删除 5 个文件：dictionary_config / dictionary_module / dictionary_service / providers/custom_dictionary / providers/openai_dictionary
- [ ] 若 @module：`dart run build_runner build --delete-conflicting-outputs` 重新生成 service_locator.config.dart
- [ ] 若无 @module：手工删除 service_locator.config.dart 中对应 import + 注册块
- [ ] 删除 translation.* 8 个 SettingsKeys（settings_keys.dart）
- [ ] 确认 dictionary_settings_page.dart 仍编译（不依赖被删文件）
- [ ] 门禁：`dart analyze --fatal-infos` + `flutter test`（测试若引用 DictionaryConfig 需检查——先 grep 确认零测试引用，已确认）
- [ ] commit

### 3. D2 WiFi 传书

- [ ] 删除 `lib/core/network/wifi_transfer_service.dart` + `lib/features/bookshelf/page/wifi_transfer_page.dart`
- [ ] route_constants.dart 删 `wifiTransfer('/wifi-transfer')`
- [ ] app_router.dart 删 import + route 注册块
- [ ] bookshelf_page.dart 删 menu PopupMenuItem('wifi') 块 + switch case 'wifi'（保留 `_showSettingsSheet` 调用逻辑——确认 case 结构）
- [ ] service_locator.config.dart 删 WifiTransferService import + 注册（若 injectable 生成，检查源文件注解方式）
- [ ] settings_keys.dart 删 `wifiTransferPort`
- [ ] 删 `assets/html/wifi_upload_page.html` + pubspec `assets/html/` 声明
- [ ] 12 个 wifi l10n key 并入 C1 步骤统一删（不在本步删，避免两脚本并发）
- [ ] 门禁：`dart analyze --fatal-infos` + `flutter test`
- [ ] commit

### 4. C2 SettingsKeys

- [ ] settings_keys.dart 删 `dictMddPath` + `currentFont`
- [ ] 门禁：`dart analyze --fatal-infos`
- [ ] commit（或并入步骤 2/3 commit）

### 5. B 类依赖

- [ ] pubspec.yaml 删 runtime 10 个：flutter_tts / audioplayers / line_icons / battery_plus / json_annotation / uuid / flutter_widget_from_html_core / flutter_svg / async / shimmer
- [ ] pubspec.yaml 删 dev 5 个：ffigen / flutter_driver / flutter_launcher_icons / dart_mcp / test
- [ ] `flutter pub get`
- [ ] 门禁：`dart analyze --fatal-infos` + `flutter test`（若某依赖被间接传递引用导致断裂，恢复该条并记录）
- [ ] commit

### 6. C1 l10n 死键（最后——D1/D2 已删，统计最准）

- [ ] 写 Python 脚本（UTF-8 显式）统计 lib/（排除 lib/l10n/ 与 lib/src/rust/）零引用 key
- [ ] 二次确认字符串字面量访问（`["key"]` 模式）
- [ ] app_en.arb + app_zh.arb 删除死键
- [ ] `flutter gen-l10n` 重新生成
- [ ] 门禁：`dart analyze --fatal-infos` + `flutter test`
- [ ] commit

### 7. D3 wordlist

- [ ] 删除 `assets/wordlists/` 4 个 JSON
- [ ] 确认 pubspec 未声明 wordlists（已确认）
- [ ] commit（可并入步骤 6）

### 8. 全量验证

- [ ] `dart analyze --fatal-infos` 0
- [ ] `flutter test` 全绿
- [ ] `cargo clippy -D warnings` 0
- [ ] `cargo test` 全绿
- [ ] `git status` 确认只删不增
- [ ] 更新 journal + ROADMAP（如适用）

## 风险与回退

| 风险 | 对策 |
| --- | --- |
| build_runner 重新生成 DI 破坏其他注册 | 备份 service_locator.config.dart 前先 `dart run build_runner build`；失败则恢复翻译链源 + 手改生成文件 |
| l10n 脚本误删活跃 key | 先跑 dry-run 打印待删清单人工核对；删除前 git 状态已 clean，可从 HEAD 恢复 ARB |
| 依赖删除引发传递断裂 | 逐条删除而非整批；断裂即恢复该条并记录原因 |
| dart_mcp 被 .mcp.json 或工具引用 | 检查 `.mcp.json` 与配置引用后再删 |
