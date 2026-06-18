// test/features/reader/page/widgets/reader_content_test.dart
//
// 覆盖 P1.2 — PageCurlWidget + ReaderContent 集成
//
// ReaderContent 是 HookWidget，需要 mock ReaderRepository 隔离 FFI。
// 使用 TestWidgetsFlutterBinding + pumpWidget 渲染不同分支。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/rendering/page_curl_widget.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_content.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockDataSource extends Mock implements ReaderRenderDataSource {}

void _stubReaderDataSource(_MockDataSource dataSource) {
  when(() => dataSource.preloadGeneration).thenReturn(ValueNotifier<int>(0));
  when(() => dataSource.prevChapterStaging).thenReturn(null);
  when(() => dataSource.nextChapterStaging).thenReturn(null);
}

Widget _wrapApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderContent — readingMode == pageTurn', () {
    testWidgets('pageTurn 模式渲染 PageCurlWidget 而非 AnimatedSwitcher', (
      tester,
    ) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);
      when(
        () => dataSource.preloadGeneration,
      ).thenReturn(ValueNotifier<int>(0));
      when(() => dataSource.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: false,
          firstParagraphIndex: 0,
          lastParagraphIndex: 0,
        ),
      ]);
      when(() => dataSource.pageContent(0)).thenReturn('Page content text.');

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            totalPages: 1,
            renderConfig: const ReaderRenderConfig(
              textColor: Colors.black87,
              backgroundColor: Color(0xFFFAFAFA),
              fontSize: 16,
              lineHeight: 1.5,
              fontFamily: '',
              letterSpacing: 0,
              paragraphSpacing: 12,
              pageMargin: 16,
              showVocabularyMark: false,
              vocabularyWords: {},
            ),
            readingMode: ReadingMode.pageTurn,
            content: 'Page content text.',
            isLoading: false,
            highlights: const [],
            scrollBuilder: (_, _) => const SizedBox(),
            bilingualBuilder: (_, _, _) => const SizedBox(),
            paginatedBuilder: (_, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageCurlWidget), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });

    testWidgets('首屏 pageTurn 且 loading 时不渲染 PageCurlWidget', (tester) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);
      when(
        () => dataSource.preloadGeneration,
      ).thenReturn(ValueNotifier<int>(0));

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            totalPages: 0,
            renderConfig: const ReaderRenderConfig(
              textColor: Colors.black87,
              backgroundColor: Color(0xFFFAFAFA),
              fontSize: 16,
              lineHeight: 1.5,
              fontFamily: '',
              letterSpacing: 0,
              paragraphSpacing: 12,
              pageMargin: 16,
              showVocabularyMark: false,
              vocabularyWords: {},
            ),
            readingMode: ReadingMode.pageTurn,
            content: '',
            isLoading: true,
            highlights: const [],
            scrollBuilder: (_, _) => const SizedBox(),
            bilingualBuilder: (_, _, _) => const SizedBox(),
            paginatedBuilder: (_, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PageCurlWidget), findsNothing);
    });

    testWidgets('pageTurn 跨章虚拟页使用预加载 staging 内容', (tester) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);
      when(() => dataSource.preloadGeneration)
          .thenReturn(ValueNotifier<int>(0));
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
      when(() => dataSource.pageContent(0)).thenReturn('Page content text.');
      when(() => dataSource.nextChapterStaging).thenReturn(
        const NextChapterStaging(
          chapterIndex: 1,
          configHash: 0x1234,
          descriptors: [
            PageDescriptor(
              pageIndex: 0,
              startOffset: 0,
              endOffset: 80,
              isLastPage: false,
              firstParagraphIndex: 0,
              lastParagraphIndex: 0,
            ),
          ],
          firstPageContent: 'Preloaded next chapter text.',
          isPartial: true,
        ),
      );

      await tester.pumpWidget(
        _wrapApp(
          SizedBox(
            height: 600,
            child: ReaderContent(
              dataSource: dataSource,
              bookId: 'test_book',
              chapterId: 0,
              pageIndex: 0,
              totalPages: 1,
              renderConfig: const ReaderRenderConfig(
                textColor: Colors.black87,
                backgroundColor: Color(0xFFFAFAFA),
                fontSize: 16,
                lineHeight: 1.5,
                fontFamily: '',
                letterSpacing: 0,
                paragraphSpacing: 12,
                pageMargin: 16,
                showVocabularyMark: false,
                vocabularyWords: {},
              ),
              readingMode: ReadingMode.pageTurn,
              content: 'Page content text.',
              isLoading: false,
              hasNextChapter: true,
              highlights: const [],
              scrollBuilder: (_, _) => const SizedBox(),
              bilingualBuilder: (_, _, _) => const SizedBox(),
              paginatedBuilder: (_, _) => const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(PageCurlWidget), findsOneWidget);
      expect(find.text('Page content text.'), findsOneWidget);
      verifyNever(() => dataSource.warmPageCache(any(), any()));
    });

    testWidgets('pageTurn 虚拟上一章页使用 prevChapterStaging', (tester) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);
      when(() => dataSource.preloadGeneration)
          .thenReturn(ValueNotifier<int>(0));
      when(() => dataSource.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: false,
          firstParagraphIndex: 0,
          lastParagraphIndex: 0,
        ),
      ]);
      when(() => dataSource.pageContent(0)).thenReturn('Current chapter page.');
      when(() => dataSource.prevChapterStaging).thenReturn(
        const NextChapterStaging(
          chapterIndex: 0,
          configHash: 0x1234,
          descriptors: [
            PageDescriptor(
              pageIndex: 1,
              startOffset: 500,
              endOffset: 600,
              isLastPage: true,
              firstParagraphIndex: 0,
              lastParagraphIndex: 0,
            ),
          ],
          firstPageContent: 'Previous chapter last page.',
          isPartial: false,
        ),
      );

      await tester.pumpWidget(
        _wrapApp(
          SizedBox(
            height: 600,
            child: ReaderContent(
              dataSource: dataSource,
              bookId: 'test_book',
              chapterId: 1,
              pageIndex: 0,
              totalPages: 2,
              renderConfig: const ReaderRenderConfig(
                textColor: Colors.black87,
                backgroundColor: Color(0xFFFAFAFA),
                fontSize: 16,
                lineHeight: 1.5,
                fontFamily: '',
                letterSpacing: 0,
                paragraphSpacing: 12,
                pageMargin: 16,
                showVocabularyMark: false,
                vocabularyWords: {},
              ),
              readingMode: ReadingMode.pageTurn,
              content: 'Current chapter page.',
              isLoading: false,
              hasPreviousChapter: true,
              highlights: const [],
              scrollBuilder: (_, _) => const SizedBox(),
              bilingualBuilder: (_, _, _) => const SizedBox(),
              paginatedBuilder: (_, _) => const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(PageCurlWidget), findsOneWidget);
      expect(find.text('Current chapter page.'), findsOneWidget);
    });
  });

  group('ReaderContent — scroll/pagination/bilingual', () {
    testWidgets('scroll 模式不渲染 PageCurlWidget', (tester) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);
      when(
        () => dataSource.preloadGeneration,
      ).thenReturn(ValueNotifier<int>(0));

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            totalPages: 1,
            renderConfig: const ReaderRenderConfig(
              textColor: Colors.black87,
              backgroundColor: Color(0xFFFAFAFA),
              fontSize: 16,
              lineHeight: 1.5,
              fontFamily: '',
              letterSpacing: 0,
              paragraphSpacing: 12,
              pageMargin: 16,
              showVocabularyMark: false,
              vocabularyWords: {},
            ),
            readingMode: ReadingMode.scroll,
            content: 'Scroll mode content.',
            isLoading: false,
            highlights: const [],
            scrollBuilder: (_, _) => const SizedBox(),
            bilingualBuilder: (_, _, _) => const SizedBox(),
            paginatedBuilder: (_, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageCurlWidget), findsNothing);
    });

    testWidgets('pagination 模式不渲染 PageCurlWidget（走 AnimatedSwitcher）', (
      tester,
    ) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);

      when(
        () => dataSource.preloadGeneration,
      ).thenReturn(ValueNotifier<int>(0));
      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            totalPages: 1,
            renderConfig: const ReaderRenderConfig(
              textColor: Colors.black87,
              backgroundColor: Color(0xFFFAFAFA),
              fontSize: 16,
              lineHeight: 1.5,
              fontFamily: '',
              letterSpacing: 0,
              paragraphSpacing: 12,
              pageMargin: 16,
              showVocabularyMark: false,
              vocabularyWords: {},
            ),
            readingMode: ReadingMode.pagination,
            content: 'Pagination mode content.',
            isLoading: false,
            highlights: const [],
            scrollBuilder: (_, _) => const SizedBox(),
            bilingualBuilder: (_, _, _) => const SizedBox(),
            paginatedBuilder: (_, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(PageCurlWidget), findsNothing);
    });

    testWidgets('阅读模式切换时不抛异常', (tester) async {
      final dataSource = _MockDataSource();
      _stubReaderDataSource(dataSource);

      when(
        () => dataSource.preloadGeneration,
      ).thenReturn(ValueNotifier<int>(0));
      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            totalPages: 1,
            renderConfig: const ReaderRenderConfig(
              textColor: Colors.black87,
              backgroundColor: Color(0xFFFAFAFA),
              fontSize: 16,
              lineHeight: 1.5,
              fontFamily: '',
              letterSpacing: 0,
              paragraphSpacing: 12,
              pageMargin: 16,
              showVocabularyMark: false,
              vocabularyWords: {},
            ),
            readingMode: ReadingMode.scroll,
            content: 'Content.',
            isLoading: false,
            highlights: const [],
            scrollBuilder: (_, _) => const SizedBox(),
            bilingualBuilder: (_, _, _) => const SizedBox(),
            paginatedBuilder: (_, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 切到 pageTurn 模式
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
      when(() => dataSource.pageContent(0)).thenReturn('Content.');

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            dataSource: dataSource,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            totalPages: 1,
            renderConfig: const ReaderRenderConfig(
              textColor: Colors.black87,
              backgroundColor: Color(0xFFFAFAFA),
              fontSize: 16,
              lineHeight: 1.5,
              fontFamily: '',
              letterSpacing: 0,
              paragraphSpacing: 12,
              pageMargin: 16,
              showVocabularyMark: false,
              vocabularyWords: {},
            ),
            readingMode: ReadingMode.pageTurn,
            content: 'Content.',
            isLoading: false,
            highlights: const [],
            scrollBuilder: (_, _) => const SizedBox(),
            bilingualBuilder: (_, _, _) => const SizedBox(),
            paginatedBuilder: (_, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageCurlWidget), findsOneWidget);
    });
  });
}
