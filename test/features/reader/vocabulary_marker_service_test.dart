// test/features/reader/vocabulary_marker_service_test.dart
//
// 注意: Python 侧单元测试覆盖纯逻辑，Dart 侧仅做集成测试。
// 该文件在当前 `test/` 目录下会跳过所有的 FFI 依赖测试，因为 Rust 初始化
// 在纯 Dart 测试环境中不可用。
// 对应的 E2E 集成测试见 test_driver/e2e_flow_test.dart 中「单词标记服务」分组。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/src/rust/api/vocab_marker.dart' as rust;
import 'package:zephyr_reader/src/rust/frb_generated.dart';

/// 尝试检查 Rust 是否可用
Future<bool> _isRustAvailable() async {
  try {
    await RustLib.init();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool rustAvailable;

  setUpAll(() async {
    rustAvailable = await _isRustAvailable();
  });

  group('VocabularyMarkerService', () {
    late VocabularyMarkerService service;

    setUp(() async {
      service = VocabularyMarkerService();
      if (rustAvailable) {
        await service.ensureLoaded();
      }
    });

    group('生词标记', () {
      test('ensureLoaded 应加载词表', () {
        if (!rustAvailable) return;
        expect(service.cet6.isNotEmpty, isTrue);
        expect(service.ielts.isNotEmpty, isTrue);
        expect(service.toefl.isNotEmpty, isTrue);
        expect(service.allWords.length, greaterThan(2000));
      });

      test('isVocabularyWord 应识别 CET-6 词汇', () {
        if (!rustAvailable) return;
        expect(service.isVocabularyWord('abandon'), isTrue);
        expect(service.isVocabularyWord('abandoned'), isFalse);
        expect(service.isVocabularyWord('zzzzz'), isFalse);
      });

      test('isVocabularyWord 应大小写不敏感', () {
        if (!rustAvailable) return;
        expect(service.isVocabularyWord('ABANDON'), isTrue);
        expect(service.isVocabularyWord('Abandon'), isTrue);
      });

      test('scanText 应返回文本中所有生词位置', () {
        if (!rustAvailable) return;
        final text = 'We should not abandon our academic pursuits.';
        final result = service.scanText(text);

        expect(result.length, equals(2));
        expect(result[0].$1, equals('abandon'));
        expect(result[1].$1, equals('academic'));
      });

      test('scanText 应返回正确的偏移位置', () {
        if (!rustAvailable) return;
        final text = 'abandon academic';
        final result = service.scanText(text);

        expect(result[0].$2, equals(0));
        expect(result[0].$3, equals(7));
        expect(result[1].$2, equals(8));
        expect(result[1].$3, equals(16));
      });

      test('scanText 英文中应跳过中文', () {
        if (!rustAvailable) return;
        final text = '放弃abandon学术academic研究';
        final result = service.scanText(text);

        expect(result.length, equals(2));
        expect(result[0].$1, equals('abandon'));
        expect(result[1].$1, equals('academic'));
      });

      test('scanText 空文本应返回空列表', () {
        if (!rustAvailable) return;
        expect(service.scanText(''), isEmpty);
        expect(service.scanText('纯中文文本'), isEmpty);
      });
    });

    group('Rust scan_for_vocabulary', () {
      test('Rust 扫描应与 Dart scanText 结果一致', () async {
        if (!rustAvailable) return;
        final texts = [
          'We should not abandon our academic pursuits.',
          'abandon academic',
          '放弃abandon学术academic研究',
          '',
          '纯中文文本',
        ];
        for (final text in texts) {
          final dartResult = service.scanText(text);
          final rustResult = rust.scanForVocabulary(text: text);
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
