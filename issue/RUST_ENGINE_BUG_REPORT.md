# Rust Engine Bug Report

> 审查日期: 2026-06-13
> 范围: `rust/src/` 全部 77 个 `.rs` 文件

---

## 严重 Bug（可能崩溃/死循环/数据损坏）

### 1. 断行算法无限循环 — `compute_line_breaks_from_indices`

**文件:** `rust/src/text/pagination.rs:72-81`

```rust
if end == start {
    end = start + 1;  // 至少一字符一行
}

if end < char_count && end > start {
    let next_char = para_char_indices[end].1;
    if is_start_avoid_punctuation(next_char) {
        end -= 1;  // 前移避开禁首标点
    }
}
```

**触发条件:** 当某行只包含 **1 个字符**（`end == start + 1`），且该行的下一个字符是禁首标点（如 `。`、`，`、`！`等）时：

1. `end = start + 1` (强制至少 1 字符)
2. 禁首标点检查命中，`end -= 1` → `end = start`
3. 下一轮 while 循环: 内层 for 再次推进到 `end = start + 1`
4. → 无限循环，永远无法跳出

**影响:** 遇到特定排版参数（窄宽度、大字号）且文本恰好以禁首标点开头时，该线程 100% CPU 永久卡死。`spawn_blocking` 线程池被耗尽。

**修复方向:** 禁首标点回退时须保证 `end > start`；若 `end == start` 则放弃本次回退。同时外层加迭代上限作为熔断。

---

### 2. FTS5 搜索查询转义被破坏 — `escape_fts5_query`

**文件:** `rust/src/search/engine.rs:284-306`

```rust
fn escape_fts5_query(query: &str) -> String {
    const SPECIAL: &[char] = &['"', '*', '^', '~', '+', '-', '(', ')', '>', '<'];
    for c in query.chars() {
        if SPECIAL.contains(&c) {
            result.push('"');
            if c == '"' { result.push('"'); }  // FTS5 中 "" 是转义
            else { result.push(c); }
            result.push('"');
        } else {
            result.push(c);
        }
    }
}
```

每个特殊字符被独立包裹在 `"..."` 中。这将 FTS5 的操作符语义完全改变：

| 输入 | 实际输出 | 本意 |
|------|---------|------|
| `hello+world` | `hello"+"world` | 搜索 helloworld (AND)? |
| `"exact phrase"` | `""exact phrase""` | 短语搜索 |
| `hello -bad` | `hello "-"bad` | 排除 bad |
| `(cat OR dog)` | `"("cat" "OR" dog")"` | OR 查询 |

**影响:** 所有使用 FTS5 操作符（`+`, `-`, `"`, `(`, `)`, `*`, `^`, `~`）的搜索行为完全错误。对纯中文单词语义影响较小（jieba 分词后再 escape 的操作符意义不大），但对英文搜索或混合搜索的精确匹配、排除、短语搜索等功能完全不可用。

**修复方向:** 用 FTS5 的 `^` prefix 或完全包裹整个查询为短语的双引号方案（而非包裹每个字符）。正确的做法是：对包含操作符的高级查询，要么 valid 的 FTS5 语法直接透传，要么将整个查询作为短语处理。

---

## 中等 Bug（结果不正确/性能问题）

### 3. Rich Text DOM 遍历双重处理

**文件:** `rust/src/text/rich_text.rs:228-254`

```rust
"p" | "div" | "section" | "article" => {
    let mut spans = Vec::new();
    collect_text_spans(handle, &mut spans, &merged_style, style_map);
    // ^^ 将 handle 下所有子节点文本收集到 spans

    if !spans.is_empty() {
        paragraphs.push(RichParagraph { .. });  // 创建段落
    }

    for child in node.children.borrow().iter() {
        traverse_dom(child, paragraphs, None, &merged_style, style_map);
        // ^^ 递归处理每个子节点 → 对于嵌套块元素(如 div>p)会重复创建段落
    }
}
```

`collect_text_spans(handle, ...)` 已经遍历了整个子树收集文本，然后 `traverse_dom` 递归又对每个子节点调用了同样的流程。

**影响:** 对结构如 `<div><p>text</p><p>more</p></div>`，`collect_text_spans` 将两个 `<p>` 的文本合并到 `<div>` 的一个段落中，然后递归 `traverse_dom` 对每个 `<p>` 又各创建了一个段落。结果:

- `<div>` 段落: "textmore" (本不应该生成段落)
- `<p>` 段落 1: "text" ✅
- `<p>` 段落 2: "more" ✅

实际输出段落数多于预期，且 `<div>` 段落合并了所有子文本。

**修复方向:** 对块级元素，要么只在 `traverse_dom` 层次创建段落（去掉 `collect_text_spans`），要么只递归处理（去掉在 `traverse_dom` 层面直接创建）。不能同时走两条路径。

---

### 4. Lazy 模式 `get_page_offsets` 返回字符索引而非字节偏移

**文件:** `rust/src/text/pagination.rs:423-435`

```rust
// lazy 模式分支
let start = page_idx * chars_per_page;
let end = (start + chars_per_page).min(self.content.len());
//    ^^^^^ chars_per_page 是字符数，content.len() 是字节数 — 单位不匹配
offsets.push(PageOffset {
    offset: start as i32,   // 字符索引作为字节偏移返回
    length: (end - start) as i32,
});
```

对比 `get_page_lazy` (行 332-361) 正确的做法：
```rust
let byte_start = self.char_boundaries.get(char_start).copied().unwrap_or(self.content.len());
let byte_end = self.char_boundaries.get(char_end).copied().unwrap_or(self.content.len());
```

**影响:** 对包含多字节 UTF-8 字符（CJK）的文本，`get_page_offsets` 返回的 `offset`/`length` 是字符索引而非字节偏移。Dart 侧用这些值去索引文本时得到的是错误位置。对于纯 ASCII 文本无影响。

**修复方向:** lazy 模式分支也应通过 `char_boundaries` 转换字符索引为字节偏移。

---

### 5. Lazy 分页阈值使用字节长度而非字符数

**文件:** `rust/src/text/pagination.rs:133-138`

```rust
let content_len = content.len(); // ← 字节数
if content_len > LAZY_PAGINATION_CHAR_THRESHOLD {
    // LAZY_PAGINATION_CHAR_THRESHOLD = 50_000 (字符数)
    return Self::new_lazy(content, config);
}
```

**影响:** 对 CJK 文本（UTF-8 下每字符 3 字节），50K 字节 ≈ 16.7K 字符，远低于 50K 字符的预期阈值。导致 CJK 书籍过早进入 eager 模式，50K 字节对应约 17K CJK 字符时也触发 eager，消耗更多内存。对纯 ASCII 文本阈值正确。

**修复方向:** 使用 `content.chars().count()` 或至少用 `content.len() / 3` 估算。

---

### 6. `format_from_extension` 未知格式静默转为 TXT

**文件:** `rust/src/api/core.rs:714-726`

```rust
match ext {
    "txt" | "text" => BookFormat::Txt,
    "epub" => BookFormat::Epub,
    "md" | "markdown" | "mdown" | "mkdn" => BookFormat::Md,
    "pdf" => BookFormat::Pdf,
    _ => BookFormat::Txt,  // ← .mobi/.azw3/.djvu/.cbr 全部静默当作 TXT
}
```

**影响:** 不支持的文件格式被当作纯文本打开，用户看到乱码或解析错误，无明确提示 "格式不支持"。

**修复方向:** 对未知扩展名返回错误 `UnsupportedFormat`，或至少在日志中警告。

---

### 7. `is_cjk_punctuation` 范围过宽包含全宽拉丁字母

**文件:** `rust/src/text/constants.rs:81-93`

```rust
pub fn is_cjk_punctuation(c: char) -> bool {
    let cp = c as u32;
    (0x3000..=0x303F).contains(&cp)
    || (0xFE30..=0xFE4F).contains(&cp)
    || (0xFE10..=0xFE1F).contains(&cp)
    || (0xFF00..=0xFFEF).contains(&cp)  // ← 包含全宽拉丁字母 Ａ-Ｚ 和 ａ-ｚ
    || matches!(c, '·' | '～' | '×' | '÷')
}
```

`0xFF00..=0xFFEF` (Halfwidth and Fullwidth Forms) 中，`0xFF21`-`0xFF3A` 是全宽 A-Z，`0xFF41`-`0xFF5A` 是全宽 a-z，这些是字母，不是标点。

**影响:** `compute_line_breaks_from_indices` 中的标点挤压逻辑（`char_width *= 0.65`）错误地对全宽字母应用了 65% 宽度压缩。排版结果不正确。

**修复方向:** 检查时排除 `0xFF21..=0xFF3A` (全宽大写拉丁) 和 `0xFF41..=0xFF5A` (全宽小写拉丁)。

---

## 轻微 Bug

### 8. 冗余 `.to_owned()` 克隆

**文件:** `rust/src/api/core.rs:189`

```rust
Ok(text.to_owned())  // text 已经是 String
```

`extract_chapter_content` 中的 `text` 已是从 `parser.extract_chapter()` 返回的 `String`。`.to_owned()` 复制了整个字符串。

---

### 9. `#[warn]` 属性不生效

**文件:** `rust/src/api/bilingual.rs:116`

```rust
#[warn(clippy::too_many_arguments)]  // 应为 #[allow]
pub async fn create_bilingual_highlight_pair(
```

`#[warn]` 是默认行为，不抑制任何警告；需要 `#[allow]` 或 `#[expect]` 才能静默该 lint。

---

### 10. FTS5 索引存储 `chapter_index` 为文本但查询时 `CAST`

**文件:** `rust/src/search/engine.rs:98,112,145,219`

索引写入时：`.bind(chapter_index.to_string())` — 存储为 TEXT
搜索查询时：`CAST(chapter_index AS INTEGER)` — 转为整数比较

SQLite 的灵活类型系统下这 "能工作"（TEXT `"1"` 等效于 INTEGER `1`），但每个查询行需要运行时类型转换，性能损失可忽略，但类型不一致是代码异味。

---

### 11. 章节缓存对 Provider 路径为死代码

**文件:** `rust/src/api/core.rs:134-190`

`try_read_cached_chapter` / `write_chapter_cache` 仅在 `extract_chapter_content` 中被调用。但 `extract_chapter_content` 仅被 `paginate_all_content` 和 `get_chapter` 的 fallback 路径（非 TXT/MD/EPUB）使用。对 TXT/MD/EPUB（目前所有支持的格式），章节内容通过 Provider 的 `read_text_range` 直接读取，缓存不会被写入。

章节缓存目录 `data/chapters/{book_id}/{chapter_index}.txt` 永远不会被创建。如果这是有意设计（Provider 自带缓存），应删除这几百行死代码。

---

### 12. CRLF 文本 `paginate_chunk` 偏移量错误

**文件:** `rust/src/api/core.rs:767-777`

```rust
let page_text = chunk.join("\n");  // 以 LF 连接
let page_len = page_text.len() as u64;
acc_offset += page_len;
```

`text.lines()` 剥离 `\r` 和 `\n`，`join("\n")` 只插入单一 `\n`。对于 CRLF 文件，原始文本中每行末尾多一个 `\r` 字节，导致 `acc_offset` 累积值小于实际文件字节偏移。

**影响:** 打开 CRLF 格式的 TXT/MD 文件时，分页偏移量偏小。

---

### 13. `config_hash` 未稳定包含 `hyphenation_language`

**文件:** `rust/src/domain/types/typeset.rs:281`

```rust
if let Some(ref lang) = self.hyphenation_language {
    bytes.extend_from_slice(lang.as_bytes());
}
```

仅当 `hyphenation_language` 为 `Some` 时将其加入哈希。逻辑上这产生正确的区分：`None` 和 `Some("")` 没有区别。但如果未来有两个相同的配置但一个显式设置语言一个未设置，它们的哈希可能意外相同。当前无实际影响。

---

### 14. `sqlx::Error` 转换丢失错误分类信息

**文件:** `rust/src/domain/error.rs:199-205`

```rust
impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        Self::DatabaseError { reason: err.to_string() }
    }
}
```

`sqlx::Error` 有多种变体 (`PoolClosed`, `Database`, `Protocol`, `RowNotFound` 等)，但全部抹平为单一的 `DatabaseError` 字符串。调试时无法区分是连接问题还是查询问题。

---

## 死代码 & 未使用导出

### 15. `create_page_streamer` 标记 DEAD CODE 但有 FRB 绑定

**文件:** `rust/src/api/core.rs:580`

```rust
// DEAD CODE: Dart 侧无调用，当前走 paginateAllContent
#[frb]
pub async fn create_page_streamer(...)
```

公开 FRB 导出但在 Dart 侧没有调用者。每次 Dart 构建都会生成无用的 FFI 绑定。

### 16. `get_paginated_chunk` 标记 DEAD CODE 但有 FRB 绑定

**文件:** `rust/src/api/core.rs:792-793`

```rust
// DEAD CODE: Dart 侧无调用
#[frb]
pub async fn get_paginated_chunk(...)
```

同上，公开但无调用方。

### 17. 注释掉的测试代码

**文件:** `rust/src/search/engine.rs:308-315`、`rust/src/api/bilingual.rs:248-336`

两处测试代码被大块注释而非条件编译 `#[cfg(test)]`。代码仍可编译，但测试脱离运行覆盖。

---

## 总结

| 严重程度 | 数量 | 关键影响 |
|---------|------|---------|
| 严重 | 2 | 断行死循环、FTS5 查询破坏 |
| 中等 | 5 | 富文本段落重复、偏移量错误、格式误判、字体排版错误 |
| 轻微 | 7 | 冗余 clone、lint 属性、类型不一致、死代码 |

**最紧急:** Bug #1（断行死循环）可能在特定文本+排版参数下 100% 卡死阅读器进程，且 `spawn_blocking` 耗尽所有 Tokio 线程。Bug #2（FTS5 escape）对英文混合搜索的高级功能完全破坏。

**下一步建议:** 先确认 Bug #1 和 #2 的修复方案，然后批量修复中等级别问题。
