import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/core/data/epub_block_image_cache.dart';
import 'package:zephyr_reader/features/reader/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_page_viewport.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
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
  final vPad = ReaderRenderConfig.pageContentVerticalPadding;
  final imageMaxWidth = (maxContentWidth - 2 * config.pageMargin).clamp(
    1.0,
    maxContentWidth,
  );

  return RepaintBoundary(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: vPad,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bodyHeight = constraints.maxHeight.clamp(
            0.0,
            constraints.maxHeight,
          );
          Logging.info(
            '[PageRender] blockPage maxH_dp=${constraints.maxHeight.toStringAsFixed(1)}'
            ' vPad=$vPad bodyHeight_dp=${bodyHeight.toStringAsFixed(1)}'
            ' blocks=${blocks.length}',
          );

          // Diagnostic: measure Flutter actual CJK char width vs Rust estimate
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final tp = TextPainter(
            text: TextSpan(text: '中', style: config.buildTextStyle()),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          final flutCjkDp = tp.width;
          final flutCjkPx = flutCjkDp * dpr;
          final pageWidthPx = (constraints.maxWidth * dpr).round();
          final fontSizePx = (config.fontSize * dpr).round();
          final rustCjkPx = flutCjkPx * kRustCharWidthScale;
          final rustEstCharsPerLine = estimateRustCharsPerLine(
            cjkWidthPx: rustCjkPx,
            pageWidthPx: pageWidthPx,
            fontSizePx: fontSizePx,
          );

          Logging.info(
            '[LineWidth] flutCjk=${flutCjkDp.toStringAsFixed(1)}dp'
            ' ${flutCjkPx.toStringAsFixed(0)}px rustCjk=${rustCjkPx.toStringAsFixed(0)}px'
            ' fontSize=${config.fontSize}dp'
            ' lineH=${config.lineHeight}'
            ' pageW_px=$pageWidthPx'
            ' rustScale=$kRustCharWidthScale'
            ' safety=$kRustLineWidthSafetyRatio'
            ' estCharsPerLine=${rustEstCharsPerLine.toStringAsFixed(1)}'
            ' viewportW=${constraints.maxWidth.toStringAsFixed(1)}dp',
          );

          // Diagnostic: accumulate total Flutter lines & height across ALL text blocks
          var totalChars = 0;
          var totalFlutterLines = 0;
          var totalRustLines = 0;
          var totalTpHeight = 0.0;
          for (final block in blocks) {
            final slice = block.whenOrNull(text: (s) => s);
            if (slice != null && slice.text.isNotEmpty) {
              final irStyle = slice.style;
              final blockFontSize = IrTextBlockStyle.effectiveFontSize(
                irStyle,
                config,
              );
              final blockLineHeight = IrTextBlockStyle.effectiveLineHeight(
                irStyle,
                config,
              );
              final textStyle = config.buildTextStyle(
                fontFamily: irStyle.fontFamily,
                fontSizeMultiplier: blockFontSize / config.fontSize,
              ).copyWith(height: blockLineHeight);
              final indentPx = slice.isBlockStart
                  ? IrTextBlockStyle.resolveFirstLineIndentPx(irStyle, config)
                  : 0.0;
              final blockPadding = slice.isBlockStart
                  ? IrTextBlockStyle.resolveBlockPadding(irStyle, config)
                  : EdgeInsets.zero;
              final layoutMaxWidth = (constraints.maxWidth - blockPadding.horizontal)
                  .clamp(1.0, constraints.maxWidth);
              final strutStyle = config.buildStrutStyle(
                fontFamily: irStyle.fontFamily,
                fontSizeMultiplier: blockFontSize / config.fontSize,
                lineHeight: blockLineHeight,
              );
              final measured = _measureSliceLayout(
                text: slice.text,
                style: textStyle,
                strutStyle: strutStyle,
                maxWidth: layoutMaxWidth,
                firstLineIndentPx: slice.isBlockStart ? indentPx : 0.0,
              );
              totalChars += slice.text.length;
              totalFlutterLines += measured.lines;
              totalRustLines += estimateRustLinesForText(
                text: slice.text,
                applyFirstLineIndent: slice.isBlockStart,
                cjkWidthPx: rustCjkPx,
                pageWidthPx: pageWidthPx,
                fontSizePx: fontSizePx,
              );
              totalTpHeight +=
                  measured.height + blockPadding.vertical + (slice.isBlockEnd &&
                          irStyle.marginBottomEm == null &&
                          config.paragraphSpacing > 0
                      ? config.paragraphSpacing
                      : 0.0);
            }
          }
          final overflowDp = (totalTpHeight - bodyHeight).clamp(0.0, double.infinity);
          Logging.info(
            '[LineBreak] TOTAL chars=$totalChars'
            ' flutLines=$totalFlutterLines rustEstLines=$totalRustLines'
            ' tpHeight=${totalTpHeight.toStringAsFixed(1)}dp'
            ' overflow=${overflowDp.toStringAsFixed(1)}dp'
            ' charsPerLine=${rustEstCharsPerLine.toStringAsFixed(1)}'
            ' rustScale=$kRustCharWidthScale'
            ' lineH_dp=${config.textRowHeight.toStringAsFixed(1)}'
            ' blocks=${blocks.length}',
          );

          final children = <Widget>[];
          var runningOffset = startOffset;

          for (final block in blocks) {
            block.when(
              text: (slice) {
                if (slice.text.isEmpty) return;
                final irStyle = slice.style;
                final blockFontSize = IrTextBlockStyle.effectiveFontSize(
                  irStyle,
                  config,
                );
                final blockStrutStyle = config.buildStrutStyle(
                  fontFamily: irStyle.fontFamily,
                  fontSizeMultiplier: blockFontSize / config.fontSize,
                  lineHeight: IrTextBlockStyle.effectiveLineHeight(
                    irStyle,
                    config,
                  ),
                );
                final textAlign = IrTextBlockStyle.resolveTextAlign(
                  irStyle.textAlign,
                  config.textAlign,
                );
                final paintedSpan = IrTextBlockStyle.buildHighlightedSpan(
                  text: slice.text,
                  spans: slice.spans,
                  irStyle: irStyle,
                  config: config,
                  highlights: highlights,
                  contentStart: runningOffset,
                  applyFirstLineIndent: slice.isBlockStart,
                  onHighlightTap: onHighlightTap,
                );
                final blockPadding = slice.isBlockStart
                    ? IrTextBlockStyle.resolveBlockPadding(irStyle, config)
                    : EdgeInsets.zero;
                final textWidget = Padding(
                  padding: blockPadding,
                  child: SelectableText.rich(
                    paintedSpan,
                    strutStyle: blockStrutStyle,
                    textAlign: textAlign,
                    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                    onSelectionChanged: (sel, cause) =>
                        _handleBlockTextSelection(
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
                if (slice.isBlockEnd) {
                  // 段落间距：marginBottomEm 由 blockPadding.bottom 处理，
                  // 此处仅对无显式 margin 的块补 paragraphSpacing
                  final extraSpacing =
                      irStyle.marginBottomEm == null &&
                          config.paragraphSpacing > 0
                      ? config.paragraphSpacing
                      : 0.0;
                  if (extraSpacing > 0) {
                    children.add(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          textWidget,
                          SizedBox(height: extraSpacing),
                        ],
                      ),
                    );
                  } else {
                    children.add(textWidget);
                  }
                } else {
                  children.add(textWidget);
                }
                runningOffset += slice.text.runes.length;
              },
              image: (slice) {
                final isFullPage = slice.layout == ImageBlockLayout.fullPage;
                children.add(
                  EpubBlockImage(
                    filePath: epubFilePath,
                    assetId: slice.assetId,
                    alt: slice.alt,
                    maxWidthPx: imageMaxWidth.round().clamp(1, 4096),
                    maxHeightPx: isFullPage
                        ? bodyHeight.round().clamp(1, 4096)
                        : null,
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

          return PaginatedPageViewport(
            maxHeight: bodyHeight,
            maxWidth: constraints.maxWidth,
            child: _ContentMeasurer(
              label:
                  'blocks=${blocks.length} vp=${bodyHeight.toStringAsFixed(1)}dp',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
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

/// 懒加载 EPUB 块图片：占位 → 缓存/Rust 解码字节 → [Image.memory]。
class EpubBlockImage extends StatefulWidget {
  const EpubBlockImage({
    super.key,
    required this.filePath,
    required this.assetId,
    required this.maxWidthPx,
    this.maxHeightPx,
    this.alt,
    this.fullPage = false,
  });

  final String filePath;
  final String assetId;
  final int maxWidthPx;
  final int? maxHeightPx;
  final String? alt;
  final bool fullPage;

  @override
  State<EpubBlockImage> createState() => _EpubBlockImageState();
}

class _EpubBlockImageState extends State<EpubBlockImage> {
  Uint8List? _imageBytes;
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
      _imageBytes = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await epubBlockImageCache.load(
        filePath: widget.filePath,
        assetId: widget.assetId,
        maxWidthPx: widget.maxWidthPx,
      );
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (e) {
      Logging.warning(
        '[EpubBlockImage] load failed asset=${widget.assetId}: $e',
      );
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _sizedPlaceholder(icon: Icons.broken_image_outlined);
    }
    final bytes = _imageBytes;
    if (bytes == null) {
      return _sizedPlaceholder(icon: Icons.image_outlined);
    }

    final maxW = widget.maxWidthPx.toDouble();
    final maxH = widget.maxHeightPx?.toDouble();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = Image.memory(
      bytes,
      width: maxW,
      height: maxH,
      fit: BoxFit.contain,
      cacheWidth: (maxW * dpr).ceil().clamp(1, 8192),
      semanticLabel: widget.alt,
      errorBuilder: (_, _, _) =>
          _sizedPlaceholder(icon: Icons.broken_image_outlined),
    );

    if (widget.fullPage) {
      return SizedBox(width: maxW, height: maxH, child: image);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: image,
    );
  }

  /// 占位符：预留图片实际尺寸空间，避免加载完成后排版跳动。
  Widget _sizedPlaceholder({required IconData icon}) {
    final maxW = widget.maxWidthPx.toDouble();
    final maxH = widget.maxHeightPx?.toDouble();
    if (maxH != null) {
      return SizedBox(
        width: maxW,
        height: math.min(maxH, 1200),
        child: Center(child: Icon(icon, size: 28, color: Colors.grey)),
      );
    }
    // 内联图片无固定高度：按 16:9 估算占位
    return SizedBox(
      width: maxW,
      height: maxW * 9 / 16,
      child: Center(child: Icon(icon, size: 28, color: Colors.grey)),
    );
  }
}

/// 测量 child 的实际渲染高度，用于诊断分页估算偏差。
class _ContentMeasurer extends StatefulWidget {
  final Widget child;
  final String label;
  const _ContentMeasurer({required this.child, required this.label});

  @override
  State<_ContentMeasurer> createState() => _ContentMeasurerState();
}

class _ContentMeasurerState extends State<_ContentMeasurer> {
  bool _measured = false;

  @override
  Widget build(BuildContext context) {
    if (!_measured) {
      _measured = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final h = box.size.height;
          final w = box.size.width;
          Logging.info(
            '[ContentHeight] ${widget.label} actualH=${h.toStringAsFixed(1)}dp'
            ' actualW=${w.toStringAsFixed(1)}dp'
            ' (constrained; see [LineBreak] overflow for intrinsic)',
          );
        }
      });
    }
    return widget.child;
  }
}

/// TextPainter 不支持 WidgetSpan；用首行缩进宽度模拟与渲染一致的行数/高度。
({int lines, double height}) _measureSliceLayout({
  required String text,
  required TextStyle style,
  required StrutStyle strutStyle,
  required double maxWidth,
  required double firstLineIndentPx,
}) {
  if (text.isEmpty) {
    return (lines: 0, height: 0.0);
  }

  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  );

  if (firstLineIndentPx <= 0) {
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: maxWidth);
    return (lines: tp.computeLineMetrics().length, height: tp.height);
  }

  final narrowWidth = (maxWidth - firstLineIndentPx).clamp(1.0, maxWidth);
  var firstLineChars = text.length;
  for (var n = 1; n <= text.length; n++) {
    tp.text = TextSpan(text: text.substring(0, n), style: style);
    tp.layout(maxWidth: narrowWidth);
    if (tp.computeLineMetrics().length > 1) {
      firstLineChars = n - 1;
      break;
    }
  }
  if (firstLineChars <= 0) {
    firstLineChars = 1;
  }

  if (firstLineChars >= text.length) {
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: narrowWidth);
    return (lines: tp.computeLineMetrics().length, height: tp.height);
  }

  tp.text = TextSpan(text: text.substring(0, firstLineChars), style: style);
  tp.layout(maxWidth: narrowWidth);
  final firstHeight = tp.height;

  final remainder = text.substring(firstLineChars);
  tp.text = TextSpan(text: remainder, style: style);
  tp.layout(maxWidth: maxWidth);
  return (
    lines: 1 + tp.computeLineMetrics().length,
    height: firstHeight + tp.height,
  );
}
