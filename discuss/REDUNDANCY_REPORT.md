# 冗余代码与文件扫描报告

> 生成日期：2026-08-02（session: pi）
> 分支：`feature/mvp-readium-only` · commit 基准：`c1932bfb`
> 扫描方法：全仓库静态扫描（Rust 模块 ↔ FRB 生成文件对照、Dart import 图、pubspec 依赖引用、git 历史、文档交叉引用、ADR/ROADMAP 对齐）
> 状态：**仅报告，未删除任何文件**。删除动作请走 R14 任务（清理 PoC 与重复代码），由用户确认后执行。

> 🔍 **Rust 专项深挖**：单引擎（Readium）决策下的 Rust 死代码全景见 [REDUNDANCY_REPORT_RUST.md](./REDUNDANCY_REPORT_RUST.md)（约 4,200+ 行死代码 + 5 项待决策功能缺口）。
---

## 统计一览

| 类别 | 条目数 | 估算可删量 |
| ------ | -------- | ----------- |
| A. 陈旧 FRB 生成文件（Rust 模块已删） | 11 文件 | ~1,834 行 |
| B. 死 UI 代码簇（note 搜索残留） | 4 文件 | ~150 行 |
| C. 零调用 Rust API 面 | 5 个函数 | ~80 行 |
| D. 未使用的 pub 依赖 | 8 个 | pubspec + lock |
| E. WiFi 传书子系统（已空壳化） | 4 项 | ~500 行 |
| F. 死资产（wordlist JSON） | 4 文件 | 60 KB |
| G. 旧文档（孤儿/被取代） | 7 文件 | ~2,000 行 |
| H. 工具输出与环境冗余 | 2 项 | ~265 KB |
| I. PoC 测试残留 | 1 文件 | 326 行 |

---

## A. 陈旧 FRB 生成文件 — Rust 侧模块已删除/不再暴露，生成物残留

**根因**：commit `c1932bfb`（移除 notes 系统）、`31521040`（移除双语模块）等在 Rust 侧删除了模块，但 `flutter_rust_bridge_codegen generate` 未重新执行或未清理旧产物。由于 `analysis_options.yaml` 排除了 `lib/src/**`，这些死文件不影响 `dart analyze`，因此静默存活。

| # | 文件 | 行数 | 删除原因 |
| --- | ------ | ------ | ---------- |
| A1 | `lib/src/rust/api/note.dart` | 105 | Rust `api/note.rs` 已删（c1932bfb）。全仓库零 import，`frb_generated.dart` 的 import 列表也无此文件。 |
| A2 | `lib/src/rust/domain/note/models.dart` | 94 | Rust `domain/note/` 已删。仅被死代码（B 类）引用。 |
| A3 | `lib/src/rust/domain/note/models.freezed.dart` | 833 | 同上，A2 的 part 文件。 |
| A4 | `lib/src/rust/domain/bilingual/models.dart` | 159 | Rust `domain/bilingual/` 已删（31521040，双语移除）。零 import。 |
| A5 | `lib/src/rust/domain/engine_position/models.dart` | 26 | Rust 侧无 `domain/engine_position`。R3 引擎位置已落在 `domain/progress`，此文件是旧 R1 规划期的生成残留。零 import。 |
| A6 | `lib/src/rust/domain/engine_position/models.freezed.dart` | 277 | 同上，A5 的 part 文件。 |
| A7 | `lib/src/rust/parser/epub.dart` | 84 | 对应 Rust `api::book::get_epub_metadata` 返回值 `EpubMetadata`，但 Dart 侧零调用（见 C1）。当前 EPUB 渲染全走 Readium。 |
| A8 | `lib/src/rust/pipeline/types.dart` | 180 | Rust pipeline 类型仅内部使用，无任何 FRB 暴露 API；Dart 侧零 import。 |
| A9 | `lib/src/rust/domain/chapter_detect/models.dart` | 51 | `chapter_detect` 仅 Rust 内部（TXT 章节检测）使用，Dart 无消费者。 |
| A10 | `lib/src/rust/common/security.dart` | 15 | Rust `common::security` 仅被 Rust 内部 API 调用，Dart 侧无消费者。 |
| A11 | `lib/src/rust/lib.dart` | 8 | FRB 桶文件，导出已删除的 `NoteStats`；应用实际直接 import `frb_generated.dart`（main.dart:11），此文件零 import。 |

**删除方式**：执行 `flutter_rust_bridge_codegen generate` 重新生成（会清掉不再暴露的产物），或按上表手动删除。手动删除时需连同 B 类一起删，否则 B 类编译失败。

---

## B. 死 UI 代码簇 — note 搜索功能残留（恒为空，永不渲染）

commit `c1932bfb` 只删了 Rust note 模块和 `learning_notes/` 页面，但**搜索页的 note 分组 UI 没删**。由于 `noteItems` 被写死为空列表，`notes.isNotEmpty` 恒为 false，整段 UI 永不渲染。

| # | 文件 | 证据 |
| --- | ------ | ------ |
| B1 | `lib/features/search/application/search_view_model.dart:83` | `const noteItems = <NoteSearchItem>[];` — 恒空 |
| B2 | `lib/features/search/page/search_results.dart` | `NoteSearchItem` 类 + `notes` 字段 + `totalCount` 中 `notes.length` 恒为 0 |
| B3 | `lib/features/search/page/widgets/search_results_view.dart:47-55` | note 分组渲染分支，条件恒为 false |
| B4 | `lib/features/search/page/widgets/search_result_cards.dart:165-` | `NoteSearchCard` 组件，仅被 B3 死分支引用 |

**删除原因**：后端数据源（Rust note 模块）已不存在，该功能无论怎么走都是空结果；保留只会让 A 类 stale 文件（A1-A3）无法删除。删除 B 类后 A1-A3 即为纯死文件。

---

## C. 零调用 Rust API 面 — Dart 侧无任何调用方

| # | 函数 | 位置 | 删除原因 |
| --- | ------ | ------ | ---------- |
| C1 | `get_epub_metadata` | `api/book.rs:231` | Dart 零调用。内置 EPUB 元数据路径已被 Readium 接管；唯一间接依赖是 A7 生成文件。 |
| C2 | `get_processed_epub_image` | `api/book.rs:254` | Dart 零调用。内置 reader 图片管线已无消费者。 |
| C3 | `get_processed_epub_image_bytes` | `api/book.rs:239` | 同上。 |
| C4 | `get_image_dimensions` | `api/book.rs:269` | Dart 零调用（图片尺寸预读是旧排版管线能力）。 |
| C5 | `create_web_book` | `api/book.rs:180` | Dart 零调用（web 书创建功能已下线）。 |
| C6 | `get_book_by_file_path` | `api/book.rs:133` | Dart 零调用。 |

**注意**：C1-C4 与内置 EPUB 回退路径绑定。若按 ADR-020「EPUB only，Builtin 兼容回退」保留回退能力，则 C1-C4 属于"待 R7 引擎策略定稿后确认"；若回退彻底退出，可删。C5-C6 无此顾虑，可直接删。

---

## D. 未使用的 pub 依赖 — 全仓库无 import

| # | 依赖 | 证据 / 删除原因 |
| --- | ------ | ------------------ |
| D1 | `flutter_tts` | TTS 已由 Readium（flureadium）接管（e2d82a7c），lib 内零 import。 |
| D2 | `audioplayers` | 同上，音频播放改由 Readium 提供。零 import。 |
| D3 | `line_icons` | 图标已全面迁移到 `phosphoricons_flutter`（0.28 版起锁定 1.0.0）。零 import。 |
| D4 | `battery_plus` | 电量显示功能不存在于当前 UI。零 import。 |
| D5 | `uuid` | 零 import（ID 生成全在 Rust 侧）。 |
| D6 | `flutter_widget_from_html_core` | 零 import。 |
| D7 | `shimmer` | 骨架屏用 `flutter_animate` 实现（skeleton_widget.dart），shimmer 零 import。 |
| D8 | `json_annotation` | 仅 codegen 时代的依赖；当前模型全部走 freezed（`freezed_annotation`），全仓库零 import。 |
| D9 | `ffigen`（dev） | 无 ffigen 配置、无 C 互操作代码；`frb_generated.io.dart` 头部注释是 FRB 自己生成的引用，非项目调用。 |

**删除方式**：从 `pubspec.yaml` 删除 + `flutter pub get` 更新 lock。D1-D2 需与「TTS 统一走 Readium」确认后执行（若未来要回到 flutter_tts 做离线 TTS 则保留 D1）。

---

## E. WiFi 传书子系统 — 已空壳化，功能实际不可用

| # | 项 | 证据 |
| --- | ----- | ------ |
| E1 | `lib/core/network/wifi_transfer_service.dart` | 文件顶部 `ignore_for_file: unused_element,unused_field,unused_import`；`start()` 为空实现（注释"wifi 传书暂屏蔽，保留空 start/stop 接口供 UI 调用"）；`_htmlContent=''`、`_port=0`、`_localIp=''`。HTTP 服务永远不会启动。 |
| E2 | `lib/features/bookshelf/page/wifi_transfer_page.dart` + 路由 | `app_router.dart:223` 仍注册该页，UI 调用空壳服务。 |
| E3 | `assets/html/wifi_upload_page.html` | `_htmlContent` 硬编码空串，此文件从未被加载。 |
| E4 | `SettingsKeys.wifiTransferPort` | 仅 E1 引用。 |

**删除原因**：功能已屏蔽且无恢复时间表（README「不在当前范围」未包含它）。保留空壳是双份误导：UI 有入口、行为为空。**决策项**：要么整删（路由 + 页面 + 服务 + DI 注册 + 资产 + pubspec `assets/html/` 声明 + settings key），要么恢复实现。

---

## F. 死资产 — wordlist JSON 无任何加载代码

| # | 文件 | 大小 |
|---|------|------|
| F1-F4 | `assets/wordlists/cet4.json` / `cet6.json` / `ielts.json` / `toefl.json` | 共 ~60 KB |

**证据**：lib 与 rust/src 中零引用（仅 rust/README.md 提到"wordlists"字样和 cargo build 指纹文件）；pubspec.yaml 的 `assets:` 段**根本没声明** `assets/wordlists/`——即使运行期想加载也加载不到。git 历史显示是 `6d598581` 时代的架构产物。**删除原因**：既无代码引用也无打包声明，纯占位。

---

## G. 旧文档 — 孤儿或被当前路线取代

| # | 文件 | 判定 | 删除原因 |
| --- | ------ | ------ | ---------- |
| G1 | `docs/readium-poc-checklist.md` | 孤儿 | PoC 已取消（R1-1 记录"PoC 阶段取消，改为正式接入"）。该文档仅服务于 `feature/readium-poc` 分支，已被 `discuss/readium/CAPABILITY_MATRIX.md` + `LOCATOR_MAPPING_REPORT.md` + ADR-020 取代，全仓库零引用。 |
| G2 | `docs/PRDv2.1.md` | 孤儿 | 2026-05 的 PRD 旧版，当前路线是 ADR-020「EPUB Readium MVP」，零引用。**需用户确认**是否仍是产品基线文档；若 MVP 交付后建议归档至 `discuss/archived/`。 |
| G3 | `docs/PRDv2.2.md` | 孤儿 | 同上，v2.1 的增量补丁。 |
| G4 | `docs/design.md` | 孤儿 | "UI 设计语言"文档，零引用。**需核对**是否与当前 lib/core/theme + 页面一致（最后一次架构变动 PHASE12 之后未更新）。 |
| G5 | `docs/RUST_ARCHITECTURE.md` | 疑似过期 | 版本 3.1 / 2026-07-07，早于 `text/→parser/` 合并（6ac62ecf）和 phase13 目录重构；目录结构描述已不准确。零引用。 |
| G6 | `docs/DATABASE_SCHEMA.md` | 疑似过期 | 零引用，schema 演进（engine_position 加入 progress 等）未反映。 |
| G7 | `discuss/rust-flutter-ffi-optimization-candidates.md` | 孤儿 | 零引用候选清单；相关决策已被 ADR-014/017/018 吸收。 |

**保留不动的文档**：`discuss/READING_BOUNDARIES.md`、`DOMAIN_MODEL.md`、`ROADMAP.md`、`DECISIONS.md`、`INTENTS.md`、`glossary.md`、`discuss/adr/*`（含被 ROADMAP 引用的 PHASE12 / reader-text-engine-roadmap）、`discuss/archived/*`（已归档，ROADMAP 有引用）、`discuss/readium/*`（R1-1 交付物）。

---

## H. 工具输出与环境冗余

| # | 项 | 证据 | 删除原因 |
| --- | ----- | ------ | ---------- |
| H1 | `piolium/`（42 文件，265 KB） | piolium 安全审计工具的输出目录，已提交进 git 且未加入 .gitignore | 工具可再生成；非源码。建议 `.gitignore` 掉，仅保留 `final-audit-report.md`（如需要审计存档）。 |
| H2 | `.agents/skills/` 中 8 个技能与 `~/.agents/skills/` 重复且内容已漂移 | `tdd`、`ui-ux-pro-max`、`mobile-design`、`skill-creator`、`grill-me`、`grill-with-docs`、`teach`、`improve-codebase-architecture` 在 repo 与全局双份；diff 显示 `tdd`、`ui-ux-pro-max` 内容不同 | 双份维护必然漂移。若 `.agents/` 是给 Codex/Cursor 用的 repo 内技能库，应明确单一来源（推荐：repo 内为源，或 gitignore 掉 repo 副本）。 |

---

## I. PoC 测试残留

| # | 文件 | 行数 | 判定 |
|---|------|------|------|
| I1 | `rust/tests/poc_path_escape.rs` | 326 | 标题即 `PoC: validate_file_path 缺少基目录限制`，`PoC-Status: executed`。 |

**删除原因**：PoC 探针已完成使命；且它断言的安全缺陷（`validate_file_path` 无基目录校验）属于**真实 bug 记录**——按 AGENTS.md 测试纪律，只能记录进 TODO/文档，不能靠这个 PoC 测试"证明"行为。建议：转为正式回归测试（若安全修复立项）或删除（若按 MVP 范围接受现状）。

---

## 附注 / 执行注意

1. **删除顺序**：B 类 → A 类（A1-A3 依赖 B）→ 其余独立。若走 `flutter_rust_bridge_codegen generate`，A 类会一次性清理，但会同时改 `frb_generated.dart` / `lib.dart`——请审查 diff。
2. **本地未提交修改**：`rust/tests/api_test.rs`（2 行删除）是用户的未提交改动，报告未触碰、**禁止用 git checkout/reset 恢复**（GIT 铁律）。
3. **C1-C4 / D1-D2 是"待决策"而非"必删"**：与内置回退和离线 TTS 路线绑定；建议在 R7（引擎策略）定稿后一并处理。
4. **删除动作**：请由用户确认后立项（R14 清理任务），逐项执行并跑 `cargo clippy -- -D warnings` + `dart analyze --fatal-infos` 双门禁验证。

---

## ✅ 执行状态（R14 第一步，2026-08-02）

**A 类（陈旧 FRB 生成文件）已清理**：

- 删除：`lib/src/rust/api/note.dart`、`lib/src/rust/domain/note/`、`lib/src/rust/domain/bilingual/`、`lib/src/rust/domain/chapter_detect/`、`lib/src/rust/domain/engine_position/`、`lib/src/rust/parser/epub.dart`（引用已删的 EpubMetadata）、`lib/src/rust/pipeline/`、`lib/src/rust/lib.dart`（过期脚手架，引用已删 NoteStats）、`lib/src/rust/domain/book/service.dart` + `service.freezed.dart`（07-16 遗留，Rust 侧 BookDetail 已移至 api/book.rs）
- `flutter_rust_bridge_codegen generate` 已重跑，`frb_generated.*` 与 api/*.dart 均为最新（create_vocabulary_word 已从生成面消失）

**B 类（note 搜索 UI 残留）已清理**：

- `search_results.dart`：删 `NoteSearchItem` 类与 `SearchResults.notes` 字段
- `search_result_cards.dart`：删 `NoteSearchCard` 组件
- `search_results_view.dart`：删 notes 分组块
- `search_view_model.dart`：删 noteItems 组装

**附注**：`book_import_service.dart` 扩展名过滤由 `{'.txt','.epub'}` 收窄为 `{'.epub'}`（TXT 下线一致）。

**未处理（保留待后续）**：C（零调用 API 面余项）、E（WiFi 传书）、F（wordlist）、I1（poc_path_escape）——其中 C 与 B 类死 API 留待 R14 后续步骤与 E2-E5 决策。
