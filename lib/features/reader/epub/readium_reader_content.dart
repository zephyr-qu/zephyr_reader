import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'readium_view_model.dart';

/// Readium EPUB 内容容器组件。
///
/// 封装 [ReadiumReaderWidget]，处理打开/加载/错误状态。
/// 代替现有 TXT 引擎的 [ReaderContent]，与同一套 UI 壳配合使用。
class ReadiumReaderContent extends HookWidget {
  final ReadiumViewModel vm;
  final String filePath;
  final Widget Function()? loadingBuilder;
  final Widget Function(String error, VoidCallback retry)? errorBuilder;

  const ReadiumReaderContent({
    super.key,
    required this.vm,
    required this.filePath,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final openFuture = useMemoized(() => vm.open(filePath), [filePath]);

    return FutureBuilder<Publication>(
      future: openFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call() ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final err = vm.error.value ?? snapshot.error.toString();
          return errorBuilder?.call(err, () {
                // 重新打开
                vm.open(filePath);
              }) ??
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
                    ElevatedButton(
                      onPressed: () => vm.open(filePath),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
        }

        final pub = snapshot.data!;
        return ReadiumReaderWidget(publication: pub);
      },
    );
  }
}
