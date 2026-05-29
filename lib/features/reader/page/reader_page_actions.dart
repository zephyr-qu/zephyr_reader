import 'dart:async';

import 'package:flutter/material.dart';

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
  if (trimmed.isEmpty) return;

  try {
    String translation;
    if (definition != null) {
      translation = _stripHtml(definition);
      if (translation.length > 200) {
        translation = '${translation.substring(0, 200)}…';
      }
    } else {
      final result = await vm.lookupMdict(trimmed);
      final entry = result?.exact;
      translation = entry != null ? _stripHtml(entry.definitionHtml) : trimmed;
      if (translation.length > 200) {
        translation = '${translation.substring(0, 200)}…';
      }
    }

    await vm.createVocabularyWord(
      word: trimmed,
      pinyin: '',
      translation: translation.isEmpty ? trimmed : translation,
      bookId: bookId,
      contextSentence: null,
    );
    vm.toastMessage.value = '已加入生词本：$trimmed';
  } catch (e) {
    vm.toastMessage.value = '加入生词本失败：$e';
  }
}

Future<void> onBilingualHighlight(
  BuildContext context,
  ReaderViewModel vm,
) async {
  final text = vm.selectedText.value;
  if (text.isEmpty) return;

  final alignment = vm.bilingualAlignment.value.value;
  if (alignment == null || alignment.segments.isEmpty) {
    vm.toastMessage.value = '没有对照译文，无法创建双语高亮';
    return;
  }

  final startOffset = vm.selectionStart.value;
  final length = vm.selectionEnd.value - vm.selectionStart.value;

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
    vm.toastMessage.value = '未找到对应的段落';
    return;
  }

  final seg = alignment.segments[segmentIndex];
  final targetText = targetLanguage == 'zh' ? seg.chinese : seg.english;

  await vm.createBilingualHighlight(
    sourceBookId: vm.bookId.value,
    sourceChapterIndex: vm.chapterIndex.value,
    sourceCharOffset: startOffset,
    sourceLength: length,
    sourceSelectedText: text,
    sourceLanguage: sourceLanguage,
    targetBookId: vm.bookId.value,
    targetChapterIndex: vm.chapterIndex.value,
    targetCharOffset: targetOffset,
    targetLength: targetText.length,
    targetSelectedText: targetText,
    targetLanguage: targetLanguage,
  );

  vm.clearSelection();
  await vm.loadHighlights();
  vm.toastMessage.value = '双语高亮已创建';
}
