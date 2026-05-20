library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/features/vocabulary/data/vocabulary_service.dart';

import '../../helpers/mock_rust_storage_service.dart';

VocabularyViewModel createViewModel() {
  return VocabularyViewModel(VocabularyService(MockRustStorageService()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabularyViewModel', () {
    late MockRustStorageService storage;
    late VocabularyService service;
    late VocabularyViewModel vm;

    setUp(() {
      storage = MockRustStorageService();
      service = VocabularyService(storage);
      vm = VocabularyViewModel(service);
    });

    group('词汇加载', () {
      test('初始状态应有空列表', () {
        expect(vm.words.value, isEmpty);
        expect(vm.stats.value, isNull);
        expect(vm.loading.value, isFalse);
        expect(vm.filterStatus.value, equals('learning'));
      });

      test('loadWords 应加载单词和统计', () async {
        await storage.addVocabularyWord(
          word: 'abandon',
          pinyin: 'fàng qì',
          translation: '放弃',
        );
        await storage.addVocabularyWord(
          word: 'absorb',
          pinyin: 'xī shōu',
          translation: '吸收',
        );

        await vm.loadWords();

        expect(vm.words.value.length, equals(2));
        expect(vm.stats.value, isNotNull);
        expect(vm.loading.value, isFalse);
      });

      test('loadWords 应筛选状态', () async {
        await storage.addVocabularyWord(
          word: 'abandon',
          pinyin: 'fàng qì',
          translation: '放弃',
        );
        final entry2 = await storage.addVocabularyWord(
          word: 'absorb',
          pinyin: 'xī shōu',
          translation: '吸收',
        );
        await storage.updateVocabularyStatus(id: entry2.id, status: 'known');

        await vm.loadWords();

        expect(vm.words.value.length, equals(1));
        expect(vm.words.value.first.status, equals('learning'));
      });

      test('默认 filterStatus 为 learning 时无匹配应返回空列表', () async {
        final entry = await storage.addVocabularyWord(
          word: 'test',
          pinyin: 'cè shì',
          translation: '测试',
        );
        await storage.updateVocabularyStatus(id: entry.id, status: 'known');

        await vm.loadWords();

        expect(vm.words.value, isEmpty);
      });

      test('loadWords 应始终重置 loading 状态', () async {
        vm.loading.value = true;
        await vm.loadWords();
        expect(vm.loading.value, isFalse);
      });
    });

    group('筛选和操作', () {
      test('setFilter 应切换筛选状态并重新加载', () async {
        final entry = await storage.addVocabularyWord(
          word: 'known_word',
          pinyin: 'yǐ zhī',
          translation: '已知',
        );
        await storage.updateVocabularyStatus(id: entry.id, status: 'known');

        await vm.setFilter('known');

        expect(vm.filterStatus.value, equals('known'));
        expect(vm.words.value.length, equals(1));
        expect(vm.words.value.first.word, equals('known_word'));
      });

      test('setFilter null 应清除筛选', () async {
        await storage.addVocabularyWord(
          word: 'test',
          pinyin: 'cè shì',
          translation: '测试',
        );

        await vm.setFilter(null);

        expect(vm.filterStatus.value, isNull);
        expect(vm.words.value.length, equals(1));
      });

      test('setFilter 应配合不同 status 筛选', () async {
        final entry = await storage.addVocabularyWord(
          word: 'word1',
          pinyin: 'p1',
          translation: 't1',
        );
        await storage.updateVocabularyStatus(id: entry.id, status: 'mastered');

        await vm.setFilter('mastered');

        expect(vm.words.value.length, equals(1));
        expect(vm.words.value.first.status, equals('mastered'));
      });

      test('updateStatus 应更新单词状态', () async {
        final entry = await storage.addVocabularyWord(
          word: 'test',
          pinyin: 'cè shì',
          translation: '测试',
        );
        await vm.loadWords();
        expect(vm.words.value.length, equals(1));

        await vm.updateStatus(entry.id, 'known');

        final updated = storage.searchVocabulary('test');
        expect((await updated).first.status, equals('known'));
      });

      test('deleteWord 应删除单词', () async {
        final entry = await storage.addVocabularyWord(
          word: 'test',
          pinyin: 'cè shì',
          translation: '测试',
        );
        await vm.loadWords();
        expect(vm.words.value.length, equals(1));

        await vm.deleteWord(entry.id);
        expect(vm.words.value.length, equals(0));
      });

      test('refresh 应重新加载单词', () async {
        await vm.refresh();
        expect(vm.loading.value, isFalse);
      });
    });
  });
}
