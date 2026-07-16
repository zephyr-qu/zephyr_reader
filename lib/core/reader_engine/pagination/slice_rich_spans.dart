import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 获取 run 的文本内容。
String runText(ReaderInlineRun run) => run.text;

/// 克隆 run 并替换文本。
ReaderInlineRun _cloneRunWithText(ReaderInlineRun run, String text) {
  return ReaderInlineRun(text: text, style: run.style, url: run.url);
}

/// 将块内 span 流按 `[start, start+len)` 裁剪（对齐 Rust `slice_inline_runs`）。
List<ReaderInlineRun> sliceRichSpans(
  List<ReaderInlineRun> spans, {
  required int start,
  required int len,
}) {
  if (len <= 0 || spans.isEmpty) return const [];
  final end = start + len;
  var cursor = 0;
  final out = <ReaderInlineRun>[];

  for (final span in spans) {
    final full = span.text;
    final spanLen = full.length;
    final spanStart = cursor;
    final spanEnd = cursor + spanLen;
    cursor = spanEnd;

    if (spanEnd <= start || spanStart >= end) continue;

    final overlapStart = (start - spanStart).clamp(0, spanLen);
    final overlapEnd = (end - spanStart).clamp(0, spanLen);
    final sliceLen = overlapEnd - overlapStart;
    if (sliceLen <= 0) continue;
    out.add(_cloneRunWithText(span, full.substring(overlapStart, overlapEnd)));
  }
  return out;
}
