import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

/// 相邻章精确预装箱结果（方案三 T2）。
///
/// 与 Rust 粗分页隔离：只存 Flutter [FlutterBlockPaginator] 产出。
class PaginationChapterReady {
  const PaginationChapterReady({
    required this.bookId,
    required this.chapterIndex,
    required this.filePath,
    required this.ir,
    required this.pages,
    required this.contentWidthDp,
    required this.contentHeightDp,
  });

  final String bookId;
  final int chapterIndex;
  final String filePath;
  final ChapterContentIr ir;
  final List<PackedPage> pages;
  final double contentWidthDp;
  final double contentHeightDp;
}

/// 进程内 next/prev staging（flag 开时使用）。
abstract final class PaginationStagingStore {
  static PaginationChapterReady? next;
  static PaginationChapterReady? prev;
  static int _generation = 0;

  static int bumpGeneration() => ++_generation;

  static int get generation => _generation;

  static bool isCurrent(int gen) => gen == _generation;

  static void clearNext() => next = null;

  static void clearPrev() => prev = null;

  static void clearAll() {
    bumpGeneration();
    next = null;
    prev = null;
  }

  static PaginationChapterReady? takeForChapter(int chapterIndex, {required bool forward}) {
    if (forward) {
      final n = next;
      if (n != null && n.chapterIndex == chapterIndex) {
        next = null;
        return n;
      }
      return null;
    }
    final p = prev;
    if (p != null && p.chapterIndex == chapterIndex) {
      prev = null;
      return p;
    }
    return null;
  }
}
