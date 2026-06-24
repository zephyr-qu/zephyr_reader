import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 滚动 ListView 每项的 charOffset / 长度（与 [ScrollModeRenderer] 扁平化逻辑一致）。
class ScrollListMetrics {
  const ScrollListMetrics({
    required this.itemCount,
    required this.charOffsets,
    required this.charLengths,
  });

  final int itemCount;
  final List<int> charOffsets;
  final List<int> charLengths;

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
}

/// 计算与滚动渲染一致的 ListView 项度量。
ScrollListMetrics computeScrollListMetrics({
  required List<String> paragraphs,
  required List<int> paragraphCharOffsets,
  List<RichParagraph>? richParagraphs,
  TextSpan? richRootSpan,
}) {
  if (richParagraphs == null || richParagraphs.isEmpty) {
    return ScrollListMetrics(
      itemCount: paragraphs.length,
      charOffsets: List<int>.from(paragraphCharOffsets),
      charLengths: paragraphs.map((p) => p.length).toList(),
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
  for (final rp in richParagraphs) {
    if (rp.isImage) {
      final imgOffset = textIdx < textParaOffsets.length
          ? textParaOffsets[textIdx]
          : accOffset;
      offsets.add(imgOffset);
      lengths.add(1);
      continue;
    }
    if (textIdx >= textParagraphs.length) continue;
    offsets.add(textParaOffsets[textIdx]);
    lengths.add(spanTextLength(textParagraphs[textIdx]));
    textIdx++;
  }

  return ScrollListMetrics(
    itemCount: offsets.length,
    charOffsets: offsets,
    charLengths: lengths,
  );
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
