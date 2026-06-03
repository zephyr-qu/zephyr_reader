import 'package:flutter/material.dart';

import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';

class LearningNotesTabSwitcher extends StatelessWidget {
  final ColorScheme colorScheme;
  final int activeTab;
  final int vocabCount;
  final int noteCount;
  final LearningNotesViewModel vm;

  const LearningNotesTabSwitcher({
    super.key,
    required this.colorScheme,
    required this.activeTab,
    required this.vocabCount,
    required this.noteCount,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _tabItem(0, '生词本', vocabCount),
                const SizedBox(width: 3),
                _tabItem(1, '笔记本', noteCount),
              ],
            ),
          ),
        );
  }

  Widget _tabItem(int index, String label, int count) {
    final cs = colorScheme;
    final active = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: cs.onSurface.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? cs.primary.withValues(alpha: 0.1)
                      : cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
