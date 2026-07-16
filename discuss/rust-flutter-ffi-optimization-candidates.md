# Rust↔Flutter FFI 边界优化候选清单

> 发散的思维导图：当前架构中可能存在的低效数据流。
> 每个候选在后面开分支单独验证，不在此深入实现。

---

## 模式概括

从图片 RGBA 直通方案发现一个通用模式：

```
Rust 处理 A → 转格式 B → FRB → Flutter 转回格式 A′（或再处理一次）
```

以下所有候选都围绕消除这类「多余中间格式」和「跨层重复工作」。

---

## 候选一 · 封面提取绕路（与图片 RGBA 同类）🔶

### 当前路径

```
Rust: EPUB → extract cover → decode → resize → 编码 JPEG → 写磁盘
  → 返回文件路径 String
Flutter: 拿到路径 → 读文件 → Image.file(path) → 再 decode JPEG
```

### 问题

封面提取后 Rust 写一次磁盘、Flutter 读一次磁盘、再 decode 一次。虽然单本书只做一次（写 DB），但首次加载封面的流程也是绕路了。

### 优化方案

```
Rust: EPUB → extract cover → decode → resize → to_rgba8().into_raw()
  → FRB DecodedImage { rgba, width, height }
Flutter: decodeImageFromPixels → RawImage
```

与图片 RGBA 路径几乎一致，可共用 `DecodedImage` struct。

### 收益

- 省磁盘 I/O（写一次、读一次）
- 省一次 JPEG encode（Rust）+ 省一次 JPEG decode（Flutter）
- 封面加载延迟降低（省了两次 I/O）

### 代价

- 需要把现有封面缓存机制（磁盘文件路径）改为内存缓存
- 改动范围：`cover.rs` + Flutter 封面 Widget

### 验证方法

统计 `extract_and_save_cover` 被调用时，从开始到 Flutter 封面显示完成的总耗时。
当前有磁盘 I/O + 两次 encode/decode。RGBA 直通可省约 50-100ms。

---

## 候选二 · 字典音频 decode 路径（与图片 RGBA 同类但不同）🔷

### 当前路径

```
Rust: 从 MDX/MDD 读音频 → 直接返回压缩字节 Vec<u8>
  → FRB zero-copy
Flutter: Uint8List → audioplayers 播放
```

### 分析

音频不需要 RGBA 路径——音频天生是压缩格式（MP3/SPX），Flutter 播放器直接消费压缩字节。当前路径已经是高效的（Rust 读原始字节 → zero-copy → Flutter 播放器解码）。

### 结论

**无需优化** ✅。音频与图片不同，不存在「decode → re-encode → decode again」模式。

---

## 候选三 · IR → plain 退化路径确认 ✅ 已整改

### 当前路径

Flutter 侧 `chapter_content_repository.dart` 中，`getChapterContentIr()` 失败或返回空 IR 时回退到 `getChapterPlain()`，再构造 plain payload。

### 问题

这是一条「Rust 侧 IR 路径失败 → 回到富文本 → 再由 Flutter 侧解析」的退化路径。它本应是极端情况的 fallback，但如果因为某些常见原因（如 IR 缓存未命中 + 解析器异常）频繁触发，就会导致：

该路径会丢失 EPUB 图片和样式，因此必须是可观测的异常降级，不能成为长期双轨。

### 验证方法

已增加 `[ReaderIrFallback]` 结构化日志字段：stage、book、chapter、mode、reason、fallbackSucceeded。正常语料不应触发。

### 如果确认频繁触发

保留显式 plain fallback 作为容错；正常链路的 IR 故障进入 N3 修复，不允许依赖 fallback 掩盖。

---

## 候选四 · 图片批量预取 FFI 合并 🔶

### 当前路径

翻页到含图页时，`EpubBlockImageCache.load()` 被每个图片独立调用。10 张图 = 10 次 FFI 调用。

```
FFI 调用 × N（每张图一次）
```

### 问题

每次 FFI 调用都有跨边界开销（参数 marshalling、上下文切换、返回反序列化）。图片多时累积明显。

### 优化方案

```rust
pub async fn get_processed_epub_image_bytes_batch(
    requests: Vec<ImageRequest>,
) -> Result<Vec<DecodedImage>, AppError> {
    // 内部分批处理，单次 FFI 边界
}

pub struct ImageRequest {
    pub file_path: String,
    pub asset_id: String,
    pub max_width_px: u32,
}
```

### 收益

- 将 N 次 FFI 调用减为 1 次
- 不影响单图解码逻辑（只是批量化打包）

### 代价

- 需要改 `EpubBlockImageCache` 的 `prefetchBlocks()` 和 `load()` 来支持批量
- 需要等所有图解码完成后才返回（可能延迟后续渲染，所以低优先级）

### 验证方法

用 `DartDevTools` 的 Timeline 统计一次翻页触发了几次 FFI 调用。
如果一页 5 张图就是 5 次调用，合并为 1 次可省 4 次边界开销（每次 ~0.5-1ms）。

---

## 候选五 · `get_chapter_plain` 大文本 FRB 传输 ✅ 正常路径已整改

### 当前路径

Flutter 在两种场景调用 `get_chapter_plain`：

1. IR 加载后的 plainText 投影（IR 路径，Rust 侧已有 plainText）
2. 搜索/进度场景需要全文 plain 锚点

### 问题

`get_chapter_plain` 返回 `String`，大 TXT 章节可达 1MB+。FRB 传输大 String 时：

- Rust 侧 UTF-8 序列化（String → bytes）
- Flutter 侧 UTF-8 反序列化（bytes → Dart String）
- 全部在主 isolate 完成

### 优化方向

对于搜索/进度锚点场景，不需要整章纯文本——只需要 IR 中的 plainText 字段（`ReaderChapterIr.plain_text`）。当前 `get_chapter_content_ir` 已经返回包含 `plain_text` 的 IR struct，多余的 `get_chapter_plain` 调用其实可以不独立存在。

**已实施**：双语 EPUB 正常路径只请求 IR 并直接使用 `ir.plainText`；仅在 IR 失败或为空时再请求 plain。其他本来只需要 plain 的调用方保持不变。

### 验证方法

查看 `chapter_content_repository.dart` 中 `getChapterPlain` 的调用时机，确认是否都是 IR 路径的冗余调用。

---

## 候选六 · 词典查词高频 FFI 调用缓存 🔷

### 当前流程

```dart
// 每次查词都跨 FFI 边界
final result = await dictApi.lookupMdict(word: query);
```

### 问题

在阅读中用户可能快速查多个词，每次查词都是一次 Rust FFI 调用（含 MDX 解析 + 文本格式化）。如果用户反复查同一个词（复习），Rust 侧每次都重新解析。

### 优化方案

在 Flutter 侧加一个 LRU 缓存：

```dart
class DictLookupCache {
  final _cache = LinkedHashMap<String, DictSearchResult>();
  static const _maxEntries = 30;

  Future<DictSearchResult?> lookup(String word) async {
    if (_cache.containsKey(word)) return _cache[word];
    final result = await dictApi.lookupMdict(word: word);
    if (result != null) _store(word, result);
    return result;
  }
}
```

### 收益

- 重复查词零 FFI 延迟
- 快速滚动查词时减少 Rust 负载

### 代价

- 轻量，~20 行代码

---

## 候选七 · 热路径 CRUD 批量化 🔷

### 当前模式

多个小操作（创建/删除书签、更新进度）各自独立跨 FFI 边界：

```dart
await bookmarkApi.createBookmark(bm1);
await bookmarkApi.createBookmark(bm2);
await bookmarkApi.createBookmark(bm3);  // 3 次 FFI
```

### 分析

一次 FFI 边界开销约 0.5-1ms（参数 marshalling、同步点）。对于单个操作微不足道，但在高频路径（批量删除、导入导出）时会累积。

### 优化方向

那些已经有 `Vec` 参数（如 `delete_bookmarks(ids: Vec<String>)`、`batch_update_book_status`）的函数已经解决了这个问题。需要检查的是还没有批量的操作。

### 验证方法

搜索 `lib/` 下循环调用 api 的模式：

```dart
for (final x in list) { await someApi.fn(x); }
```

如果存在这种模式且调用次数可能超过 5+，就应该添加批量 API。

---

## 候选八 · IR 大 Struct 序列化开销评估 🔶

### 当前路径

`get_chapter_content_ir` 返回 `ReaderChapterIr`，包含：

```
ReaderChapterIr
  ├── blocks: Vec<ContentBlock>
  │    ├── Text { runs: Vec<ReaderInlineRun>, ... }
  │    ├── Image { ... }
  │    └── ... (other variants)
  ├── plain_text: String
  ├── image_asset_ids: Vec<String>
  └── ... (metadata fields)
```

对于大章节（100KB 纯文本 + 数百个 InlineRun），IR 序列化后的 FRB 传输量可能达到 200KB+。

### 问题

FRB 的 SSE codec 需要遍历整个 IR 树来序列化/反序列化。这个序列化/反序列化在两边都是同步进行的：

- Rust 侧序列化：遍历所有 block，编码每个字段（同步，但在 tokio 线程，不阻塞 UI ✅）
- Flutter 侧反序列化：遍历所有 block，解码每个字段（同步，在主 isolate ❌）

### 需要验证

1. 一次 `get_chapter_content_ir` 的完整 RTT 是多少？
2. 其中 Flutter 侧反序列化耗时占比多少？
3. 大章节（100KB+ 内容）RTT 是否会超过 200ms？

### 可能的优化（如果反序列化确实是瓶颈）

- 将 IR 切分为「元信息首屏」和「完整数据延迟加载」，但涉及 IR 管线架构变更，成本高
- 用 FlatBuffers/MessagePack 等二进制格式替代 FRB SSE codec（实验性，成本很高）

---

## 优先级总览

| # | 候选 | 收益 | 风险 | 建议 |
| --- | ------ | ------ | ------ | ------ |
| 1 | 📦 图片 RGBA 直通 | 🔶 中 | 低 | **Phase 12 已纳入** |
| 2 | 🖼️ 封面 RGBA 直通 | 🔷 低 | 低 | 随 N2 架构审查时评估 |
| 3 | 🔙 IR → plain fallback | 🔷 低 | 低 | ✅ 已结构化记录，N3 继续审计根因 |
| 4 | 📸 图片批量预取 FFI 合并 | 🔷 低 | 低 | 随 N4 边界测试验证 |
| 5 | 📖 `get_chapter_plain` 冗余 | 🔷 低 | 低 | ✅ 双语正常路径已移除 |
| 6 | 📚 词典查词缓存 | 🔷 低 | 低 | 随手做 |
| 7 | 🔄 热路径 CRUD 批量化 | 🔹 极低 | 低 | 有症状时再动 |
| 8 | 🏗️ IR 大 Struct 序列化 | 🔶 中 | 高 | 先测 RTT 再决定 |

### 图例

| 标记 | 含义 |
| ------ | ------ |
| 🔶 | 收益或成本中等 |
| 🔷 | 收益或成本低 |
| 🔹 | 收益或成本极低 |

---

## 快速验证脚本思路

### 候选三：`get_chapter` fallback 频率

```dart
// 在 chapter_content_repository.dart 加计数器
int _chapterFallbackCount = 0;
// ... get_chapter 被调用时 ++
// 某个 debug page 显示该计数值
```

### 候选四：FFI 调用计数

```dart
// 在 EpubBlockImageCache.load() 加计数器
int _imageFfiCallCount = 0;
// 在每个章节加载完成后输出
```

### 候选八：IR 反序列化耗时测量

```dart
final stopwatch = Stopwatch()..start();
final frbIr = await reader_api.getChapterContentIr(...);
stopwatch.stop();
Logging.info('[IrLoad] getChapterContentIr RTT: ${stopwatch.elapsedMilliseconds}ms');
```

---

---

> **状态**：收集阶段，未经分支验证。前面打需在独立分支上逐个验证。

---

# 第二卷：Flutter 渲染管线与 Widget 性能

> FFI 之外，Flutter 侧自身也有可优化的模式。以下候选不涉及 Rust，聚焦 Dart/Flutter 渲染性能。

> *注：部分优化（如动画 setState）只影响 debug profile，release 模式有差异，需在 release-profile 下验证。*

>

---

## 候选九 · PageCurl 动画每帧全 Widget 重建 ✅ 已整改

> 来源：`page_curl_widget.dart:47` — `_ctrl.addListener(() => setState(() {}))`

### 问题

动画每帧（60fps）`setState` 重建整个 `PageCurlWidget` 树——包含 `pageBuilder`（整页内容）。
若 `pageBuilder` 含 LayoutBuilder/图片等重型组件，每次帧回调都触发它们重新 build，造成翻页动画掉帧。

### 优化方案：AnimatedBuilder 隔离重建范围

```dart
// 当前
_ctrl.addListener(() => setState(() {}))
// → 重建整个 widget 树，包括 pageBuilder 的内容

// 优化后
AnimatedBuilder(
  animation: _ctrl,
  builder: (context, child) {
    // 只有 ClipPath/Transform 在此重建
    return ClipPath(
      clipper: _PageCurlClipper(progress: _ctrl.value),
      child: child!,
    );
  },
  child: widget.pageBuilder(widget.pageIndex),  // 静态内容，不随动画重建
)
```

### 实施结果

- controller tick 仅重建 ClipPath / Transform / shadow 动画层。
- 当前页及相邻页由 pageIndex/pageBuilder 生命周期缓存；组件测试锁定动画期间 `pageBuilder` 调用次数不增长。
- 手势、回弹、跨页回调接口不变。

---

## 候选十 · `_ContentMeasurer` 调试 Widget 泄漏到生产路径 ✅ 已删除

> 来源：`block_page_content.dart:336-367`

### 问题

`_ContentMeasurer` 是 Phase 4 遗留的度量工具，包裹了每一页的 `Column`。
每次翻页触发一次 `addPostFrameCallback` + `findRenderObject()`——这不是产品功能。

### 实施结果

确认没有生产消费者后直接删除 wrapper、post-frame callback 和 `[ContentHeight]` 诊断日志。

### 收益

- 每次翻页少一次 post-frame callback + `findRenderObject()` 遍历
- 不要对 Flutter 引擎来说 `findRenderObject()` 是一次 layout-pass 触达

---

## 候选十一 · LayoutBuilder 嵌套布局链 🔷

> 来源：`paginated_renderer.dart` + `block_page_content.dart` — 4 层 LayoutBuilder

### 当前布局链

```
LayoutBuilder (paginated_renderer.dart:218)  ← 外层容器尺寸
  └─ LayoutBuilder (paginated_renderer.dart:406)  ← 翻页区域内容
       └─ LayoutBuilder (paginated_renderer.dart:484)  ← blocks 容器
            └─ LayoutBuilder (block_page_content.dart:43)  ← 内联块
```

每个 `LayoutBuilder` 在布局阶段都独立运行一次 builder callback。嵌套导致 layout-pass 被串行化——外层算完内层才能算。

### 优化方向

- 如果约束链是简单透传，可替换为 `SizedBox` / `ConstrainedBox`（已知尺寸时）
- 需逐层验证每个 `LayoutBuilder` 是否真依赖运行时约束
- 对深嵌套页面可能减少 1-3ms 的布局时间

---

## 候选十二 · RepaintBoundary 粒度过粗 🔷

> 来源：`block_page_content.dart:37` — 整页内容在一个 `RepaintBoundary` 中

### 问题

`block_page_content.dart:37` 将整页所有 blocks 放在一个 `RepaintBoundary` 下。
当该页某张图片加载完成时（`Image.memory` 内部触发 repaint），整个 `RepaintBoundary` 重绘——包括其他已渲染的文本 block。

### 优化方向

- 将每张 `EpubBlockImage` 单独包裹 `RepaintBoundary`（图片加载完成只重绘图片区域）
- 文本 block 稳定后不需要额外 repaint
- 页面上图片太多时（10+）可能得不偿失，需测试找到最佳粒度

---

### 现状

每次 Rust 侧 API 签名变更后都需要运行 `flutter_rust_bridge_codegen generate`，
该命令对所有 129 个函数重新生成代码（即使只改了一个）。
`frb_generated.dart` 9810 行 / 298KB，codegen 时间随 API 数量线性增长。

### 方向

- 利用 FRB 2.x 的 `--watch` 模式（持续监听 Rust 文件变更，增量生成）
- 或通过 FRB 的 `only` 参数指定只生成修改过的函数
- 需验证 FRB 2.12.0 的支持度

---

# 第四卷：其他零散模式

## 候选十三 · ScrollController 多 Listener 链式重建 🔷

> 来源：`scroll_mode_renderer.dart` 多层 widget 绑定到同一个 `ScrollController`

scroll 模式下 `ScrollController` 被多层 widget 共享。每次滚动像素触发所有 listener。
如果多个 listener 各自调用 `setState`，导致链式重建。

### 验证方法

添加计数器：一次像素滚动触发了多少次 `build()`。
如果 count > 预期的 widget 数量（每个帧 1-2 次重建），说明存在重建蔓延。

---

## 候选十四 · 同级数据多个 FRB 往返 🔷

> 模式：同一页面需要多个 List API，但各自独立走 FFI

### 假设（需验证）

```dart
// 书架页面可能同时需要
final books = await bookApi.listBooks();
final shelfBooks = await bookApi.listBookshelfBooks();  // 两次 FFI
```

### 优化方向

- 合并为一个复合 struct 返回，省一次 FFI 往返（~0.5-1ms）
- 更主要的：如果书架是首屏，减少串行请求的「瀑布」

---

# 更新优先级总览

| # | 候选 | 卷 | 收益 | 风险 | 验证时机 |
|---|------|----|------|------|---------|
| 1 | 📦 图片 RGBA 直通 | FFI 边界 | 🔶 中 | 低 | **Phase 12 已纳入** |
| 2 | 🖼️ 封面 RGBA 直通 | FFI 边界 | 🔷 低 | 低 | 随 N2 架构审查评估 |
| 3 | 🔙 IR → plain fallback | FFI 边界 | 🔷 低 | 低 | ✅ 已结构化记录，N3 继续审计根因 |
| 4 | 📸 图片批量预取 FFI 合并 | FFI 边界 | 🔷 低 | 低 | 随 N4 边界测试验证 |
| 5 | 📖 `get_chapter_plain` 冗余 | FFI 边界 | 🔷 低 | 低 | ✅ 双语正常路径已移除 |
| 6 | 📚 词典查词缓存 | FFI 边界 | 🔷 低 | 低 | 随手做 |
| 7 | 🔄 热路径 CRUD 批量化 | FFI 边界 | 🔹 极低 | 低 | 有症状时再动 |
| 8 | 🏗️ IR 大 Struct 序列化 | FFI 边界 | 🔶 中 | 高 | 先测 RTT 再决定 |
| 9 | 📄 PageCurl 动画全重建 | 渲染管线 | 🔶 中 | 低 | ✅ 已隔离并加组件测试 |
| 10 | 🐞 `_ContentMeasurer` 泄漏 | 渲染管线 | 🔷 低 | 极低 | ✅ 已删除 |
| 11 | 📐 LayoutBuilder 嵌套 | 渲染管线 | 🔷 低 | 低 | 逐层验证约束链 |
| 12 | 🖌️ RepaintBoundary 边界 | 渲染管线 | 🔷 低 | 低 | 图片密集页 profile |
| 13 | 🔄 FRB codegen 增量 | 开发者体验 | 🔷 低 | 低 | 验证 2.12 支持度 |
| 14 | 📜 ScrollController 链式重建 | 渲染管线 | 🔷 低 | 低 | build 调用计数 |
| 15 | 🔗 同级 API 多往返 | FFI 边界 | 🔹 极低 | 低 | 书架首屏 profile |
