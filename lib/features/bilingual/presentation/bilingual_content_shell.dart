import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/reader/core/domain/bilingual_reader_delegate.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_translation_dialog.dart';
import 'package:zephyr_reader/features/bilingual/presentation/bilingual_renderer.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/bilingual/models.dart';
import 'package:zephyr_reader/src/rust/domain/note/models.dart';


/// 双语内容外壳组件。
///
/// 封装 [BilingualModeRenderer] 和 [ReaderTranslationDialog]，
/// 通过 [BilingualReaderDelegate] 获取双语状态并驱动翻译流程。
/// 内部管理双语高亮对生命周期，核心阅读器无需感知。
class BilingualContentShell extends HookWidget {
  final BilingualReaderDelegate delegate;
  final ScrollController scrollController;
  final ReaderRenderConfig config;
  final List<Note> highlights;
  final void Function(Note) onHighlightTap;
  final void Function(String, int, int) onSelectionChanged;
  final void Function(Offset?) onSelectionGlobalPosition;

  const BilingualContentShell({
    super.key,
    required this.delegate,
    required this.scrollController,
    required this.config,
    required this.highlights,
    required this.onHighlightTap,
    required this.onSelectionChanged,
    required this.onSelectionGlobalPosition,
  });

  void _showTranslationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ReaderTranslationDialog(
        onChanged: delegate.setTranslationContent,
        translationConfigured: delegate.isConfigured,
        onTranslateWithApi: () {
          Navigator.of(context).pop();
          unawaited(delegate.translateChapter());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bilingual pairs fetched externally; delegate doesn't expose bookId/chapterIndex.
    // For now pass empty list — the renderer works without pairs (alignment mode).
    // TODO(p4-5): inject bookId/chapterIndex into delegate for auto-fetch.
    final pairs = useState<List<BilingualHighlightPair>>([]);

    return BilingualModeRenderer(
      config: config,
      scrollController: scrollController,
      bilingualPairs: pairs.value,
      isBilingualLoading: delegate.isBilingualLoading,
      bilingualError: delegate.bilingualError,
      bilingualAlignment: delegate.alignment,
      highlights: highlights,
      onRequestTranslation: () => _showTranslationDialog(context),
      onRetryTranslation: () => unawaited(delegate.translateChapter()),
      onHighlightTap: onHighlightTap,
      onSelectionChanged: onSelectionChanged,
      onSelectionGlobalPosition: onSelectionGlobalPosition,
    );
  }
}
