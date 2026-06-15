import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import 'package:zephyr_reader/src/rust/api/dictionary.dart' as dict_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import '../application/reader_view_model.dart';

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

Future<void> onBilingualHighlight(
  BuildContext context,
  ReaderViewModel vm,
) async {
  final text = vm.annotations.selectedText.value;
  final l10n = AppLocalizations.of(context)!;
  if (text.isEmpty) return;

  final alignment = vm.translation.bilingualAlignment.value.value;
  if (alignment == null || alignment.segments.isEmpty) {
    vm.toastMessage.value = l10n.bilingualNoAlignment;
    return;
  }

  final startOffset = vm.annotations.selectionStart.value;
  final length =
      vm.annotations.selectionEnd.value - vm.annotations.selectionStart.value;

  int segmentIndex = -1;
  String sourceLanguage = 'zh';
  String targetLanguage = 'en';
  int targetOffset = 0;

  int cnAcc = 0;
  int enAcc = 0;
  for (int i = 0; i < alignment.segments.length; i++) {
    final seg = alignment.segments[i];
    final cnEnd = cnAcc + seg.chinese.length;
    final enEnd = enAcc + seg.english.length;

    if (startOffset >= cnAcc && startOffset < cnEnd) {
      segmentIndex = i;
      sourceLanguage = 'zh';
      targetLanguage = 'en';
      targetOffset = enAcc;
      break;
    }
    if (startOffset >= enAcc && startOffset < enEnd) {
      segmentIndex = i;
      sourceLanguage = 'en';
      targetLanguage = 'zh';
      targetOffset = cnAcc;
      break;
    }

    cnAcc += seg.chinese.length;
    enAcc += seg.english.length;
  }

  if (segmentIndex == -1) {
    vm.toastMessage.value = l10n.bilingualNoParagraph;
    return;
  }

  final seg = alignment.segments[segmentIndex];
  final targetText = targetLanguage == 'zh' ? seg.chinese : seg.english;
  try {
    await vm.translation.createBilingualHighlight(
      BilingualHighlightParams(
        sourceBookId: vm.state.bookId.value,
        sourceChapterIndex: vm.state.chapterIndex.value,
        sourceCharOffset: startOffset,
        sourceLength: length,
        sourceSelectedText: text,
        sourceLanguage: sourceLanguage,
        targetBookId: vm.state.bookId.value,
        targetChapterIndex: vm.state.chapterIndex.value,
        targetCharOffset: targetOffset,
        targetLength: targetText.length,
        targetSelectedText: targetText,
        targetLanguage: targetLanguage,
        highlightColor: 0xFFE91E63,
      ),
    );
  } catch (e, stack) {
    Logging.error('onBilingualHighlight', exception: e, stackTrace: stack);
    vm.toastMessage.value = l10n.bilingualHighlightFailed;
    return;
  }

  vm.annotations.clearSelection();
  await vm.annotations.loadHighlights();
  vm.toastMessage.value = l10n.bilingualHighlightCreated;
}
