import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class TtsSettingsPage extends HookWidget {
  const TtsSettingsPage({super.key});

  static const _previewText =
      'The quick brown fox jumps over the lazy dog. 敏捷的棕色狐狸跳过了懒狗。';

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<TtsSettingsViewModel>(), []);
    final tts = useMemoized(() => getIt<TtsService>(), []);

    // 页面首次构建时将持久化设置应用到 TTS 引擎
    useEffect(() {
      unawaited(tts.setSpeed(vm.speed.value));
      unawaited(tts.setPitch(vm.pitch.value));
      tts.setPauseBetween(vm.pauseBetween.value);
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.ttsSettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildPreviewCard(cs, tts, l10n),
          const SizedBox(height: 24),
          _buildVoiceSection(context, cs, tts, l10n),
          const SizedBox(height: 24),
          _buildPlaybackSection(cs, vm, tts, l10n),
          const SizedBox(height: 24),
          _buildBilingualSection(context, cs, vm, l10n),
          const SizedBox(height: 24),
          _buildBehaviorSection(context, cs, vm, l10n),
        ],
      ),
    );
  }

  Future<void> _preview(TtsService tts) async {
    await tts.speak(_previewText);
  }

  Future<void> _showLangPicker(
    BuildContext context,
    AppLocalizations l10n,
    TtsService tts,
  ) async {
    final langs = await tts.getLanguages();
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.ttsEngine,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ...langs.map(
            (lang) => ListTile(
              title: Text(lang),
              selected: lang == tts.currentLanguage.value,
              trailing: lang == tts.currentLanguage.value
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () => Navigator.pop(ctx, lang),
            ),
          ),
        ],
      ),
    );
    if (selected != null && selected != tts.currentLanguage.value) {
      await tts.setLanguage(selected);
    }
  }

  Future<void> _showVoicePicker(
    BuildContext context,
    AppLocalizations l10n,
    TtsService tts,
    String localePrefix,
  ) async {
    final allVoices = await tts.getVoices();
    final voices = allVoices
        .map((v) => Map<String, String>.from(v as Map))
        .where((v) => v['locale']?.startsWith(localePrefix) ?? false)
        .toList();
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              localePrefix == 'zh'
                  ? l10n.ttsChineseVoice
                  : l10n.ttsEnglishVoice,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          if (voices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.settings,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...voices.map(
              (v) => ListTile(
                title: Text(v['name'] ?? v['locale'] ?? ''),
                onTap: () => Navigator.pop(ctx, v),
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      await tts.setVoice(selected);
    }
  }

  Widget _buildPreviewCard(
    ColorScheme cs,
    TtsService tts,
    AppLocalizations l10n,
  ) {
    final isPlaying = tts.isPlaying.value;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.85),
            cs.primary.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _previewText,
            style: TextStyle(fontSize: 14, height: 1.6, color: cs.onPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: isPlaying ? tts.stop : () => _preview(tts),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? PhosphorIconsFill.stop : PhosphorIconsFill.play,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isPlaying ? l10n.ttsPreviewStop : l10n.ttsPreviewPlay,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onPrimary,
                ),
              ),
              const Spacer(),
              Text(
                l10n.ttsAutoRefresh,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onPrimary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildVoiceSection(
    BuildContext context,
    ColorScheme cs,
    TtsService tts,
    AppLocalizations l10n,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.ttsVoiceEngine),
            SettingsCard(
              children: [
                _selectItem(cs, l10n.ttsEngine, tts.currentLanguage.value, () {
                  _showLangPicker(context, l10n, tts);
                }),
                _selectItem(cs, l10n.ttsEnglishVoice, 'Google US English', () {
                  _showVoicePicker(context, l10n, tts, 'en');
                }),
                _selectItem(cs, l10n.ttsChineseVoice, '讯飞小燕', () {
                  _showVoicePicker(context, l10n, tts, 'zh');
                }),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildPlaybackSection(
    ColorScheme cs,
    TtsSettingsViewModel vm,
    TtsService tts,
    AppLocalizations l10n,
  ) {
    final speed = useSignalValue<double, Signal<double>>(vm.speed.signal);
    final pitch = useSignalValue<double, Signal<double>>(vm.pitch.signal);
    final pauseBetween = useSignalValue<int, Signal<int>>(
      vm.pauseBetween.signal,
    );
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.ttsPlaybackParams),
            SettingsCard(
              children: [
                SettingsSliderTile(
                  label: l10n.ttsSpeed,
                  value: '${speed.toStringAsFixed(1)}x',
                  current: speed,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (v) {
                    vm.speed.value = v;
                    unawaited(tts.setSpeed(v));
                  },
                ),
                SettingsSliderTile(
                  label: l10n.ttsPitch,
                  value: pitch.toStringAsFixed(1),
                  current: pitch,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (v) {
                    vm.pitch.value = v;
                    unawaited(tts.setPitch(v));
                  },
                ),
                SettingsSliderTile(
                  label: l10n.ttsPauseBetween,
                  value: '${pauseBetween}ms',
                  current: pauseBetween.toDouble(),
                  min: 0,
                  max: 1000,
                  onChanged: (v) {
                    vm.pauseBetween.value = v.toInt();
                    tts.setPauseBetween(v.toInt());
                  },
                  step: 50,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildBilingualSection(
    BuildContext context,
    ColorScheme cs,
    TtsSettingsViewModel vm,
    AppLocalizations l10n,
  ) {
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
              iconColor: MenuItemSemantic.reading.iconColor(
                Theme.of(context).brightness,
              ),
              iconBackground: MenuItemSemantic.reading.iconBackground(
                Theme.of(context).brightness,
              ),
              title: l10n.ttsBilingualAlternate,
              subtitle: l10n.ttsBilingualAlternateDesc,
              value: useSignalValue<bool, Signal<bool>>(
                vm.bilingualAlternate.signal,
              ),
              onChanged: (v) => vm.bilingualAlternate.value = v,
            ),
            SettingsToggleTile(
              icon: PhosphorIconsRegular.textAa,
              iconColor: MenuItemSemantic.reading.iconColor(
                Theme.of(context).brightness,
              ),
              iconBackground: MenuItemSemantic.reading.iconBackground(
                Theme.of(context).brightness,
              ),
              title: l10n.ttsOriginalOnly,
              subtitle: l10n.ttsOriginalOnlyDesc,
              value: useSignalValue<bool, Signal<bool>>(vm.originalOnly.signal),
              onChanged: (v) => vm.originalOnly.value = v,
            ),
            SettingsSliderTile(
              label: l10n.ttsSwitchInterval,
              value:
                  '${useSignalValue<int, Signal<int>>(vm.switchInterval.signal)}ms',
              current: useSignalValue<int, Signal<int>>(
                vm.switchInterval.signal,
              ).toDouble(),
              min: 200,
              max: 1500,
              onChanged: (v) => vm.switchInterval.value = v.toInt(),
              step: 100,
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    ColorScheme cs,
    TtsSettingsViewModel vm,
    AppLocalizations l10n,
  ) {
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

  Widget _selectItem(
    ColorScheme cs,
    String label,
    String current,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              current,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
