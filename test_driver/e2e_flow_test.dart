// test_driver/e2e_flow_test.dart
//
// E2E 流程测试 — 使用 Page Object 模式
//
// 前提: Rust FFI 已初始化（见 setUpAll）
// 运行: flutter test integration_test/

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/src/rust/api/data/init.dart';
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

import 'pages/bookshelf_page.dart';
import 'pages/reader_page.dart';
import 'pages/search_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
    final tempDir = await getTemporaryDirectory();
    await initStorage(dataDir: '${tempDir.path}/test_data');
    await initSearchEngine();
    await AppConfig.instance.init();
    await configureDependencies();
  });

  tearDownAll(() async {
    // 清理测试数据
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
    testWidgets('打开应用 → 显示主布局', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      // 主布局渲染
      expect(find.byType(MainLayout), findsOneWidget);
    });

    testWidgets('导航到书架 → 显示书架页面', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      expect(bookshelf.isOnBookshelfPage, isTrue);
    });

    testWidgets('完整流程: 书架 → 书籍详情 → 阅读页', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      // Step 1: 导航到书架
      final bookshelf = BookshelfPageObject(tester);
      await bookshelf.navigateToBookshelf();
      expect(bookshelf.isOnBookshelfPage, isTrue);

      // Step 2: 点击书籍（如果存在）
      // 注意: 测试环境可能无实际书籍，此处仅验证导航不崩溃
      await bookshelf.tapFirstBook();
      await tester.pump(const Duration(seconds: 1));

      // Step 3: 验证阅读页面（如果已导航）
      // 成功进入阅读页则不崩溃
    });

    testWidgets('阅读页面: 工具栏交互', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final reader = ReaderPageObject(tester);

      // 点击屏幕中央（阅读页内点击不应崩溃）
      await reader.tapCenter();
      await tester.pump();

      // 点击返回（不应崩溃）
      await reader.tapBack();
      await tester.pump(const Duration(seconds: 1));
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

    testWidgets('输入搜索关键词不应崩溃', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2));

      final search = SearchPageObject(tester);
      await search.navigateToSearch();
      // 输入中文关键词
      await search.enterSearchQuery('算法');
      await tester.pump(const Duration(seconds: 1));
      // 不应崩溃即可
    });
  });
}
