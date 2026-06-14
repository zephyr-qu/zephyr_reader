import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/models/font_info.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

String _fontFamily(FontRepository fontRepo, String fontId) {
  try {
    final font = fontRepo.availableFonts.value.firstWhere(
      (f) => f.id == fontId,
    );
    return fontRepo.familyNameFor(font);
  } catch (_) {
    return 'system-ui, sans-serif';
  }
}

class TypographyPreview extends HookWidget {
  final ReaderConfig config;
  final FontRepository fontRepo;

  const TypographyPreview({
    super.key,
    required this.config,
    required this.fontRepo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final double fontSize = useSignalValue(config.fontSize.signal);
    final double lineHeight = useSignalValue(config.lineHeight.signal);
    final double paragraphSpacing = useSignalValue(
      config.paragraphSpacing.signal,
    );
    final double letterSpacing = useSignalValue(config.letterSpacing.signal);
    final double margin = useSignalValue(config.padding.signal);
    final FontInfo? currentFontInfo = useSignalValue(fontRepo.currentFont);
    final fontId = currentFontInfo?.id ?? 'system';

    return Container(
      padding: EdgeInsets.fromLTRB(margin, 24, margin, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.livePreview,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: AnimTokens.fast,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '春风又绿江南岸，明月何时照我还。',
                  style: TextStyle(
                    fontFamily: _fontFamily(fontRepo, fontId),
                    fontSize: fontSize * 1.05,
                    height: lineHeight,
                    letterSpacing: letterSpacing,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: paragraphSpacing),
                Text(
                  'The spring wind has greened the southern shore again.',
                  style: TextStyle(
                    fontFamily: _fontFamily(fontRepo, fontId),
                    fontSize: fontSize * 0.9,
                    height: lineHeight,
                    letterSpacing: letterSpacing,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }
}
