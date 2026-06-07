import 'package:flutter/material.dart';

class VersionFooter extends StatelessWidget {
  final String appVersion;
  final String checkUpdateLabel;
  final String feedbackLabel;
  final VoidCallback onCheckUpdate;
  final VoidCallback onFeedback;

  const VersionFooter({
    super.key,
    required this.appVersion,
    required this.checkUpdateLabel,
    required this.feedbackLabel,
    required this.onCheckUpdate,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Zephyr Reader $appVersion',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 2),
        Text(
          'Flutter 3.41.2 · Rust 1.82.0 · FRB 2.12.0',
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onCheckUpdate,
              child: Text(
                checkUpdateLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              ' · ',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            GestureDetector(
              onTap: onFeedback,
              child: Text(
                feedbackLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
