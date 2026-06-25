import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 滚动 ListView 每项的 charOffset / 长度 / 估算高度（与 [ScrollModeRenderer] 一致）。
class ScrollListMetrics {
  const ScrollListMetrics({
    required this.itemCount,
    required this.charOffsets,
    required this.charLengths,
    this.itemExtents = const [],
  });

  final int itemCount;
  final List<int> charOffsets;
  final List<int> charLengths;

  /// 每项 scroll extent（含段间距；最后一项不含 trailing spacing）。
  final List<double> itemExtents;

  bool get hasItemExtents =>
      itemExtents.isNotEmpty && itemExtents.length == itemCount;

  static const empty = ScrollListMetrics(
    itemCount: 0,
    charOffsets: [],
    charLengths: [],
  );

  int charOffsetAt(int index) {
    if (index < 0 || index >= itemCount) return 0;
    return charOffsets[index];
  }

  int charLengthAt(int index) {
    if (index < 0 || index >= itemCount) return 0;
    return charLengths[index];
  }

  /// 段内 charOffset → ListView 项下标。
  int itemIndexForCharOffset(int charOffset) {
    if (itemCount == 0) return 0;
    for (var i = itemCount - 1; i >= 0; i--) {
      if (charOffset >= charOffsets[i]) return i;
    }
    return 0;
  }

  double itemExtentAt(int index, {required double uniformFallback}) {
    if (hasItemExtents && index >= 0 && index < itemExtents.length) {
      return itemExtents[index];
    }
    return uniformFallback;
  }

  double scrollOffsetForLocalItem(
    int index, {
    double inItemRatio = 0,
    required double uniformFallback,
  }) {
    var offset = 0.0;
    for (var i = 0; i < index && i < itemCount; i++) {
      offset += itemExtentAt(i, uniformFallback: uniformFallback);
    }
    if (index >= 0 && index < itemCount && inItemRatio > 0) {
      offset += itemExtentAt(index, uniformFallback: uniformFallback) *
          inItemRatio.clamp(0.0, 1.0);
    }
    return offset;
  }

  double totalScrollExtent({required double uniformFallback}) {
    if (itemCount == 0) return 0;
    if (hasItemExtents) {
      return itemExtents.fold(0.0, (sum, ext) => sum + ext);
    }
    return itemCount * uniformFallback;
  }
}

/// 计算与滚动渲染一致的 ListView 项度量。
ScrollListMetrics computeScrollListMetrics({
  required List<String> paragraphs,
  required List<int> paragraphCharOffsets,
  List<RichParagraph>? richParagraphs,
  TextSpan? richRootSpan,
  ScrollLayoutParams? layout,
}) {
  if (richParagraphs == null || richParagraphs.isEmpty) {
    final lengths = paragraphs.map((p) => p.length).toList();
    return ScrollListMetrics(
      itemCount: paragraphs.length,
      charOffsets: List<int>.from(paragraphCharOffsets),
      charLengths: lengths,
      itemExtents: layout == null
          ? const []
          : _plainTextExtents(lengths, layout),
    );
  }

  final hasImages = richParagraphs.any((p) => p.isImage);
  if (!hasImages) {
    final spans = richRootSpan != null
        ? extractParagraphSpans(richRootSpan)
        : <TextSpan>[];
    final offsets = <int>[];
    final lengths = <int>[];
    var acc = 0;
    for (final span in spans) {
      offsets.add(acc);
      final len = spanTextLength(span);
      lengths.add(len);
      acc += len + 2;
    }
    return ScrollListMetrics(
      itemCount: spans.length,
      charOffsets: offsets,
      charLengths: lengths,
      itemExtents: layout == null
          ? const []
          : _richTextExtents(spans, layout),
    );
  }

  final textParagraphs = richRootSpan != null
      ? extractParagraphSpans(richRootSpan)
      : <TextSpan>[];
  final textParaOffsets = <int>[];
  var accOffset = 0;
  for (final p in textParagraphs) {
    textParaOffsets.add(accOffset);
    accOffset += spanTextLength(p) + 2;
  }

  var textIdx = 0;
  final offsets = <int>[];
  final lengths = <int>[];
  final kinds = <_ScrollItemKind>[];
  final imageData = <Uint8List?>[];
  final textSpans = <TextSpan?>[];

  for (final rp in richParagraphs) {
    if (rp.isImage) {
      final imgOffset = textIdx < textParaOffsets.length
          ? textParaOffsets[textIdx]
          : accOffset;
      offsets.add(imgOffset);
      lengths.add(1);
      kinds.add(_ScrollItemKind.image);
      imageData.add(rp.imageData);
      textSpans.add(null);
      continue;
    }
    if (textIdx >= textParagraphs.length) {
      if (textIdx >= paragraphs.length) continue;
      offsets.add(paragraphCharOffsets[textIdx]);
      lengths.add(paragraphs[textIdx].length);
      kinds.add(_ScrollItemKind.text);
      imageData.add(null);
      textSpans.add(null);
      textIdx++;
      continue;
    }
    offsets.add(textParaOffsets[textIdx]);
    lengths.add(spanTextLength(textParagraphs[textIdx]));
    kinds.add(_ScrollItemKind.text);
    imageData.add(null);
    textSpans.add(textParagraphs[textIdx]);
    textIdx++;
  }

  return ScrollListMetrics(
    itemCount: offsets.length,
    charOffsets: offsets,
    charLengths: lengths,
    itemExtents: layout == null
        ? const []
        : _mixedRichExtents(
            kinds: kinds,
            charLengths: lengths,
            imageData: imageData,
            layout: layout,
          ),
  );
}

/// IR 块流 ListView 度量（每 [ContentBlock] 一项；图片高度用占位估算）。
ScrollListMetrics computeScrollIrListMetrics({
  required List<ContentBlock> blocks,
  ScrollLayoutParams? layout,
}) {
  final offsets = <int>[];
  final lengths = <int>[];
  for (final block in blocks) {
    block.when(
      text: (tb) {
        offsets.add(tb.plain.plainStart);
        lengths.add(tb.plain.plainLen);
      },
      image: (ib) {
        offsets.add(ib.plain.plainStart);
        lengths.add(1);
      },
    );
  }
  return ScrollListMetrics(
    itemCount: offsets.length,
    charOffsets: offsets,
    charLengths: lengths,
    itemExtents: layout == null
        ? const []
        : _irBlockExtents(blocks, layout),
  );
}

List<double> _irBlockExtents(List<ContentBlock> blocks, ScrollLayoutParams layout) {
  final extents = <double>[];
  for (var i = 0; i < blocks.length; i++) {
    final includeBottomSpacing = i < blocks.length - 1;
    extents.add(
      blocks[i].when(
        text: (tb) => _textItemExtent(
          tb.plain.plainLen,
          layout,
          includeBottomSpacing: includeBottomSpacing,
        ),
        image: (_) => _imageItemExtent(
          Uint8List(0),
          layout,
          includeBottomSpacing: includeBottomSpacing,
        ),
      ),
    );
  }
  return extents;
}

enum _ScrollItemKind { text, image }

List<double> _plainTextExtents(List<int> charLengths, ScrollLayoutParams layout) {
  final extents = <double>[];
  for (var i = 0; i < charLengths.length; i++) {
    extents.add(
      _textItemExtent(
        charLengths[i],
        layout,
        includeBottomSpacing: i < charLengths.length - 1,
      ),
    );
  }
  return extents;
}

List<double> _richTextExtents(List<TextSpan> spans, ScrollLayoutParams layout) {
  final extents = <double>[];
  for (var i = 0; i < spans.length; i++) {
    extents.add(
      _textItemExtent(
        spanTextLength(spans[i]),
        layout,
        includeBottomSpacing: i < spans.length - 1,
      ),
    );
  }
  return extents;
}

List<double> _mixedRichExtents({
  required List<_ScrollItemKind> kinds,
  required List<int> charLengths,
  required List<Uint8List?> imageData,
  required ScrollLayoutParams layout,
}) {
  final extents = <double>[];
  for (var i = 0; i < kinds.length; i++) {
    final includeBottomSpacing = i < kinds.length - 1;
    extents.add(
      switch (kinds[i]) {
        _ScrollItemKind.text => _textItemExtent(
            charLengths[i],
            layout,
            includeBottomSpacing: includeBottomSpacing,
          ),
        _ScrollItemKind.image => _imageItemExtent(
            imageData[i] ?? Uint8List(0),
            layout,
            includeBottomSpacing: includeBottomSpacing,
          ),
      },
    );
  }
  return extents;
}

double _textItemExtent(
  int charLen,
  ScrollLayoutParams layout, {
  required bool includeBottomSpacing,
}) {
  final lineCount = _estimateLineCount(charLen, layout);
  final body = lineCount * layout.textRowHeight;
  return body + (includeBottomSpacing ? layout.paragraphSpacing : 0);
}

double _imageItemExtent(
  Uint8List data,
  ScrollLayoutParams layout, {
  required bool includeBottomSpacing,
}) {
  if (data.isEmpty) {
    return includeBottomSpacing ? layout.paragraphSpacing : 0;
  }
  const imageVerticalPadding = 16.0;
  const defaultHeightRatio = 0.55;
  final dims = readImageDimensions(data);
  final displayHeight = dims == null
      ? layout.contentWidth * defaultHeightRatio
      : dims.$2 * math.min(1.0, layout.contentWidth / dims.$1);
  return displayHeight +
      imageVerticalPadding +
      (includeBottomSpacing ? layout.paragraphSpacing : 0);
}

int _estimateLineCount(int charLen, ScrollLayoutParams layout) {
  if (charLen <= 0) return 1;
  final charsPerLine =
      (layout.contentWidth / layout.fontSize * 0.9).floor().clamp(1, 999);
  return (charLen / charsPerLine).ceil().clamp(1, 9999);
}

/// 从 PNG/JPEG 头部读取 intrinsic 尺寸（轻量，无完整解码）。
(int width, int height)? readImageDimensions(Uint8List bytes) {
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    final w = (bytes[16] << 24) |
        (bytes[17] << 16) |
        (bytes[18] << 8) |
        bytes[19];
    final h = (bytes[20] << 24) |
        (bytes[21] << 16) |
        (bytes[22] << 8) |
        bytes[23];
    if (w > 0 && h > 0) return (w, h);
  }

  if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      if (marker == 0xD9 || marker == 0xDA) break;
      if (i + 3 >= bytes.length) break;
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (len < 2) break;
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        if (i + 8 >= bytes.length) break;
        final h = (bytes[i + 5] << 8) | bytes[i + 6];
        final w = (bytes[i + 7] << 8) | bytes[i + 8];
        if (w > 0 && h > 0) return (w, h);
      }
      i += 2 + len;
    }
  }
  return null;
}

/// 与 [ScrollModeRenderer._extractParagraphSpans] 相同。
List<TextSpan> extractParagraphSpans(TextSpan rootSpan) {
  if (rootSpan.children == null || rootSpan.children!.isEmpty) {
    return [rootSpan];
  }
  final paragraphs = <TextSpan>[];
  var currentChildren = <InlineSpan>[];
  for (final child in rootSpan.children!) {
    if (child is! TextSpan) continue;
    if (child.text == '\n\n') {
      if (currentChildren.isNotEmpty) {
        paragraphs.add(TextSpan(children: currentChildren));
        currentChildren = [];
      }
    } else {
      currentChildren.add(child);
    }
  }
  if (currentChildren.isNotEmpty) {
    paragraphs.add(TextSpan(children: currentChildren));
  }
  return paragraphs;
}

int spanTextLength(TextSpan span) {
  if (span.text != null) return span.text!.length;
  if (span.children != null) {
    var len = 0;
    for (final child in span.children!) {
      if (child is TextSpan) len += spanTextLength(child);
    }
    return len;
  }
  return 0;
}
