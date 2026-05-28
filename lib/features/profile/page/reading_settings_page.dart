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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';

class ReadingSettingsPage extends StatefulHookWidget {
  const ReadingSettingsPage({super.key});

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage>
    with SignalsMixin {
  final _config = getIt<ReaderConfig>();

  @override
  Widget build(BuildContext context) {
    // 设置状态
    final fontSize = useSignal(_config.fontSize.value.size.toDouble());
    final lineHeight = useSignal(_config.lineHeight.value);
    final enableAnimation = useSignal(true);
    final keepScreenOn = useSignal(true);
    final showBattery = useSignal(false);
    final showTime = useSignal(true);
    final clickZone = useSignal(3); // 1: 简化，2: 中等，3: 完整

    return Scaffold(
      appBar: AppBar(title: const Text('阅读设置')),
      body: ListView(
        children: [
          _buildFontSection(context, fontSize, lineHeight),
          _buildPageSection(context, enableAnimation),
          _buildScreenSection(context, keepScreenOn, showBattery, showTime),
          _buildReaderAppearanceSection(context),
          _buildClickZoneSection(context, clickZone),
          _buildResetSection(
            context,
            fontSize,
            lineHeight,
            enableAnimation,
            keepScreenOn,
            showBattery,
            showTime,
            clickZone,
          ),
          SizedBox(height: DesignTokens.spacing(Spacing.xl)),
        ],
      ),
    );
  }

  Widget _buildFontSection(
    BuildContext context,
    Signal<double> fontSize,
    Signal<double> lineHeight,
  ) {
    return _buildSection(
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
          onChanged: (v) {
            fontSize.value = v;
            _config.setFontSize(ReaderFontSize.fromSize(v));
          },
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
          onChanged: (v) {
            lineHeight.value = v;
            _config.setLineHeight(v);
          },
        ),
        const Divider(height: 1),
        _buildFontSelector(context),
        const Divider(height: 1),
        _buildFontRecommendations(context),
      ],
    );
  }

  Widget _buildPageSection(BuildContext context, Signal<bool> enableAnimation) {
    return _buildSection(
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
    );
  }

  Widget _buildScreenSection(
    BuildContext context,
    Signal<bool> keepScreenOn,
    Signal<bool> showBattery,
    Signal<bool> showTime,
  ) {
    return _buildSection(
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
    );
  }

  Widget _buildClickZoneSection(BuildContext context, Signal<int> clickZone) {
    return _buildSection(
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
    );
  }

  Widget _buildReaderAppearanceSection(BuildContext context) {
    final bgIndex = useSignal(getIt<ReaderConfig>().readerBgColorIndex.value);

    return _buildSection(
      context,
      title: '阅读外观',
      children: [_buildBgColorPicker(context, bgIndex)],
    );
  }

  Widget _buildBgColorPicker(BuildContext context, Signal<int> bgIndex) {
    const bgColors = [
      Color(0xFFFAFAFA),
      Color(0xFFF5F0E8),
      Color(0xFFFFF8E7),
      Color(0xFFC7EDCC),
      Color(0xFFF0F0F0),
    ];
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '阅读背景色',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(bgColors.length, (i) {
              final isDark = bgColors[i].computeLuminance() < 0.5;
              final isSelected = bgIndex.value == i;
              return GestureDetector(
                onTap: () {
                  bgIndex.value = i;
                  getIt<ReaderConfig>().setReaderBgColorIndex(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? DesignTokens.warmAccent
                          : cs.outlineVariant.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: DesignTokens.warmAccent.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          PhosphorIconsBold.check,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black54,
                        )
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSection(
    BuildContext context,
    Signal<double> fontSize,
    Signal<double> lineHeight,
    Signal<bool> enableAnimation,
    Signal<bool> keepScreenOn,
    Signal<bool> showBattery,
    Signal<bool> showTime,
    Signal<int> clickZone,
  ) {
    return _buildSection(
      context,
      title: '',
      children: [
        ListTile(
          title: const Text('重置为默认值', style: TextStyle(color: Colors.red)),
          leading: const Icon(
            PhosphorIconsRegular.arrowsClockwise,
            color: Colors.red,
          ),
          onTap: () async {
            await _config.resetToDefault();
            fontSize.value = _config.fontSize.value.size.toDouble();
            lineHeight.value = _config.lineHeight.value;
            enableAnimation.value = true;
            keepScreenOn.value = true;
            showBattery.value = false;
            showTime.value = true;
            clickZone.value = 3;

            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已重置为默认设置')));
          },
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              DesignTokens.spacing(Spacing.md),
              DesignTokens.spacing(Spacing.md),
              DesignTokens.spacing(Spacing.md),
              DesignTokens.spacing(Spacing.sm),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        Column(children: children),
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

  Widget _buildFontSelector(BuildContext context) {
    final fontRepo = getIt<FontRepository>();
    return ListTile(
      title: Text(fontRepo.currentFont.value?.name ?? '系统默认'),
      trailing: Icon(
        PhosphorIconsRegular.caretRight,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        showModalBottomSheet<String>(
          context: context,
          builder: (c) => Column(
            mainAxisSize: MainAxisSize.min,
            children: fontRepo.availableFonts.value.map((font) {
              final theme = Theme.of(c);
              return ListTile(
                title: Text(font.name),
                trailing: fontRepo.currentFont.value?.id == font.id
                    ? Icon(
                        PhosphorIconsRegular.check,
                        size: 18,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  fontRepo.setCurrentFont(font.id);
                  Navigator.pop(c, font.id);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFontRecommendations(BuildContext context) {
    final theme = Theme.of(context);
    final recommendations = [
      FontRecommendation(
        name: '霞鹜文楷',
        url: 'https://github.com/lxgw/LXGW-WenKai',
        description: '开源楷体字体，适合中文长文阅读',
        family: 'LXGW WenKai',
      ),
      FontRecommendation(
        name: '思源宋体',
        url: 'https://github.com/adobe-fonts/source-han-serif',
        description: 'Adobe 与 Google 联合开发的宋体，端庄典雅',
        family: 'Source Han Serif',
      ),
      FontRecommendation(
        name: '得意黑',
        url: 'https://github.com/atelier-anchor/smiley-sans',
        description: '开源人文几何风格字体，现代感强',
        family: 'Smiley Sans',
      ),
    ];

    return ExpansionTile(
      title: const Text('推荐字体', style: TextStyle(fontSize: 14)),
      subtitle: const Text('从网络安装更多字体', style: TextStyle(fontSize: 12)),
      leading: Icon(
        PhosphorIconsRegular.textT,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      children: recommendations.map((rec) {
        return ListTile(
          title: Text(rec.name, style: const TextStyle(fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rec.description,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                rec.family,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          trailing: Icon(
            PhosphorIconsRegular.arrowSquareOut,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () async {
            final uri = Uri.tryParse(rec.url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          contentPadding: EdgeInsets.only(
            left: DesignTokens.spacing(Spacing.xxl),
            right: DesignTokens.spacing(Spacing.md),
          ),
        );
      }).toList(),
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
