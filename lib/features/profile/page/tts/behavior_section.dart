import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class BehaviorSection extends HookWidget {
  final TtsSettingsViewModel vm;
  final AppLocalizations l10n;

  const BehaviorSection({super.key, required this.vm, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.ttsBehavior),
            SettingsCard(
              showDividers: true,
              children: [
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.playCircle,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.ttsBackgroundPlay,
                  subtitle: l10n.ttsBackgroundPlayDesc,
                  value: useSignalValue<bool, Signal<bool>>(
                    vm.backgroundPlay.signal,
                  ),
                  onChanged: (v) => vm.backgroundPlay.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowRight,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.ttsAutoPage,
                  subtitle: l10n.ttsAutoPageDesc,
                  value: useSignalValue<bool, Signal<bool>>(vm.autoPage.signal),
                  onChanged: (v) => vm.autoPage.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.highlighter,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.ttsHighlightFollow,
                  subtitle: l10n.ttsHighlightFollowDesc,
                  value: useSignalValue<bool, Signal<bool>>(
                    vm.highlightFollow.signal,
                  ),
                  onChanged: (v) => vm.highlightFollow.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.moon,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.ttsDimOnLock,
                  subtitle: l10n.ttsDimOnLockDesc,
                  value: useSignalValue<bool, Signal<bool>>(
                    vm.dimOnLock.signal,
                  ),
                  onChanged: (v) => vm.dimOnLock.value = v,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
