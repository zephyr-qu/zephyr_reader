# Phase 4 范围 — 引擎完善（Grilling 第五轮，2026-06-25）

> **状态**：✅ 已关闭（2026-07-03）。代码交付完毕；真机签退推迟至 Phase 5 M5 收尾。
> **来源**：`/grill-with-docs` 会话；决策归档 [xinxi-round5.md](./xinxi-round5.md)  
> **绑定**：[READING_BOUNDARIES.md](./READING_BOUNDARIES.md) v1.2 · [ROADMAP.md](./ROADMAP.md) Phase 4

---

## 北极星（四周主线）

**只做核心阅读引擎完善**，不扩 Won't 范围（PDF 阅读、账号同步、章内搜索 UI 等均不在 Phase 4）。

> **进度仍存 charOffset；渲染统一吃 IR；staging 预取必须命中、不可见 loading。**

---

## 决策汇总

| ID | 问题 | 决策 | ADR |
|----|------|------|-----|
| D1 | 四周主线 | **B** 引擎 polish | — |
| D2 | PDF | **A** Won't；更新文档删阅读/待办条目 | — |
| D3 | 同步 | **A** Won't 不变；WebDAV = 备份工具 | — |
| D4 | 章内搜索 | **C** 不做；全书搜索覆盖 | — |
| D5 | Scroll 大章 | **B** Scroll 也走 Chunked IR | [009](./adr/009-scroll-ir-unification.md) |
| D6 | 排版 CSS | **B** scroll + 块分页 Text 块统一投射 | [010](./adr/010-block-css-in-ir.md) |
| D7 | 双语 | **B** 独立 feature 模块，主链零依赖 | [011](./adr/011-bilingual-feature-module.md) |
| D8 | 跨章验收 | **C** staging 不允许 loading spinner | [012](./adr/012-staging-prefetch-guarantee.md) |
| D9a | 标点挤压 | 接受 by design | — |
| D9b | 字宽漂移 | Flutter Metrics 回传校准 | [013](./adr/013-flutter-metrics-calibration.md) |
| D9c | Rust 取消 | 仍不做 | — |
| D10 | 文档真理源 | **A** BOUNDARIES + ADR；对齐 README/DOMAIN_MODEL | — |
| D11 | 版式像原书 | **窄义**（font/缩进/段距/强调/图位） | [010](./adr/010-block-css-in-ir.md) |

---

## Phase 4 backlog（建议实施顺序）

| # | 项 | 验收 |
|---|-----|------|
| P4-0 | 文档对齐（README、DOMAIN_MODEL、glossary） | 无 Won't 冲突描述 |
| P4-1 | **Scroll → Chunked IR** | ✅ IR 主路径 + 跨章拼接；scroll 无 rich/epubRichSkipped |
| P4-2 | **IR Text 块基础 CSS**（`text-indent`、margin、font-family） | ✅ 块级 + 行内 span；CSS 显式 indent 优先；`BlockLayoutCache` v2 |
| P4-3 | **Staging 硬保证** | ✅ 跨章 prev hold 帧 + next 门闸；剩余 spinner 仅 page cache / EPS / fallback |
| P4-4 | **Flutter Metrics 回传** | ✅ 首屏 TextPainter → `applySessionCalibration` → repaginate + sled |
| P4-5 | **双语 feature 模块** | ✅ 独立模块，旧 `reader/translation/` 已删除，DI 重新生成；`BilingualReaderDelegate` 封装高亮逻辑，主链零 FRB 双语 import |

**不在 Phase 4**：PDF 阅读 UI、章内搜索、云盘直同步、Rust CancellationToken、CJK 标点挤压引擎。

---

## 不变量补充（Phase 4）

在 [DOMAIN_MODEL.md](./DOMAIN_MODEL.md) §3 基础上：

- **I6**：scroll 与 pagination **渲染输入均为 IR**（`ContentBlock[]`）；`plainText` 仍为进度/搜索/TTS 锚点（ADR-001 不变）。
- **I7**：跨章 adjacent 导航时，staging 预取未就绪 **不得** 向用户展示 loading；应阻塞翻页或静默等待至命中（ADR-012）。

---

## 退出标准（✅ 已签退）

- [x] P4-1～P4-4 代码 + 对应 Rust/Dart 测试（P4-1 完成，P4-2/P4-3/P4-4 已交付）
- [x] P4-5 双语 feature 模块（旧 `reader/translation/` 已删除，DI codegen 完成，真机待验收）
- [x] Phase 2/3 回归：`pagination_session_test` (34 pass)、`epub_reading_chain_test` (34 pass)
- [x] I1 持久化清理：`ReadingProgress` 移除 `page_index`/`total_pages`（Rust struct + SQL + Dart 全链路）
- [x] G1+G2 block font-size：`RichParagraph` → `TextBlockStyle`(IR) → Flutter `mapToTextStyle()`
- [x] FFI 测试恢复：`initFfiForTest()` 显式加载 DLL，集成测试 24/24 pass
- [ ] 真机：跨章 forward/backward 无可见 spinner（推迟至 Phase 5 M5 收尾）

---

## 相关文档

- [xinxi-round5.md](./xinxi-round5.md) — 本轮问卷原文
- [PHASE3_EXIT.md](./PHASE3_EXIT.md) — Phase 3 非阻塞遗留（部分纳入 P4-1/P4-3）
