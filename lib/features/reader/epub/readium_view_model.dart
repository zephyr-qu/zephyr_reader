import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';

/// Readium EPUB 阅读器的轻量 ViewModel。
///
/// 封装 [Flureadium] API，通过信号暴露给 UI 层。
/// 与现有 TXT 阅读器共用 [ReaderConfig] 共享设置（主题、字体等）。
class ReadiumViewModel {
  final Flureadium reader;
  final ReaderConfig config;

  // ==================== 信号 ====================

  /// 阅读进度（0.0 ~ 1.0）
  final progress = signal<double>(0.0);

  /// 阅读器状态（如 opening, ready, closed）
  final status = signal<String>('closed');

  /// 当前打开的书籍标题
  final title = signal<String>('');

  /// 错误信息
  final error = signal<String?>(null);

  /// 文件路径
  final filePath = signal<String>('');

  // ==================== 订阅 ====================

  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;
  StreamSubscription<ReadiumError>? _errorSub;

  ReadiumViewModel({required this.config, Flureadium? reader})
    : reader = reader ?? Flureadium();

  /// 打开 EPUB 文件。
  ///
  /// [path] 可以是本地文件路径或 `file:///` URI。
  Future<Publication> open(String path) async {
    try {
      final uriPath = path.startsWith('file://')
          ? path
          : Uri.file(path).toString();
      filePath.value = uriPath;
      status.value = 'opening...';
      error.value = null;

      final pub = await reader.openPublication(uriPath);
      title.value = pub.metadata.title ?? pub.metadata.identifier ?? '';
      status.value = 'ready';

      // 取消旧订阅，建立新订阅（fire-and-forget）
      unawaited(_locatorSub?.cancel().then((_) {}));
      _locatorSub = reader.onTextLocatorChanged.listen((locator) {
        progress.value = locator.locations?.totalProgression ?? 0.0;
      });

      unawaited(_statusSub?.cancel().then((_) {}));
      _statusSub = reader.onReaderStatusChanged.listen((s) {
        status.value = s.name;
      });

      unawaited(_errorSub?.cancel().then((_) {}));
      _errorSub = reader.onErrorEvent.listen((e) {
        error.value = e.message ?? e.toString();
      });

      return pub;
    } catch (e) {
      error.value = e.toString();
      status.value = 'error';
      rethrow;
    }
  }

  /// 关闭当前出版物。
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

  // ==================== 导航 ====================

  Future<void> goLeft() => reader.goLeft();

  Future<void> goRight() => reader.goRight();

  Future<void> skipToNext() => reader.skipToNext();

  Future<void> skipToPrevious() => reader.skipToPrevious();

  // ==================== 生命周期 ====================

  void dispose() {
    unawaited(_locatorSub?.cancel().then((_) {}));
    unawaited(_statusSub?.cancel().then((_) {}));
    unawaited(_errorSub?.cancel().then((_) {}));
  }
}
