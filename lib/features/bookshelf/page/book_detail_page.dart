import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class BookDetailPage extends StatelessWidget {
  final String bookId;
  const BookDetailPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<BookshelfViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsLight.caretLeft),
          onPressed: () => context.pop(),
          tooltip: '返回',
        ),
        title: const Text(''),
      ),
      body: SafeArea(
        child: FutureBuilder<Book?>(
          key: ValueKey(bookId),
          future: vm.getBookDetail(bookId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '加载失败',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => vm.getBookDetail(bookId),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }
            final book = snapshot.data!;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing(Spacing.lg),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radius(RadiusSize.md),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: 0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radius(RadiusSize.md),
                                  ),
                                  child: SizedBox(
                                    width: 120,
                                    height: 180,
                                    child: Container(
                                      color: theme
                                          .colorScheme.primaryContainer,
                                      child: book.coverPath != null
                                          ? Image.file(
                                              File(book.coverPath!),
                                              fit: BoxFit.cover,
                                              cacheWidth: 300,
                                              errorBuilder: (_, _, _) =>
                                                  _coverPlaceholder(theme),
                                            )
                                          : _coverPlaceholder(theme),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                  width: DesignTokens.spacing(Spacing.lg)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                        letterSpacing: -0.3,
                                        height: 1.3,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book.author ?? '未知作者',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(
                                        height: DesignTokens.spacing(
                                            Spacing.md)),
                                    Row(
                                      children: [
                                        _infoItemCompact(
                                            context, '格式',
                                            book.format.name.toUpperCase()),
                                        const SizedBox(width: 16),
                                        _infoItemCompact(context, '章节',
                                            '${book.chapterCount}'),
                                        const SizedBox(width: 16),
                                        _infoItemCompact(context, '状态',
                                            _statusLabel(book.status.name)),
                                      ],
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () => context.pushNamed(
                                          RouteNames.reader,
                                          pathParameters: {
                                            'bookId': book.bookId,
                                            'chapterId': '0',
                                          },
                                        ),
                                        child: const Text('开始阅读'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _SectionHeader(title: '简介'),
                        const Divider(height: 0.5),
                        const SizedBox(height: 12),
                        SelectableText(
                          book.description ?? '暂无简介',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const _SectionHeader(title: '目录'),
                        const Divider(height: 0.5),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: DesignTokens.spacing(Spacing.lg),
                    right: DesignTokens.spacing(Spacing.lg),
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.dividerColor,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${index + 1}. ',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(width: DesignTokens.spacing(Spacing.sm)),
                            Text(
                              '第 ${index + 1} 章',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    }, childCount: book.chapterCount),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing(Spacing.lg),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                  ),
                ),
              ],
            );
          },
        ),
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

  Widget _infoItemCompact(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
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
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading':
        return '阅读中';
      case 'completed':
        return '已读完';
      default:
        return '未读';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: DesignTokens.spacing(Spacing.sm)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
