import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/dictionary/builtin_dictionary.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/dictionary/models.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';

import '../application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api/dictionary.dart' as dict_api;
import 'reader_page_actions.dart';

const _kPrefMdxPath = SettingsKeys.dictMdxPath;
const _kPrefMddPath = SettingsKeys.dictMddPath;

void showDictionaryPanel(
  BuildContext context,
  ReaderViewModel vm,
  String text,
) async {
  if (text.trim().isEmpty) return;
  final l10n = AppLocalizations.of(context)!;
  final configured = await _ensureMdictConfigured(context, vm);
  if (!configured || !context.mounted) return;

  DictSearchResult? result;
  List<String> segments = [];
  bool loading = true;
  String? error;
  try {
    result = await dict_api.lookupMdict(word: text.trim());
    segments = await dict_api.segmentText(text: text.trim());
    HapticFeedback.lightImpact();
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
        child: ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.zero,
          itemCount: 5,
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DesignTokens.warmAccent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              case 1:
                return Column(
                  children: [
                    SizedBox(height: Spacing.md.value),
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
                            tooltip: l10n.pronunciation,
                            onPressed: () => _playAudio(
                              context,
                              vm,
                              result!.exact!.audioKey!,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              case 2:
                if (result?.exact != null) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      HtmlWidget(
                        result!.exact!.definitionHtml,
                        textStyle: const TextStyle(fontSize: 15),
                      ),
                    ],
                  );
                } else if (result?.suggestions.isNotEmpty ?? false) {
                  return Column(
                    children: [
                      SizedBox(height: Spacing.sm.value),
                      Text(
                        l10n.noExactMatch,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: result!.suggestions
                            .cast<String>()
                            .map(
                              (s) => ActionChip(
                                label: Text(
                                  s,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(),
                                ),
                                onPressed: () {
                                  showDictionaryPanel(context, vm, s);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                } else if (loading) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: Spacing.lg.value,
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                } else {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: Spacing.lg.value,
                    ),
                    child: Text(
                      error ?? l10n.noDefinition,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }
              case 3:
                if (segments.length <= 1) return const SizedBox.shrink();
                return Column(
                  children: [
                    SizedBox(height: Spacing.lg.value),
                    Text(
                      l10n.wordSegmentation,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: segments
                          .map(
                            (s) => ActionChip(
                              label: Text(
                                s,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(),
                              ),
                              onPressed: () {
                                Theme.of(context).textTheme.labelLarge?.copyWith();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              case 4:
                if (result?.exact == null) return const SizedBox.shrink();
                return Column(
                  children: [
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
                      label: Text(l10n.addToVocabulary),
                    ),
                  ],
                );
              default:
                return const SizedBox.shrink();
            }
          },
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
    final bytes = await dict_api.extractAudio(audioKey: audioKey);
    if (bytes == null || bytes.isEmpty) return;
    final player = AudioPlayer();
    await player.play(BytesSource(bytes));
  } catch (e) {
    Logging.error('Play audio error', exception: e);
  }
}

Future<bool> _ensureMdictConfigured(
  BuildContext context,
  ReaderViewModel vm,
) async {
  final l10n = AppLocalizations.of(context)!;
  final prefs = getIt<SharedPreferences>();

  final savedMdx = prefs.getString(_kPrefMdxPath);
  if (savedMdx != null && File(savedMdx).existsSync()) {
    final savedMdd = prefs.getString(_kPrefMddPath);
    dict_api.closeDictionary();
    try {
      await dict_api.initDictionary(
        mdxPath: savedMdx,
        mddPath: (savedMdd != null && File(savedMdd).existsSync())
            ? savedMdd
            : null,
      );
      Logging.info('user dict loaded');
      return true;
    } catch (e, st) {
      Logging.error(
        'user dict fail, fallback to builtin',
        exception: e,
        stackTrace: st,
      );
    }
  }

  try {
    final builtinPath = await BuiltinDictionary.ensureExtracted();
    dict_api.closeDictionary();
    await dict_api.initDictionary(mdxPath: builtinPath);
    Logging.info('builtin dict loaded');
    return true;
  } catch (e, st) {
    Logging.error('builtin dict fail', exception: e, stackTrace: st);
  }

  if (!context.mounted) return false;

  final pick = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.selectDictionaryFile),
      content: Text(l10n.selectMdxDescription),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final result = await FilePicker.pickFile(type: FileType.any);
            if (result != null && result.path != null) {
              if (!context.mounted) return;
              Navigator.pop(ctx, result.path);
            } else {
              if (!context.mounted) return;
              Navigator.pop(ctx);
            }
          },
          child: Text(l10n.selectFile),
        ),
      ],
    ),
  );

  if (pick == null || pick.isEmpty) return false;

  final mdxFile = File(pick);
  if (!mdxFile.existsSync() || !pick.toLowerCase().endsWith('.mdx')) {
    if (context.mounted) {
      showInfoSnack(context, l10n.invalidMdxFile);
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

  dict_api.closeDictionary();
  try {
    await dict_api.initDictionary(
      mdxPath: pick,
      mddPath: mddExists ? mddPath : null,
    );
  } catch (e) {
    Logging.error('dict load fail', exception: e);
    if (context.mounted) {
      showInfoSnack(context, l10n.dictionaryLoadFailed);
    }
    return false;
  }
  return true;
}
