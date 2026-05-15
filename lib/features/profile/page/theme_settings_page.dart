library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/eye_protection_theme.dart';
import 'package:zephyr_reader/core/theme/pure_black_theme.dart';

class ThemeSettingsPage extends HookWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = useState(ThemeMode.system);
    final autoThemeEnabled = useState(false);

    return Scaffold(
      appBar: AppBar(title: const Text('主题设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('主题模式', style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('跟随系统'), value: ThemeMode.system,
            groupValue: themeMode.value, onChanged: (v) { if (v != null) themeMode.value = v; },
            contentPadding: EdgeInsets.zero, dense: true,
          ),
          const Divider(height: 0.5, indent: 16),
          RadioListTile<ThemeMode>(
            title: const Text('浅色模式'), value: ThemeMode.light,
            groupValue: themeMode.value, onChanged: (v) { if (v != null) themeMode.value = v; },
            contentPadding: EdgeInsets.zero, dense: true,
          ),
          const Divider(height: 0.5, indent: 16),
          RadioListTile<ThemeMode>(
            title: const Text('深色模式'), value: ThemeMode.dark,
            groupValue: themeMode.value, onChanged: (v) { if (v != null) themeMode.value = v; },
            contentPadding: EdgeInsets.zero, dense: true,
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('自动切换', style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5)),
          ),
          SwitchListTile(
            title: const Text('自动主题切换'),
            subtitle: const Text('根据时间自动切换深色/浅色'),
            value: autoThemeEnabled.value,
            onChanged: (v) { autoThemeEnabled.value = v; },
            contentPadding: EdgeInsets.zero, dense: true,
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('主题预览', style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5)),
          ),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _previewCard('浅色', Colors.white, const Color(0xFF1A1A1A)),
                const SizedBox(width: 12),
                _previewCard('深色', const Color(0xFF0A0A0A), const Color(0xFFF2F2F2)),
                const SizedBox(width: 12),
                _previewCard('纯黑', PureBlackTheme.backgroundColor, PureBlackTheme.textPrimary),
                const SizedBox(width: 12),
                _previewCard('护眼', EyeProtectionTheme.backgroundColor, EyeProtectionTheme.textPrimary),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('阅读主题', style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5)),
          ),
          ListTile(
            title: const Text('阅读背景'), subtitle: const Text('设置阅读页面的背景颜色'),
            trailing: const Icon(Icons.chevron_right, size: 18, color: DesignTokens.textSecondary),
            contentPadding: EdgeInsets.zero, dense: true,
            onTap: () {},
          ),
          const Divider(height: 0.5),
          ListTile(
            title: const Text('阅读亮度'), subtitle: const Text('调节阅读页面的屏幕亮度'),
            trailing: const Icon(Icons.chevron_right, size: 18, color: DesignTokens.textSecondary),
            contentPadding: EdgeInsets.zero, dense: true,
            onTap: () {},
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _previewCard(String name, Color bg, Color textColor) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesignTokens.divider, width: 0.5),
              ),
              child: Center(
                child: Text('Aa', style: TextStyle(fontSize: 20, color: textColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
        ],
      ),
    );
  }
}
