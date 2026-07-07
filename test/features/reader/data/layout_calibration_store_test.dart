import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/features/reader/data/layout_calibration_store.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';

class _MockPrefs extends Mock implements PreferencesService {}

const _measureParams = TypesetMeasureParams(
  width: 390,
  height: 844,
  pagePadding: 16,
  contentVerticalPadding: 20,
  fontSize: 16,
  lineHeight: 1.5,
  letterSpacing: 0,
  fontFamily: 'Noto Sans SC',
  devicePixelRatio: 3.0,
  baselineAlign: true,
  firstLineIndentChars: 2,
);

const _sampleData = CalibrationData(
  dpr: 3.0,
  cjkWidth: 16.0,
  asciiWidth: 9.6,
  digitWidth: 9.6,
  punctWidth: 16.0,
  latinExtWidth: 11.2,
  otherWidth: 12.8,
  effectiveLineWidthRatio: 0.976,
  lineHeightDp: 24.0,
);

void main() {
  group('LayoutCalibrationStore', () {
    late _MockPrefs prefs;

    setUp(() {
      prefs = _MockPrefs();
    });

    test('A1 save_load_roundtrip', () async {
      final key = LayoutCalibrationStore.cacheKey(_measureParams);

      when(() => prefs.setString(key, any())).thenAnswer((_) async => true);
      when(() => prefs.getString(key)).thenReturn(null);

      await LayoutCalibrationStore.save(prefs, key, _sampleData);

      final savedJson =
          verify(() => prefs.setString(key, captureAny())).captured.single
              as String;
      when(() => prefs.getString(key)).thenReturn(savedJson);

      final loaded = LayoutCalibrationStore.load(prefs, key);
      expect(loaded, isNotNull);
      expect(loaded!.dpr, _sampleData.dpr);
      expect(loaded.cjkWidth, _sampleData.cjkWidth);
      expect(
        loaded.effectiveLineWidthRatio,
        _sampleData.effectiveLineWidthRatio,
      );
      expect(loaded.lineHeightDp, _sampleData.lineHeightDp);
      expect(loaded.asciiWidth, _sampleData.asciiWidth);
    });

    test('A2 cache_key_stable', () {
      final k1 = LayoutCalibrationStore.cacheKey(_measureParams);
      final k2 = LayoutCalibrationStore.cacheKey(_measureParams);
      expect(k1, equals(k2));
    });

    test('A3 cache_key_font_change', () {
      const params2 = TypesetMeasureParams(
        width: 390,
        height: 844,
        pagePadding: 16,
        contentVerticalPadding: 20,
        fontSize: 20, // changed
        lineHeight: 1.5,
        letterSpacing: 0,
        fontFamily: 'Noto Sans SC',
        devicePixelRatio: 3.0,
        baselineAlign: true,
        firstLineIndentChars: 2,
      );
      final k1 = LayoutCalibrationStore.cacheKey(_measureParams);
      final k2 = LayoutCalibrationStore.cacheKey(params2);
      expect(k1, isNot(equals(k2)));
    });

    test('A4 corrupt_json_returns_null', () {
      final key = LayoutCalibrationStore.cacheKey(_measureParams);
      when(() => prefs.getString(key)).thenReturn('not valid json {{{');
      final loaded = LayoutCalibrationStore.load(prefs, key);
      expect(loaded, isNull);
    });

    test('A5 missing_fields_use_defaults', () {
      final key = LayoutCalibrationStore.cacheKey(_measureParams);
      // JSON missing effectiveLineWidthRatio and lineHeightDp
      final partialJson = jsonEncode({
        'dpr': 3.0,
        'cjkWidth': 16.0,
        'asciiWidth': 9.6,
        'digitWidth': 9.6,
        'punctWidth': 16.0,
        'latinExtWidth': 11.2,
        'otherWidth': 12.8,
        // effectiveLineWidthRatio omitted
        // lineHeightDp omitted
      });
      when(() => prefs.getString(key)).thenReturn(partialJson);
      final loaded = LayoutCalibrationStore.load(prefs, key);
      expect(loaded, isNotNull);
      expect(loaded!.effectiveLineWidthRatio, 0.97); // default
      expect(loaded.lineHeightDp, 0); // default
    });
  });
}
