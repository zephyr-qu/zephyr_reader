import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_chrome_shell.dart';

import 'readium_reader_content.dart';
import 'readium_view_model.dart';

/// Readium EPUB 阅读器壳层。
///
/// 通过 [ReaderChromeShell] 复用通用 UI 壳层（主题、工具栏、翻页等），
/// 内容区使用 [ReadiumReaderContent]（封装 Readium 原生渲染）。
class ReadiumReaderShell extends HookWidget {
  final String filePath;

  const ReadiumReaderShell({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    final ReaderConfig config = useMemoized(() => getIt<ReaderConfig>());
    final ReadiumViewModel vm = useMemoized(
      () => ReadiumViewModel(config: config),
    );

    // 解包信号值（显式 as 转换避免 useSignalValue 泛型推断失败）
    final double progress = useSignalValue(vm.progress) as double;
    final String statusText = useSignalValue(vm.status) as String;
    final String bookTitle = useSignalValue(vm.title) as String;

    // 生命周期 — 清理 ViewModel 资源
    useEffect(() {
      return () {
        unawaited(vm.close());
        vm.dispose();
      };
    }, []);

    final String progressText = progress > 0
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : statusText;

    return ReaderChromeShell(
      config: config,
      content: ReadiumReaderContent(vm: vm, filePath: filePath),
      title: bookTitle,
      progress: progressText,
      isReady: statusText == 'ready',
      onPreviousPage: () => unawaited(vm.goLeft()),
      onNextPage: () => unawaited(vm.goRight()),
    );
  }
}
