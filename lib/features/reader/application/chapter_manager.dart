import 'dart:async';

import 'package:async/async.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../core/reader/reader_config.dart';
import '../data/repositories/rust_reader_repository.dart';

/// 章节管理器
///
/// 管理书籍/章节加载、分页导航、布局参数、自动滚动和搜索索引生命周期。
/// 不持有 UI 面板状态（由 ReaderViewModel 管理）。
class ChapterManager {
  final ReaderRepository _repo;
  final ReaderConfig _config;

  ChapterManager(this._repo, this._config);

  // ==================== 书籍状态 ====================

  /// 当前书籍 ID
  final bookId = signal<String>('0');

  /// 当前章节索引（从 0 开始）
  final chapterIndex = signal<int>(0);

  /// 章节列表
  final chapters = asyncSignal<List<Chapter>>(AsyncState.data([]));

  /// 当前章节内容
  final chapterContent = asyncSignal<String>(AsyncState.data(''));

  /// 总页数（分页模式）
  final totalPages = signal<int>(0);

  /// 当前页码
  final pageIndex = signal<int>(0);

  /// 当前阅读位置在章节内的字符偏移
  final currentCharOffset = signal<int>(0);

  /// 待消费的跳转目标偏移，用于通知阅读内容组件定位
  final pendingJumpCharOffset = signal<int?>(null);

  // ==================== UI 加载状态 ====================

  /// 是否正在加载
  final isLoading = signal<bool>(false);

  /// 错误信息
  final error = signal<String?>(null);

  // ==================== 布局参数 ====================

  /// 页面宽度（逻辑像素）
  final pageWidth = signal<double>(400);

  /// 页面高度（逻辑像素）
  final pageHeight = signal<double>(600);

  /// 设备像素比，用于 dp → px 转换
  final devicePixelRatio = signal<double>(1.0);

  /// 字符宽度校准数据（首次排版前测量一次，缓存复用）
  final _calibration = signal<CalibrationData?>(null);

  /// 当前字体系列名（由 FontRepository 提供）
  String _fontFamily = 'Noto Sans SC';

  /// 阅读模式
  final readingMode = signal<ReadingMode>(ReadingMode.pagination);

  // ==================== 搜索索引生命周期 ====================

  /// 章节全文索引操作，防止并发堆积
  CancelableOperation<void>? _searchIndexOperation;

  // ==================== 自动滚动 ====================

  /// 自动滚动触发器
  final autoScrollTick = signal<int>(0);

  Timer? _autoScrollTimer;

  // ==================== 计算信号 ====================

  /// 获取阅读进度百分比
  late final ReadonlySignal<String> progressText = computed(() {
    final totalChapters = chapters.value.value?.length ?? 0;
    if (totalChapters == 0) return '0%';
    final chapterProgress = (chapterIndex.value + 1) / totalChapters;
    return '${(chapterProgress * 100).toStringAsFixed(1)}%';
  });

  /// 获取当前章节标题
  late final ReadonlySignal<String> currentChapterTitle = computed(() {
    final chapterList = chapters.value.value ?? [];
    if (chapterIndex.value >= 0 && chapterIndex.value < chapterList.length) {
      return chapterList[chapterIndex.value].title;
    }
    return '加载中...';
  });

  static const int _preloadCount = 3;

  // ==================== 字体与校准 ====================

  /// 设置字体信息并重新校准
  void updateFont(String fontFamily) {
    _fontFamily = fontFamily;
    _calibration.value = null; // 字体变化后校准失效
  }

  // ==================== 章节加载 ====================

  /// 加载章节列表
  Future<void> loadChapters() async {
    chapters.value = AsyncState.loading();
    try {
      final data = await _repo.getChapters(bookId.value);
      chapters.value = AsyncState.data(data);
    } catch (e) {
      chapters.value = AsyncState.error(e);
      rethrow;
    }
  }

  /// 加载上次的阅读进度
  Future<void> loadLastProgress() async {
    try {
      final progress = await _repo.loadReadingProgress(bookId.value);
      if (progress != null) {
        chapterIndex.value = progress.chapterIndex;
        currentCharOffset.value = progress.charOffset;
      }
    } catch (e) {
      Logging.error('加载阅读进度失败', exception: e);
    }
  }

  /// 加载章节内容
  ///
  /// [onChapterLoaded] 在章节内容和分页完成后调用（用于 VM 加载高亮）。
  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    bool restartSession = true,
    Future<void> Function()? onChapterLoaded,
  }) async {
    chapterContent.value = AsyncState.loading();
    isLoading.value = true;

    try {
      final content = await _repo.loadChapterContent(
        bookId.value,
        chapterIndex,
      );

      // 将章节内容索引到 FTS5（不阻塞 UI，取消上一个并发索引）
      await _searchIndexOperation?.cancel();
      _searchIndexOperation = CancelableOperation.fromFuture(
        _indexForSearch(chapterIndex, content),
        onCancel: () {},
      );

      // █ 字符宽度校准（仅首次执行，字体/字号/DPR 变化后重置） █
      if (_calibration.value == null) {
        _calibration.value = await calibrateSafely(
          fontSize: _config.fontSize.value,
          devicePixelRatio: devicePixelRatio.value,
          fontFamily: _fontFamily,
        );
      }

      // █ 带 KV 缓存的分页排版 █
      List<PageInfo> pages;
      bool paginationFromCache = false;

      final result = await _repo.getPaginatedChapterPages(
        bookId: bookId.value,
        chapterIndex: chapterIndex,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: pageWidth.value,
        height: pageHeight.value,
        padding: 16,
        devicePixelRatio: devicePixelRatio.value,
        calibration: _calibration.value,
        fontFamily: _fontFamily,
      );

      if (result.isFallback) {
        Logging.warning(
          'loadChapter: Rust pagination fallback, using Dart approximate',
        );
        pages = await _repo.calculatePages(
          bookId: bookId.value,
          chapterId: chapterIndex,
          fontSize: _config.fontSize.value,
          lineHeight: _config.lineHeight.value,
          width: pageWidth.value,
          height: pageHeight.value,
          padding: 16,
        );
      } else {
        pages = result.pages;
        paginationFromCache = result.cacheHit;
      }

      chapterContent.value = AsyncState.data(content);
      totalPages.value = pages.length;

      this.chapterIndex.value = chapterIndex;
      currentCharOffset.value = initialCharOffset.clamp(0, content.length);
      pageIndex.value = resolvePageIndexForOffset(
        pages,
        currentCharOffset.value,
      );
      pendingJumpCharOffset.value = currentCharOffset.value;
      error.value = null;

      Logging.debug(
        'loadChapter: pages=${pages.length} cacheHit=$paginationFromCache '
        'resolvePage=$pageIndex off=$currentCharOffset',
      );

      // 回调：加载高亮等 VM 层数据
      if (onChapterLoaded != null) {
        await onChapterLoaded();
      }

      // 预加载前后章节（不阻塞 UI）
      _prefetchChapters(chapterIndex);
    } catch (e) {
      chapterContent.value = AsyncState.error(e);
      error.value = '章节加载失败：$e';
      Logging.error('ChapterManager.loadChapter error', exception: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载指定页（不保存进度 — 由调用方负责）
  void loadPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= totalPages.value) {
      return;
    }

    this.pageIndex.value = pageIndex;
    final pages = _repo.currentPages;
    if (pages != null && pageIndex < pages.length) {
      currentCharOffset.value = pages[pageIndex].startOffset;
    }
  }

  /// 预加载前后章节到缓存
  void _prefetchChapters(int centerIndex) {
    final chapterList = chapters.value.value ?? [];
    if (chapterList.isEmpty) return;

    final start = (centerIndex - _preloadCount).clamp(
      0,
      chapterList.length - 1,
    );
    final end = (centerIndex + _preloadCount).clamp(0, chapterList.length - 1);

    for (int i = start; i <= end; i++) {
      if (i == centerIndex) continue;
      _repo.preloadChapter(bookId.value, i);
    }
  }

  /// 将章节内容索引到 FTS5（不阻塞 UI，失败静默忽略）
  Future<void> _indexForSearch(int chapterIndex, String content) async {
    try {
      final chapterList = chapters.value.value ?? [];
      final title =
          chapterList
              .where((c) => c.chapterIndex == chapterIndex)
              .firstOrNull
              ?.title ??
          '';
      await search_api.indexChapter(
        bookId: bookId.value,
        chapterId: '${bookId.value}_$chapterIndex',
        chapterIndex: chapterIndex.toString(),
        chapterTitle: title,
        content: content,
      );
    } catch (e) {
      Logging.error('全文索引失败', exception: e);
    }
  }

  // ==================== 章节导航 ====================

  /// 上一章
  Future<void> previousChapter() async {
    if (chapterIndex.value > 0) {
      final newChapterIndex = chapterIndex.value - 1;
      await loadChapter(newChapterIndex);
    }
  }

  /// 下一章
  Future<void> nextChapter() async {
    final chapterList = chapters.value.value ?? [];
    if (chapterIndex.value < chapterList.length - 1) {
      final newChapterIndex = chapterIndex.value + 1;
      await loadChapter(newChapterIndex);
    }
  }

  /// 跳转到指定章节
  Future<void> jumpToChapter(int chapterIndex) async {
    await loadChapter(chapterIndex);
  }

  /// 跳转到指定位置
  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await loadChapter(chapterIndex, initialCharOffset: charOffset);
  }

  // ==================== 页面导航 ====================

  /// 上一页
  void previousPage() {
    if (pageIndex.value > 0) {
      loadPage(pageIndex.value - 1);
    }
  }

  /// 下一页
  void nextPage() {
    if (pageIndex.value < totalPages.value - 1) {
      loadPage(pageIndex.value + 1);
    }
  }

  /// 更新当前阅读位置
  void updateCurrentCharOffset(int charOffset) {
    final contentLength = chapterContent.value.value?.length ?? 0;
    currentCharOffset.value = charOffset.clamp(0, contentLength);
  }

  /// 消费待消费的跳转目标偏移
  void consumePendingJumpOffset() {
    pendingJumpCharOffset.value = null;
  }

  // ==================== 自动滚动 ====================

  void startAutoScroll() {
    stopAutoScroll();
    _autoScrollTimer = Timer.periodic(
      Duration(seconds: _config.autoScrollSpeed.value),
      (timer) {
        autoScrollTick.value++;
      },
    );
  }

  void stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  // ==================== 工具方法 ====================

  int resolvePageIndexForOffset(List<PageInfo> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (charOffset >= page.startOffset && charOffset < page.endOffset) {
        return i;
      }
    }
    return pages.length - 1;
  }

  // ==================== 重置 ====================

  /// 重置所有信号到默认值
  void reset() {
    _autoScrollTimer?.cancel();
    _searchIndexOperation?.cancel();
    bookId.value = '0';
    chapterIndex.value = 0;
    chapters.value = AsyncState.data([]);
    chapterContent.value = AsyncState.data('');
    totalPages.value = 0;
    pageIndex.value = 0;
    currentCharOffset.value = 0;
    pendingJumpCharOffset.value = null;
    isLoading.value = false;
    error.value = null;
    autoScrollTick.value = 0;
  }

  void dispose() {
    _autoScrollTimer?.cancel();
    _searchIndexOperation?.cancel();
  }
}
