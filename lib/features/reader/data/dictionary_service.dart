library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/src/rust/api/dictionary.dart' as dict_api;

@injectable
class DictionaryService {
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    final dictFile = File('${appDir.path}/dictionary.db');
    if (!dictFile.existsSync()) {
      final data = await rootBundle.load('assets/dictionary.db');
      await dictFile.create(recursive: true);
      await dictFile.writeAsBytes(data.buffer.asUint8List());
    }
    await dict_api.initDictionary(path: dictFile.path);
    _initialized = true;
  }

  Future<List<dict_api.DictEntry>> lookup(String word) async {
    await ensureInitialized();
    return dict_api.lookupWord(word: word);
  }

  Future<List<dict_api.DictEntry>> fuzzySearch(String prefix, {int limit = 10}) async {
    await ensureInitialized();
    return dict_api.fuzzySearchDictionary(prefix: prefix, limit: limit);
  }

  Future<List<dict_api.DictEntry>> searchDefinitions(String query, {int limit = 10}) async {
    await ensureInitialized();
    return dict_api.searchDictionaryDefinitions(query: query, limit: limit);
  }

  Future<dict_api.DictInfo> info() async {
    await ensureInitialized();
    return dict_api.getDictionaryInfo();
  }

  Future<List<String>> segment(String text) async {
    await ensureInitialized();
    return dict_api.segmentText(text: text);
  }
}
