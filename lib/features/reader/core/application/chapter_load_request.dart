import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

/// 章节导航类型（影响分页意图推导与 UI 动效）。
enum ChapterNavigationKind {
  /// 相邻跨章（翻页触发的换章，走 staging promote / 虚拟页）。
  adjacentCrossChapter,

  /// 手动跳章（TOC / 书签 / 搜索），保留 AnimatedSwitcher 过渡。
  manualJump,
}

/// 单次章节加载请求的不可变参数。
class ChapterLoadRequest {
  final int chapterIndex;
  final int initialCharOffset;
  final ReadingMode readingMode;
  final bool? preserveContent;
  final Future<void> Function()? onChapterLoaded;
  final ChapterNavigationKind navigationKind;

  const ChapterLoadRequest({
    required this.chapterIndex,
    this.initialCharOffset = 0,
    this.readingMode = ReadingMode.pagination,
    this.preserveContent,
    this.onChapterLoaded,
    this.navigationKind = ChapterNavigationKind.manualJump,
  });
}
