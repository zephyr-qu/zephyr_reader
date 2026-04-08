/// 笔记服务（简化版）
///
/// TODO: 等待 FRB 正确生成 DbNote 类型后完善
library;

/// 笔记服务
class NoteService {
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  static NoteService get instance => _instance;

  /// 获取笔记统计
  Future<Map<String, int>> getNoteStats(String bookId) async {
    // TODO: 实现获取笔记统计
    return {'total': 0, 'highlights': 0, 'annotations': 0};
  }
}
