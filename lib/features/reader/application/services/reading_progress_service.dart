/// 阅读进度服务
///
/// 功能�?/// - 保存和加载阅读进�?/// - 记录阅读时长
/// - �?Rust 引擎同步进度
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读进度服务
class ReadingProgressService {
  final SharedPreferences? _prefs;

  ReadingProgressService(this._prefs);

  static const String _prefix = 'reading_progress_';

  /// 更新阅读进度
  void updateReadingProgress({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required int totalPages,
  }) {
    if (_prefs == null) return;

    final key = '$_prefix$bookId';
    final data = {
      'chapterId': chapterId,
      'pageIndex': pageIndex,
      'totalPages': totalPages,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _prefs.setString(key, jsonEncode(data));
    debugPrint(
      '保存进度：book=$bookId, chapter=$chapterId, page=$pageIndex/$totalPages',
    );
  }

  /// 加载阅读进度
  Map<String, dynamic>? loadReadingProgress(int bookId) {
    if (_prefs == null) return null;

    final key = '$_prefix$bookId';
    final data = _prefs.getString(key);
    if (data == null) return null;

    return jsonDecode(data) as Map<String, dynamic>;
  }

  /// 清除阅读进度
  void clearReadingProgress(int bookId) {
    if (_prefs == null) return;

    final key = '$_prefix$bookId';
    _prefs.remove(key);
  }

  /// 获取所有阅读进�?
   Map<int, Map<String, dynamic>> getAllReadingProgress() {
    final result = <int, Map<String, dynamic>>{};

    if (_prefs == null) return result;

    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final bookId = int.tryParse(key.substring(_prefix.length));
        if (bookId != null) {
          final data = _prefs.getString(key);
          if (data != null) {
            result[bookId] = jsonDecode(data) as Map<String, dynamic>;
          }
        }
      }
    }

    return result;
  }
}
