import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_preview.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

void main() {
  late ReaderConfig config;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    config = ReaderConfig(SharedPreferencesService(prefs));
    if (getIt.isRegistered<ReaderConfig>()) {
      getIt.unregister<ReaderConfig>();
    }
    getIt.registerSingleton<ReaderConfig>(config);
  });

  /// 高视口让懒加载 ListView 一次性渲染所有分区。
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TypographySettingsPage(),
      ),
    );
    // 等待预览动画 + persisted 信号 debounce 结束
    await tester.pumpAndSettle();
  }

  testWidgets('preview stays compact on a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    final previewHeight = tester.getSize(find.byType(TypographyPreview)).height;
    expect(
      previewHeight,
      lessThan(844 * 0.4),
      reason: '默认 100% 字号的预览不应占据接近整屏的高度',
    );
    expect(find.text('字体'), findsOneWidget);

    config.fontSize.value = 200;
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(TypographyPreview)).height,
      lessThan(844 * 0.65),
      reason: '最大字号的预览仍应保留足够空间给设置项',
    );
  });

  testWidgets('renders all typography sections', (tester) async {
    useTallViewport(tester);
    await pumpPage(tester);

    expect(find.text('实时预览'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Serif'), findsOneWidget);
    expect(find.text('Noto Serif SC'), findsOneWidget);
    expect(find.text('字体大小'), findsOneWidget);
    expect(find.text('页边距'), findsOneWidget);
    expect(find.text('行间距'), findsOneWidget);
    // 低频/技术项已移除：字重、字间距、段间距、首行缩进
    expect(find.text('字重'), findsNothing);
    expect(find.text('字间距'), findsNothing);
    expect(find.text('段间距'), findsNothing);
    expect(find.text('首行缩进'), findsNothing);
    expect(find.text('文本对齐'), findsNothing);
    expect(find.text('阅读模式'), findsOneWidget);
    expect(find.text('分页'), findsOneWidget);
    expect(find.text('滚动'), findsOneWidget);
  });

  testWidgets('font family selection updates ReaderConfig', (tester) async {
    useTallViewport(tester);
    await pumpPage(tester);

    expect(config.fontFamily.value, 'System');
    await tester.tap(find.text('Serif'));
    // 等待 persistedString 150ms debounce 落盘，避免遗留定时器
    await tester.pump(const Duration(milliseconds: 200));
    expect(config.fontFamily.value, 'Serif');
  });

  testWidgets('reading mode selection updates ReaderConfig', (tester) async {
    useTallViewport(tester);
    await pumpPage(tester);

    expect(config.readingMode.value, ReadingMode.pagination);
    await tester.tap(find.text('滚动'));
    await tester.pump();
    expect(config.readingMode.value, ReadingMode.scroll);
  });

  testWidgets('font size slider updates ReaderConfig', (tester) async {
    useTallViewport(tester);
    await pumpPage(tester);

    expect(config.fontSize.value, ReaderTypographyDefaults.fontSize);
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(60, 0));
    // 等待 persisted 信号 debounce 落盘
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      config.fontSize.value,
      greaterThan(ReaderTypographyDefaults.fontSize),
    );
  });
}
