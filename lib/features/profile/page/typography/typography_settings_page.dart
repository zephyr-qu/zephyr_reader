
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_preview.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// Typography settings page (MVP — font service removed).
class TypographySettingsPage extends HookWidget {
  const TypographySettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final config = useMemoized(() => getIt<ReaderConfig>(), []);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.typographySettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          TypographyPreview(
            config: config,
            fontRepo: FontRepository(),
          ),
        ],
      ),
    );
  }
}

