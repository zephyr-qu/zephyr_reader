import 'dart:math' as math;
import 'dart:typed_data';

import 'package:zephyr_reader/reader_engine/scroll/scroll_layout_params.dart';
import 'package:zephyr_reader/reader_engine/shared/ir_types.dart';

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
      offset +=
          itemExtentAt(index, uniformFallback: uniformFallback) *
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

/// 计算与滚动渲染一致的 ListView 项度量（纯文本路径）。
ScrollListMetrics computeScrollListMetrics({
  required List<String> paragraphs,
  required List<int> paragraphCharOffsets,
  ScrollLayoutParams? layout,
}) {
  final lengths = paragraphs.map((p) => p.length).toList();
  return ScrollListMetrics(
    itemCount: paragraphs.length,
    charOffsets: List<int>.from(paragraphCharOffsets),
    charLengths: lengths,
    itemExtents: layout == null ? const [] : _plainTextExtents(lengths, layout),
  );
}

/// IR 块流 ListView 度量（每 [ReaderIrBlock] 一项；图片高度用占位估算）。
ScrollListMetrics computeScrollIrListMetrics({
  required List<ReaderIrBlock> blocks,
  ScrollLayoutParams? layout,
}) {
  final offsets = <int>[];
  final lengths = <int>[];
  for (final block in blocks) {
    offsets.add(block.plainStart);
    lengths.add(block.kind == ReaderIrBlockKind.image ? 1 : block.plainLen);
  }
  return ScrollListMetrics(
    itemCount: offsets.length,
    charOffsets: offsets,
    charLengths: lengths,
    itemExtents: layout == null ? const [] : _irBlockExtents(blocks, layout),
  );
}

List<double> _irBlockExtents(
  List<ReaderIrBlock> blocks,
  ScrollLayoutParams layout,
) {
  final extents = <double>[];
  for (var i = 0; i < blocks.length; i++) {
    final includeBottomSpacing = i < blocks.length - 1;
    final block = blocks[i];
    extents.add(
      block.kind == ReaderIrBlockKind.image
          ? _imageItemExtent(
              Uint8List(0),
              layout,
              includeBottomSpacing: includeBottomSpacing,
            )
          : _textItemExtent(
              block.plainLen,
              layout,
              includeBottomSpacing: includeBottomSpacing,
            ),
    );
  }
  return extents;
}

List<double> _plainTextExtents(
  List<int> charLengths,
  ScrollLayoutParams layout,
) {
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
  final charsPerLine = (layout.contentWidth / layout.fontSize * 0.9)
      .floor()
      .clamp(1, 999);
  return (charLen / charsPerLine).ceil().clamp(1, 9999);
}

/// 从 PNG/JPEG 头部读取 intrinsic 尺寸（轻量，无完整解码）。
(int width, int height)? readImageDimensions(Uint8List bytes) {
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    final w =
        (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final h =
        (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
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
