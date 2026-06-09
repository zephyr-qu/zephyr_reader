import 'dart:async';

import 'package:async/async.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

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
  double pageWidth = 400;

  /// 页面高度（逻辑像素）
  double pageHeight = 600;

  /// 设备像素比，用于 dp → px 转换
  double devicePixelRatio = 1.0;

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
    return '';
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
      Logging.error('Failed to load reading progress', exception: e);
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

      unawaited(_postLoadTasks(chapterIndex, content));

      // █ 字符宽度校准（仅首次执行，字体/字号/DPR 变化后重置） █
      if (_calibration.value == null) {
        _calibration.value = await calibrateSafely(
          fontSize: _config.fontSize.value,
          devicePixelRatio: devicePixelRatio,
          fontFamily: _fontFamily,
        );
      }

      // █ 轻量级分页排版（仅页面描述符，文本按需加载） █
      final total = await _repo.paginateChapter(
        bookId: bookId.value,
        chapterIndex: chapterIndex,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: pageWidth,
        height: pageHeight,
        padding: _config.padding.value,
        devicePixelRatio: devicePixelRatio,
        calibration: _calibration.value,
        fontFamily: _fontFamily,
        letterSpacing: _config.letterSpacing.value,
        paragraphSpacing: _config.paragraphSpacing.value,
        punctuationSqueeze: _config.punctuationSqueeze.value,
      );

      final descriptors = _repo.descriptors;
      if (total == 0 || descriptors == null || descriptors.isEmpty) {
        // █ Rust 分页失败，回退到 Dart 估算分页 █
        Logging.warning(
          'loadChapter: Rust pagination fallback, using Dart approximate',
        );
        final pages = await _repo.calculatePages(
          bookId: bookId.value,
          chapterId: chapterIndex,
          fontSize: _config.fontSize.value,
          lineHeight: _config.lineHeight.value,
          width: pageWidth,
          height: pageHeight,
          padding: _config.padding.value,
        );

        chapterContent.value = AsyncState.data(content);
        totalPages.value = pages.length;
        this.chapterIndex.value = chapterIndex;
        currentCharOffset.value = initialCharOffset.clamp(0, content.length);
        pageIndex.value = resolvePageIndexFromPageInfo(
          pages,
          currentCharOffset.value,
        );
        pendingJumpCharOffset.value = currentCharOffset.value;
        error.value = null;

        Logging.debug(
          'loadChapter (fallback): pages=${pages.length} '
          'resolvePage=$pageIndex off=$currentCharOffset',
        );
      } else {
        chapterContent.value = AsyncState.data(content);
        totalPages.value = total;
        this.chapterIndex.value = chapterIndex;
        currentCharOffset.value = initialCharOffset.clamp(0, content.length);
        pageIndex.value = resolvePageIndexForOffset(
          descriptors,
          currentCharOffset.value,
        );
        pendingJumpCharOffset.value = currentCharOffset.value;
        error.value = null;

        Logging.debug(
          'loadChapter: pages=${descriptors.length} '
          'resolvePage=$pageIndex off=$currentCharOffset',
        );
      }

      // 回调：加载高亮等 VM 层数据
      if (onChapterLoaded != null) {
        await onChapterLoaded();
      }
    } catch (e) {
      chapterContent.value = AsyncState.error(e);
      error.value = AppErrorMapper.humanReadable(e);
      Logging.error('ChapterManager.loadChapter error', exception: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 章节内容加载完成后异步执行：搜索索引 + 预加载前后章节。
  Future<void> _postLoadTasks(int chapterIndex, String content) async {
    await _searchIndexOperation?.cancel();
    _searchIndexOperation = CancelableOperation.fromFuture(
      _indexForSearch(chapterIndex, content),
      onCancel: () => Logging.debug('_searchIndexOperation cancelled'),
    );
    unawaited(_prefetchChapters(chapterIndex));
  }

  /// 加载指定页（不保存进度 — 由调用方负责）
  void loadPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= totalPages.value) {
      return;
    }

    this.pageIndex.value = pageIndex;

    // 从新版 descriptors 获取偏移
    final descriptors = _repo.descriptors;
    if (descriptors != null && pageIndex < descriptors.length) {
      currentCharOffset.value = descriptors[pageIndex].startOffset;
    } else {
      // 回退到旧版 currentPages
      final pages = _repo.currentPages;
      if (pages != null && pageIndex < pages.length) {
        currentCharOffset.value = pages[pageIndex].startOffset;
      }
    }

    // 确保周围页面内容已缓存
    _repo.ensurePageWindow(pageIndex);
  }

  /// 预加载前后章节到缓存（限制并发数为 2，避免堆积）。
  Future<void> _prefetchChapters(int centerIndex) async {
    final chapterList = chapters.value.value ?? [];
    if (chapterList.isEmpty) return;

    final start = (centerIndex - _preloadCount).clamp(
      0,
      chapterList.length - 1,
    );
    final end = (centerIndex + _preloadCount).clamp(0, chapterList.length - 1);

    final indices = <int>[];
    for (int i = start; i <= end; i++) {
      if (i != centerIndex) indices.add(i);
    }
    // 批次限制并发数为 2，减轻 Rust 层压力
    const batchSize = 2;
    for (int b = 0; b < indices.length; b += batchSize) {
      final batch = indices.skip(b).take(batchSize);
      await Future.wait(
        batch.map(
          (i) => _repo.preloadChapter(bookId.value, i).catchError((_) {}),
        ),
      );
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
        chapterIndex: chapterIndex,
        chapterTitle: title,
        content: content,
      );
    } catch (e) {
      Logging.error('Failed to build full-text search index', exception: e);
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

  int resolvePageIndexFromPageInfo(List<PageInfo> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    int lo = 0, hi = pages.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final page = pages[mid];
      if (charOffset < page.startOffset) {
        hi = mid - 1;
      } else if (charOffset >= page.endOffset) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return charOffset < pages[0].startOffset ? 0 : pages.length - 1;
  }

  int resolvePageIndexForOffset(
    List<PageDescriptor> descriptors,
    int charOffset,
  ) {
    if (descriptors.isEmpty) return 0;
    int lo = 0, hi = descriptors.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final page = descriptors[mid];
      if (charOffset < page.startOffset) {
        hi = mid - 1;
      } else if (charOffset >= page.endOffset) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return charOffset < descriptors[0].startOffset ? 0 : descriptors.length - 1;
  }

  // ==================== 重置 ====================

  /// 重置所有信号到默认值，取消定时器和搜索索引操作。
  void reset() {
    stopAutoScroll();
    _searchIndexOperation?.cancel();
    _searchIndexOperation = null;
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
}
