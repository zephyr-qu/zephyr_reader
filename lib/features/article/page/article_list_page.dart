import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../application/article_view_model.dart';
import '../../../../di/service_locator.dart';

class ArticleListPage extends StatelessWidget {
  const ArticleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<ArticleViewModel>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (vm.articles.value.value == null) vm.load();
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Articles'),
          ),
          Watch.builder(
            builder: (context) {
              final async = vm.articles.value;
              if (async.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (async.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text(async.error.toString())),
                );
              } else {
                final list = async.value ?? [];
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final article = list[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              context.push('/articles/${article.id}', extra: article);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.title,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Read more about this topic...',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Text(
                                        'Read Now',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: list.length,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
