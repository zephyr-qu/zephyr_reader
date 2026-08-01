import 'dart:async';
import 'dart:convert';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';

/// Readium EPUB reader ViewModel (MVP).
///
/// Wraps [Flureadium] directly, exposes reading state via signals.
class ReadiumViewModel {
  final Flureadium reader;
  final ReaderConfig config;
  final String bookId;
  final int initialChapterIndex;
  Timer? _saveTimer;
  Future<void>? _closeFuture;
  bool _viewportReady = false;
  bool _closing = false;
  bool _navigationInProgress = false;
  int _openGeneration = 0;

  static const _positionPrefix = 'readium_position_';

  // ==================== Signals ====================

  final progress = signal<double>(0.0);
  final status = signal<String>('closed');
  final title = signal<String>('');
  final error = signal<String?>(null);
  final tocLinks = signal<List<Link>>([]);
  final currentChapterHref = signal<String>('');
  final isTtsPlaying = signal<bool>(false);
  final readingMode = signal<ReadingMode>(ReadingMode.pagination);

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
  }) : reader = reader ?? Flureadium();

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

      final pub = await reader.openPublication(uriPath);
      if (generation != _openGeneration) {
        await reader.closePublication();
        throw StateError('Open cancelled');
      }
      _publication = pub;
      final links = flattenToc(pub.tableOfContents);
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
    _scheduleSave();
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

  Future<void> _close() async {
    _closing = true;
    _openGeneration += 1;
    status.value = 'closing';
    _viewportReady = false;
    _saveTimer?.cancel();
    try {
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
      fontWeight: null,
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

  // ==================== Position Persistence ====================

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _savePositionNow);
  }

  Future<void> _savePositionNow() async {
    final locator = _currentLocator;
    if (locator == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _positionPrefix + bookId,
      jsonEncode(locator.toJson()),
    );
  }

  Future<Locator?> _loadSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_positionPrefix + bookId);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Locator.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
