import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/date_formatters.dart';
import 'package:zephyr_reader/l10n/app_localizations_en.dart';

/// 测试用 AppLocalizations（英文）
final _l10n = AppLocalizationsEn();

void main() {
  group('formatRelativeTime', () {
    test('刚刚 — 当前时间', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now, _l10n), equals('Just now'));
    });

    test('刚刚 — 1分钟内', () {
      final past = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(past, _l10n), equals('Just now'));
    });

    test('N分钟前', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(past, _l10n), equals('5 min ago'));
    });

    test('N小时前', () {
      final past = DateTime.now().subtract(const Duration(hours: 3));
      expect(formatRelativeTime(past, _l10n), equals('3 hr ago'));
    });

    test('超过1天显示月-日 时:分格式', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final result = formatRelativeTime(past, _l10n);
      expect(result, contains('-'));
      expect(result, contains(':'));
    });

    test('边界值: 59分钟显示分钟', () {
      final past = DateTime.now().subtract(const Duration(minutes: 59));
      expect(formatRelativeTime(past, _l10n), equals('59 min ago'));
    });

    test('边界值: 60分钟显示小时', () {
      final past = DateTime.now().subtract(const Duration(minutes: 60));
      expect(formatRelativeTime(past, _l10n), contains('hr ago'));
    });

    test('边界值: 23小时显示小时', () {
      final past = DateTime.now().subtract(const Duration(hours: 23));
      expect(formatRelativeTime(past, _l10n), contains('hr ago'));
    });

    test('边界值: 24小时显示日期', () {
      final past = DateTime.now().subtract(const Duration(hours: 24));
      final result = formatRelativeTime(past, _l10n);
      expect(result, contains('-'));
      expect(result, contains(':'));
    });

    test('未来时间应显示刚刚', () {
      final future = DateTime.now().add(const Duration(seconds: 10));
      expect(formatRelativeTime(future, _l10n), equals('Just now'));
    });

    test('零时长', () {
      final same = DateTime.now();
      expect(formatRelativeTime(same, _l10n), equals('Just now'));
    });
  });

  group('formatDateYYYYMMDD', () {
    test('标准日期格式', () {
      final date = DateTime(2026, 5, 29);
      expect(formatDateYYYYMMDD(date), equals('2026-05-29'));
    });

    test('个位数月日补零', () {
      final date = DateTime(2026, 1, 5);
      expect(formatDateYYYYMMDD(date), equals('2026-01-05'));
    });

    test('年末日期', () {
      final date = DateTime(2026, 12, 31);
      expect(formatDateYYYYMMDD(date), equals('2026-12-31'));
    });

    test('年初日期', () {
      final date = DateTime(2026, 1, 1);
      expect(formatDateYYYYMMDD(date), equals('2026-01-01'));
    });
  });
}
