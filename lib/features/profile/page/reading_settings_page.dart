/// 阅读设置页面
///
/// 提供阅读器相关的设置选项：
/// - 字体大小
/// - 行间距
/// - 翻页模式
/// - 主题设置
/// - 亮度调节
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 阅读设置页面
class ReadingSettingsPage extends StatefulHookWidget {
  const ReadingSettingsPage({super.key});

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage>
    with SignalsMixin {
  @override
  Widget build(BuildContext context) {
    // 设置状态
    final fontSize = useSignal(18.0);
    final lineHeight = useSignal(1.5);
    final enableAnimation = useSignal(true);
    final keepScreenOn = useSignal(true);
    final showBattery = useSignal(false);
    final showTime = useSignal(true);
    final clickZone = useSignal(3); // 1: 简化，2: 中等，3: 完整

    return Scaffold(
      appBar: AppBar(title: const Text('阅读设置')),
      body: ListView(
        children: [
          // 字体设置
          _buildSection(
            context,
            title: '字体设置',
            children: [
              _buildSliderSetting(
                context,
                title: '字体大小',
                value: fontSize.value,
                min: 12,
                max: 32,
                divisions: 20,
                suffix: '${fontSize.value.toInt()}px',
                onChanged: (v) => fontSize.value = v,
              ),
              const Divider(height: 1),
              _buildSliderSetting(
                context,
                title: '行间距',
                value: lineHeight.value,
                min: 1.0,
                max: 2.0,
                divisions: 20,
                suffix: 'x${lineHeight.value.toStringAsFixed(1)}',
                onChanged: (v) => lineHeight.value = v,
              ),
            ],
          ),

          // 翻页设置
          _buildSection(
            context,
            title: '翻页设置',
            children: [
              _buildRadioSetting(
                context,
                title: '翻页模式',
                value: 0,
                groupValue: 0,
                items: const [('上下滚动', 0), ('左右翻页', 1)],
                onChanged: (_) {},
              ),
              const Divider(height: 1),
              _buildRadioSetting(
                context,
                title: '翻页动画',
                value: enableAnimation.value ? 0 : 1,
                groupValue: 0,
                items: const [('启用', 0), ('禁用', 1)],
                onChanged: (v) => enableAnimation.value = v == 0,
              ),
            ],
          ),

          // 屏幕设置
          _buildSection(
            context,
            title: '屏幕设置',
            children: [
              _buildSwitchSetting(
                context,
                title: '保持屏幕常亮',
                subtitle: '阅读时不让屏幕关闭',
                value: keepScreenOn.value,
                onChanged: (v) => keepScreenOn.value = v,
              ),
              const Divider(height: 1),
              _buildSwitchSetting(
                context,
                title: '显示电量',
                subtitle: '在阅读器中显示电量百分比',
                value: showBattery.value,
                onChanged: (v) => showBattery.value = v,
              ),
              const Divider(height: 1),
              _buildSwitchSetting(
                context,
                title: '显示时间',
                subtitle: '在阅读器中显示当前时间',
                value: showTime.value,
                onChanged: (v) => showTime.value = v,
              ),
            ],
          ),

          // 点击区域设置
          _buildSection(
            context,
            title: '点击区域',
            children: [
              _buildRadioSetting(
                context,
                title: '点击区域布局',
                value: clickZone.value,
                groupValue: clickZone.value,
                items: const [('完整区域 (推荐)', 3), ('中等区域', 2), ('简化区域', 1)],
                onChanged: (v) {
                  if (v != null) clickZone.value = v;
                },
              ),
            ],
          ),

          // 重置设置
          _buildSection(
            context,
            title: '',
            children: [
              ListTile(
                title: const Text(
                  '重置为默认值',
                  style: TextStyle(color: Colors.red),
                ),
                leading: const Icon(Icons.refresh, color: Colors.red),
                onTap: () {
                  fontSize.value = 18.0;
                  lineHeight.value = 1.5;
                  enableAnimation.value = true;
                  keepScreenOn.value = true;
                  showBattery.value = false;
                  showTime.value = true;
                  clickZone.value = 3;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已重置为默认设置')));
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSliderSetting(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: suffix,
        onChanged: onChanged,
      ),
      trailing: Text(suffix, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildRadioSetting(
    BuildContext context, {
    required String title,
    required int value,
    required int groupValue,
    required List<(String, int)> items,
    required ValueChanged<int?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        children: items.map((item) {
          return RadioGroup<int>(
            groupValue: groupValue,
            onChanged: (v) {
              onChanged(v);
            },
            child: RadioListTile<int>(
              title: Text(item.$1),
              value: item.$2,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}
