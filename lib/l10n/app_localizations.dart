import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get tabBookshelf;

  /// No description provided for @tabStatistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get tabStatistics;

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabProfile;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @continueReading.
  ///
  /// In zh, this message translates to:
  /// **'继续阅读'**
  String get continueReading;

  /// No description provided for @recentReading.
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get recentReading;

  /// No description provided for @noReadingRecord.
  ///
  /// In zh, this message translates to:
  /// **'暂无阅读记录'**
  String get noReadingRecord;

  /// No description provided for @bookshelf.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get bookshelf;

  /// No description provided for @searchBooks.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍'**
  String get searchBooks;

  /// No description provided for @importBook.
  ///
  /// In zh, this message translates to:
  /// **'导入书籍'**
  String get importBook;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @reading.
  ///
  /// In zh, this message translates to:
  /// **'在读'**
  String get reading;

  /// No description provided for @notStarted.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get notStarted;

  /// No description provided for @finished.
  ///
  /// In zh, this message translates to:
  /// **'已读完'**
  String get finished;

  /// No description provided for @gridView.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

  /// No description provided for @noBooks.
  ///
  /// In zh, this message translates to:
  /// **'暂无书籍'**
  String get noBooks;

  /// No description provided for @bookDetail.
  ///
  /// In zh, this message translates to:
  /// **'书籍详情'**
  String get bookDetail;

  /// No description provided for @author.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get author;

  /// No description provided for @translator.
  ///
  /// In zh, this message translates to:
  /// **'译者'**
  String get translator;

  /// No description provided for @publisher.
  ///
  /// In zh, this message translates to:
  /// **'出版社'**
  String get publisher;

  /// No description provided for @format.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get format;

  /// No description provided for @fileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get fileSize;

  /// No description provided for @totalPages.
  ///
  /// In zh, this message translates to:
  /// **'总页数'**
  String get totalPages;

  /// No description provided for @readingProgress.
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get readingProgress;

  /// No description provided for @readingTime.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get readingTime;

  /// No description provided for @readingCount.
  ///
  /// In zh, this message translates to:
  /// **'阅读次数'**
  String get readingCount;

  /// No description provided for @estimatedRemaining.
  ///
  /// In zh, this message translates to:
  /// **'预计剩余'**
  String get estimatedRemaining;

  /// No description provided for @startReading.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读'**
  String get startReading;

  /// No description provided for @readFromBeginning.
  ///
  /// In zh, this message translates to:
  /// **'从头开始'**
  String get readFromBeginning;

  /// No description provided for @notesCount.
  ///
  /// In zh, this message translates to:
  /// **'笔记数'**
  String get notesCount;

  /// No description provided for @highlightsCount.
  ///
  /// In zh, this message translates to:
  /// **'高亮数'**
  String get highlightsCount;

  /// No description provided for @vocabularyCount.
  ///
  /// In zh, this message translates to:
  /// **'生词数'**
  String get vocabularyCount;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @exportNotes.
  ///
  /// In zh, this message translates to:
  /// **'导出笔记'**
  String get exportNotes;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @reader.
  ///
  /// In zh, this message translates to:
  /// **'阅读器'**
  String get reader;

  /// No description provided for @scrollMode.
  ///
  /// In zh, this message translates to:
  /// **'滚动'**
  String get scrollMode;

  /// No description provided for @pageTurnMode.
  ///
  /// In zh, this message translates to:
  /// **'翻页'**
  String get pageTurnMode;

  /// No description provided for @paginationMode.
  ///
  /// In zh, this message translates to:
  /// **'分页'**
  String get paginationMode;

  /// No description provided for @bilingualMode.
  ///
  /// In zh, this message translates to:
  /// **'对照'**
  String get bilingualMode;

  /// No description provided for @horizontal.
  ///
  /// In zh, this message translates to:
  /// **'横排'**
  String get horizontal;

  /// No description provided for @vertical.
  ///
  /// In zh, this message translates to:
  /// **'竖排'**
  String get vertical;

  /// No description provided for @fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// No description provided for @lineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行间距'**
  String get lineHeight;

  /// No description provided for @letterSpacing.
  ///
  /// In zh, this message translates to:
  /// **'字间距'**
  String get letterSpacing;

  /// No description provided for @paragraphSpacing.
  ///
  /// In zh, this message translates to:
  /// **'段间距'**
  String get paragraphSpacing;

  /// No description provided for @pageMargin.
  ///
  /// In zh, this message translates to:
  /// **'页边距'**
  String get pageMargin;

  /// No description provided for @readingBackground.
  ///
  /// In zh, this message translates to:
  /// **'阅读背景'**
  String get readingBackground;

  /// No description provided for @brightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get brightness;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @font.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get font;

  /// No description provided for @defaultFont.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get defaultFont;

  /// No description provided for @chapterN.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 章'**
  String chapterN(int n);

  /// No description provided for @pageInfo.
  ///
  /// In zh, this message translates to:
  /// **'{current}/{total}'**
  String pageInfo(int current, int total);

  /// No description provided for @bookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get bookmarks;

  /// No description provided for @addBookmark.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get addBookmark;

  /// No description provided for @noBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'暂无书签'**
  String get noBookmarks;

  /// No description provided for @searchInPage.
  ///
  /// In zh, this message translates to:
  /// **'页面内查找'**
  String get searchInPage;

  /// No description provided for @noResults.
  ///
  /// In zh, this message translates to:
  /// **'无结果'**
  String get noResults;

  /// No description provided for @ttsPlay.
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get ttsPlay;

  /// No description provided for @ttsPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get ttsPause;

  /// No description provided for @ttsStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get ttsStop;

  /// No description provided for @ttsSpeed.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get ttsSpeed;

  /// No description provided for @selectionCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get selectionCopy;

  /// No description provided for @selectionHighlight.
  ///
  /// In zh, this message translates to:
  /// **'高亮'**
  String get selectionHighlight;

  /// No description provided for @selectionNote.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get selectionNote;

  /// No description provided for @selectionDictionary.
  ///
  /// In zh, this message translates to:
  /// **'查词'**
  String get selectionDictionary;

  /// No description provided for @selectionVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'生词本'**
  String get selectionVocabulary;

  /// No description provided for @selectionBilingual.
  ///
  /// In zh, this message translates to:
  /// **'标注两侧'**
  String get selectionBilingual;

  /// No description provided for @highlightYellow.
  ///
  /// In zh, this message translates to:
  /// **'黄色'**
  String get highlightYellow;

  /// No description provided for @highlightGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get highlightGreen;

  /// No description provided for @highlightBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get highlightBlue;

  /// No description provided for @highlightPink.
  ///
  /// In zh, this message translates to:
  /// **'粉色'**
  String get highlightPink;

  /// No description provided for @highlightPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫色'**
  String get highlightPurple;

  /// No description provided for @dictionary.
  ///
  /// In zh, this message translates to:
  /// **'词典'**
  String get dictionary;

  /// No description provided for @lookupWord.
  ///
  /// In zh, this message translates to:
  /// **'查词'**
  String get lookupWord;

  /// No description provided for @addToVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'加入生词本'**
  String get addToVocabulary;

  /// No description provided for @noDefinition.
  ///
  /// In zh, this message translates to:
  /// **'未找到释义'**
  String get noDefinition;

  /// No description provided for @vocabulary.
  ///
  /// In zh, this message translates to:
  /// **'生词本'**
  String get vocabulary;

  /// No description provided for @vocabularyBook.
  ///
  /// In zh, this message translates to:
  /// **'生词本'**
  String get vocabularyBook;

  /// No description provided for @wordCount.
  ///
  /// In zh, this message translates to:
  /// **'词数'**
  String get wordCount;

  /// No description provided for @learning.
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get learning;

  /// No description provided for @known.
  ///
  /// In zh, this message translates to:
  /// **'已掌握'**
  String get known;

  /// No description provided for @newWord.
  ///
  /// In zh, this message translates to:
  /// **'新词'**
  String get newWord;

  /// No description provided for @searchWords.
  ///
  /// In zh, this message translates to:
  /// **'搜索单词'**
  String get searchWords;

  /// No description provided for @noWords.
  ///
  /// In zh, this message translates to:
  /// **'暂无生词'**
  String get noWords;

  /// No description provided for @statusUnlearned.
  ///
  /// In zh, this message translates to:
  /// **'未学'**
  String get statusUnlearned;

  /// No description provided for @statusLearning.
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get statusLearning;

  /// No description provided for @statusMastered.
  ///
  /// In zh, this message translates to:
  /// **'已掌握'**
  String get statusMastered;

  /// No description provided for @fromBook.
  ///
  /// In zh, this message translates to:
  /// **'来自'**
  String get fromBook;

  /// No description provided for @statistics.
  ///
  /// In zh, this message translates to:
  /// **'阅读统计'**
  String get statistics;

  /// No description provided for @annualReport.
  ///
  /// In zh, this message translates to:
  /// **'年度阅览报告'**
  String get annualReport;

  /// No description provided for @readingOverview.
  ///
  /// In zh, this message translates to:
  /// **'阅读概览'**
  String get readingOverview;

  /// No description provided for @weeklyOverview.
  ///
  /// In zh, this message translates to:
  /// **'本周总览'**
  String get weeklyOverview;

  /// No description provided for @readingDuration.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get readingDuration;

  /// No description provided for @readingWords.
  ///
  /// In zh, this message translates to:
  /// **'阅读字数'**
  String get readingWords;

  /// No description provided for @readingDays.
  ///
  /// In zh, this message translates to:
  /// **'阅读天数'**
  String get readingDays;

  /// No description provided for @consecutiveDays.
  ///
  /// In zh, this message translates to:
  /// **'连续阅读天数'**
  String get consecutiveDays;

  /// No description provided for @booksCompleted.
  ///
  /// In zh, this message translates to:
  /// **'读完书籍'**
  String get booksCompleted;

  /// No description provided for @readingSpeed.
  ///
  /// In zh, this message translates to:
  /// **'平均阅读速度'**
  String get readingSpeed;

  /// No description provided for @wordsPerMinute.
  ///
  /// In zh, this message translates to:
  /// **'字/分钟'**
  String get wordsPerMinute;

  /// No description provided for @readingFootprint.
  ///
  /// In zh, this message translates to:
  /// **'阅读足迹'**
  String get readingFootprint;

  /// No description provided for @daysActive.
  ///
  /// In zh, this message translates to:
  /// **'天活跃'**
  String get daysActive;

  /// No description provided for @readingTrend.
  ///
  /// In zh, this message translates to:
  /// **'本周阅读趋势'**
  String get readingTrend;

  /// No description provided for @readingRhythm.
  ///
  /// In zh, this message translates to:
  /// **'阅读节奏'**
  String get readingRhythm;

  /// No description provided for @recentDays.
  ///
  /// In zh, this message translates to:
  /// **'近 {days} 天'**
  String recentDays(int days);

  /// No description provided for @sessions.
  ///
  /// In zh, this message translates to:
  /// **'阅读会话'**
  String get sessions;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appSettings.
  ///
  /// In zh, this message translates to:
  /// **'应用设置'**
  String get appSettings;

  /// No description provided for @readingSettings.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readingSettings;

  /// No description provided for @themeSettings.
  ///
  /// In zh, this message translates to:
  /// **'主题设置'**
  String get themeSettings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'阅读外观'**
  String get appearance;

  /// No description provided for @readerBgColor.
  ///
  /// In zh, this message translates to:
  /// **'阅读背景色'**
  String get readerBgColor;

  /// No description provided for @fontSettings.
  ///
  /// In zh, this message translates to:
  /// **'字体设置'**
  String get fontSettings;

  /// No description provided for @pageSettings.
  ///
  /// In zh, this message translates to:
  /// **'翻页设置'**
  String get pageSettings;

  /// No description provided for @screenSettings.
  ///
  /// In zh, this message translates to:
  /// **'屏幕设置'**
  String get screenSettings;

  /// No description provided for @keepScreenOn.
  ///
  /// In zh, this message translates to:
  /// **'保持屏幕常亮'**
  String get keepScreenOn;

  /// No description provided for @showBattery.
  ///
  /// In zh, this message translates to:
  /// **'显示电量'**
  String get showBattery;

  /// No description provided for @showTime.
  ///
  /// In zh, this message translates to:
  /// **'显示时间'**
  String get showTime;

  /// No description provided for @clickZone.
  ///
  /// In zh, this message translates to:
  /// **'点击区域'**
  String get clickZone;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @region.
  ///
  /// In zh, this message translates to:
  /// **'地区'**
  String get region;

  /// No description provided for @syncSettings.
  ///
  /// In zh, this message translates to:
  /// **'同步设置'**
  String get syncSettings;

  /// No description provided for @autoSync.
  ///
  /// In zh, this message translates to:
  /// **'自动同步'**
  String get autoSync;

  /// No description provided for @manualSync.
  ///
  /// In zh, this message translates to:
  /// **'手动同步'**
  String get manualSync;

  /// No description provided for @daily.
  ///
  /// In zh, this message translates to:
  /// **'每天一次'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In zh, this message translates to:
  /// **'每周一次'**
  String get weekly;

  /// No description provided for @backupRestore.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupRestore;

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份数据'**
  String get backup;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复数据'**
  String get restore;

  /// No description provided for @storageManagement.
  ///
  /// In zh, this message translates to:
  /// **'存储管理'**
  String get storageManagement;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearCache;

  /// No description provided for @cacheSize.
  ///
  /// In zh, this message translates to:
  /// **'缓存大小'**
  String get cacheSize;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @userAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get userAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @resetToDefault.
  ///
  /// In zh, this message translates to:
  /// **'重置为默认值'**
  String get resetToDefault;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @webdavConfig.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 配置'**
  String get webdavConfig;

  /// No description provided for @serverUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverUrl;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @remotePath.
  ///
  /// In zh, this message translates to:
  /// **'远程路径'**
  String get remotePath;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @syncHistory.
  ///
  /// In zh, this message translates to:
  /// **'同步历史'**
  String get syncHistory;

  /// No description provided for @syncSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailed;

  /// No description provided for @lastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSync;

  /// No description provided for @conflictResolution.
  ///
  /// In zh, this message translates to:
  /// **'冲突解决'**
  String get conflictResolution;

  /// No description provided for @useLocal.
  ///
  /// In zh, this message translates to:
  /// **'使用本地版本'**
  String get useLocal;

  /// No description provided for @useRemote.
  ///
  /// In zh, this message translates to:
  /// **'使用远程版本'**
  String get useRemote;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// No description provided for @empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get empty;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @unknownAuthor.
  ///
  /// In zh, this message translates to:
  /// **'未知作者'**
  String get unknownAuthor;

  /// No description provided for @greetingMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好'**
  String get greetingMorning;

  /// No description provided for @greetingNoon.
  ///
  /// In zh, this message translates to:
  /// **'中午好'**
  String get greetingNoon;

  /// No description provided for @greetingAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好'**
  String get greetingEvening;

  /// No description provided for @greetingLateNight.
  ///
  /// In zh, this message translates to:
  /// **'夜深了'**
  String get greetingLateNight;

  /// No description provided for @startReadingJourney.
  ///
  /// In zh, this message translates to:
  /// **'开始你的阅读之旅'**
  String get startReadingJourney;

  /// No description provided for @exploreNewWorld.
  ///
  /// In zh, this message translates to:
  /// **'打开一本书，探索新的世界'**
  String get exploreNewWorld;

  /// No description provided for @goToBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'去书库'**
  String get goToBookshelf;

  /// No description provided for @splashTagline.
  ///
  /// In zh, this message translates to:
  /// **'轻如风，阅无界'**
  String get splashTagline;

  /// No description provided for @bookshelfSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍...'**
  String get bookshelfSearchHint;

  /// No description provided for @bookshelfSettings.
  ///
  /// In zh, this message translates to:
  /// **'书架设置'**
  String get bookshelfSettings;

  /// No description provided for @bookshelfEmpty.
  ///
  /// In zh, this message translates to:
  /// **'书架空空如也'**
  String get bookshelfEmpty;

  /// No description provided for @closeSearch.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get closeSearch;

  /// No description provided for @scanFolder.
  ///
  /// In zh, this message translates to:
  /// **'扫描文件夹'**
  String get scanFolder;

  /// No description provided for @batchManage.
  ///
  /// In zh, this message translates to:
  /// **'批量管理'**
  String get batchManage;

  /// No description provided for @globalSearch.
  ///
  /// In zh, this message translates to:
  /// **'全局搜索'**
  String get globalSearch;

  /// No description provided for @editCategory.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get editCategory;

  /// No description provided for @markAsUnread.
  ///
  /// In zh, this message translates to:
  /// **'标记为未开始'**
  String get markAsUnread;

  /// No description provided for @markAsReading.
  ///
  /// In zh, this message translates to:
  /// **'标记为阅读中'**
  String get markAsReading;

  /// No description provided for @reExtractCover.
  ///
  /// In zh, this message translates to:
  /// **'补提取封面'**
  String get reExtractCover;

  /// No description provided for @unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpin;

  /// No description provided for @pinTop.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinTop;

  /// No description provided for @selectCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get selectCategory;

  /// No description provided for @bookImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入：{title}'**
  String bookImported(String title);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(String error);

  /// No description provided for @scanningFolder.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描文件夹...'**
  String get scanningFolder;

  /// No description provided for @noBookFilesFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到书籍文件'**
  String get noBookFilesFound;

  /// No description provided for @scanComplete.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成，导入了 {count} 本书'**
  String scanComplete(int count);

  /// No description provided for @showReadingProgress.
  ///
  /// In zh, this message translates to:
  /// **'显示阅读进度'**
  String get showReadingProgress;

  /// No description provided for @showRecentReading.
  ///
  /// In zh, this message translates to:
  /// **'显示最近阅读'**
  String get showRecentReading;

  /// No description provided for @defaultSort.
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get defaultSort;

  /// No description provided for @selectSortMethod.
  ///
  /// In zh, this message translates to:
  /// **'选择排序方式'**
  String get selectSortMethod;

  /// No description provided for @moveCategory.
  ///
  /// In zh, this message translates to:
  /// **'移动分类'**
  String get moveCategory;

  /// No description provided for @changeStatus.
  ///
  /// In zh, this message translates to:
  /// **'更改状态'**
  String get changeStatus;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @selectedBooksCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 本'**
  String selectedBooksCount(int count);

  /// No description provided for @bookInfo.
  ///
  /// In zh, this message translates to:
  /// **'书籍信息'**
  String get bookInfo;

  /// No description provided for @chapterCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'章节数'**
  String get chapterCountLabel;

  /// No description provided for @totalChars.
  ///
  /// In zh, this message translates to:
  /// **'总字符'**
  String get totalChars;

  /// No description provided for @addedTime.
  ///
  /// In zh, this message translates to:
  /// **'添加时间'**
  String get addedTime;

  /// No description provided for @chapterList.
  ///
  /// In zh, this message translates to:
  /// **'章节列表'**
  String get chapterList;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @viewAllChapters.
  ///
  /// In zh, this message translates to:
  /// **'查看全部 {count} 章'**
  String viewAllChapters(int count);

  /// No description provided for @category.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get category;

  /// No description provided for @weeklyReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'本周阅读时长'**
  String get weeklyReadingTime;

  /// No description provided for @dangerZone.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get dangerZone;

  /// No description provided for @deleteBook.
  ///
  /// In zh, this message translates to:
  /// **'删除本书'**
  String get deleteBook;

  /// No description provided for @confirmDeleteBookMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除本书吗？此操作不可恢复。'**
  String get confirmDeleteBookMessage;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailed(String error);

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @appearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'外观主题'**
  String get appearanceSection;

  /// No description provided for @readingModeSection.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get readingModeSection;

  /// No description provided for @layoutSection.
  ///
  /// In zh, this message translates to:
  /// **'版面布局'**
  String get layoutSection;

  /// No description provided for @typographySection.
  ///
  /// In zh, this message translates to:
  /// **'文字排版'**
  String get typographySection;

  /// No description provided for @searchInChapterHint.
  ///
  /// In zh, this message translates to:
  /// **'在章节内搜索...'**
  String get searchInChapterHint;

  /// No description provided for @previous.
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get next;

  /// No description provided for @currentlyReading.
  ///
  /// In zh, this message translates to:
  /// **'正在阅读'**
  String get currentlyReading;

  /// No description provided for @setBilingualTranslation.
  ///
  /// In zh, this message translates to:
  /// **'设置对照译文'**
  String get setBilingualTranslation;

  /// No description provided for @pasteTranslationHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴或输入当前章节的译文内容：'**
  String get pasteTranslationHint;

  /// No description provided for @addNote.
  ///
  /// In zh, this message translates to:
  /// **'添加笔记'**
  String get addNote;

  /// No description provided for @noteHintText.
  ///
  /// In zh, this message translates to:
  /// **'输入你的笔记内容…'**
  String get noteHintText;

  /// No description provided for @editNote.
  ///
  /// In zh, this message translates to:
  /// **'编辑笔记'**
  String get editNote;

  /// No description provided for @deleteHighlight.
  ///
  /// In zh, this message translates to:
  /// **'删除高亮'**
  String get deleteHighlight;

  /// No description provided for @profileDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'书友'**
  String get profileDisplayName;

  /// No description provided for @profileTagline.
  ///
  /// In zh, this message translates to:
  /// **'阅读是一种生活态度'**
  String get profileTagline;

  /// No description provided for @consecutiveDaysLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续天数'**
  String get consecutiveDaysLabel;

  /// No description provided for @sectionStudyMgmt.
  ///
  /// In zh, this message translates to:
  /// **'学习与管理'**
  String get sectionStudyMgmt;

  /// No description provided for @sectionReadingExp.
  ///
  /// In zh, this message translates to:
  /// **'阅读体验'**
  String get sectionReadingExp;

  /// No description provided for @sectionSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get sectionSystem;

  /// No description provided for @learningNotes.
  ///
  /// In zh, this message translates to:
  /// **'学习与笔记'**
  String get learningNotes;

  /// No description provided for @readingSessions.
  ///
  /// In zh, this message translates to:
  /// **'阅读会话'**
  String get readingSessions;

  /// No description provided for @storageSync.
  ///
  /// In zh, this message translates to:
  /// **'存储与同步'**
  String get storageSync;

  /// No description provided for @ttsSettings.
  ///
  /// In zh, this message translates to:
  /// **'朗读设置'**
  String get ttsSettings;

  /// No description provided for @typographySettings.
  ///
  /// In zh, this message translates to:
  /// **'排版与字体'**
  String get typographySettings;

  /// No description provided for @themeBrightness.
  ///
  /// In zh, this message translates to:
  /// **'主题与亮度'**
  String get themeBrightness;

  /// No description provided for @otherSettings.
  ///
  /// In zh, this message translates to:
  /// **'其他设置'**
  String get otherSettings;

  /// No description provided for @synced.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get synced;

  /// No description provided for @appVersionDisplay.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader v{version}'**
  String appVersionDisplay(String version);

  /// No description provided for @appIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'应用介绍'**
  String get appIntroduction;

  /// No description provided for @coreFeatures.
  ///
  /// In zh, this message translates to:
  /// **'核心特性'**
  String get coreFeatures;

  /// No description provided for @techStack.
  ///
  /// In zh, this message translates to:
  /// **'技术栈'**
  String get techStack;

  /// No description provided for @moreInfo.
  ///
  /// In zh, this message translates to:
  /// **'更多信息'**
  String get moreInfo;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @openSourceLicense.
  ///
  /// In zh, this message translates to:
  /// **'开源许可证'**
  String get openSourceLicense;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get feedback;

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get alreadyLatestVersion;

  /// No description provided for @cannotOpenLink.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get cannotOpenLink;

  /// No description provided for @aboutFeature1.
  ///
  /// In zh, this message translates to:
  /// **'纯离线使用，无需网络'**
  String get aboutFeature1;

  /// No description provided for @aboutFeature2.
  ///
  /// In zh, this message translates to:
  /// **'支持 EPUB、TXT、PDF 格式'**
  String get aboutFeature2;

  /// No description provided for @aboutFeature3.
  ///
  /// In zh, this message translates to:
  /// **'智能排版引擎'**
  String get aboutFeature3;

  /// No description provided for @aboutFeature4.
  ///
  /// In zh, this message translates to:
  /// **'双语对照阅读'**
  String get aboutFeature4;

  /// No description provided for @aboutFeature5.
  ///
  /// In zh, this message translates to:
  /// **'生词本与学习记录'**
  String get aboutFeature5;

  /// No description provided for @aboutFeature6.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 多端同步'**
  String get aboutFeature6;

  /// No description provided for @copyrightFooter.
  ///
  /// In zh, this message translates to:
  /// **'© 2026 Zephyr Reader'**
  String get copyrightFooter;

  /// No description provided for @madeWithFooter.
  ///
  /// In zh, this message translates to:
  /// **'Made with Flutter · Rust · ❤'**
  String get madeWithFooter;

  /// No description provided for @errorFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'文件不存在'**
  String get errorFileNotFound;

  /// No description provided for @errorFileReadError.
  ///
  /// In zh, this message translates to:
  /// **'文件读取失败'**
  String get errorFileReadError;

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In zh, this message translates to:
  /// **'不支持的格式'**
  String get errorUnsupportedFormat;

  /// No description provided for @errorEpubParse.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 解析错误'**
  String get errorEpubParse;

  /// No description provided for @errorDatabase.
  ///
  /// In zh, this message translates to:
  /// **'数据库错误'**
  String get errorDatabase;

  /// No description provided for @errorInternal.
  ///
  /// In zh, this message translates to:
  /// **'内部错误'**
  String get errorInternal;

  /// No description provided for @errorTaskPanic.
  ///
  /// In zh, this message translates to:
  /// **'任务执行异常：{task}'**
  String errorTaskPanic(String task);

  /// No description provided for @selectDictionaryFile.
  ///
  /// In zh, this message translates to:
  /// **'选择词典文件'**
  String get selectDictionaryFile;

  /// No description provided for @selectMdxDescription.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个 .mdx 格式的词典文件…'**
  String get selectMdxDescription;

  /// No description provided for @invalidMdxFile.
  ///
  /// In zh, this message translates to:
  /// **'请选择有效的 .mdx 文件'**
  String get invalidMdxFile;

  /// No description provided for @dictionaryLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'词典加载失败，请检查文件是否有效'**
  String get dictionaryLoadFailed;

  /// No description provided for @pronunciation.
  ///
  /// In zh, this message translates to:
  /// **'发音'**
  String get pronunciation;

  /// No description provided for @noExactMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到精确匹配，您是否想查：'**
  String get noExactMatch;

  /// No description provided for @wordSegmentation.
  ///
  /// In zh, this message translates to:
  /// **'分词：'**
  String get wordSegmentation;

  /// No description provided for @bilingualNoAlignment.
  ///
  /// In zh, this message translates to:
  /// **'没有对照译文，无法创建双语高亮'**
  String get bilingualNoAlignment;

  /// No description provided for @bilingualNoParagraph.
  ///
  /// In zh, this message translates to:
  /// **'未找到对应的段落'**
  String get bilingualNoParagraph;

  /// No description provided for @bilingualHighlightCreated.
  ///
  /// In zh, this message translates to:
  /// **'双语高亮已创建'**
  String get bilingualHighlightCreated;

  /// No description provided for @selectFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get selectFile;

  /// No description provided for @categoryManagement.
  ///
  /// In zh, this message translates to:
  /// **'标签管理'**
  String get categoryManagement;

  /// 简体中文翻译 - 关于页面标题
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// 简体中文翻译 - 应用标语
  ///
  /// In zh, this message translates to:
  /// **'如和风般轻盈的阅读体验'**
  String get aboutTagline;

  /// 简体中文翻译 - 核心特性分区标题
  ///
  /// In zh, this message translates to:
  /// **'核心特性'**
  String get aboutSectionFeatures;

  /// 简体中文翻译 - 技术栈分区标题
  ///
  /// In zh, this message translates to:
  /// **'技术栈'**
  String get aboutSectionTechStack;

  /// 简体中文翻译 - 链接分区标题
  ///
  /// In zh, this message translates to:
  /// **'更多信息'**
  String get aboutSectionLinks;

  /// 简体中文翻译 - 应用描述
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader 是一款基于 Flutter + Rust 架构的离线双语小说阅读器。纯本地设计，无后台、无广告、无数据收集，专注于中英双语阅读体验。'**
  String get aboutDescription;

  /// 简体中文翻译 - 特性：离线
  ///
  /// In zh, this message translates to:
  /// **'纯离线使用'**
  String get aboutFeatureOffline;

  /// 简体中文翻译 - 特性描述：离线
  ///
  /// In zh, this message translates to:
  /// **'核心功能 100% 离线可用，无后台无广告'**
  String get aboutFeatureOfflineDesc;

  /// 简体中文翻译 - 特性：高性能
  ///
  /// In zh, this message translates to:
  /// **'高性能解析'**
  String get aboutFeaturePerformance;

  /// 简体中文翻译 - 特性描述：高性能
  ///
  /// In zh, this message translates to:
  /// **'Rust 引擎驱动，大文件瞬间解析'**
  String get aboutFeaturePerformanceDesc;

  /// 简体中文翻译 - 特性：双语
  ///
  /// In zh, this message translates to:
  /// **'双语排版'**
  String get aboutFeatureBilingual;

  /// 简体中文翻译 - 特性描述：双语
  ///
  /// In zh, this message translates to:
  /// **'中英文同等优先，优雅对照阅读'**
  String get aboutFeatureBilingualDesc;

  /// 简体中文翻译 - 特性：主题
  ///
  /// In zh, this message translates to:
  /// **'多主题支持'**
  String get aboutFeatureThemes;

  /// 简体中文翻译 - 特性描述：主题
  ///
  /// In zh, this message translates to:
  /// **'亮色 / 深色 / 纯黑夜间模式'**
  String get aboutFeatureThemesDesc;

  /// 简体中文翻译 - 特性：适配
  ///
  /// In zh, this message translates to:
  /// **'设备适配'**
  String get aboutFeatureAdaptive;

  /// 简体中文翻译 - 特性描述：适配
  ///
  /// In zh, this message translates to:
  /// **'手机与平板双端自适应布局'**
  String get aboutFeatureAdaptiveDesc;

  /// 简体中文翻译 - 特性：同步
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get aboutFeatureSync;

  /// 简体中文翻译 - 特性描述：同步
  ///
  /// In zh, this message translates to:
  /// **'跨设备数据同步与安全备份'**
  String get aboutFeatureSyncDesc;

  /// 简体中文翻译 - 检查更新链接
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutCheckUpdate;

  /// 简体中文翻译 - 已是最新提示
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get aboutLatestVersion;

  /// 简体中文翻译 - 用户协议链接
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get aboutUserAgreement;

  /// 简体中文翻译 - 隐私政策链接
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get aboutPrivacyPolicy;

  /// 简体中文翻译 - 开源许可证链接
  ///
  /// In zh, this message translates to:
  /// **'开源许可证'**
  String get aboutOpenSourceLicense;

  /// 简体中文翻译 - 问题反馈链接
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get aboutFeedback;

  /// 简体中文翻译 - 链接打开失败提示
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get aboutCannotOpenLink;

  /// 简体中文 - 未知版本号
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknownVersion;

  /// 上一个搜索结果
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get prev;

  /// 朗读功能
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get readAloud;

  /// 加入生词本成功提示，{word}为单词
  ///
  /// In zh, this message translates to:
  /// **'已加入生词本：{word}'**
  String addedToVocabulary(String word);

  /// 加入生词本失败提示，{error}为错误信息
  ///
  /// In zh, this message translates to:
  /// **'加入生词本失败：{error}'**
  String addToVocabFailed(String error);

  /// 读者主题-日间
  ///
  /// In zh, this message translates to:
  /// **'日间'**
  String get readerThemeLight;

  /// 读者主题-夜间
  ///
  /// In zh, this message translates to:
  /// **'夜间'**
  String get readerThemeDark;

  /// 读者主题-护眼
  ///
  /// In zh, this message translates to:
  /// **'护眼'**
  String get readerThemeSepia;

  /// 字号-小
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get readerFontSizeSmall;

  /// 字号-中
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get readerFontSizeMedium;

  /// 字号-大
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get readerFontSizeLarge;

  /// 字号-特大
  ///
  /// In zh, this message translates to:
  /// **'特大'**
  String get readerFontSizeXLarge;

  /// 排序-最近阅读
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get sortLastRead;

  /// 排序-添加时间
  ///
  /// In zh, this message translates to:
  /// **'添加时间'**
  String get sortCreatedAt;

  /// 排序-书名
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get sortTitle;

  /// 排序-作者
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get sortAuthor;

  /// 排序-阅读进度
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get sortProgress;

  /// 主题-跟随系统
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get themeSystem;

  /// 书籍简介标签
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get introLabel;

  /// 当前章节标签
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentChapter;

  /// 书籍名称标签
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get bookTitle;

  /// 编辑书籍元数据
  ///
  /// In zh, this message translates to:
  /// **'编辑元数据'**
  String get editMetadata;

  /// 读书统计-时长
  ///
  /// In zh, this message translates to:
  /// **'累计时长'**
  String get statReadingTime;

  /// 读书统计-次数
  ///
  /// In zh, this message translates to:
  /// **'阅读次数'**
  String get statReadingCount;

  /// 读书统计-预计剩余
  ///
  /// In zh, this message translates to:
  /// **'预计剩余'**
  String get statEstimatedRemaining;

  /// 展开按钮
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// 目录标题，{count}为章节数
  ///
  /// In zh, this message translates to:
  /// **'目录（{count} 章）'**
  String tocTitle(int count);

  /// 章节总数, {count}为数字
  ///
  /// In zh, this message translates to:
  /// **'{count} 章'**
  String totalChapters(int count);

  /// ISBN标签
  ///
  /// In zh, this message translates to:
  /// **'ISBN'**
  String get isbn;

  /// 书籍简介区域标题
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get bookIntro;

  /// 定时主题-日落到日出
  ///
  /// In zh, this message translates to:
  /// **'日落到日出'**
  String get timePresetSunsetToSunrise;

  /// 定时主题-傍晚到早晨
  ///
  /// In zh, this message translates to:
  /// **'傍晚到早晨'**
  String get timePresetEveningToMorning;

  /// 定时主题-自定义
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get timePresetCustom;

  /// 应用主题区域标题
  ///
  /// In zh, this message translates to:
  /// **'应用主题'**
  String get appTheme;

  /// 书籍格式
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get bookFormat;

  /// 书籍简介区域
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get bookIntroLabel;

  /// 排序方式弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'选择排序方式'**
  String get sortDialogTitle;

  /// 点击区域-右手模式
  ///
  /// In zh, this message translates to:
  /// **'右手模式'**
  String get tapLayoutRightHanded;

  /// 点击区域-左手模式
  ///
  /// In zh, this message translates to:
  /// **'左手模式'**
  String get tapLayoutLeftHanded;

  /// 翻页点击区域
  ///
  /// In zh, this message translates to:
  /// **'点击区域'**
  String get tapLayout;

  /// 刚刚（相对时间）
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// N 分钟前
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前'**
  String timeMinutesAgo(int minutes);

  /// N 小时前
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前'**
  String timeHoursAgo(int hours);

  /// 上次同步时间
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String lastSyncTime(String time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
