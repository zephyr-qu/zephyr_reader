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
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/dictionary/models.dart';

import '../application/reader_view_model.dart';
import 'reader_page_actions.dart';

const _kPrefMdxPath = 'dict_mdx_path';
const _kPrefMddPath = 'dict_mdd_path';

void showDictionaryPanel(
  BuildContext context,
  ReaderViewModel vm,
  String text,
) async {
  if (text.trim().isEmpty) return;
  final configured = await _ensureMdictConfigured(context, vm);
  if (!configured || !context.mounted) return;

  DictSearchResult? result;
  List<String> segments = [];
  bool loading = true;
  String? error;

  try {
    result = await vm.lookupMdict(text.trim());
    segments = await vm.segmentText(text.trim());
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (scrollCtx, scrollController) => Padding(
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
                        _playAudio(context, vm, result!.exact!.audioKey!),
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
                          showDictionaryPanel(context, vm, s);
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
                          showDictionaryPanel(context, vm, s);
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
                    vm,
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
      ),
    ),
  );
}

Future<void> _playAudio(
  BuildContext context,
  ReaderViewModel vm,
  String audioKey,
) async {
  try {
    final bytes = await vm.extractAudio(audioKey);
    if (bytes == null) return;
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

Future<bool> _ensureMdictConfigured(
  BuildContext context,
  ReaderViewModel vm,
) async {
  final prefs = await SharedPreferences.getInstance();

  final savedMdx = prefs.getString(_kPrefMdxPath);
  if (savedMdx != null && File(savedMdx).existsSync()) {
    final savedMdd = prefs.getString(_kPrefMddPath);
    vm.closeDictionary();
    try {
      await vm.initDictionary(
        savedMdx,
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

  try {
    final builtinPath = await BuiltinDictionary.ensureExtracted();
    vm.closeDictionary();
    await vm.initDictionary(builtinPath);
    Logging.info('内置词典加载成功');
    return true;
  } catch (e, st) {
    Logging.error('内置词典加载失败', exception: e, stackTrace: st);
  }

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
              if (!context.mounted) return;
              Navigator.pop(ctx, result.files.single.path);
            } else {
              if (!context.mounted) return;
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

  vm.closeDictionary();
  try {
    await vm.initDictionary(pick, mddPath: mddExists ? mddPath : null);
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
