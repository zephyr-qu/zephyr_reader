import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/vocab_marker.dart' as rust;

@lazySingleton
class VocabularyMarkerService {
  Set<String> _allWords = {};
  Set<String> _cet6Words = {};
  Set<String> _ieltsWords = {};
  Set<String> _toeflWords = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _allWords = rust.getAllVocabularyWords().toSet();
    _cet6Words = rust.getCet6Words().toSet();
    _ieltsWords = rust.getIeltsWords().toSet();
    _toeflWords = rust.getToeflWords().toSet();
    _loaded = true;
  }

  /// 全部词汇。
  Set<String> get allWords => _allWords;

  /// CET-6 词汇（仅该词库，不含雅思/托福）。
  UnmodifiableSetView<String> get cet6 => UnmodifiableSetView(_cet6Words);

  /// IELTS 词汇（仅该词库，不含四六级/托福）。
  UnmodifiableSetView<String> get ielts => UnmodifiableSetView(_ieltsWords);

  /// TOEFL 词汇（仅该词库，不含四六级/雅思）。
  UnmodifiableSetView<String> get toefl => UnmodifiableSetView(_toeflWords);

  bool isVocabularyWord(String word) {
    return _allWords.contains(word.toLowerCase());
  }

  List<(String, int, int)> scanText(String text) {
    final result = <(String, int, int)>[];
    final wordRegex = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?");
    for (final match in wordRegex.allMatches(text)) {
      if (isVocabularyWord(match.group(0)!)) {
        result.add((match.group(0)!, match.start, match.end));
      }
    }
    return result;
  }
}
