import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// 搜索结果列表中的单一条目。
///
/// 显示匹配片段 [snippet] 和章节标题 [chapterTitle]，
/// 点击跳转至阅读器对应位置。
class SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.goNamed(
        AppRoute.reader.name,
        pathParameters: {
          'bookId': result.bookId,
          'chapterId': result.chapterId,
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: ListTile(
          title: Text(result.snippet),
          subtitle: Text(result.chapterTitle),
        ),
      ),
    );
  }
}
