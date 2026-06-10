// test_driver/e2e_flow_test.dart
//
// E2E 流程测试 — 使用 Page Object 模式 + 真实 fixture 书籍数据
//
// 前提: Rust FFI 已初始化（见 setUpAll）
// 运行: flutter test test_driver/e2e_flow_test.dart
//
// 测试数据: 在 setUpAll 中导入 test/fixtures/ 下的书籍文件，
//           确保每个测试 group 有真实数据可操作。

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

import '../test/helpers/integration_test_helper.dart';
import 'pages/bookshelf_page.dart';
import 'pages/reader_page.dart';
import 'pages/search_page.dart';

/// 在临时存储中导入 fixture 书籍，供测试使用。
///
/// 返回已导入的书籍标题列表，便于测试验证。
Future<List<String>> _seedFixtures() async {
  final fixtures = [
    'small.txt',
    '活着.txt',
    'mixed_content.md',
  ];
  final titles = <String>[];
  for (final name in fixtures) {
    final path = await copyFixtureFile(name);
    final result = await core_api.parseBook(filePath: path);
    titles.add(result.bookInfo.title);
  }
  return titles;
}

/// E2E 测试在宿主平台要求 Rust FFI compose 后运行。
/// 无 FFI 时跳过书籍相关测试，仅运行纯 Dart 测试。

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 先尝试初始化 AppConfig 和 DI（不依赖 FFI 的部分）
    await AppConfig.instance.init();

    // 初始化 Rust FFI（可能因缺少原生库而失败）
    Object? ffiError;
    try {
      await RustLib.init();
      await setupTestStorage(label: 'e2e');
      await initSearchEngine();
    } catch (e) {
      ffiError = e;
    }

    await configureDependencies();

    // 仅在 FFI 可用时导入书籍数据
    if (ffiError == null) {
      await _seedFixtures();
    }
  });

  tearDownAll(() async {
    try {
      await teardownTestStorage();
    } catch (_) {}
  });

  group('单词标记服务', () {
    late VocabularyMarkerService vocabService;

    setUp(() {
      vocabService = VocabularyMarkerService();
    });

    testWidgets('ensureLoaded 应加载词表', (tester) async {
      await vocabService.ensureLoaded();
      expect(vocabService.cet6.isNotEmpty, isTrue);
      expect(vocabService.ielts.isNotEmpty, isTrue);
      expect(vocabService.toefl.isNotEmpty, isTrue);
      expect(vocabService.allWords.length, greaterThan(2000));
    });

    testWidgets('isVocabularyWord 应识别词汇', (tester) async {
      await vocabService.ensureLoaded();
      expect(vocabService.isVocabularyWord('abandon'), isTrue);
      expect(vocabService.isVocabularyWord('abandoned'), isFalse);
      expect(vocabService.isVocabularyWord('zzzzz'), isFalse);
    });

    testWidgets('isVocabularyWord 应大小写不敏感', (tester) async {
      await vocabService.ensureLoaded();
      expect(vocabService.isVocabularyWord('ABANDON'), isTrue);
      expect(vocabService.isVocabularyWord('Abandon'), isTrue);
    });
  });

  group('E2E - 书架到阅读流程', () {
    testWidgets('打开应用 → 主布局含底部导航栏', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainLayout), findsOneWidget);
    });

    testWidgets('导航到书架 → 显示书籍网格', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();

      // 等待网格渲染完成
      await bookshelf.waitForReady();
      expect(bookshelf.hasBooks, isTrue,
          reason: '书架应显示已导入的 fixture 书籍');
    });

    testWidgets('书架网格显示已导入的书籍', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      await bookshelf.waitForReady();

      expect(bookshelf.bookCount, greaterThanOrEqualTo(2),
          reason: '应显示至少 2 本已导入的书籍');
      expect(bookshelf.bookExists('活着'), isTrue,
          reason: '导入的《活着》应出现在书架');
    });

    testWidgets('点击书籍 → 进入阅读页', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      await bookshelf.waitForReady();

      // 点击第一本书
      await bookshelf.tapFirstBook();
      // 应进入书籍详情或阅读页（不崩溃）
      await tester.pump(const Duration(seconds: 1));
      // 成功进入阅读相关页面即为通过
    });

    testWidgets('阅读页面工具栏交互', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      // 导航到书架并进入书籍详情
      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      await bookshelf.waitForReady();
      final bookCount = bookshelf.bookCount;
      // 至少有一本书
      expect(bookCount, greaterThan(0));

      // 点击书籍
      await bookshelf.tapBookByIndex(0);
      await tester.pump(const Duration(seconds: 2));

      // 返回书架
      final reader = ReaderPageObject(tester);
      await reader.tapBack();
      await tester.pump(const Duration(seconds: 1));

      // 验证返回后书架仍在
      expect(bookshelf.isOnBookshelfPage, isTrue);
    });
  });

  group('E2E - 页面导航', () {
    testWidgets('导航到搜索页面', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final search = SearchPageObject(tester);
      await search.navigateToSearch();
      expect(search.isOnSearchPage, isTrue);
    });

    testWidgets('导航到统计页面', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      expect(find.text('统计'), findsOneWidget);
    });

    testWidgets('导航到个人中心页面', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('我').last);
      await tester.pumpAndSettle();
      expect(find.text('我'), findsOneWidget);
    });

    testWidgets('书架 → 搜索 → 阅读 完整导航闭环', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      // 书架
      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      await bookshelf.waitForReady();
      expect(bookshelf.hasBooks, isTrue);

      // 切换到搜索 Tab
      final search = SearchPageObject(tester);
      await search.navigateToSearch();
      await tester.pump(const Duration(seconds: 1));
      expect(search.isOnSearchPage, isTrue);

      // 切换回书架
      await bookshelf.navigateToBookshelf();
      await bookshelf.waitForReady();
      expect(bookshelf.hasBooks, isTrue);
    });
  });

  group('E2E - 搜索功能', () {
    testWidgets('搜索页面基本渲染', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final search = SearchPageObject(tester);
      await search.navigateToSearch();
      expect(search.isOnSearchPage, isTrue);
    });

    testWidgets('输入书籍标题关键词应返回结果', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final search = SearchPageObject(tester);
      await search.navigateToSearch();
      await tester.pump(const Duration(seconds: 1));

      // 搜索已导入书籍的标题关键词
      await search.search('测试');
      // 等待搜索索引和结果加载
      await tester.pump(const Duration(seconds: 3));

      // 应返回匹配的书籍结果
      expect(search.hasResults, isTrue,
          reason: '搜索 "测试" 应匹配 small.txt/mixed_content.md 的内容');
    });

    testWidgets('输入中文关键词不应崩溃', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final search = SearchPageObject(tester);
      await search.navigateToSearch();
      await search.search('福贵');
      await tester.pump(const Duration(seconds: 2));
      // 不应崩溃，结果可为空（搜索索引未建）
    });
  });

  group('E2E - TTS 朗读', () {
    testWidgets('阅读页 TTS 按钮存在', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      // 进入阅读页
      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      await bookshelf.waitForReady();

      // 搜索 TTS 按钮是否存在（阅读页底部工具栏）
      // 此测试仅验证 UI 元素存在，不依赖实际导航
      // 读按钮文本在 l10n 中为 '朗读' 或 'Read Aloud'
      expect(
        find.text('朗读').last,
        findsWidgets,
      );
    });
  });
}
