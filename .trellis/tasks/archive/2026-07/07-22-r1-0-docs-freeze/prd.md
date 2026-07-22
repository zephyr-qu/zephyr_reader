# R1-0：文档与决策冻结

## Goal

将 ADR-019 从"草稿"重写为反映新版 Phase R1 设计的正式决策，同步修改 READING_BOUNDARIES.md、DOMAIN_MODEL.md、ROADMAP.md，为双引擎接入建立准确的文档基础。

## Background

当前 ADR-019（引擎统一 ADR）是一个草稿阶段的设计，其核心方案是"定义一个大型 ReaderEngine 接口 + 两个引擎分别实现"。该方案存在以下问题：

1. `ReaderEngine` 接口试图把 `PaginationEngine`、ScrollEngine、IR 等 Builtin 内部概念强加给 Readium
2. 接口里塞了十几个 Signal 和 `Widget buildContent()`，违反了最小接口原则
3. 实施顺序被反转：先定义接口 → 再实现，而不是先验证能力 → 再冻结 seam
4. 没有位置模型、能力模型、引擎策略等关键设计决策

Phase R1 的重新设计已在本次会话中定义，需要更新 ADR 反映新方案。

同时，READING_BOUNDARIES.md 当前包含 "WebView / 完整 HTML 排版引擎" 的绝对禁止，这与 Readium 接入冲突，需要调整。DOMAIN_MODEL.md 需要增加新的实体，ROADMAP.md 需要新增 Phase R1。

## Requirements

### 1. 重写 ADR-019

- 状态从"草稿"改为"已通过"
- 替代原大型 `ReaderEngine` 接口方案 → 改为三个小接口：`ReadingBackend`、`ReadingSnapshot`、`ReadingViewportAdapter`
- 位置模型：`ReadingPosition`（charOffset）为领域真理，Readium `Locator` 为 Adapter 私有位置
- 能力模型：`ReadingCapabilities` 显式列出引擎支持/不支持的能力
- 引擎策略：`ReadingBackendPolicy` 支持 builtinOnly / readiumForEpub / perBook
- 实施顺序：R1-0 文档 → R1-1 能力探针 → R1-2 位置桥 → R1-3 Builtin Adapter → R1-4 Readium Adapter → R1-5 引擎策略 → R1-6 统一入口 → R1-7 功能补齐 → R1-8 签退
- seam 位置：阅读会话行为层（不是 PaginationEngine 层）
- 停止使用"TXT 引擎"称呼自研引擎 → 改称 Builtin

### 2. 修改 READING_BOUNDARIES.md

- Won't 列表中的 "WebView / 完整 HTML 排版引擎" 改为：
  - ✅ "允许封装后的 Readium EPUB Navigator（通过 flureadium 接入）"
  - ❌ "不允许业务代码或 UI 层直接依赖 WebView / Platform View"
- 一页纸增加 Readium 的提及
- 更新当前阶段标记为 Phase R1

### 3. 更新 DOMAIN_MODEL.md

- 不变：I1（持久化只用 `ReadingPosition`，不用 `pageIndex`）保持不变
- 新增实体：
  - `ReadingBackend` — 抽象阅读后端接口
  - `EnginePositionHint` — 引擎私有的位置加速提示（如 Readium Locator JSON）
  - `ReadingCapabilities` — 引擎能力描述
  - `ReadingSnapshot` — 原子阅读状态快照
- 明确：`charOffset` 仍为领域真理（跨引擎位置交换的权威格式）
- 明确：Readium Locator 只是 Adapter 私有位置，不进入领域持久化模型
- 更新用例 → 实体表

### 4. 更新 ROADMAP.md

- 在 Phase 13 和 Phase 14 之间插入 Phase R1
- Phase R1 包含 R1-0 ~ R1-8 完整任务树
- 标记 R1-0 为当前进行中

### 5. 文档一致性

- 全文统一用语：Builtin（代替"TXT 引擎"）、Readium（代替"Readium 引擎"）
- 明确 Phase R1 只接 EPUB，不接 PDF 或漫画
- 不支持的能力必须通过 capability 显式暴露，禁止空实现

## Acceptance Criteria

- [ ] ADR-019 已重写，反映三个小接口方案
- [ ] ADR-019 包含位置模型、能力模型、引擎策略的决策记录
- [ ] ADR-019 实施计划更新为 R1-0 ~ R1-8
- [ ] READING_BOUNDARIES.md Won't 列表已更新：Readium EPUB Navigator 不再是绝对禁止
- [ ] DOMAIN_MODEL.md 新增 ReadingBackend、EnginePositionHint、ReadingCapabilities、ReadingSnapshot
- [ ] DOMAIN_MODEL.md 明确 charOffset 仍为领域真理
- [ ] ROADMAP.md 新增 Phase R1 条目（R1-0 ~ R1-8）
- [ ] 全文已统一用语（Builtin、Readium）
- [ ] 更改已 git add + commit

## Notes

- This is documentation-only task — no production code changes
- Commit message: `docs: phase R1 document freeze — accept readium dual-engine boundary`
