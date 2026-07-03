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
  String get fontSize => '字体大小';

  @override
  String get followSystemFontScale => '跟随系统';

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
  String chapterN(Object n) {
    return '第 $n 章';
  }

  @override
  String pageInfo(Object current, Object total) {
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
  String get dictionary => '词典管理';

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
  String recentDays(Object days) {
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
  String get manualSync => '手动同步';

  @override
  String get daily => '每天一次';

  @override
  String get weekly => '每周一次';

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
  String get selectPreset => '选择预设';

  @override
  String get clearConfig => '清除配置';

  @override
  String get serverUrlRequired => '请输入服务器地址';

  @override
  String get serverUrlInvalid => '请输入完整的 URL（包含 http:// 或 https://）';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get remotePathRequired => '请输入远程路径';

  @override
  String get remotePathInvalid => '远程路径应以 / 开头';

  @override
  String get configSaved => 'WebDAV 配置已保存';

  @override
  String get saveConfigFailed => '保存配置失败';

  @override
  String get configCleared => '配置已清除';

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
  String get syncConfigInvalid => '同步配置无效，请检查 WebDAV 设置';

  @override
  String get dataCleared => '已清理缓存';

  @override
  String dataClearFailed(Object error) {
    return '清理缓存失败：$error';
  }

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
  String get confirmAgain => '二次确认';

  @override
  String get continueAction => '继续';

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get offline => '离线';

  @override
  String get empty => '暂无内容';

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
  String get selectSortMethod => '选择排序方式';

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
  String viewAllChapters(Object count) {
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
  String deleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String get loadFailed => '加载失败';

  @override
  String get saveHighlightFailed => '保存高亮失败';

  @override
  String get saveAnnotationFailed => '保存笔记失败';

  @override
  String get deleteHighlightFailed => '删除高亮失败';

  @override
  String get updateNoteFailed => '更新笔记失败';

  @override
  String get bilingualHighlightFailed => '双语高亮创建失败';

  @override
  String chapterLoadFailed(Object error) {
    return '章节加载失败：$error';
  }

  @override
  String get epubRichTextSkipped => '本章内容较大，已以纯文本显示（图片与样式暂不可用）';

  @override
  String get contentEmpty => '内容为空';

  @override
  String get appearanceSection => '外观主题';

  @override
  String get readingModeSection => '阅读模式';

  @override
  String get typographySection => '文字排版';

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
  String get pasteTranslationPlaceholder => '在此粘贴译文文本…';

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
  String get sectionReadingData => '阅读数据';

  @override
  String get sectionReadingTools => '阅读工具';

  @override
  String get sectionDisplayAppearance => '显示与外观';

  @override
  String get learningNotes => '阅读笔记';

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
  String get synced => '已同步';

  @override
  String appVersionDisplay(Object version) {
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
  String get aboutFeature2 => '支持 EPUB、TXT 格式';

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
  String get madeWithFooter => '用 Flutter · Rust · ❤ 构建';

  @override
  String get errorFileNotFound => '文件未找到';

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
  String errorTaskPanic(Object task) {
    return '任务失败：$task';
  }

  @override
  String get selectDictionaryFile => '选择词典文件';

  @override
  String get selectMdxDescription => '请选择一个 .mdx 词典文件…';

  @override
  String get invalidMdxFile => '请选择有效的 .mdx 文件';

  @override
  String get dictionaryLoadFailed => '词典加载失败，请检查文件';

  @override
  String get pronunciation => '发音';

  @override
  String get noExactMatch => '未找到精确匹配。您是不是要找：';

  @override
  String get wordSegmentation => '分词：';

  @override
  String get bilingualNoAlignment => '未找到双语对齐位置';

  @override
  String get bilingualNoParagraph => '未找到对应段落';

  @override
  String get bilingualHighlightCreated => '双语高亮已创建';

  @override
  String get selectFile => '选择文件';

  @override
  String get dictionaryConfigHint =>
      '请选择一个 .mdx 格式的词典文件。如果有同名的 .mdd 资源文件（音频/图片），放在同一目录下会自动加载。';

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
      'Zephyr Reader 是一款纯离线的双语小说阅读器，Flutter + Rust 构建，100% 本地，无后端，无广告，无数据收集，专注于中英文双语阅读体验。';

  @override
  String get aboutFeatureOffline => '完全离线';

  @override
  String get aboutFeatureOfflineDesc => '核心功能无需网络，无后端无广告';

  @override
  String get aboutFeaturePerformance => '高性能';

  @override
  String get aboutFeaturePerformanceDesc => 'Rust 引擎即时解析大文件';

  @override
  String get aboutFeatureBilingual => '双语对照';

  @override
  String get aboutFeatureBilingualDesc => '中英同权对齐';

  @override
  String get aboutFeatureThemes => '多主题';

  @override
  String get aboutFeatureThemesDesc => '浅色/深色/纯黑夜间模式';

  @override
  String get aboutFeatureAdaptive => '自适应布局';

  @override
  String get aboutFeatureAdaptiveDesc => '手机和平板自动适配';

  @override
  String get aboutFeatureSync => 'WebDAV 同步';

  @override
  String get aboutFeatureSyncDesc => '多端同步与安全备份';

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
  String get readingAssist => '阅读辅助';

  @override
  String addedToVocabulary(Object word) {
    return '已加入生词本：$word';
  }

  @override
  String addToVocabFailed(Object error) {
    return '加入生词本失败：$error';
  }

  @override
  String get readerThemeLight => '白天';

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
  String totalChapters(Object count) {
    return '共 $count 章';
  }

  @override
  String get isbn => 'ISBN';

  @override
  String get bookIntro => '内容简介';

  @override
  String get timePresetSunsetToSunrise => '日落到日出';

  @override
  String get timePresetEveningToMorning => '傍晚到早晨';

  @override
  String get timePresetCustom => '自定义';

  @override
  String get appTheme => '应用主题';

  @override
  String get autoTheme => '自动主题';

  @override
  String get autoThemeDesc => '根据时间段自动切换深浅主题';

  @override
  String get autoThemeSchedule => '定时设置';

  @override
  String get bookFormat => '格式';

  @override
  String get bookIntroLabel => '内容简介';

  @override
  String get sortDialogTitle => '选择排序方式';

  @override
  String get tapLayoutRightHanded => '右手模式';

  @override
  String get tapLayoutLeftHanded => '左手模式';

  @override
  String get tapLayout => '翻页点击区域';

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
  String lastSyncTime(Object time) {
    return '上次同步：$time';
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
  String get weekdayMon => '一';

  @override
  String get weekdayTue => '二';

  @override
  String get weekdayWed => '三';

  @override
  String get weekdayThu => '四';

  @override
  String get weekdayFri => '五';

  @override
  String get weekdaySat => '六';

  @override
  String get weekdaySun => '日';

  @override
  String get vocabStats => '生词统计';

  @override
  String get statusIgnored => '已忽略';

  @override
  String get noSessions => '暂无阅读会话';

  @override
  String get autoRecordHint => '开始阅读后会自动记录';

  @override
  String get sessionDetails => '会话详情';

  @override
  String get unknownBook => '未知书籍';

  @override
  String sessionSummary(Object chars, Object count, Object duration) {
    return '共 $count 次 · $duration · 阅读 $chars';
  }

  @override
  String chapterInfo(Object chars, Object index) {
    return '第 $index 章 · $chars';
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
  String get wifiPageTitle => 'WiFi 传书';

  @override
  String get wifiServerRunning => '服务器运行中';

  @override
  String get wifiServerStopped => '服务器已停止';

  @override
  String get wifiStartServer => '启动服务器';

  @override
  String get wifiStopServer => '停止服务器';

  @override
  String get wifiCopyLink => '复制链接';

  @override
  String get wifiLinkCopied => '链接已复制';

  @override
  String get wifiInstruction => '连接与电脑相同的 Wi-Fi 网络，在浏览器中打开上方地址即可传输文件。';

  @override
  String wifiFileUploaded(Object filename) {
    return '已上传：$filename';
  }

  @override
  String get wifiServerStarted => '服务器已启动';

  @override
  String batchDeleteConfirm(Object count) {
    return '确定要删除选中的 $count 本书吗？';
  }

  @override
  String get categoryName => '分类名称';

  @override
  String get addCategory => '添加分类';

  @override
  String get editCategoryName => '编辑分类名称';

  @override
  String get deleteCategory => '删除分类';

  @override
  String confirmDeleteCategory(Object name) {
    return '确定要删除分类「$name」吗？关联书籍不会受影响。';
  }

  @override
  String get categoryNameRequired => '请输入分类名称';

  @override
  String get categoryAlreadyExists => '分类名称已存在';

  @override
  String get noCategories => '暂无分类';

  @override
  String get addCategoryHint => '点击右上角添加分类';

  @override
  String get wifiTransferLog => '传输记录';

  @override
  String get wifiWaitUpload => '等待文件上传…';

  @override
  String get wifiStartServerPrompt => '启动服务器开始传输';

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
  String get searchGroupBooks => '书籍';

  @override
  String get searchGroupNotes => '笔记';

  @override
  String get searchGroupVocab => '生词';

  @override
  String get searchNoResults => '未找到相关结果';

  @override
  String get bookSearchHint => '搜索书籍内容…';

  @override
  String get bookSearchHintAll => '搜索所有书籍内容…';

  @override
  String get searchHint => '搜索书籍、笔记、生词…';

  @override
  String get searchHistory => '搜索历史';

  @override
  String get searchFailed => '搜索失败';

  @override
  String get searchEnterKeyword => '请输入搜索关键词';

  @override
  String get searchTryOtherKeywords => '尝试其他关键词';

  @override
  String get searchError => '搜索出错';

  @override
  String resultSummary(Object count, Object duration) {
    return '找到 $count 条结果 · 耗时 ${duration}ms';
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
  String get currentDataStats => '当前数据统计';

  @override
  String get backingUp => '备份中…';

  @override
  String get restoring => '恢复中…';

  @override
  String operationFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String lastBackup(Object time) {
    return '上次备份：$time';
  }

  @override
  String get neverBackedUp => '尚未进行过备份';

  @override
  String dataSummary(Object books, Object notes) {
    return '数据量：$books 本书 · $notes 条笔记';
  }

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
  String get restoreStatVocabulary => '生词';

  @override
  String get allBooks => '全部书籍';

  @override
  String get allWordLists => '全部词库';

  @override
  String get export => '导出';

  @override
  String get exportLearningData => '导出学习数据';

  @override
  String get exportNotesMarkdownDesc => '导出所有笔记为 Markdown 文档';

  @override
  String get exportVocabCsvDesc => '导出所有生词为表格文件';

  @override
  String get goReading => '去阅读';

  @override
  String get noNotes => '暂无笔记';

  @override
  String get noteEmptyHint => '在阅读中做笔记后，它们会出现在这里';

  @override
  String get notebook => '笔记本';

  @override
  String get notesMarkdown => '笔记 (Markdown)';

  @override
  String get totalVocabCount => '生词总数';

  @override
  String get vocabEmptyHint => '在阅读中添加生词后，它们会出现在这里';

  @override
  String get vocabListCsv => '生词表 (CSV)';

  @override
  String get wordListCet4 => 'CET-4';

  @override
  String get wordListCet6 => 'CET-6';

  @override
  String get wordListIelts => 'IELTS';

  @override
  String get wordListToefl => 'TOEFL';

  @override
  String confirmDeleteWord(Object word) {
    return '确定要删除「$word」吗？';
  }

  @override
  String get vocabPageEmptyHint => '去阅读时点击单词即可加入生词本';

  @override
  String get vocabFilterEmptyHint => '没有符合条件的生词';

  @override
  String vocabStatsAll(Object count) {
    return '全部 $count';
  }

  @override
  String vocabStatsUnstarted(Object count) {
    return '未学 $count';
  }

  @override
  String vocabStatsLearning(Object count) {
    return '学习中 $count';
  }

  @override
  String vocabStatsMastered(Object count) {
    return '已掌握 $count';
  }

  @override
  String vocabStatsIgnored(Object count) {
    return '已忽略 $count';
  }

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
  String get fontSelection => '字体选择';

  @override
  String get typographyParams => '排版参数';

  @override
  String get advancedTypography => '高级排版';

  @override
  String get cjkOptimization => 'CJK 优化';

  @override
  String get punctuationSqueeze => '标点挤压';

  @override
  String get punctuationSqueezeDesc => '减少中文标点符号周围的空白';

  @override
  String get baselineAlign => '中西文基线对齐';

  @override
  String get baselineAlignDesc => '强制统一行高，避免混排时文字跳动';

  @override
  String get firstLineIndent => '首行缩进';

  @override
  String get firstLineIndentDesc => '每个段落缩进 2 个字符';

  @override
  String get autoScroll => '自动翻页';

  @override
  String get autoScrollSpeed => '翻页间隔';

  @override
  String get ttsPreviewStop => '停止试听';

  @override
  String get ttsPreviewPlay => '试听当前配置';

  @override
  String get ttsAutoRefresh => '修改后自动刷新';

  @override
  String get enableHyphenation => '英文连字符断词';

  @override
  String get autoSpaceRatio => '中西文间距';

  @override
  String get autoSpaceRatioDesc => '中文和英文之间的视觉间隔比例';

  @override
  String get enableHyphenationDesc => '英文单词在行末以连字符断开';

  @override
  String get typesetLanguage => '语言类型';

  @override
  String get typesetLanguageAuto => '自动检测';

  @override
  String get typesetLanguageChinese => '中文';

  @override
  String get typesetLanguageEnglish => '英文';

  @override
  String get typesetLanguageMixed => '中英混合';

  @override
  String get ttsVoiceEngine => '语音引擎';

  @override
  String get ttsEngine => 'TTS 引擎';

  @override
  String get systemDefault => '系统默认';

  @override
  String get ttsEnglishVoice => '英文语音';

  @override
  String get ttsChineseVoice => '中文语音';

  @override
  String get ttsPlaybackParams => '播放参数';

  @override
  String get ttsPitch => '音调';

  @override
  String get ttsPauseBetween => '句间停顿';

  @override
  String get ttsBilingualReading => '双语朗读';

  @override
  String get zephyrExclusive => 'Zephyr 专属';

  @override
  String get ttsBilingualAlternate => '双语交替朗读';

  @override
  String get ttsBilingualAlternateDesc => '先读英文原文，再读中文译文';

  @override
  String get ttsOriginalOnly => '仅朗读原文';

  @override
  String get ttsOriginalOnlyDesc => '跳过译文段落，适合听力训练';

  @override
  String get ttsSwitchInterval => '中英切换间隔';

  @override
  String get ttsBehavior => '行为偏好';

  @override
  String get ttsBackgroundPlay => '后台播放';

  @override
  String get ttsBackgroundPlayDesc => '切出应用或锁屏后继续朗读';

  @override
  String get ttsAutoPage => '自动翻页';

  @override
  String get ttsAutoPageDesc => '读完当前章节自动跳转下一章';

  @override
  String get ttsHighlightFollow => '高亮跟随';

  @override
  String get ttsHighlightFollowDesc => '朗读时实时高亮当前句子';

  @override
  String get ttsDimOnLock => '息屏时降低音量';

  @override
  String get ttsDimOnLockDesc => '节省电量，适合睡前听书';

  @override
  String get otherBehavior => '应用行为';

  @override
  String get languageSubtitle => '简体中文 / English';

  @override
  String get otherNotifications => '通知与提醒';

  @override
  String get otherNotificationsDesc => '阅读目标提醒、同步完成通知';

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
  String get resetAllSettingsDesc => '恢复默认排版、主题、同步配置';

  @override
  String get clearAllData => '清理缓存';

  @override
  String get clearAllDataDesc => '清除阅读缓存和临时文件，不影响个人数据';

  @override
  String get confirmReset => '确认重置';

  @override
  String get confirmResetContent =>
      '此操作将恢复排版、主题、同步配置等所有设置为默认值。\n\n不会删除书籍、笔记和生词数据。';

  @override
  String get clearAllDataTitle => '清理缓存';

  @override
  String get clearAllDataContent => '此操作将清除阅读缓存和临时文件。\n\n不会删除书籍、笔记和生词数据。';

  @override
  String get confirmClear => '确认清除';

  @override
  String get translationApi => '自动翻译';

  @override
  String get translationProvider => '翻译服务';

  @override
  String get translationApiUrl => 'API 地址';

  @override
  String get translationApiKey => 'API 密钥';

  @override
  String get translationModel => '模型';

  @override
  String get translationSourceLang => '源语言';

  @override
  String get translationTargetLang => '目标语言';

  @override
  String get translationAutoDetect => '自动检测';

  @override
  String get translationTimeout => '超时（秒）';

  @override
  String get translationTest => '测试连接';

  @override
  String get translationTranslateWithApi => '使用API翻译';

  @override
  String get translationTestSuccess => '连接测试成功';

  @override
  String translationTestFailed(Object error) {
    return '连接测试失败：$error';
  }

  @override
  String get translationApiNotConfigured => '未配置自动翻译';

  @override
  String get translating => '正在翻译…';

  @override
  String translationFailed(Object error) {
    return '翻译失败：$error';
  }

  @override
  String get translationRetry => '重试';

  @override
  String get translationManualPaste => '手动粘贴';

  @override
  String get readingMode => '阅读模式';

  @override
  String get themeSwitch => '主题切换';

  @override
  String get bookmarkManage => '书签管理';

  @override
  String get searchBookmarkHint => '搜索书签...';

  @override
  String get clearAll => '清空所有';

  @override
  String get deleteSelected => '删除选中';

  @override
  String get sortByTime => '按时间排序';

  @override
  String get sortByChapter => '按章节排序';

  @override
  String get sortByPosition => '按位置排序';

  @override
  String totalBookmarks(int count) {
    return '共 $count 个书签';
  }

  @override
  String bookTotalBookmarks(int count) {
    return '本书总计 $count 个';
  }

  @override
  String get reload => '重新加载';

  @override
  String get noBookmarksFound => '未找到相关书签';

  @override
  String get addBookmarkHint => '阅读时点击右上角添加书签';

  @override
  String get deleteBookmark => '删除书签';

  @override
  String confirmDeleteBookmark(String title) {
    return '确定要删除\"$title\"吗？';
  }

  @override
  String get confirmDeleteBookmarkSimple => '确定要删除此书签吗？';

  @override
  String get batchDelete => '批量删除';

  @override
  String confirmBatchDelete(int count) {
    return '确定要删除选中的 $count 个书签吗？';
  }

  @override
  String deletedBookmarks(int count) {
    return '已删除 $count 个书签';
  }

  @override
  String get clearAllBookmarks => '清空书签';

  @override
  String get confirmAddBookmark => '确定要在这里添加书签吗？';

  @override
  String get bookmarkAdded => '书签已添加';

  @override
  String get add => '添加';

  @override
  String get bookmarkDeleted => '书签已删除';

  @override
  String get jumpTo => '跳转';

  @override
  String get charOffset => '偏移';

  @override
  String get notesAndHighlights => '笔记与标注';

  @override
  String get refreshTooltip => '刷新';

  @override
  String get confirmClearAllBookmarks => '确定要清空本书的所有书签吗？此操作不可恢复';

  @override
  String get clearedAllBookmarks => '已清空所有书签';

  @override
  String get themePreviewSampleText => '春风又绿江南岸，明月何时照我还。';

  @override
  String get textAlign => '文字对齐';

  @override
  String get textAlignJustify => '两端对齐';

  @override
  String get textAlignStart => '左对齐';

  @override
  String get textAlignCenter => '居中';

  @override
  String get textAlignEnd => '右对齐';
}
