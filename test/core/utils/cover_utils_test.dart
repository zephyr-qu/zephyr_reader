import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/core/app_config.dart';

void main() {
  group('resolveCoverPath', () {
    test('null 输入返回 null', () {
      expect(resolveCoverPath(null), isNull);
    });

    test('空字符串输入返回 null', () {
      expect(resolveCoverPath(''), isNull);
    });

    test('有效相对路径拼接 AppConfig.instance.coverDir', () {
      AppConfig.instance.init(coverDir: '/test/covers');
      final result = resolveCoverPath('cover.jpg');
      expect(result, isNotNull);
      expect(result, contains('cover.jpg'));
      expect(result, contains('/test/covers'));
    });

    test('多级相对路径正确拼接', () {
      final result = resolveCoverPath('subdir/image.png');
      expect(result, contains('subdir/image.png'));
      expect(result, contains('/test/covers'));
    });

    test('多次调用返回一致路径', () {
      final r1 = resolveCoverPath('cover.jpg');
      final r2 = resolveCoverPath('cover.jpg');
      expect(r1, equals(r2));
    });
  });
}
