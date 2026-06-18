# 第四轮 — Phase 1 缺口确认（来源：appendix04 + 代码对照）

> **背景**：`feat/simplify` @ `ad647a3` 已完成加载链瘦身、PDF/MD 剥离。\
> **目的**：冻结 Phase 1 **剩余验收**（ROADMAP 1.4 / 1.5 + appendix04 风险 A/B）。\
> **读前**： [ROADMAP.md](./ROADMAP.md) · [ADR-002](./adr/002-pageturn-is-pagination-skin.md) · [DOMAIN\_MODEL.md](./DOMAIN_MODEL.md)

**代码快照（供对照，非选项）**

| 项          | 现状                                                                           |
| ---------- | ---------------------------------------------------------------------------- |
| EPUB→plain | `html_to_plain_text` 已对 `p/div/h1…` 插 `\n`（单换行，非 `\n\n`）                     |
| 分页竞态       | Orchestrator `_generation` 防写回；已去掉 partial 早写 `chapterContent`               |
| pageTurn   | `reader_content.dart` 独立 early-return + `PageCurlWidget`；数据仍走同一 Rust session |
| intent     | 5 个：`normalLoad` / `configReload` / `expandOnly` / `stagingPromote*`         |

***

## R4-1 — plainText 分段规则（appendix04 风险 A）

ADR-001 要求书签/TTS/搜索都锚在 `plainText`。当前块级标签只产 **单** **`\n`**。

- [x] **A（推荐）**：维持现状（单 `\n` + `clean_whitespace`），Phase 2 前不改编码

**Phase 2 预留**：在 Phase 2 引入 IR 时，我们可以重新定义 `ContentBlock::Paragraph`，那时再决定是用 `\n\n` 还是通过样式控制间距，而不污染 `plainText` 的原始性

- [ ] **B**：块级开/闭标签统一为 `\n\n`（段落视觉更接近 HTML）
- [ ] **C**：仅 `p/h1-h6` 用 `\n\n`，`div/li` 仍单 `\n`
- [ ] **D**：其他：\_\_\_\_\_\_\_\_\_\_

**若选 B/C，是否接受**：已存 `charOffset` 书签在规则变更后可能偏移？

- [ ] 接受（文档注明需重导或迁移）
- [ ] 不接受（必须版本化 plain 规则）

**不接受**。必须保证 `charOffset` 的绝对稳定性。如果未来真要改规则，必须通过版本号迁移或重新索引，不能在 Phase 1 悄悄改动。

***

## R4-2 — plainText 验收方式（风险 A 可测性）

- [ ] **A（推荐）**：加 2–3 个 Rust 单元测试（固定 HTML fixture → 期望 plain 含段落空行）
- [ ] **B**：再加 1 本真实 EPUB 黄金样章（人工目视 + offset 断言）
- [ ] **C**：暂不测，Phase 2 IR 时一并处理

* **选择：A（推荐） + B（补充）**。
* **理由**：
  - **A 是底线**：必须有 Rust 单元测试固定 HTML fixture，确保解析逻辑回归安全。
  - **B 是保险**：选一本结构复杂的真实 EPUB（含嵌套 div, list, table），人工核对生成的 `plainText` 是否可读。这能发现单元测试覆盖不到的边界情况（如特殊 Unicode 字符）。

***

## R4-3 — pageTurn 皮肤边界（appendix04 风险 B / ROADMAP 1.5）

ADR-002：pageTurn = pagination 皮肤。当前 UI 在 `reader_content` 有 **70+ 行** 独立分支。

- [x] **A（推荐）**：抽 `PageTurnShell`（或扩 `PaginatedRenderer`），**只接收** `(pageIndex → Widget)` + staging 虚拟页；动画层不读 `descriptors`/Rust API

**彻底解耦**：这是实现 ADR-002 的唯一正途。动画层只关心 `(pageIndex) -> Widget` 的映射，不关心底层是 Rust 还是 Dart 算的页。

- [ ] **B**：保持 `reader_content` 内联，仅删重复逻辑、共用 `buildStagingPageContent`
- [ ] **C**：Phase 1 不动 UI，1.5 推迟到 Phase 2 前
- <br />

<br />

**staging 虚拟页**（上一章末页 / 下一章首页）是否必须零改动保留？

- [x] 必须（G2-b）
- [ ] 可简化（说明：\_\_\_\_\_\_\_\_\_\_）

**Staging 虚拟页**：**必须零改动保留**。这是“换章丝滑”的核心体验，不能因为重构 UI 而牺牲性能。`PageTurnShell` 应透明地接收 staging 提供的上一页/下一页 Widget。

***

## R4-4 — pagination 与 pageTurn 设置重载

改字号/行距时，两种模式是否 **同一** `configReload` 路径？

- [x] **是（推荐）**：共用 orchestrator + `repaginateInPlace`，仅皮肤不同

* **逻辑复用**：字号/行距改变影响的是**分页计算本身**，而不是动画。无论是滑动还是翻页，底层的 `PageInfo` 都需要重新计算。
* **代码简洁**：Orchestrator 只需要触发一次 `repaginateInPlace`，UI 层根据当前皮肤决定是重绘列表还是重绘动画容器。

- [ ] **否**：pageTurn 单独重载逻辑（需说明理由）。

<br />

***

## R4-5 — Orchestrator intent 收敛（ROADMAP 1.4）

当前 5 intent。Phase 1 目标收敛到几条？

- [ ] **A（推荐）**：保留 5 个，只补 `discuss/INTENTS.md` 状态机图 + 何时选用表（最小代码改动）
- [ ] **B**：合并为 3 个：`freshLoad` / `sameChapterRepaginate` / `stagingHandoff`（含代码重构）
- [ ] **C**：合并为 2 个：`load` / `stagingPromote`（激进，需 ADR 修订）

**若合并，staging 双向**是否仍要区分 forward/backward？

- [ ] 要（末页 vs 首页 handoff 不同）
- [ ] 不要（统一 promote 参数）

<br />

- **选择：A（推荐）**：保留 5 个，补文档。
- **理由**：
  - **风险最低**：Phase 1 的目标是瘦身，不是重写状态机。合并 Intent 需要大规模修改调用方，容易引入 Bug。
  - **明确契约**：通过 `discuss/INTENTS.md` 明确每个 Intent 的触发场景和前置条件，比盲目合并代码更有价值。
  - **Staging 双向**：**要区分**。Forward（预取下一章首页）和 Backward（预取上一章末页）的逻辑不同，统一参数会增加内部判断复杂度。

***

## R4-6 — Rust 侧任务取消（appendix04 风险 C）

Dart 已有 `_generation`；Rust 分页/expand 仍可能跑完才丢弃。

- [x] **A（推荐）**：Phase 1 **不做** Rust 取消；generation 足够

* **性价比低**：Dart 侧的 `_generation` 已经能防止旧结果覆盖新状态。Rust 侧的计算通常在毫秒级，强行加入 `CancellationToken` 会污染纯函数式的分页算法，增加 FRB 桥接复杂度。
* **留待 Phase 2**：当 Phase 2 引入更重的 IR 计算和图片预处理时，再考虑后台任务取消。

- [ ] **B**：Phase 1 为 `paginate_session_*` 加 `session_id` 失效检查（轻量）
- [ ] **C**：完整 `CancellationToken`（Phase 2）

## R4-7 — 全文 ready 前 UI 行为（1.2 验收）

simplify 后首屏不再写 partial `chapterContent`；分页模式 TTS/搜索已延后。

首屏分页时 **选择/复制** 是否允许用 Rust `pageContent`（非 full plain）？

- [x] **A（推荐）**：允许（当前页文本即可）；进度仍以 finalize 后 plain 为准

<br />

- **体验优先**：用户打开书就想看内容，不想等全文解析完。只要 Rust 能返回当前页的 `pageContent`，就应该允许交互。
- **进度锚定**：虽然可以交互，但**持久化进度**必须等到 `plainText` 全文 Ready 并计算出准确的 `charOffset` 后才执行。 interim 状态只存在于内存中。

<br />

- [ ] **B**：禁止，直到 `chapterContent` data 才启用选择
- [ ] **C**：显示「加载中」占位，禁用选择/搜索入口

***

## R4-8 — Phase 2 前置（appendix04 加分项，非 Phase 1 必须）

### ContentBlock 预定义

- [ ] **做**：Phase 1 末尾只加 Rust `enum ContentBlock` + FRB 导出，不接分页
- [x] **不做（推荐）**：严格 Phase 2 再引入（避免半套 IR）

### 分页错误埋点

- [ ] **做**：`readerNotice` + 日志枚举（如无 descriptors、expand 失败）
- [x] **不做（推荐）**：仅现有 `error` 信号 + toast

<br />

- **ContentBlock 预定义**：**不做（推荐）**。
  - **理由**：严格遵循 Phase 边界。提前引入半套 IR 会导致 Flutter 层出现“既用旧逻辑又等新接口”的混乱状态。
- **分页错误埋点**：**不做（推荐）**。
  - **理由**：Phase 1 沿用现有的 `error` 信号即可。过早引入复杂的日志枚举会增加维护成本，等 Phase 2 块分页稳定后再做精细化观测。

***

## R4-9 — 本轮回合产出物

勾选你希望我在你答完后 **写入 discuss/** 的文档：

- [x] `INTENTS.md`（若 R4-5 选 A/B）
- [x] ADR-007 plainText 分段规则（若 R4-1 选 B/C）
- [x] `PHASE1_EXIT.md` 验收清单（汇总 R4 答案 + ROADMAP 1.4–1.6）
- [ ] 暂不写文档，只回聊天结论

***

## ✅ 已确认（2026-06-18）

→ [ADR-007](./adr/007-plaintext-segmentation-stability.md) · [INTENTS.md](./INTENTS.md) · [PHASE1_EXIT.md](./PHASE1_EXIT.md) · [ROADMAP.md](./ROADMAP.md) 已更新。

**Phase 1 剩余实现**：plain 测试 → `PageTurnShell` → EPUB 样章核对。
