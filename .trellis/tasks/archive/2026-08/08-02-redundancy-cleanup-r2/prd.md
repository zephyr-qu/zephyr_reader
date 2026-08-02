# 冗余清理 R2：死文件/依赖/l10n 键/死链整肃

## 背景

REDUNDANCY_REPORT_V2.md（2026-08 生成，基准 c1932bfb）列出 A/B/C/D 四类冗余，报告生成后仅 Rust 侧大清扫（f5cef45c，-13,696 行）完成，Flutter 侧清理项全部未执行。用户确认本轮执行全部清理项，并对 D1/D2 做出删除裁决。

## 范围（用户已裁决）

### A. 死文件删除（3 个，~300 行）

- `lib/core/presentation/widgets/go_reading_empty_state.dart` — 零引用
- `lib/core/presentation/widgets/selection_chip.dart` — 零引用
- `lib/core/theme/theme_extension.dart`（AppThemeExtension）— 仅 app_theme.dart 构造注入，无 `extension<AppThemeExtension>` 消费方；需联动删除 app_theme.dart 的 extensions 块

### B. 未使用 pub 依赖删除（15 个）

- runtime（10）：flutter_tts / audioplayers / line_icons / battery_plus / json_annotation / uuid / flutter_widget_from_html_core / flutter_svg / async / shimmer
- dev（5）：ffigen / flutter_driver / flutter_launcher_icons / dart_mcp / test
- 保留：freezed 家族 / injectable 家族 / build_runner / mocktail / dio / webdav_client / fl_chart / flutter_animate / file_picker / url_launcher / package_info_plus / phosphoricons_flutter / flureadium / intl / logger / go_router / signals_* / flutter_hooks / get_it / flutter_secure_storage / path_provider / path / shared_preferences / flutter_rust_bridge / rust_lib

### C1. l10n 死键（248 个，占 ARB 41%）

- 全量核对 lib/（排除 l10n）`\bkey\b` 零引用的 key 删除
- 含翻译 API 簇、笔记/书签簇、生词本簇、搜索簇、旧排版簇、TTS 旧簇、统计旧簇、WiFi 簇（12 个）
- 删除后重新 `flutter gen-l10n`

### C2. SettingsKeys 死键（2 个）

- `dictMddPath` / `currentFont` — 零引用

### D1. 翻译适配器链路整删（用户裁决：删除）

- `lib/features/dictionary/dictionary_config.dart`（8 persisted signals）
- `lib/features/dictionary/dictionary_module.dart`
- `lib/features/dictionary/dictionary_service.dart`
- `lib/features/dictionary/providers/custom_dictionary.dart` + `openai_dictionary.dart`
- 联动：DI 注册（service_locator.config.dart 3 处）+ translation.* 8 个 SettingsKeys + C1 翻译簇 l10n key
- 保留：dictionary_settings_page.dart / DictionarySettingsViewModel / Rust dict_api（活跃 mdict 链路）
- 保留：dio（WebDAV 活跃）

### D2. WiFi 传书子系统整删（用户裁决：删除）

- `lib/core/network/wifi_transfer_service.dart`（267 行空壳）
- `lib/features/bookshelf/page/wifi_transfer_page.dart`（332 行）
- `assets/html/wifi_upload_page.html`（4.1K，唯一 html 资产）
- 联动 5 处：AppRoute.wifiTransfer（route_constants + app_router）、bookshelf_page wifi 菜单项 + case、DI 注册、SettingsKeys.wifiTransferPort、pubspec `assets/html/` 声明、12 个 wifi l10n key

### D3. wordlist 死资产

- `assets/wordlists/cet4.json / cet6.json / ielts.json / toefl.json`（60KB）— 零加载代码，pubspec 未声明

## 接受标准

1. `dart analyze --fatal-infos`：0 issue
2. `flutter gen-l10n`：成功，生成物与 ARB 一致
3. `flutter test`：全绿（基线 22）
4. `cargo clippy -D warnings` + `cargo test`：不回归（Flutter 侧清理不应触碰 Rust；跑一次确认）
5. `flutter pub get`：成功，pubspec.lock 同步
6. 无测试因"删依赖/删文件"而修改生产逻辑来凑数——测试若断裂只记录，不改生产代码
7. `flutter analyze` 无未使用 import 残留（app_theme.dart extensions 块删除后无 orphan）

## 非目标（不做）

- 不触碰 FRB 生成区（frb_generated.* / lib/src/rust/）
- 不执行任何 git 破坏性命令
- 不删活跃 mdict 词典链路 / WebDAV / 统计页 / 主题系统
- D1 翻译链路如删除后发现隐藏消费方 → 停止并回退该子项，不强行推进
