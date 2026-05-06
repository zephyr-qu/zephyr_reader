import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/presentation/widgets/ui_components.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书籍详情页面 - 响应式设计
class BookDetailPage extends StatelessWidget {
  final String bookId;

  const BookDetailPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<BookshelfViewModel>();
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, theme, deviceType),
          SliverPadding(
            padding: pagePadding,
            sliver: FutureBuilder<DbBookRecord?>(
              key: ValueKey(bookId),
              future: vm.getBookDetail(bookId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            '加载中...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text('加载失败：${snapshot.error}'),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _loadBookDetail(context),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final book = snapshot.data;
                if (book == null) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text('书籍不存在', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => context.go('/bookshelf'),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('返回书架'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: isDesktop
                      ? _buildTabletLayout(context, book, theme)
                      : _buildPhoneLayout(context, book, theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    return SliverAppBar(
      floating: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.go('/bookshelf'),
            child: Text(
              '书架',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/articles'),
            child: Text(
              '文章',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('编辑功能开发中')));
          },
          tooltip: '编辑',
        ),
        SizedBox(width: deviceType == DeviceType.desktop ? 16 : 8),
      ],
    );
  }

  Widget _buildPhoneLayout(
    BuildContext context,
    DbBookRecord book,
    ThemeData theme,
  ) {
    final spacing = LayoutBreakpoints.getSpacing(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroSection(context, book, theme),
        SizedBox(height: spacing),
        _buildInfoSection(book, theme),
        SizedBox(height: spacing),
        _buildDescriptionSection(book, theme),
        SizedBox(height: spacing),
        _buildChaptersSection(context, book, theme),
        SizedBox(height: spacing),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    DbBookRecord book,
    ThemeData theme,
  ) {
    final spacing = LayoutBreakpoints.getSpacing(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(context, book, theme),
                  SizedBox(height: spacing),
                  _buildInfoSection(book, theme),
                  SizedBox(height: spacing),
                  _buildDescriptionSection(book, theme),
                ],
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: 1,
              child: _buildChaptersSection(context, book, theme),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    DbBookRecord book,
    ThemeData theme,
  ) {
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;
    final coverWidth = isDesktop ? 140.0 : 120.0;
    final coverHeight = isDesktop ? 200.0 : 170.0;

    return GradientCard(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: coverWidth,
              height: coverHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: book.coverPath != null
                  ? Image.network(
                      book.coverPath!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildCoverPlaceholder(
                          theme,
                          coverWidth,
                          coverHeight,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    )
                  : _buildCoverPlaceholder(theme, coverWidth, coverHeight),
            ),
          ),
          SizedBox(width: isDesktop ? 24 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      book.author,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _startReading(context, book),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('开始阅读'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildCoverPlaceholder(ThemeData theme, double width, double height) {
    return Center(
      child: Icon(
        Icons.book_rounded,
        size: width * 0.4,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildInfoSection(DbBookRecord book, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _buildInfoItem(
              context: '总章节',
              value: '${book.chapterCount} 章',
              icon: Icons.chrome_reader_mode_rounded,
              theme: theme,
            ),
            _buildInfoItem(
              context: '状态',
              value: _getStatusText(book.status.name),
              icon: _getStatusIcon(book.status.name),
              theme: theme,
            ),
            _buildInfoItem(
              context: '添加时间',
              value: _formatDate(book.addedAt),
              icon: Icons.calendar_today_rounded,
              theme: theme,
            ),
            if (book.lastOpenedAt != null)
              _buildInfoItem(
                context: '最后阅读',
                value: _formatDate(book.lastOpenedAt!),
                icon: Icons.access_time_rounded,
                theme: theme,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 500.ms);
  }

  Widget _buildInfoItem({
    required String context,
    required String value,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(
    DbBookRecord book,
    ThemeData theme,
  ) {
    if (book.description == null || book.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '简介',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              book.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }

  Widget _buildChaptersSection(
    BuildContext context,
    DbBookRecord book,
    ThemeData theme,
  ) {
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_rounded, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      '章节目录',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('全部章节功能开发中')));
                  },
                  child: Text('全部 ${book.chapterCount} 章'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(
              book.chapterCount.clamp(0, isDesktop ? 15 : 10),
              (index) =>
                  _buildChapterItem(context, index, book, theme, isDesktop),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }

  Widget _buildChapterItem(
    BuildContext context,
    int index,
    DbBookRecord book,
    ThemeData theme,
    bool isDesktop,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 12 : 8,
        vertical: 4,
      ),
      dense: !isDesktop,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      title: Text(
        '第 ${index + 1} 章',
        style: theme.textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => _startReading(context, book, chapterIndex: index + 1),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'reading':
        return Icons.menu_book_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'dropped':
        return Icons.pause_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'reading':
        return '阅读中';
      case 'completed':
        return '已完结';
      case 'dropped':
        return '已弃坑';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _startReading(
    BuildContext context,
    DbBookRecord book, {
    int? chapterIndex,
  }) {
    final targetChapter = chapterIndex ?? 1;
    context.pushNamed(
      RouteNames.reader,
      pathParameters: {
        'bookId': book.bookId,
        'chapterId': targetChapter.toString(),
      },
    );
  }

  void _loadBookDetail(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    context.go(currentRoute);
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书籍'),
        content: const Text('确定要删除这本书吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final vm = getIt<BookshelfViewModel>();
              final success = await vm.deleteBook(bookId);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('删除成功')));
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
