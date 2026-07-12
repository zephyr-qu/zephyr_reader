# 方案三：Flutter 精确分页 + 性能兜底

## Goal

在方案 2 spike（Conditional Go）之上，定义**产品化分页终态**：页边界真理在 Flutter；Rust 只出 IR（+ 可选粗估 hint）；用 isolate / 相邻章预装箱满足 staging 与大章性能，**不做** metrics 回传环。

本任务产出：**计划 + 可行性评估 + 分阶段门槛**；**不**在 Phase 5 插队合并主线。

## Relation to 方案 2 / ADR-016

| 文档 | 关系 |
|------|------|
| [07-12-flutter-side-pagination](../07-12-flutter-side-pagination/prd.md) | **T0 已完成**：证明 TextPainter 装箱可行；Verdict = Conditional Go |
| [ADR-016](../../../discuss/adr/016-flutter-pagination-engine-proposed.md) | 职责提案；本任务把毕业门槛拆成 T1–T5 执行计划 |
| ADR-006 / 013 | 生产仍有效；接受 ADR-016 前不 silent 改 |

**一句话**：方案 2 = 精确分页 MVP；方案 3 = 同一真理 + staging / 大章 /（可选）粗 hint。

## Background

| 项 | 说明 |
|----|------|
| 当前阶段 | Phase 5 稳定性；方案三排队，不插队真机签退主线 |
| 硬契约 | 正式翻页/书签只认 Flutter 精确页；Rust 粗结果不得写入正式 session |
| 进度 | `chapterIndex + charOffset`（ADR-001）不变 |
| Must | S1 大 TXT、S2 EPUB 图、S3 书签、换章零可见 loading（ADR-004/012） |

## Requirements

### R0 — 计划与门控（本任务交付）

- R0.1：`design.md` 写清架构、模块、与方案 1/2 差异。
- R0.2：`implement.md` 写清 T0–T5 顺序、每阶段验证命令与 Go/No-Go。
- R0.3：可行性评估写入本文 Verdict；列出风险与缓释。

### R1–R5 — 产品化（后续实现任务，本 PRD 定义验收）

| ID | 内容 |
|----|------|
| R1 | Spike → 正式 `FlutterPaginationSession`；复用块渲染；flag 可灰度 |
| R2 | Image：InlineContain / FullPage；与现网语义对齐 |
| R3 | Staging：相邻章 **同算法**后台精确预装箱 + promote；满足 ADR-012 |
| R4 | 大章：装箱进 isolate/`compute`；首屏优先；可取消 |
| R5 | （可选）Rust 粗页数/粗 descriptor = **Hint only**；不驱动翻页 |

## Acceptance Criteria

### 本任务（计划）

- [x] AC-P1：`design.md` + `implement.md` 可执行。
- [x] AC-P2：可行性 Verdict 明确（见下）。
- [x] AC-P3：与方案 2 / ADR-016 交叉引用完整。

### 毕业（ADR-016 Accept 前，实现任务勾选）

- [ ] AC1：flag 开，当前章零 Rust 分页 FFI；overflow 真机以 `ok` 为主。
- [ ] AC2：改字号后 charOffset 书签不跳句。
- [ ] AC3：跨章 forward/backward 无可见 spinner/骨架当常态（ADR-012）。
- [ ] AC4：百万字级 TXT 首屏可进、装箱不堵死 UI（订 p95）。
- [ ] AC5：含图 EPUB 翻页可见、无系统性丢字。
- [ ] AC6：flag 关 = 现网路径可用直至 Rust 分页删除。
- [ ] AC7：新 ADR 接受后更新 `READING_BOUNDARIES` 技术分工一行。

## Out of Scope（本任务及 T1 首轮）

- Phase 5 插队合并 / 删除生产 `BlockPaginator`
- WebView / 完整 CSS（Won't）
- 双语接入分页主链
- 把 Rust 粗分页当正式 `PageDescriptor`
- 当前章 Flutter、staging 仍 Rust 的双真理半吊子方案

## Decisions Locked

| # | 决策 |
|---|------|
| D1 | 页边界真理 = Flutter `TextPainter` 装箱 |
| D2 | Rust 正职 = IR + 图资源；（粗分页仅 Hint，默认延后 T4） |
| D3 | Staging 必须同算法精确预装箱，禁止粗页冒充真页 |
| D4 | 无 Flutter→Rust metrics 校准环 |
| D5 | 主线切换在 Phase 5 签退之后（或单开后续 Phase）；现网 flag 默认关 |
| D6 | T0 = 方案 2 spike；T0 已 Conditional Go → 可开 T1 计划，未开合并 |

## Feasibility Verdict

| 维度 | 判断 |
|------|------|
| 技术 | **可行** — 依赖 T0（已过）+ T2 staging + T3 大章 |
| 产品 | **可行** — 若 staging 用精确预装箱而非粗页 |
| 现在主线化 | **不可行** — Phase 5 + ADR-016 未接受 |
| 现在该做 | **保持 explore**；Phase 5 后按 `implement.md` 开 T1 |

**总判：Conditional Go（产品化计划成立；执行排队）。**

### 风险摘要

| 风险 | 严重度 | 缓释 |
|------|--------|------|
| Staging 时延不够 | 高 | T2 真机抽样；预取窗口加宽；宁可挡手势不 spinner |
| 大章主线程卡 | 高 | T3 强制 isolate；首屏优先 |
| 装箱复杂度膨胀 | 中 | 对齐现有规则；超预算则 No-Go 回方案 1 |
| 双引擎并存过久 | 中 | flag + T5 必须二选一 |
| 粗分页误用 | 低→高 | T4 默认不做；契约写死 Hint-only |

## Notes

- 实现启动前：`task.py start` 新开实现子任务或本任务升格，并起草/更新 ADR-016 毕业清单勾选。
- 粗分页（T4）可永久不做；不影响 T1–T3 Go。
