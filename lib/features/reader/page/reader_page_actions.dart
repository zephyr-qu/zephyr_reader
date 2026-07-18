import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import 'package:zephyr_reader/src/rust/api/dictionary.dart'
    as dict_api;
import 'package:zephyr_reader/src/rust/api/vocab.dart' as vocab_api;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';

String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<void> addToVocabulary(
  BuildContext context,
  ReaderViewModel vm,
  String word, {
  String? definition,
  String? bookId,
  int? chapterIndex,
  int? charOffset,
}) async {
  final trimmed = word.trim();
  final l10n = AppLocalizations.of(context)!;
  if (trimmed.isEmpty) return;

  try {
    String translation;
    if (definition != null) {
      translation = _stripHtml(definition);
      if (translation.length > 200) {
        translation = '${translation.substring(0, 200)}…';
      }
    } else {
      final result = await dict_api.lookupMdict(word: trimmed);
      final entry = result?.exact;
      translation = entry != null ? _stripHtml(entry.definitionHtml) : trimmed;
      if (translation.length > 200) {
        translation = '${translation.substring(0, 200)}…';
      }
    }

    await vocab_api.createVocabularyWord(
      word: trimmed,
      pinyin: '',
      translation: translation.isEmpty ? trimmed : translation,
      bookId: bookId,
      contextSentence: null,
    );
    vm.toastMessage.value = l10n.addedToVocabulary(trimmed);
  } catch (e) {
    vm.toastMessage.value = l10n.addToVocabFailed(e.toString());
  }
}

