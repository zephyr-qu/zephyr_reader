// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tabHome => '首页';

  @override
  String get tabBookshelf => '书架';

  @override
  String get tabStatistics => '统计';

  @override
  String get tabProfile => '我的';

  @override
  String get back => '返回';

  @override
  String get continueReading => '继续阅读';

  @override
  String get recentReading => '最近阅读';

  @override
  String get noReadingRecord => '暂无阅读记录';

  @override
  String get bookshelf => '书架';

  @override
  String get importBook => '导入书籍';

  @override
  String get all => '全部';

  @override
  String get reading => '在读';

  @override
  String get notStarted => '未开始';

  @override
  String get finished => '已读完';

  @override
  String get listView => '列表视图';

  @override
  String get bookDetail => '书籍详情';

  @override
  String get author => '作者';

  @override
  String get translator => '译者';

  @override
  String get publisher => '出版社';

  @override
  String get format => '格式';

  @override
  String get fileSize => '文件大小';

  @override
  String get readingProgress => '阅读进度';

  @override
  String get readingTime => '阅读时长';

  @override
  String estimatedTime(Object hours, Object minutes) {
    return '约 $hours小时$minutes分钟';
  }

  @override
  String estimatedTimeShort(Object minutes) {
    return '约 $minutes分钟';
  }

  @override
  String get startReading => '开始阅读';

  @override
  String get readFromBeginning => '从头开始';

  @override
  String get edit => '编辑';

  @override
  String get exportNotes => '导出笔记';

  @override
  String get refresh => '刷新';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get reader => '阅读器';

  @override
  String get scrollMode => '滚动';

  @override
  String get paginationMode => '分页';

  @override
  String get fontSize => '字体大小';

  @override
  String get fontFamily => '字体';

  @override
  String get fontWeight => '字重';

  @override
  String get lineHeight => '行间距';

  @override
  String get letterSpacing => '字间距';

  @override
  String get paragraphSpacing => '段间距';

  @override
  String get paragraphIndent => '首行缩进';

  @override
  String get textAlignment => '文本对齐';

  @override
  String get textAlignAuto => '默认';

  @override
  String get textAlignLeft => '左对齐';

  @override
  String get textAlignJustify => '两端对齐';

  @override
  String get pageMargin => '页边距';

  @override
  String get brightness => '亮度';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get font => '字体';

  @override
  String get bookmarks => '书签';

  @override
  String get addBookmark => '添加书签';

  @override
  String get ttsSpeed => '语速';

  @override
  String get wordCount => '词数';

  @override
  String get statistics => '阅读统计';

  @override
  String get booksCompleted => '读完书籍';

  @override
  String get readingTrend => '本周阅读趋势';

  @override
  String get sessions => '阅读会话';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get chinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get backup => '备份数据';

  @override
  String get clearCache => '清理缓存';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get userAgreement => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get resetToDefault => '重置为默认值';

  @override
  String get dataCleared => '已清理缓存';

  @override
  String dataClearFailed(Object error) {
    return '清理缓存失败：$error';
  }

  @override
  String get loading => '加载中…';

  @override
  String get error => '出错了';

  @override
  String get retry => '重试';

  @override
  String get save => '保存';

  @override
  String get close => '关闭';

  @override
  String get confirm => '确定';

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get unknownError => '未知错误';

  @override
  String get search => '搜索';

  @override
  String get unknownAuthor => '未知作者';

  @override
  String get greetingMorning => '早上好';

  @override
  String get greetingNoon => '中午好';

  @override
  String get greetingAfternoon => '下午好';

  @override
  String get greetingEvening => '晚上好';

  @override
  String get greetingLateNight => '夜深了';

  @override
  String get startReadingJourney => '开始你的阅读之旅';

  @override
  String get exploreNewWorld => '打开一本书，探索新的世界';

  @override
  String get goToBookshelf => '去书库';

  @override
  String get splashTagline => '轻如风，阅无界';

  @override
  String get bookshelfSearchHint => '搜索书籍...';

  @override
  String get bookshelfSettings => '书架设置';

  @override
  String get bookshelfEmpty => '书架空空如也';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get scanFolder => '扫描文件夹';

  @override
  String get batchManage => '批量管理';

  @override
  String get editCategory => '编辑分类';

  @override
  String get markAsUnread => '标记为未开始';

  @override
  String get markAsReading => '标记为阅读中';

  @override
  String get reExtractCover => '补提取封面';

  @override
  String get unpin => '取消置顶';

  @override
  String get pinTop => '置顶';

  @override
  String get selectCategory => '选择分类';

  @override
  String bookImported(Object title) {
    return '已导入：$title';
  }

  @override
  String importFailed(Object error) {
    return '导入失败：$error';
  }

  @override
  String get scanningFolder => '正在扫描文件夹...';

  @override
  String get noBookFilesFound => '未找到书籍文件';

  @override
  String scanComplete(Object count) {
    return '扫描完成，导入了 $count 本书';
  }

  @override
  String scanProgress(Object done, Object total) {
    return '正在扫描 $done/$total...';
  }

  @override
  String scanCompleteWithFailures(Object fail, Object success) {
    return '扫描完成，导入了 $success 本，导入失败 $fail 本';
  }

  @override
  String get showReadingProgress => '显示阅读进度';

  @override
  String get defaultSort => '默认排序';

  @override
  String get moveCategory => '移动分类';

  @override
  String get changeStatus => '更改状态';

  @override
  String get apply => '应用';

  @override
  String selectedBooksCount(Object count) {
    return '已选 $count 本';
  }

  @override
  String get addedTime => '添加时间';

  @override
  String get chapterList => '章节列表';

  @override
  String get collapse => '收起';

  @override
  String get category => '分类';

  @override
  String get dangerZone => '危险操作';

  @override
  String get deleteBook => '删除本书';

  @override
  String get confirmDeleteBookMessage => '确定要删除本书吗？此操作不可恢复。';

  @override
  String deleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String get loadFailed => '加载失败';

  @override
  String get appearanceSection => '阅读外观';

  @override
  String get readingModeSection => '阅读模式';

  @override
  String get typographySection => '文字排版';

  @override
  String get previous => '上一个';

  @override
  String get next => '下一个';

  @override
  String get profileDisplayName => '书友';

  @override
  String get profileTagline => '阅读是一种生活态度';

  @override
  String get sectionSystem => '系统';

  @override
  String get sectionReadingData => '阅读数据';

  @override
  String get sectionReadingTools => '阅读工具';

  @override
  String get sectionDisplayAppearance => '显示与外观';

  @override
  String get readingSessions => '阅读记录';

  @override
  String get dataManagement => '数据管理';

  @override
  String get ttsSettings => '朗读设置';

  @override
  String get typographySettings => '排版与字体';

  @override
  String get themeBrightness => '主题与亮度';

  @override
  String get otherSettings => '其他设置';

  @override
  String appVersionDisplay(Object version) {
    return 'Zephyr Reader v$version';
  }

  @override
  String get checkUpdate => '检查更新';

  @override
  String get openSourceLicense => '开源许可证';

  @override
  String get feedback => '问题反馈';

  @override
  String get categoryManagement => '分类管理';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutTagline => '轻如风，阅无界';

  @override
  String get aboutSectionFeatures => '核心特性';

  @override
  String get aboutSectionTechStack => '技术栈';

  @override
  String get aboutSectionLinks => '链接';

  @override
  String get aboutDescription =>
      'Zephyr Reader 是一款纯离线的阅读器，Flutter + Rust 构建，100% 本地，无后端，无广告，无数据收集，专注于中英文阅读体验。';

  @override
  String get aboutFeatureOffline => '完全离线';

  @override
  String get aboutFeatureOfflineDesc => '核心功能无需网络，无后端无广告';

  @override
  String get aboutFeaturePerformance => '高性能';

  @override
  String get aboutFeaturePerformanceDesc => 'Rust 引擎即时解析大文件';

  @override
  String get aboutFeatureThemes => '多主题';

  @override
  String get aboutFeatureThemesDesc => '浅色/深色/纯黑夜间模式';

  @override
  String get aboutFeatureAdaptive => '自适应布局';

  @override
  String get aboutFeatureAdaptiveDesc => '手机和平板自动适配';

  @override
  String get aboutCheckUpdate => '检查更新';

  @override
  String get aboutLatestVersion => '已是最新版本';

  @override
  String get aboutUserAgreement => '用户协议';

  @override
  String get aboutPrivacyPolicy => '隐私政策';

  @override
  String get aboutOpenSourceLicense => '开源许可证';

  @override
  String get aboutFeedback => '问题反馈';

  @override
  String get aboutCannotOpenLink => '无法打开链接';

  @override
  String get unknownVersion => '未知';

  @override
  String get readAloud => '朗读';

  @override
  String get readingAssist => '阅读辅助';

  @override
  String get readerThemeLight => '白天';

  @override
  String get readerThemeDark => '夜间';

  @override
  String get readerThemeSepia => '护眼';

  @override
  String get readerCustomBackground => '自定义背景';

  @override
  String get readerCustomBackgroundDisabled => '深色和护眼主题使用固定背景';

  @override
  String get sortLastRead => '最近阅读';

  @override
  String get sortCreatedAt => '添加时间';

  @override
  String get sortTitle => '书名';

  @override
  String get sortAuthor => '作者';

  @override
  String get sortProgress => '阅读进度';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get introLabel => '简介';

  @override
  String get bookTitle => '书名';

  @override
  String get currentChapter => '当前';

  @override
  String get editMetadata => '编辑元数据';

  @override
  String get statReadingTime => '阅读时长';

  @override
  String get statReadingCount => '阅读次数';

  @override
  String get statEstimatedRemaining => '预计剩余';

  @override
  String get expand => '展开';

  @override
  String tocTitle(Object count) {
    return '目录（$count 章）';
  }

  @override
  String get isbn => 'ISBN';

  @override
  String get appTheme => '应用主题';

  @override
  String get autoTheme => '自动主题';

  @override
  String get bookFormat => '格式';

  @override
  String get sortDialogTitle => '选择排序方式';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(Object minutes) {
    return '$minutes 分钟前';
  }

  @override
  String timeHoursAgo(Object hours) {
    return '$hours 小时前';
  }

  @override
  String get todayReading => '今日阅读';

  @override
  String get minutes => '分钟';

  @override
  String goalTemplate(Object minutes) {
    return '目标 $minutes 分钟';
  }

  @override
  String get streakLabel => '连续阅读';

  @override
  String get daysUnit => '天';

  @override
  String booksRead(Object count) {
    return '读过 $count 本书';
  }

  @override
  String get insufficientData => '数据不足';

  @override
  String get readingHeatmap => '阅读热力图';

  @override
  String get noSessions => '暂无阅读会话';

  @override
  String get autoRecordHint => '开始阅读后会自动记录';

  @override
  String get sessionDetails => '会话详情';

  @override
  String get unknownBook => '未知书籍';

  @override
  String sessionSummary(Object count, Object duration) {
    return '共 $count 次 · $duration';
  }

  @override
  String chapterInfo(Object index) {
    return '第 $index 章';
  }

  @override
  String get deleteSessionTitle => '删除会话记录';

  @override
  String get deleteSessionConfirm => '确定要删除本书的所有阅读会话记录吗？';

  @override
  String get periodToday => '本日';

  @override
  String get periodWeek => '本周';

  @override
  String get periodMonth => '本月';

  @override
  String get periodYear => '全年';

  @override
  String get totalReadingTime => '总阅读时长';

  @override
  String get sessionsCount => '次会话';

  @override
  String batchDeleteConfirm(Object count) {
    return '确定要删除选中的 $count 本书吗？';
  }

  @override
  String get categoryName => '分类名称';

  @override
  String get addCategory => '添加分类';

  @override
  String get deleteCategory => '删除分类';

  @override
  String confirmDeleteCategory(Object name) {
    return '确定要删除分类「$name」吗？关联书籍不会受影响。';
  }

  @override
  String get categoryNameRequired => '请输入分类名称';

  @override
  String get noCategories => '暂无分类';

  @override
  String get addCategoryHint => '点击右上角添加分类';

  @override
  String get backupSuccess => '备份成功';

  @override
  String backupFailed(Object error) {
    return '备份失败：$error';
  }

  @override
  String get restoreSuccess => '恢复成功';

  @override
  String restoreFailed(Object error) {
    return '恢复失败：$error';
  }

  @override
  String get clear => '清除';

  @override
  String get restoreRestartNotice => '数据已还原，请重启应用以生效。';

  @override
  String get restoreTitle => '从备份还原';

  @override
  String get restoreSubtitle => '选择一个 .db 备份文件恢复数据';

  @override
  String get restoring => '恢复中…';

  @override
  String get neverBackedUp => '尚未进行过备份';

  @override
  String timeDaysAgo(Object days) {
    return '$days 天前';
  }

  @override
  String timeMonthsAgo(Object months) {
    return '$months 个月前';
  }

  @override
  String get restoreConfirmTitle => '确认还原';

  @override
  String get restoreConfirmWarning => '此操作将覆盖当前所有数据。请确认该备份文件来源可信。';

  @override
  String get restoreConfirmAction => '确认还原';

  @override
  String get restoreStatVersion => '备份版本';

  @override
  String get restoreStatExportedAt => '导出时间';

  @override
  String get restoreStatBooks => '书籍';

  @override
  String get restoreStatNotes => '笔记';

  @override
  String get restoreStatBookmarks => '书签';

  @override
  String get secondsUnit => '秒';

  @override
  String get hoursUnit => '小时';

  @override
  String get charsUnit => '字';

  @override
  String get thousandCharsUnit => '千';

  @override
  String get byteUnit => 'B';

  @override
  String get kilobyteUnit => 'KB';

  @override
  String get megabyteUnit => 'MB';

  @override
  String get gigabyteUnit => 'GB';

  @override
  String get livePreview => '实时预览';

  @override
  String get autoScroll => '自动翻页';

  @override
  String get autoScrollSpeed => '翻页间隔';

  @override
  String get ttsPitch => '音调';

  @override
  String get otherBehavior => '应用行为';

  @override
  String get languageSubtitle => '简体中文 / English';

  @override
  String get otherNotifications => '通知与提醒';

  @override
  String get otherNotificationsDesc => '阅读目标提醒';

  @override
  String get otherStartupCheck => '启动时检查更新';

  @override
  String get otherStartupCheckDesc => '仅前台启动时检测新版本';

  @override
  String get otherExperimental => '实验性功能';

  @override
  String get otherLegal => '法律与合规';

  @override
  String get openSourceLicenseDesc => 'Flutter / Rust / 第三方库许可';

  @override
  String get resetAllSettings => '重置所有设置';

  @override
  String get resetAllSettingsDesc => '恢复默认排版、主题等设置';

  @override
  String get clearAllData => '清理缓存';

  @override
  String get clearAllDataDesc => '清除阅读缓存和临时文件，不影响个人数据';

  @override
  String get confirmReset => '确认重置';

  @override
  String get confirmResetContent => '此操作将恢复排版、主题等所有设置为默认值。\n\n不会删除书籍和阅读进度。';

  @override
  String get clearAllDataTitle => '清理缓存';

  @override
  String get clearAllDataContent => '此操作将清除阅读缓存和临时文件。\n\n不会删除书籍和阅读进度。';

  @override
  String get confirmClear => '确认清除';

  @override
  String get readingMode => '阅读模式';

  @override
  String get deleteBookmark => '删除书签';

  @override
  String get add => '添加';

  @override
  String get charOffset => '偏移';

  @override
  String get themePreviewSampleText => '春风又绿江南岸，明月何时照我还。';
}
