// test/features/reader/page/widgets/paginated_renderer_test.dart
//
// 覆盖：
//   P1.1 — buildSinglePageContent 单元测试
//   P2.1 — PaginatedModeRenderer 代码路径
//
// buildSinglePageContent 为顶层函数，所有依赖通过参数注入，纯 widget 测试。
// PaginatedModeRenderer 需要 mock ReaderRepository 以隔离 FFI 依赖。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/rendering/page_curl_widget.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_renderer.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockDataSource extends Mock implements ReaderRenderDataSource {}

void _stubDataSource(_MockDataSource dataSource) {
  when(() => dataSource.preloadGeneration).thenReturn(ValueNotifier<int>(0));
  when(() => dataSource.prevChapterStaging).thenReturn(null);
  when(() => dataSource.nextChapterStaging).thenReturn(null);
}

ReaderRenderConfig _config({
  double fontSize = 16,
  double lineHeight = 1.5,
  Color textColor = Colors.black,
  String fontFamily = '',
}) {
  return ReaderRenderConfig(
    textColor: textColor,
    backgroundColor: Colors.white,
    fontSize: fontSize,
    lineHeight: lineHeight,
    fontFamily: fontFamily,
    letterSpacing: 0,
    paragraphSpacing: 12,
    pageMargin: 16,
    showVocabularyMark: false,
    vocabularyWords: const {},
  );
}

Widget _buildInApp(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: widget),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ========================
  // P1.1 — buildSinglePageContent
  // ========================

  group('buildSinglePageContent', () {
    testWidgets('dataSource 返回 null 时渲染加载指示器', (tester) async {
      final dataSource = _MockDataSource();
      when(() => dataSource.pageContent(any())).thenReturn(null);

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              dataSource: dataSource,
              config: _config(),
              highlights: const [],
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('正常页面内容渲染 SelectableText.rich', (tester) async {
      final dataSource = _MockDataSource();
      when(() => dataSource.pageContent(0)).thenReturn('Hello world.');

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              dataSource: dataSource,
              config: _config(),
              highlights: const [],
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('空内容不崩溃', (tester) async {
      final dataSource = _MockDataSource();
      when(() => dataSource.pageContent(0)).thenReturn('');

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              dataSource: dataSource,
              config: _config(),
              highlights: const [],
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  // ========================
  // P2.1 — PaginatedModeRenderer
  // ========================

  group('PaginatedModeRenderer', () {
    testWidgets('curl 皮肤+descriptors 渲染 PageCurlWidget', (tester) async {
      final dataSource = _MockDataSource();
      _stubDataSource(dataSource);
      when(() => dataSource.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 10,
          isLastPage: false,
          firstParagraphIndex: 0,
          lastParagraphIndex: 0,
        ),
      ]);
      when(() => dataSource.pageContent(0)).thenReturn('Page content.');

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            content: 'Page content.',
            highlights: const [],
            readingMode: ReadingMode.pagination,
            paginationSkin: PaginationSkin.curl,
          ),
        ),
      );

      expect(find.byType(PageView), findsNothing);
      expect(find.byType(PageCurlWidget), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('slide 皮肤+descriptors 渲染 PageView.builder', (
      tester,
    ) async {
      final dataSource = _MockDataSource();
      _stubDataSource(dataSource);
      when(() => dataSource.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 10,
          isLastPage: false,
          firstParagraphIndex: 0,
          lastParagraphIndex: 0,
        ),
      ]);
      when(() => dataSource.pageContent(0)).thenReturn('Page content.');

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            content: '',
            highlights: const [],
            readingMode: ReadingMode.pagination,
          ),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('无 descriptors 走 fallback 分页', (tester) async {
      final dataSource = _MockDataSource();
      _stubDataSource(dataSource);
      when(() => dataSource.descriptors).thenReturn(null);

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            content: 'A long text for fallback pagination in the test.',
            highlights: const [],
            readingMode: ReadingMode.pagination,
          ),
        ),
      );

      expect(find.byType(PageView), findsNothing);
      expect(find.text('分页数据加载失败'), findsOneWidget);
    });
  });
}
