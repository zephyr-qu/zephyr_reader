# Test Plan — Zephyr Reader

当前覆盖：**98 tests** (2026-06-09，新增 18 个)

测试层级：

```
Widget Test (组件)        → 现有主力
Integration Test (集成)   → 未搭建
Golden Test (截图对比)    → 未引入，ROI 不高暂不纳入
```

## Priority 1 (立即 / 与本次改动相关)

### 1.1 `buildSinglePageContent` 单元测试 ✅ 已实现

**文件：** `test/features/reader/page/widgets/paginated_renderer_test.dart`

| 用例 | 验证点 | 状态 |
|------|--------|------|
| `repo.getPageContent` 返回 null | 返回 `SizedBox` 占位（width:inf, height:600） | ✅ |
| 正常页面内容 | 渲染 `SelectableText.rich` | ✅ |
| `writingDirection == WritingDirection.vertical` | 走竖排分支（`Directionality.rtl`） | ✅ |
| 空内容 | 不崩溃，渲染 `SelectableText.rich` | ✅ |

### 1.2 PageCurlWidget + ReaderContent 集成 ✅ 已实现

**文件：** `test/features/reader/page/widgets/reader_content_test.dart`

| 用例 | 验证点 | 状态 |
|------|--------|------|
| `readingMode == pageTurn` | 渲染 `PageCurlWidget`，不渲染 `AnimatedSwitcher` | ✅ |
| `readingMode == scroll/pagination/bilingual` | 不受影响，不渲染 PageCurlWidget | ✅ |
| pageTurn + loading 首屏 | 不渲染 PageCurlWidget | ✅ |
| 其他 mode 切换回 pageTurn | hooks 顺序一致，不抛异常 | ✅ |

## Priority 2 (补充现有测试缺口)

### 2.1 PaginatedModeRenderer ✅ 已实现

**文件：** `test/features/reader/page/widgets/paginated_renderer_test.dart`

| 路径 | 入口 | 测试点 | 状态 |
|------|------|--------|------|
| descriptor 分页 | `build` → `descriptors != null` | pageTurn 模式走 `_buildPageTurn`，非 pageTurn 走 `PageView.builder` | ✅ |
| fallback 分页 | `build` → `descriptors == null`, `currentPages == null` | 文本切割后每页非空 | ✅ |
| 旧版 currentPages | `build` → `descriptors == null`, `currentPages != null` | 渲染缓存页内容 | ✅ |

### 2.2 ReaderRepository 缓存策略 ⏸️ 暂缓

**文件：** `test/features/reader/data/repositories/reader_repository_test.dart`（未创建）

| 用例 | 验证点 | 状态 |
|------|--------|------|
| `paginateChapter` 成功后 | `descriptors` 不为 null，前 5 页预加载到缓存 | ⏸️ 依赖 Rust FFI，需集成测试环境 |
| `getPageContent` 命中缓存 | 直接返回内容，不调用 `core_api.getPageContent` | ⏸️ 同上 |
| `getPageContent` 未命中 | 返回 null | ⏸️ 同上 |
| `ensurePageWindow` | 同步获取当前页，异步预加载 ±3 页 | ⏸️ 同上 |
| 页数超过 5 的缓存清理 | 远离的旧页被移除 | ⏸️ 同上 |

### 2.3 ReaderViewModel 翻页逻辑 ✅ 已实现

**文件：** `test/features/reader/application/reader_view_model_test.dart`

| 用例 | 验证点 | 状态 |
|------|--------|------|
| `loadPage(n)` | 委托给 `chapterManager.loadPage` | ✅ |
| `previousPage` | 非第一页时减 1 | ✅ |
| `previousPage` 边界 | 第 0 页时不变 | ✅ |
| `nextPage` | 非最后一页时加 1 | ✅ |
| `nextPage` 边界 | 最后一页时不变 | ✅ |
| `setReadingMode` | `readingMode` 信号更新 | ✅ |

## Priority 3 (长期)

### 3.1 Rust 侧单元测试

`rust/tests/unit_text_test.rs` 当前编译失败（crate 引用错误）。修复后覆盖：

| 模块 | 测试点 |
|------|--------|
| 文本排版 | `TypesetCalibration` 参数边界 |
| 分页算法 | 大文本/空文本/纯 CJK 分页结果 |
| 页面内容获取 | 按 offset 截取正确段落 |

### 3.2 ReaderPage 集成测试

**工具：** `integration_test` 包

| 场景 |
|------|
| 打开书籍 → scroll 模式 → 翻页 |
| 切换到 pageTurn 模式 → 左/右点击翻页 |
| 切换阅读模式不崩溃 |
| 切换章节后 pageIndex 正确重置 |

## 当前测试布局

```
test/
├── core/           ✅ theme, reader, utils, settings
├── features/
│   ├── backup/     ✅ 2 tests
│   ├── bookshelf/  ✅ 6 tests
│   ├── home/       (empty dir)
│   ├── profile/    ✅ 2 tests
│   ├── reader/     ✅ 10 tests（含新增 3 文件共 18 项）
│   ├── search/     ✅ 2 tests
│   ├── statistics/ ✅ 2 tests
│   └── sync/       ✅ 1 test
├── widget/         ✅ 11 tests (含 page_curl_widget 13 条)
├── helpers/        fixtures + test utilities
└── fixtures/        EPUB / TXT 测试文件
```

## CI 检查命令

```bash
# 静态分析
dart analyze lib/features/reader/

# 全部测试
flutter test

# 仅本项目新增测试
flutter test test/features/reader/page/widgets/
flutter test test/features/reader/
```
