/// 路由路径常量定义
///
/// 集中管理应用中所有路由的路径模式字符串，用于 [GoRouter] 路由配置。
/// 使用路径参数（如 `/reader/:bookId/:chapterId`）标识动态路由。
abstract class RoutePaths {
  static const String splash = '/';
  static const String home = '/home';
  static const String bookshelf = '/bookshelf';
  static const String bookDetail = '/books/:id';
  static const String reader = '/reader/:bookId/:chapterId';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String statistics = '/statistics';
  static const String categoryManagement = '/bookshelf/categories';
  // 设置相关
  static const String about = '/about';

  // 全书搜索
  static const String bookSearch = '/search/book';

  // 书签管理
  static const String bookmarkManage = '/reader/:bookId/bookmarks';

  // 生词本
  static const String vocabulary = '/vocabulary';

  // 学习与笔记
  static const String learningNotes = '/learning-notes';

  // 阅读会话
  static const String readingSessions = '/statistics/sessions';

  // 缓存管理
  static const String cacheManage = '/settings/cache';

  // 存储与同步
  static const String storageSync = '/settings/storage-sync';

  // TTS 朗读设置
  static const String ttsSettings = '/settings/tts';

  // 排版与字体设置
  static const String typographySettings = '/settings/typography';

  // 主题与亮度
  static const String themeBrightness = '/settings/theme';

  // 其他设置
  static const String otherSettings = '/settings/other';

  // WiFi 传书
  static const String wifiTransfer = '/wifi-transfer';

  // 本地备份恢复
  static const String localBackup = '/settings/local-backup';
}

/// 路由名称常量定义
///
/// 集中管理应用中所有路由的命名标识，用于程序化导航和路由识别。
/// 与 [RoutePaths] 中的路径一一对应。
abstract class RouteNames {
  static const String splash = 'splash';
  static const String home = 'home';
  static const String bookshelf = 'bookshelf';
  static const String bookDetail = 'bookDetail';
  static const String reader = 'reader';
  static const String search = 'search';
  static const String settings = 'settings';
  static const String profile = 'profile';
  static const String statistics = 'statistics';
  static const String categoryManagement = 'categoryManagement';

  // 设置相关
  static const String about = 'about';

  // 全书搜索
  static const String bookSearch = 'bookSearch';

  // 书签管理
  static const String bookmarkManage = 'bookmarkManage';

  // 生词本
  static const String vocabulary = 'vocabulary';

  // 学习与笔记
  static const String learningNotes = 'learningNotes';

  // 阅读会话
  static const String readingSessions = 'readingSessions';

  // 缓存管理
  static const String cacheManage = 'cacheManage';

  // 存储与同步
  static const String storageSync = 'storageSync';

  // TTS 朗读设置
  static const String ttsSettings = 'ttsSettings';

  // 排版与字体设置
  static const String typographySettings = 'typographySettings';

  // 主题与亮度
  static const String themeBrightness = 'themeBrightness';

  // 其他设置
  static const String otherSettings = 'otherSettings';

  // WiFi 传书
  static const String wifiTransfer = 'wifiTransfer';

  // 本地备份恢复
  static const String localBackup = 'localBackup';
}
