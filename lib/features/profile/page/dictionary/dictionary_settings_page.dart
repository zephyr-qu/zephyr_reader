import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/core/dictionary/builtin_dictionary.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/dictionary.dart' as dict_api;

class DictionarySettingsPage extends HookWidget {
  const DictionarySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final prefs = useMemoized(() => getIt<SharedPreferences>());

    final currentMdx = useState<String?>(
      prefs.getString(SettingsKeys.dictMdxPath),
    );
    final dictionaries = useState<List<Dictionary>>([]);
    final loading = useState(true);

    useEffect(() {
      _loadState(dictionaries, loading);
      return null;
    }, []);

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.dictionary),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          const SizedBox(height: 8),
          _buildCurrentDictCard(
            context,
            cs,
            l10n,
            currentMdx,
            prefs,
            dictionaries,
            loading,
          ),
          const SizedBox(height: 16),
          _buildDictListSection(
            context,
            cs,
            l10n,
            dictionaries,
            prefs,
            currentMdx,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDictCard(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
    ValueNotifier<String?> currentMdx,
    SharedPreferences prefs,
    ValueNotifier<List<Dictionary>> dictionaries,
    ValueNotifier<bool> loading,
  ) {
    return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIconsFill.bookOpen,
                      size: 22,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dictionary,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loading.value
                              ? '...'
                              : currentMdx.value != null
                              ? currentMdx.value!
                                    .split(Platform.pathSeparator)
                                    .last
                              : l10n.selectMdxDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _divider(cs),
            _actionRow(
              cs,
              l10n.selectDictionaryFile,
              PhosphorIconsRegular.folderOpen,
              () => _pickDictionary(context, prefs, currentMdx, dictionaries),
            ),
            if (currentMdx.value != null && currentMdx.value != 'builtin') ...[
              _divider(cs),
              _actionRow(
                cs,
                l10n.resetToDefault,
                PhosphorIconsRegular.arrowCounterClockwise,
                () => _resetToBuiltin(context, prefs, currentMdx, dictionaries),
              ),
            ],
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildDictListSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
    ValueNotifier<List<Dictionary>> dictionaries,
    SharedPreferences prefs,
    ValueNotifier<String?> currentMdx,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '${l10n.dictionary} (${dictionaries.value.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.4,
            ),
          ),
        ),
        SettingsCard(
              children: dictionaries.value.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            l10n.selectMdxDescription,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ]
                  : dictionaries.value
                        .map(
                          (dict) => _dictTile(
                            context,
                            cs,
                            l10n,
                            dict,
                            prefs,
                            currentMdx,
                            dictionaries,
                          ),
                        )
                        .toList(),
            )
            .animate()
            .fadeIn(duration: 300.ms, delay: 150.ms)
            .slideY(begin: 0.03, end: 0),
      ],
    );
  }

  Widget _divider(ColorScheme cs) =>
      Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.15));

  Widget _actionRow(
    ColorScheme cs,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dictTile(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
    Dictionary dict,
    SharedPreferences prefs,
    ValueNotifier<String?> currentMdx,
    ValueNotifier<List<Dictionary>> dictionaries,
  ) {
    final active = dict.filePath == currentMdx.value;
    return Column(
      children: [
        InkWell(
          onTap: active
              ? null
              : () => _switchDict(context, prefs, currentMdx, l10n, dict),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _iconBox(cs, active),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dict.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${dict.wordCount} 词条 • ${dict.dictType}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (active)
                  Icon(
                    PhosphorIconsFill.checkCircle,
                    size: 18,
                    color: cs.primary,
                  )
                else
                  GestureDetector(
                    onTap: () => _confirmDelete(
                      context,
                      prefs,
                      l10n,
                      dict,
                      dictionaries,
                      currentMdx,
                    ),
                    child: Icon(
                      PhosphorIconsRegular.trash,
                      size: 18,
                      color: cs.error.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!active) _divider(cs),
      ],
    );
  }

  Widget _iconBox(ColorScheme cs, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active
            ? cs.primary.withValues(alpha: 0.1)
            : cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        active ? PhosphorIconsFill.bookOpen : PhosphorIconsRegular.bookOpen,
        size: 16,
        color: active ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }

  Future<void> _switchDict(
    BuildContext context,
    SharedPreferences prefs,
    ValueNotifier<String?> currentMdx,
    AppLocalizations l10n,
    Dictionary dict,
  ) async {
    try {
      dict_api.closeDictionary();
      await dict_api.initDictionary(mdxPath: dict.filePath);
      await prefs.setString(SettingsKeys.dictMdxPath, dict.filePath);
      currentMdx.value = dict.filePath;
      if (context.mounted) {
        showInfoSnack(context, '${l10n.dictionary} → ${dict.name}');
      }
    } catch (e, st) {
      Logging.error('dict switch failed', exception: e, stackTrace: st);
      if (context.mounted) showInfoSnack(context, l10n.dictionaryLoadFailed);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SharedPreferences prefs,
    AppLocalizations l10n,
    Dictionary dict,
    ValueNotifier<List<Dictionary>> dictionaries,
    ValueNotifier<String?> currentMdx,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dictionary),
        content: Text(dict.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await dict_api.deleteDictionary(id: dict.id);
      await _loadState(dictionaries, ValueNotifier(false));
      if (!context.mounted) return;
      if (currentMdx.value == dict.filePath) {
        await _resetToBuiltin(context, prefs, currentMdx, dictionaries);
      }
    } catch (e, st) {
      Logging.error('dict delete failed', exception: e, stackTrace: st);
    }
  }
}

Future<void> _loadState(
  ValueNotifier<List<Dictionary>> dictionaries,
  ValueNotifier<bool> loading,
) async {
  try {
    final list = await dict_api.listDictionaries();
    dictionaries.value = list;
  } catch (_) {}
  loading.value = false;
}

Future<void> _pickDictionary(
  BuildContext context,
  SharedPreferences prefs,
  ValueNotifier<String?> currentMdx,
  ValueNotifier<List<Dictionary>> dictionaries,
) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['mdx'],
  );
  if (result == null || result.files.isEmpty) return;
  final path = result.files.single.path;
  if (path == null) return;

  final mddPath = path.replaceAll('.mdx', '.mdd');
  final mddExists = File(mddPath).existsSync();

  try {
    dict_api.closeDictionary();
    await dict_api.initDictionary(
      mdxPath: path,
      mddPath: mddExists ? mddPath : null,
    );
    await prefs.setString(SettingsKeys.dictMdxPath, path);
    currentMdx.value = path;
    final name = path.split(Platform.pathSeparator).last.replaceAll('.mdx', '');
    await dict_api.upsertDictionary(
      dict: Dictionary(
        id: '',
        name: name,
        filePath: path,
        dictType: 'MDict',
        langFrom: null,
        langTo: null,
        isEnabled: true,
        wordCount: 0,
        addedAt: DateTime.now(),
      ),
    );
    await _loadState(dictionaries, ValueNotifier(false));
    if (context.mounted) showInfoSnack(context, '$name ✓');
  } catch (e, st) {
    Logging.error('dict load failed', exception: e, stackTrace: st);
    if (context.mounted) showInfoSnack(context, l10n.dictionaryLoadFailed);
  }
}

Future<void> _resetToBuiltin(
  BuildContext context,
  SharedPreferences prefs,
  ValueNotifier<String?> currentMdx,
  ValueNotifier<List<Dictionary>> dictionaries,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final builtinPath = await BuiltinDictionary.ensureExtracted();
    dict_api.closeDictionary();
    await dict_api.initDictionary(mdxPath: builtinPath);
    await prefs.setString(SettingsKeys.dictMdxPath, builtinPath);
    currentMdx.value = builtinPath;
    await _loadState(dictionaries, ValueNotifier(false));
    if (context.mounted) showInfoSnack(context, l10n.dictionary);
  } catch (e, st) {
    Logging.error('builtin dict load failed', exception: e, stackTrace: st);
    if (context.mounted) showInfoSnack(context, l10n.dictionaryLoadFailed);
  }
}
