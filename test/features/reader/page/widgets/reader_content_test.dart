// test/features/reader/page/widgets/reader_content_test.dart
//
// 覆盖 P1.2 — PageCurlWidget + ReaderContent 集成
//
// ReaderContent 是 HookWidget，需要 mock ReaderRepository 隔离 FFI。
// 使用 TestWidgetsFlutterBinding + pumpWidget 渲染不同分支。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/page/ui/page_curl_widget.dart';
import 'package:zephyr_reader/features/reader/page/renderer/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_content.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockRepo extends Mock implements ReaderRepository {}

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
      final repo = _MockRepo();
      when(() => repo.preloadGeneration).thenReturn(ValueNotifier<int>(0));
      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: false,
        ),
      ]);
      when(() => repo.getPageContent(0)).thenReturn('Page content text.');

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            repo: repo,
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
      final repo = _MockRepo();
      when(() => repo.preloadGeneration).thenReturn(ValueNotifier<int>(0));

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            repo: repo,
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
  });

  group('ReaderContent — scroll/pagination/bilingual', () {
    testWidgets('scroll 模式不渲染 PageCurlWidget', (tester) async {
      final repo = _MockRepo();
      when(() => repo.preloadGeneration).thenReturn(ValueNotifier<int>(0));

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            repo: repo,
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
      final repo = _MockRepo();

      when(() => repo.preloadGeneration).thenReturn(ValueNotifier<int>(0));
      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            repo: repo,
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
      final repo = _MockRepo();

      when(() => repo.preloadGeneration).thenReturn(ValueNotifier<int>(0));
      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            repo: repo,
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
      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 10,
          isLastPage: false,
        ),
      ]);
      when(() => repo.getPageContent(0)).thenReturn('Content.');

      await tester.pumpWidget(
        _wrapApp(
          ReaderContent(
            repo: repo,
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
