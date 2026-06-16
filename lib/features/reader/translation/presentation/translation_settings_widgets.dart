part of 'translation_settings_page.dart';

/// 图标 + 标题 + 当前值 + 右箭头 → 点击弹起底部面板。
class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBox(context, icon, cs),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// 图标 + 标签 + 内联文本输入。
class _InputTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String initialValue;
  final bool obscureText;
  final ValueChanged<String> onChanged;

  const _InputTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.obscureText,
    required this.onChanged,
  });

  @override
  State<_InputTile> createState() => _InputTileState();
}

class _InputTileState extends State<_InputTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_InputTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _iconBox(context, widget.icon, cs),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              obscureText: widget.obscureText,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                border: InputBorder.none,
                isDense: true,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _iconBox(BuildContext context, IconData icon, ColorScheme cs) {
  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(RadiusSize.sm.value),
    ),
    child: Icon(icon, size: 16, color: cs.onPrimaryContainer),
  );
}

void _showSheet(
  BuildContext context, {
  required String title,
  required List<(String label, String value, IconData icon)> options,
  required String current,
  required ValueChanged<String> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                ctx,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          for (final (label, value, icon) in options)
            InkWell(
              onTap: () {
                onSelected(value);
                Navigator.pop(ctx);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: value == current
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: value == current
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: value == current
                            ? Theme.of(ctx).colorScheme.primary
                            : Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (value == current)
                      Icon(
                        PhosphorIconsFill.checkCircle,
                        size: 20,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

/// 占位，避免编译问题；实际从 l10n 取
const l10nCustom = 'Custom';
