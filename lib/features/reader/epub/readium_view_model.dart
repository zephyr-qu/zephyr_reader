import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';

/// Readium EPUB reader ViewModel (MVP).
///
/// Wraps [Flureadium] directly, exposes reading state via signals.
class ReadiumViewModel {
  final Flureadium reader;
  final ReaderConfig config;

  // ==================== Signals ====================

  /// Reading progress (0.0 ~ 1.0)
  final progress = signal<double>(0.0);

  /// Reader status (closed, opening..., ready, error)
  final status = signal<String>('closed');

  /// Current book title
  final title = signal<String>('');

  /// Error message
  final error = signal<String?>(null);

  /// Current Locator (updated from stream)
  Locator? _currentLocator;

  // ==================== Subscriptions ====================

  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;
  StreamSubscription<ReadiumError>? _errorSub;

  ReadiumViewModel({required this.config}) : reader = Flureadium();
  /// Open an EPUB file.
  Future<Publication> open(String path) async {
    try {
      final uriPath = path.startsWith('file://')
          ? path
          : Uri.file(path).toString();
      status.value = 'opening...';
      error.value = null;

      final pub = await reader.openPublication(uriPath);
      title.value = pub.metadata.title;
      status.value = 'ready';

      // Cancel old subscriptions, create new ones
      await _locatorSub?.cancel();
      _locatorSub = reader.onTextLocatorChanged.listen((locator) {
        _currentLocator = locator;
        progress.value = locator.locations?.totalProgression ?? 0.0;
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

  /// Close the current publication.
  Future<void> close() async {
    await _locatorSub?.cancel();
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
    _locatorSub?.cancel();
    _statusSub?.cancel();
    _errorSub?.cancel();
  }
}
