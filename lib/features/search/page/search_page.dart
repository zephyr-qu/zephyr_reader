import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_service.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/domain/repositories/search_repository.dart';
import 'package:signals_flutter/signals_flutter.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final vm = getIt<SearchViewModel>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      vm.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索小说')),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索小说名称或作者',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Watch.builder(
                  builder: (context) {
                    if (vm.keyword.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        vm.updateKeyword('');
                        vm.clear();
                      },
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) {
                vm.updateKeyword(value);
                vm.search();
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              vm.updateKeyword(_searchController.text);
              vm.search();
            },
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Watch.builder(
      builder: (context) {
        final async = vm.results.value;

        if (async.isLoading && vm.currentPage.value == 1) {
          return const Center(child: CircularProgressIndicator());
        }

        if (async.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('搜索失败: ${async.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => vm.search(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final results = async.value ?? [];

        if (results.isEmpty && vm.keyword.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('未找到 "${vm.keyword.value}" 相关的小说'),
              ],
            ),
          );
        }

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('输入关键词开始搜索', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: results.length + (vm.hasMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < results.length) {
              return _buildResultItem(results[index]);
            } else {
              return Watch.builder(
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: vm.isSearching.value
                        ? const Center(child: CircularProgressIndicator())
                        : const Center(child: Text('没有更多了')),
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPreview(result),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 60,
                  height: 80,
                  color: Colors.grey[300],
                  child: result.coverUrl != null
                      ? Image.network(
                          result.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.book,
                                size: 32,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.book, size: 32, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.author,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.totalChapters}章 · ${result.source}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (result.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        result.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview(SearchResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.coverUrl != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      result.coverUrl!,
                      width: 120,
                      height: 160,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 160,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book, size: 48),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('作者: ${result.author}'),
              const SizedBox(height: 8),
              Text('章节数: ${result.totalChapters}'),
              const SizedBox(height: 8),
              Text('来源: ${result.source}'),
              if (result.description != null) ...[
                const SizedBox(height: 16),
                const Text(
                  '简介:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(result.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // 添加到书架
              final bookshelfService = GetIt.I.get<BookshelfService>();
              final book = await bookshelfService.addBook(
                title: result.title,
                author: result.author,
                filePath: result.id, // 使用搜索 ID 作为临时文件路径
                fileFormat: 'web', // 网络源
                totalChapters: result.totalChapters,
                description: result.description,
                coverPath: result.coverUrl,
              );

              if (!context.mounted) return;

              if (book != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加 ${result.title} 到书架')),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('添加失败，书籍可能已存在')));
              }
            },
            child: const Text('添加到书架'),
          ),
        ],
      ),
    );
  }
}
