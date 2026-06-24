# 功能分支说明

| 分支 | 基线 | 用途 | 状态 |
|------|------|------|------|
| `master` | — | 主开发线 | Phase 2 已合入（2026-06-24） |
| `fix` | `master` | 阅读链 P0/P1 修复 | 待与 `master` 同步 |
| `feat/phase2-ir` | `master` | Phase 2：IR + `BlockPaginator`（ADR-003） | **已合入 master，归档** |
| `feat/simplify` | `fix` | Phase 1 瘦身（历史） | 已合入 `fix` / `master` |
| `feat/pdf` | `fix` @ `7648036` | PDF 实验（simplify 前快照） | 备查；落后主线 |
| `feat/md` | `fix` @ `7648036` | MD 实验（simplify 前快照） | 备查；落后主线 |

## feat/phase2-ir（已归档）

已合入 `master`。验收见 [PHASE2_EXIT.md](./PHASE2_EXIT.md)；遗留项见 **Phase 3 backlog**。

**当前主线**：Phase 3 在 `master` 上继续（预取、排版一致、大章 IR）。

## feat/simplify 范围（已完成）

**做**：ROADMAP Phase 1；主链仅 **EPUB + TXT**。

**不做**：staging 删除、IR/BlockPaginator。
