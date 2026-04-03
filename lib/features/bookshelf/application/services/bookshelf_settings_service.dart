/// 书架设置服务
///
/// 管理书架页面的显示设置
library;

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 书架排序方式
enum BookshelfSortType {
  lastRead('last_read', '最近阅读'),
  createdAt('created_at', '添加时间'),
  title('title', '书名'),
  author('author', '作者'),
  progress('progress', '阅读进度');

  final String key;
  final String displayName;

  const BookshelfSortType(this.key, this.displayName);

  static BookshelfSortType fromKey(String key) {
    return BookshelfSortType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => BookshelfSortType.lastRead,
    );
  }
}

/// 书架设置服务
@singleton
class BookshelfSettingsService {
  final SharedPreferences _prefs;

  /// 显示阅读进度
  final showReadingProgress = signal<bool>(true);

  /// 显示最近阅读
  final showRecentReading = signal<bool>(true);

  /// 默认排序方式
  final defaultSortType = signal<BookshelfSortType>(BookshelfSortType.lastRead);

  static const String _keyShowReadingProgress =
      'bookshelf.show_reading_progress';
  static const String _keyShowRecentReading = 'bookshelf.show_recent_reading';
  static const String _keyDefaultSortType = 'bookshelf.default_sort_type';

  BookshelfSettingsService(this._prefs) {
    _loadSettings();
  }

  /// 加载设置
  void _loadSettings() {
    showReadingProgress.value = _prefs.getBool(_keyShowReadingProgress) ?? true;
    showRecentReading.value = _prefs.getBool(_keyShowRecentReading) ?? true;
    defaultSortType.value = BookshelfSortType.fromKey(
      _prefs.getString(_keyDefaultSortType) ?? 'last_read',
    );
  }

  /// 保存显示阅读进度设置
  Future<void> setShowReadingProgress(bool value) async {
    showReadingProgress.value = value;
    await _prefs.setBool(_keyShowReadingProgress, value);
  }

  /// 保存显示最近阅读设置
  Future<void> setShowRecentReading(bool value) async {
    showRecentReading.value = value;
    await _prefs.setBool(_keyShowRecentReading, value);
  }

  /// 保存默认排序方式
  Future<void> setDefaultSortType(BookshelfSortType type) async {
    defaultSortType.value = type;
    await _prefs.setString(_keyDefaultSortType, type.key);
  }

  /// 显示排序选项对话框
  Future<BookshelfSortType?> showSortTypeDialog(BuildContext context) async {
    return showDialog<BookshelfSortType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择排序方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BookshelfSortType.values.map((type) {
            return ListTile(
              title: Text(type.displayName),
              trailing: defaultSortType.value == type
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(context, type),
            );
          }).toList(),
        ),
      ),
    );
  }
}
