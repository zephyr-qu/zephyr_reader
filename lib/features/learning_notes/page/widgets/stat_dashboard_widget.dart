import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LearningNotesStatDashboard extends StatelessWidget {
  final ColorScheme colorScheme;
  final int vocabTotalCount;
  final int noteTotalCount;
  final int vocabMasteredCount;

  const LearningNotesStatDashboard({
    super.key,
    required this.colorScheme,
    required this.vocabTotalCount,
    required this.noteTotalCount,
    required this.vocabMasteredCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          _statCard(
            '$vocabTotalCount',
            '生词总数',
            PhosphorIconsRegular.bookOpen,
            const Color(0xFFAB47BC),
            const Color(0xFFF3E5F5),
          ),
          const SizedBox(width: 10),
          _statCard(
            '$noteTotalCount',
            '笔记条数',
            PhosphorIconsRegular.notePencil,
            const Color(0xFFFFA726),
            const Color(0xFFFFF3E0),
          ),
          const SizedBox(width: 10),
          _statCard(
            '$vocabMasteredCount',
            '已掌握',
            PhosphorIconsRegular.sealCheck,
            const Color(0xFF66BB6A),
            const Color(0xFFE8F5E9),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String number,
    String label,
    IconData icon,
    Color accent,
    Color bg,
  ) {
    final cs = colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              number,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
