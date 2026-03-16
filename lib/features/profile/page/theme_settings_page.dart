/// 主题设置页面
///
/// 提供主题选择、自动切换、阅读模式等设置
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../core/theme/eye_protection_theme.dart';
import '../../../core/theme/pure_black_theme.dart';

/// 主题设置页面
class ThemeSettingsPage extends HookWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = useState(ThemeMode.system);
    final autoThemeEnabled = useState(false);
    final darkModeStart = useState(18);
    final darkModeEnd = useState(6);

    return Scaffold(
      appBar: AppBar(title: const Text('主题设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题模式选择
          _buildThemeModeSection(context, themeMode),
          const SizedBox(height: 24),
          // 自动主题切换
          _buildAutoThemeSection(
            context,
            autoThemeEnabled,
            darkModeStart,
            darkModeEnd,
          ),
          const SizedBox(height: 24),
          // 主题预览
          _buildThemePreviewSection(context),
          const SizedBox(height: 24),
          // 阅读主题设置
          _buildReadingThemeSection(context),
        ],
      ),
    );
  }

  Widget _buildThemeModeSection(
    BuildContext context,
    ValueNotifier<ThemeMode> themeMode,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '主题模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: themeMode.value,
            onChanged: (value) {
              if (value != null) {
                themeMode.value = value;
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  subtitle: const Text('根据系统设置自动切换'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  subtitle: const Text('始终使用浅色主题'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  subtitle: const Text('始终使用深色主题'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoThemeSection(
    BuildContext context,
    ValueNotifier<bool> autoThemeEnabled,
    ValueNotifier<int> darkModeStart,
    ValueNotifier<int> darkModeEnd,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('自动主题切换'),
            subtitle: const Text('根据时间自动切换深色/浅色模式'),
            value: autoThemeEnabled.value,
            onChanged: (value) {
              autoThemeEnabled.value = value;
            },
          ),
          if (autoThemeEnabled.value) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('深色模式时间'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('开始时'),
                            DropdownButton<int>(
                              value: darkModeStart.value,
                              isExpanded: true,
                              items: List.generate(24, (i) => i)
                                  .map(
                                    (hour) => DropdownMenuItem(
                                      value: hour,
                                      child: Text('$hour:00'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  darkModeStart.value = value;
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(''),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('结束时间'),
                            DropdownButton<int>(
                              value: darkModeEnd.value,
                              isExpanded: true,
                              items: List.generate(24, (i) => i)
                                  .map(
                                    (hour) => DropdownMenuItem(
                                      value: hour,
                                      child: Text('$hour:00'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  darkModeEnd.value = value;
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemePreviewSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '主题预览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildThemePreviewCard(
                  context,
                  '浅色',
                  Colors.white,
                  Colors.black87,
                ),
                const SizedBox(width: 16),
                _buildThemePreviewCard(
                  context,
                  '深色',
                  const Color(0xFF1a1a1a),
                  const Color(0xFFe0e0e0),
                ),
                const SizedBox(width: 16),
                _buildThemePreviewCard(
                  context,
                  '纯黑',
                  PureBlackTheme.backgroundColor,
                  PureBlackTheme.textPrimary,
                ),
                const SizedBox(width: 16),
                _buildThemePreviewCard(
                  context,
                  '护眼',
                  EyeProtectionTheme.backgroundColor,
                  EyeProtectionTheme.textPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThemePreviewCard(
    BuildContext context,
    String name,
    Color bgColor,
    Color textColor,
  ) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: bgColor,
                  child: Center(
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 24,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingThemeSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '阅读主题',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('阅读背景'),
            subtitle: const Text('设置阅读页面的背景颜'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 跳转到阅读背景设
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('阅读背景设置功能开发中')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('阅读亮度'),
            subtitle: const Text('调节阅读页面的屏幕亮'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 跳转到亮度设
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('阅读亮度设置功能开发中')));
            },
          ),
        ],
      ),
    );
  }
}
