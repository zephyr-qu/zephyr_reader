import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';

class BookDetailPage extends StatelessWidget {
  final int bookId;
  final vm = getIt<BookshelfViewModel>();

  BookDetailPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: FutureBuilder<Book?>(
        future: vm.getBookDetail(bookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final book = snapshot.data;
          if (book == null) {
            return const Center(child: Text('书籍不存在'));
          }

          return _buildContent(context, book);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Book book) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, book),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(book),
                const SizedBox(height: 24),
                _buildDescriptionSection(book),
                const SizedBox(height: 24),
                _buildChaptersSection(context, book),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Book book) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 100,
              height: 140,
              color: Colors.grey[300],
              child: book.coverPath != null
                  ? Image.network(
                      book.coverPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.book, size: 48, color: Colors.grey),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.book, size: 48, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.author,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _startReading(context, book),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('开始阅读'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Book book) {
    return Row(
      children: [
        _buildInfoItem('总章节', '${book.totalChapters}'),
        const SizedBox(width: 24),
        _buildInfoItem('状态', _getStatusText(book.status)),
        const SizedBox(width: 24),
        _buildInfoItem('添加时间', _formatDate(book.createdAt)),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(Book book) {
    if (book.description == null || book.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '简介',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          book.description!,
          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildChaptersSection(BuildContext context, Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '章节目录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {},
              child: Text('全部 ${book.totalChapters} 章'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(
          book.totalChapters.clamp(0, 10),
          (index) => ListTile(
            dense: true,
            title: Text('第 ${index + 1} 章'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _startReading(context, book, chapterIndex: index + 1),
          ),
        ),
      ],
    );
  }

  void _startReading(BuildContext context, Book book, {int? chapterIndex}) {
    final targetChapter = chapterIndex ?? 1;
    context.pushNamed(
      RouteNames.reader,
      pathParameters: {
        'bookId': book.id.toString(),
        'chapterId': targetChapter.toString(),
      },
    );
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
}
