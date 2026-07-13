# 后续规划 — ADR-016 收口（删 DEAD PATH → Accept）

**日期**：2026-07-12  
**当前分支**：`phase/stage6-line-width-calib`  
**现状基线**：`d472b64`（Flutter 已为唯一分页主路径；spike 命名已去）  
**前置结论**：TXT + EPUB Conditional Go；ADR-016 **条件接受**

本文只规划 **尚未做完** 的收口工作。T0–T5 产品路径已落地，见 [implement.md](./implement.md)。

---

## 一句话目标

删掉 Rust 装箱 / 校准写回死代码与双真理残留，正式 **Accept ADR-016**，让仓库只剩一条分页真理：**Rust 出 IR，Flutter 精确装箱**。

---

## 已完成（不重复做）

| 项 | 提交 / 位置 |
|----|-------------|
| explore 真机 Go + spans | `308e706` |
| DEAD PATH 标注 | `3923541` + [016-dead-path-inventory.md](../../../discuss/adr/016-dead-path-inventory.md) |
| 合入 stage6 | `9052b17` |
| `spike/` → `flutter_pagination/`；关主路径 | `d472b64` |

---

## 阶段划分

```
P6 删 Dart 死路径 ──► P7 删/缩 Rust 装箱 FFI ──► P8 校准环收口
        │                      │                      │
        └──────── 每阶段可独立提交；红测即停 ──────────┘
                              │
                              ▼
                    P9 Accept ADR-016 + 文档收敛
                              │
                              ▼
                    P10（可选）合 master / 关 explore 分支
```

**原则**：长删除拆提交；每提交后 `flutter test test/features/reader/flutter_pagination/` + 相关 orchestrator 测必须绿。不 silent 扩 scope（不顺手做 T4 hint、不重写滚动模式）。

---

## P6 — 删 Dart 侧死路径（优先，风险低）

**目标**：`chapter_load_orchestrator` / coordinator / session 工厂不再保留「可复活」的 Rust 分页入口。

| # | 工作项 | 验收 |
|---|--------|------|
| P6.1 | 删除 orchestrator 内 `if (false) { … }` 整段 DEAD PATH（原 Rust 装箱+校准加载体） | 文件显著变短；无 `unreachable`/`dead_code` 噪音 |
| P6.2 | 删除或内联掉仅被该段调用的私有方法（如仅服务校准回传的 `_captureMetricsBackfeed`、仅服务旧 quick-paginate 的路径） | 无未引用 private；grep `MetricsBackfeed` / `repaginateAfterMetricsBackfeed` 仅剩 DEAD 注释或为零 |
| P6.3 | `PaginationCoordinator.repaginateAfterMetricsBackfeed`：删除，或改为显式 `UnsupportedError` + 无调用方 | 仓库无生产调用 |
| P6.4 | 删除 `RustPaginationSession`（及工厂注释中的对照说明） | `pagination_session_factory` 只创建 `FlutterPaginationSession` |
| P6.5 | `PaginationSession.applySessionCalibration`：接口层改为可选废弃——Flutter session 已 no-op；若无外部调用则从接口移除 | 接口与实现一致；无空壳「假装校准」 |

**建议提交信息**：`refactor(reader): 删除 Dart 侧 Rust 分页/校准死路径（ADR-016 P6）`

**门控**：

```bash
flutter test test/features/reader/flutter_pagination/
flutter test test/features/reader/core/application/chapter_load_orchestrator_test.dart
dart analyze lib/features/reader --fatal-infos
```

---

## P7 — 缩/删 Rust 装箱与 session FFI（风险中）

**目标**：Rust 不再对外提供「正式页装箱」API；保留 **IR + 图解码**（产品 Must）。

| # | 工作项 | 注意 |
|---|--------|------|
| P7.1 | 盘点仍被 Dart/`frb` 调用的分页 FFI：`create_pagination_session*`、`apply_session_calibration`、`paginate_chapter`、`repaginate_session`、`paginate_session_full`、`get_session_page_*`、`store_line_breaks` 等 | 先出调用图，再删；**禁止**未改 Dart 就删 FFI |
| P7.2 | Dart 侧确认零调用后，删对应 `rust/src/api/core.rs` 导出 + `reading/session.rs` 实现 | 走 `flutter_rust_bridge_codegen generate`；**禁止手改** `frb_generated*` / `lib/src/rust/` |
| P7.3 | `block_paginator.rs`：删除 **或** 移入 `#[cfg(test)]` / `examples` 作对照（默认推荐：**删生产路径，单测若依赖则改测 Flutter 或删测**） | clippy `-D warnings` 绿 |
| P7.4 | sled / `config_hash` / layout cache：若仅服务 Rust 分页 session，一并收缩；若仍被书签以外逻辑误用，先 ADR 小记再动 | 不破坏 ADR-001 charOffset |

**建议提交**：可拆 2 个 commit——(1) 停 Dart 调用 + FRB 重生；(2) 删 `block_paginator` 与 session 实现。

**门控**：

```bash
cargo clippy -p <rust-crate> -- -D warnings   # 按仓库实际 package
cargo test -p <rust-crate> --lib
flutter test test/features/reader/flutter_pagination/
# 真机冒烟：打开 TXT + 带图 EPUB，翻页/跨章/改字号各一次
```

---

## P8 — 校准环收口（测量可留、写回必删）

**目标**：消灭 Flutter→Rust 校准写回；**诊断用测量**可保留。

| # | 保留 | 删除或停用 |
|---|------|------------|
| P8.1 | `TypesetCalibrator` 中纯测量 / overflow 诊断（若仍服务滚动或调试） | `apply_session_calibration` 全链、`LayoutCalibrationStore` 写路径、orchestrator 内 `resolveLayoutCalibration` 分页依赖 |
| P8.2 | `page_overflow_diagnosis`（Flutter 侧自检） | 渲染路径再传 `layoutCalibration` 给「Rust 估行宽」诊断（已 null，清残留 API） |
| P8.3 | — | 测试里「校准写回后页数变化」类用例：改断言 Flutter 重装箱，或删除 |

**决策点（做 P8 前选一个）**：

- **A（推荐）**：校准缓存整模块删除——产品不再需要设备指纹校准。  
- **B**：保留只读测量工具类，去掉 store + 写回；文档标明「诊断 only」。

---

## P9 — 正式 Accept ADR-016 + 文档收敛

| # | 工作项 |
|---|--------|
| P9.1 | `discuss/adr/016-…`：状态改为 **Accepted**；更新分支字段为 `phase/stage6-line-width-calib`（或合入后的目标分支）；勾掉「待做」门槛 |
| P9.2 | ADR-013 → **Superseded by 016**；ADR-006 分页职责段交叉引用 016 |
| P9.3 | 更新 [DECISIONS.md](../../../discuss/DECISIONS.md)、[016-dead-path-inventory.md](../../../discuss/adr/016-dead-path-inventory.md)（改为「已删除」归档或删文件） |
| P9.4 | 刷新本任务 `implement.md` / `design.md` 风险表（去掉「禁止改 block_paginator」「spike 自由」等过时约束） |
| P9.5 | 评估 ROADMAP / Phase 5：本收口是 **稳定性工程**，不新开 Phase；若 Phase 5 退出清单含「校准环」，勾完成 |

**建议提交**：`docs(adr-016): Accept — Flutter 精确分页为正式方案`

---

## P10 — 分支与发布（可选，单独决策）

| # | 工作项 | 说明 |
|---|--------|------|
| P10.1 | 合入目标主干（`master` / 团队主线） | 用户明确要求再 push/PR |
| P10.2 | 归档 `explore/flutter-side-pagination` | 保留标签或备注指向 Accept 提交 |
| P10.3 | 真机签退清单（短） | TXT 大章 / EPUB 图 / 跨章 / 改字号书签 — 签在 `compare-*.md` 或 Phase5 退出单 |

---

## 明确不做（本收口）

- T4 Rust 粗页 Hint（默认跳过，Accept 后也不做，除非新开 ADR）
- 滚动模式大改、WebView 全引擎
- 为「过测试」改 Flutter 装箱启发式（发现 bug → 记 TODO / 新任务，不 silent 改生产逻辑糊弄）
- 手改 FRB 生成文件

---

## 推荐执行顺序与检查点

| 顺序 | 阶段 | 停止条件 |
|------|------|----------|
| 1 | **P6** | orchestrator/工厂测红；或仍有生产路径调用 `RustPaginationSession` |
| 2 | **P7** | FRB/链接失败；或误删 `get_chapter_content_ir` / 图解码 |
| 3 | **P8** | 选 A/B 后；测量删除导致滚动模式回归则回退到 B |
| 4 | **P9** | 代码未删干净就 Accept → **禁止**（先码后文） |
| 5 | **P10** | 仅当需要合主干时 |

每阶段结束：**本地 commit 存档**（与本次收口节奏一致）。

---

## 成功标准（全部满足才算收口完成）

1. 分页模式下，运行时 **零** `create_pagination_session` / `apply_session_calibration` / `paginate_chapter` 调用  
2. 仓库无 `spike` 包名、无 `kFlutterPaginationSpike`  
3. ADR-016 **Accepted**；ADR-013 Superseded  
4. `flutter_pagination` 单测 + orchestrator 相关测绿；clippy 绿  
5. 真机抽样：TXT + 带图 EPUB 各至少一条「打开→翻页→跨章→改字号」无回归  

---

## 相关文档

| 文档 | 用途 |
|------|------|
| [implement.md](./implement.md) | T0–T5 完成度 |
| [compare-txt.md](./compare-txt.md) / [compare-epub.md](./compare-epub.md) | 真机 Go 记录 |
| [016-flutter-pagination-engine-proposed.md](../../../discuss/adr/016-flutter-pagination-engine-proposed.md) | ADR（待 Accept） |
| [016-dead-path-inventory.md](../../../discuss/adr/016-dead-path-inventory.md) | 待删清单 |
