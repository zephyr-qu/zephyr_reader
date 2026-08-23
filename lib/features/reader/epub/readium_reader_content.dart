import 'dart:async';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';

import 'readium_view_model.dart';

/// Readium EPUB 内容容器组件。
///
/// 封装 [ReadiumReaderWidget]，处理打开/加载/错误状态。
/// native 生命周期和 Locator 通过 [ReadiumViewModel] 的事件流处理。
class ReadiumReaderContent extends HookWidget {
  final ReadiumViewModel vm;
  final String filePath;
  final Widget Function()? loadingBuilder;
  final Widget Function(String error, VoidCallback retry)? errorBuilder;
  final ValueNotifier<bool>? shouldShowControls;

  const ReadiumReaderContent({
    super.key,
    required this.vm,
    required this.filePath,
    this.loadingBuilder,
    this.errorBuilder,
    this.shouldShowControls,
  });

  @override
  Widget build(BuildContext context) {
    final retryAttempt = useState(0);
    final horizontalDragDistance = useRef(0.0);
    final readingMode = useSignalValue(vm.readingMode) as ReadingMode;
    // Reading mode changes the native pager type, so that change gets a fresh
    // Platform View. Text alignment is submitted to the existing native
    // navigator and must not replace the view while it is mounted.
    final viewportKey = useMemoized(GlobalKey.new, [
      filePath,
      retryAttempt.value,
      readingMode,
    ]);
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
        final isPagination = readingMode == ReadingMode.pagination;
        final viewport = GestureDetector(
          behavior: isPagination
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
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
          child: _ReadiumViewport(
            viewportKey: viewportKey,
            publication: pub,
            initialLocator: vm.currentLocator ?? vm.initialLocator,
            shouldShowControls: shouldShowControls,
          ),
        );
        // Subscribe before the native Platform View is created. Its ready
        // status is broadcast and can otherwise be emitted before the old
        // post-frame subscription is installed.
        unawaited(vm.onViewportReady());
        return viewport;
      },
    );
  }
}

class _ReadiumViewport extends StatelessWidget {
  final GlobalKey viewportKey;
  final Publication publication;
  final Locator? initialLocator;
  final ValueNotifier<bool>? shouldShowControls;

  const _ReadiumViewport({
    required this.viewportKey,
    required this.publication,
    required this.initialLocator,
    required this.shouldShowControls,
  });

  @override
  Widget build(BuildContext context) {
    return ReadiumReaderWidget(
      key: viewportKey,
      publication: publication,
      initialLocator: initialLocator,
      shouldShowControls: shouldShowControls,
    );
  }
}
