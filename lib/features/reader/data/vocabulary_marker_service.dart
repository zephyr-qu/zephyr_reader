import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/vocab_marker.dart' as rust;

@lazySingleton
class VocabularyMarkerService {
  Set<String> _allWords = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final words = rust.getAllVocabularyWords();
    _allWords = words.toSet();
    _loaded = true;
  }

  Set<String> get allWords => _allWords;
  Set<String> get cet6 => _allWords;
  Set<String> get ielts => _allWords;
  Set<String> get toefl => _allWords;

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
