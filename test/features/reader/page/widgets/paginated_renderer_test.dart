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
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/rendering/page_curl_widget.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_renderer.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockDataSource extends Mock implements ReaderRenderDataSource {}

void _stubDataSource(_MockDataSource dataSource) {
  when(() => dataSource.preloadGeneration).thenReturn(ValueNotifier<int>(0));
  when(() => dataSource.prevChapterStaging).thenReturn(null);
  when(() => dataSource.nextChapterStaging).thenReturn(null);
  when(
    () => dataSource.sessionMode,
  ).thenReturn(ChapterPaginationMode.plainText);
  when(() => dataSource.sessionFilePath).thenReturn(null);
  when(() => dataSource.pageBlocks(any())).thenReturn(null);
}

_MockDataSource _mockDataSource() {
  final dataSource = _MockDataSource();
  _stubDataSource(dataSource);
  return dataSource;
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
    testWidgets('dataSource 返回 null 时渲染骨架占位（无 spinner）', (tester) async {
      final dataSource = _mockDataSource();
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

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('正常页面内容渲染 SelectableText.rich', (tester) async {
      final dataSource = _mockDataSource();
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

    testWidgets('contentBlocks 模式渲染 Image 占位', (tester) async {
      final dataSource = _mockDataSource();
      when(
        () => dataSource.sessionMode,
      ).thenReturn(ChapterPaginationMode.contentBlocks);
      when(() => dataSource.sessionFilePath).thenReturn('/books/test.epub');
      when(() => dataSource.pageBlocks(0)).thenReturn([
        const PageBlockSlice.image(
          PageImageBlockSlice(
            blockIndex: 1,
            assetId: 'img_cover',
            layout: ImageBlockLayout.inlineContain,
            alt: 'cover',
          ),
        ),
      ]);

      await tester.pumpWidget(
        _buildInApp(
          LayoutBuilder(
            builder: (context, constraints) => buildSinglePageContent(
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

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('空内容不崩溃', (tester) async {
      final dataSource = _mockDataSource();
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

    testWidgets('slide 皮肤+descriptors 渲染 PageView.builder', (tester) async {
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

    testWidgets('contentBlocks staging 渲染 Image 占位', (tester) async {
      final dataSource = _mockDataSource();
      when(() => dataSource.nextChapterStaging).thenReturn(
        NextChapterStaging(
          chapterIndex: 1,
          configHash: 0x1234,
          descriptors: const [
            PageDescriptor(
              pageIndex: 0,
              startOffset: 0,
              endOffset: 80,
              isLastPage: false,
              firstParagraphIndex: 0,
              lastParagraphIndex: 0,
            ),
          ],
          firstPageContent: '',
          isPartial: false,
          paginationMode: ChapterPaginationMode.contentBlocks,
          filePath: '/books/test.epub',
          anchorPageBlocks: const [
            PageBlockSlice.image(
              PageImageBlockSlice(
                blockIndex: 1,
                assetId: 'img_staging',
                layout: ImageBlockLayout.inlineContain,
                alt: 'staging',
              ),
            ),
          ],
        ),
      );
      when(() => dataSource.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: true,
          firstParagraphIndex: 0,
          lastParagraphIndex: 0,
        ),
      ]);
      when(() => dataSource.pageContent(0)).thenReturn('Current page.');

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(initialPage: 1),
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            content: 'Current page.',
            highlights: const [],
            readingMode: ReadingMode.pagination,
            hasNextChapter: true,
          ),
        ),
      );

      await tester.pump();
      final stagingImageIcon = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.image_outlined ||
                w.icon == Icons.broken_image_outlined),
      );
      expect(stagingImageIcon, findsOneWidget);
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

    // ========================
    // T5 — staging virtual pages (ADR-012 行为锁定)
    // ========================

    group('staging virtual pages', () {
      late _MockDataSource dataSource;

      setUp(() {
        dataSource = _mockDataSource();
      });

      testWidgets('prev staging hit renders content (not spinner)', (
        tester,
      ) async {
        when(() => dataSource.prevChapterStaging).thenReturn(
          NextChapterStaging(
            chapterIndex: -1,
            configHash: 0xABCD,
            descriptors: const [
              PageDescriptor(
                pageIndex: 0,
                startOffset: 0,
                endOffset: 100,
                isLastPage: true,
                firstParagraphIndex: 0,
                lastParagraphIndex: 0,
              ),
            ],
            firstPageContent: 'Previous chapter content.',
            isPartial: false,
          ),
        );
        when(() => dataSource.descriptors).thenReturn([
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 80,
            isLastPage: false,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
          ),
        ]);
        when(() => dataSource.pageContent(0)).thenReturn('Current page.');

        await tester.pumpWidget(
          _buildInApp(
            PaginatedModeRenderer(
              config: _config(),
              pageController: PageController(initialPage: 0),
              dataSource: dataSource,
              bookId: 'test_book',
              chapterId: 0,
              pageIndex: 0,
              content: 'Current page.',
              highlights: const [],
              readingMode: ReadingMode.pagination,
              hasPreviousChapter: true,
            ),
          ),
        );

        // Virtual page 0 = previous chapter staging page → must NOT show spinner
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Should render staging page content
        expect(find.text('Previous chapter content.'), findsOneWidget);
      });

      testWidgets('next staging hit on cross chapter page renders content', (
        tester,
      ) async {
        when(() => dataSource.nextChapterStaging).thenReturn(
          NextChapterStaging(
            chapterIndex: 1,
            configHash: 0xABCD,
            descriptors: const [
              PageDescriptor(
                pageIndex: 0,
                startOffset: 0,
                endOffset: 100,
                isLastPage: false,
                firstParagraphIndex: 0,
                lastParagraphIndex: 0,
              ),
            ],
            firstPageContent: 'Next chapter first page.',
            isPartial: false,
          ),
        );
        when(() => dataSource.descriptors).thenReturn([
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 80,
            isLastPage: true,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
          ),
        ]);
        when(() => dataSource.pageContent(0)).thenReturn('Current last page.');

        await tester.pumpWidget(
          _buildInApp(
            PaginatedModeRenderer(
              config: _config(),
              // initialPage 1 = cross-chapter virtual page (beyond descriptors[0])
              pageController: PageController(initialPage: 1),
              dataSource: dataSource,
              bookId: 'test_book',
              chapterId: 0,
              pageIndex: 0,
              content: 'Current last page.',
              highlights: const [],
              readingMode: ReadingMode.pagination,
              hasNextChapter: true,
            ),
          ),
        );

        // Virtual page 1 = next chapter staging page → must NOT show spinner
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Should render staging page content
        expect(find.text('Next chapter first page.'), findsOneWidget);
      });

      /// ADR-012: staging miss 时 _extendedPageCount 排除跨章虚拟页，
      /// 用户翻到末页即停止。hold 帧由 _buildCrossChapterPage 兜底。
      testWidgets('next staging miss excludes cross-chapter page', (
        tester,
      ) async {
        // nextChapterStaging is null → _stagingReadyForNext() = false
        when(() => dataSource.descriptors).thenReturn([
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 80,
            isLastPage: true,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
          ),
        ]);
        when(() => dataSource.pageContent(0)).thenReturn('Current last page.');

        await tester.pumpWidget(
          _buildInApp(
            PaginatedModeRenderer(
              config: _config(),
              pageController: PageController(initialPage: 0),
              dataSource: dataSource,
              bookId: 'test_book',
              chapterId: 0,
              pageIndex: 0,
              content: 'Current last page.',
              highlights: const [],
              readingMode: ReadingMode.pagination,
              hasNextChapter: true,
            ),
          ),
        );

        // 跨章虚拟页被 _extendedPageCount 排除，仅渲染内容页
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Current last page.'), findsOneWidget);
      });

      /// ADR-012: prev staging miss 时，_buildPreviousChapterPage 返回 hold 帧（当前章首页），不展示 spinner。
      testWidgets('prev staging miss shows hold frame (not spinner)', (
        tester,
      ) async {
        // prevChapterStaging is null, but hasPreviousChapter = true
        when(() => dataSource.prevChapterStaging).thenReturn(null);
        when(() => dataSource.descriptors).thenReturn([
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 80,
            isLastPage: false,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
          ),
        ]);
        when(() => dataSource.pageContent(0)).thenReturn('Current first page.');

        await tester.pumpWidget(
          _buildInApp(
            PaginatedModeRenderer(
              config: _config(),
              // page 0 = prev virtual page (hasPreviousChapter=true)
              pageController: PageController(initialPage: 0),
              dataSource: dataSource,
              bookId: 'test_book',
              chapterId: 0,
              pageIndex: 0,
              content: 'Current first page.',
              highlights: const [],
              readingMode: ReadingMode.pagination,
              hasPreviousChapter: true,
            ),
          ),
        );

        // ADR-012: hold frame renders content, not spinner
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Hold frame shows current chapter's first page
        expect(find.text('Current first page.'), findsOneWidget);
      });
    });
  });
}
