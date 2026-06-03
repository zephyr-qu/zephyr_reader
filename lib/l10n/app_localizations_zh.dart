// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Zephyr Reader';

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
  String get searchBooks => '搜索书籍';

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
  String get gridView => '网格视图';

  @override
  String get listView => '列表视图';

  @override
  String get noBooks => '暂无书籍';

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
  String get totalPages => '总页数';

  @override
  String get readingProgress => '阅读进度';

  @override
  String get readingTime => '阅读时长';

  @override
  String get readingCount => '阅读次数';

  @override
  String get estimatedRemaining => '预计剩余';

  @override
  String get startReading => '开始阅读';

  @override
  String get readFromBeginning => '从头开始';

  @override
  String get notesCount => '笔记数';

  @override
  String get highlightsCount => '高亮数';

  @override
  String get vocabularyCount => '生词数';

  @override
  String get edit => '编辑';

  @override
  String get share => '分享';

  @override
  String get exportNotes => '导出笔记';

  @override
  String get refresh => '刷新';

  @override
  String get delete => '删除';

  @override
  String get confirmDelete => '确认删除';

  @override
  String get cancel => '取消';

  @override
  String get reader => '阅读器';

  @override
  String get scrollMode => '滚动';

  @override
  String get pageTurnMode => '翻页';

  @override
  String get paginationMode => '分页';

  @override
  String get bilingualMode => '对照';

  @override
  String get horizontal => '横排';

  @override
  String get vertical => '竖排';

  @override
  String get fontSize => '字体大小';

  @override
  String get lineHeight => '行间距';

  @override
  String get letterSpacing => '字间距';

  @override
  String get paragraphSpacing => '段间距';

  @override
  String get pageMargin => '页边距';

  @override
  String get readingBackground => '阅读背景';

  @override
  String get brightness => '亮度';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get font => '字体';

  @override
  String get defaultFont => '系统默认';

  @override
  String chapterN(int n) {
    return '第 $n 章';
  }

  @override
  String pageInfo(int current, int total) {
    return '$current/$total';
  }

  @override
  String get bookmarks => '书签';

  @override
  String get addBookmark => '添加书签';

  @override
  String get noBookmarks => '暂无书签';

  @override
  String get searchInPage => '页面内查找';

  @override
  String get noResults => '无结果';

  @override
  String get ttsPlay => '朗读';

  @override
  String get ttsPause => '暂停';

  @override
  String get ttsStop => '停止';

  @override
  String get ttsSpeed => '语速';

  @override
  String get selectionCopy => '复制';

  @override
  String get selectionHighlight => '高亮';

  @override
  String get selectionNote => '笔记';

  @override
  String get selectionDictionary => '查词';

  @override
  String get selectionVocabulary => '生词本';

  @override
  String get selectionBilingual => '标注两侧';

  @override
  String get highlightYellow => '黄色';

  @override
  String get highlightGreen => '绿色';

  @override
  String get highlightBlue => '蓝色';

  @override
  String get highlightPink => '粉色';

  @override
  String get highlightPurple => '紫色';

  @override
  String get dictionary => '词典';

  @override
  String get lookupWord => '查词';

  @override
  String get addToVocabulary => '加入生词本';

  @override
  String get noDefinition => '未找到释义';

  @override
  String get vocabulary => '生词本';

  @override
  String get vocabularyBook => '生词本';

  @override
  String get wordCount => '词数';

  @override
  String get learning => '学习中';

  @override
  String get known => '已掌握';

  @override
  String get newWord => '新词';

  @override
  String get searchWords => '搜索单词';

  @override
  String get noWords => '暂无生词';

  @override
  String get statusUnlearned => '未学';

  @override
  String get statusLearning => '学习中';

  @override
  String get statusMastered => '已掌握';

  @override
  String get fromBook => '来自';

  @override
  String get statistics => '阅读统计';

  @override
  String get annualReport => '年度阅览报告';

  @override
  String get readingOverview => '阅读概览';

  @override
  String get weeklyOverview => '本周总览';

  @override
  String get readingDuration => '阅读时长';

  @override
  String get readingWords => '阅读字数';

  @override
  String get readingDays => '阅读天数';

  @override
  String get consecutiveDays => '连续阅读天数';

  @override
  String get booksCompleted => '读完书籍';

  @override
  String get readingSpeed => '平均阅读速度';

  @override
  String get wordsPerMinute => '字/分钟';

  @override
  String get readingFootprint => '阅读足迹';

  @override
  String get daysActive => '天活跃';

  @override
  String get readingTrend => '本周阅读趋势';

  @override
  String get readingRhythm => '阅读节奏';

  @override
  String recentDays(int days) {
    return '近 $days 天';
  }

  @override
  String get sessions => '阅读会话';

  @override
  String get settings => '设置';

  @override
  String get appSettings => '应用设置';

  @override
  String get readingSettings => '阅读设置';

  @override
  String get themeSettings => '主题设置';

  @override
  String get appearance => '阅读外观';

  @override
  String get readerBgColor => '阅读背景色';

  @override
  String get fontSettings => '字体设置';

  @override
  String get pageSettings => '翻页设置';

  @override
  String get screenSettings => '屏幕设置';

  @override
  String get keepScreenOn => '保持屏幕常亮';

  @override
  String get showBattery => '显示电量';

  @override
  String get showTime => '显示时间';

  @override
  String get clickZone => '点击区域';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get chinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get region => '地区';

  @override
  String get syncSettings => '同步设置';

  @override
  String get autoSync => '自动同步';

  @override
  String get manualSync => '手动同步';

  @override
  String get daily => '每天一次';

  @override
  String get weekly => '每周一次';

  @override
  String get backupRestore => '备份与恢复';

  @override
  String get backup => '备份数据';

  @override
  String get restore => '恢复数据';

  @override
  String get storageManagement => '存储管理';

  @override
  String get clearCache => '清理缓存';

  @override
  String get cacheSize => '缓存大小';

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
  String get sync => '同步';

  @override
  String get webdavConfig => 'WebDAV 配置';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get remotePath => '远程路径';

  @override
  String get testConnection => '测试连接';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncHistory => '同步历史';

  @override
  String get syncSuccess => '同步成功';

  @override
  String get syncFailed => '同步失败';

  @override
  String get lastSync => '上次同步';

  @override
  String get conflictResolution => '冲突解决';

  @override
  String get useLocal => '使用本地版本';

  @override
  String get useRemote => '使用远程版本';

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
  String get offline => '离线';

  @override
  String get empty => '暂无内容';

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
  String get globalSearch => '全局搜索';

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
  String bookImported(String title) {
    return '已导入：$title';
  }

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get scanningFolder => '正在扫描文件夹...';

  @override
  String get noBookFilesFound => '未找到书籍文件';

  @override
  String scanComplete(int count) {
    return '扫描完成，导入了 $count 本书';
  }

  @override
  String get showReadingProgress => '显示阅读进度';

  @override
  String get showRecentReading => '显示最近阅读';

  @override
  String get defaultSort => '默认排序';

  @override
  String get selectSortMethod => '选择排序方式';

  @override
  String get moveCategory => '移动分类';

  @override
  String get changeStatus => '更改状态';

  @override
  String get apply => '应用';

  @override
  String selectedBooksCount(int count) {
    return '已选 $count 本';
  }

  @override
  String get bookInfo => '书籍信息';

  @override
  String get chapterCountLabel => '章节数';

  @override
  String get totalChars => '总字符';

  @override
  String get addedTime => '添加时间';

  @override
  String get chapterList => '章节列表';

  @override
  String get collapse => '收起';

  @override
  String viewAllChapters(int count) {
    return '查看全部 $count 章';
  }

  @override
  String get category => '分类';

  @override
  String get weeklyReadingTime => '本周阅读时长';

  @override
  String get dangerZone => '危险操作';

  @override
  String get deleteBook => '删除本书';

  @override
  String get confirmDeleteBookMessage => '确定要删除本书吗？此操作不可恢复。';

  @override
  String deleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get loadFailed => '加载失败';

  @override
  String get appearanceSection => '外观主题';

  @override
  String get readingModeSection => '阅读模式';

  @override
  String get layoutSection => '版面布局';

  @override
  String get typographySection => '文字排版';

  @override
  String get searchInChapterHint => '在章节内搜索...';

  @override
  String get previous => '上一个';

  @override
  String get next => '下一个';

  @override
  String get currentlyReading => '正在阅读';

  @override
  String get setBilingualTranslation => '设置对照译文';

  @override
  String get pasteTranslationHint => '粘贴或输入当前章节的译文内容：';

  @override
  String get addNote => '添加笔记';

  @override
  String get noteHintText => '输入你的笔记内容…';

  @override
  String get editNote => '编辑笔记';

  @override
  String get deleteHighlight => '删除高亮';

  @override
  String get profileDisplayName => '书友';

  @override
  String get profileTagline => '阅读是一种生活态度';

  @override
  String get consecutiveDaysLabel => '连续天数';

  @override
  String get sectionStudyMgmt => '学习与管理';

  @override
  String get sectionReadingExp => '阅读体验';

  @override
  String get sectionSystem => '系统';

  @override
  String get learningNotes => '学习与笔记';

  @override
  String get readingSessions => '阅读会话';

  @override
  String get storageSync => '存储与同步';

  @override
  String get ttsSettings => '朗读设置';

  @override
  String get typographySettings => '排版与字体';

  @override
  String get themeBrightness => '主题与亮度';

  @override
  String get otherSettings => '其他设置';

  @override
  String get synced => '已同步';

  @override
  String appVersionDisplay(String version) {
    return 'Zephyr Reader v$version';
  }

  @override
  String get appIntroduction => '应用介绍';

  @override
  String get coreFeatures => '核心特性';

  @override
  String get techStack => '技术栈';

  @override
  String get moreInfo => '更多信息';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get openSourceLicense => '开源许可证';

  @override
  String get feedback => '问题反馈';

  @override
  String get alreadyLatestVersion => '已是最新版本';

  @override
  String get cannotOpenLink => '无法打开链接';

  @override
  String get aboutFeature1 => '纯离线使用，无需网络';

  @override
  String get aboutFeature2 => '支持 EPUB、TXT、PDF 格式';

  @override
  String get aboutFeature3 => '智能排版引擎';

  @override
  String get aboutFeature4 => '双语对照阅读';

  @override
  String get aboutFeature5 => '生词本与学习记录';

  @override
  String get aboutFeature6 => 'WebDAV 多端同步';

  @override
  String get copyrightFooter => '© 2026 Zephyr Reader';

  @override
  String get madeWithFooter => 'Made with Flutter · Rust · ❤';

  @override
  String get errorFileNotFound => '文件不存在';

  @override
  String get errorFileReadError => '文件读取失败';

  @override
  String get errorUnsupportedFormat => '不支持的格式';

  @override
  String get errorEpubParse => 'EPUB 解析错误';

  @override
  String get errorDatabase => '数据库错误';

  @override
  String get errorInternal => '内部错误';

  @override
  String errorTaskPanic(String task) {
    return '任务执行异常：$task';
  }

  @override
  String get selectDictionaryFile => '选择词典文件';

  @override
  String get selectMdxDescription => '请选择一个 .mdx 格式的词典文件…';

  @override
  String get invalidMdxFile => '请选择有效的 .mdx 文件';

  @override
  String get dictionaryLoadFailed => '词典加载失败，请检查文件是否有效';

  @override
  String get pronunciation => '发音';

  @override
  String get noExactMatch => '未找到精确匹配，您是否想查：';

  @override
  String get wordSegmentation => '分词：';

  @override
  String get bilingualNoAlignment => '没有对照译文，无法创建双语高亮';

  @override
  String get bilingualNoParagraph => '未找到对应的段落';

  @override
  String get bilingualHighlightCreated => '双语高亮已创建';

  @override
  String get selectFile => '选择文件';

  @override
  String get categoryManagement => '标签管理';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutTagline => '如和风般轻盈的阅读体验';

  @override
  String get aboutSectionFeatures => '核心特性';

  @override
  String get aboutSectionTechStack => '技术栈';

  @override
  String get aboutSectionLinks => '更多信息';

  @override
  String get aboutDescription =>
      'Zephyr Reader 是一款基于 Flutter + Rust 架构的离线双语小说阅读器。纯本地设计，无后台、无广告、无数据收集，专注于中英双语阅读体验。';

  @override
  String get aboutFeatureOffline => '纯离线使用';

  @override
  String get aboutFeatureOfflineDesc => '核心功能 100% 离线可用，无后台无广告';

  @override
  String get aboutFeaturePerformance => '高性能解析';

  @override
  String get aboutFeaturePerformanceDesc => 'Rust 引擎驱动，大文件瞬间解析';

  @override
  String get aboutFeatureBilingual => '双语排版';

  @override
  String get aboutFeatureBilingualDesc => '中英文同等优先，优雅对照阅读';

  @override
  String get aboutFeatureThemes => '多主题支持';

  @override
  String get aboutFeatureThemesDesc => '亮色 / 深色 / 纯黑夜间模式';

  @override
  String get aboutFeatureAdaptive => '设备适配';

  @override
  String get aboutFeatureAdaptiveDesc => '手机与平板双端自适应布局';

  @override
  String get aboutFeatureSync => 'WebDAV 同步';

  @override
  String get aboutFeatureSyncDesc => '跨设备数据同步与安全备份';

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
  String get prev => '上一个';

  @override
  String get readAloud => '朗读';

  @override
  String addedToVocabulary(String word) {
    return '已加入生词本：$word';
  }

  @override
  String addToVocabFailed(String error) {
    return '加入生词本失败：$error';
  }

  @override
  String get readerThemeLight => '日间';

  @override
  String get readerThemeDark => '夜间';

  @override
  String get readerThemeSepia => '护眼';

  @override
  String get readerFontSizeSmall => '小';

  @override
  String get readerFontSizeMedium => '中';

  @override
  String get readerFontSizeLarge => '大';

  @override
  String get readerFontSizeXLarge => '特大';

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
  String get themeSystem => '系统';

  @override
  String get introLabel => '简介';

  @override
  String get currentChapter => '当前';

  @override
  String get bookTitle => '书名';

  @override
  String get editMetadata => '编辑元数据';

  @override
  String get statReadingTime => '累计时长';

  @override
  String get statReadingCount => '阅读次数';

  @override
  String get statEstimatedRemaining => '预计剩余';

  @override
  String get expand => '展开';

  @override
  String tocTitle(int count) {
    return '目录（$count 章）';
  }

  @override
  String totalChapters(int count) {
    return '$count 章';
  }

  @override
  String get isbn => 'ISBN';

  @override
  String get bookIntro => '简介';

  @override
  String get timePresetSunsetToSunrise => '日落到日出';

  @override
  String get timePresetEveningToMorning => '傍晚到早晨';

  @override
  String get timePresetCustom => '自定义';

  @override
  String get appTheme => '应用主题';

  @override
  String get bookFormat => '格式';

  @override
  String get bookIntroLabel => '简介';

  @override
  String get sortDialogTitle => '选择排序方式';

  @override
  String get tapLayoutRightHanded => '右手模式';

  @override
  String get tapLayoutLeftHanded => '左手模式';

  @override
  String get tapLayout => '点击区域';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String lastSyncTime(String time) {
    return '上次同步：$time';
  }
}
