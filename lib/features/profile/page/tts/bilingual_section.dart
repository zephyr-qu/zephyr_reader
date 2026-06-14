import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class BilingualSection extends HookWidget {
  final TtsSettingsViewModel vm;
  final AppLocalizations l10n;

  const BilingualSection({super.key, required this.vm, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final int switchInterval = useSignalValue(vm.switchInterval.signal);
    final cs = Theme.of(context).colorScheme;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: l10n.ttsBilingualReading,
              tag: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.brightness == Brightness.dark
                      ? const Color(0xFF4E2D0D)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.zephyrExclusive,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: cs.brightness == Brightness.dark
                        ? const Color(0xFFFFCC80)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
            ),
            SettingsCard(
              showDividers: true,
              children: [
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowsLeftRight,
                  semantic: MenuItemSemantic.reading,
                  title: l10n.ttsBilingualAlternate,
                  subtitle: l10n.ttsBilingualAlternateDesc,
                  value: useSignalValue(vm.bilingualAlternate.signal),
                  onChanged: (v) => vm.bilingualAlternate.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.textAa,
                  semantic: MenuItemSemantic.reading,
                  title: l10n.ttsOriginalOnly,
                  subtitle: l10n.ttsOriginalOnlyDesc,
                  value: useSignalValue(vm.originalOnly.signal),
                  onChanged: (v) => vm.originalOnly.value = v,
                ),
                SettingsSliderTile(
                  label: l10n.ttsSwitchInterval,
                  value: '${switchInterval}ms',
                  current: switchInterval.toDouble(),
                  min: 200,
                  max: 1500,
                  onChanged: (v) => vm.switchInterval.value = v.toInt(),
                  step: 100,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
