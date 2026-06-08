import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _previewColors = <(Color, Color)>[
  (Color(0xFFFFFFFF), Color(0xFF1D1D1F)),
  (Color(0xFFF5E6C8), Color(0xFF3E2723)),
  (Color(0xFFFFF8E1), Color(0xFF4E342E)),
  (Color(0xFFC8E6C9), Color(0xFF1B5E20)),
  (Color(0xFFECEFF1), Color(0xFF263238)),
  (Color(0xFF000000), Color(0xFF9E9E9E)),
];

class ThemePreviewCard extends StatelessWidget {
  final int bgIndex;

  const ThemePreviewCard({super.key, required this.bgIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = _previewColors[bgIndex.clamp(0, _previewColors.length - 1)];
    final bg = colors.$1;
    final fg = colors.$2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bg.computeLuminance() > 0.5
              ? cs.outlineVariant.withValues(alpha: 0.15)
              : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '春风又绿江南岸，明月何时照我还。',
                style: TextStyle(fontSize: 16, height: 1.8, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                'The spring wind has greened the southern shore again.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: fg.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '实时预览',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }
}
