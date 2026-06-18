# 目标架构（North Star）

> 对齐 `appendix01`–`03` 与你的第二轮选择。  
> **现状 ≠ 目标**；本文描述终态，供后续阶段对照，不要求本周实现。

---

## 1. 职责划分（建议 G7 答案）

| 层 | 职责 | 不做 |
|----|------|------|
| **Rust** | 解析 → **IR (ContentBlock[])** → 块分页 → 缓存 → 图片管道（路径/缩略） | UI 状态、动画 |
| **Flutter** | 视口、signals、按页拉块、Text/Image 渲染、staging 触发 | 全书分页算法、HTML 解析 |

这与 appendix01「Heavy Logic in Rust, Reactive UI in Flutter」一致，**推荐作为 G7 默认方案**。

---

## 2. 统一 IR（异构输入，一种中间表示）

```
EPUB ──► 解析 HTML ──┐
                     ├──► Vec<ContentBlock> per chapter
TXT  ──► 编码+分段 ──┘

ContentBlock:
  - Text { spans, block_style }
  - Image { asset_id, alt }   // 字节懒加载
  - Spacer / Heading / ...    // 按需扩展
```

TXT 与 EPUB **分页引擎只认 IR**，解决「双真理源」中的加载分裂。

---

## 3. 数据流（三章）

### 阶段 A — 解析索引（不重分页）

- 输出：章元数据 + IR 或 IR 磁盘索引
- 与现 `Provider` / `getChapter` 可演进衔接

### 阶段 B — 按需分页

- 输入：IR + `TypesetConfig` + viewport → `config_hash`
- 输出：`PageInfo[]`（每页 = 块 id 范围 + 布局元数据）
- 缓存：现有 layout KV / sled 思路可复用

### 阶段 C — 渲染

- Flutter 要第 N 页 → Rust 返回块列表 + 文本切片
- 图片 → `get_image(asset_id, width)` → 本地路径 → `Image.file`

---

## 4. 与现状差距（诚实清单）

| 现状 | 目标 |
|------|------|
| 分页吃 plain string，`RichTextConverter` 丢图 | 分页吃 IR，含 Image 块 |
| scroll 用 `RichParagraph`，分页另一套 | 解析一次 → IR → scroll 可转 TextSpan，分页用块 |
| Orchestrator 5 intent + contentFuture 并行 | 单章加载状态机 + staging 性能层 |
| `PageStreamer` 行切 plain | 逐步由 `BlockPaginator` 替代（TXT 可先适配 IR） |

---

## 5. 图片跨页（你已写的规则）

```
剩余页高 >= 缩放后图高  → 插入当前页
否则                    → 独占一页（缩小 contain）
```

不支持 float 绕排 → Won't，与边界一致。

---

## 6. 换章丝滑（staging 在架构中的位置）

```
用户翻到末页 → 已预取 next 章 PageInfo[0] + 首屏块
用户翻到首页 → 已预取 prev 章末页
```

staging 缓存的是 **下一章分页结果/首屏块**，不是替代 ADR-001 的进度模型。

---

## 7. 加载策略（appendix03 采纳）

| 策略 | 采纳 |
|------|------|
| 按章分块 | ✅ |
| 懒加载（页/图） | ✅ |
| 相邻章预取 | ✅（G2-b） |
| 流式 TXT | 超大 TXT 再做 |
| 零拷贝 | 暂不 |

---

## 8. 建议否定的路线

- **WebView 分页**：已 Won't
- **纯 Flutter TextPainter 分页为主**：与现有 Rust 投资重复，除非 Rust IR 证伪
- **继续 plain PageStreamer 上堆图片**：违反 ADR-003
