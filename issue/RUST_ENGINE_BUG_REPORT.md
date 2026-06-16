# Rust Engine Bug Report

> 审查日期: 2026-06-13
> 复核日期: 2026-06-16
> 范围: `rust/src/` 全部 77 个 `.rs` 文件

***

## 严重 Bug（可能崩溃/死循环/数据损坏）

***

###

## 中等 Bug（结果不正确/性能问题）

###

<br />

***

###

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

**复核 (2026-06-16):** ❌ 未修复

- `core.rs:841-852` 仍为 `match ext { ... _ => BookFormat::Txt }` 静默 fallback
- `AppError::UnsupportedFormat` 错误变体已在 `error.rs:28-29` 定义，但全项目 0 处使用
- 用户打开 .mobi / .azw3 / .djvu / .cbr 仍会得到乱码或解析错误，无明确错误提示
- 风险等级：实际触发率取决于用户导入习惯（移动端 / PC 端常用 .epub 较少遇到）；但用户支持场景下不可接受

***

<br />

## 轻微 Bug

### 8. 冗余 `.to_owned()` 克隆

**文件:** `rust/src/api/core.rs:189`

```rust
Ok(text.to_owned())  // text 已经是 String
```

`extract_chapter_content` 中的 `text` 已是从 `parser.extract_chapter()` 返回的 `String`。`.to_owned()` 复制了整个字符串。

**复核 (2026-06-16):** ❌ 未修复

- `core.rs:236` 仍为 `Ok(text.to_owned())`
- 移除 `.to_owned()` 即可（`text` 已经是 `String`）

***

### 9. `#[warn]` 属性不生效

**文件:** `rust/src/api/bilingual.rs:116`

```rust
#[warn(clippy::too_many_arguments)]  // 应为 #[allow]
pub async fn create_bilingual_highlight_pair(
```

`#[warn]` 是默认行为，不抑制任何警告；需要 `#[allow]` 或 `#[expect]` 才能静默该 lint。

**复核 (2026-06-16):** ❌ 未修复

- `bilingual.rs:116` 仍为 `#[warn(clippy::too_many_arguments)]`
- 意图应是抑制警告，应改 `#[allow(...)]` 或 `#[expect(...)]`
- 影响：编译时 `too_many_arguments` lint 仍会触发，但因 `#[warn]` 是默认级别，行为上等同于无属性

***

### 10. FTS5 索引存储 `chapter_index` 为文本但查询时 `CAST`

**文件:** `rust/src/search/engine.rs:98,112,145,219`

索引写入时：`.bind(chapter_index.to_string())` — 存储为 TEXT
搜索查询时：`CAST(chapter_index AS INTEGER)` — 转为整数比较

SQLite 的灵活类型系统下这 "能工作"（TEXT `"1"` 等效于 INTEGER `1`），但每个查询行需要运行时类型转换，性能损失可忽略，但类型不一致是代码异味。

**复核 (2026-06-16):** ❌ 未修复

- `engine.rs:98,112,145,211,219` 仍维持 TEXT 存储 + CAST 读取的不一致模式
- 文档原评：性能影响可忽略，仅代码异味

***

### 11. 章节缓存对 Provider 路径为死代码

**文件:** `rust/src/api/core.rs:134-190`

`try_read_cached_chapter` / `write_chapter_cache` 仅在 `extract_chapter_content` 中被调用。但 `extract_chapter_content` 仅被 `paginate_all_content` 和 `get_chapter` 的 fallback 路径（非 TXT/MD/EPUB）使用。对 TXT/MD/EPUB（目前所有支持的格式），章节内容通过 Provider 的 `read_text_range` 直接读取，缓存不会被写入。

章节缓存目录 `data/chapters/{book_id}/{chapter_index}.txt` 永远不会被创建。如果这是有意设计（Provider 自带缓存），应删除这几百行死代码。

**复核 (2026-06-16):** ❌ 未修复

- `core.rs:181,198,226-237` `try_read_cached_chapter` / `write_chapter_cache` / `extract_chapter_content` 仍存在
- 调用关系：`extract_chapter_content` 在 `core.rs:227,234` 调用缓存读写；其本身被 `paginate_all_content` / `get_chapter` fallback 调用
- 当前支持格式（TXT/MD/EPUB）走 Provider 路径，缓存不写入
- 与文档原评一致：死代码 / 几百行冗余

***

### 12. CRLF 文本 `paginate_chunk` 偏移量错误

**文件:** `rust/src/api/core.rs:767-777`

```rust
let page_text = chunk.join("\n");  // 以 LF 连接
let page_len = page_text.len() as u64;
acc_offset += page_len;
```

`text.lines()` 剥离 `\r` 和 `\n`，`join("\n")` 只插入单一 `\n`。对于 CRLF 文件，原始文本中每行末尾多一个 `\r` 字节，导致 `acc_offset` 累积值小于实际文件字节偏移。

**影响:** 打开 CRLF 格式的 TXT/MD 文件时，分页偏移量偏小。

**复核 (2026-06-16):** ❌ 未修复

- `core.rs:891-926` `paginate_chunk` 仍维持 `text.lines().collect() → chunk.join("\n") → page_text.len() as u64`
- CRLF 文件每个 `\r` 未计入 `page_len`，`acc_offset` 累积偏低
- 影响：分页偏移量不准确，但因 `paginate_chunk` 自身已被标记为 DEAD CODE（见 #16），实际触发率取决于是否有调用方
- 双重风险：死代码 + 死代码里的 bug

***

### 13. `config_hash` 未稳定包含 `hyphenation_language`

**文件:** `rust/src/domain/types/typeset.rs:281`

```rust
if let Some(ref lang) = self.hyphenation_language {
    bytes.extend_from_slice(lang.as_bytes());
}
```

仅当 `hyphenation_language` 为 `Some` 时将其加入哈希。逻辑上这产生正确的区分：`None` 和 `Some("")` 没有区别。但如果未来有两个相同的配置但一个显式设置语言一个未设置，它们的哈希可能意外相同。当前无实际影响。

**复核 (2026-06-16):** ❌ 未修复（与原评一致）

- `typeset.rs:264-266` 仍为 `if let Some(ref lang) = self.hyphenation_language { ... }`
- 文档原评：当前无实际影响
- 注：`Hash` 实现（`typeset.rs:167-168`）已经无条件 `self.hyphenation_language.hash(state)`，与 `config_hash` 的行为存在微妙差异（Hash 区分 `None` 和 `Some("")`，config\_hash 不区分）

***

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

**复核 (2026-06-16):** ❌ 未修复

- `error.rs:77-83` 仍为 `Self::DatabaseError { reason: err.to_string() }`
- 建议：拆分为 `DatabaseConnection` / `DatabaseQuery` / `DatabaseRowNotFound` 等子变体或在 `reason` 中保留分类前缀（如 `[Connection] xxx`）

***

## 死代码 & 未使用导出

### 15. `create_page_streamer` 标记 DEAD CODE 但有 FRB 绑定

**文件:** `rust/src/api/core.rs:580`

```rust
// DEAD CODE: Dart 侧无调用，当前走 paginateAllContent
#[frb]
pub async fn create_page_streamer(...)
```

公开 FRB 导出但在 Dart 侧没有调用者。每次 Dart 构建都会生成无用的 FFI 绑定。

**复核 (2026-06-16):** ❌ 未修复

- `core.rs:540-543` `// DEAD CODE` 注释 + `#[frb]` 公开导出 仍在
- 验证 Dart 侧无调用：可通过 `grep -r "createPageStreamer" lib/` 确认（未在本次复核中执行）
- 后果：每次 `flutter_rust_bridge_codegen` 生成无用 FFI 绑定

***

### 16. `get_paginated_chunk` 标记 DEAD CODE 但有 FRB 绑定

**文件:** `rust/src/api/core.rs:792-793`

```rust
// DEAD CODE: Dart 侧无调用
#[frb]
pub async fn get_paginated_chunk(...)
```

同上，公开但无调用方。

**复核 (2026-06-16):** ❌ 未修复

- `core.rs:937-940` `// DEAD CODE` 注释 + `#[frb]` 公开导出 仍在
- 与 #12 关联：内部调用的 `paginate_chunk` 也有偏移 bug

***

### 17. 注释掉的测试代码

**文件:** `rust/src/search/engine.rs:308-315`、`rust/src/api/bilingual.rs:248-336`

两处测试代码被大块注释而非条件编译 `#[cfg(test)]`。代码仍可编译，但测试脱离运行覆盖。

**复核 (2026-06-16):** ❌ 未修复

- `engine.rs:297-304` 单函数 `truncate_snippet` 被注释
- `bilingual.rs:248-336` 整个 `mod tests { ... }` 块（87 行）被注释，含 7 个测试用例
- 影响：bilingual 关键路径（创建/查询/删除高亮对、双语对齐）失去回归测试保护
- 建议：直接删除注释代码（git 历史可恢复）或恢复为 `#[cfg(test)]` 编译

***

## 总结

| 严重程度 | 数量 | 状态（2026-06-16 复核）            | 关键影响                       |
| ---- | -- | ---------------------------- | -------------------------- |
| 严重   | 2  | ✅ 全部已修                       | —                          |
| 中等   | 5  | 4/5 已修；#6 format 静默转 TXT 仍未修 | 未知格式乱码无提示                  |
| 轻微   | 7  | ❌ 全部未修                       | 冗余 clone、lint 失效、类型不一致、死代码 |

**已修复 6 项**: #1 断行死循环、#2 FTS5 escape、#3 富文本双重处理、#4 lazy 字节偏移、#5 lazy 阈值单位、#7 全宽拉丁标点误判。

**未修复 11 项**: #6、#8-#17 全部仍存在原始问题。

**最紧急残留项:**

1. **#6** — 用户打开 .mobi/.azw3 等未知格式会看到乱码无错误提示（最影响用户体验）
2. **#11 + #15 + #16** — 几百行死代码 + 仍生成 FFI 绑定（技术债累积）
3. **#12** — 死代码里仍有 bug（双重风险）
4. **#17** — bilingual 模块 87 行测试脱离运行（回归无保护）

**已修复 #2 的代价:** FTS5 转义策略从 "字符级 escape" 改为 "整体短语包裹"。所有特殊字符（`+`, `-`, `*`, `(`, `)` 等）都成为字面量，用户无法再使用 FTS5 原生操作符语法（AND/OR/NOT/前缀匹配）。需评估是否需要在 UI 上提示用户当前搜索为字面量短语搜索。

**附加发现 (复核过程中):**

- `cargo build --tests` 编译失败（多个 test crate 报错），与本 issue 无关，属未提交改动：`rust/src/api/core.rs` 正在重构 pagination session 架构（`paginate_session_full` → `repaginate_session` + `apply_session_repagination`），可能影响测试签名

