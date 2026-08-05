import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/tts/playback_section.dart';
import 'package:zephyr_reader/features/profile/page/tts/behavior_section.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// TTS settings page.
class TtsSettingsPage extends HookWidget {
  const TtsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<TtsSettingsViewModel>(), []);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.ttsSettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          BehaviorSection(vm: vm, l10n: l10n),
          PlaybackSection(vm: vm, l10n: l10n),
        ],
      ),
    );
  }
}
