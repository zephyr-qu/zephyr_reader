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
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/page/widgets/paginated_renderer.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_render_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockRepo extends Mock implements ReaderRepository {}

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
    testWidgets('repo 返回 null 时渲染 Container 占位', (tester) async {
      final repo = _MockRepo();
      when(() => repo.getPageContent(any())).thenReturn(null);

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              repo: repo,
              config: _config(),
              highlights: const [],
              writingDirection: WritingDirection.horizontal,
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('正常页面内容渲染 SelectableText.rich', (tester) async {
      final repo = _MockRepo();
      when(() => repo.getPageContent(0)).thenReturn('Hello world.');

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              repo: repo,
              config: _config(),
              highlights: const [],
              writingDirection: WritingDirection.horizontal,
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('竖排书写方向走 Directionality.rtl 分支', (tester) async {
      final repo = _MockRepo();
      when(() => repo.getPageContent(0)).thenReturn('竖排\n测试');

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              repo: repo,
              config: _config(),
              highlights: const [],
              writingDirection: WritingDirection.vertical,
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      final directionalities = tester.widgetList<Directionality>(
        find.byType(Directionality),
      );
      expect(directionalities.last.textDirection, TextDirection.rtl);
    });

    testWidgets('空内容不崩溃', (tester) async {
      final repo = _MockRepo();
      when(() => repo.getPageContent(0)).thenReturn('');

      await tester.pumpWidget(
        _buildInApp(
          Builder(
            builder: (context) => buildSinglePageContent(
              context: context,
              pageIndex: 0,
              startOffset: 0,
              repo: repo,
              config: _config(),
              highlights: const [],
              writingDirection: WritingDirection.horizontal,
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
    testWidgets('pageTurn 模式+descriptors 走 _buildPageTurn 分支', (tester) async {
      final repo = _MockRepo();
      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 10,
          isLastPage: false,
        ),
      ]);
      when(() => repo.getPageContent(0)).thenReturn('Page content.');

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            repo: repo,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            content: 'Page content.',
            highlights: const [],
            readingMode: ReadingMode.pageTurn,
          ),
        ),
      );

      expect(find.byType(PageView), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('非 pageTurn 模式+descriptors 渲染 PageView.builder', (
      tester,
    ) async {
      final repo = _MockRepo();
      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 10,
          isLastPage: false,
        ),
      ]);
      when(() => repo.getPageContent(0)).thenReturn('Page content.');

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            repo: repo,
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

    testWidgets('无 descriptors 有 currentPages 走旧版分支', (tester) async {
      final repo = _MockRepo();
      when(() => repo.descriptors).thenReturn(null);
      when(() => repo.currentPages).thenReturn([
        PageInfo(
          pageIndex: 0,
          content: 'Old page content.',
          startOffset: 0,
          endOffset: 18,
        ),
      ]);

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            repo: repo,
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
      expect(find.text('Old page content.'), findsOneWidget);
    });

    testWidgets('无 descriptors 无 currentPages 走 fallback 分页', (tester) async {
      final repo = _MockRepo();
      when(() => repo.descriptors).thenReturn(null);
      when(() => repo.currentPages).thenReturn(null);

      await tester.pumpWidget(
        _buildInApp(
          PaginatedModeRenderer(
            config: _config(),
            pageController: PageController(),
            repo: repo,
            bookId: 'test_book',
            chapterId: 0,
            pageIndex: 0,
            content: 'A long text for fallback pagination in the test.',
            highlights: const [],
            readingMode: ReadingMode.pagination,
          ),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });
}
