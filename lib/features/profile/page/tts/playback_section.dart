import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class PlaybackSection extends HookWidget {
  final TtsSettingsViewModel vm;
  final TtsService tts;
  final AppLocalizations l10n;

  const PlaybackSection({
    super.key,
    required this.vm,
    required this.tts,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
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
}
