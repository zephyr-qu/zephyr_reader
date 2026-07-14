# Phase 7：清理冗余代码

## Goal

经过 P6–P9 大规模重构（删 Rust 分页 FFI、去校准环、拆 core.rs、合入 master），代码中存在大量过时/冗余残留。Phase 7 的目标是一次全面清理。

## 审计结果

### A — 命名清理（8 处）

| 文件 | 当前文本 | 清理方向 |
| ------ | ---------- | ---------- |
| `pagination_coordinator.dart:110` | "全章分页（spike / 字号变更后重装箱）" | spike → FlutterPagination |
| `active_chapter_ir.dart:3` | "当前 spike session 持有的章 IR" | spike → FlutterPagination |
| `flutter_pagination_session.dart:223,251` | `Exception('SpikeSession: ...')` | SpikeSession → FlutterPaginationSession |
| `chapter_load_orchestrator.dart:110` | "Rust 装箱+校准见 DEAD PATH" | DEAD PATH → 已删，注释可简化 |

### B — 过时 ADR / Phase 注释清理（~20 处）

`ADR-012`, `ADR-013`, `ADR-014`, `ADR-015`, `ADR-016`, `Phase 3`, `Phase 4`, `P4-1`, `P4-3`, `P4-5` 等标签散布在代码注释中。ADR 已完成，注释中的引用可简化为直接说明行为。

### C — Rust 死代码（`pagination_store.rs`, `block_state.rs`）

这两个模块的功能曾被 Rust 分页 session 使用，P7 删了消费者但保留了结构体和方法。目前用 `#[allow(dead_code)]` 压制告警。

**选项**：

- C1：彻底删除 `pagination_store.rs`、`block_state.rs` 中未被引用的代码
- C2：保留 `#[allow(dead_code)]` 不动（如果短期内还可能复用）

### D — `PackedPage` / `FRB PageDescriptor` 双重类型

| 类型 | 来源 | 用途 |
| ------ | ------ | ------ |
| `PackedPage` | 纯 Dart (`packed_page.dart`) | Flutter 装箱产出 |
| `PageDescriptor` | FRB (`pagination.dart`) | 跨 FFI 接口类型 |
| `PackedBlockSlice` | 纯 Dart | Flutter 装箱中间态 |
| `PageBlockSlice` | FRB (`block_pagination.dart`) | 渲染入参 |

两者字段几乎一样（pageIndex, startOffset, endOffset, isLastPage）。**建议合并**：删除 `PageDescriptor` 的 FRB 定义（不再被任何 FFI 使用），让 Flutter 侧统一使用纯 Dart 类型。或至少消除 `_applyPages` 中的冗余转换。

### E — 其他发现

| 项目 | 说明 |
| ------ | ------ |
| TODO(p4-5) bilingual auto-fetch | 第 55 行的 TODO，双语 pair 从不会自动取数 |
| `applySessionCalibration` 接口残留 | 接口层已删，但 `buildTypesetConfig` 还接收 `calibration` 参数（总是传 null） |
| `page_overflow_diagnosis.dart` | P6 留的诊断工具，仍依赖 Rust `paginate_chapter`（已删），**编译报错？** |
| `typeset_calibrator.dart` 大文件 | ~850 行，含 `buildTypesetConfig`、`measureLayoutFingerprint`、`calibrateFromPageText` 等。大部分函数已无调用方 |

## 工作量评估

| 优先级 | 项 | 估计 |
| -------- | ---- | ------ |
| 🔴 P0 | 检查 `page_overflow_diagnosis.dart` 是否编译失败 | 5 min |
| 🔴 P0 | 清理 `SpikeSession` → `FlutterPaginationSession` Exception 文本 | 5 min |
| 🟡 P1 | 删除死者名 ADR/Phase 注释 | 30 min |
| 🟡 P1 | Rust `#[allow(dead_code)]` 代码整肃 | 30 min |
| 🟢 P2 | `PackedPage` ↔ `PageDescriptor` 合并评估 | 30 min |
| 🟢 P2 | `typeset_calibrator.dart` 死函数清理 | 30 min |
| 🟢 P3 | TODO(p4-5) 双语 auto-fetch | 独立功能，与清理无关 |

## 验收标准

- [ ] `SpikeSession` / `spike` 命名从代码中消失
- [ ] `page_overflow_diagnosis.dart` 不复用已删的分页 API（或确认编译通过）
- [ ] Rust 无 `#[allow(dead_code)]` 压制（删除死代码而非压制）
- [ ] `PackedPage` 和 `FRB PageDescriptor` 合并或给出明确 No-go 理由
- [ ] 过时 ADR/Phase 注释清理至少覆盖 `lib/features/reader/`
- [ ] `flutter test` 全绿
- [ ] `cargo clippy -- -D warnings` 零告警（不含 pre-existing）
