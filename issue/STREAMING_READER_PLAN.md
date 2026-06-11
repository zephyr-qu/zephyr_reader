# Streaming Reader 改造方案

## 现状：一章打开做了什么

每次用户点击目录中的章节，以下步骤同步阻塞：

```
loadChapter(chapterIndex)
  │
  ├─ 1. Future.wait ────────────────────────────── 墙钟 = max(a, b, c)
  │    ├─ a) getChapter(file, index)              ← Rust: 全文纯文本
  │    │    → EpubContentProvider::open
  │    │    → build_spine_offsets → html_to_plain_text × N spines
  │    │    → read_text_range(0, content_len)
  │    │    → String (全文) ─── FFI ───→ Dart
  │    │
  │    ├─ b) getEpubChapterRichContent(file, index) ← Rust: 全文富文本
  │    │    → 独立打开 EpubFile
  │    │    → read_chapter_content → 再读 N 个 spine HTML
  │    │    → html5ever 全量解析 → Vec<RichParagraph>
  │    │    → FFI → Dart
  │    │
  │    └─ c) calibrateSafely                      ← CJK 字符宽度测量
  │
  ├─ 2. paginateChapter(config)                   ← Rust: 全文分页
  │    → provider.read_text_range(0, content_len)  ← 再取一遍全文
  │    → PageStreamer::new(content, config)
  │    → optimize_punctuation(content)
  │    → optimize_spaces(content)
  │    → 计算 N 个 line_offsets
  │    → descriptors ─── FFI ───→ Dart
  │
  ├─ 3. ensurePageWindow(0)                       ← 缓存第 0 页内容
  │    → get_page_content (sync FFI)
  │
  └─ 4. 显示第一页 ← 此时用户才看到内容
```

### 6 个结构性浪费

| # | 问题 | 后果 |
|---|------|------|
| 1 | 全文 String 通过 FFI 拷贝 **2 次**（getChapter + paginateChapter） | 无关内容也压了带宽 |
| 2 | 同一 spine HTML 被**独立读取 2 遍**（provider + rich text） | I/O 翻倍 |
| 3 | 全文**分页预计算全部行偏移**，才显示第 1 页 | 首屏延迟 = 全量排版时间 |
| 4 | calibration 跑在关键路径上，阻塞首次渲染 | 首屏额外 +~2s |
| 5 | 翻页走 `get_page_content`（sync FFI），状态在 Rust LRU 里 | 每次翻页 FFI 开销 |
| 6 | 改字号/行高 = 重新走 1‑6 全流程 | 设置变更响应慢 |

---

## 目标架构：增量流式渲染

```
tap chapter
  │
  ├─ 1. 立即读取 第 1 个 spine 的 HTML
  │    → html_to_plain_text → 取前 M 个字符估算分页
  │    → 构建 第 0 页 文本 + 下一页起始偏移
  │    → 渲染 第 0 页  ← 50-200ms 内看到内容
  │
  ├─ 2. 后台继续：读取第 2-N 个 spine
  │    → 增量扩充 text buffer
  │    → 按需追加行偏移（append_line_offsets）
  │
  ├─ 3. 用户翻页 → 从已构建的行偏移拿内容
  │    → 如果下一页偏移尚未构建 → 阻塞等（极少发生）
  │
  └─ 4. 翻到 buffer 边缘 → 触发下一批 spine 加载
```

### 关键变化

- **无"加载 → 分页"两阶段**，合为流式 pipeline
- **无 calibration 阻塞**，使用默认表 + 后台渐进修正
- **无 html5ever 全量解析**，仅对可见段落做轻量样式提取
- **翻页无 FFI**，行偏移映射到 Dart 侧
- **改字号只重建当前页 ±3 页**

---

## 分阶段实施

### 第一阶段：砍掉重复路径 & 解除 calibration 阻塞（低风险，快速见效）

#### 1.1 删除 html5ever 富文本路径（`getEpubChapterRichContent`）

**理由**：html5ever 解析 300KB+ HTML 贡献了原始 21s 瓶颈。且该路径与 provider 路径重复读取同一份 spine HTML。

**改动**：

- Rust `api/epub.rs`：标记 `get_epub_chapter_rich_content` 为 deprecate，内部直接返回空 `Vec`
- Dart `rust_reader_repository.dart`：删除 `epubRichFuture` 分支，只走纯文本路径
- 后续可替换为轻量标签解析器（只解析加粗/斜体/标题），不做完整 DOM

**文件清单**：
```
rust/src/api/epub.rs          — deprecate get_epub_chapter_rich_content
lib/.../rust_reader_repository.dart  — 删除 epubRichFuture 分支
rust/src/parser/epub/parse.rs — get_chapter_content_rich / read_chapter_content 可后续删除
```

**验证**：所有 widget 测试继续 pass，富文本降级为纯文本（样式暂时丢失）

#### 1.2 calibration 异步化

**理由**：`calibrateSafely` 跑在 `Future.wait` 中，阻塞首次渲染。

**改动**：

- 保留 `calibrateSafely` 后台执行，但不作为 `loadChapterContent` 的依赖
- 使用默认 `CharWidthTable`（中 = 2.0, 英 = 1.0, 标点 = 1.0）首次渲染
- calibration 完成后通过 signal 通知 `PageStreamer` 调整个别字符宽度
- 因为 CJK 字符宽度差异小（中文字符 2.0 vs 实测 2.0x），误差 <5%，不影响分页大体正确

**文件清单**：
```
lib/features/reader/application/chapter_manager.dart  — 分离 calibration 依赖
rust/src/text/char_width.rs     — 已提供默认表
rust/src/text/pagination.rs    — 渐进校准接口（新增）
```

---

### 第二阶段：流式 Reader 内核（核心重构）

#### 2.1 新增 `StreamingPageReader`

替代 `PageStreamer`，支持增量 feeding：

```rust
/// 流式分页读取器：支持增量追加内容，按需构建行偏移。
pub struct StreamingPageReader {
    /// 累计的全文 buffer（未做 optimize_punctuation，翻页时实时处理）
    buffer: String,
    /// 已构建的行偏移，用于快速获取已分页内容
    line_offsets: Vec<(usize, usize)>,
    /// 最近的分页配置（改变时需局部重建）
    config: TypesetConfig,
    /// 字符宽度表（允许渐进校准）
    width_table: CharWidthTable,
    /// buffer 中有多少个字符已完成宽度计算
    processed_chars: usize,
}

impl StreamingPageReader {
    /// 以最少内容创建，尽快响应第一页
    pub fn new_first_page(initial_text: &str, config: TypesetConfig) -> Self;

    /// 追加更多文本内容，增量计算行偏移
    pub fn append(&mut self, more_text: &str);

    /// 获取第 N 页内容（只在已构建的范围内有效）
    pub fn get_page(&self, page_index: usize) -> Option<String>;

    /// 改变排版参数，局部重建偏移（当前页 ±3 页）
    pub fn reconfigure(&mut self, config: TypesetConfig);

    /// 渐进校准字符宽度
    pub fn refine_width(&mut self, ch: char, actual_width: f32);
}
```

**与 `PageStreamer` 的关键区别**：

| | PageStreamer | StreamingPageReader |
|---|---|---|
| content ownership | 构造时传入完整 String | 通过 `append()` 增量追加 |
| 行偏移计算 | 全量在 `new()` 中完成 | 每次 `append()` 增量计算 |
| 首屏延迟 | 必须等全文 line_offsets | 首次 `new_first_page` 后立即可用 |
| 校准 | 构造时固定 | 调用 `refine_width()` 渐进调整 |
| 配置变更 | 重建整个实例 | `reconfigure()` 局部重建 |
| 翻页 | 同步 FFI（跨进程） | 直接内存读取 |

**文件**：`rust/src/text/streaming_reader.rs`（新增）

#### 2.2 `SpineStreamer` — 流式 spine 读取器

当前 `EpubContentProvider` 在 `build_spine_offsets` 中 eager-load **所有** spine。改为逐条 lazily 读取。

```rust
/// 以 spine 条目为粒度流式读取 EPUB。
pub struct SpineStreamer {
    epub: EpubFile,
    spine_hrefs: Vec<String>,
    /// 已加载并缓存的 spine 文本（None = 尚未加载）
    cached_texts: Vec<Option<String>>,
    /// 当前已加载到第几个 spine
    loaded_up_to: usize,
}

impl SpineStreamer {
    /// 打开 EPUB，读取 spine 列表但不加载任何内容
    pub fn open(path: &str, chapter_index: i32) -> Result<Self>;

    /// 确保前 N 个 spine 已加载（每次只加载尚未加载的）
    pub fn ensure_loaded(&mut self, up_to: usize) -> Result<()>;

    /// 获取已加载内容的累计文本
    pub fn accumulated_text(&self) -> &str;
}
```

**文件**：`rust/src/parser/epub/streamer.rs`（新增，或直接改造 `provider.rs`）

#### 2.3 Dart 侧流式加载流程

```
tap chapter
  │
  ├─ Dart → Rust: createStreamingReader(path, index, config)
  │    → 打开 EpubFile，读取 spine 列表（不加载内容）
  │    → 返回 StreamingReader handle
  │    → 立即加载第 1 个 spine
  │    → html_to_plain_text → 取前 ~2000 字估算分页
  │    → 构建第 0 页文本 → 返回 { page0_text, page0_offset_begin, page0_offset_end }
  │    → 渲染第 0 页
  │
  ├─ 后台（isolate / microtask）:
  │    → Rust: appendMore(handle, count=3)
  │    → 加载 spine 2-4
  │    → 增量计算 line_offsets
  │    → 返回已就绪的 page_count
  │
  ├─ 用户翻到 page N:
  │    → Rust: getPage(handle, N) → 行偏移已就绪 → 直接返回文本
  │    → 如果 N 尚未就绪，同步加载下一个 spine
  │
  └─ 翻到 page_count - 3:
       → 触发下一批 appendMore
```

**核心改变**：不再有 `loadChapterContent` 返回整章文本，而是返回第一页 + handle。

---

### 第三阶段：分页状态移至 Dart 侧

**理由**：当前翻页走 `get_page_content`（sync FFI）。对于 `活着.epub` 的 9 个 spine 和 ~36 页，每次翻页的 FFI 开销不大，但在大章节（500+ 页）时明显。

**方案**：

- Rust `StreamingPageReader::get_descriptors_snapshot()` 返回 `Vec<PageDescriptor>`（偏移量，不含文本）
- 序列化后通过 FFI 一次性传给 Dart
- Dart 侧持有 `List<PageDescriptor>` + `String content`
- 翻页 = Dart 侧字符串切片，零 FFI

```dart
class PageDescriptor {
  final int startOffset;
  final int endOffset;
  final bool isFirstOfParagraph;
}

class DartPageReader {
  final String content;
  final List<PageDescriptor> descriptors;
  
  String getPage(int index) {
    final d = descriptors[index];
    return content.substring(d.startOffset, d.endOffset);
  }
  
  /// 设置变更：只截断 descriptors 到当前可见范围 + 5 页，
  /// 通知 Rust 侧继续计算后续偏移
  void reconfigure(double fontSize, double lineHeight) {
    // 保留前 5 页的 descriptors
    // 其余截断
    // Rust 侧异步重新计算并追加
  }
}
```

---

### 第四阶段：轻量富文本替代 html5ever

**现状**：删除 html5ever 后，所有章节显示为纯文本，丢失加粗/斜体/标题样式。

**轻量方案**：用 CSS `columns` + WebView 渲染 EPUB。这是主流做法：

```
EPUB HTML → 注入 CSS column 规则 → WebView 渲染 → 读取第一栏作为第 0 页
```

但 WebView 在 Flutter 中有集成成本（`webview_flutter`、平台视图）。

**折衷方案**：自制轻量标签流解析器

```rust
/// 线性扫描 HTML，只提取加粗/斜体/标题标签。
/// 不建 DOM 树，不做实体解码，只输出 RichSpan 流。
pub fn lightweight_tag_scan(html: &str) -> Vec<RichSpan>;
```

**对比**：

| | html5ever（当前） | 轻量扫描（目标） | CSS columns（终极） |
|---|---|---|---|
| 解析 317KB HTML | 21s | ~5ms | ~5ms |
| 样式支持 | 完整 CSS | 仅 b/i/h1-h6 | 完整 CSS |
| 实现复杂度 | 已实现 | 200 行 Rust | 需 WebView |
| 维护成本 | 高 | 低 | 中 |

---

## 路线图与估计

```
Phase 0 (现在)   html5ever 跳过 >100KB ✓ + spine item cap ✓
Phase 1 (1-2d)   删除 html5ever 路径 + calibration 异步化
Phase 2 (3-5d)   流式 Reader 内核（StreamingPageReader + SpineStreamer）
Phase 3 (1-2d)   分页状态移到 Dart 侧
Phase 4 (2-3d)   轻量标签解析器 / WebView 集成
```

## 测量指标

| 指标 | 当前 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|------|------|---------|---------|---------|---------|
| ch5 首屏 (活着) | ~21s | ~3s | ~200ms | ~200ms | ~200ms |
| 翻页延迟 | ~5ms FFI | ~5ms FFI | ~5ms FFI | <1ms | <1ms |
| 改字号重排版 | 21s+ | 3s+ | ~200ms | ~5ms | ~5ms |
| 骨架屏 | 看不到 | 看不到 | 无 | 无 | 无 |
