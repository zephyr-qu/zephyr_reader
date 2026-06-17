import 'package:flutter/material.dart';
import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/pagination_session_factory.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart';
import 'package:zephyr_reader/features/reader/domain/model/page_info.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';

export 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart'
    show ReadingProgressData;

@Injectable(as: ReaderRepositoryInterface)
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
  String? pageContent(int pageIndex) {
    final cached = _session.pageContent(pageIndex);
    if (cached != null) return cached;
    // Cache miss：返回 null（Renderer 展示 placeholder），后台异步取
    return null;
  }


  @override
  void warmPageCache(int pageIndex, String content) {
    _session.warmPageCache(pageIndex, content);
  }

  @override
  ValueNotifier<int> get preloadGeneration => _chapterContent.preloadGeneration;

  @override
  NextChapterStaging? get nextChapterStaging =>
      _chapterContent.nextChapterStaging;

  @override
  NextChapterStaging? get prevChapterStaging =>
      _chapterContent.prevChapterStaging;

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
      _chapterContent.loadContent(bookId, chapterId, readingMode: readingMode);

  @override
  void disposePagination() => _session.dispose();
  @override
  int? get sessionConfigHash => _session.sessionConfigHash;
  @override
  int? get sessionChapterIndex => _session.sessionChapterIndex;
  @override
  bool get sessionIsPartial => _session.sessionIsPartial;

  @override
  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) => _session.repaginateInPlace(
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
  }) => _session.beginPaginate(
    bookId: bookId,
    chapterIndex: chapterIndex,
    params: params,
    maxChars: maxChars,
  );
  @override
  Future<({int totalPages, bool isPartial})> beginPaginateFromCache({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) => _session.beginPaginateFromCache(
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
  }) => _session.expandToFullChapter(
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
  Future<void> preloadNextChapterStaging(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  }) => _chapterContent.preloadNextChapterStaging(
    bookId,
    chapterIndex,
    fontSize: fontSize,
    lineHeight: lineHeight,
    width: width,
    height: height,
    padding: padding,
    devicePixelRatio: devicePixelRatio,
    fontFamily: fontFamily,
  );


  @override
  Future<void> preloadPreviousChapterStaging(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  }) => _chapterContent.preloadPreviousChapterStaging(
    bookId,
    chapterIndex,
    fontSize: fontSize,
    lineHeight: lineHeight,
    width: width,
    height: height,
    padding: padding,
    devicePixelRatio: devicePixelRatio,
    fontFamily: fontFamily,
  );

  @override
  void clearAdjacentStaging() => _chapterContent.clearAdjacentStaging();
  @override
  void clearNextChapterStaging() => _chapterContent.clearNextChapterStaging();

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
  void ensurePageWindow(int centerPage) {
    _session.ensureWindow(centerPage);
    preloadGeneration.value++;
  }

  @override
  void ensureWindow(int centerPage) => ensurePageWindow(centerPage);

  @override
  Future<ReadingProgressData?> loadReadingProgress(String bookId) =>
      _progress.load(bookId);
}
