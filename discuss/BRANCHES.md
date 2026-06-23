# 功能分支说明

| 分支 | 基线 | 用途 | 状态 |
|------|------|------|------|
| `master` | — | 主开发线 | Phase 1 已合入 @ `2eebb52` |
| `fix` | `master` | 阅读链 P0/P1 修复 | 与 `master` 同步 @ `2eebb52` |
| `feat/phase2-ir` | `master` | **Phase 2**：IR + `BlockPaginator`（ADR-003） | **当前实施** |
| `feat/simplify` | `fix` | Phase 1 瘦身（历史） | 已合入 `fix` / `master` |
| `feat/pdf` | `fix` @ `7648036` | PDF 实验（simplify 前快照） | 备查；落后主线 |
| `feat/md` | `fix` @ `7648036` | MD 实验（simplify 前快照） | 备查；落后主线 |

## feat/phase2-ir 范围

**做**（见 [PHASE2_EXIT.md](./PHASE2_EXIT.md)）：`ContentBlock` IR、`BlockPaginator`、pagination 内联图、S2/S3 验收。

**不做**：staging 删除、PDF 主链、WebView、float/多栏排版。

**保留**（Phase 1 交接）：5 intent orchestrator、`PaginationSkin` / staging、`plainText + charOffset` 进度模型。

## feat/simplify 范围（已完成）

**做**：ROADMAP Phase 1；主链仅 **EPUB + TXT**。

**不做**：staging 删除、IR/BlockPaginator。
