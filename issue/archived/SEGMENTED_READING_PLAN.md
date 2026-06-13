# 分段读取方案 Phase 2（简化版）

## 目标

首屏延迟从 ~2s（Phase 0/1）降到 **100ms 级别**——用户点击章节后第 0 页立刻渲染，无骨架屏感知。

**约束**：不改 `PageStreamer` 内核，不改 `EpubContentProvider` 惰性加载改造，最小化 Rust 改动。

## 思路

不造流式内核。用 **"先喂一页 → 后台加载全文 → 切换"** 替代当前"全文加载完才渲染"。

```
tap chapter
  │
  ├─ 1. get_chapter_first_spine_only(file, index)     ← 新增 Rust API
  │    → 读取第 1 个 spine HTML
  │    → html_to_plain_text
  │    → 取前 ~2000 字估算第一页可渲染的文本
  │    → ImmediateReturn { text: String, has_more: bool }
  │
  ├─ 2. 立即渲染第 0 页（~100ms）
  │    ← 用户看到内容
  │
  ├─ 3. 后台并发（wall clock 不阻塞渲染）:
  │    ├─ a) getChapter + paginateChapter ← 现有路径，走缓存
  │    └─ b) getEpubChapterRichContent ← 已跳过
  │
  ├─ 4. paginateChapter 就绪（~2s 后）
  │    → 页码统一替换为完整分页
  │    → 用户当前页不变（保持阅读位置）
  │
  └─ 5. 翻页：如果完整分页已就绪 → 用它；否则 → 从首段文本估算
```

## 文件清单与改动

### Step 1：新增 Rust API `get_chapter_first_spine_only`

**文件**：`rust/src/api/core.rs`

新增函数：

```rust
/// 快速获取第一章的第一个 spine 的纯文本。
/// 只读一个 spine，不做分页，不做全量 spine 加载。
/// 用于 Dart 侧快速渲染首屏。
#[frb]
pub async fn get_chapter_first_spine_only(
    file_path: String,
    chapter_index: i32,
) -> Result<FirstSpineResult, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    let format = format_from_extension(&validated_path);

    let content = if format == BookFormat::Epub {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        // 只读第 1 个 spine（约 0..content_len 的前 1/spine_count）
        // 通过 content_length 触发 build_spine_offsets（这是必要的，
        // 但后续 build_spine_offsets 的 OnceLock 会缓存，不重复加载）
        let total = provider.content_length();
        // 读取前 ~2000 字符（大致一页的文本量）
        let read_len = 2000u64.min(total);
        let text = provider.read_text_range(0, read_len)?;
        text
    } else {
        // TXT/MD 直接读文件前 N 字节
        let content = tokio::fs::read_to_string(&validated_path).await?;
        content.chars().take(2000).collect()
    };

    Ok(FirstSpineResult {
        text: content,
        total_length_estimate: 0, // 暂不返回
    })
}
```

**新增类型**：

```rust
#[frb]
pub struct FirstSpineResult {
    pub text: String,
}
```

实际上还可以优化：不让 `content_length()` 触发全部 spine 加载。因为知道 `spine_texts` 长度 = 需要处理 N 个 spine。我们可以只读第一个 spine：

```rust
pub async fn get_chapter_first_spine_only(
    file_path: String,
    chapter_index: i32,
) -> Result<FirstSpineResult, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;

    let text = if validated_path.ends_with(".epub") {
        // 打开 EPUB，只读第一个 spine（不触发全部 spine 加载）
        let text = tokio::task::spawn_blocking(move || {
            let mut epub = crate::parser::epub::unzip::EpubFile::open(&validated_path)?;
            let chapters = crate::parser::epub::toc::extract_chapters_from_epub(&mut epub, "");
            let chapter = chapters.iter()
                .find(|c| c.chapter_index == chapter_index as i64)
                .ok_or_else(|| AppError::chapter_extract_error(chapter_index, "chapter not found"))?;

            let spine = epub.spine();
            let start = chapter.start_index as usize;
            if start >= spine.len() {
                return Err(AppError::chapter_extract_error(chapter_index, "spine index out of range"));
            }

            let href = &spine[start];
            let html = epub.read_resource(href)
                .map_err(|e| AppError::chapter_extract_error(chapter_index, e.to_string()))?;
            let plain = crate::parser::epub::provider::html_to_plain_text(&html);
            // 取前 2000 字符作为首屏
            Ok(plain.chars().take(2000).collect::<String>())
        })
        .await
        .map_err(|e| AppError::task_panic("first_spine", e.to_string()))??;
        text
    } else {
        // TXT/MD: 读前 2000 字
        let content = tokio::fs::read_to_string(&validated_path).await?;
        content.chars().take(2000).collect()
    };

    Ok(FirstSpineResult { text })
}
```

**注意**：需要用 `html_to_plain_text`，它在 `provider.rs` 里是 `pub(crate)` 的。需要改为 `pub` 或调整可见性。

### Step 2：Dart 侧新增流式加载路径

**文件**：`lib/features/reader/data/repositories/rust_reader_repository.dart`

```dart
class ReaderRepository {
  // ... 现有字段

  /// 流式读取状态
  bool _streamLoaded = false;          // 全文分页是否就绪
  String? _firstSpineText;             // 首个 spine 纯文本（首屏用）
  
  /// 快速获取首屏文本（不阻塞）
  Future<String> loadChapterFirstSpine(String bookId, int chapterId) async {
    final book = await book_api.getBook(bookId: bookId);
    if (book == null || book.filePath.isEmpty) {
      throw Exception('Book not found: $bookId');
    }
    final result = await core_api.getChapterFirstSpineOnly(
      filePath: book.filePath,
      chapterIndex: chapterId,
    );
    _firstSpineText = result.text;
    _streamLoaded = false;
    return result.text;
  }

  /// 后台加载全文+分页（不阻塞调用方）
  Future<void> loadChapterFullContent(String bookId, int chapterId) async {
    // 走现有 loadChapterContent + paginateChapter 路径
    await loadChapterContent(bookId, chapterId);
    // ... 分页等
    _streamLoaded = true;
  }

  /// 获取第 N 页（优先用完整分页，fallback 到估算）
  List<PageInfo>? get currentPagesOrEstimate {
    if (_streamLoaded && currentPages != null) return currentPages;
    // 用首段文本估算分页
    if (_firstSpineText != null) {
      return _paginateApproximate(
        _firstSpineText!,
        fontSize: _lastFontSize ?? 16,
        lineHeight: _lastLineHeight ?? 1.6,
        width: _lastWidth ?? 400,
        height: _lastHeight ?? 600,
        padding: _lastPadding ?? 20,
      );
    }
    return null;
  }
}
```

### Step 3：ReaderViewModel 流式状态

**文件**：`lib/features/reader/application/reader_view_model.dart`（根据项目结构可能需要调整）

```dart
/// 流式加载状态
enum StreamStage { firstSpine, fullReady }

class ReaderViewModel {
  // ...
  
  StreamStage _stage = StreamStage.firstSpine;
  
  Future<void> loadChapter(int index) async {
    _stage = StreamStage.firstSpine;
    
    // 1. 快速首屏
    final firstText = await _repo.loadChapterFirstSpine(bookId, index);
    _updateContent(firstText);
    _stage = StreamStage.firstSpine;
    
    // 2. 后台全文加载
    _repo.loadChapterFullContent(bookId, index).then((_) {
      _stage = StreamStage.fullReady;
      // 用完整分页替换视图
      _updateContent(_repo.currentPagesOrEstimate);
    });
  }
  
  String? getPageContent(int page) {
    if (_stage == StreamStage.fullReady) {
      return _repo.getPageContent(page); // 完整分页
    }
    return _estimatePageContent(page); // 首段估算
  }
}
```

**关键点**：`_stage` 过渡时保证用户当前阅读位置不变。

### Step 4：Widget 层适配

**文件**：`lib/features/reader/presentation/page/reader_content.dart`（推测）

```dart
// 当前：FutureBuilder + loadChapterContent 的 String
// 改为：监听 ReaderViewModel 的 stage + content stream

Widget build(BuildContext context) {
  return viewModel.currentPageContent.when(
    // stream 模式：收到任何内容就渲染
    data: (content) => ReaderContentView(content: content),
    loading: () => const SizedBox.shrink(), // 无骨架屏
    error: (e) => ErrorView(e),
  );
}
```

## 边界情况与处理

| 情况 | 处理 |
|------|------|
| 第 1 个 spine 文本不足一页 | 返回全部文本。估算分页可能只有 1 页。全文就绪后替换 |
| 第 1 个 spine 是封面/图片 | 返回空文本。渲染空页。全文就绪后恢复正常 |
| 用户快速翻页 | 翻到全文未覆盖的页码 → 用首段文本估算继续翻。当全文就绪后页码可能变化，但当前页内容不变 |
| 全文就绪时页码数不同 | 保持用户当前阅读位置不变（char_offset 对齐），仅更新 total_pages |
| 章节只有一个 spine（小章节） | 首屏返回全部文本。全文几乎同时就绪，无缝切换 |
| EPUB 被外部修改 | 现有校验不变。首次打开时验证，后续读取用缓存 |

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| html_to_plain_text 对超大 HTML(165KB+) 慢 | 首屏只取前 2000 字符，`Read` 操作在 `take(2000)` 之后不处理剩余字符。但 `html_to_plain_text` 已全部处理完文本。需要改为截断输入：`html.chars().take(5000).collect()` 再传入 `html_to_plain_text` |
| FRB 序列化 FirstSpineResult 开销 | 2000 字符的 String，FFI 拷贝 ~2KB。无影响 |
| 首屏显示的页码与全文分页不一致 | 第 0 页内容一致（因为文本相同）。后续页码可能偏移。用户翻到第 5 页前全文已就绪 |

## 验收标准

1. `test/fixtures/活着.epub` 第 5 章首屏 < 200ms
2. 首屏内容与全文分页第 0 页一致
3. 全文就绪后页码切换不闪烁、不丢失阅读位置
4. 现有 `loadChapter` 路径（非流式）保持兼容

## 工期估计

| 步骤 | 文件 | 预计 |
|------|------|------|
| Rust API `get_chapter_first_spine_only` | 1 file | 0.5d |
| Dart 流式加载 + repository 改造 | 2 files | 1d |
| ViewModel 状态 + Widget 适配 | 2 files | 1d |
| 测试 + 手动验证 | - | 0.5d |
| **合计** | **~5 files** | **3d** |

## 后续（Phase 2b）

分段读取稳定后，可进一步优化：

- **Phase 2b.1**：`html_to_plain_text` 输入截断为 HTML 前 5KB，消除大 HTML 文件的处理延迟
- **Phase 2b.2**：首个 spine 文本取回后立即用 `_paginateApproximate` 快速估算页数，免去等待 `paginateChapter`
- **Phase 2b.3**：后台全文加载与首屏渲染解耦——用 Isolate 或在 Rust 侧使用 `tokio::spawn` 避免卡 UI 线程
