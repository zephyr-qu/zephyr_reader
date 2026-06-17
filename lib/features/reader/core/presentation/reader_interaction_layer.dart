import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_ui_state.dart';
import 'package:zephyr_reader/features/reader/page/reader_dictionary_panel.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_actions.dart';
import 'package:zephyr_reader/features/reader/annotations/presentation/reader_annotation_dialog.dart';
import 'package:zephyr_reader/features/reader/page/touch/selection_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/touch/tap_zone.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

double readerSelectionToolbarTop(double screenHeight, Offset? pos) {
  if (pos == null) return 80;
  const gap = 8.0;
  const h = 52.0;
  final above = pos.dy - h - gap;
  if (above > 0) return above;
  final below = pos.dy + gap + 20;
  return below.clamp(0, screenHeight - h);
}

class ReaderSelectionToolbarLayer extends HookWidget {
  const ReaderSelectionToolbarLayer({
    super.key,
    required this.vm,
    required this.uiState,
  });

  final ReaderViewModel vm;
  final ReaderUiState uiState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String bSelectedtext = useSignalValue(vm.annotations.selectedText);
    final int bSelectionstart = useSignalValue(vm.annotations.selectionStart);
    final ReadingMode bCurrentreadingmode = useSignalValue(vm.readingMode);
    final Offset? selectionGlobalPos = useSignalValue(
      uiState.selectionGlobalPos,
    );

    if (bSelectedtext.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: readerSelectionToolbarTop(
        MediaQuery.sizeOf(context).height,
        selectionGlobalPos,
      ),
      left: 0,
      right: 0,
      child: SelectionToolbar(
        selectedText: bSelectedtext,
        onHighlight: () => vm.saveHighlight(l10n),
        onAnnotate: () => showDialog<void>(
          context: context,
          builder: (_) => ReaderAnnotationDialog(
            selectedText: bSelectedtext,
            onSave: (text) => vm.saveAnnotation(text, l10n),
          ),
        ),
        onLookup: () => showDictionaryPanel(context, vm, bSelectedtext),
        onAddToVocabulary: () => addToVocabulary(
          context,
          vm,
          bSelectedtext,
          bookId: vm.chapterManager.bookId.value,
          chapterIndex: vm.chapterManager.chapterIndex.value,
          charOffset: bSelectionstart,
        ),
        onBilingualHighlight: bCurrentreadingmode == ReadingMode.bilingual
            ? () => onBilingualHighlight(context, vm)
            : null,
        onDismiss: () => vm.annotations.clearSelection(),
      ),
    );
  }
}

class ReaderTapZoneLayer extends HookWidget {
  const ReaderTapZoneLayer({
    super.key,
    required this.vm,
    required this.uiState,
    required this.tapLayout,
    required this.withTimer,
  });

  final ReaderViewModel vm;
  final ReaderUiState uiState;
  final TapLayout tapLayout;
  final void Function(VoidCallback action) withTimer;

  @override
  Widget build(BuildContext context) {
    final bool showToolbar = useSignalValue(uiState.showToolbar);
    final String bSelectedtext = useSignalValue(vm.annotations.selectedText);
    final int bPageindex = useSignalValue(vm.chapterManager.pageIndex);
    final int bTotalpages = useSignalValue(vm.chapterManager.totalPages);
    final int bChapterindex = useSignalValue(vm.chapterManager.chapterIndex);
    final AsyncState<List<Chapter>> chaptersState = useSignalValue(
      vm.chapterManager.chapters,
    );
    final int bNumchapters = (chaptersState.value as List?)?.length ?? 0;
    final ReadingMode bCurrentreadingmode = useSignalValue(vm.readingMode);

    final showSelection = bSelectedtext.isNotEmpty;

    if (showToolbar ||
        showSelection ||
        bCurrentreadingmode == ReadingMode.pageTurn) {
      return const SizedBox.shrink();
    }

    return TapZone(
      tapLayout: tapLayout,
      pageIndex: bPageindex,
      totalPages: bTotalpages,
      hasNextChapter: bChapterindex < bNumchapters - 1,
      hasPreviousChapter: bChapterindex > 0,
      onPreviousPage: () {
        unawaited(vm.chapterManager.previousPage());
        HapticFeedback.lightImpact();
      },
      onNextPage: () {
        unawaited(vm.chapterManager.nextPage());
        HapticFeedback.lightImpact();
      },
      onCenterTap: () => withTimer(() {
        uiState.showToolbar.value = !showToolbar;
        HapticFeedback.selectionClick();
      }),
    );
  }
}
