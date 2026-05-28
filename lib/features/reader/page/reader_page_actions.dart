import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zephyr_reader/core/dictionary/builtin_dictionary.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/dictionary/models.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart' as bilingual_api;
import 'package:zephyr_reader/src/rust/api/dictionary.dart' as dict_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import '../application/reader_view_model.dart';

const _kPrefMdxPath = 'dict_mdx_path';
const _kPrefMddPath = 'dict_mdd_path';

void showDictionaryPanel(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  // Lazy file picker: auto-load persisted path or prompt on first use
  final configured = await _ensureMdictConfigured(context);
  if (!configured || !context.mounted) return;

  DictSearchResult? result;
  List<String> segments = [];
  bool loading = true;
  String? error;

  try {
    result = dict_api.lookupMdict(word: text.trim());
    segments = await dict_api.segmentText(text: text.trim());
    hapticFeedback(HapticType.light);
  } catch (e) {
    error = e.toString();
  }
  loading = false;

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.spacing(Spacing.md)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (result?.exact?.audioKey != null)
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.speakerHigh),
                      tooltip: '发音',
                      onPressed: () =>
                          _playAudio(context, result!.exact!.audioKey!),
                    ),
                ],
              ),
              if (result?.exact != null) ...[
                const SizedBox(height: 8),
                HtmlWidget(
                  result!.exact!.definitionHtml,
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ] else if (result?.suggestions.isNotEmpty ?? false) ...[
                SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                const Text(
                  '未找到精确匹配，您是否想查：',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: result!.suggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showDictionaryPanel(context, s);
                          },
                        ),
                      )
                      .toList(),
                ),
              ] else if (loading) ...[
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                Text(
                  error ?? '未找到释义',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              if (segments.length > 1) ...[
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                const Text(
                  '分词：',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: segments
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showDictionaryPanel(context, s);
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              if (result?.exact != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    addToVocabulary(
                      context,
                      text,
                      definition: result!.exact!.definitionHtml,
                    );
                  },
                  icon: const Icon(PhosphorIconsRegular.listPlus, size: 18),
                  label: const Text('加入生词本'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _playAudio(BuildContext context, String audioKey) async {
  try {
    final bytes = dict_api.extractAudio(audioKey: audioKey);
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未找到发音文件'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final ext = audioKey.contains('.') ? audioKey.split('.').last : 'wav';
    final tempFile = File('${tempDir.path}/dict_audio.$ext');
    await tempFile.writeAsBytes(bytes);
    await AudioPlayer().play(DeviceFileSource(tempFile.path));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

/// Very basic HTML-to-plain-text for vocabulary storage.
String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<void> addToVocabulary(
  BuildContext context,
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
      final result = dict_api.lookupMdict(word: trimmed);
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
      chapterIndex: chapterIndex,
      charOffset: charOffset,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入生词本：$trimmed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('加入生词本失败：$e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有对照译文，无法创建双语高亮'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未找到对应的段落'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final seg = alignment.segments[segmentIndex];
  final targetText = targetLanguage == 'zh' ? seg.chinese : seg.english;

  try {
    await bilingual_api.createBilingualHighlightPair(
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
      highlightColor: 0xFFE91E63,
    );

    vm.clearSelection();
    await vm.loadHighlights();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('双语高亮已创建'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

// ==================== MDict file selection helpers ====================

/// Ensure an MDict file path is configured.
///
/// 1. Check SharedPreferences for a previously selected path → auto-configure.
/// 2. If none exists, prompt user to pick a .mdx file.
/// Returns true if a valid dictionary is now configured.
///
/// Priority: user saved dict > built-in dictionary > file picker dialog.
Future<bool> _ensureMdictConfigured(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  // Step 1: Try user's previously saved dictionary
  final savedMdx = prefs.getString(_kPrefMdxPath);
  if (savedMdx != null && File(savedMdx).existsSync()) {
    final savedMdd = prefs.getString(_kPrefMddPath);
    await dict_api.closeDictionary();
    try {
      await dict_api.initDictionary(
        mdxPath: savedMdx,
        mddPath: (savedMdd != null && File(savedMdd).existsSync())
            ? savedMdd
            : null,
      );
      Logging.info('用户词典加载成功');
      return true;
    } catch (e, st) {
      Logging.error('用户词典加载失败，回退内置词典', exception: e, stackTrace: st);
    }
  }

  // Step 2: Fallback to built-in dictionary
  try {
    final builtinPath = await BuiltinDictionary.ensureExtracted();
    await dict_api.closeDictionary();
    await dict_api.initDictionary(mdxPath: builtinPath);
    Logging.info('内置词典加载成功');
    return true;
  } catch (e, st) {
    Logging.error('内置词典加载失败', exception: e, stackTrace: st);
  }

  // Step 3: Last resort — file picker dialog
  if (!context.mounted) return false;

  final pick = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('选择词典文件'),
      content: const Text(
        '请选择一个 .mdx 格式的词典文件。\n\n'
        '如果有同名的 .mdd 资源文件（音频/图片），'
        '放在同一目录下会自动加载。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            final result = await FilePicker.pickFiles(
              type: FileType.any,
              allowMultiple: false,
            );
            if (result != null && result.files.single.path != null) {
              Navigator.pop(ctx, result.files.single.path);
            } else {
              Navigator.pop(ctx);
            }
          },
          child: const Text('选择文件'),
        ),
      ],
    ),
  );

  if (pick == null || pick.isEmpty) return false;

  final mdxFile = File(pick);
  if (!mdxFile.existsSync() || !pick.toLowerCase().endsWith('.mdx')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择有效的 .mdx 文件'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  final mddPath = '${pick.substring(0, pick.length - 4)}.mdd';
  final mddExists = File(mddPath).existsSync();

  await prefs.setString(_kPrefMdxPath, pick);
  if (mddExists) {
    await prefs.setString(_kPrefMddPath, mddPath);
  } else {
    await prefs.remove(_kPrefMddPath);
  }

  await dict_api.closeDictionary();
  try {
    await dict_api.initDictionary(
      mdxPath: pick,
      mddPath: mddExists ? mddPath : null,
    );
  } catch (e) {
    Logging.error('词典加载失败', exception: e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('词典加载失败，请检查文件是否有效'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
  return true;
}
