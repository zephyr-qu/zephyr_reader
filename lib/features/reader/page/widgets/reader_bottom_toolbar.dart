library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class ReaderBottomToolbar extends StatelessWidget {
  final int currentPageIndex;
  final int totalPages;
  final ThemeMode themeMode;
  final bool isTtsPlaying;

  final VoidCallback? onShowCatalog;
  final VoidCallback? onShowNotes;
  final VoidCallback? onShowSettings;
  final VoidCallback? onTtsToggle;

  const ReaderBottomToolbar({
    super.key,
    required this.currentPageIndex,
    required this.totalPages,
    required this.themeMode,
    this.isTtsPlaying = false,
    this.onShowCatalog,
    this.onShowNotes,
    this.onShowSettings,
    this.onTtsToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    final textColor = isDark
        ? const Color(0xFFE8E6E1)
        : const Color(0xFF2C2C2C);
    final accentColor = DesignTokens.warmAccent;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _BarButton(
                    icon: PhosphorIconsLight.listBullets,
                    onTap: onShowCatalog,
                    color: textColor,
                    tooltip: '目录',
                  ),
                  _BarButton(
                    icon: PhosphorIconsLight.notePencil,
                    onTap: onShowNotes,
                    color: textColor,
                    tooltip: '笔记',
                  ),
                  const Spacer(),
                  _ProgressBadge(
                    pageIndex: currentPageIndex,
                    totalPages: totalPages,
                    accentColor: accentColor,
                  ),
                  const Spacer(),
                  _BarButton(
                    icon: PhosphorIconsLight.gearSix,
                    onTap: onShowSettings,
                    color: accentColor,
                    tooltip: '设置',
                  ),
                  _BarButton(
                    icon: isTtsPlaying
                        ? PhosphorIconsLight.speakerHigh
                        : PhosphorIconsLight.speakerNone,
                    onTap: onTtsToggle,
                    color: isTtsPlaying ? const Color(0xFF4CAF50) : textColor,
                    tooltip: '朗读',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final String? tooltip;

  const _BarButton({
    required this.icon,
    this.onTap,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: _PressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final int pageIndex;
  final int totalPages;
  final Color accentColor;

  const _ProgressBadge({
    required this.pageIndex,
    required this.totalPages,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        '${pageIndex + 1} / ${totalPages > 0 ? totalPages : 1}',
        style: TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({required this.child, this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _anim = Tween(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Transform.scale(
        scale: _anim.value,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: widget.child,
        ),
      ),
    );
  }
}
