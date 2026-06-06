# Rust 代码冗余分析报告

> 基于 `chapter_detect.rs` 冗余清理后的全面复查。最后更新: 2026-06-06

***

<br />

***

## P1 - 低风险重复

### 2. `epub/toc.rs` 私有通用字符串工具函数

**位置:** `rust/src/parser/epub/toc.rs:129-160`

```rust
// toc.rs - 三个私有函数，功能通用，并非 EPUB 特有
fn extract_title_from_href(href: &str) -> String  // 路径/URL → 可读标题
fn camel_to_spaces(s: &str) -> String              // "CamelCase" → "Camel Case"
fn capitalize_first(s: &str) -> String             // "hello" → "Hello"
```

**问题:**

- **不可复用** — 其他模块（如 MD 解析中从文件名提取标题）需要类似功能时无法调用
- **不可测试** — 私有函数，无独立测试
- **`capitalize_first`** **接近标准库操作** — 任何人需要时大概率会重写

**建议:** 将 `capitalize_first`（可能 `camel_to_spaces` 一起）提取到 `text/` 模块下的共享 utils 中。其余两个函数可以保持原位，但标记为 `pub(crate)` 以备复用。

***

## P2 - 样板代码重复（可接受）

### 3. `Chapter` 结构体构造重复 6 次

**位置（按构造次数排序）：**

| # | 位置                             | 用途                 |
| - | ------------------------------ | ------------------ |
| 1 | `text/chapter_detect.rs:61-72` | 正则检测到章节标题          |
| 2 | `parser/epub/toc.rs:70-81`     | EPUB TOC 解析        |
| 3 | `parser/epub/toc.rs:112-123`   | EPUB spine 回退生成    |
| 4 | `parser/md/parse.rs:151-162`   | Markdown `##` 标题解析 |
| 5 | `parser/pdf/parse.rs:121-132`  | PDF 按页分组           |
| 6 | `parser/txt/parse.rs:172-182`  | TXT Full Text 兜底   |

**每个构造器都重复：**

```rust
Chapter {
    id: uuid::Uuid::new_v4().to_string(),          // 6/6
    book_id: book_id.to_string(),                   // 6/6
    word_count: 0,                                   // 6/6
    cached_at: chrono::Utc::now(),                   // 5/6（md 缺）
    level: 0,                                        // 6/6
    // 其余字段因上下文不同而各异
}
```

**影响:** 纯样板代码，增加格式切换时的视觉噪音，但不产生逻辑重复。如果新增格式（如 MOBI），开发者需要重新拼一遍同样的字段。

### 4. `Book` 结构体构造重复 4 次

**位置:**

| # | 位置                            |
| - | ----------------------------- |
| 1 | `parser/txt/parse.rs:124-144` |
| 2 | `parser/epub/parse.rs:65-83`  |
| 3 | `parser/pdf/parse.rs:71-91`   |
| 4 | `parser/md/parse.rs:66-86`    |

**每个构造器都重复：**

```rust
Book {
    book_id,           // Uuid::new_v4().to_string()
    file_path,         // 传参
    file_hash: None,   // 4/4
    file_mtime: None,  // 4/4
    cover_path: None,  // 3/4（epub 有封面）
    publisher: None,   // 3/4（epub 有值）
    // ...其他 Optional 字段...
    added_at: chrono::Utc::now(),       // 4/4
    last_opened_at: None,               // 4/4
    status: BookStatus::Reading,        // 4/4
    is_pinned: false,                   // 4/4
}
```

**影响:** 同 Chapter。可考虑提取 `fn default_book()` 或 Builder，但收益有限。

***

## 未发现重复的领域 ✅

### A. 数字转换函数

- `chinese_number_to_int` / `roman_to_int` — 仅存在于 `chapter_detect.rs`，无重复
- 没有使用外部 chinese-number / roman numeral crate

### B. 正则表达式常量

| 位置                      | 正则                                           | 领域             | 状态     |
| ----------------------- | -------------------------------------------- | -------------- | ------ |
| `text/constants.rs`     | `CHAPTER_PATTERN_ZH/EN/DIGIT`, `TAG_PATTERN` | 章节检测 + HTML 标签 | ✅ 集中共享 |
| `text/css.rs`           | CSS 规则/声明/RGB/style 提取                       | CSS 解析         | ✅ 领域内  |
| `parser/md/provider.rs` | Markdown 行内格式                                | MD → HTML      | ✅ 领域内  |

所有正则集中声明，无交叉重复。

### C. 各 Parser 的 `extract_chapter` 接口

四个 parser 都实现了 `async fn extract_chapter(&self, file_path: &str, chapter_index: i32) -> Result<String, AppError>`，通过 `Parser` enum 多态分发。这是**刻意设计的策略模式**，不是代码重复——每个实现的内部逻辑完全不同（TXT 字节切片、EPUB spine 读取、MD comrak 渲染、PDF 按页提取）。

### D. 错误处理

`AppError::chapter_extract_error` 被调用 9+ 次，但每个调用点的 message 各有不同上下文。属于共享 error type 的合理使用。

***

## 总结

| 等级 | 项目                                           | 建议                     |
| -- | -------------------------------------------- | ---------------------- |
| P0 | `txt/parse.rs` fallback 循环                   | ✅ **已清除**              |
| P1 | `epub/toc.rs` 私有通用工具函数（`capitalize_first` 等） | ⬜ 提取到 `text/utils.rs`  |
| P2 | `Chapter` / `Book` 构造器重复                     | 🔲 低优先级，可引入 Builder 模式 |

**P1 的** **`capitalize_first`** **提取是下一件最值得做的事**——它是纯函数、无外部依赖、可能在多处被隐含地需要。其余的都是设计遵从性重复，在 Rust 的 struct literal 文化中是可以接受的。

---

## Appendix: `Chapter.start_index` / `end_index` 语义对照

这两个字段在不同格式和不同代码路径下承载**完全不同的语义**。以下按格式逐一说明。

### TXT

| 路径 | 语义 | 单位 | 值来源 |
|---|---|---|---|
| `chapter_detect.rs` 写入 | 章节标题在解码后内容中的字节偏移 | 字节（UTF-8） | `m.start() as i64` |
| `txt/parse.rs` Full Text 写入 | `start=0`, `end=content.len()` | 字节 | 解码后字符串长度 |
| `txt/mod.rs:extract_chapter` 读取 | `content[start..end]` 切片 | 字节 | DB 读出 |
| `api/core.rs:get_chapter_bounds` 读取 | 返回给 Dart / Provider 路径 | 字节 | DB 读出 |

**关键约束：** 值必须是 UTF-8 字符边界。`txt/mod.rs:extract_chapter`（第 91 行）会在非字符边界上报错返回。

**代码路径：**
- 设置 1 → `text/chapter_detect.rs:extract_chapters_with_pattern` 第 65-66 行
- 设置 2 → `parser/txt/parse.rs:extract_chapters` 第 176-177 行
- 读取 1 → `parser/txt/mod.rs:TxtParser::extract_chapter` 第 82-103 行
- 读取 2 → `api/core.rs:get_chapter_bounds` 第 595 行

---

### EPUB

| 路径 | 语义 | 单位 | 值来源 |
|---|---|---|---|
| `toc.rs:extract_toc_items` 写入 | spine 数组索引（第几个 HTML 资源） | 整数索引 | `find_spine_index_by_toc_href` |
| `toc.rs:generate_chapters_from_spine` 写入 | `start=i`, `end=i+1` | 索引 | enumerate |
| `mod.rs:extract_chapter` 读取 | `spine.get(start)` → href → `read_resource(href)` | 索引 | DB 读出 |
| `parse.rs:read_chapter_content` 读取 | `spine[start..end]` 合并读取 | 索引范围 | DB 读出 |
| `provider.rs:open` 读取 | `spine[start..end]` 合并读取 | 索引范围 | DB 读出 |

**关键约束：** `end_index` 是专为 EPUB 设计的**半开区间**——读取 `spine[start..end]`（包含 start，不包含 end）。`toc.rs` 排序后按相邻 `start_index` 填充 `end_index`，确保 TOC 未列出的分片资源被合并到前一个章节。

**代码路径：**
- 设置 1 → `parser/epub/toc.rs:extract_toc_items` 第 74-75 行（初始），第 99 行（计算 end）
- 设置 2 → `parser/epub/toc.rs:generate_chapters_from_spine` 第 116-117 行
- 读取 1 → `parser/epub/mod.rs:EpubParser::extract_chapter` 第 95 行
- 读取 2 → `parser/epub/parse.rs:read_chapter_content` 第 144-145 行
- 读取 3 → `parser/epub/provider.rs:open` 第 53-54 行

---

### MD

| 路径 | 语义 | 单位 | 值来源 |
|---|---|---|---|
| `md/parse.rs` 写入 | **无意义**，恒为 `start=0, end=0` | — | 常量 |

MD 解析基于 `##` 标题做内容分割，章节自带文本内容。`start_index/end_index` 从不被读取——DB 中的 0 值不会被任何消费者使用。

**代码路径：**
- 设置 → `parser/md/parse.rs:extract_chapters` 第 159-160 行
- 读取 → 无

---

### PDF

| 路径 | 语义 | 单位 | 值来源 |
|---|---|---|---|
| `pdf/parse.rs` 写入 | 页码范围（`start_page`, `end_page`） | 页码 | `chapter_index * PAGES_PER_CHAPTER` |

PDF 的 `extract_chapter`（`mod.rs` 第 94-95 行）**不读取 start_index/end_index**，而是直接根据 `chapter_index * DEFAULT_PAGES_PER_CHAPTER` 计算页码。这两个字段只在测试中断言使用。

**代码路径：**
- 设置 → `parser/pdf/parse.rs:generate_chapters` 第 129-130 行
- 读取 → 仅测试 `parser/pdf/parse.rs:176-182`

---

### API 层消费路径

`api/core.rs` 中有两套路径使用这些字段：

#### 路径 A：旧路径 — `get_chapter` → `Parser::extract_chapter`
- 不经过 start_index/end_index 解析，直接调用格式对应的 `extract_chapter()` 方法
- 各格式内部自行解释这些字段（TXT 切片、EPUB spine 索引、PDF 不读）

#### 路径 B：新路径 — `get_paginated_chunk` → `ChapterContentProvider::read_text_range`
- TXT/MD：`get_chapter_bounds` 从 DB 读出 (start, end)，作为**文件字节偏移**传给 provider
- EPUB：**不读 DB**，直接 `chunk_index * PAGINATION_CHUNK_SIZE` 作为 0-based 纯文本偏移
- PDF：不走此路径

```rust
// api/core.rs:676-688 — 两种偏移计算方式
if format == BookFormat::Epub {
    (chunk_index * CHUNK_SIZE, ...)  // 0-based 纯文本偏移
} else {
    let (chapter_start, chapter_end) = get_chapter_bounds(...);  // 文件字节偏移
    (chapter_start + chunk_index * CHUNK_SIZE, ...)
}
```

---

### 总结：语义不一致风险

| 格式 | `start_index` 实际含义 | 读取方是否理解此含义 |
|---|---|---|
| TXT | 字节偏移 | ✅ 是（txt/mod.rs, provider） |
| EPUB | spine 索引 | ✅ 是（epub/mod.rs, parse.rs, provider） |
| MD | 恒为 0，无用 | ⚠️ 无人读取，无害 |
| PDF | 页码 | ⚠️ 无人读取，无害 |

**MD 和 PDF 的字段是死数据**——写入后从不读取。如果需要统一语义或为 MD 启用 Provider 路径，需要额外处理。

---

## Appendix B: `level` / `word_count` 存活分析

### `level` — EPUB 多级目录用，其他格式存默认值

| 设置位置 | 值 | 含义 |
|---|---|---|
| `text/chapter_detect.rs` | `0` | TXT 章节无层级 |
| `parser/txt/parse.rs` | `0` | Full Text 兜底 |
| `parser/epub/toc.rs:extract_toc_items` | `*level as i64` | EPUB TOC 实际层级（1-based） |
| `parser/epub/toc.rs:generate_chapters_from_spine` | `0` | spine 回退生成 |
| `parser/md/parse.rs` | `0` | MD 基于 `##` 标题，无层级 |
| `parser/pdf/parse.rs` | `0` | PDF 按页分组，无层级 |

**消费方：** `lib/features/reader/page/widgets/chapter_list_widget.dart`（第 94, 210 行）
- `(chapter.level - 1).clamp(0, 4)` — 多级缩进
- `chapter.level <= 1` — 是否显示章节编号前缀

对于 EPUB 之外的格式，`level = 0` 产生 `indent = 0, showNumber = true`，是正确默认行为。**不是死数据。**

### `word_count` — 全局只写不读，且 MD 一处赋值语义错误 🔴

| 设置位置 | 值 | 含义 |
|---|---|---|
| `text/chapter_detect.rs` | `0` | 占位 |
| `parser/txt/parse.rs` | `0` | TXT Full Text 兜底 |
| `parser/epub/toc.rs:extract_toc_items` | `0` | EPUB TOC 解析 |
| `parser/epub/toc.rs:generate_chapters_from_spine` | `0` | EPUB spine 回退 |
| `parser/pdf/parse.rs` | `0` | PDF 按页分组 |
| `parser/md/parse.rs` | `text.len() as i64` | **字节长度，不是词数也不是字符数** |

`parser/md/parse.rs:151` 是唯一设非零值的地方——但 `text.len()` 是 UTF-8 **字节长度**（中文字 1 字=3 字节），存到名为 `word_count` 的字段里语义完全不对。而且即便存了，也**从未被任何代码读取过**。

**查询结果：** Rust 侧没有任何 `.word_count` 读取（仅 SQL upsert 写入 DB）。Dart 侧无匹配。

**结论：死数据，且 MD 处的赋值是误导性的。** 如果未来需要统计章节字数，应该用 `text.chars().count()` 或者独立的字数统计算法，而不是 `text.len()`。
