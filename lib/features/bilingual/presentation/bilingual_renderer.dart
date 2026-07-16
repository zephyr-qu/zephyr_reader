import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/highlight_painter.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';

import 'package:zephyr_reader/core/utils/find_render_box.dart';
import 'package:zephyr_reader/src/rust/domain/bilingual/models.dart';
import 'package:zephyr_reader/src/rust/domain/note/models.dart';

/// 双语对照模式渲染器。
///
/// 并排显示中英文对照内容，支持高亮配对显示。
class BilingualModeRenderer extends StatelessWidget {
  final ReaderRenderConfig config;
  final ScrollController scrollController;
  final List<BilingualHighlightPair> bilingualPairs;
  final bool isBilingualLoading;
  final String? bilingualError;
  final BilingualAlignment? bilingualAlignment;
  final List<Note> highlights;
  final VoidCallback? onRequestTranslation;
  final void Function(Note)? onHighlightTap;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final VoidCallback? onRetryTranslation;
  final void Function(Offset?)? onSelectionGlobalPosition;

  const BilingualModeRenderer({
    super.key,
    required this.config,
    required this.scrollController,
    required this.bilingualPairs,
    required this.isBilingualLoading,
    this.bilingualError,
    required this.bilingualAlignment,
    required this.highlights,
    this.onRequestTranslation,
    this.onHighlightTap,
    this.onSelectionChanged,
    this.onRetryTranslation,
    this.onSelectionGlobalPosition,
  });

  void _reportSelectionPosition(BuildContext context, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionGlobalPosition?.call(null);
      return;
    }
    final box = findRenderBox(context);
    if (box == null || !box.hasSize || !box.attached) return;
    onSelectionGlobalPosition?.call(box.localToGlobal(Offset.zero));
  }

  void _onSelection(
    TextSelection sel,
    String paragraphText,
    int offset,
    BuildContext context,
  ) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionChanged?.call('', 0, 0);
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final text = paragraphText.substring(start, end);
    onSelectionChanged?.call(text, offset + start, offset + end);
    _reportSelectionPosition(context, sel);
  }

  @override
  Widget build(BuildContext context) {
    if (isBilingualLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bilingualError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              bilingualError!,
              style: TextStyle(fontSize: 16, color: config.textColor),
            ),
            const SizedBox(height: 20),
            if (onRetryTranslation != null)
              OutlinedButton.icon(
                onPressed: onRetryTranslation,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                label: Text(AppLocalizations.of(context)!.translationRetry),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRequestTranslation,
              icon: const Icon(PhosphorIconsRegular.pencil),
              label: Text(AppLocalizations.of(context)!.translationManualPaste),
            ),
          ],
        ),
      );
    }
    final alignment = bilingualAlignment;
    if (alignment == null || alignment.segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '无对照译文',
              style: TextStyle(fontSize: 16, color: config.textColor),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRequestTranslation,
              icon: const Icon(PhosphorIconsRegular.plus),
              label: const Text('设置译文'),
            ),
          ],
        ),
      );
    }

    // BilingualHighlightPair 现只含 noteId 和文本（无完整 Note 对象），
    // 双语高亮渲染需配合 annotationsService 按 noteId 查询 Note 后实现（待完善）。
    final cnHighlights = highlights
        .where((h) => h.language == null || h.language == 'zh')
        .toList();
    final enHighlights = highlights.where((h) => h.language == 'en').toList();

    final chineseStyle = config.buildTextStyle();
    final chineseStrut = config.buildStrutStyle();
    final englishStyle = config.buildTextStyle(
      color: config.textColor.withAlpha(180),
      useLatin: true,
      fontSizeMultiplier: 0.9,
    );
    final englishStrut = config.buildStrutStyle(
      useLatin: true,
      fontSizeMultiplier: 0.9,
    );
    // 双语中文段首行缩进：与单语 scroll 模式行为一致
    final cnIndentPx = config.firstLineIndent
        ? IrReaderIrBlock.defaultFirstLineIndentEm * config.fontSize
        : 0.0;

    final cnOffsets = <int>[];
    var acc = 0;
    for (final seg in alignment.segments) {
      cnOffsets.add(acc);
      acc += seg.chinese.length;
    }
    final enOffsets = <int>[];
    acc = 0;
    for (final seg in alignment.segments) {
      enOffsets.add(acc);
      acc += seg.english.length;
    }

    final listView = ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
      scrollDirection: Axis.vertical,
      itemCount: alignment.segments.length,
      itemBuilder: (context, index) {
        final seg = alignment.segments[index];
        final cnOff = cnOffsets[index];
        final enOff = enOffsets[index];

        final cnSegHighlights = cnHighlights
            .where((h) {
              final hStart = h.charOffset.toInt();
              final hEnd = hStart + h.length.toInt();
              return hEnd > cnOff && hStart < cnOff + seg.chinese.length;
            })
            .map((h) => h.copyWith(charOffset: h.charOffset - cnOff))
            .toList();

        final cnSpan = HighlightPainter.paintPlain(
          seg.chinese,
          chineseStyle,
          cnSegHighlights,
          onHighlightTap: onHighlightTap,
          vocabularyWords: config.effectiveVocabWords,
        );

        // 双语中文段：与 IrReaderIrBlock 同方案的首行缩进
        final cnIndentedSpan = cnIndentPx > 0
            ? TextSpan(
                style: chineseStyle,
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: SizedBox(width: cnIndentPx),
                  ),
                  cnSpan,
                ],
              )
            : cnSpan;

        final enSegHighlights = enHighlights
            .where((h) {
              final hStart = h.charOffset.toInt();
              final hEnd = hStart + h.length.toInt();
              return hEnd > enOff && hStart < enOff + seg.english.length;
            })
            .map((h) => h.copyWith(charOffset: h.charOffset - enOff))
            .toList();

        final enSpan = HighlightPainter.paintPlain(
          seg.english,
          englishStyle,
          enSegHighlights,
          onHighlightTap: onHighlightTap,
          vocabularyWords: config.effectiveVocabWords,
        );

        final segmentWidget = RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < alignment.segments.length - 1
                  ? config.paragraphSpacing
                  : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText.rich(
                  cnIndentedSpan,
                  strutStyle: chineseStrut,
                  textAlign: config.textAlign,
                  textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                  onSelectionChanged: (sel, cause) =>
                      _onSelection(sel, seg.chinese, cnOff, context),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: config.textColor.withAlpha(40),
                ),
                const SizedBox(height: 4),
                SelectableText.rich(
                  enSpan,
                  strutStyle: englishStrut,
                  textAlign: config.textAlign,
                  textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                  onSelectionChanged: (sel, cause) =>
                      _onSelection(sel, seg.english, enOff, context),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );

        return segmentWidget;
      },
    );

    return listView;
  }
}
