import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';

class _MockSharedPreferences extends Mock implements PreferencesService {
  _MockSharedPreferences() {
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => remove(any())).thenAnswer((_) async => true);
    // Default getter stubs: return the defaultValue argument when no stored value
    when(
      () => getInt(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (inv) => inv.namedArguments[const Symbol('defaultValue')] as int,
    );
    when(
      () => getBool(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (inv) => inv.namedArguments[const Symbol('defaultValue')] as bool,
    );
    when(
      () => getDouble(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (inv) => inv.namedArguments[const Symbol('defaultValue')] as double,
    );
    when(() => getString(any())).thenReturn(null);
    when(() => getIntOrNull(any())).thenReturn(null);
  }
}

enum _TestEnum { alpha, beta, gamma }

void main() {
  late _MockSharedPreferences prefs;

  setUp(() {
    prefs = _MockSharedPreferences();
  });

  group('PersistedSignal core', () {
    group('initial value from prefs', () {
      test('从 prefs 读取初始值', () {
        when(
          () => prefs.getInt('age', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(42);
        final ps = persistedInt(prefs, 'age', 0);
        expect(ps.value, equals(42));
      });

      test('prefs 无存储值时使用 defaultValue', () {
        // Default stub returns defaultValue (99) – simulates no stored value
        final ps = persistedInt(prefs, 'age', 99);
        expect(ps.value, equals(99));
      });

      test('bool 类型初始值', () {
        when(
          () => prefs.getBool('flag', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(true);
        final ps = persistedBool(prefs, 'flag', false);
        expect(ps.value, isTrue);
      });

      test('double 类型初始值', () {
        when(
          () => prefs.getDouble(
            'ratio',
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(1.5);
        final ps = persistedDouble(prefs, 'ratio', 0.0);
        expect(ps.value, equals(1.5));
      });

      test('String 类型初始值', () {
        when(() => prefs.getString('name')).thenReturn('Alice');
        final ps = persistedString(prefs, 'name', 'default');
        expect(ps.value, equals('Alice'));
      });
    });

    group('setter behavior', () {
      test('设置不同值触发 save', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          0,
          debounce: const Duration(minutes: 1),
        );

        ps.value = 10;
        await ps.saveImmediately();

        verify(() => prefs.setInt('x', 10)).called(1);
      });

      test('设置相同值被去重', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          0,
          debounce: const Duration(minutes: 1),
        );

        ps.value = 10;
        ps.value = 10;
        await ps.saveImmediately();

        // saveImmediately 只保存当前值，验证 setInt 只触发了一次（去重）
        verify(() => prefs.setInt('x', 10)).called(1);
      });

      test('非零 debounce 延迟写入', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          0,
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = 10;
        // 立即验证不应写入
        verifyNever(() => prefs.setInt('x', 10));

        // 等待 debounce
        await Future<void>.delayed(const Duration(milliseconds: 60));
        verify(() => prefs.setInt('x', 10)).called(1);
      });
    });

    group('reset()', () {
      test('reset 恢复默认值并触发保存', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          42,
          debounce: const Duration(minutes: 1),
        );

        ps.value = 100;
        expect(ps.value, equals(100));

        ps.reset();
        await ps.saveImmediately();
        expect(ps.value, equals(42));
        verify(() => prefs.setInt('x', 42)).called(1);
      });
    });

    group('dispose()', () {
      test('dispose 取消待写入的定时器', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          0,
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = 10;
        ps.dispose();

        await Future<void>.delayed(const Duration(milliseconds: 60));
        verifyNever(() => prefs.setInt('x', 10));
      });

      test('dispose 后 setter 不触发保存', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          0,
          debounce: const Duration(minutes: 1),
        );

        ps.dispose();
        ps.value = 99;
        await ps.saveImmediately();

        verifyNever(() => prefs.setInt('x', 99));
      });

      test('dispose 不改变信号值', () {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(prefs, 'x', 0);

        ps.dispose();
        expect(ps.value, equals(5));
      });
    });

    group('saveImmediately()', () {
      test('跳过 debounce 直接写入', () async {
        when(
          () => prefs.getInt('x', defaultValue: any(named: 'defaultValue')),
        ).thenReturn(5);
        final ps = persistedInt(
          prefs,
          'x',
          0,
          debounce: const Duration(minutes: 1),
        );

        ps.value = 10;
        await ps.saveImmediately();

        verify(() => prefs.setInt('x', 10)).called(1);
      });
    });
  });

  group('factory functions', () {
    test('persistedBool', () async {
      when(
        () => prefs.getBool('flag', defaultValue: any(named: 'defaultValue')),
      ).thenReturn(true);
      final ps = persistedBool(
        prefs,
        'flag',
        false,
        debounce: const Duration(minutes: 1),
      );
      expect(ps.value, isTrue);

      ps.value = false;
      await ps.saveImmediately();
      verify(() => prefs.setBool('flag', false)).called(1);
    });

    test('persistedInt', () async {
      when(
        () => prefs.getInt('count', defaultValue: any(named: 'defaultValue')),
      ).thenReturn(7);
      final ps = persistedInt(
        prefs,
        'count',
        0,
        debounce: const Duration(minutes: 1),
      );
      expect(ps.value, equals(7));

      ps.value = 3;
      await ps.saveImmediately();
      verify(() => prefs.setInt('count', 3)).called(1);
    });

    test('persistedDouble', () async {
      when(
        () => prefs.getDouble('pi', defaultValue: any(named: 'defaultValue')),
      ).thenReturn(3.14);
      final ps = persistedDouble(
        prefs,
        'pi',
        0.0,
        debounce: const Duration(minutes: 1),
      );
      expect(ps.value, equals(3.14));

      ps.value = 2.72;
      await ps.saveImmediately();
      verify(() => prefs.setDouble('pi', 2.72)).called(1);
    });

    test('persistedString', () async {
      when(() => prefs.getString('greeting')).thenReturn('hello');
      final ps = persistedString(
        prefs,
        'greeting',
        'default',
        debounce: const Duration(minutes: 1),
      );
      expect(ps.value, equals('hello'));

      ps.value = 'world';
      await ps.saveImmediately();
      verify(() => prefs.setString('greeting', 'world')).called(1);
    });

    group('persistedNullableString', () {
      test('prefs 有值时读取', () {
        when(() => prefs.getString('note')).thenReturn('some note');
        final ps = persistedNullableString(prefs, 'note');
        expect(ps.value, equals('some note'));
      });

      test('prefs 无值时默认 null', () {
        when(() => prefs.getString('note')).thenReturn(null);
        final ps = persistedNullableString(prefs, 'note');
        expect(ps.value, isNull);
      });

      test('设 null 时调用 remove', () async {
        when(() => prefs.getString('note')).thenReturn('value');
        final ps = persistedNullableString(
          prefs,
          'note',
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = null;
        await ps.saveImmediately();
        verify(() => prefs.remove('note')).called(1);
      });

      test('设非 null 时调用 setString', () async {
        when(() => prefs.getString('note')).thenReturn(null);
        final ps = persistedNullableString(
          prefs,
          'note',
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = 'hello';
        await ps.saveImmediately();
        verify(() => prefs.setString('note', 'hello')).called(1);
      });
    });

    group('persistedNullableInt', () {
      test('prefs 有值时读取', () {
        when(() => prefs.getIntOrNull('color')).thenReturn(0xFF0000);
        final ps = persistedNullableInt(prefs, 'color');
        expect(ps.value, equals(0xFF0000));
      });

      test('prefs 无值时默认 null', () {
        when(() => prefs.getIntOrNull('color')).thenReturn(null);
        final ps = persistedNullableInt(prefs, 'color');
        expect(ps.value, isNull);
      });

      test('设 null 时调用 remove', () async {
        when(() => prefs.getIntOrNull('color')).thenReturn(255);
        final ps = persistedNullableInt(
          prefs,
          'color',
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = null;
        await ps.saveImmediately();
        verify(() => prefs.remove('color')).called(1);
      });
    });

    group('persistedEnum', () {
      test('prefs 有值时解析', () {
        when(() => prefs.getString('mode')).thenReturn('beta');
        final ps = persistedEnum<_TestEnum>(
          prefs,
          'mode',
          _TestEnum.alpha,
          (s) => _TestEnum.values.firstWhere((e) => e.name == s),
        );
        expect(ps.value, equals(_TestEnum.beta));
      });

      test('prefs 无值时使用默认值', () {
        when(() => prefs.getString('mode')).thenReturn(null);
        final ps = persistedEnum<_TestEnum>(
          prefs,
          'mode',
          _TestEnum.gamma,
          (s) => _TestEnum.values.firstWhere((e) => e.name == s),
        );
        expect(ps.value, equals(_TestEnum.gamma));
      });

      test('写入时调用 setString 存 name', () async {
        when(() => prefs.getString('mode')).thenReturn(null);
        final ps = persistedEnum<_TestEnum>(
          prefs,
          'mode',
          _TestEnum.alpha,
          (s) => _TestEnum.values.firstWhere((e) => e.name == s),
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = _TestEnum.beta;
        await ps.saveImmediately();
        verify(() => prefs.setString('mode', 'beta')).called(1);
      });

      test('解析失败时返回默认值', () {
        when(() => prefs.getString('mode')).thenReturn('invalid');
        final ps = persistedEnum<_TestEnum>(
          prefs,
          'mode',
          _TestEnum.alpha,
          (s) => _TestEnum.values.firstWhere((e) => e.name == s),
        );
        expect(ps.value, equals(_TestEnum.alpha));
      });
    });

    group('persistedEnumCustom', () {
      test('使用自定义序列化/反序列化', () {
        when(() => prefs.getString('sort')).thenReturn('2');
        final ps = persistedEnumCustom<intTestEnum>(
          prefs,
          'sort',
          intTestEnum.ten,
          (s) => intTestEnum.values.firstWhere((e) => e.value == int.parse(s)),
          (e) => e.value.toString(),
        );
        expect(ps.value, equals(intTestEnum.two));
      });

      test('自定义序列化写入', () async {
        when(() => prefs.getString('sort')).thenReturn(null);
        final ps = persistedEnumCustom<intTestEnum>(
          prefs,
          'sort',
          intTestEnum.ten,
          (s) => intTestEnum.values.firstWhere((e) => e.value == int.parse(s)),
          (e) => e.value.toString(),
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = intTestEnum.five;
        await ps.saveImmediately();
        verify(() => prefs.setString('sort', '5')).called(1);
      });
    });

    group('persistedColor', () {
      test('prefs 有值时读取 Color', () {
        when(() => prefs.getIntOrNull('accent')).thenReturn(0xFFF59E0B);
        final ps = persistedColor(prefs, 'accent');
        expect(ps.value, equals(const Color(0xFFF59E0B)));
      });

      test('prefs 无值时默认 null', () {
        when(() => prefs.getIntOrNull('accent')).thenReturn(null);
        final ps = persistedColor(prefs, 'accent');
        expect(ps.value, isNull);
      });

      test('设 null 时调用 remove', () async {
        when(() => prefs.getIntOrNull('accent')).thenReturn(0xFF000000);
        final ps = persistedColor(
          prefs,
          'accent',
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = null;
        await ps.saveImmediately();
        verify(() => prefs.remove('accent')).called(1);
      });

      test('设 Color 时调用 setInt 存 ARGB32', () async {
        when(() => prefs.getIntOrNull('accent')).thenReturn(null);
        final ps = persistedColor(
          prefs,
          'accent',
          debounce: const Duration(milliseconds: 50),
        );

        ps.value = const Color(0xFF448AFF);
        await ps.saveImmediately();
        verify(() => prefs.setInt('accent', 0xFF448AFF)).called(1);
      });
    });
  });
}

// ignore: camel_case_types
enum intTestEnum { ten, two, five }

extension on intTestEnum {
  int get value {
    return switch (this) {
      intTestEnum.ten => 10,
      intTestEnum.two => 2,
      intTestEnum.five => 5,
    };
  }
}
