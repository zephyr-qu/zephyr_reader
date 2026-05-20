library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ChapterListWidget extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ThemeMode themeMode;
  final ValueChanged<int> onChapterSelected;
  final VoidCallback onClose;

  const ChapterListWidget({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.themeMode,
    required this.onChapterSelected,
    required this.onClose,
  });

  @override
  State<ChapterListWidget> createState() => _ChapterListWidgetState();
}

class _ChapterListWidgetState extends State<ChapterListWidget> {
  final _scrollController = ScrollController();

  static const _cnNumerals = [
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
    });
  }

  void _scrollToCurrent() {
    final idx = widget.chapters.indexWhere(
      (c) => c.chapterIndex == widget.currentChapterIndex,
    );
    if (idx >= 0 && _scrollController.hasClients) {
      final offset = idx * 64.0;
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        offset.clamp(0, maxScroll),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF111118) : const Color(0xFFF8F6F0);
    final surfaceColor = isDark
        ? const Color(0xFF1A1A24)
        : const Color(0xFFFFFDF7);
    final textColor = isDark
        ? const Color(0xFFE8E6E1)
        : const Color(0xFF2C2C2C);
    final mutedColor = isDark
        ? const Color(0xFF6B6B76)
        : const Color(0xFF9C9C9C);
    final accentColor = DesignTokens.warmAccent;
    final dividerColor = isDark
        ? const Color(0xFF2A2A35)
        : const Color(0xFFEDEBE4);

    return Material(
      color: Colors.transparent,
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(textColor, mutedColor, accentColor, dividerColor),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: 4,
                    bottom: 24,
                    left: DesignTokens.spacing(Spacing.md),
                    right: DesignTokens.spacing(Spacing.sm),
                  ),
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = widget.chapters[index];
                    final isCurrent =
                        chapter.chapterIndex == widget.currentChapterIndex;
                    final indent = (chapter.level - 1).clamp(0, 4);
                    return _buildChapterItem(
                      chapter: chapter,
                      index: index,
                      isCurrent: isCurrent,
                      indent: indent,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      accentColor: accentColor,
                      surfaceColor: surfaceColor,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    Color textColor,
    Color mutedColor,
    Color accentColor,
    Color dividerColor,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.spacing(Spacing.md),
        DesignTokens.spacing(Spacing.sm),
        DesignTokens.spacing(Spacing.sm),
        DesignTokens.spacing(Spacing.sm),
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.sm)),
          Text(
            '目录',
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.chapters.length} 章',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.sm)),
          IconButton(
            icon: Icon(PhosphorIconsRegular.x, color: mutedColor, size: 22),
            onPressed: widget.onClose,
            splashRadius: 20,
            tooltip: '关闭',
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
    required Color textColor,
    required Color mutedColor,
    required Color accentColor,
    required Color surfaceColor,
    required bool isDark,
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
          onTap: () => widget.onChapterSelected(chapter.chapterIndex),
          borderRadius: BorderRadius.circular(10),
          splashColor: accentColor.withValues(alpha: 0.08),
          highlightColor: accentColor.withValues(alpha: 0.04),
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
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isCurrent
                  ? Border(left: BorderSide(color: accentColor, width: 3))
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
                            ? accentColor
                            : mutedColor.withValues(alpha: 0.5),
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
                        color: mutedColor.withValues(alpha: 0.2),
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
                          color: isCurrent ? accentColor : textColor,
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
                            color: accentColor.withValues(alpha: 0.7),
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
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
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
