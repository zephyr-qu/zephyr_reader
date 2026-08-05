# 阅读器排版引擎优化与功能评估

> **已终止路线**：本文讨论 Rust/Flutter 自研文本引擎和 TXT 排版。当前 EPUB Readium MVP 不执行本文待办；如需恢复，必须重新更新边界、路线和 ADR。

## 背景

Rust 侧 `text/` 模块经多轮重构后已拆除，功能迁移到 Flutter `reader_engine` 模块。本文档评估 README 中列出的但尚未完备的功能，以及 Flutter 侧分页/装箱管线的优化机会。

---

## Phase 13 — Flutter 排版管线优化（规划中）

### 装箱/渲染管线 4 段

| 阶段 | 位置 | 耗时（100KB 章） | 瓶颈 |
|------|------|------------------|------|
| IR fetch | Rust redb（持久化） | ~1ms | 已缓存 |
| 断行 | `line_break_extractor.dart` | 80-200ms | TextPainter 主 isolate |
| 装箱 | `_PagePacker` | 50-150ms | 逐块累积高度 |
| 渲染 | `block_page_content.dart` | UI 帧 | 图片 decode 主 isolate |

### 优化项

#### 1. 图片解码移到后台 isolate 🔶 中收益 / 中成本

**问题**：`EpubBlockImage` 在 build 阶段通过 `dart:ui decodeImageFromList` 在主 isolate 解码。图片密集的 EPUB（插图文学书/漫画）翻页时 UI jank。

**做法**：`_EpubBlockImageState` 中把 decode 推到后台 isolate，返回 `ui.Image` 再 setState。

**收益**：图像类 EPUB 翻页不卡。常速翻页无感时收益低。

#### 2. `sliceRichSpans` 预索引 🔷 低收益 / 低成本

**问题**：EPUB 富文本有数千个 `ReaderInlineRun`，当前每次 `flushSlice()` 都线性扫描 `block.runs`。

**做法**：`_TextPackContext.create()` 时用二分查找定位切片范围，避免每页线性扫描。

**收益**：EPUB 富文本章节分页提速约 5-15%。纯文本 TXT 无影响。

#### 3. 大 TXT 切窗边界优化 🔷 低收益 / 低成本

**问题**：切窗只认 `\n` 作为边界。TXT 文件通常无段落换行，永远硬切 4000 字符。

**做法**：加中文句号 `。` 和英文句号 `.` 作为备选切窗边界。

**收益**：大 TXT 段落排版更一致（不截断在句子中间）。对性能无直接影响。

---

## 中英文混排优化

### 现有基础

`ReaderRenderConfig` 已实现：

- CJK 字体回退栈（PingFang SC, Microsoft YaHei, Noto Sans CJK SC 等）
- `TextAlign.justify` 两端对齐
- `forceStrutHeight` + `textHeightBehavior` 行盒一致
- IR 块级样式（heading 缩放、首行缩进、段间距）

### 缺失部分

| 优化点 | 改动范围 | 难度 |
| -------- | ---------- | ------ |
| CJK/Latin 字距微调 | `ir_text_block_style.dart` 按脚本拆 TextSpan 设不同 `letterSpacing` | 中 |
| 两端对齐字间距 `wordSpacing` | `reader_render_config.dart` 加一行 | 低 |
| 标点挤压（全角→半角压缩） | `RichTextConverter` 替换 | 低 |

主要工作量在于拆分文本段后测一遍断行，确保分页页码不偏移。改动集中在 `IrReaderIrBlock` 和 `RichTextConverter`，不涉及 `_PagePacker` 核心算法。

### 结论

| 维度 | 评估 |
| ------ | ------ |
| **难度** | 中低 |
| **收益** | 中 — 中英夹杂多的技术书籍观感改善；纯中文/纯英文书差别不大 |
| **决定** | 非当前 MVP 范围，排队后续迭代 |

---

## 英文连字支持（Hyphenation）

### 现状

未实现。Flutter 无原生断字 API。

### 可行方案

| 方案 | 问题 |
| ------ | ------ |
| `\u00AD` 软连字 + `TextPainter` | Flutter 在 `\u00AD` 处断开但**不渲染连字符 `-`** |
| 手动拆词插 `-\n` | 词长度改变 → `line_break_extractor` 断点偏移 → `_PagePacker` 字符计数错位 |
| Rust `hyphenation` crate + IR 标记 | 需要 FRB 扩展类型 + IR 管线改动 |

无论哪条路，都穿透整个阅读栈：

```
IR 管线 (Rust) → FRB → line_break_extractor → _PagePacker → 渲染
    ↑                                                   ↑
  必须标记可断点                              断字后字符偏移全变
```

断字规则还是语言相关的（英语/德语/法语不同模式）。

### 结论

| 维度 | 评估 |
| ------ | ------ |
| **难度** | 高（穿透整个渲染栈） |
| **收益** | 极低 |
| **决定** | **跳过，不实现** |

原因：核心读者是中文用户；英文内容主要为短标题/元数据/UI，极少长词；主流中文阅读器（微信读书/iReader）也未实现此功能。

---

## 布局缓存（Flutter 侧持久化）

已分析（2026-07）。

当前 Rust redb 缓存 IR（解析后的结构化块），Flutter 内存缓存当前章分页结果。相邻章通过 `PaginationStagingStore` 预装箱。

| 维度 | 评估 |
| ------ | ------ |
| **必要性** | 低 |
| **实现成本** | 高（`PackedPage[]` 序列化 + 版本化 + 渲染配置变更时失效） |
| **收益** | 低（staging 已覆盖相邻章导航） |
| **决定** | **不需要** |
