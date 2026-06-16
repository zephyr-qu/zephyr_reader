import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_shell.dart';

/// 阅读器页面。
///
/// 核心阅读界面，支持滚动/翻页/双语对照等多种阅读模式。
/// 包含工具栏、目录、书签、笔记、搜索、高亮、TTS 朗读等完整阅读功能。
/// 通过 [ReaderViewModel] 管理阅读状态。
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
    return ReaderShell(
      bookId: bookId,
      initialChapterId: initialChapterId,
    );
  }
}
