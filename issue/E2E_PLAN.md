# E2E 测试补全计划

> 基于现有 `test_driver/e2e_flow_test.dart` 和 `test/fixtures/` 的补全规划。

---

## 现状总结

### 已有但"空转"
现有 E2E 测试 `e2e_flow_test.dart` 中有 4 个 group，但**没有导入任何真实书籍数据**：

```
书架到阅读流程  →  导航到书架 → "如果存在书籍就点" → 实际无数据，测试等于测了空壳
搜索功能        →  输入关键词 → "不应崩溃" → 无结果可验证
页面导航        →  切换 Tab → 只看崩溃不崩溃
单词标记服务    →  纯单元测试，不是 E2E
```

### 已有但可用的基础设施
- ✅ `test/fixtures/` — 8 个真实测试文件（txt、epub、md，含中英文、纯中文、混合内容）
- ✅ `test/helpers/integration_test_helper.dart` — `copyFixtureFile()`、`setupTestStorage()`、`parseTestBook()`、`deleteTestBook()`
- ✅ `test_driver/pages/` — Page Object 模式骨架
- ✅ `IntegrationTestWidgetsFlutterBinding` — 已配置，支持帧同步
- ✅ Rust FFI 初始化流程 — `setUpAll` 中已有

---

## 补全方案

### 阶段一：夯实基础设施

#### 1.1 数据播种 — setUpAll 中导入真实书籍

当前 setUpAll 只初始化了 storage/search，但没有导入任何书籍。测试启动时书架是空的。

需要增加一个 `_seedFixtures()` 步骤：

```dart
setUpAll(() async {
  await RustLib.init();
  final tempDir = await getTemporaryDirectory();
  await initStorage(dataDir: '${tempDir.path}/test_data');
  await initSearchEngine();
  await AppConfig.instance.init();
  await configureDependencies();
  // ★ 新增：导入测试书籍
  await _seedFixtures();
});

Future<void> _seedFixtures() async {
  // 导入不同类型书籍覆盖不同解析路径
  for (final fixture in ['活着.txt', 'small.txt', 'mixed_content.md']) {
    final path = await copyFixtureFile(fixture);
    await core_api.parseBook(filePath: path);
  }
  // 导入 EPUB 格式
  final epubPath = await copyFixtureFile('活着.epub');
  await core_api.parseBook(filePath: epubPath);
}
```

#### 1.2 强化 Page Object

当前 Page Object 用硬等（`pump(2s)`）和模糊文本查找（`find.text('书架').last`），脆弱且慢。

改进方向（每个 Page Object 三阶段）：

| 阶段 | 方法 | 说明 |
|------|------|------|
| wait | `waitForReady()` | 用 `pumpUntil` 或 key 检测页面就绪，替代 `pump(2s)` |
| act | 具体操作 | `tapBook(String title)`、`startTts()`、`switchMode()` |
| assert | `hasContent` | 验证真实数据渲染，替代 `evaluate().isNotEmpty` |

**关键改动 — 给关键 Widget 加 Key：**

```dart
// 在 lib 侧给重要容器加 Key（如没有的话）
// ReaderContent  → Key('reader_content')
// BookshelfGrid  → Key('bookshelf_grid')
// SearchResults  → Key('search_results')
// TtsButton      → Key('tts_button')
// PageTurnButton → Key('page_turn_next')
```

Page Object 改用 Key 定位：

```dart
class BookshelfPageObject {
  Future<void> waitForReady() async {
    await tester.pumpUntil(
      find.byKey(Key('bookshelf_grid')),
      const Duration(seconds: 10),
    );
  }

  bool get hasBooks =>
      find.byKey(Key('bookshelf_grid')).evaluate().isNotEmpty;

  Future<void> tapBookByTitle(String title) async {
    await tester.tap(find.byKey(Key('book_$title')));
    await tester.pumpAndSettle();
  }
}
```

---

### 阶段二：完整测试场景（按优先级）

#### P0 — 已有场景加数据（当前测试立刻变得有意义）

| 测试 | 当前 | 改进后 |
|------|------|--------|
| 书架→阅读流程 | 空书架，静默跳过 | 导入书籍后验证网格渲染、点击进入阅读页 |
| 搜索功能 | 输入无结果 | 搜索 "福贵" 验证结果列表非空 |
| 阅读页工具栏 | 点空白内容 | 点已有书籍进入阅读页，验证设置/返回 |

#### P1 — 阅读器核心流程

```
导入书籍
  ↓
验证书架网格渲染（列数、封面）
  ↓
点击进入书籍详情
  ↓
点击"开始阅读"
  ↓
验证阅读页面渲染内容
  ↓
切换阅读模式：scroll → paginated → bilingual
  ↓
翻页：点击下一页 → 验证内容变化
  ↓
返回书架
```

需要的 Fixture：`活着.txt`（284KB，多章节，适合分页）

#### P1 — 搜索完整流程

```
导入 medium.epub
  ↓
进入搜索页
  ↓
输入关键词 "kernel"
  ↓
验证搜索结果：匹配章节数 > 0
  ↓
点击结果项
  ↓
验证跳转到阅读页并高亮关键词
```

需要的 Fixture：`mixed_content.md`（含中英文段落、代码块、表格，适合搜索测试）

#### P2 — 双语阅读模式

```
导入 mixed_content.md
  ↓
进入阅读页
  ↓
切换到双语模式
  ↓
触发翻译（mock 翻译服务 or 验证 UI 切换不崩溃）
  ↓
验证双语对齐渲染
```

#### P2 — 批量管理

```
导入 3+ 本书
  ↓
进入书架
  ↓
开启批量选择模式
  ↓
选择 2 本书
  ↓
验证选中状态
  ↓
取消选择
```

#### P3 — TTS 朗读（需要 FFI + 真实语音引擎）

```
进入阅读页
  ↓
启动 TTS 朗读
  ↓
验证 isPlaying 信号为 true
  ↓
暂停
  ↓
验证 isPaused 信号为 true
  ↓
恢复
  ↓
停止
  ↓
验证 isPlaying 为 false
```

#### P3 — 备份/恢复流程

---

### 阶段三：Page Object 完整定义

#### BookshelfPageObject（增强）

```dart
class BookshelfPageObject {
  final WidgetTester tester;
  BookshelfPageObject(this.tester);

  // ── 等待 ──
  Future<void> waitForReady() async { /* pumpUntil(bookshelf_grid) */ }

  // ── 导航 ──
  Future<void> navigateToBookshelf();

  // ── 操作 ──
  Future<void> tapBookByIndex(int index);
  Future<void> tapBookByTitle(String title);
  Future<void> startBatchMode();
  Future<void> toggleBookSelection(int index);
  Future<void> importBook(String fixtureName);

  // ── 断言 ──
  bool get hasBooks;
  int get bookCount;
}
```

#### ReaderPageObject（新增）

```dart
class ReaderPageObject {
  final WidgetTester tester;
  ReaderPageObject(this.tester);

  // ── 等待 ──
  Future<void> waitForReady();

  // ── 翻页 ──
  Future<void> tapNextPage();
  Future<void> tapPrevPage();
  Future<void> swipeLeft();
  Future<void> swipeRight();

  // ── 阅读模式 ──
  Future<void> switchToScrollMode();
  Future<void> switchToPaginatedMode();
  Future<void> switchToBilingualMode();

  // ── TTS ──
  Future<void> tapTtsButton();
  Future<void> toggleTtsPlayback();

  // ── 返回 ──
  Future<void> goBack();
}
```

#### SearchPageObject（增强）

```dart
class SearchPageObject {
  // ── 等待 ──
  Future<void> waitForReady();

  // ── 导航 ──
  Future<void> navigateToSearch();

  // ── 操作 ──
  Future<void> search(String query);
  Future<void> tapResultByIndex(int index);

  // ── 断言 ──
  bool get hasResults;
  int get resultCount;
  bool hasResultContaining(String text);
}
```

#### BatchToolbarPageObject（新增）

```dart
class BatchToolbarPageObject {
  Future<void> selectAll();
  Future<void> deselectAll();
  Future<void> tapDelete();
  Future<void> tapAddToCategory();
}
```

---

### 阶段四：Fixtures 使用策略

| 文件 | 格式 | 大小 | 适用场景 |
|------|------|------|----------|
| `small.txt` | TXT | 4.5KB | 快速解析测试、分页验证 |
| `活着.txt` | TXT | 284KB | 完整 TTI 测试、多章节翻页 |
| `活着.epub` | EPUB | 185KB | EPUB 解析路径验证 |
| `mixed_content.md` | MD | 1.2KB | 搜索测试、双语模式、markdown 渲染 |
| `mixed_cjk_latin.txt` | TXT | — | TTS 中英交替朗读测试 |
| `pure_cjk.txt` | TXT | — | 纯中文内容、originalOnly TTS |
| `medium.epub` | EPUB | — | 中等规模 EPUB 解析 |
| `large.txt` | TXT | — | 大文件内存压力测试 |

每个测试 group 在 `setUpAll` 中用 `copyFixtureFile()` + `parseBook()` 导入其需要的 fixture，在 `tearDownAll` 中用 `deleteTestBook()` 清理。

---

### 阶段五：CI 集成

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [pull_request]

jobs:
  e2e:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test test_driver/e2e_flow_test.dart
        # 需要 macOS runner 编译 Rust -> FFI 可用
```

注意：E2E 测试依赖 Rust FFI，只能在桌面平台（macOS/Windows/Linux）上运行，不能在 Android/iOS 模拟器上跑。

---

## 工作分解

| 步骤 | 内容 | 估算 |
|------|------|------|
| 1. 数据播种 | `setUpAll` 中导入 fixture 书籍 | 0.5h |
| 2. 强化 Page Object | `pumpUntil` + Key 定位 | 1h |
| 3. 给 lib 侧加 Key | 给关键容器加 `Key('...')` | 0.5h |
| 4. 已有场景加数据 | 书架、搜索、阅读页测试更新 | 1h |
| 5. 新增 ReaderPageObject + 翻页测试 | 翻页、模式切换 | 1h |
| 6. 新增 SearchPageObject 增强 + 搜索测试 | 搜索→结果→跳转 | 1h |
| 7. 批量管理测试 | 选择/取消选择 | 1h |
| 8. TTS 测试 | 播放/暂停/恢复/停止 | 1h |
| 9. CI 集成 | GitHub Actions workflow | 0.5h |
| **合计** | | **~7.5h** |
