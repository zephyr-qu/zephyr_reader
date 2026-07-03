---
name: P4 文档债务清理
overview: 对齐 READING_BOUNDARIES v1.2 — 清除 PDF 阅读承诺、更新 doc 索引、修正 rust/README 与主 README 不一致。
todos:
  - id: rust-readme
    content: "rust/README.md 移除 PDF 阅读/解析宣传，改为 Won't 或 internal only"
    status: pending
  - id: doc-readme-index
    content: "doc/README.md 活跃规划指向 Phase4 + archive 过时 pland"
    status: pending
  - id: changelog-unreleased
    content: "CHANGELOG Unreleased 增加文档对齐条目"
    status: pending
  - id: grep-sweep
    content: "全仓 grep PDF阅读/待办 PDF 渲染 残留（排除 rust 内部 parser 目录说明）"
    status: pending
isProject: false
---

# T2 — 文档债务清理

**参与者任务** · 估时 **0.5d** · **仅 Markdown** · 零代码风险

---

## 背景

主 [README.md](../README.md) 已按 D2-A 去掉 PDF 用户承诺，但以下仍不一致：

| 文件 | 问题 |
|------|------|
| [rust/README.md](../rust/README.md) | 仍宣传「PDF 文件解析」「PDF 封面提取」为产品能力 |
| [doc/README.md](../README.md) | `pland.md` 标 P0 活跃，实际已在 `archive/` |
| [issue/READING_CORE_GAP_ANALYSIS.md](../issue/READING_CORE_GAP_ANALYSIS.md) | 写「分页模式无图片」— Phase 2 后已过时 |
| [CHANGELOG.md](../CHANGELOG.md) | Unreleased 可记本轮文档对齐 |

**边界**：`rust/src/parser/pdf/` 代码可保留；文档写 **internal / 非用户功能 / Won't 不投入**。

---

## Step 1 — rust/README.md（30min）

1. 打开 `rust/README.md`
2. 功能列表中 PDF 改为：

   ```markdown
   - **PDF 解析（内部）**：仅导入/metadata 遗留；**无阅读器 UI**，见 READING_BOUNDARIES Won't
   ```

3. 目录树 `pdf/` 注释改为 `内部解析，非阅读主链`
4. 删除「PDF 支持异步解析模式」作为卖点表述（可移到「遗留模块」小节）

---

## Step 2 — doc/README.md 索引（20min）

1. 活跃规划表改为：

   | 文档 | 主题 | 状态 |
   |------|------|------|
   | [discuss/PHASE4_SCOPE.md](../discuss/PHASE4_SCOPE.md) | Phase 4 引擎完善 | **活跃** |
   | [discuss/plans/PHASE4_PARTICIPANT_INDEX.md](../discuss/plans/PHASE4_PARTICIPANT_INDEX.md) | 可并行参与任务 | **活跃** |
   | archive/* | 已完成规划 | 归档 |

2. 删除或下移 `pland.md` P0 行（文件在 `doc/archive/pland.md`）

---

## Step 3 — grep 清扫（30min）

```powershell
cd F:\App\zephyr_reader
rg -i "PDF.*阅读|PDF 渲染|pdf.*reader" --glob "*.md"
```

对每个命中：

- **用户向** → 改 Won't 或删除
- **开发者向**（parser 目录）→ 加「非阅读主链」脚注

**不要改**：`discuss/READING_BOUNDARIES.md` Won't 段（已是真理源）

---

## Step 4 — CHANGELOG（10min）

在 `## [Unreleased]` 增加：

```markdown
### 文档
- 对齐 READING_BOUNDARIES v1.2：rust/README、doc 索引、差距分析过时条目
```

---

## 验收标准

- [ ] `rg "PDF 阅读" README.md rust/README.md` 无用户承诺表述
- [ ] `doc/README.md` 无指向不存在路径的活跃 plan
- [ ] PR 仅 `.md` 文件（允许 CHANGELOG）

---

## 参考

- [discuss/READING_BOUNDARIES.md](../discuss/READING_BOUNDARIES.md) v1.2 Won't
- [discuss/xinxi-round5.md](../discuss/xinxi-round5.md) D2-A
