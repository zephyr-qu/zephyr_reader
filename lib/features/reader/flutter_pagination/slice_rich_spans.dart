import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 与 Flutter 装箱索引一致：Dart [String] UTF-16 码元下标（对齐 `substring` /
/// packer 的 `sliceLocalStart`）。BMP 中文与 Rust Unicode scalar 一致。
String richSpanText(RichTextSpan span) =>
    span.when(styled: (_, data) => data.text, link: (data, _) => data.text);

RichTextSpan _cloneSpanWithText(RichTextSpan span, String text) => span.when(
  styled: (style, _) => RichTextSpan.styled(style, RichTextSpanData(text: text)),
  link: (_, url) =>
      RichTextSpan.link(data: RichTextSpanData(text: text), url: url),
);

/// 将块内 span 流按 `[start, start+len)` 裁剪（对齐 Rust `slice_rich_spans`）。
List<RichTextSpan> sliceRichSpans(
  List<RichTextSpan> spans, {
  required int start,
  required int len,
}) {
  if (len <= 0 || spans.isEmpty) return const [];
  final end = start + len;
  var cursor = 0;
  final out = <RichTextSpan>[];

  for (final span in spans) {
    final full = richSpanText(span);
    final spanLen = full.length;
    final spanStart = cursor;
    final spanEnd = cursor + spanLen;
    cursor = spanEnd;

    if (spanEnd <= start || spanStart >= end) continue;

    final overlapStart = (start - spanStart).clamp(0, spanLen);
    final overlapEnd = (end - spanStart).clamp(0, spanLen);
    final sliceLen = overlapEnd - overlapStart;
    if (sliceLen <= 0) continue;
    out.add(
      _cloneSpanWithText(span, full.substring(overlapStart, overlapEnd)),
    );
  }
  return out;
}
