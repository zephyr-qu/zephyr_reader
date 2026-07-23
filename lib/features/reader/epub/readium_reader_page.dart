import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'readium_reader_shell.dart';

/// Readium EPUB 阅读器页面入口。
///
/// 接收一个 EPUB 文件路径，打开统一风格的阅读页面。
/// 使用方式：
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => ReadiumReaderPage(filePath: '/path/to/book.epub'),
///   ),
/// );
/// ```
class ReadiumReaderPage extends HookWidget {
  final String filePath;

  const ReadiumReaderPage({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return ReadiumReaderShell(filePath: filePath);
  }
}
