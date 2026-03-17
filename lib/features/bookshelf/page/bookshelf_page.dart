import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/book_category.dart';
import 'package:zephyr_reader/shared/widget/loading_indicator.dart';

class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<BookshelfViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => vm.startSearch(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.pushNamed(RouteNames.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryFilter(context, vm),
          Expanded(child: _buildBookList(context, vm)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.search),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context, BookshelfViewModel vm) {
    return Watch.builder(
      builder: (context) {
        final categories = BookCategory.values;
        final selected = vm.selectedCategory.value;

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category == selected;

              return FilterChip(
                label: Text(category.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    vm.selectCategory(category);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBookList(BuildContext context, BookshelfViewModel vm) {
    return Watch.builder(
      builder: (context) {
        final async = vm.books.value;

        if (async.isLoading) {
          return const LoadingIndicator();
        }

        if (async.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('加载失败: ${async.error}'),
                ElevatedButton(
                  onPressed: vm.loadBooks,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final books = async.value ?? [];

        if (books.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('书架空空如也'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.pushNamed(RouteNames.search),
                  child: const Text('去搜索小说'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return _buildBookCard(context, book);
          },
        );
      },
    );
  }

  Widget _buildBookCard(BuildContext context, Book book) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          RouteNames.bookDetail,
          pathParameters: {'id': book.id.toString()},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: book.coverPath != null
                    ? Image.network(
                        book.coverPath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.book,
                              size: 48,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.book, size: 48, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusChip(book.status),
                      const Spacer(),
                      Text(
                        '${book.totalChapters}章',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'reading':
        color = Colors.blue;
        label = '阅读中';
        break;
      case 'completed':
        color = Colors.green;
        label = '已完结';
        break;
      case 'dropped':
        color = Colors.grey;
        label = '已弃坑';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
