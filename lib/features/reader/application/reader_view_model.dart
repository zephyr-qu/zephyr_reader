import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/domain/models/chapter.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';

import '../../../core/reader/reader_config.dart';
import '../domain/repositories/reader_repository.dart';

/// 阅读器视图模型
@injectable
class ReaderViewModel {

  ReaderViewModel(this._repo, this.config) {
    // 监听自动滚动设置变化
    effect(() {
      if (config.autoScroll.value && isReading.value) {
        _startAutoScroll();
      } else {
        _stopAutoScroll();
      }
    });
  }
  final ReaderRepository _repo;
  final ReaderConfig config;

  /// 当前小说 ID
  final bookId = signal<int>(0);

  /// 当前章节 ID
  final chapterId = signal<int>(0);

  /// 当前章节索引
  final chapterIndex = signal<int>(1);

  /// 章节内容
  final chapterContent = asyncSignal<String>(AsyncState.data(''));

  /// 章节列表
  final chapters = asyncSignal<List<Chapter>>(AsyncState.data([]));

  /// 阅读位置（字符偏移量）
  final scrollPosition = signal<double>(0);

  /// 总字符数
  final totalCharacters = signal<int>(0);

  /// 阅读进度（0-1）
  late final readingProgress = computed(() {
    if (totalCharacters.value == 0) return 0.0;
    return (scrollPosition.value / totalCharacters.value).clamp(0.0, 1.0);
  });

  /// 是否显示目录
  final showCatalog = signal<bool>(false);

  /// 是否显示设置面板
  final showSettings = signal<bool>(false);

  /// 书签列表
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  /// 阅读时长（秒）
  final readingDuration = signal<int>(0);

  /// 是否正在阅读
  final isReading = signal<bool>(false);

  Timer? _readingTimer;
  Timer? _autoScrollTimer;

  /// 加载书籍
  Future<void> loadBook(int bookId) async {
    bookId = bookId;
    await loadChapters();
    await loadBookmarks();
  }

  /// 加载章节列表
  Future<void> loadChapters() async {
    chapters.value = AsyncState.loading();
    try {
      final data = await _repo.getChapters(bookId.value);
      chapters.value = AsyncState.data(data);
    } catch (e) {
      chapters.value = AsyncState.error(e);
    }
  }

  /// 加载章节
  Future<void> loadChapter(int index) async {
    chapterIndex.value = index;

    chapterContent.value = AsyncState.loading();
    try {
      final chapter = await _repo.getChapter(bookId.value, index);
      if (chapter == null) {
        chapterContent.value = AsyncState.error('章节不存在');
        return;
      }

      chapterId.value = chapter.id;
      final content = await _repo.getChapterContent(chapter.contentFile);
      chapterContent.value = AsyncState.data(content ?? '内容加载失败');
      totalCharacters.value = content?.length ?? 0;

      // 保存阅读历史
      await _repo.saveReadingHistory(bookId.value, chapter.id, 0, 0);
    } catch (e) {
      chapterContent.value = AsyncState.error(e);
    }
  }

  /// 上一章
  Future<void> previousChapter() async {
    final current = chapterIndex.value;
    if (current > 1) {
      await loadChapter(current - 1);
    }
  }

  /// 下一章
  Future<void> nextChapter() async {
    final current = chapterIndex.value;
    final chapterList = chapters.value.value ?? [];
    if (current < chapterList.length) {
      await loadChapter(current + 1);
    }
  }

  /// 跳转到指定章节
  Future<void> jumpToChapter(int index) async {
    await loadChapter(index);
    showCatalog.value = false;
  }

  /// 更新阅读位置
  void updateScrollPosition(double position) {
    scrollPosition.value = position;
  }

  /// 开始阅读计时
  void startReading() {
    if (isReading.value) return;
    isReading.value = true;
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readingDuration.value++;
    });
  }

  /// 停止阅读计时
  void stopReading() async {
    if (!isReading.value) return;
    isReading.value = false;
    _readingTimer?.cancel();

    // 保存阅读时长
    await _repo.saveReadingHistory(
      bookId.value,
      chapterId.value,
      scrollPosition.value.toInt(),
      readingDuration.value,
    );

    readingDuration.value = 0;
  }

  /// 自动滚动
  void _startAutoScroll() {
    _stopAutoScroll();
    _autoScrollTimer = Timer.periodic(
      Duration(seconds: config.autoScrollSpeed.value),
      (timer) {
        // 触发滚动事件
        // 这里需要与 UI 层配合实现
      },
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// 切换目录显示
  void toggleCatalog() {
    showCatalog.value = !showCatalog.value;
    showSettings.value = false;
  }

  /// 切换设置面板显示
  void toggleSettings() {
    showSettings.value = !showSettings.value;
    showCatalog.value = false;
  }

  /// 加载书签
  Future<void> loadBookmarks() async {
    bookmarks.value = AsyncState.loading();
    try {
      final data = await _repo.getBookmarks(bookId.value);
      bookmarks.value = AsyncState.data(data);
    } catch (e) {
      bookmarks.value = AsyncState.error(e);
    }
  }

  /// 添加书签
  Future<bool> addBookmark(String? note) async {
    try {
      await _repo.addBookmark(
        bookId.value,
        chapterId.value,
        scrollPosition.value.toInt(),
        note,
      );
      await loadBookmarks();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除书签
  Future<bool> deleteBookmark(int bookmarkId) async {
    try {
      final success = await _repo.deleteBookmark(bookmarkId);
      if (success) {
        await loadBookmarks();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 跳转到书签位置
  Future<void> jumpToBookmark(Bookmark bookmark) async {
    // 先找到书签对应的章节索引
    final chapterList = chapters.value.value ?? [];
    final chapterIndex = chapterList.indexWhere(
      (chapter) => chapter.id == bookmark.chapterId,
    );

    if (chapterIndex != -1) {
      // 加载对应章节
      await loadChapter(chapterIndex + 1); // 章节索引从1开始
      // 设置滚动位置，使用 pageIndex
      scrollPosition.value = bookmark.position.toDouble();
    }
  }

  /// 获取阅读进度百分比
  String get progressText {
    final progress = readingProgress.value;
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  void dispose() {
    _readingTimer?.cancel();
    _autoScrollTimer?.cancel();
  }
}
