import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';

/// 主题模式选项组件。
///
/// 显示一个主题模式（浅色/深色/跟随系统）的选择卡片，点击切换。
/// 选中态高亮显示，使用 [AppThemeType] 标识主题模式类型。
class ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppThemeType type;
  final AppThemeType currentTheme;
  final VoidCallback onTap;

  const ThemeModeOption({
    super.key,
    required this.label,
    required this.icon,
    required this.type,
    required this.currentTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = currentTheme == type;
    final iconColor = active ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
