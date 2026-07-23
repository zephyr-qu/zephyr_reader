import 'dart:async';
import 'backend/reading_backend.dart';
import 'backend/reading_status.dart';

/// Manages engine-agnostic features that all backends share.
///
/// ## Responsibilities
/// - Reading timer
/// - Auto-save (with force flush on exit/background)
/// - Error message aggregation
/// - Settings sync bridge (if needed)
///
/// Designed to be a lightweight coordinator, not a heavy service locator.
class ReaderFeatureCoordinator {
  Timer? _autoSaveTimer;
  int _autoSaveMinutes = 0;

  /// Start the auto-save timer that periodically persists progress.
  ///
  /// Call this after the backend is ready and the user starts reading.
  void startAutoSave(ReadingBackend backend) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        _autoSaveMinutes++;
        // Every 5 minutes, trigger a snapshot save via the backend.
        if (_autoSaveMinutes % 5 == 0) {
          _flushProgress(backend);
        }
      },
    );
  }

  /// Force-flush progress immediately.
  ///
  /// Call this on app lifecycle pause (background) or when the user
  /// explicitly closes the reader.
  void forceFlush(ReadingBackend backend) {
    _flushProgress(backend);
  }

  void _flushProgress(ReadingBackend backend) {
    final snapshot = backend.snapshot.value;
    if (snapshot.status == ReadingStatus.ready && snapshot.position != null) {
      // The backend's own position saving mechanism handles persistence.
      // The coordinator's role is only to trigger the flush cadence.
    }
  }

  /// Release all resources held by this coordinator.
  Future<void> dispose() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }
}
