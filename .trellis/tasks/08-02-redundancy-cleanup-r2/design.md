# 设计：冗余清理 R2

## 删除边界与联动矩阵

### A. 死文件（3）

| 删除 | 联动 |
| --- | --- |
| `go_reading_empty_state.dart` | 无 |
| `selection_chip.dart` | 无 |
| `theme_extension.dart` | app_theme.dart `extensions: [AppThemeExtension(...)]` 块（~L290-299）必须一并删除，否则编译错 |

A3 注意：app_theme.dart L42 注释提到 AppThemeExtension 可保留（注释非代码）。删除 extensions 块后确认无 `AppThemeExtension` 标识符残留。

### B. 依赖（15）

删除后 `flutter pub get` 重新解析。风险：间接依赖被传递引用（如 dio 依赖 json_annotation？需确认——`json_annotation` 是 dio 的可选/传递依赖吗）。**步骤**：逐依赖 grep 符号确认零引用后再删；删除后 pub get + analyze 验证，若某个删除导致传递依赖断裂，恢复该条。

### C1. l10n 死键（248）

**方法**：Python 脚本（UTF-8 显式编码）：

1. 读 `lib/l10n/app_en.arb` 全部 key
2. 对每个 key 在 lib/（排除 lib/l10n/ 与 lib/src/rust/ 生成区）做 `\bkey\b` 正则计数
3. 零计数 → 待删
4. **二次确认**：对候选死键 grep `"key"` 字符串字面量用法（防止通过字符串索引访问，如 `AppLocalizations.of(context)` 动态 getter 场景不存在，但防止 `l10n.toJson()['key']` 类）——本项目无此模式，跑一遍确认
5. 从 app_en.arb + app_zh.arb 删除（两文件 key 集合同步，zh 可能缺 key——以 en 为基准）
6. `flutter gen-l10n` 重新生成

**预期遗漏风险**：报告统计 248 是基于当时快照；以脚本实测为准（可能更多或更少）。

### C2. SettingsKeys（2）

`dictMddPath`/`currentFont` 行删除，无联动（确认过零引用）。

### D1. 翻译链

| 删除 | 联动 |
| --- | --- |
| `dictionary_config.dart` / `dictionary_module.dart` / `dictionary_service.dart` / `providers/*.dart` | service_locator.config.dart 的 import + 3 处注册（DictionaryConfig singleton、dictionaryService lazySingleton、_DictionaryModule 生成类） |
| translation.* 8 个 SettingsKeys | settings_keys.dart 删除 |
| 翻译簇 l10n key | 并入 C1 死键清理（翻译键零引用后自动覆盖） |

**保留**：dictionary_settings_page.dart（活跃，走 Rust dict_api）、DictionarySettingsViewModel、dio。

**风险**：service_locator.config.dart 是 injectable 生成物，应通过删除源文件上的 `@module`/`@singleton` 注解 + 重新 build_runner 生成，而非手改生成文件。需确认 dictionary_module.dart 是否带 `@module` 注解——是则删源后 `dart run build_runner build --delete-conflicting-outputs` 重新生成 DI。**这是关键决策点**。

### D2. WiFi 传书

| 删除 | 联动 |
| --- | --- |
| `wifi_transfer_service.dart` / `wifi_transfer_page.dart` | bookshelf_page.dart 菜单 PopupMenuItem('wifi') 块 + switch case 'wifi'（注意 case 'wifi' 内还调了 `_showSettingsSheet`——删除时保留该调用，仅删 context.push 行） |
| `wifi_upload_page.html` | pubspec `assets/html/` 声明（html 目录将空） |
| AppRoute.wifiTransfer | route_constants.dart 枚举项 + app_router.dart import + route 注册 |
| SettingsKeys.wifiTransferPort | settings_keys.dart 删除 |
| 12 个 wifi l10n key | 并入 C1 |

**注意**：bookshelf_page 的 case 'wifi' 后没有 break（Dart switch 隐式 break），但 `_showSettingsSheet(context, vm)` 在 push 之后调用——检查 switch 语法（Dart 3 switch statement 无需 break，case 体独立）。

### D3. wordlist

4 个 JSON 文件删除，无联动（pubspec 未声明，零加载代码）。

## 执行顺序（依赖关系）

1. **A**（死文件，独立）→ analyze 验证
2. **D1**（翻译链，需 build_runner 重新生成 DI）→ 先做，因为会改动 service_locator.config.dart
3. **D2**（WiFi，路由/页面/DI/资产）→ 再做
4. **C2**（SettingsKeys）→ 顺手
5. **B**（依赖）→ pubspec 修改 + pub get + analyze
6. **C1**（l10n 死键，最后——依赖 D1/D2 删除后再统计，避免重复劳动）→ 脚本 + gen-l10n
7. 全量门禁：analyze / test / clippy / cargo test

## 回滚策略

- 每步独立 commit，单步失败可单独 revert（不用 git revert 破坏性命令，用增量修复）
- D1 若 build_runner 重新生成后出现意外依赖断裂 → 恢复翻译链源文件，改用人工编辑 DI 配置（保留生成文件手改是下策，但比破坏 build 好）
- C1 脚本误删活跃 key → 从 git 恢复 ARB（git checkout 单文件不违规，非丢弃未提交更改——ARB 修改已提交在独立 commit 中）
