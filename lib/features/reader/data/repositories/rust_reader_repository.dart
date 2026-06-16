import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/pagination_session_factory.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';

export 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart'
    show ReadingProgressData;

class ReaderRepository
    implements ReaderRepositoryInterface, ReaderRenderDataSource {
  ReaderRepository(
    this._chapterContent,
    this._progress,
    PaginationSessionFactory sessionFactory,
  ) : _session = sessionFactory.create();

  final ChapterContentRepository _chapterContent;
  final ProgressRepository _progress;
  final PaginationSession _session;

  // ==================== ReaderRenderDataSource ====================

  @override
  List<PageDescriptor>? get descriptors => _session.descriptors;

  @override
  String? pageContent(int pageIndex) => _session.pageContent(pageIndex);

  @override
  void warmPageCache(int pageIndex, String content) {
    _session.warmPageCache(pageIndex, content);
  }

  @override
  ValueNotifier<int> get preloadGeneration =>
      _chapterContent.preloadGeneration;

  @override
  String? getPreloadedNextChapterContent(
    int chapterIndex, {
    int pageIndex = 0,
  }) =>
      _chapterContent.getPreloadedNextChapterContent(
        chapterIndex,
        pageIndex: pageIndex,
      );

  @override
  TextSpan? get currentRichContent => _chapterContent.currentRichContent;

  @override
  List<RichParagraph>? get currentRichParagraphs =>
      _chapterContent.currentRichParagraphs;

  // ==================== ReaderRepositoryInterface ====================

  @override
  Future<List<Chapter>> getChapters(String bookId) =>
      _chapterContent.getChapters(bookId);

  @override
  Future<String> loadChapterContent(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  }) =>
      _chapterContent.loadContent(
        bookId,
        chapterId,
        readingMode: readingMode,
      );

  @override
  void disposePagination() => _session.dispose();
  @override
  int? get sessionConfigHash => _session.sessionConfigHash;

  @override
  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) =>
      _session.repaginateInPlace(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
      );

  @override
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) =>
      _session.beginPaginate(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
      );
  @override
  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) =>
      _session.expandToFullChapter(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
      );

  @override
  Future<String> loadChapterFirstSpine(String bookId, int chapterId) =>
      _chapterContent.loadFirstSpine(bookId, chapterId);

  @override
  Future<void> preloadChapter(String bookId, int chapterId) =>
      _chapterContent.preload(bookId, chapterId);

  @override
  Future<void> preloadNextChapterFirstPage(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
  }) =>
      _chapterContent.preloadNextChapterFirstPage(
        bookId,
        chapterIndex,
        fontSize: fontSize,
        lineHeight: lineHeight,
        width: width,
        height: height,
        padding: padding,
      );

  @override
  bool get hasPreloadedNextChapter =>
      _chapterContent.hasPreloadedNextChapter;

  @override
  void clearPreloadedNextChapter() =>
      _chapterContent.clearPreloadedNextChapter();

  @override
  List<PageInfo> paginateApproximate(
    String content, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) {
    return PaginationEngine.paginateApproximate(
      content,
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
    );
  }

  @override
  Future<List<PageInfo>> calculatePages({
    required String bookId,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) async {
    final content = await loadChapterContent(bookId, chapterId);
    final pages = PaginationEngine.paginateApproximate(
      content,
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
    );
    return pages;
  }

  @override
  void ensurePageWindow(int centerPage) => _session.ensureWindow(centerPage);


  @override
  Future<ReadingProgressData?> loadReadingProgress(String bookId) =>
      _progress.load(bookId);
}
