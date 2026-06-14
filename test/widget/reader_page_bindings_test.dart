// test/widget/reader_page_bindings_test.dart
//
// HookBuilder Widget 测试 — useReaderBindings 信号绑定验证
//
// 验证 useReaderBindings 能正确连接 ReaderViewModel 的信号，
// 并在 ViewModel 信号变化时同步更新。

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/application/reader_page_state.dart';
import 'package:zephyr_reader/features/reader/page/binding/reader_page_bindings.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// ===== Mock Config =====

class _MockSharedPreferences extends Mock implements SharedPreferences {
  _MockSharedPreferences() {
    when(() => getString(any())).thenReturn(null);
    when(() => getBool(any())).thenReturn(null);
    when(() => getInt(any())).thenReturn(null);
    when(() => getDouble(any())).thenReturn(null);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
  }
}

class _MockReaderConfig implements ReaderConfig {
  @override
  final theme = PersistedSignal<ReaderTheme>(
    ReaderTheme.light,
    _MockSharedPreferences(),
    'theme',
  );
  @override
  final readerBgColorIndex = PersistedSignal<int>(
    0,
    _MockSharedPreferences(),
    'readerBgColorIndex',
  );
  @override
  final brightnessOverlay = signal<double>(0.0);
  @override
  final fontSize = PersistedSignal<double>(
    16.0,
    _MockSharedPreferences(),
    'fontSize',
  );
  @override
  final lineHeight = PersistedSignal<double>(
    1.6,
    _MockSharedPreferences(),
    'lineHeight',
  );
  @override
  final letterSpacing = PersistedSignal<double>(
    0.0,
    _MockSharedPreferences(),
    'letterSpacing',
  );
  @override
  final paragraphSpacing = PersistedSignal<double>(
    0.0,
    _MockSharedPreferences(),
    'paragraphSpacing',
  );
  @override
  final padding = PersistedSignal<double>(
    16.0,
    _MockSharedPreferences(),
    'padding',
  );
  @override
  final writingDirection = PersistedSignal<WritingDirection>(
    WritingDirection.ltr,
    _MockSharedPreferences(),
    'writingDirection',
  );
  @override
  final baselineAlign = PersistedSignal<bool>(
    true,
    _MockSharedPreferences(),
    'baselineAlign',
  );
  @override
  final textAlign = PersistedSignal<TextAlign>(
    TextAlign.left,
    _MockSharedPreferences(),
    'textAlign',
  );
  @override
  final autoScroll = PersistedSignal<bool>(
    false,
    _MockSharedPreferences(),
    'autoScroll',
  );
  @override
  final autoScrollSpeed = PersistedSignal<int>(
    8,
    _MockSharedPreferences(),
    'autoScrollSpeed',
  );
  @override
  final tapLayout = PersistedSignal<TapLayout>(
    TapLayout.classic,
    _MockSharedPreferences(),
    'tapLayout',
  );
  @override
  final punctuationSqueeze = PersistedSignal<bool>(
    true,
    _MockSharedPreferences(),
    'punctuationSqueeze',
  );
  @override
  final followSystemFontScale = PersistedSignal<bool>(
    false,
    _MockSharedPreferences(),
    'followSystemFontScale',
  );
  @override
  bool get isDarkMode => theme.value == ReaderTheme.dark;
}

// ===== Mock ViewModel =====

class MockReaderViewModel extends Mock implements ReaderViewModel {
  @override
  final config = _MockReaderConfig();
  @override
  final state = ReaderPageState();
  @override
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));
  @override
  final pageIndex = signal(0);
  @override
  final totalPages = signal(1);
  @override
  final isLoading = signal(false);
  @override
  final error = signal<String?>(null);
  @override
  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );
  @override
  final autoScrollTick = signal(0);
  @override
  final highlights = asyncSignal<List<Note>>(AsyncState.data([]));
  @override
  final toastMessage = signal('');
  @override
  late final ReadonlySignal<String> progressText = computed(() => '0%');
  @override
  late final ReadonlySignal<String> currentChapterTitle = computed(
    () => 'Chapter',
  );
  @override
  late final ReadonlySignal<double> fontSizeDouble = computed(
    () => config.fontSize.value,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReaderViewModel mockVm;

  setUp(() {
    mockVm = MockReaderViewModel();
  });

  group('useReaderBindings', () {
    testWidgets('绑定 ReaderViewModel 所有信号', (tester) async {
      late ReaderPageBindings bindings;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bindings = useReaderBindings(mockVm);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // 验证信号值同步
      expect(bindings.fontSize, equals(16.0));
      expect(bindings.lineHeight, equals(1.6));
      expect(bindings.bgIndex, equals(0));
      expect(bindings.isLoading, isFalse);
      expect(bindings.currentBookId, equals(''));
      expect(bindings.chapterIndex, equals(0));
      expect(bindings.pageIndex, equals(0));
      expect(bindings.totalPages, equals(1));
    });

    testWidgets('ViewModel 信号变化时绑定自动更新', (tester) async {
      late ReaderPageBindings bindings;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bindings = useReaderBindings(mockVm);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(bindings.fontSize, equals(16.0));

      // 更新 ViewModel 信号
      mockVm.config.fontSize.value = 20.0;
      await tester.pump();

      // 绑定应反映新值
      expect(bindings.fontSize, equals(20.0));
    });

    testWidgets('多个信号独立更新', (tester) async {
      late ReaderPageBindings bindings;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bindings = useReaderBindings(mockVm);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // 同时更新多个信号
      mockVm.config.fontSize.value = 18.0;
      mockVm.state.chapterIndex.value = 5;
      await tester.pump();

      expect(bindings.fontSize, equals(18.0));
      expect(bindings.chapterIndex, equals(5));
    });

    testWidgets('useSignalEffect 在 mount 时触发', (tester) async {
      int effectCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              useSignalEffect(() {
                effectCallCount++;
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // effect 在 mount 时至少触发一次
      expect(effectCallCount, equals(1));
    });

    testWidgets('useSignalEffect 响应信号变化', (tester) async {
      int effectCallCount = 0;
      final trigger = signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              useSignalEffect(() {
                trigger.value; // 订阅
                effectCallCount++;
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(effectCallCount, equals(1));

      trigger.value = 1;
      await tester.pump();
      expect(effectCallCount, equals(2));

      trigger.value = 2;
      await tester.pump();
      expect(effectCallCount, equals(3));
    });
  });
}
