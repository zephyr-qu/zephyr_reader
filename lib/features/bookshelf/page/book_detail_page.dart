import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/category.dart' as category_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/data/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class BookDetailPage extends StatefulWidget {
  final String bookId;
  const BookDetailPage({super.key, required this.bookId});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  Book? _book;
  ReadingProgress? _progress;
  NoteStats? _noteStats;
  List<Chapter> _chapters = [];
  List<Category> _categories = [];
  List<ReadingSession> _sessions = [];
  List<Vocab> _vocabList = [];
  bool _showAllChapters = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        book_api.getBook(bookId: widget.bookId),
        progress_api.getProgress(bookId: widget.bookId),
        note_api.getNoteStats(bookId: widget.bookId),
        chapter_api.listChaptersByBook(bookId: widget.bookId),
        category_api.listCategoriesByBook(bookId: widget.bookId),
        session_api.listSessionsByBook(
          bookId: widget.bookId,
          limit: BigInt.from(10000),
        ),
        vocab_api.listVocabularyByStatus(bookId: widget.bookId),
      ]);
      setState(() {
        _book = results[0] as Book?;
        _progress = results[1] as ReadingProgress?;
        _noteStats = results[2] as NoteStats?;
        _chapters = results[3] as List<Chapter>;
        _categories = results[4] as List<Category>;
        _sessions = results[5] as List<ReadingSession>;
        _vocabList = results[6] as List<Vocab>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsLight.caretLeft),
          onPressed: () => context.pop(),
          tooltip: '返回',
        ),
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _book == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }
    final book = _book!;
    final currentChapterIndex = _progress?.chapterIndex ?? -1;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero: Cover + Meta
          _buildHero(theme, book),

          // Action Buttons
          _buildActions(theme, book, currentChapterIndex),

          // Progress Card
          if (_progress != null) _buildProgressCard(theme, book),

          // Note Stats
          _buildNoteStatsRow(theme),

          // TOC Accordion
          _buildTocSection(theme, book, currentChapterIndex),

          // Book Info
          _buildInfoSection(theme, book),

          // Description
          if (book.description != null && book.description!.isNotEmpty)
            _buildDescSection(theme, book),

          // Bottom Actions
          _buildBottomActions(theme, book),
        ],
      ),
    );
  }

  // ──────────────── Hero ────────────────

  Widget _buildHero(ThemeData theme, Book book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 120,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: theme.colorScheme.primaryContainer,
                    child: book.coverPath != null
                        ? Image.file(
                            File(book.coverPath!),
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            errorBuilder: (_, _, _) => _coverPlaceholder(theme),
                          )
                        : _coverPlaceholder(theme),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  book.author ?? '未知作者',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // Tags
                if (_categories.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _categories
                        .map(
                          (c) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 10),
                // File info
                Text(
                  '${_formatFileSize(book.fileSize)}${book.isbn != null ? '  ·  ${book.isbn}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        PhosphorIconsRegular.book,
        size: 48,
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
      ),
    );
  }

  // ──────────────── Actions ────────────────

  Widget _buildActions(ThemeData theme, Book book, int currentChapterIndex) {
    final hasProgress = _progress != null && (_progress?.progress ?? 0) > 0;
    final chapterTitle =
        hasProgress &&
            currentChapterIndex >= 0 &&
            currentChapterIndex < _chapters.length
        ? _chapters[currentChapterIndex].title
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => context.pushNamed(
                  RouteNames.reader,
                  pathParameters: {
                    'bookId': book.bookId,
                    'chapterId': '${_progress?.chapterIndex ?? 0}',
                  },
                ),
                child: Text(
                  hasProgress
                      ? '继续阅读${chapterTitle != null ? ' · $chapterTitle' : ''}'
                      : '开始阅读',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: theme.dividerColor),
                ),
                onPressed: () => context.pushNamed(
                  RouteNames.reader,
                  pathParameters: {'bookId': book.bookId, 'chapterId': '0'},
                ),
                child: const Text(
                  '从头开始',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Progress Card ────────────────

  Widget _buildProgressCard(ThemeData theme, Book book) {
    final pct = (_progress?.progress ?? 0.0) * 100;
    final totalMinutes = (_progress?.readingTimeSeconds ?? 0) ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    // 阅读次数
    final readCount = _sessions.length;

    // 预计剩余时间
    String? remainingStr;
    final progress = _progress!.progress;
    final readingTime = _progress!.readingTimeSeconds.toDouble();
    if (progress > 0.01 && readingTime > 0) {
      final remainingSec = ((1.0 - progress) * readingTime / progress).round();
      if (remainingSec > 0) {
        final rh = remainingSec ~/ 3600;
        final rm = (remainingSec % 3600) ~/ 60;
        remainingStr = rh > 0 ? '约 ${rh}h ${rm}min' : '约 ${rm}min';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '阅读进度',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progress!.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          // Three stats
          Row(
            children: [
              _statItem(theme, timeStr, '累计时长'),
              _statItem(theme, '$readCount', '阅读次数'),
              if (remainingStr != null) _statItem(theme, remainingStr, '预计剩余'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Note Stats ────────────────

  Widget _buildNoteStatsRow(ThemeData theme) {
    final highlightCount = _noteStats?.highlightCount ?? 0;
    final annotationCount = _noteStats?.annotationCount ?? 0;
    final vocabCount = _vocabList.length;

    if (highlightCount == 0 && annotationCount == 0 && vocabCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _noteStatCard(
            theme,
            '$highlightCount',
            '高亮',
            const Color(0xFFFFA726),
            Colors.orange.shade50,
            () {
              // Navigate to notes page filtered to highlights
            },
          ),
          const SizedBox(width: 8),
          _noteStatCard(
            theme,
            '$annotationCount',
            '笔记',
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            () {
              // Navigate to notes page filtered to annotations
            },
          ),
          const SizedBox(width: 8),
          _noteStatCard(
            theme,
            '$vocabCount',
            '生词',
            const Color(0xFFAB47BC),
            Colors.purple.shade50,
            () {
              // Navigate to vocabulary page
            },
          ),
        ],
      ),
    );
  }

  Widget _noteStatCard(
    ThemeData theme,
    String count,
    String label,
    Color color,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light
                ? bgColor
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────── TOC ────────────────

  Widget _buildTocSection(ThemeData theme, Book book, int currentChapterIndex) {
    if (_chapters.isEmpty) return const SizedBox.shrink();

    final displayChapters = _showAllChapters
        ? _chapters
        : _chapters.take(5).toList();
    final hasMore = _chapters.length > 5;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: hasMore
                ? () => setState(() => _showAllChapters = !_showAllChapters)
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '目录 (${_chapters.length} 章)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (hasMore)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showAllChapters ? '收起' : '展开',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _showAllChapters
                              ? PhosphorIconsRegular.caretUp
                              : PhosphorIconsRegular.caretDown,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Divider
          Divider(height: 1, color: theme.dividerColor),
          // List
          ...displayChapters.asMap().entries.map((entry) {
            final idx = entry.key;
            final chapter = entry.value;
            final isCurrent =
                currentChapterIndex >= 0 &&
                chapter.chapterIndex == currentChapterIndex;
            return InkWell(
              onTap: () {
                context.pushNamed(
                  RouteNames.reader,
                  pathParameters: {
                    'bookId': book.bookId,
                    'chapterId': '${chapter.chapterIndex}',
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        )
                      : null,
                  border: idx < displayChapters.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA726),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────── Book Info ────────────────

  Widget _buildInfoSection(ThemeData theme, Book book) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow(theme, '格式', book.format.name.toUpperCase()),
          _infoRow(theme, '文件大小', _formatFileSize(book.fileSize)),
          if (book.publisher != null && book.publisher!.isNotEmpty)
            _infoRow(theme, '出版社', book.publisher!),
          if (book.translator != null && book.translator!.isNotEmpty)
            _infoRow(theme, '译者', book.translator!),
          if (book.isbn != null && book.isbn!.isNotEmpty)
            _infoRow(theme, 'ISBN', book.isbn!),
          if (_categories.isNotEmpty)
            _infoRow(theme, '分类', _categories.map((c) => c.name).join(' / ')),
          _infoRow(
            theme,
            '添加时间',
            DateFormat('yyyy-MM-dd').format(book.addedAt.toLocal()),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              key,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Description ────────────────

  Widget _buildDescSection(ThemeData theme, Book book) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '简介',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            book.description ?? '',
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Bottom Actions ────────────────

  Widget _buildBottomActions(ThemeData theme, Book book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _showEditMetadataDialog(context),
              icon: const Icon(PhosphorIconsRegular.pencilLine, size: 16),
              label: const Text(
                '编辑元数据',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                context.pushNamed(RouteNames.learningNotes);
              },
              icon: const Icon(PhosphorIconsRegular.fileArrowUp, size: 16),
              label: const Text(
                '导出笔记',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                foregroundColor: const Color(0xFFEF5350),
              ),
              onPressed: () => _showDeleteConfirmDialog(context),
              icon: const Icon(PhosphorIconsRegular.trash, size: 16),
              label: const Text(
                '删除书籍',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Dialogs ────────────────

  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除「${_book!.title}」吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await book_api.deleteBook(bookId: widget.bookId);
      } catch (e) {
        Logging.error('删除书籍失败', exception: e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (context.mounted) context.pop();
    }
  }

  Future<void> _showEditMetadataDialog(BuildContext context) async {
    final nameController = TextEditingController(text: _book!.title);
    final authorController = TextEditingController(text: _book!.author ?? '');
    final publisherController = TextEditingController(
      text: _book!.publisher ?? '',
    );
    final translatorController = TextEditingController(
      text: _book!.translator ?? '',
    );
    final isbnController = TextEditingController(text: _book!.isbn ?? '');
    final descController = TextEditingController(
      text: _book!.description ?? '',
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('编辑元数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '书名'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(labelText: '作者'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: publisherController,
                decoration: const InputDecoration(labelText: '出版社'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: translatorController,
                decoration: const InputDecoration(labelText: '译者'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: isbnController,
                decoration: const InputDecoration(labelText: 'ISBN'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '简介'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c, {
                'title': nameController.text,
                'author': authorController.text,
                'publisher': publisherController.text,
                'translator': translatorController.text,
                'isbn': isbnController.text,
                'description': descController.text,
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      final updated = Book(
        bookId: _book!.bookId,
        filePath: _book!.filePath,
        fileHash: _book!.fileHash,
        fileSize: _book!.fileSize,
        fileMtime: _book!.fileMtime,
        title: result['title'] ?? _book!.title,
        author: result['author']?.isNotEmpty == true ? result['author'] : null,
        description: result['description']?.isNotEmpty == true
            ? result['description']
            : null,
        publisher: result['publisher']?.isNotEmpty == true
            ? result['publisher']
            : null,
        translator: result['translator']?.isNotEmpty == true
            ? result['translator']
            : null,
        isbn: result['isbn']?.isNotEmpty == true ? result['isbn'] : null,
        coverPath: _book!.coverPath,
        chapterCount: _book!.chapterCount,
        totalCharacters: _book!.totalCharacters,
        format: _book!.format,
        addedAt: _book!.addedAt,
        lastOpenedAt: _book!.lastOpenedAt,
        status: _book!.status,
        isPinned: _book!.isPinned,
      );
      try {
        await book_api.upsertBook(book: updated);
      } catch (e) {
        Logging.error('保存书籍信息失败', exception: e);
        return;
      }
      if (!mounted) return;
      setState(() => _book = updated);
    }
  }

  // ──────────────── Helpers ────────────────

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
