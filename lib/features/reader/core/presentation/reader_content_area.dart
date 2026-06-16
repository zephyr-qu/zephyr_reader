import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/annotations/presentation/reader_annotation_dialog.dart';
import 'package:zephyr_reader/features/reader/annotations/presentation/reader_highlight_sheet.dart';
import 'package:zephyr_reader/features/reader/rendering/bilingual_renderer.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_renderer.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/rendering/scroll_mode_renderer.dart';
import 'package:zephyr_reader/features/reader/page/ui/battery_indicator.dart';
import 'package:zephyr_reader/features/reader/page/ui/brightness_mask.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_content.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_translation_dialog.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReaderContentArea extends HookWidget {
  const ReaderContentArea({
    super.key,
    required this.vm,
    required this.dataSource,
    required this.fontRepo,
    required this.vocabWords,
    required this.selectionGlobalPos,
    required this.themeMode,
  });

  final ReaderViewModel vm;
  final ReaderRenderDataSource dataSource;
  final FontRepository fontRepo;
  final Signal<Set<String>> vocabWords;
  final Signal<Offset?> selectionGlobalPos;
  final ThemeMode themeMode;

  static const _brightnessPresets = [0.0, 0.3, 0.5, 0.7];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int bBgindex = useSignalValue(vm.config.readerBgColorIndex.signal);
    final double bBrightness = useSignalValue(vm.config.brightnessOverlay);
    final String bCurrentbookid = useSignalValue(vm.state.bookId);
    final int bChapterindex = useSignalValue(vm.state.chapterIndex);
    final int bPageindex = useSignalValue(vm.chapterManager.pageIndex);
    final int bTotalpages = useSignalValue(vm.chapterManager.totalPages);
    final ReadingMode bCurrentreadingmode = useSignalValue(
      vm.state.readingMode,
    );
    final double bFontsize = useSignalValue(vm.config.fontSize.signal);
    final double bLineheight = useSignalValue(vm.config.lineHeight.signal);
    final AsyncState<String> chContent = useSignalValue(
      vm.state.chapterContent,
    );
    final String bContent = chContent.value ?? '';
    final bool bIsloading = useSignalValue(vm.chapterManager.isLoading);
    final String? bError = useSignalValue(vm.chapterManager.error);
    final AsyncState<BilingualAlignment?> bState = useSignalValue(
      vm.translation.bilingualAlignment,
    );
    final BilingualAlignment? bBilingualalign = bState.value;
    final bool bIsbilingualloading = bState.isLoading;
    final int bAutoscrolltick = useSignalValue(
      vm.chapterManager.autoScrollTick,
    );
    final AsyncState<List<Note>> highlightsState = useSignalValue(
      vm.annotations.highlights,
    );
    final List<Note> bHighlights = highlightsState.value ?? [];
    final double bLetterspacing = useSignalValue(
      vm.config.letterSpacing.signal,
    );
    final double bParagraphspacing = useSignalValue(
      vm.config.paragraphSpacing.signal,
    );
    final double bPagemargin = useSignalValue(vm.config.padding.signal);
    final WritingDirection bWritingdirection = useSignalValue(
      vm.config.writingDirection,
    );
    final int? bPendingjumpcharoffset = useSignalValue(
      vm.state.pendingJumpCharOffset,
    );
    final String bProgresstext = useSignalValue(
      vm.chapterManager.progressText,
    );
    final bool bBaselinealign = useSignalValue(vm.config.baselineAlign.signal);
    final TextAlign bTextalign = useSignalValue(vm.config.textAlign.signal);
    final AsyncState<List<Chapter>> chaptersState = useSignalValue(
      vm.chapterManager.chapters,
    );
    final int bNumchapters = (chaptersState.value as List?)?.length ?? 0;
    final vocabWordSet = useSignalValue<Set<String>, Signal<Set<String>>>(
      vocabWords,
    );
    final fontFamily = fontRepo.currentFontFamily;

    void cycleBrightness() {
      final current = vm.config.brightnessOverlay.value;
      final idx = _brightnessPresets.indexWhere(
        (p) => (p - current).abs() < 0.05,
      );
      final nextIdx = idx == -1 ? 0 : (idx + 1) % _brightnessPresets.length;
      vm.config.brightnessOverlay.value = _brightnessPresets[nextIdx];
    }

    final textScaler = vm.config.followSystemFontScale.value
        ? MediaQuery.textScalerOf(context)
        : TextScaler.noScaling;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Builder(
            builder: (context) {
              final renderConfig = ReaderRenderConfig(
                textColor: ReaderContent.getTextColor(themeMode),
                backgroundColor: ReaderContent.getBackgroundColor(
                  themeMode,
                  bBgindex,
                ),
                fontSize: bFontsize,
                lineHeight: bLineheight,
                fontFamily: fontFamily,
                letterSpacing: bLetterspacing,
                paragraphSpacing: bParagraphspacing,
                pageMargin: bPagemargin,
                showVocabularyMark: true,
                vocabularyWords: vocabWordSet,
                baselineAlign: bBaselinealign,
                textAlign: bTextalign,
              );
              Future<void> onHighlightTap(Note note) =>
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ReaderHighlightSheet(
                      note: note,
                      onEdit: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => ReaderAnnotationDialog(
                            selectedText: note.selectedText ?? '',
                            initialContent: note.content,
                            onSave: (text) {
                              final updated = note.copyWith(
                                content: text,
                                updatedAt: DateTime.now(),
                              );
                              vm.updateNote(updated, l10n);
                            },
                          ),
                        );
                      },
                      onDelete: () => vm.deleteNote(note.id, l10n),
                    ),
                  );
              return ReaderContent(
                dataSource: dataSource,
                bookId: bCurrentbookid,
                chapterId: bChapterindex,
                pageIndex: bPageindex,
                totalPages: bTotalpages,
                renderConfig: renderConfig,
                readingMode: bCurrentreadingmode,
                content: bContent,
                isLoading: bIsloading,
                error: bError,
                hasNextChapter: bChapterindex < bNumchapters - 1,
                scrollBuilder: (_, sc) => ScrollModeRenderer(
                  config: renderConfig,
                  scrollController: sc,
                  dataSource: dataSource,
                  bookId: bCurrentbookid,
                  chapterId: bChapterindex,
                  content: bContent,
                  highlights: bHighlights,
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) =>
                      selectionGlobalPos.value = pos,
                  writingDirection: bWritingdirection,
                  showSentenceSplit: true,
                ),
                bilingualBuilder: (_, sc, pairs) => BilingualModeRenderer(
                  config: renderConfig,
                  scrollController: sc,
                  bilingualPairs: pairs,
                  isBilingualLoading: bIsbilingualloading,
                  bilingualAlignment: bBilingualalign,
                  highlights: bHighlights,
                  onRequestTranslation: () => showDialog<void>(
                    context: context,
                    builder: (_) => ReaderTranslationDialog(
                      onChanged: vm.translation.setTranslationContent,
                      translationConfigured: vm.translation.isConfigured,
                      onTranslateWithApi: () {
                        Navigator.of(context).pop();
                        unawaited(vm.translation.translateChapter());
                      },
                    ),
                  ),
                  onRetryTranslation: () =>
                      unawaited(vm.translation.translateChapter()),
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) =>
                      selectionGlobalPos.value = pos,
                  writingDirection: bWritingdirection,
                ),
                paginatedBuilder: (_, pc) => PaginatedModeRenderer(
                  config: renderConfig,
                  pageController: pc,
                  dataSource: dataSource,
                  bookId: bCurrentbookid,
                  chapterId: bChapterindex,
                  pageIndex: bPageindex,
                  content: bContent,
                  highlights: bHighlights,
                  readingMode: bCurrentreadingmode,
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) =>
                      selectionGlobalPos.value = pos,
                  onPageChanged: vm.loadPage,
                  onPositionChanged: vm.chapterManager.updateCurrentCharOffset,
                  writingDirection: bWritingdirection,
                ),
                onPageChanged: vm.loadPage,
                onRetry: () => vm.loadChapter(
                  bChapterindex,
                  initialCharOffset: vm.state.currentCharOffset.value,
                  restartSession: false,
                ),
                autoScrollTick: bAutoscrolltick,
                highlights: bHighlights,
                onSelectionChanged: vm.annotations.updateSelection,
                onSelectionGlobalPosition: (pos) =>
                    selectionGlobalPos.value = pos,
                writingDirection: bWritingdirection,
                jumpToCharOffset: bPendingjumpcharoffset,
                onPositionChanged: vm.chapterManager.updateCurrentCharOffset,
                onJumpHandled: vm.chapterManager.consumePendingJumpOffset,
                onReachEnd: () => unawaited(vm.chapterManager.nextChapter()),
              );
            },
          ),
        ),
        BrightnessMask(
          brightness: bBrightness,
          readingMode: bCurrentreadingmode,
          onDoubleTap: cycleBrightness,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: BatteryIndicator(progressText: bProgresstext),
        ),
      ],
    );
  }
}
