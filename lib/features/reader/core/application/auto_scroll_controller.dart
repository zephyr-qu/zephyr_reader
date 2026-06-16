import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';

/// 自动滚动定时器控制。
class AutoScrollController {
  final ReaderConfig _config;

  /// 自动滚动触发器
  final autoScrollTick = signal<int>(0);

  Timer? _autoScrollTimer;

  AutoScrollController(this._config);

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

  void reset() {
    stopAutoScroll();
    autoScrollTick.value = 0;
  }
}
