abstract class RoutePaths {
  static const String splash = '/';
  static const String home = '/home';
  static const String bookshelf = '/bookshelf';
  static const String bookDetail = '/books/:id';
  static const String reader = '/reader/:bookId/:chapterId';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String articles = '/articles';
  static const String articleDetail = '/articles/:id';
  static const String statistics = '/statistics';
  static const String categoryManagement = '/bookshelf/categories';

  // 设置相关
  static const String readingSettings = '/settings/reading';
  static const String appSettings = '/settings/app';
  static const String themeSettings = '/settings/theme';
  static const String about = '/about';

  // 同步相关
  static const String sync = '/settings/sync';
  static const String syncHistory = '/settings/sync/history';
  static const String backupRestore = '/settings/sync/backup';

  // 全书搜索
  static const String bookSearch = '/search/book';

  // 阅读统计详情
  static const String readingStats = '/statistics/detail';

  // 笔记管理
  static const String noteManage = '/reader/:bookId/notes';

  // 书签管理
  static const String bookmarkManage = '/reader/:bookId/bookmarks';

  // 生词本
  static const String vocabulary = '/vocabulary';
}

abstract class RouteNames {
  static const String splash = 'splash';
  static const String home = 'home';
  static const String bookshelf = 'bookshelf';
  static const String bookDetail = 'bookDetail';
  static const String reader = 'reader';
  static const String search = 'search';
  static const String settings = 'settings';
  static const String profile = 'profile';
  static const String articles = 'articles';
  static const String articleDetail = 'articleDetail';
  static const String statistics = 'statistics';
  static const String categoryManagement = 'categoryManagement';

  // 设置相关
  static const String readingSettings = 'readingSettings';
  static const String appSettings = 'appSettings';
  static const String themeSettings = 'themeSettings';
  static const String about = 'about';

  // 同步相关
  static const String sync = 'sync';
  static const String syncHistory = 'syncHistory';
  static const String backupRestore = 'backupRestore';

  // 全书搜索
  static const String bookSearch = 'bookSearch';

  // 阅读统计详情
  static const String readingStats = 'readingStats';

  // 笔记管理
  static const String noteManage = 'noteManage';

  // 书签管理
  static const String bookmarkManage = 'bookmarkManage';

  // 生词本
  static const String vocabulary = 'vocabulary';
}
