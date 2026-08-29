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
  final String? sourceFingerprint;
  final int initialChapterIndex;
  final Future<void> Function(ReadingProgress progress) persistProgress;
  final SessionRecorder recordSession;
  final Future<void> Function({required EnginePositionHint hint})
  saveEnginePosition;
  final Future<EnginePositionHint?> Function({required String bookId})
  loadEnginePosition;
  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  Future<void>? _closeFuture;
  bool _viewportReady = false;
  bool _closing = false;
  bool _navigationInProgress = false;
  int _openGeneration = 0;
  Future<void> _preferencesQueue = Future<void>.value();
  int _preferencesVersion = 0;
  bool _preferencesDirty = false;

  // ==================== Progress / Session persistence ====================
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
  final isScrollModeSupported = signal<bool>(true);
  final canRetry = signal<bool>(false);
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
    this.sourceFingerprint,
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
      isActive: () => _viewportReady && !_closing,
    );
  }

  /// Open an EPUB file.
  Future<Publication> open(String path) async {
    // Yield to the event loop to avoid triggering signal listeners
    // during the build phase (useMemoized calls this synchronously).
    await Future(() {});

    final generation = ++_openGeneration;
    var nativePublicationOpened = false;
    try {
      _preferencesVersion++;
      _closeFuture = null;

      // A ViewModel can be reused after close, or a retry can race with a
      // still-mounted native viewport. Invalidate the old Dart listeners and
      // close the old native session before opening the next publication.
      await _cancelViewportSubscriptions();
      if (_currentLocator != null || _viewportReady) {
        await _sessionTracker.finalize();
        await _queueSave();
      }
      if (_publication != null || _viewportReady || _statusSub != null) {
        await reader.closePublication();
      }

      final uriPath = path.startsWith('file://')
          ? path
          : Uri.file(path).toString();
      status.value = 'opening...';
      error.value = null;
      canRetry.value = false;
      _viewportReady = false;
      _preferencesDirty = true;
      _closing = false;
      _navigationInProgress = false;
      _publication = null;
      _currentLocator = null;
      _initialLocator = null;
      _publicationFingerprint = '';
      readingMode.value = config.readingMode.value;
      _sessionTracker.reset();

      // ADR-021 修订：预置默认偏好，让原生 WebView 首次创建即处于正确布局
      // （scroll 或分页），消除"先分页后热切 scroll"的时序竞争。
      reader.setDefaultPreferences(
        EPUBPreferences(scroll: readingMode.value == ReadingMode.scroll),
      );

      final pub = await reader.openPublication(uriPath);
      nativePublicationOpened = true;
      if (generation != _openGeneration) {
        await reader.closePublication();
        throw StateError('Open cancelled');
      }
      _publication = pub;
      _publicationFingerprint = _publicationFingerprintFor(pub);
      isScrollModeSupported.value = _supportsScrollMode(pub);
      if (!isScrollModeSupported.value &&
          readingMode.value == ReadingMode.scroll) {
        readingMode.value = ReadingMode.pagination;
      }
      final links = pub.tocFlattened;
      await _loadBookMetadata();
      unawaited(_touchBook());
      _initialLocator = await _loadSavedPosition();
      if (generation != _openGeneration) {
        await reader.closePublication();
        _publication = null;
        throw StateError('Open cancelled');
      }
      if (_initialLocator == null && pub.readingOrder.isNotEmpty) {
        final chapterIndex = initialChapterIndex.clamp(
          0,
          pub.readingOrder.length - 1,
        );
        _initialLocator = pub.locatorFromLink(pub.readingOrder[chapterIndex]);
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
        if (nativePublicationOpened || _publication != null) {
          try {
            await reader.closePublication();
          } catch (_) {
            // Preserve the original open error for the retry UI.
          }
          _publication = null;
        }
        error.value = e.toString();
        canRetry.value = true;
        status.value = 'error';
      }
      rethrow;
    }
  }

  /// Position restored when constructing the native viewport.
  Locator? get initialLocator => _initialLocator;

  /// Current native position, used when the viewport is recreated for a layout
  /// mode change.
  Locator? get currentLocator => _currentLocator;

  /// Progress within the currently rendered EPUB resource.
  double? get currentResourceProgression =>
      _currentLocator?.locations?.progression;

  /// Subscribes to the native reader lifecycle before the platform widget is
  /// mounted. This avoids missing the broadcast `ready` status emitted while
  /// the native view is being created.
  Future<void> onViewportReady() async {
    if (_publication == null || _viewportReady || _closing) return;

    // Register the first listeners synchronously. Readium exposes a broadcast
    // status stream (not a replaying stream), so deferring this registration
    // until after the first frame can miss the native `ready` event and leave
    // every navigation command blocked by `_viewportReady`.
    final generation = _openGeneration;

    void listenToViewportEvents() {
      _statusSub = reader.onReaderStatusChanged.listen((s) {
        if (_closing || generation != _openGeneration) return;
        status.value = s.name;
        if (s.isReady) unawaited(_markViewportReady(generation));
      });

      _locatorSub = reader.onTextLocatorChanged.listen(
        (locator) => _onLocatorChangedForGeneration(locator, generation),
      );

      _errorSub = reader.onErrorEvent.listen((e) {
        if (_closing || generation != _openGeneration) return;
        error.value = e.message;
        canRetry.value = true;
        status.value = 'error';
      });
    }

    if (_statusSub != null) return;
    listenToViewportEvents();
  }

  Future<void> _markViewportReady(int generation) async {
    if (_viewportReady ||
        _closing ||
        generation != _openGeneration ||
        _publication == null) {
      return;
    }
    try {
      if (_preferencesDirty) await _applyPreferences();
      if (_closing || generation != _openGeneration || _publication == null) {
        return;
      }
      _preferencesDirty = false;
      _viewportReady = true;
      canRetry.value = false;
      error.value = null;
      status.value = 'ready';
    } catch (e) {
      error.value = e.toString();
      canRetry.value = true;
      status.value = 'error';
    }
  }

  /// Receives the authoritative locator from the rendered viewport.
  void onLocatorChanged(Locator locator) {
    _onLocatorChangedForGeneration(locator, _openGeneration);
  }

  void _onLocatorChangedForGeneration(Locator locator, int generation) {
    if (_closing || generation != _openGeneration) return;
    _currentLocator = locator;
    progress.value = locator.locations?.totalProgression ?? 0.0;
    if (locator.href.isNotEmpty) {
      currentChapterHref.value = locator.href;
    }
    if (_viewportReady) {
      error.value = null;
      canRetry.value = false;
      status.value = 'ready';
    }
    _sessionTracker.track(locator);
    _scheduleSave();
    _bookmarkController.updateForLocator(locator);
  }

  /// Navigate to a TOC link.
  Future<bool> goToLink(Link link) async {
    final publication = _publication;
    if (publication == null || !_viewportReady) return false;
    var navigated = false;
    try {
      await _runNavigation(() async {
        navigated = await reader.goByLink(link, publication);
        if (!navigated) throw StateError('目录定位失败');
      });
    } catch (e) {
      error.value = e.toString();
    }
    return navigated;
  }

  /// Close the current publication.
  Future<void> close() => _closeFuture ??= _close();

  /// Clears a retryable viewport error before rebuilding the native reader.
  void prepareRetry() {
    canRetry.value = false;
    error.value = null;
  }

  /// 应用进入后台/被中断时调用：结束当前会话并保存进度，但不关闭出版刊物。
  ///
  /// 之后继续阅读会开启新的会话（后台 = 阅读暂停 = 会话边界）。
  Future<void> flush() async {
    if (_closing || !_viewportReady) return;
    _saveTimer?.cancel();
    await _sessionTracker.finalize();
    await _queueSave();
  }

  Future<void> _close() async {
    _closing = true;
    _preferencesVersion++;
    _openGeneration += 1;
    status.value = 'closing';
    _viewportReady = false;
    _preferencesDirty = false;
    _saveTimer?.cancel();
    Object? closeError;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        closeError ??= e;
      }
    }

    await attempt(_sessionTracker.finalize);
    await attempt(_queueSave);

    await attempt(_cancelViewportSubscriptions);

    if (_ttsEnabled) await attempt(stopTts);
    if (_publication != null) await attempt(reader.closePublication);

    _publication = null;
    _currentLocator = null;
    isScrollModeSupported.value = true;
    _initialLocator = null;
    if (closeError != null) error.value = closeError.toString();
    status.value = 'closed';
  }

  Future<void> _cancelViewportSubscriptions() async {
    final statusSub = _statusSub;
    _statusSub = null;
    await statusSub?.cancel();

    final locatorSub = _locatorSub;
    _locatorSub = null;
    await locatorSub?.cancel();

    final errorSub = _errorSub;
    _errorSub = null;
    await errorSub?.cancel();
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

    await _runNavigation(() => _goToLocator(target));
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
      error.value = null;
      canRetry.value = false;
      status.value = 'ready';
    } catch (e) {
      error.value = e.toString();
      canRetry.value = false;
      status.value = 'error';
    } finally {
      _navigationInProgress = false;
    }
  }

  Future<void> _goToLocator(Locator locator) async {
    if (!await reader.goToLocator(locator)) {
      throw StateError('定位失败');
    }
  }
  // ==================== Preferences ====================

  Future<void> setReadingMode(ReadingMode mode) async {
    if (readingMode.value == mode) return;

    // Readium's Android navigator creates its resource pager with the initial
    // layout. Runtime scroll changes invalidate that pager asynchronously, so
    // recreating the Platform View is the only reliable way to make the new
    // layout take effect immediately. Set the default first so the new native
    // view is born in the requested mode.
    reader.setDefaultPreferences(
      EPUBPreferences(scroll: mode == ReadingMode.scroll),
    );

    if (_viewportReady) {
      _viewportReady = false;
      _preferencesDirty = true;
      status.value = 'applying preferences...';
    }

    readingMode.value = mode;
    config.readingMode.value = mode;
  }

  Future<bool> applyPreferences() async {
    _preferencesDirty = true;
    if (!_viewportReady) return false;

    // A slider emits many values during one drag. Keep the queue serialized,
    // but let stale requests exit before another native reflow is started.
    final requestVersion = ++_preferencesVersion;
    final next = _preferencesQueue.then((_) async {
      if (!_viewportReady || _closing) return false;
      if (requestVersion != _preferencesVersion) return true;
      try {
        final locator = _currentLocator;
        await _applyPreferences();
        if (requestVersion != _preferencesVersion) return true;

        // The native MethodChannel completes only after Readium and the
        // custom CSS have finished applying. Revisit the current locator
        // immediately after that acknowledgement; timing delays here make
        // the result depend on device performance.
        if (locator != null && !_closing) {
          if (requestVersion == _preferencesVersion &&
              !_closing &&
              _viewportReady) {
            await reader.goToLocator(locator);
          }
        }
        if (requestVersion != _preferencesVersion) return true;
        _preferencesDirty = false;
        error.value = null;
        status.value = 'ready';
        return true;
      } catch (e) {
        error.value = e.toString();
        canRetry.value = false;
        status.value = 'error';
        return false;
      }
    });
    _preferencesQueue = next.then<void>((_) {});
    return next;
  }

  bool _supportsScrollMode(Publication publication) {
    final rendition = publication.metadata.rendition;
    return publication.readingOrder.every(
      (link) =>
          link.properties.layout != EpubLayout.fixed &&
          rendition?.layoutOf(link) != EpubLayout.fixed,
    );
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
          bg = ReaderBgColors.darkBackground;
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
    final fontFamily = switch (config.fontFamily.value) {
      // Readium expects CSS generic family names for these built-in choices.
      'System' => 'sans-serif',
      'Serif' => 'serif',
      final value => value,
    };
    final fontSizePercent = config.fontSize.value < 50
        ? 100.0
        : config.fontSize.value
              .clamp(
                ReaderTypographyDefaults.minFontSize,
                ReaderTypographyDefaults.maxFontSize,
              )
              .toDouble();
    final lineHeight = config.lineHeight.value
        .clamp(
          ReaderTypographyDefaults.minLineHeight,
          ReaderTypographyDefaults.maxLineHeight,
        )
        .toDouble();
    // ReaderConfig stores the CSS numeric weight (300..700), while Readium
    // expects a relative boldness value (0..2.5). Convert persisted UI values
    // at this native bridge instead of changing the public config semantics.
    final fontWeight =
        config.fontWeight.value
            .clamp(
              ReaderTypographyDefaults.minFontWeight,
              ReaderTypographyDefaults.maxFontWeight,
            )
            .toDouble() /
        ReaderTypographyDefaults.fontWeight;
    final prefs = EPUBPreferences(
      fontFamily: fontFamily,
      // Readium only applies user alignment/typography overrides when
      // publisher CSS is disabled for the navigator.
      publisherStyles: false,
      // Migrate old built-in dp values (< 50) to Readium's ratio scale.
      fontSize: fontSizePercent / 100.0,
      fontWeight: fontWeight,
      lineHeight: lineHeight,
      letterSpacing: config.letterSpacing.value,
      paragraphSpacing: config.paragraphSpacing.value,
      paragraphIndent: config.paragraphIndent.value,
      textAlign: switch (config.textAlign.value) {
        ReaderTextAlign.auto => null,
        ReaderTextAlign.left => TextAlign.left,
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
        await reader.play(null);
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
    _saveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_queueSave());
    });
  }

  Future<void> _queueSave() {
    final next = _saveQueue.then((_) => _savePositionNow());
    _saveQueue = next;
    return next;
  }

  Future<void> _savePositionNow() async {
    final locator = _currentLocator;
    if (locator == null) return;
    await _saveReadingProgress();
  }

  /// 进度写入 Rust `reading_progress` 表；失败时保留阅读流程并提示用户。
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
        // 阅读时长由 reading_sessions 聚合提供（详情卡读 totalReadingSeconds）；
        // 此字段保留兼容写入，不再被统计消费。
        readingTimeSeconds: 0,
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
        } catch (e) {
          error.value = '标记阅读完成失败：$e';
        }
      }
    } catch (e) {
      error.value = '保存阅读进度失败：$e';
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
    } catch (e) {
      error.value = '保存阅读位置失败：$e';
    }
  }


  Future<Locator?> _loadSavedPosition() async {
    try {
      final hint = await loadEnginePosition(bookId: bookId);
      if (hint == null) return null;
      if (hint.engineKind != 'readium') return null;
      final opaque = hint.opaquePosition;
      if (opaque.isEmpty) return null;
      // ADR-019：Locator 与当前 EPUB 指纹不匹配时必须丢弃。
      if (hint.publicationFingerprint.isEmpty ||
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

  Future<void> toggleBookmark() async {
    // 互斥守卫由 ReadiumBookmarkController 内部持有（_add/_removeCurrent/_delete）。
    if (isBookmarked.value) {
      await removeBookmark();
    } else {
      await addBookmark();
    }
  }

  Future<void> goToBookmark(Bookmark entry) async {
    if (!_viewportReady || _closing) return;
    await _runNavigation(
      () => _bookmarkController.goTo(entry, navigate: _goToLocator),
    );
  }

  Future<void> deleteBookmarkByEntry(Bookmark entry) async {
    await _bookmarkController.delete(entry);
  }

  Future<void> _loadBookmarks() async {
    await _bookmarkController.load(currentLocator: _currentLocator);
  }

  String _tocTitleForHref(String href) {
    for (final link in tocLinks.value) {
      if (link.href == href) return link.title ?? '';
    }
    final path = _hrefPath(href);
    for (final link in tocLinks.value) {
      if (_hrefPath(link.href) == path) return link.title ?? '';
    }
    return '';
  }

  /// href → 正文阅读顺序索引。
  int _chapterIndexForHref(String href) {
    if (href.isEmpty) return _sessionTracker.currentChapterIndex ?? 0;
    final path = _hrefPath(href);
    final readingOrder = _publication?.readingOrder ?? const <Link>[];
    for (var i = 0; i < readingOrder.length; i++) {
      final linkHref = readingOrder[i].href;
      if (_hrefPath(linkHref) == path) return i;
    }
    // 资源不在目录中（如附录）：沿用当前会话章节，避免误拆会话。
    return _sessionTracker.currentChapterIndex ?? 0;
  }

  /// Locator → legacy auxiliary offset.
  ///
  /// MVP 的恢复真相是完整 Locator，Readium 也不提供章节字符偏移。
  /// 因此不能把全书 progression 伪装成章节 offset；这里只保留原生位置
  /// 作为会话/书签列表的辅助字段。
  int _charOffsetFor(Locator locator) {
    return locator.locations?.position ?? 0;
  }

  /// 预载既有阅读累计时长。
  Future<void> _loadBookMetadata() async {
    try {
      final detail = await book_api.getBookDetail(bookId: bookId);
      _lastIsCompleted = detail.progress?.isCompleted ?? false;
    } catch (_) {
      // 元数据加载失败不影响阅读；进度估算退化为页码位置。
    }
  }

  String _publicationFingerprintFor(Publication publication) {
    final source = sourceFingerprint?.trim();
    final identifier = publication.metadata.identifier?.trim();
    if (source == null || source.isEmpty) return identifier ?? '';
    if (identifier == null || identifier.isEmpty) return source;
    return '$source|id:$identifier';
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
