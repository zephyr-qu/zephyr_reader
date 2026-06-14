import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

const _cnNumerals = [
  '一',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
  '十',
  '十一',
  '十二',
  '十三',
  '十四',
  '十五',
  '十六',
  '十七',
  '十八',
  '十九',
  '二十',
];

/// 章节列表组件。
///
/// 展示书籍的章节列表，支持点击跳转和当前章节高亮。
class ChapterList extends HookWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;
  final VoidCallback onClose;

  const ChapterList({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent(scrollController, chapters, currentChapterIndex);
      });
      return null;
    }, [chapters, currentChapterIndex]);

    final l10n = AppLocalizations.of(context)!;
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;

    return Container(
      color: readerTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(readerTheme, l10n),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.only(
                  top: 4,
                  bottom: 24,
                  left: DesignTokens.spacing(Spacing.md),
                  right: DesignTokens.spacing(Spacing.sm),
                ),
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isCurrent = chapter.chapterIndex == currentChapterIndex;
                  final indent = (chapter.level - 1).clamp(0, 4);
                  return _buildChapterItem(
                    chapter: chapter,
                    index: index,
                    isCurrent: isCurrent,
                    indent: indent,
                    readerTheme: readerTheme,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToCurrent(
    ScrollController controller,
    List<Chapter> chapters,
    int currentChapterIndex,
  ) {
    final idx = chapters.indexWhere(
      (c) => c.chapterIndex == currentChapterIndex,
    );
    if (idx >= 0 && controller.hasClients) {
      final offset = idx * 64.0;
      final maxScroll = controller.position.maxScrollExtent;
      controller.animateTo(
        offset.clamp(0, maxScroll),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildHeader(ReaderThemeExtension readerTheme, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.spacing(Spacing.md),
        DesignTokens.spacing(Spacing.sm),
        DesignTokens.spacing(Spacing.sm),
        DesignTokens.spacing(Spacing.sm),
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: readerTheme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: readerTheme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.sm)),
          Text(
            l10n.chapterList,
            style: TextStyle(
              color: readerTheme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: readerTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${chapters.length} ${l10n.chapterCountLabel}',
              style: TextStyle(
                color: readerTheme.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.sm)),
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.x,
              color: readerTheme.mutedColor,
              size: 22,
            ),
            onPressed: onClose,
            splashRadius: 20,
            tooltip: l10n.close,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterItem({
    required Chapter chapter,
    required int index,
    required bool isCurrent,
    required int indent,
    required ReaderThemeExtension readerTheme,
  }) {
    final showNumber = chapter.level <= 1;
    final cnNum = index < _cnNumerals.length
        ? _cnNumerals[index]
        : '${index + 1}';

    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChapterSelected(chapter.chapterIndex),
          borderRadius: BorderRadius.circular(10),
          splashColor: readerTheme.accentColor.withValues(alpha: 0.08),
          highlightColor: readerTheme.accentColor.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: EdgeInsets.only(
              left: showNumber ? 4 : 20,
              right: 8,
              top: 10,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: isCurrent
                  ? readerTheme.accentColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isCurrent
                  ? Border(
                      left: BorderSide(
                        color: readerTheme.accentColor,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                if (showNumber)
                  Container(
                    width: 28,
                    alignment: Alignment.center,
                    child: Text(
                      cnNum,
                      style: TextStyle(
                        color: isCurrent
                            ? readerTheme.accentColor
                            : readerTheme.mutedColor.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                if (indent > 0)
                  SizedBox(
                    width: 14,
                    child: CustomPaint(
                      painter: _TreeBranchPainter(
                        color: readerTheme.mutedColor.withValues(alpha: 0.2),
                      ),
                      size: const Size(14, 20),
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapter.title,
                        style: TextStyle(
                          color: isCurrent
                              ? readerTheme.accentColor
                              : readerTheme.textColor,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: isCurrent ? 15 : 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 2),
                        Text(
                          '正在阅读',
                          style: TextStyle(
                            color: readerTheme.accentColor.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: readerTheme.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: readerTheme.accentColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeBranchPainter extends CustomPainter {
  final Color color;
  _TreeBranchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width * 0.6, midY), paint);
    canvas.drawLine(
      Offset(size.width * 0.6, midY),
      Offset(size.width * 0.6, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) =>
      oldDelegate.color != color;
}
