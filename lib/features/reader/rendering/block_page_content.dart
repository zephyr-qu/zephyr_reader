import 'dart:io';

import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/rendering/highlight_painter.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_page_viewport.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub_api;
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 块分页页 Widget（Text + Image 块列表）。
Widget buildBlockPageContent({
  required BuildContext context,
  required List<PageBlockSlice> blocks,
  required int startOffset,
  required String epubFilePath,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  required void Function(Note)? onHighlightTap,
  required void Function(String text, int start, int end)? onSelectionChanged,
  required void Function(Offset?)? onSelectionGlobalPosition,
  required double maxContentWidth,
}) {
  final textStyle = config.buildTextStyle();
  final strutStyle = config.buildStrutStyle();
  final vPad = ReaderRenderConfig.pageContentVerticalPadding;
  final imageMaxWidth =
      (maxContentWidth - 2 * config.pageMargin).clamp(1.0, maxContentWidth);

  final children = <Widget>[];
  var runningOffset = startOffset;

  void appendBlock(Widget child) {
    if (children.isNotEmpty) {
      children.add(SizedBox(height: config.paragraphSpacing));
    }
    children.add(child);
  }

  for (final block in blocks) {
    block.when(
      text: (slice) {
        if (slice.text.isEmpty) return;
        final paintedSpan = HighlightPainter.paintPlain(
          slice.text,
          textStyle,
          highlights,
          onHighlightTap: onHighlightTap,
          vocabularyWords: config.effectiveVocabWords,
          contentStart: runningOffset,
        );
        appendBlock(
          SelectableText.rich(
            paintedSpan,
            strutStyle: strutStyle,
            textAlign: config.textAlign,
            textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
            onSelectionChanged: (sel, cause) => _handleBlockTextSelection(
              sel,
              slice.text,
              runningOffset,
              context,
              onSelectionChanged,
              onSelectionGlobalPosition,
            ),
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
          ),
        );
        runningOffset += slice.text.runes.length;
      },
      image: (slice) {
        final isFullPage = slice.layout == ImageBlockLayout.fullPage;
        appendBlock(
          EpubBlockImage(
            filePath: epubFilePath,
            assetId: slice.assetId,
            alt: slice.alt,
            maxWidthPx: imageMaxWidth.round().clamp(1, 4096),
            fullPage: isFullPage,
          ),
        );
        runningOffset += 1; // ADR-008: \uFFFC
      },
    );
  }

  if (children.isEmpty) {
    children.add(const SizedBox.shrink());
  }

  return RepaintBoundary(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: vPad,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bodyHeight =
              (constraints.maxHeight - 2 * vPad).clamp(0.0, constraints.maxHeight);
          return PaginatedPageViewport(
            maxHeight: bodyHeight,
            maxWidth: constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          );
        },
      ),
    ),
  );
}

void _handleBlockTextSelection(
  TextSelection sel,
  String paragraphText,
  int offset,
  BuildContext context,
  void Function(String text, int start, int end)? onSelectionChanged,
  void Function(Offset?)? onSelectionGlobalPosition,
) {
  if (!sel.isValid || sel.isCollapsed) {
    onSelectionChanged?.call('', 0, 0);
    return;
  }
  final start = sel.start;
  final end = sel.end;
  final text = paragraphText.substring(start, end);
  onSelectionChanged?.call(text, offset + start, offset + end);
  if (onSelectionGlobalPosition != null) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.attached) {
      onSelectionGlobalPosition(box.localToGlobal(Offset.zero));
    }
  }
}

/// 懒加载 EPUB 块图片：占位 → Rust 本地路径 → [Image.file]。
class EpubBlockImage extends StatefulWidget {
  const EpubBlockImage({
    super.key,
    required this.filePath,
    required this.assetId,
    required this.maxWidthPx,
    this.alt,
    this.fullPage = false,
  });

  final String filePath;
  final String assetId;
  final int maxWidthPx;
  final String? alt;
  final bool fullPage;

  @override
  State<EpubBlockImage> createState() => _EpubBlockImageState();
}

class _EpubBlockImageState extends State<EpubBlockImage> {
  String? _localPath;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EpubBlockImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.maxWidthPx != widget.maxWidthPx ||
        oldWidget.filePath != widget.filePath) {
      _localPath = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final path = await Future.microtask(
        () => epub_api.getProcessedEpubImage(
          filePath: widget.filePath,
          assetId: widget.assetId,
          maxWidthPx: widget.maxWidthPx,
        ),
      );
      if (!mounted) return;
      setState(() => _localPath = path);
    } catch (e) {
      Logging.warning('[EpubBlockImage] load failed asset=${widget.assetId}: $e');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _placeholder(
        icon: Icons.broken_image_outlined,
        label: widget.alt ?? widget.assetId,
      );
    }
    final path = _localPath;
    if (path == null || !File(path).existsSync()) {
      return _placeholder(
        icon: Icons.image_outlined,
        label: widget.alt,
      );
    }

    final maxW = widget.maxWidthPx.toDouble();
    final image = Image.file(
      File(path),
      width: maxW,
      fit: BoxFit.contain,
      semanticLabel: widget.alt,
      errorBuilder: (_, _, _) => _placeholder(
        icon: Icons.broken_image_outlined,
        label: widget.alt,
      ),
    );

    if (widget.fullPage) {
      return SizedBox(
        width: maxW,
        child: AspectRatio(aspectRatio: 3 / 4, child: image),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: image,
    );
  }

  Widget _placeholder({required IconData icon, String? label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Colors.grey),
          if (label != null && label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
