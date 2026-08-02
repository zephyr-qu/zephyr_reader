import 'dart:async';
import 'dart:convert';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/api/engine_position.dart' as engine_position_api;
import 'package:zephyr_reader/src/rust/api/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';
import 'package:zephyr_reader/src/rust/domain/engine_positions/models.dart';
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

/// 会话记录回调（默认走 FRB `session_api.createSession`，测试可注入）。
typedef SessionRecorder = Future<void> Function({
  required String bookId,
  required int chapterIndex,
  required int startCharOffset,
  required int endCharOffset,
  required int startedAt,
});

Future<void> _defaultPersistProgress(ReadingProgress progress) =>
    progress_api.upsertProgress(progress: progress);

Future<void> _defaultSaveEnginePosition({required EnginePositionHint hint}) =>
    engine_position_api.saveEnginePosition(hint: hint);

Future<EnginePositionHint?> _defaultLoadEnginePosition({required String bookId}) =>
    engine_position_api.getEnginePosition(bookId: bookId);

///
/// Wraps [Flureadium] directly, exposes reading state via signals.
class ReadiumViewModel {
  final Flureadium reader;
  final ReaderConfig config;
  final String bookId;
  final int initialChapterIndex;
  final Future<void> Function(ReadingProgress progress) persistProgress;
  final SessionRecorder recordSession;
  final Future<void> Function({required EnginePositionHint hint}) saveEnginePosition;
  final Future<EnginePositionHint?> Function({required String bookId})
      loadEnginePosition;
  Timer? _saveTimer;
  Future<void>? _closeFuture;
  bool _viewportReady = false;
  bool _closing = false;
  bool _navigationInProgress = false;
  int _openGeneration = 0;

  // ==================== Progress / Session persistence ====================
  int _totalChars = 0;
  int _accumulatedReadingSeconds = 0;
  DateTime _lastReadingTick = DateTime.now();
  DateTime? _sessionStartedAt;
  int? _sessionChapterIndex;
  int _sessionStartOffset = 0;
  int _sessionLastOffset = 0;
  String _publicationFingerprint = '';
  bool _lastIsCompleted = false;

  // ==================== Signals ====================

  final progress = signal<double>(0.0);
  final status = signal<String>('closed');
  final title = signal<String>('');
  final error = signal<String?>(null);
  final tocLinks = signal<List<Link>>([]);
  final currentChapterHref = signal<String>('');
  final isTtsPlaying = signal<bool>(false);
  final readingMode = signal<ReadingMode>(ReadingMode.pagination);
  final bookmarks = signal<List<Bookmark>>([]);
  final isBookmarked = signal<bool>(false);
  Locator? _currentLocator;
  Locator? _initialLocator;
  Publication? _publication;
  bool _ttsEnabled = false;
  // ==================== Subscriptions ====================

  StreamSubscription<ReadiumReaderStatus>? _statusSub;
  StreamSubscription<ReadiumError>? _errorSub;

  ReadiumViewModel({
    required this.config,
    required this.bookId,
    this.initialChapterIndex = 0,
    Flureadium? reader,
    Future<void> Function(ReadingProgress progress)? persistProgress,
    SessionRecorder? sessionRecorder,
    Future<void> Function({required EnginePositionHint hint})? enginePositionSaver,
    Future<EnginePositionHint?> Function({required String bookId})?
        enginePositionLoader,
  })  : reader = reader ?? Flureadium(),
        persistProgress = persistProgress ?? _defaultPersistProgress,
        recordSession = sessionRecorder ?? session_api.createSession,
        saveEnginePosition =
            enginePositionSaver ?? _defaultSaveEnginePosition,
        loadEnginePosition =
            enginePositionLoader ?? _defaultLoadEnginePosition;

  /// Open an EPUB file.
  Future<Publication> open(String path) async {
    // Yield to the event loop to avoid triggering signal listeners
    // during the build phase (useMemoized calls this synchronously).
    await Future(() {});

    final generation = ++_openGeneration;
    try {
      final uriPath = path.startsWith('file://')
          ? path
          : Uri.file(path).toString();
      status.value = 'opening...';
      error.value = null;
      _viewportReady = false;
      _closing = false;
      _navigationInProgress = false;
      readingMode.value = config.readingMode.value;
      _sessionStartedAt = null;
      _sessionChapterIndex = null;
      _sessionStartOffset = 0;
      _sessionLastOffset = 0;
      _accumulatedReadingSeconds = 0;
      _lastReadingTick = DateTime.now();

      final pub = await reader.openPublication(uriPath);
      if (generation != _openGeneration) {
        await reader.closePublication();
        throw StateError('Open cancelled');
      }
      _publication = pub;
      _publicationFingerprint = pub.metadata.identifier ?? '';
      final links = flattenToc(pub.tableOfContents);
      await _loadBookMetadata();
      unawaited(_touchBook());
      _initialLocator = await _loadSavedPosition();
      if (generation != _openGeneration) {
        await reader.closePublication();
        _publication = null;
        throw StateError('Open cancelled');
      }
      if (_initialLocator == null && links.isNotEmpty) {
        final chapterIndex = initialChapterIndex.clamp(0, links.length - 1);
        _initialLocator = pub.locatorFromLink(links[chapterIndex]);
      }
      _currentLocator = _initialLocator;
      batch(() {
        title.value = pub.metadata.title;
        tocLinks.value = links;
        currentChapterHref.value = _initialLocator?.href ?? '';
        progress.value = _initialLocator?.locations?.totalProgression ?? 0.0;
      });

      unawaited(_loadBookmarks());
      return pub;
    } catch (e) {
      if (generation == _openGeneration) {
        error.value = e.toString();
        status.value = 'error';
      }
      rethrow;
    }
  }

  /// Position restored when constructing the native viewport.
  Locator? get initialLocator => _initialLocator;

  /// Completes the open sequence after the native platform view is ready.
  Future<void> onViewportReady() async {
    if (_publication == null || _viewportReady || _closing) return;

    await _statusSub?.cancel();
    _statusSub = reader.onReaderStatusChanged.listen((s) {
      if (_viewportReady && !_closing) status.value = s.name;
    });

    await _errorSub?.cancel();
    _errorSub = reader.onErrorEvent.listen((e) {
      if (_closing) return;
      error.value = e.message;
      status.value = 'error';
    });

    try {
      await reader.setNavigationConfig(
        ReaderNavigationConfig(
          enableEdgeTapNavigation: true,
          enableSwipeNavigation: false,
        ),
      );
      await _applyPreferences();
      if (_closing || _publication == null) return;
      _viewportReady = true;
      status.value = 'ready';
    } catch (e) {
      error.value = e.toString();
      status.value = 'error';
    }
  }

  /// Receives the authoritative locator from the rendered viewport.
  void onLocatorChanged(Locator locator) {
    if (_closing) return;
    _currentLocator = locator;
    progress.value = locator.locations?.totalProgression ?? 0.0;
    if (locator.href.isNotEmpty) {
      currentChapterHref.value = locator.href;
    }
    _trackSession(locator);
    _scheduleSave();
    _updateBookmarkState();
  }

  /// Navigate to a TOC link.
  Future<bool> goToLink(Link link) async {
    if (_publication == null || !_viewportReady) return false;
    try {
      return await reader.goByLink(link, _publication!);
    } catch (e) {
      error.value = e.toString();
      return false;
    }
  }

  /// Close the current publication.
  Future<void> close() => _closeFuture ??= _close();

  /// 应用进入后台/被中断时调用：结束当前会话并保存进度，但不关闭出版刊物。
  ///
  /// 之后继续阅读会开启新的会话（后台 = 阅读暂停 = 会话边界）。
  Future<void> flush() async {
    if (_closing || !_viewportReady) return;
    _saveTimer?.cancel();
    await _finalizeSession();
    await _savePositionNow();
  }
  Future<void> _close() async {
    _closing = true;
    _openGeneration += 1;
    status.value = 'closing';
    _viewportReady = false;
    _saveTimer?.cancel();
    try {
      await _finalizeSession();
      await _savePositionNow();
      await _statusSub?.cancel();
      _statusSub = null;
      await _errorSub?.cancel();
      _errorSub = null;
      if (_ttsEnabled) await stopTts();
      if (_publication != null) await reader.closePublication();
    } catch (e) {
      error.value = e.toString();
    } finally {
      _publication = null;
      _initialLocator = null;
      status.value = 'closed';
    }
  }

  // ==================== Navigation ====================

  Future<void> goLeft() => _navigatePage(reader.goLeft);

  Future<void> goRight() => _navigatePage(reader.goRight);

  /// Skip to the previous reading-order resource (previous chapter).
  Future<void> skipToPrevious() async {
    if (!_viewportReady || _closing || _navigationInProgress) return;
    _navigationInProgress = true;
    try {
      await reader.skipToPrevious();
    } finally {
      _navigationInProgress = false;
    }
  }

  /// Continue into the next reading-order resource after an upward scroll
  /// attempt at the end of the current resource.
  Future<void> advanceFromScrollBoundary() async {
    if (readingMode.value != ReadingMode.scroll ||
        !_viewportReady ||
        _closing ||
        _navigationInProgress) {
      return;
    }

    final resourceProgression = _currentLocator?.locations?.progression;
    if (resourceProgression == null || resourceProgression < 0.99) return;

    _navigationInProgress = true;
    try {
      await reader.skipToNext();
    } finally {
      _navigationInProgress = false;
    }
  }

  Future<void> _navigatePage(Future<void> Function() pageNavigation) async {
    if (!_viewportReady || _closing || _navigationInProgress) return;

    _navigationInProgress = true;
    try {
      await pageNavigation();
    } finally {
      _navigationInProgress = false;
    }
  }
  // ==================== Preferences ====================

  Future<void> setReadingMode(ReadingMode mode) async {
    if (readingMode.value == mode) return;
    readingMode.value = mode;
    config.readingMode.value = mode;
    await applyPreferences();
  }

  Future<void> applyPreferences() async {
    if (!_viewportReady) return;
    try {
      await _applyPreferences();
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> _applyPreferences() async {
    final theme = config.theme.value;
    // Background from preset in light theme, otherwise theme-derived.
    final Color bg;
    if (theme == ReaderTheme.light) {
      final idx = config.readerBgColorIndex.value.clamp(0, ReaderBgColors.presets.length - 1);
      bg = ReaderBgColors.presets[idx];
    } else {
      switch (theme) {
        case ReaderTheme.dark:
          bg = const Color(0xFF1A1A1A);
        case ReaderTheme.sepia:
          bg = const Color(0xFFF5E6D3);
        case ReaderTheme.light:
          bg = const Color(0xFFFFFFFF);
      }
    }
    final Color text;
    switch (theme) {
      case ReaderTheme.dark:
        text = const Color(0xFFCCCCCC);
      case ReaderTheme.sepia:
        text = const Color(0xFF4A3B2F);
      case ReaderTheme.light:
        text = const Color(0xFF1A1A1A);
    }
    final fontFamily = config.fontFamily.value;
    final prefs = EPUBPreferences(
      fontFamily: fontFamily,
      // Migrate old built-in dp values (< 50) to Readium percentage scale (80–200).
      fontSize: (() {
        final v = config.fontSize.value.round();
        return v < 50 ? 100 : v;
      })(),
      fontWeight: config.fontWeight.value,
      verticalScroll: readingMode.value == ReadingMode.scroll,
      backgroundColor: bg,
      textColor: text,
      pageMargins:
          config.padding.value.clamp(
            ReaderTypographyDefaults.minPadding,
            ReaderTypographyDefaults.maxPadding,
          ) /
          ReaderTypographyDefaults.padding,
    );
    await reader.setEPUBPreferences(prefs);
  }

  // ==================== TTS ====================

  Future<void> toggleTts() async {
    if (!_viewportReady) return;
    try {
      if (!_ttsEnabled) {
        await reader.ttsEnable(null);
        _ttsEnabled = true;
        isTtsPlaying.value = true;
      } else if (isTtsPlaying.value) {
        await reader.pause();
        isTtsPlaying.value = false;
      } else {
        await reader.play(null);
        isTtsPlaying.value = true;
      }
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> stopTts() async {
    if (_ttsEnabled) await reader.stop();
    _ttsEnabled = false;
    isTtsPlaying.value = false;
  }

  /// Skip to next TTS utterance (sentence).
  Future<void> ttsNext() async {
    if (!_viewportReady || !_ttsEnabled) return;
    try {
      await reader.next();
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// Skip to previous TTS utterance (sentence).
  Future<void> ttsPrevious() async {
    if (!_viewportReady || !_ttsEnabled) return;
    try {
      await reader.previous();
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// Resume TTS playback after pause.
  Future<void> ttsResume() async {
    if (!_viewportReady || !_ttsEnabled) return;
    try {
      await reader.resume();
      isTtsPlaying.value = true;
    } catch (e) {
      error.value = e.toString();
    }
  }

  // ==================== Position Persistence ====================

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _savePositionNow);
  }

  Future<void> _savePositionNow() async {
    final locator = _currentLocator;
    if (locator == null) return;
    _accumulateReadingSeconds();
    await _saveReadingProgress();
  }

  /// 进度写入 Rust `reading_progress` 表（尽力而为，失败静默）。
  Future<void> _saveReadingProgress() async {
    final locator = _currentLocator;
    if (locator == null) return;
    final totalProgression = locator.locations?.totalProgression ?? 0.0;
    final isCompleted = totalProgression >= 0.999;
    try {
      final progress = ReadingProgress(
        bookId: bookId,
        chapterIndex: _chapterIndexForHref(locator.href),
        chunkIndex: 0,
        chapterId: locator.href,
        charOffset: _charOffsetFor(locator),
        progress: totalProgression,
        readingTimeSeconds: _accumulatedReadingSeconds,
        lastReadAt: DateTime.now().toUtc(),
        isCompleted: isCompleted,
      );
      await persistProgress(progress);
      // 读完自动标记书架状态（一次性转换，避免重复写）。
      if (isCompleted && !_lastIsCompleted) {
        _lastIsCompleted = true;
        try {
          await book_api.updateBookStatus(
            bookId: bookId,
            status: BookStatus.completed,
          );
        } catch (_) {
          // 静默失败：状态标记是尽力而为，不中断阅读流程。
        }
      }
    } catch (_) {
      // 静默失败：逻辑进度是尽力而为，不中断阅读流程。
    }
    // ADR-019：完整 Locator 作为引擎私有恢复提示，存 reading_engine_positions。
    // 与逻辑进度相互独立 —— 恢复提示失败不应阻塞进度，反之亦然。
    try {
      await saveEnginePosition(
        hint: EnginePositionHint(
          bookId: bookId,
          engineKind: 'readium',
          publicationFingerprint: _publicationFingerprint,
          opaquePosition: jsonEncode(locator.toJson()),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      // 静默失败：恢复提示是尽力而为，不中断阅读流程。
    }
  }

  void _accumulateReadingSeconds() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastReadingTick).inSeconds;
    if (elapsed > 0) {
      _accumulatedReadingSeconds += elapsed;
      _lastReadingTick = now;
    }
  }
  Future<Locator?> _loadSavedPosition() async {
    try {
      final hint = await loadEnginePosition(bookId: bookId);
      if (hint == null) return null;
      final opaque = hint.opaquePosition;
      if (opaque.isEmpty) return null;
      // ADR-019：Locator 与当前 EPUB 指纹不匹配时必须丢弃。
      if (hint.publicationFingerprint.isNotEmpty &&
          hint.publicationFingerprint != _publicationFingerprint) {
        return null;
      }
      final map = jsonDecode(opaque) as Map<String, dynamic>;
      return Locator.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ==================== Bookmarks ====================

  Future<void> addBookmark() async {
    final locator = _currentLocator;
    if (locator == null || _closing) return;
    final title = _tocTitleForHref(locator.href);
    try {
      final bookmark = await bookmark_api.createBookmark(
        bookId: bookId,
        chapterIndex: _chapterIndexForHref(locator.href),
        charOffset: _charOffsetFor(locator),
        title: title,
        locatorJson: jsonEncode(locator.toJson()),
      );
      bookmarks.value = [...bookmarks.value, bookmark];
      _updateBookmarkState();
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> removeBookmark() async {
    final locator = _currentLocator;
    if (locator == null || _closing) return;
    final key = jsonEncode(locator.toJson());
    final match = bookmarks.value.where((b) => b.locatorJson == key);
    if (match.isEmpty) return;
    try {
      await bookmark_api.deleteBookmark(bookmarkId: match.first.id);
      bookmarks.value =
          bookmarks.value.where((b) => b.locatorJson != key).toList();
      _updateBookmarkState();
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> goToBookmark(Bookmark entry) async {
    final locatorJson = entry.locatorJson;
    if (locatorJson == null) return;
    try {
      final map = jsonDecode(locatorJson) as Map<String, dynamic>;
      final locator = Locator.fromJson(map);
      if (locator != null) await reader.goToLocator(locator);
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> deleteBookmarkByEntry(Bookmark entry) async {
    try {
      await bookmark_api.deleteBookmark(bookmarkId: entry.id);
      bookmarks.value =
          bookmarks.value.where((b) => b.id != entry.id).toList();
      _updateBookmarkState();
    } catch (e) {
      error.value = e.toString();
    }
  }

  bool get isCurrentLocatorBookmarked {
    final locator = _currentLocator;
    if (locator == null) return false;
    final key = jsonEncode(locator.toJson());
    return bookmarks.value.any((b) => b.locatorJson == key);
  }

  void _updateBookmarkState() {
    isBookmarked.value = isCurrentLocatorBookmarked;
  }

  Future<void> _loadBookmarks() async {
    try {
      final list = await bookmark_api.listBookmarksByBook(bookId: bookId);
      bookmarks.value = list;
      _updateBookmarkState();
    } catch (_) {}
  }

  String _tocTitleForHref(String href) {
    for (final link in tocLinks.value) {
      if (link.href == href) return link.title ?? '';
    }
    return '';
  }

  // ==================== Reading session tracking ====================

  /// 按章节分段记录阅读会话：进入章节时开启，章节切换/关闭时结束。
  void _trackSession(Locator locator) {
    if (!_viewportReady || _closing) return;
    final chapterIndex = _chapterIndexForHref(locator.href);
    final offset = _charOffsetFor(locator);
    if (_sessionStartedAt == null || _sessionChapterIndex == null) {
      _sessionStartedAt = DateTime.now();
      _sessionChapterIndex = chapterIndex;
      _sessionStartOffset = offset;
      _sessionLastOffset = offset;
    } else if (chapterIndex != _sessionChapterIndex) {
      unawaited(_finalizeSession());
      _sessionStartedAt = DateTime.now();
      _sessionChapterIndex = chapterIndex;
      _sessionStartOffset = offset;
      _sessionLastOffset = offset;
    } else if (offset > _sessionLastOffset) {
      _sessionLastOffset = offset;
    }
  }

  /// 结束当前章节会话并写入 Rust `reading_sessions`（尽力而为，失败静默）。
  Future<void> _finalizeSession() async {
    final startedAt = _sessionStartedAt;
    final chapterIndex = _sessionChapterIndex;
    if (startedAt == null || chapterIndex == null) return;
    _sessionStartedAt = null;
    _sessionChapterIndex = null;
    final startOffset = _sessionStartOffset;
    final endOffset = _sessionLastOffset;
    try {
      await recordSession(
        bookId: bookId,
        chapterIndex: chapterIndex,
        startCharOffset: startOffset,
        endCharOffset: endOffset,
        startedAt: startedAt.millisecondsSinceEpoch ~/ 1000,
      );
    } catch (_) {
      // 静默失败：会话记录是尽力而为，不中断阅读流程。
    }
  }

  /// href → 扁平目录索引（Readium 语义：flattenToc 下标）。
  int _chapterIndexForHref(String href) {
    if (href.isEmpty) return _sessionChapterIndex ?? 0;
    final path = _hrefPath(href);
    for (var i = 0; i < tocLinks.value.length; i++) {
      final linkHref = tocLinks.value[i].href;
      if (_hrefPath(linkHref) == path) return i;
    }
    // 资源不在目录中（如附录）：沿用当前会话章节，避免误拆会话。
    return _sessionChapterIndex ?? 0;
  }

  static String _hrefPath(String href) {
    final uri = Uri.tryParse(href);
    return uri?.path ?? href;
  }

  /// Locator → 逻辑字符偏移。
  ///
  /// Readium 不提供全局字符偏移，用 totalProgression × 全书字符数估算；
  /// 全书字符数未知（加载失败/测试环境）时退回出版页码位置。
  int _charOffsetFor(Locator locator) {
    final totalProgression = locator.locations?.totalProgression ?? 0.0;
    if (_totalChars > 0 && totalProgression > 0) {
      return (totalProgression * _totalChars)
          .round()
          .clamp(0, _totalChars)
          .toInt();
    }
    return locator.locations?.position ?? 0;
  }

  /// 预载书籍元数据（总字符数 + 既有进度累计时长）。
  Future<void> _loadBookMetadata() async {
    try {
      final detail = await book_api.getBookDetail(bookId: bookId);
      _totalChars = detail.book.totalCharacters;
      _accumulatedReadingSeconds = detail.progress?.readingTimeSeconds ?? 0;
      _lastIsCompleted = detail.progress?.isCompleted ?? false;
    } catch (_) {
      // 元数据加载失败不影响阅读；进度估算退化为页码位置。
    }
  }

  /// 记录打开时间（最近阅读/书架排序依据，尽力而为）。
  Future<void> _touchBook() async {
    try {
      await book_api.touchBook(bookId: bookId);
    } catch (_) {
      // 静默失败：最近阅读标记不中断阅读流程。
    }
  }
}
