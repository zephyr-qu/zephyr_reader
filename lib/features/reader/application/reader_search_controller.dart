import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../domain/services/highlight_painter.dart';

/// 页面内搜索控制器
///
/// 管理搜索面板的打开/关闭、查询词、匹配导航，无外部依赖。
@injectable
class ReaderSearchController {
  final showSearch = signal<bool>(false);
  final searchQuery = signal<String>('');
  final searchMatches = signal<int>(0);
  final searchCurrentIndex = signal<int>(0);
  final searchMatchParagraph = signal<int>(-1);

  void toggleSearch() {
    showSearch.value = !showSearch.value;
    if (!showSearch.value) {
      searchQuery.value = '';
      searchMatches.value = 0;
      searchCurrentIndex.value = 0;
      searchMatchParagraph.value = -1;
    }
  }

  void updateSearch(
    String query, {
    int matches = 0,
    int currentIndex = 0,
    int paragraphIndex = -1,
  }) {
    searchQuery.value = query;
    HighlightPainter.invalidateCache();
    searchMatches.value = matches;
    searchCurrentIndex.value = currentIndex.clamp(
      0,
      (matches - 1).clamp(0, 999999),
    );
    searchMatchParagraph.value = paragraphIndex;
  }

  void nextSearchMatch() {
    if (searchMatches.value <= 0) return;
    searchCurrentIndex.value =
        (searchCurrentIndex.value + 1) % searchMatches.value;
  }

  void prevSearchMatch() {
    if (searchMatches.value <= 0) return;
    searchCurrentIndex.value =
        (searchCurrentIndex.value - 1 + searchMatches.value) %
        searchMatches.value;
  }

  void dispose() {
    showSearch.dispose();
    searchQuery.dispose();
    searchMatches.dispose();
    searchCurrentIndex.dispose();
    searchMatchParagraph.dispose();
  }
}
