/// 备份对话框
///
/// 提供创建备份的对话框组件
library;

/// 备份数据类型
enum BackupType { readingProgress, bookmarks, bookshelf, settings, all }

String backupTypeName(BackupType type) {
  switch (type) {
    case BackupType.all:
      return '全部数据';
    case BackupType.readingProgress:
      return '阅读进度';
    case BackupType.bookmarks:
      return '书签';
    case BackupType.bookshelf:
      return '书架';
    case BackupType.settings:
      return '设置';
  }
}
