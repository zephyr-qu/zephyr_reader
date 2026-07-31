import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';

import 'readium_reader_content.dart';
import 'readium_view_model.dart';

/// Readium EPUB reader shell (MVP simplified).
///
/// Wraps [ReadiumReaderContent] in a minimal Scaffold with a top bar.
class ReadiumReaderShell extends HookWidget {
  final String filePath;

  const ReadiumReaderShell({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    final ReaderConfig config = useMemoized(() => getIt<ReaderConfig>());
    final ReadiumViewModel vm = useMemoized(
      () => ReadiumViewModel(config: config),
    );

    final double progress = useSignalValue(vm.progress) as double;
    final String statusText = useSignalValue(vm.status) as String;
    final String bookTitle = useSignalValue(vm.title) as String;

    // Lifecycle — clean up ViewModel resources
    useEffect(() {
      return () {
        unawaited(vm.close());
        vm.dispose();
      };
    }, []);

    final String progressText = progress > 0
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : statusText;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(bookTitle, style: const TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(progressText,
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ReadiumReaderContent(vm: vm, filePath: filePath),
      ),
    );
  }
}
