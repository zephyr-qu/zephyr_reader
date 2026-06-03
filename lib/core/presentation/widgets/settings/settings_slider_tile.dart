import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';

class SettingsSliderTile extends StatelessWidget {
  final String label;
  final String value;
  final double current;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double step;
  final ColorScheme colorScheme;

  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.08),
              thumbColor: colorScheme.primary,
              overlayColor: colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: current.clamp(min, max),
              min: min,
              max: max,
              divisions: step > 0
                  ? ((max - min) / step).round().clamp(1, 1000)
                  : null,
              onChanged: (value) {
                hapticFeedback(HapticType.selection);
                onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
