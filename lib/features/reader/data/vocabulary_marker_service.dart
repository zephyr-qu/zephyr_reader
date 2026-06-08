import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/vocab_marker.dart' as rust;

@lazySingleton
/// 生词标记服务。
///
/// 从 Rust 侧加载词库（CET6/IELTS/TOEFL），提供文本中生词检测能力。
class VocabularyMarkerService {
  Set<String> _allWords = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _allWords = rust.getAllVocabularyWords().toSet();
    _loaded = true;
  }

  /// 全部内置词汇的不可变视图。
  UnmodifiableSetView<String> get allWords => UnmodifiableSetView(_allWords);

  /// 判断单词是否在词汇表中（不区分大小写）。
  bool isVocabularyWord(String word) => _allWords.contains(word.toLowerCase());

  /// CET-6 词汇（当前返回全量词库）。
  /// TODO: 多词库管理页面完成后返回独立词库
  UnmodifiableSetView<String> get cet6 => allWords;

  /// IELTS 词汇（当前返回全量词库）。
  /// TODO: 多词库管理页面完成后返回独立词库
  UnmodifiableSetView<String> get ielts => allWords;

  /// TOEFL 词汇（当前返回全量词库）。
  /// TODO: 多词库管理页面完成后返回独立词库
  UnmodifiableSetView<String> get toefl => allWords;
}
