import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

/// 当前 FlutterPaginationSession 持有的章 IR（供渲染查 Image intrinsic，避免改 FRB）。
abstract final class ActiveChapterIr {
  static ChapterContentIr? current;

  static void set(ChapterContentIr? ir) => current = ir;

  static void clear() => current = null;

  /// 按 assetId 查 IR 中的图块（无则 null）。
  static ImageBlock? findImage(String assetId) {
    final ir = current;
    if (ir == null || assetId.isEmpty) return null;
    for (final b in ir.blocks) {
      final img = b.when(text: (_) => null, image: (i) => i);
      if (img != null && img.assetId == assetId) return img;
    }
    return null;
  }
}
