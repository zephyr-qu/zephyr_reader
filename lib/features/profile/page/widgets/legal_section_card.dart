import 'package:flutter/material.dart';

/// 法律/协议类页面的章节卡片，统一标题 + 内容列表样式。
class LegalSectionCard extends StatelessWidget {
  final String title;
  final List<String> content;

  const LegalSectionCard({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...content.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
