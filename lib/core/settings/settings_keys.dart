/// 所有持久化键的唯一定义处
///
/// 本文件集中管理所有持久化键，禁止在其他文件中定义 `_key*` 常量。
abstract final class SettingsKeys {
  SettingsKeys._();

  // ==================== 主题 ====================

  /// 主题类型（存储 AppThemeType.index）
  static const themeType = 'app.theme.type';

  /// 自定义主色（ARGB32 int）
  static const customPrimaryColor = 'app.theme.custom_color';

  /// 当前主题预设 ID
  static const currentPresetId = 'app.theme.preset_id';

  /// 应用语言（null = 跟随系统）
  static const locale = 'app.locale';

  /// 是否启用自动主题切换
  static const autoThemeEnabled = 'auto_theme_enabled';

  /// 深色模式开始小时
  static const darkModeStartHour = 'dark_mode_start_hour';

  /// 深色模式结束小时
  static const darkModeEndHour = 'dark_mode_end_hour';

  /// 亮度遮罩值（0–100）
  static const brightness = 'theme.brightness';

  /// 是否跟随系统亮度
  static const useSystemBrightness = 'theme.use_system_brightness';

  // ==================== 阅读器 ====================

  /// 阅读器主题 ID
  static const readerTheme = 'reader_theme';

  /// 阅读器字号
  static const readerFontSize = 'reader_font_size';

  /// 字体族
  static const readerFontFamily = 'reader_font_family';

  /// 字重
  static const readerFontWeight = 'reader_font_weight';

  /// 阅读模式（分页/滚动）
  static const readerReadingMode = 'reader_reading_mode';

  static const readerPadding = 'reader_padding';

  /// 阅读背景色预设索引
  static const readerBgColorIndex = 'reader_bg_color_index';

  /// 是否自动翻页
  static const readerAutoScroll = 'reader_auto_scroll';

  /// 自动翻页速度（秒）
  static const readerAutoScrollSpeed = 'reader_auto_scroll_speed';

  // ==================== 书架 ====================

  /// 显示阅读进度
  static const bookshelfShowProgress = 'bookshelf.show_reading_progress';

  /// 默认排序方式
  static const bookshelfDefaultSort = 'bookshelf.default_sort_type';

  /// 是否列表视图
  static const bookshelfIsListView = 'bookshelf.is_list_view';

  // ==================== 备份 ====================

  /// 上次备份时间戳
  static const lastBackupAt = 'last_backup_at';

  /// 上次备份大小
  static const lastBackupSize = 'last_backup_size';

  // ==================== Wi-Fi 传输 ====================

  /// Wi-Fi 传输端口
  static const wifiTransferPort = 'wifi_transfer_port';

  // ==================== TTS ====================

  static const ttsSpeed = 'tts_speed';
  static const ttsPitch = 'tts_pitch';
  static const ttsPauseBetween = 'tts_pause_between';
  static const ttsBilingualAlternate = 'tts_bilingual_alternate';
  static const ttsOriginalOnly = 'tts_original_only';
  static const ttsSwitchInterval = 'tts_switch_interval';
  static const ttsBackgroundPlay = 'tts_background_play';
  static const ttsAutoPage = 'tts_auto_page';
  static const ttsHighlightFollow = 'tts_highlight_follow';
  static const ttsDimOnLock = 'tts_dim_on_lock';

  // ==================== 词典 ====================

  /// 词典 MDX 文件路径
  static const dictMdxPath = 'dict_mdx_path';

  /// 词典 MDD 资源文件路径
  static const dictMddPath = 'dict_mdd_path';

  // ==================== 字体 ====================

  /// 当前字体 ID
  static const currentFont = 'custom_font.current';

  // ==================== 其他 ====================

  /// 通知
  static const otherNotifications = 'other.notifications';

  /// 启动检查更新
  static const otherStartupCheck = 'other.startup_check';

  // ==================== 自动翻译 ====================

  /// 翻译服务提供商 ("openai" | "custom")
  static const translationProvider = 'translation.provider';

  /// API 端点地址
  static const translationApiUrl = 'translation.api_url';

  /// API 密钥
  static const translationApiKey = 'translation.api_key';

  /// 模型名（仅 OpenAI）
  static const translationModel = 'translation.model';

  /// 目标语言
  static const translationTargetLang = 'translation.target_lang';

  /// 源语言 ("auto" | "zh" | "en")
  static const translationSourceLang = 'translation.source_lang';

  /// 超时秒数
  static const translationTimeout = 'translation.timeout';
}
