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

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

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

  /// No description provided for @estimatedTime.
  ///
  /// In zh, this message translates to:
  /// **'约 {hours}小时{minutes}分钟'**
  String estimatedTime(Object hours, Object minutes);

  /// No description provided for @estimatedTimeShort.
  ///
  /// In zh, this message translates to:
  /// **'约 {minutes}分钟'**
  String estimatedTimeShort(Object minutes);

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

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

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

  /// No description provided for @paginationMode.
  ///
  /// In zh, this message translates to:
  /// **'分页'**
  String get paginationMode;

  /// No description provided for @fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// No description provided for @fontFamily.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get fontFamily;

  /// No description provided for @fontWeight.
  ///
  /// In zh, this message translates to:
  /// **'字重'**
  String get fontWeight;

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

  /// No description provided for @paragraphIndent.
  ///
  /// In zh, this message translates to:
  /// **'首行缩进'**
  String get paragraphIndent;

  /// No description provided for @textAlignment.
  ///
  /// In zh, this message translates to:
  /// **'文本对齐'**
  String get textAlignment;

  /// No description provided for @textAlignAuto.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get textAlignAuto;

  /// No description provided for @textAlignLeft.
  ///
  /// In zh, this message translates to:
  /// **'左对齐'**
  String get textAlignLeft;

  /// No description provided for @textAlignJustify.
  ///
  /// In zh, this message translates to:
  /// **'两端对齐'**
  String get textAlignJustify;

  /// No description provided for @pageMargin.
  ///
  /// In zh, this message translates to:
  /// **'页边距'**
  String get pageMargin;

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

  /// No description provided for @ttsSpeed.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get ttsSpeed;

  /// No description provided for @dictionary.
  ///
  /// In zh, this message translates to:
  /// **'词典管理'**
  String get dictionary;

  /// No description provided for @wordCount.
  ///
  /// In zh, this message translates to:
  /// **'词数'**
  String get wordCount;

  /// No description provided for @statistics.
  ///
  /// In zh, this message translates to:
  /// **'阅读统计'**
  String get statistics;

  /// No description provided for @readingWords.
  ///
  /// In zh, this message translates to:
  /// **'阅读字数'**
  String get readingWords;

  /// No description provided for @booksCompleted.
  ///
  /// In zh, this message translates to:
  /// **'读完书籍'**
  String get booksCompleted;

  /// No description provided for @readingTrend.
  ///
  /// In zh, this message translates to:
  /// **'本周阅读趋势'**
  String get readingTrend;

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

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份数据'**
  String get backup;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearCache;

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

  /// No description provided for @dataCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清理缓存'**
  String get dataCleared;

  /// No description provided for @dataClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存失败：{error}'**
  String dataClearFailed(Object error);

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

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

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
  String bookImported(Object title);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(Object error);

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
  String scanComplete(Object count);

  /// No description provided for @scanProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描 {done}/{total}...'**
  String scanProgress(Object done, Object total);

  /// No description provided for @scanCompleteWithFailures.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成，导入了 {success} 本，导入失败 {fail} 本'**
  String scanCompleteWithFailures(Object fail, Object success);

  /// No description provided for @showReadingProgress.
  ///
  /// In zh, this message translates to:
  /// **'显示阅读进度'**
  String get showReadingProgress;

  /// No description provided for @defaultSort.
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get defaultSort;

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
  String selectedBooksCount(Object count);

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

  /// No description provided for @category.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get category;

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
  String deleteFailed(Object error);

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @appearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'阅读外观'**
  String get appearanceSection;

  /// No description provided for @readingModeSection.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get readingModeSection;

  /// No description provided for @typographySection.
  ///
  /// In zh, this message translates to:
  /// **'文字排版'**
  String get typographySection;

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

  /// No description provided for @sectionSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get sectionSystem;

  /// No description provided for @sectionReadingData.
  ///
  /// In zh, this message translates to:
  /// **'阅读数据'**
  String get sectionReadingData;

  /// No description provided for @sectionReadingTools.
  ///
  /// In zh, this message translates to:
  /// **'阅读工具'**
  String get sectionReadingTools;

  /// No description provided for @sectionDisplayAppearance.
  ///
  /// In zh, this message translates to:
  /// **'显示与外观'**
  String get sectionDisplayAppearance;

  /// No description provided for @readingSessions.
  ///
  /// In zh, this message translates to:
  /// **'阅读记录'**
  String get readingSessions;

  /// No description provided for @dataManagement.
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

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

  /// No description provided for @appVersionDisplay.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader v{version}'**
  String appVersionDisplay(Object version);

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

  /// No description provided for @selectDictionaryFile.
  ///
  /// In zh, this message translates to:
  /// **'选择词典文件'**
  String get selectDictionaryFile;

  /// No description provided for @selectMdxDescription.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个 .mdx 词典文件…'**
  String get selectMdxDescription;

  /// No description provided for @dictionaryLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'词典加载失败，请检查文件'**
  String get dictionaryLoadFailed;

  /// No description provided for @categoryManagement.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get categoryManagement;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In zh, this message translates to:
  /// **'轻如风，阅无界'**
  String get aboutTagline;

  /// No description provided for @aboutSectionFeatures.
  ///
  /// In zh, this message translates to:
  /// **'核心特性'**
  String get aboutSectionFeatures;

  /// No description provided for @aboutSectionTechStack.
  ///
  /// In zh, this message translates to:
  /// **'技术栈'**
  String get aboutSectionTechStack;

  /// No description provided for @aboutSectionLinks.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get aboutSectionLinks;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader 是一款纯离线的阅读器，Flutter + Rust 构建，100% 本地，无后端，无广告，无数据收集，专注于中英文阅读体验。'**
  String get aboutDescription;

  /// No description provided for @aboutFeatureOffline.
  ///
  /// In zh, this message translates to:
  /// **'完全离线'**
  String get aboutFeatureOffline;

  /// No description provided for @aboutFeatureOfflineDesc.
  ///
  /// In zh, this message translates to:
  /// **'核心功能无需网络，无后端无广告'**
  String get aboutFeatureOfflineDesc;

  /// No description provided for @aboutFeaturePerformance.
  ///
  /// In zh, this message translates to:
  /// **'高性能'**
  String get aboutFeaturePerformance;

  /// No description provided for @aboutFeaturePerformanceDesc.
  ///
  /// In zh, this message translates to:
  /// **'Rust 引擎即时解析大文件'**
  String get aboutFeaturePerformanceDesc;

  /// No description provided for @aboutFeatureThemes.
  ///
  /// In zh, this message translates to:
  /// **'多主题'**
  String get aboutFeatureThemes;

  /// No description provided for @aboutFeatureThemesDesc.
  ///
  /// In zh, this message translates to:
  /// **'浅色/深色/纯黑夜间模式'**
  String get aboutFeatureThemesDesc;

  /// No description provided for @aboutFeatureAdaptive.
  ///
  /// In zh, this message translates to:
  /// **'自适应布局'**
  String get aboutFeatureAdaptive;

  /// No description provided for @aboutFeatureAdaptiveDesc.
  ///
  /// In zh, this message translates to:
  /// **'手机和平板自动适配'**
  String get aboutFeatureAdaptiveDesc;

  /// No description provided for @aboutCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutCheckUpdate;

  /// No description provided for @aboutLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get aboutLatestVersion;

  /// No description provided for @aboutUserAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get aboutUserAgreement;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutOpenSourceLicense.
  ///
  /// In zh, this message translates to:
  /// **'开源许可证'**
  String get aboutOpenSourceLicense;

  /// No description provided for @aboutFeedback.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get aboutFeedback;

  /// No description provided for @aboutCannotOpenLink.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get aboutCannotOpenLink;

  /// No description provided for @unknownVersion.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknownVersion;

  /// No description provided for @readAloud.
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get readAloud;

  /// No description provided for @readingAssist.
  ///
  /// In zh, this message translates to:
  /// **'阅读辅助'**
  String get readingAssist;

  /// No description provided for @readerThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'白天'**
  String get readerThemeLight;

  /// No description provided for @readerThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'夜间'**
  String get readerThemeDark;

  /// No description provided for @readerThemeSepia.
  ///
  /// In zh, this message translates to:
  /// **'护眼'**
  String get readerThemeSepia;

  /// No description provided for @sortLastRead.
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get sortLastRead;

  /// No description provided for @sortCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'添加时间'**
  String get sortCreatedAt;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get sortTitle;

  /// No description provided for @sortAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get sortAuthor;

  /// No description provided for @sortProgress.
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get sortProgress;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @introLabel.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get introLabel;

  /// No description provided for @bookTitle.
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get bookTitle;

  /// No description provided for @currentChapter.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentChapter;

  /// No description provided for @editMetadata.
  ///
  /// In zh, this message translates to:
  /// **'编辑元数据'**
  String get editMetadata;

  /// No description provided for @statReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get statReadingTime;

  /// No description provided for @statReadingCount.
  ///
  /// In zh, this message translates to:
  /// **'阅读次数'**
  String get statReadingCount;

  /// No description provided for @statEstimatedRemaining.
  ///
  /// In zh, this message translates to:
  /// **'预计剩余'**
  String get statEstimatedRemaining;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @tocTitle.
  ///
  /// In zh, this message translates to:
  /// **'目录（{count} 章）'**
  String tocTitle(Object count);

  /// No description provided for @isbn.
  ///
  /// In zh, this message translates to:
  /// **'ISBN'**
  String get isbn;

  /// No description provided for @appTheme.
  ///
  /// In zh, this message translates to:
  /// **'应用主题'**
  String get appTheme;

  /// No description provided for @autoTheme.
  ///
  /// In zh, this message translates to:
  /// **'自动主题'**
  String get autoTheme;

  /// No description provided for @bookFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get bookFormat;

  /// No description provided for @sortDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择排序方式'**
  String get sortDialogTitle;

  /// No description provided for @timeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前'**
  String timeMinutesAgo(Object minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前'**
  String timeHoursAgo(Object hours);

  /// No description provided for @todayReading.
  ///
  /// In zh, this message translates to:
  /// **'今日阅读'**
  String get todayReading;

  /// No description provided for @minutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minutes;

  /// No description provided for @goalTemplate.
  ///
  /// In zh, this message translates to:
  /// **'目标 {minutes} 分钟'**
  String goalTemplate(Object minutes);

  /// No description provided for @streakLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续阅读'**
  String get streakLabel;

  /// No description provided for @daysUnit.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get daysUnit;

  /// No description provided for @booksRead.
  ///
  /// In zh, this message translates to:
  /// **'读过 {count} 本书'**
  String booksRead(Object count);

  /// No description provided for @insufficientData.
  ///
  /// In zh, this message translates to:
  /// **'数据不足'**
  String get insufficientData;

  /// No description provided for @readingHeatmap.
  ///
  /// In zh, this message translates to:
  /// **'阅读热力图'**
  String get readingHeatmap;

  /// No description provided for @noSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无阅读会话'**
  String get noSessions;

  /// No description provided for @autoRecordHint.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读后会自动记录'**
  String get autoRecordHint;

  /// No description provided for @sessionDetails.
  ///
  /// In zh, this message translates to:
  /// **'会话详情'**
  String get sessionDetails;

  /// No description provided for @unknownBook.
  ///
  /// In zh, this message translates to:
  /// **'未知书籍'**
  String get unknownBook;

  /// No description provided for @sessionSummary.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 次 · {duration} · 阅读 {chars}'**
  String sessionSummary(Object chars, Object count, Object duration);

  /// No description provided for @chapterInfo.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 章 · {chars}'**
  String chapterInfo(Object chars, Object index);

  /// No description provided for @deleteSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除会话记录'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除本书的所有阅读会话记录吗？'**
  String get deleteSessionConfirm;

  /// No description provided for @periodToday.
  ///
  /// In zh, this message translates to:
  /// **'本日'**
  String get periodToday;

  /// No description provided for @periodWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In zh, this message translates to:
  /// **'全年'**
  String get periodYear;

  /// No description provided for @totalReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'总阅读时长'**
  String get totalReadingTime;

  /// No description provided for @sessionsCount.
  ///
  /// In zh, this message translates to:
  /// **'次会话'**
  String get sessionsCount;

  /// No description provided for @batchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 本书吗？'**
  String batchDeleteConfirm(Object count);

  /// No description provided for @categoryName.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryName;

  /// No description provided for @addCategory.
  ///
  /// In zh, this message translates to:
  /// **'添加分类'**
  String get addCategory;

  /// No description provided for @deleteCategory.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get deleteCategory;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除分类「{name}」吗？关联书籍不会受影响。'**
  String confirmDeleteCategory(Object name);

  /// No description provided for @categoryNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入分类名称'**
  String get categoryNameRequired;

  /// No description provided for @noCategories.
  ///
  /// In zh, this message translates to:
  /// **'暂无分类'**
  String get noCategories;

  /// No description provided for @addCategoryHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角添加分类'**
  String get addCategoryHint;

  /// No description provided for @backupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'备份成功'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败：{error}'**
  String backupFailed(Object error);

  /// No description provided for @restoreSuccess.
  ///
  /// In zh, this message translates to:
  /// **'恢复成功'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{error}'**
  String restoreFailed(Object error);

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @restoreRestartNotice.
  ///
  /// In zh, this message translates to:
  /// **'数据已还原，请重启应用以生效。'**
  String get restoreRestartNotice;

  /// No description provided for @restoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'从备份还原'**
  String get restoreTitle;

  /// No description provided for @restoreSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择一个 .db 备份文件恢复数据'**
  String get restoreSubtitle;

  /// No description provided for @restoring.
  ///
  /// In zh, this message translates to:
  /// **'恢复中…'**
  String get restoring;

  /// No description provided for @neverBackedUp.
  ///
  /// In zh, this message translates to:
  /// **'尚未进行过备份'**
  String get neverBackedUp;

  /// No description provided for @timeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前'**
  String timeDaysAgo(Object days);

  /// No description provided for @timeMonthsAgo.
  ///
  /// In zh, this message translates to:
  /// **'{months} 个月前'**
  String timeMonthsAgo(Object months);

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认还原'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmWarning.
  ///
  /// In zh, this message translates to:
  /// **'此操作将覆盖当前所有数据。请确认该备份文件来源可信。'**
  String get restoreConfirmWarning;

  /// No description provided for @restoreConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认还原'**
  String get restoreConfirmAction;

  /// No description provided for @restoreStatVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份版本'**
  String get restoreStatVersion;

  /// No description provided for @restoreStatExportedAt.
  ///
  /// In zh, this message translates to:
  /// **'导出时间'**
  String get restoreStatExportedAt;

  /// No description provided for @restoreStatBooks.
  ///
  /// In zh, this message translates to:
  /// **'书籍'**
  String get restoreStatBooks;

  /// No description provided for @restoreStatNotes.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get restoreStatNotes;

  /// No description provided for @restoreStatBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get restoreStatBookmarks;

  /// No description provided for @secondsUnit.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get secondsUnit;

  /// No description provided for @hoursUnit.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get hoursUnit;

  /// No description provided for @charsUnit.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get charsUnit;

  /// No description provided for @thousandCharsUnit.
  ///
  /// In zh, this message translates to:
  /// **'千'**
  String get thousandCharsUnit;

  /// No description provided for @byteUnit.
  ///
  /// In zh, this message translates to:
  /// **'B'**
  String get byteUnit;

  /// No description provided for @kilobyteUnit.
  ///
  /// In zh, this message translates to:
  /// **'KB'**
  String get kilobyteUnit;

  /// No description provided for @megabyteUnit.
  ///
  /// In zh, this message translates to:
  /// **'MB'**
  String get megabyteUnit;

  /// No description provided for @gigabyteUnit.
  ///
  /// In zh, this message translates to:
  /// **'GB'**
  String get gigabyteUnit;

  /// No description provided for @livePreview.
  ///
  /// In zh, this message translates to:
  /// **'实时预览'**
  String get livePreview;

  /// No description provided for @autoScroll.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get autoScroll;

  /// No description provided for @autoScrollSpeed.
  ///
  /// In zh, this message translates to:
  /// **'翻页间隔'**
  String get autoScrollSpeed;

  /// No description provided for @ttsPlaybackParams.
  ///
  /// In zh, this message translates to:
  /// **'播放参数'**
  String get ttsPlaybackParams;

  /// No description provided for @ttsPitch.
  ///
  /// In zh, this message translates to:
  /// **'音调'**
  String get ttsPitch;

  /// No description provided for @ttsPauseBetween.
  ///
  /// In zh, this message translates to:
  /// **'句间停顿'**
  String get ttsPauseBetween;

  /// No description provided for @ttsOriginalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅朗读原文'**
  String get ttsOriginalOnly;

  /// No description provided for @ttsSwitchInterval.
  ///
  /// In zh, this message translates to:
  /// **'中英切换间隔'**
  String get ttsSwitchInterval;

  /// No description provided for @ttsBehavior.
  ///
  /// In zh, this message translates to:
  /// **'行为偏好'**
  String get ttsBehavior;

  /// No description provided for @ttsBackgroundPlay.
  ///
  /// In zh, this message translates to:
  /// **'后台播放'**
  String get ttsBackgroundPlay;

  /// No description provided for @ttsBackgroundPlayDesc.
  ///
  /// In zh, this message translates to:
  /// **'切出应用或锁屏后继续朗读'**
  String get ttsBackgroundPlayDesc;

  /// No description provided for @ttsAutoPage.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get ttsAutoPage;

  /// No description provided for @ttsAutoPageDesc.
  ///
  /// In zh, this message translates to:
  /// **'读完当前章节自动跳转下一章'**
  String get ttsAutoPageDesc;

  /// No description provided for @ttsHighlightFollow.
  ///
  /// In zh, this message translates to:
  /// **'高亮跟随'**
  String get ttsHighlightFollow;

  /// No description provided for @ttsHighlightFollowDesc.
  ///
  /// In zh, this message translates to:
  /// **'朗读时实时高亮当前句子'**
  String get ttsHighlightFollowDesc;

  /// No description provided for @ttsDimOnLock.
  ///
  /// In zh, this message translates to:
  /// **'息屏时降低音量'**
  String get ttsDimOnLock;

  /// No description provided for @ttsDimOnLockDesc.
  ///
  /// In zh, this message translates to:
  /// **'节省电量，适合睡前听书'**
  String get ttsDimOnLockDesc;

  /// No description provided for @otherBehavior.
  ///
  /// In zh, this message translates to:
  /// **'应用行为'**
  String get otherBehavior;

  /// No description provided for @languageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'简体中文 / English'**
  String get languageSubtitle;

  /// No description provided for @otherNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知与提醒'**
  String get otherNotifications;

  /// No description provided for @otherNotificationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读目标提醒、同步完成通知'**
  String get otherNotificationsDesc;

  /// No description provided for @otherStartupCheck.
  ///
  /// In zh, this message translates to:
  /// **'启动时检查更新'**
  String get otherStartupCheck;

  /// No description provided for @otherStartupCheckDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅前台启动时检测新版本'**
  String get otherStartupCheckDesc;

  /// No description provided for @otherExperimental.
  ///
  /// In zh, this message translates to:
  /// **'实验性功能'**
  String get otherExperimental;

  /// No description provided for @otherLegal.
  ///
  /// In zh, this message translates to:
  /// **'法律与合规'**
  String get otherLegal;

  /// No description provided for @openSourceLicenseDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter / Rust / 第三方库许可'**
  String get openSourceLicenseDesc;

  /// No description provided for @resetAllSettings.
  ///
  /// In zh, this message translates to:
  /// **'重置所有设置'**
  String get resetAllSettings;

  /// No description provided for @resetAllSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认排版、主题、同步配置'**
  String get resetAllSettingsDesc;

  /// No description provided for @clearAllData.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearAllData;

  /// No description provided for @clearAllDataDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除阅读缓存和临时文件，不影响个人数据'**
  String get clearAllDataDesc;

  /// No description provided for @confirmReset.
  ///
  /// In zh, this message translates to:
  /// **'确认重置'**
  String get confirmReset;

  /// No description provided for @confirmResetContent.
  ///
  /// In zh, this message translates to:
  /// **'此操作将恢复排版、主题、同步配置等所有设置为默认值。\n\n不会删除书籍、笔记和生词数据。'**
  String get confirmResetContent;

  /// No description provided for @clearAllDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearAllDataTitle;

  /// No description provided for @clearAllDataContent.
  ///
  /// In zh, this message translates to:
  /// **'此操作将清除阅读缓存和临时文件。\n\n不会删除书籍、笔记和生词数据。'**
  String get clearAllDataContent;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get confirmClear;

  /// No description provided for @readingMode.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get readingMode;

  /// No description provided for @deleteBookmark.
  ///
  /// In zh, this message translates to:
  /// **'删除书签'**
  String get deleteBookmark;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @charOffset.
  ///
  /// In zh, this message translates to:
  /// **'偏移'**
  String get charOffset;

  /// No description provided for @themePreviewSampleText.
  ///
  /// In zh, this message translates to:
  /// **'春风又绿江南岸，明月何时照我还。'**
  String get themePreviewSampleText;

  /// No description provided for @aboutFeatureLookup.
  ///
  /// In zh, this message translates to:
  /// **'词典与翻译'**
  String get aboutFeatureLookup;

  /// No description provided for @aboutFeatureLookupDesc.
  ///
  /// In zh, this message translates to:
  /// **'离线词典 + 可配置翻译 API'**
  String get aboutFeatureLookupDesc;
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
