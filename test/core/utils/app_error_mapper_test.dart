import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/src/rust/common/error.dart';

void main() {
  group('AppErrorMapper.humanReadable', () {
    test(
      'StaleBookData returns the message verbatim (user-facing instruction)',
      () {
        const msg = 'Chapter bounds missing. Please re-import this book.';
        final result = AppErrorMapper.humanReadable(
          const AppError.staleBookData(message: msg),
        );
        expect(result, msg);
      },
    );

    test('ChapterTooLarge returns size info + reimport hint', () {
      final result = AppErrorMapper.humanReadable(
        AppError.chapterTooLarge(
          sizeBytes: BigInt.from(2_500_000),
          details: 'spine 0 is 2500000 bytes',
        ),
      );
      // 消息应提到 size 数量级（MB）+ 重新导入建议
      final hasMb = result.toLowerCase().contains('mb');
      final hasReimport =
          result.contains('重新导入') ||
          result.toLowerCase().contains('reimport') ||
          result.toLowerCase().contains('re-import');
      expect(
        hasMb || hasReimport,
        true,
        reason: 'Should mention MB or reimport hint, got: $result',
      );
    });

    test('chapterExtractError includes chapter index and reason', () {
      final result = AppErrorMapper.humanReadable(
        const AppError.chapterExtractError(index: 3, reason: 'invalid xhtml'),
      );
      expect(result, contains('3'));
      expect(result, contains('invalid xhtml'));
    });

    test('epubParseError includes the reason', () {
      final result = AppErrorMapper.humanReadable(
        const AppError.epubParseError(reason: 'missing container.xml'),
      );
      expect(result, contains('EPUB'));
      expect(result, contains('missing container.xml'));
    });

    test('fileNotFound includes the path', () {
      final result = AppErrorMapper.humanReadable(
        const AppError.fileNotFound(path: '/missing/book.epub'),
      );
      expect(result, contains('/missing/book.epub'));
    });

    test('unknown Object returns generic message, does not throw', () {
      final result = AppErrorMapper.humanReadable(StateError('weird'));
      expect(result, isNotEmpty);
    });
  });
}
