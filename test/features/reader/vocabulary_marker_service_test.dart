library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/src/rust/api/vocab_marker.dart' as rust;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabularyMarkerService', () {
    late VocabularyMarkerService service;

    setUp(() async {
      service = VocabularyMarkerService();
      await service.ensureLoaded();
    });

    group('生词标记', () {
      test('ensureLoaded 应加载词表', () {
        expect(service.cet6.isNotEmpty, isTrue);
        expect(service.ielts.isNotEmpty, isTrue);
        expect(service.toefl.isNotEmpty, isTrue);
        expect(service.allWords.length, greaterThan(2000));
      });

      test('isVocabularyWord 应识别 CET-6 词汇', () {
        expect(service.isVocabularyWord('abandon'), isTrue);
        expect(service.isVocabularyWord('abandoned'), isFalse);
        expect(service.isVocabularyWord('zzzzz'), isFalse);
      });

      test('isVocabularyWord 应大小写不敏感', () {
        expect(service.isVocabularyWord('ABANDON'), isTrue);
        expect(service.isVocabularyWord('Abandon'), isTrue);
      });

      test('scanText 应返回文本中所有生词位置', () {
        final text = 'We should not abandon our academic pursuits.';
        final result = service.scanText(text);

        expect(result.length, equals(2));
        expect(result[0].$1, equals('abandon'));
        expect(result[1].$1, equals('academic'));
      });

      test('scanText 应返回正确的偏移位置', () {
        final text = 'abandon academic';
        final result = service.scanText(text);

        expect(result[0].$2, equals(0));
        expect(result[0].$3, equals(7));
        expect(result[1].$2, equals(8));
        expect(result[1].$3, equals(16));
      });

      test('scanText 英文中应跳过中文', () {
        final text = '放弃abandon学术academic研究';
        final result = service.scanText(text);

        expect(result.length, equals(2));
        expect(result[0].$1, equals('abandon'));
        expect(result[1].$1, equals('academic'));
      });

      test('scanText 空文本应返回空列表', () {
        expect(service.scanText(''), isEmpty);
        expect(service.scanText('纯中文文本'), isEmpty);
      });
    });

    group('Rust scan_for_vocabulary', () {
      test('Rust 扫描应与 Dart scanText 结果一致', () async {
        final texts = [
          'We should not abandon our academic pursuits.',
          'abandon academic',
          '放弃abandon学术academic研究',
          '',
          '纯中文文本',
        ];
        for (final text in texts) {
          final dartResult = service.scanText(text);
          final rustResult = await rust.scanForVocabulary(text: text);
          expect(
            rustResult.map((m) => m.word).toList(),
            equals(dartResult.map((t) => t.$1).toList()),
            reason: 'Mismatch for text: "$text"',
          );
        }
      });
    });
  });
}
