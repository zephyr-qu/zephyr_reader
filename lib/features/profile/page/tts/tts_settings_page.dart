import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/tts/select_item_tile.dart';
import 'package:zephyr_reader/features/profile/page/tts/tts_preview_card.dart';
import 'package:zephyr_reader/features/profile/page/tts/playback_section.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// TTS 语音朗读设置页面。
///
/// 提供语速、音调、音量等 TTS 参数调节，
/// 以及朗读引擎选择和预览功能。
/// 使用 [TtsSettingsViewModel] 管理设置状态。
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

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.ttsSettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          TtsPreviewCard(
            text: _previewText,
            isPlaying: tts.isPlaying.value,
            playLabel: l10n.ttsPreviewPlay,
            stopLabel: l10n.ttsPreviewStop,
            autoLabel: l10n.ttsAutoRefresh,
            onPlay: () => _preview(tts),
            onStop: tts.stop,
          ),
          const SizedBox(height: 16),
          _buildVoiceSection(context, tts, l10n),
          const SizedBox(height: 16),
          PlaybackSection(vm: vm, tts: tts, l10n: l10n),
          const SizedBox(height: 16),
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

  Widget _buildVoiceSection(
    BuildContext context,
    TtsService tts,
    AppLocalizations l10n,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.ttsVoiceEngine),
            SettingsCard(
              children: [
                SelectItemTile(
                  label: l10n.ttsEngine,
                  value: tts.currentLanguage.value,
                  onTap: () {
                    _showLangPicker(context, l10n, tts);
                  },
                ),
                SelectItemTile(
                  label: l10n.ttsEnglishVoice,
                  value: l10n.systemDefault,
                  onTap: () {
                    _showVoicePicker(context, l10n, tts, 'en');
                  },
                ),
                SelectItemTile(
                  label: l10n.ttsChineseVoice,
                  value: l10n.systemDefault,
                  onTap: () {
                    _showVoicePicker(context, l10n, tts, 'zh');
                  },
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
