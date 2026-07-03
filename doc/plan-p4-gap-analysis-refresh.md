---
name: P4 差距分析文档刷新
overview: 修订 issue/READING_CORE_GAP_ANALYSIS.md 中与 Phase 2/3 及 round5 决策冲突的条目，文首加「过时段落」指引。
todos:
  - id: banner
    content: "文首增加：以 READING_BOUNDARIES + PHASE4_SCOPE 为准"
    status: pending
  - id: fix-pagination-image
    content: "修正「分页模式无 EPUB 图片」为已实现"
    status: pending
  - id: fix-chapter-search
    content: "章内搜索标为 Won't（D4-C）"
    status: pending
  - id: fix-pdf-p1
    content: "PDF P1 改为 Won't 不投入"
    status: pending
  - id: update-conclusion
    content: "重写 §十四结论：剩余项对齐 Phase 4 backlog"
    status: pending
isProject: false
---

# T3 — 差距分析文档刷新

**参与者任务** · 估时 **0.5d** · **仅文档** · 减少新人误导

---

## 目标文件

[issue/READING_CORE_GAP_ANALYSIS.md](../issue/READING_CORE_GAP_ANALYSIS.md)（初版 2026-06-11，复核 2026-06-16）

---

## 必须修正的已知错误

| 位置（约） | 旧表述 | 新表述 |
|------------|--------|--------|
| §二 图片内嵌 | pagination **未接入** | Phase 2/3 块分页已支持；scroll 仍 rich/IR 过渡 |
| §十四 P1 #1 | PDF UI 待接线 | **Won't**（D2-A）；不列 P1 |
| §十四 P1 #3 | 笔记同步类型 | 降为 P2 或标注「WebDAV 备份范围，非多端同步」 |
| Should 章内搜索 | 缺失 | **Won't**（D4-C）；全书搜索覆盖 |
| 覆盖率 87% | 静态数字 | 改为「见 PHASE4_SCOPE；本表仅主流对比参考」 |

---

## 文首模板（复制粘贴）

```markdown
> **⚠️ 状态（2026-06-25）**  
> 本文件为 **2026-06 主流阅读器对比快照**，非实施真理源。  
> **产品边界** → [discuss/READING_BOUNDARIES.md](../discuss/READING_BOUNDARIES.md) v1.2  
> **当前 backlog** → [discuss/PHASE4_SCOPE.md](../discuss/PHASE4_SCOPE.md)  
> **引擎状态** → [issue/CORE_READING_CHAIN_STATUS.md](./CORE_READING_CHAIN_STATUS.md)
```

---

## §十四 结论重写建议

**仍缺失（与 Phase 4 对齐）** — 示例：

1. Scroll 统一 IR（P4-1，进行中）
2. IR 块基础 CSS 跨模式一致（P4-2）
3. Staging 零可见 loading（P4-3）
4. Metrics 回传校准（P4-4）
5. 双语 feature 模块边界（P4-5）
6. （可选 P2）多色高亮选择器、屏幕常亮、翻页速度…

**明确移出列表**：PDF 阅读 UI、章内搜索、云盘直同步

---

## 验收标准

- [ ] 文首 banner 存在
- [ ] 无「分页模式无图片」矛盾表述
- [ ] PDF 不在 P1 缺失列表
- [ ] 不删除历史对比表（保留作参考），用 ~~删除线~~ 或 **已过时** 标注行

---

## 不要改

- `discuss/` 下 ADR（真理源）
- 代码
