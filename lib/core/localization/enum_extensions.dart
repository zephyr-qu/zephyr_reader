import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/auto_theme_service.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

extension ReaderThemeX on ReaderTheme {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    ReaderTheme.light => l10n.readerThemeLight,
    ReaderTheme.dark => l10n.readerThemeDark,
    ReaderTheme.sepia => l10n.readerThemeSepia,
  };
}

extension ReaderFontSizeX on ReaderFontSize {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    ReaderFontSize.small => l10n.readerFontSizeSmall,
    ReaderFontSize.medium => l10n.readerFontSizeMedium,
    ReaderFontSize.large => l10n.readerFontSizeLarge,
    ReaderFontSize.xLarge => l10n.readerFontSizeXLarge,
  };
}

extension AppThemeTypeX on AppThemeType {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    AppThemeType.light => l10n.themeLight,
    AppThemeType.dark => l10n.themeDark,
    AppThemeType.system => l10n.themeSystem,
  };
}

extension ThemeTimePresetX on ThemeTimePreset {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    ThemeTimePreset.sunsetToSunrise => l10n.timePresetSunsetToSunrise,
    ThemeTimePreset.eveningToMorning => l10n.timePresetEveningToMorning,
    ThemeTimePreset.custom => l10n.timePresetCustom,
  };
}

extension TapLayoutX on TapLayout {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    TapLayout.rightHanded => l10n.tapLayoutRightHanded,
    TapLayout.leftHanded => l10n.tapLayoutLeftHanded,
  };
}
