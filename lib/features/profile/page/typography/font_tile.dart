import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader/models/font_info.dart';

class FontTile extends StatelessWidget {
  final FontInfo font;
  final bool isActive;
  final String familyName;
  final VoidCallback onTap;

  const FontTile({
    super.key,
    required this.font,
    required this.isActive,
    required this.familyName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sampleChar = switch (font.id) {
      'serif' => '宋',
      'sans' => '黑',
      _ => '永',
    };
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary.withValues(alpha: 0.08)
                : cs.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? cs.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                sampleChar,
                style: TextStyle(
                  fontFamily: familyName,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isActive ? cs.primary : cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                font.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
