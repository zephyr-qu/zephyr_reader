import 'dart:async';
import 'dart:convert';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/epub/readium_bookmark_controller.dart';
import 'package:zephyr_reader/features/reader/epub/readium_session_tracker.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/engine_position.dart'
    as engine_position_api;
import 'package:zephyr_reader/src/rust/api/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';
import 'package:zephyr_reader/src/rust/domain/engine_positions/models.dart';
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

Future<void> _defaultPersistProgress(ReadingProgress progress) =>
    progress_api.upsertProgress(progress: progress);

Future<void> _defaultSaveEnginePosition({required EnginePositionHint hint}) =>
    engine_position_api.saveEnginePosition(hint: hint);

Future<EnginePositionHint?> _defaultLoadEnginePosition({
  required String bookId,
}) => engine_position_api.getEnginePosition(bookId: bookId);

///
/// Wraps [FlutterReadium] directly, exposes reading state via signals.
class ReadiumViewModel {
  final FlutterReadium reader;
  final ReaderConfig config;
  final TtsSettingsViewModel? ttsSettings;
  final String bookId;
  final int initialChapterIndex;
  final Future<void> Function(ReadingProgress progress) persistProgress;
  final SessionRecorder recordSession;
  final Future<void> Function({required EnginePositionHint hint})
  saveEnginePosition;
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
  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumError>? _errorSub;
  late final ReadiumBookmarkController _bookmarkController;
  late final ReadiumSessionTracker _sessionTracker;

  ReadiumViewModel({
    required this.config,
    required this.bookId,
    this.ttsSettings,
    this.initialChapterIndex = 0,
    FlutterReadium? reader,
    Future<void> Function(ReadingProgress progress)? persistProgress,
    SessionRecorder? sessionRecorder,
    Future<void> Function({required EnginePositionHint hint})?
    enginePositionSaver,
    Future<EnginePositionHint?> Function({required String bookId})?
    enginePositionLoader,
  }) : reader = reader ?? FlutterReadium(),
       persistProgress = persistProgress ?? _defaultPersistProgress,
       recordSession = sessionRecorder ?? session_api.createSession,
       saveEnginePosition = enginePositionSaver ?? _defaultSaveEnginePosition,
       loadEnginePosition = enginePositionLoader ?? _defaultLoadEnginePosition {
    _bookmarkController = ReadiumBookmarkController(
      bookId: bookId,
      onError: (e) => error.value = e.toString(),
      bookmarks: bookmarks,
      isBookmarked: isBookmarked,
    );
    _sessionTracker = ReadiumSessionTracker(
      bookId: bookId,
      recordSession: recordSession,
      chapterIndexForHref: _chapterIndexForHref,
      charOffsetFor: _charOffsetFor,
      isReady: () => _viewportReady,
      isClosing: () => _closing,
    );
  }

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
      _sessionTracker.reset();
      _accumulatedReadingSeconds = 0;
      _lastReadingTick = DateTime.now();

      // ADR-021 修订：预置默认偏好，让原生 WebView 首次创建即处于正确布局
      // （scroll 或分页），消除"先分页后热切 scroll"的时序竞争。
      reader.setDefaultPreferences(
        EPUBPreferences(scroll: readingMode.value == ReadingMode.scroll),
      );

      final pub = await reader.openPublication(uriPath);
      if (generation != _openGeneration) {
        await reader.closePublication();
        throw StateError('Open cancelled');
      }
      _publication = pub;
      _publicationFingerprint = pub.metadata.identifier ?? '';
      final links = pub.tocFlattened;
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

  /// Progress within the currently rendered EPUB resource.
  double? get currentResourceProgression =>
      _currentLocator?.locations?.progression;

  /// Subscribes to the native reader lifecycle after the platform widget is
  /// mounted. The platform emits the first ready status once its channel is
  /// usable, so preferences are applied only from that status callback.
  Future<void> onViewportReady() async {
    if (_publication == null || _viewportReady || _closing) return;

    await _statusSub?.cancel();
    _statusSub = reader.onReaderStatusChanged.listen((s) {
      if (_closing) return;
      status.value = s.name;
      if (s.isReady) unawaited(_markViewportReady());
    });

    await _locatorSub?.cancel();
    _locatorSub = reader.onTextLocatorChanged.listen(onLocatorChanged);

    await _errorSub?.cancel();
    _errorSub = reader.onErrorEvent.listen((e) {
      if (_closing) return;
      error.value = e.message;
      status.value = 'error';
    });
  }

  Future<void> _markViewportReady() async {
    if (_viewportReady || _closing || _publication == null) return;
    try {
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
    _sessionTracker.track(locator);
    _scheduleSave();
    _bookmarkController.updateForLocator(locator);
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
    await _sessionTracker.finalize();
    await _savePositionNow();
  }

  Future<void> _close() async {
    _closing = true;
    _openGeneration += 1;
    status.value = 'closing';
    _viewportReady = false;
    _saveTimer?.cancel();
    try {
      await _sessionTracker.finalize();
      await _savePositionNow();
      await _statusSub?.cancel();
      _statusSub = null;
      await _locatorSub?.cancel();
      _locatorSub = null;
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

  Future<void> goLeft() => _runNavigation(reader.goBackward);

  Future<void> goRight() => _runNavigation(reader.goForward);

  /// Skip to the previous reading-order resource (previous chapter).
  Future<void> skipToPrevious() async {
    if (!_viewportReady || _closing || _navigationInProgress) return;
    final publication = _publication;
    final locator = _currentLocator;
    if (publication == null || locator == null) return;

    final currentPath = _hrefPath(locator.href);
    final currentIndex = publication.readingOrder.indexWhere(
      (link) => _hrefPath(link.href) == currentPath,
    );
    if (currentIndex <= 0) return;

    final target = publication.locatorFromLink(
      publication.readingOrder[currentIndex - 1],
    );
    if (target == null) return;

    await _runNavigation(() => reader.goToLocator(target));
  }

  static String _hrefPath(String href) {
    final path = Uri.tryParse(href)?.path ?? href;
    return path.startsWith('/') ? path.substring(1) : path;
  }

  Future<void> _runNavigation(Future<void> Function() navigation) async {
    if (!_viewportReady || _closing || _navigationInProgress) return;

    _navigationInProgress = true;
    try {
      await navigation();
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
      final idx = config.readerBgColorIndex.value.clamp(
        0,
        ReaderBgColors.presets.length - 1,
      );
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
      // Migrate old built-in dp values (< 50) to Readium's ratio scale.
      fontSize: (() {
        final v = config.fontSize.value.round();
        return v < 50 ? 1.0 : v / 100.0;
      })(),
      fontWeight: config.fontWeight.value,
      lineHeight: config.lineHeight.value,
      letterSpacing: config.letterSpacing.value,
      paragraphSpacing: config.paragraphSpacing.value,
      paragraphIndent: config.paragraphIndent.value,
      textAlign: switch (config.textAlign.value) {
        ReaderTextAlign.auto => null,
        ReaderTextAlign.left => TextAlign.left,
        ReaderTextAlign.center => TextAlign.center,
        ReaderTextAlign.right => TextAlign.right,
        ReaderTextAlign.justify => TextAlign.justify,
      },
      scroll: readingMode.value == ReadingMode.scroll,
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
        await reader.ttsEnable(ttsSettings?.toReadiumPreferences());
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

  /// Applies the currently persisted TTS preferences without restarting TTS.
  Future<void> applyTtsPreferences() async {
    if (!_viewportReady || !_ttsEnabled || ttsSettings == null) return;
    try {
      await reader.ttsSetPreferences(ttsSettings!.toReadiumPreferences());
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
    await _bookmarkController.add(
      locator: locator,
      chapterIndex: _chapterIndexForHref(locator.href),
      charOffset: _charOffsetFor(locator),
      title: _tocTitleForHref(locator.href),
    );
  }

  Future<void> removeBookmark() async {
    final locator = _currentLocator;
    if (locator == null || _closing) return;
    await _bookmarkController.removeCurrent(locator);
  }

  Future<void> goToBookmark(Bookmark entry) async {
    await _bookmarkController.goTo(entry, navigate: reader.goToLocator);
  }

  Future<void> deleteBookmarkByEntry(Bookmark entry) async {
    await _bookmarkController.delete(entry);
  }

  Future<void> _loadBookmarks() async {
    await _bookmarkController.load();
  }

  String _tocTitleForHref(String href) {
    for (final link in tocLinks.value) {
      if (link.href == href) return link.title ?? '';
    }
    return '';
  }

  /// href → 扁平目录索引（Readium 语义：flattenToc 下标）。
  int _chapterIndexForHref(String href) {
    if (href.isEmpty) return _sessionTracker.currentChapterIndex ?? 0;
    final path = _hrefPath(href);
    for (var i = 0; i < tocLinks.value.length; i++) {
      final linkHref = tocLinks.value[i].href;
      if (_hrefPath(linkHref) == path) return i;
    }
    // 资源不在目录中（如附录）：沿用当前会话章节，避免误拆会话。
    return _sessionTracker.currentChapterIndex ?? 0;
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
