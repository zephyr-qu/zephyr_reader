import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/span_factory.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/image_cache.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart'
    show BlockStyle;

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
              final blockFontSize = IrReaderIrBlock.effectiveFontSize(
                irStyle,
                config,
              );
              final blockStrutStyle = config.buildStrutStyle(
                fontSizeMultiplier: blockFontSize / config.fontSize,
                lineHeight: IrReaderIrBlock.effectiveLineHeight(
                  irStyle,
                  config,
                ),
              );
              final textAlign = IrReaderIrBlock.resolveTextAlign(
                irStyle.textAlign,
                config.textAlign,
              );
              final paintedSpan = IrReaderIrBlock.buildHighlightedSpan(
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
                  ? IrReaderIrBlock.resolveBlockPadding(irStyle, config)
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
              runningOffset += block.text.length;
            } else {
              final isFullPage =
                  block.imageLayout == ReaderIrBlockLayout.fullPage;
              final inlineMaxH = isFullPage
                  ? null
                  : _inlineImageDisplayHeightDp(
                      contentWidthDp: imageMaxWidth,
                      intrinsicWidth: block.imageIntrinsicWidth,
                      intrinsicHeight: block.imageIntrinsicHeight,
                    );
              children.add(
                EpubBlockImage(
                  filePath: epubFilePath,
                  assetId: block.assetId ?? '',
                  alt: block.imageAlt,
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

// ── Phase 4: PagePlan-based renderer ──

/// 从 [PagePlan] 渲染页面内容，使用 [SpanFactory] 代替 [IrReaderIrBlock]。
///
/// 与 [buildBlockPageContent] 并行存在，供新布局管线使用。
/// 约定 phase4: rendering path lives here; Phase 6 removes the old buildBlockPageContent.
Widget buildPagePlanContent({
  required BuildContext context,
  required PagePlan page,
  required LayoutSpec spec,
  required ReaderRenderConfig config,
  required String epubFilePath,
  required List<Note> highlights,
  required void Function(Note)? onHighlightTap,
  required void Function(String text, int start, int end)? onSelectionChanged,
  required void Function(Offset?)? onSelectionGlobalPosition,
}) {
  final vPad = ReaderRenderConfig.pageContentVerticalPadding;
  final spanFactory = SpanFactory(spec);

  return RepaintBoundary(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spec.contentPadding,
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
          final children = <Widget>[];

          for (
            var fragmentIndex = 0;
            fragmentIndex < page.fragments.length;
            fragmentIndex++
          ) {
            final fragment = page.fragments[fragmentIndex];
            final hasFollowing = fragmentIndex < page.fragments.length - 1;
            if (!fragment.isImage) {
              final text = fragment.text ?? '';
              if (text.isEmpty) continue;

              final irStyle =
                  fragment.style ??
                  const BlockStyle(isHeading: false, headingLevel: 0);
              final blockStrutStyle = spanFactory.blockStrutStyle(irStyle);
              final resolvedPadding = spanFactory.blockPadding(irStyle);
              final blockPadding = EdgeInsets.only(
                top: fragment.isBlockStart ? resolvedPadding.top : 0.0,
                bottom: fragment.isBlockEnd ? resolvedPadding.bottom : 0.0,
              );
              final paintedSpan = IrReaderIrBlock.buildHighlightedSpan(
                text: text,
                spans: fragment.spans,
                irStyle: irStyle,
                config: config,
                highlights: highlights,
                contentStart: fragment.startUtf16,
                applyFirstLineIndent: fragment.isBlockStart,
                onHighlightTap: onHighlightTap,
              );

              final textWidget = Padding(
                padding: blockPadding,
                child: SelectableText.rich(
                  paintedSpan,
                  strutStyle: blockStrutStyle,
                  textScaler: spec.textScaler,
                  textAlign: irStyle.textAlign == null
                      ? spec.textAlign
                      : IrReaderIrBlock.resolveTextAlign(
                          irStyle.textAlign,
                          spec.textAlign,
                        ),
                  textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                  onSelectionChanged: (sel, cause) => _handleBlockTextSelection(
                    sel,
                    text,
                    fragment.startUtf16,
                    context,
                    onSelectionChanged,
                    onSelectionGlobalPosition,
                  ),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
              );
              final extraSpacing =
                  hasFollowing &&
                      fragment.isBlockEnd &&
                      irStyle.marginBottomEm == null &&
                      spec.paragraphSpacing > 0
                  ? spec.paragraphSpacing
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
              final isFullPage =
                  fragment.imageLayout == ReaderIrBlockLayout.fullPage;
              final imageMaxWidth = constraints.maxWidth.clamp(
                1.0,
                constraints.maxWidth,
              );
              final displayWidth = isFullPage
                  ? imageMaxWidth
                  : (fragment.imageDisplayWidth ?? imageMaxWidth).clamp(
                      1.0,
                      imageMaxWidth,
                    );
              final displayHeight = isFullPage
                  ? bodyHeight
                  : fragment.imageDisplayHeight;
              children.add(
                EpubBlockImage(
                  filePath: epubFilePath,
                  assetId: fragment.assetId ?? '',
                  alt: fragment.imageAlt,
                  maxWidthPx: displayWidth.round(),
                  maxHeightPx: displayHeight?.round(),
                  fullPage: isFullPage,
                ),
              );
            }
          }

          if (children.isEmpty) {
            children.add(const SizedBox.shrink());
          }

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

/// 内联图显示高度（不含 padding），与装箱 [imageDisplayHeightDp] 同源。
double _inlineImageDisplayHeightDp({
  required double contentWidthDp,
  int? intrinsicWidth,
  int? intrinsicHeight,
}) {
  return imageDisplayHeightDp(
    contentWidthDp: contentWidthDp,
    intrinsicWidth: intrinsicWidth,
    intrinsicHeight: intrinsicHeight,
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
  int _loadGeneration = 0;

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
    final generation = ++_loadGeneration;
    try {
      final bytes = await epubBlockImageCache.load(
        filePath: widget.filePath,
        assetId: widget.assetId,
        maxWidthPx: widget.maxWidthPx,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _imageBytes = bytes);
    } catch (e) {
      Logging.warning(
        '[EpubBlockImage] load failed asset=${widget.assetId}: $e',
      );
      if (!mounted || generation != _loadGeneration) return;
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

/// 分页单页视口：固定高度，由 Flutter 分页保证不溢出。
class PaginatedPageViewport extends StatelessWidget {
  const PaginatedPageViewport({
    super.key,
    required this.maxHeight,
    required this.maxWidth,
    required this.child,
  });

  final double maxHeight;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Logging.info(
      '[PageViewport] maxH_dp=\${maxHeight.toStringAsFixed(1)}'
      ' maxW_dp=\${maxWidth.toStringAsFixed(1)}',
    );
    return SizedBox(
      height: maxHeight,
      width: maxWidth,
      child: ClipRect(
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    );
  }
}
