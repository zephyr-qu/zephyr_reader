import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 将排版配置中的字体族映射为预览可用的 Flutter 字体族。
///
/// Readium 侧使用 CSS 字体族名（webview 内生效）；Flutter 预览只能使用
/// 内置/打包字体，因此 Serif 与 Noto Serif SC 都映射到打包的 Noto Serif SC。
String? previewFontFamily(String fontFamily) {
  return switch (fontFamily) {
    'System' => null,
    _ => 'Noto Serif SC',
  };
}

/// 将字重数值（100–900）映射为 [FontWeight]。
FontWeight previewFontWeight(double weight) {
  final index = ((weight - 100) / 100).round().clamp(0, 8);
  return FontWeight.values[index];
}

/// 排版设置实时预览卡片。
class TypographyPreview extends HookWidget {
  final ReaderConfig config;

  const TypographyPreview({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final double fontSize = useSignalValue(config.fontSize.signal);
    final double fontWeight = useSignalValue(config.fontWeight.signal);
    final String fontFamily = useSignalValue(config.fontFamily.signal);
    final double lineHeight = 1.8;
    final double paragraphSpacing = 16.0;
    final double letterSpacing = 0.0;
    final double margin = useSignalValue(config.padding.signal);
    final family = previewFontFamily(fontFamily);
    final weight = previewFontWeight(fontWeight);

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
                    fontFamily: family,
                    fontSize: fontSize * 1.05,
                    fontWeight: weight,
                    height: lineHeight,
                    letterSpacing: letterSpacing,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: paragraphSpacing),
                Text(
                  'The spring wind has greened the southern shore again.',
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: fontSize * 0.9,
                    fontWeight: weight,
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
