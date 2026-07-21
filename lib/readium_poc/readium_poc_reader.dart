import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';

/// 最小化 Readium PoC 阅读器页面。
///
/// 职责：在隔离的 [readium_poc] 目录中，验证 Readium 能否
/// 满足 Zephyr Reader 的核心 EPUB 阅读需求。
///
/// 验证目标：
/// 1. 零溢出排版、分页连续
/// 2. 文本选择和高亮
/// 3. 性能基线（帧率/内存）
/// 4. TXT 包装 EPUB 后的性能
class ReadiumPocReader extends StatefulWidget {
  final String filePath;

  const ReadiumPocReader({super.key, required this.filePath});

  @override
  State<ReadiumPocReader> createState() => _ReadiumPocReaderState();
}

class _ReadiumPocReaderState extends State<ReadiumPocReader> {
  final reader = FlutterReadium();
  late Future<Publication> _openFuture;
  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;
  double _progress = 0.0;
  String _status = 'opening...';

  @override
  void initState() {
    super.initState();
    _openFuture = reader.openPublication(widget.filePath);
    _locatorSub = reader.onTextLocatorChanged.listen((locator) {
      if (!mounted) return;
      setState(() {
        _progress = locator.locations?.totalProgression ?? 0.0;
      });
    });
    _statusSub = reader.onReaderStatusChanged.listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status.name;
      });
    });
  }

  @override
  void dispose() {
    _locatorSub?.cancel();
    _statusSub?.cancel();
    reader.closePublication();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Readium PoC — ${_progress.toStringAsFixed(1)}%'),
        actions: [
          Text(_status, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Publication>(
        future: _openFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Open failed: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final pub = snapshot.data!;
          return Column(
            children: [
              Expanded(child: ReadiumReaderWidget(publication: pub)),
              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: () => reader.goBackward(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => reader.goBackward(),
          ),
          Text('${(_progress * 100).toStringAsFixed(0)}%'),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => reader.goForward(),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: () => reader.goForward(),
          ),
        ],
      ),
    );
  }
}
