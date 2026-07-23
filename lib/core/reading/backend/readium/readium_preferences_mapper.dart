import 'dart:ui' show Color;

import 'package:flureadium/flureadium.dart';

import '../../preferences/reading_preferences.dart';

/// Maps [ReadingPreferences] to [EPUBPreferences] for the Readium engine.
///
/// ## Supported mappings
///
/// | Unified setting | EPUBPreferences | Note |
/// |---|---|---|
/// | fontSize | fontSize (×100) | Converted from Flutter logical px to Readium units |
/// | lineHeight | — | Not supported by flureadium EPUBPreferences |
/// | fontFamily | fontFamily | Passed through when non-null |
/// | pageMargin | pageMargins | Direct mapping |
/// | theme | backgroundColor + textColor | Light / Sepia / Dark presets |
/// | textAlignment | — | Not supported by flureadium EPUBPreferences |
/// | readingMode | verticalScroll | paginated ↔ scroll toggle |
///
/// Settings not supported by flureadium should be gated via
/// [ReadingCapabilities] at the UI layer.
class ReadiumPreferencesMapper {
  const ReadiumPreferencesMapper();

  /// Convert [prefs] to [EPUBPreferences].
  EPUBPreferences toEpubPreferences(ReadingPreferences prefs) {
    return EPUBPreferences(
      fontFamily: prefs.fontFamily ?? _defaultFontFamily(prefs.theme),
      fontSize: _fontSizeToReadium(prefs.fontSize),
      fontWeight: 400,
      verticalScroll: prefs.readingMode == 'scroll',
      backgroundColor: _themeBg(prefs.theme),
      textColor: _themeFg(prefs.theme),
      pageMargins: prefs.pageMargin,
    );
  }

  /// Convert the font size from Flutter logical pixels to Readium units.
  ///
  /// Readium stores fontSize as hundredths (e.g. fontFamily 'Original'
  /// at size 16.0dp → fontSize: 1600). The formula:
  /// `readiumFontSize = (flutterFontSize / 16.0) * 100`
  int _fontSizeToReadium(double flutterFontSize) {
    return (flutterFontSize / 16.0 * 100).round();
  }

  /// Default font family per theme (Readium 'Original' for all themes).
  String _defaultFontFamily(String theme) => 'Original';

  // Theme color presets -------------------------------------------------

  Color _themeBg(String theme) {
    switch (theme) {
      case 'sepia':
        return const Color(0xFFF5E6D3);
      case 'dark':
        return const Color(0xFF1A1A2E);
      default: // 'light'
        return const Color(0xFFFFFFFF);
    }
  }

  Color _themeFg(String theme) {
    switch (theme) {
      case 'sepia':
        return const Color(0xFF3E2723);
      case 'dark':
        return const Color(0xFFE0E0E0);
      default: // 'light'
        return const Color(0xFF000000);
    }
  }
}
