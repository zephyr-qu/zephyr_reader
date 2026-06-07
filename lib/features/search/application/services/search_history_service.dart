/// 搜索历史记录服务（内存存储，应用重启后清空）。
class SearchHistoryService {
  final List<String> _history = [];
  static const int maxHistory = 20;

  List<String> getHistory() => List.unmodifiable(_history);

  void addHistory(String query) {
    if (query.trim().isEmpty) return;
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > maxHistory) _history.removeLast();
  }

  void clearHistory() => _history.clear();

  void removeHistory(String query) => _history.remove(query);
}
