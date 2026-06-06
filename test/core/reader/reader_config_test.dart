import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderTheme', () {
    test('values 应有 3 个主题', () {
      expect(ReaderTheme.values.length, equals(3));
    });

    test('light 主题属性', () {
      expect(ReaderTheme.light.id, equals('light'));
    });

    test('dark 主题属性', () {
      expect(ReaderTheme.dark.id, equals('dark'));
    });

    test('sepia 主题属性', () {
      expect(ReaderTheme.sepia.id, equals('sepia'));
    });

    test('fromId 有效 ID 返回对应主题', () {
      expect(ReaderTheme.fromId('light'), equals(ReaderTheme.light));
      expect(ReaderTheme.fromId('dark'), equals(ReaderTheme.dark));
      expect(ReaderTheme.fromId('sepia'), equals(ReaderTheme.sepia));
    });

    test('fromId 无效 ID 返回默认 light', () {
      expect(ReaderTheme.fromId('unknown'), equals(ReaderTheme.light));
      expect(ReaderTheme.fromId(''), equals(ReaderTheme.light));
    });

    test('fromId 大小写敏感', () {
      expect(ReaderTheme.fromId('Light'), equals(ReaderTheme.light));
    });
  });

  group('ReaderFontSize', () {
    test('values 应有 4 个大小', () {
      expect(ReaderFontSize.values.length, equals(4));
    });

    test('各档位大小值正确', () {
      expect(ReaderFontSize.small.size, equals(14));
      expect(ReaderFontSize.medium.size, equals(16));
      expect(ReaderFontSize.large.size, equals(18));
      expect(ReaderFontSize.xLarge.size, equals(20));
    });

    test('fromSize 已知大小返回对应档位', () {
      expect(ReaderFontSize.fromSize(14), equals(ReaderFontSize.small));
      expect(ReaderFontSize.fromSize(16), equals(ReaderFontSize.medium));
      expect(ReaderFontSize.fromSize(18), equals(ReaderFontSize.large));
      expect(ReaderFontSize.fromSize(20), equals(ReaderFontSize.xLarge));
    });

    test('fromSize 未知大小返回 medium', () {
      expect(ReaderFontSize.fromSize(15), equals(ReaderFontSize.medium));
      expect(ReaderFontSize.fromSize(999), equals(ReaderFontSize.medium));
    });
  });

  group('ReaderConfig', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    test('默认值初始化', () {
      final config = ReaderConfig(prefs);
      expect(config.theme.value, equals(ReaderTheme.light));
      expect(config.fontSize.value, equals(16.0));
      expect(config.lineHeight.value, equals(1.6));
      expect(config.paragraphSpacing.value, equals(16.0));
      expect(config.padding.value, equals(16.0));
      expect(config.readerBgColorIndex.value, equals(0));
      expect(config.autoScroll.value, isFalse);
      expect(config.autoScrollSpeed.value, equals(30));
      expect(config.letterSpacing.value, equals(0.0));
      expect(config.punctuationSqueeze.value, isTrue);
      expect(config.baselineAlign.value, isTrue);
    });

    test('从 SharedPreferences 加载已保存的值', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'reader_theme': 'sepia',
        'reader_font_size': 18.0,
        'reader_line_height': 2.0,
        'reader_bg_color_index': 2,
        'reader_auto_scroll': true,
      });
      final customPrefs = await SharedPreferences.getInstance();
      final config = ReaderConfig(customPrefs);
      expect(config.theme.value, equals(ReaderTheme.sepia));
      expect(config.fontSize.value, equals(18.0));
      expect(config.lineHeight.value, equals(2.0));
      expect(config.readerBgColorIndex.value, equals(2));
      expect(config.autoScroll.value, isTrue);
      // 未保存的字段使用默认值
      expect(config.paragraphSpacing.value, equals(16.0));
      expect(config.letterSpacing.value, equals(0.0));
    });

    test('setTheme 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.theme.value = ReaderTheme.dark;
      await config.theme.saveImmediately();

      expect(config.theme.value, equals(ReaderTheme.dark));
      expect(prefs.getString('reader_theme'), equals('dark'));
    });

    test('setFontSize 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.fontSize.value = 18.0;
      // 等待 debounce 写入
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.fontSize.value, equals(18.0));
      expect(prefs.getDouble('reader_font_size'), equals(18.0));
    });

    test('setLineHeight 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.lineHeight.value = 2.0;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.lineHeight.value, equals(2.0));
      expect(prefs.getDouble('reader_line_height'), equals(2.0));
    });

    test('setParagraphSpacing 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.paragraphSpacing.value = 24.0;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.paragraphSpacing.value, equals(24.0));
      expect(prefs.getDouble('reader_paragraph_spacing'), equals(24.0));
    });

    test('setPadding 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.padding.value = 32.0;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.padding.value, equals(32.0));
      expect(prefs.getDouble('reader_padding'), equals(32.0));
    });

    test('setReaderBgColorIndex 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.readerBgColorIndex.value = 3;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.readerBgColorIndex.value, equals(3));
      expect(prefs.getInt('reader_bg_color_index'), equals(3));
    });

    test('setAutoScroll 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.autoScroll.value = true;
      await config.autoScroll.saveImmediately();

      expect(config.autoScroll.value, isTrue);
      expect(prefs.getBool('reader_auto_scroll'), isTrue);
    });

    test('setAutoScrollSpeed 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.autoScrollSpeed.value = 60;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.autoScrollSpeed.value, equals(60));
      expect(prefs.getInt('reader_auto_scroll_speed'), equals(60));
    });

    test('setLetterSpacing 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.letterSpacing.value = 0.5;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(config.letterSpacing.value, equals(0.5));
      expect(prefs.getDouble('reader_letter_spacing'), equals(0.5));
    });

    test('setPunctuationSqueeze 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.punctuationSqueeze.value = false;
      await config.punctuationSqueeze.saveImmediately();

      expect(config.punctuationSqueeze.value, isFalse);
      expect(prefs.getBool('reader_punctuation_squeeze'), isFalse);
    });

    test('setBaselineAlign 更新信号并持久化', () async {
      final config = ReaderConfig(prefs);
      config.baselineAlign.value = false;
      await config.baselineAlign.saveImmediately();

      expect(config.baselineAlign.value, isFalse);
      expect(prefs.getBool('reader_baseline_align'), isFalse);
    });

    test('resetToDefault 重置所有设置', () async {
      final config = ReaderConfig(prefs);
      // 先改一些值
      config.theme.value = ReaderTheme.dark;
      config.fontSize.value = 18.0;
      config.autoScroll.value = true;
      config.letterSpacing.value = 0.5;

      // 重置
      await config.resetToDefault();

      // 验证信号复位
      expect(config.theme.value, equals(ReaderTheme.light));
      expect(config.fontSize.value, equals(ReaderFontSize.medium.size));
      expect(config.autoScroll.value, isFalse);
      expect(config.letterSpacing.value, equals(0.0));
      // 验证 SharedPreferences 同步写回
      await config.theme.saveImmediately();
      expect(prefs.getString('reader_theme'), equals('light'));
      await config.fontSize.saveImmediately();
      expect(prefs.getDouble('reader_font_size'), equals(16.0));
      await config.autoScroll.saveImmediately();
      expect(prefs.getBool('reader_auto_scroll'), isFalse);
    });
  });
}
