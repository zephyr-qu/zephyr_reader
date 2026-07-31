import 'dart:async';
import 'dart:convert';

import 'package:flureadium/flureadium.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';

/// Readium EPUB reader ViewModel (MVP).
///
/// Wraps [Flureadium] directly, exposes reading state via signals.
class ReadiumViewModel {
  final Flureadium reader;
  final ReaderConfig config;
  final String _bookId;
  Timer? _saveTimer;

  static const _positionPrefix = 'readium_position_';

  // ==================== Signals ====================

  final progress = signal<double>(0.0);
  final status = signal<String>('closed');
  final title = signal<String>('');
  final error = signal<String?>(null);
  final tocLinks = signal<List<Link>>([]);
  final currentChapterHref = signal<String>('');

  Locator? _currentLocator;
  Publication? _publication;

  // ==================== Subscriptions ====================

  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;
  StreamSubscription<ReadiumError>? _errorSub;

  ReadiumViewModel({required this.config, required this._bookId})
    : reader = Flureadium();

  /// Open an EPUB file.
  Future<Publication> open(String path) async {
    try {
      final uriPath = path.startsWith('file://')
          ? path
          : Uri.file(path).toString();
      status.value = 'opening...';
      error.value = null;

      final pub = await reader.openPublication(uriPath);
      _publication = pub;
      title.value = pub.metadata.title;
      tocLinks.value = pub.tableOfContents;
      status.value = 'ready';

      // Restore last position
      unawaited(_restorePosition());

      // Cancel old subscriptions, create new ones
      await _locatorSub?.cancel();
      _locatorSub = reader.onTextLocatorChanged.listen((locator) {
        _currentLocator = locator;
        progress.value = locator.locations?.totalProgression ?? 0.0;
        if (locator.href.isNotEmpty) {
          currentChapterHref.value = locator.href;
        }
        _scheduleSave();
      });

      await _statusSub?.cancel();
      _statusSub = reader.onReaderStatusChanged.listen((s) {
        status.value = s.name;
      });

      await _errorSub?.cancel();
      _errorSub = reader.onErrorEvent.listen((e) {
        error.value = e.message;
      });

      return pub;
    } catch (e) {
      error.value = e.toString();
      status.value = 'error';
      rethrow;
    }
  }

  /// Get the current locator for position persistence.
  Locator? getCurrentLocator() => _currentLocator;

  /// Navigate to a TOC link.
  Future<bool> goToLink(Link link) async {
    if (_publication == null) return false;
    return reader.goByLink(link, _publication!);
  }

  /// Close the current publication.
  Future<void> close() async {
    _saveTimer?.cancel();
    await _savePositionNow();
    _locatorSub = null;
    await _statusSub?.cancel();
    _statusSub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    await reader.closePublication();
    status.value = 'closed';
  }

  // ==================== Navigation ====================

  Future<void> goLeft() => reader.goLeft();
  Future<void> goRight() => reader.goRight();
  Future<void> skipToNext() => reader.skipToNext();
  Future<void> skipToPrevious() => reader.skipToPrevious();

  // ==================== Lifecycle ====================

  void dispose() {
    _saveTimer?.cancel();
    _savePositionNow();
    _locatorSub?.cancel();
    _statusSub?.cancel();
    _errorSub?.cancel();
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
      _positionPrefix + _bookId,
      jsonEncode(locator.toJson()),
    );
  }

  Future<void> _restorePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_positionPrefix + _bookId);
    if (jsonStr == null) return;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final locator = Locator.fromJson(map);
      if (locator != null) {
        await reader.goToLocator(locator);
      }
    } catch (_) {
      // Corrupted position data, ignore
    }
  }
}
