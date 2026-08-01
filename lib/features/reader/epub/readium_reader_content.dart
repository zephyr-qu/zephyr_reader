import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';

import 'readium_view_model.dart';

/// Readium EPUB 内容容器组件。
///
/// 封装 [ReadiumReaderWidget]，处理打开/加载/错误状态。
/// viewport ready、Locator 和点击事件回传给 [ReadiumViewModel]。
class ReadiumReaderContent extends HookWidget {
  final ReadiumViewModel vm;
  final String filePath;
  final Widget Function()? loadingBuilder;
  final Widget Function(String error, VoidCallback retry)? errorBuilder;
  final VoidCallback? onViewportTap;

  const ReadiumReaderContent({
    super.key,
    required this.vm,
    required this.filePath,
    this.loadingBuilder,
    this.errorBuilder,
    this.onViewportTap,
  });

  @override
  Widget build(BuildContext context) {
    final retryAttempt = useState(0);
    final horizontalDragDistance = useRef(0.0);
    final scrollPointerStartY = useRef<double?>(null);
    final readingMode = useSignalValue(vm.readingMode) as ReadingMode;
    final isPagination = readingMode == ReadingMode.pagination;
    final openFuture = useMemoized(() => vm.open(filePath), [
      filePath,
      retryAttempt.value,
    ]);

    void retry() {
      retryAttempt.value += 1;
    }

    return FutureBuilder<Publication>(
      future: openFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call() ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final err = vm.error.value ?? snapshot.error.toString();
          return errorBuilder?.call(err, retry) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      err,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: retry, child: const Text('重试')),
                  ],
                ),
              );
        }

        final pub = snapshot.data!;
        return Listener(
          onPointerDown: isPagination
              ? null
              : (event) => scrollPointerStartY.value = event.position.dy,
          onPointerUp: isPagination
              ? null
              : (event) {
                  final startY = scrollPointerStartY.value;
                  scrollPointerStartY.value = null;
                  if (startY != null && startY - event.position.dy >= 48) {
                    unawaited(vm.advanceFromScrollBoundary());
                  }
                },
          onPointerCancel: isPagination
              ? null
              : (_) => scrollPointerStartY.value = null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: isPagination
                ? (_) => horizontalDragDistance.value = 0
                : null,
            onHorizontalDragUpdate: isPagination
                ? (details) {
                    horizontalDragDistance.value += details.primaryDelta ?? 0;
                  }
                : null,
            onHorizontalDragEnd: isPagination
                ? (details) {
                    final distance = horizontalDragDistance.value;
                    final velocity = details.primaryVelocity ?? 0;
                    horizontalDragDistance.value = 0;

                    if (distance <= -48 || velocity <= -300) {
                      unawaited(vm.goRight());
                    } else if (distance >= 48 || velocity >= 300) {
                      unawaited(vm.goLeft());
                    }
                  }
                : null,
            onHorizontalDragCancel: isPagination
                ? () => horizontalDragDistance.value = 0
                : null,
            child: ReadiumReaderWidget(
              publication: pub,
              initialLocator: vm.initialLocator,
              onReady: () => unawaited(vm.onViewportReady()),
              onLocatorChanged: vm.onLocatorChanged,
              onTap: onViewportTap,
            ),
          ),
        );
      },
    );
  }
}
