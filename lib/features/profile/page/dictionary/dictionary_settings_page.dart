import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/dictionary_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class DictionarySettingsPage extends HookWidget {
  const DictionarySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final vm = useMemoized(() => getIt<DictionarySettingsViewModel>());

    useEffect(() {
      vm.load();
      return null;
    }, []);

    final String? currentMdx = useSignalValue(vm.currentMdxPath.signal);
    final List<Dictionary> dictionaries = useSignalValue(vm.dictionaries);
    final bool loading = useSignalValue(vm.loading);

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
            vm,
            dictionaries,
            loading,
          ),
          const SizedBox(height: 16),
          _buildDictListSection(
            context,
            cs,
            l10n,
            dictionaries,
            currentMdx,
            vm,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDictCard(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
    String? currentMdx,
    DictionarySettingsViewModel vm,
    List<Dictionary> dictionaries,
    bool loading,
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
                          loading
                              ? '...'
                              : currentMdx != null
                                  ? currentMdx
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
              () => _pickDictionary(context, vm),
            ),
            if (currentMdx != null && currentMdx != 'builtin') ...[
              _divider(cs),
              _actionRow(
                cs,
                l10n.resetToDefault,
                PhosphorIconsRegular.arrowCounterClockwise,
                () => _resetToBuiltin(context, vm),
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
    List<Dictionary> dictionaries,
    String? currentMdx,
    DictionarySettingsViewModel vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '${l10n.dictionary} (${dictionaries.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.4,
            ),
          ),
        ),
        SettingsCard(
          children: dictionaries.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l10n.selectMdxDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                ]
              : dictionaries
                  .map(
                    (dict) => _dictTile(
                      context,
                      cs,
                      l10n,
                      dict,
                      currentMdx,
                      vm,
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
    String? currentMdx,
    DictionarySettingsViewModel vm,
  ) {
    final active = dict.filePath == currentMdx;
    return Column(
      children: [
        InkWell(
          onTap: active
              ? null
              : () => _switchDict(context, vm, l10n, dict),
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
                      l10n,
                      dict,
                      vm,
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

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _switchDict(
    BuildContext context,
    DictionarySettingsViewModel vm,
    AppLocalizations l10n,
    Dictionary dict,
  ) async {
    final name = await vm.switchDict(dict);
    if (!context.mounted) return;
    if (name != null) {
      showInfoSnack(context, '${l10n.dictionary} → $name');
    } else {
      showInfoSnack(context, l10n.dictionaryLoadFailed);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    Dictionary dict,
    DictionarySettingsViewModel vm,
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
    final success = await vm.deleteDict(dict);
    if (!context.mounted) return;
    if (success) {
      showInfoSnack(context, '${l10n.dictionary} ✓');
    } else {
      showInfoSnack(context, l10n.dictionaryLoadFailed);
    }
  }

  Future<void> _pickDictionary(
    BuildContext context,
    DictionarySettingsViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    final name = await vm.addDictFromPath(path);
    if (!context.mounted) return;
    if (name != null) {
      showInfoSnack(context, '$name ✓');
    } else {
      showInfoSnack(context, l10n.dictionaryLoadFailed);
    }
  }

  Future<void> _resetToBuiltin(
    BuildContext context,
    DictionarySettingsViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.resetToBuiltin();
    if (!context.mounted) return;
    if (result != null) {
      showInfoSnack(context, l10n.dictionary);
    } else {
      showInfoSnack(context, l10n.dictionaryLoadFailed);
    }
  }
}
