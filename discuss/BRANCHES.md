# 功能分支说明

| 分支 | 基线 | 用途 |
|------|------|------|
| `fix` | main | 阅读链 P0/P1 修复与架构文档 |
| `feat/simplify` | `fix` | **Phase 1 瘦身**：单 plain 路径、gate EPUB rich、移除 PDF/MD |
| `feat/pdf` | `fix` | PDF 实验（已自 simplify 剥离，保留分支备查） |
| `feat/md` | `fix` | MD 实验（已自 simplify 剥离，保留分支备查） |

## feat/simplify 范围

**做**：ROADMAP Phase 1；主链仅 **EPUB + TXT**。

**不做**：staging 删除、IR/BlockPaginator。
