import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/format_utils.dart';
import 'package:zephyr_reader/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();

void main() {
  group('formatFileSize', () {
    test('0 bytes', () {
      expect(formatFileSize(0), equals('0 B'));
    });

    test('小于 1024 bytes', () {
      expect(formatFileSize(512), equals('512 B'));
      expect(formatFileSize(1023), equals('1023 B'));
    });

    test('边界值: 1024 bytes = 1.0 KB', () {
      expect(formatFileSize(1024), equals('1.0 KB'));
    });

    test('KB 范围', () {
      expect(formatFileSize(2048), equals('2.0 KB'));
      expect(formatFileSize(1024 * 1023), equals('1023.0 KB'));
    });

    test('边界值: 1 MB', () {
      expect(formatFileSize(1024 * 1024), equals('1.0 MB'));
    });

    test('MB 范围', () {
      expect(formatFileSize(5 * 1024 * 1024), equals('5.0 MB'));
      expect(formatFileSize(1024 * 1024 * 1023), equals('1023.0 MB'));
    });

    test('边界值: 1 GB', () {
      expect(formatFileSize(1024 * 1024 * 1024), equals('1.0 GB'));
    });

    test('GB 及以上', () {
      expect(formatFileSize(2 * 1024 * 1024 * 1024), equals('2.0 GB'));
      expect(formatFileSize(10 * 1024 * 1024 * 1024), equals('10.0 GB'));
    });
  });

  group('formatChars', () {
    test('小于 1000 直接显示数字', () {
      expect(formatChars(0, _l10n), equals('0chars'));
      expect(formatChars(999, _l10n), equals('999chars'));
    });

    test('边界值: 1000 显示千单位', () {
      expect(formatChars(1000, _l10n), equals('1.0Kchars'));
    });

    test('千范围', () {
      expect(formatChars(1500, _l10n), equals('1.5Kchars'));
      expect(formatChars(123456, _l10n), equals('123.5Kchars'));
    });

    test('大数值', () {
      expect(formatChars(9999999, _l10n), equals('10000.0Kchars'));
    });
  });
}
