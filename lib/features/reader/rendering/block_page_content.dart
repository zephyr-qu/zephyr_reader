import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/epub_block_image_cache.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/active_chapter_ir.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/features/reader/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_page_viewport.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';


/// 块分页页 Widget（Text + Image 块列表）。
Widget buildBlockPageContent({
  required BuildContext context,
  required List<PackedBlockSlice> blocks,
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
          PaginationViewportMetrics.note(
            width: constraints.maxWidth,
            height: bodyHeight,
          );
          Logging.info(
            '[PageRender] blockPage maxH_dp=${constraints.maxHeight.toStringAsFixed(1)}'
            ' vPad=$vPad bodyHeight_dp=${bodyHeight.toStringAsFixed(1)}'
            ' blocks=${blocks.length}',
          );

          final children = <Widget>[];
          var runningOffset = startOffset;

          for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
            final block = blocks[blockIndex];
            final hasFollowing = blockIndex < blocks.length - 1;
            if (!block.isImage) {
              if (block.text.isEmpty) continue;
              final irStyle = block.style!;
              final blockFontSize = IrTextBlockStyle.effectiveFontSize(
                irStyle,
                config,
              );
              final blockStrutStyle = config.buildStrutStyle(
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
                text: block.text,
                spans: block.spans,
                irStyle: irStyle,
                config: config,
                highlights: highlights,
                contentStart: runningOffset,
                applyFirstLineIndent: block.isBlockStart,
                onHighlightTap: onHighlightTap,
              );
              final blockPadding = block.isBlockStart
                  ? IrTextBlockStyle.resolveBlockPadding(irStyle, config)
                  : EdgeInsets.zero;
              final textWidget = Padding(
                padding: blockPadding,
                child: SelectableText.rich(
                  paintedSpan,
                  strutStyle: blockStrutStyle,
                  textAlign: textAlign,
                  textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                  onSelectionChanged: (sel, cause) => _handleBlockTextSelection(
                    sel,
                    block.text,
                    runningOffset,
                    context,
                    onSelectionChanged,
                    onSelectionGlobalPosition,
                  ),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
              );
              // 段距只加在块与块之间；页末最后一块不加（对齐分页 pending flush）。
              final extraSpacing =
                  hasFollowing &&
                      block.isBlockEnd &&
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
              runningOffset += block.text.runes.length;
            } else {
              final isFullPage = block.imageLayout == ImageBlockLayout.fullPage;
              final inlineMaxH = isFullPage
                  ? null
                  : _inlineImageDisplayHeightDp(
                      assetId: block.assetId ?? '',
                      contentWidthDp: imageMaxWidth,
                    );
              children.add(
                EpubBlockImage(
                  filePath: epubFilePath,
                  assetId: block.assetId ?? '',
                  alt: block.alt,
                  maxWidthPx: imageMaxWidth.round().clamp(1, 4096),
                  maxHeightPx: isFullPage
                      ? bodyHeight.round().clamp(1, 4096)
                      : inlineMaxH?.round().clamp(1, 4096),
                  fullPage: isFullPage,
                ),
              );
              runningOffset += 1; // ADR-008: \uFFFC
            }
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

/// 内联图显示高度（不含 padding），与装箱 [imageDisplayHeightDp] 同源。
double _inlineImageDisplayHeightDp({
  required String assetId,
  required double contentWidthDp,
}) {
  final img = ActiveChapterIr.findImage(assetId);
  return imageDisplayHeightDp(
    contentWidthDp: contentWidthDp,
    intrinsicWidth: img?.intrinsicWidth,
    intrinsicHeight: img?.intrinsicHeight,
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
    final maxW = widget.maxWidthPx.toDouble();
    final maxH = widget.maxHeightPx?.toDouble();

    late final Widget content;
    if (_error != null) {
      content = _sizedPlaceholder(icon: Icons.broken_image_outlined);
    } else {
      final bytes = _imageBytes;
      if (bytes == null) {
        content = _sizedPlaceholder(icon: Icons.image_outlined);
      } else {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        content = Image.memory(
          bytes,
          width: maxW,
          height: maxH,
          fit: BoxFit.contain,
          cacheWidth: (maxW * dpr).ceil().clamp(1, 8192),
          semanticLabel: widget.alt,
          errorBuilder: (_, _, _) =>
              _sizedPlaceholder(icon: Icons.broken_image_outlined),
        );
      }
    }

    if (widget.fullPage) {
      return SizedBox(width: maxW, height: maxH, child: content);
    }
    // 与装箱 [kInlineImageVerticalPaddingDp] 对齐：占位与成图同一套 padding。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
  }

  /// 占位符：预留图片实际尺寸空间，避免加载完成后排版跳动。
  Widget _sizedPlaceholder({required IconData icon}) {
    final maxW = widget.maxWidthPx.toDouble();
    final maxH = widget.maxHeightPx?.toDouble();
    final h = maxH ?? (maxW * kDefaultImageHeightRatio);
    return SizedBox(
      width: maxW,
      height: math.min(h, 1200),
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
