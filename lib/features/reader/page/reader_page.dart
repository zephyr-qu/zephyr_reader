import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/reader/page/unified_reader_shell.dart';

/// 统一阅读器页面入口。
///
/// 所有书籍（TXT / Builtin EPUB / Readium EPUB）都通过此页面进入。
/// 后端引擎由 [UnifiedReaderShell] 根据书籍格式自动选择。
class ReaderPage extends HookWidget {
  final String bookId;
  final int initialChapterId;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedReaderShell(
      bookId: bookId,
      initialChapterId: initialChapterId,
    );
  }
}
