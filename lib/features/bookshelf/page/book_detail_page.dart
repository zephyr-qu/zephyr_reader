import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

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
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text(''),
      ),
      body: FutureBuilder<Book?>(
        key: ValueKey(bookId),
        future: vm.getBookDetail(bookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 160,
                  height: 240,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: book.coverPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(book.coverPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _coverPlaceholder(theme)),
                        )
                      : _coverPlaceholder(theme),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(book.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimary, letterSpacing: -0.3),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(book.author ?? '',
                  style: const TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.pushNamed(
                    RouteNames.reader,
                    pathParameters: {'bookId': book.bookId, 'chapterId': '1'},
                  ),
                  child: const Text('开始阅读'),
                ),
              ),
              const SizedBox(height: 40),
              const _SectionHeader(title: '信息'),
              const Divider(height: 0.5),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _infoItem('格式', book.format.name.toUpperCase()),
                    const SizedBox(width: 32),
                    _infoItem('章节', '${book.chapterCount}'),
                    const SizedBox(width: 32),
                    _infoItem('状态', _statusLabel(book.status.name)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const _SectionHeader(title: '简介'),
              const Divider(height: 0.5),
              const SizedBox(height: 12),
              SelectableText(
                book.description ?? '暂无简介',
                style: const TextStyle(fontSize: 15, height: 1.7, color: DesignTokens.textPrimary),
              ),
              const SizedBox(height: 40),
              const _SectionHeader(title: '目录'),
              const Divider(height: 0.5),
              ...List.generate(book.chapterCount, (i) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Text('${i + 1}. ',
                        style: const TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text('第 ${i + 1} 章',
                        style: const TextStyle(fontSize: 14, color: DesignTokens.textPrimary),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  Widget _coverPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(Icons.book_rounded, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: DesignTokens.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading': return '阅读中';
      case 'completed': return '已读完';
      default: return '未读';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
        style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
      ),
    );
  }
}
