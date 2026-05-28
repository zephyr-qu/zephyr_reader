import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';

class TypographySettingsPage extends StatefulWidget {
  const TypographySettingsPage({super.key});

  @override
  State<TypographySettingsPage> createState() => _TypographySettingsPageState();
}

class _TypographySettingsPageState extends State<TypographySettingsPage> {
  final _config = getIt<ReaderConfig>();
  final _fontRepo = getIt<FontRepository>();

  double _fontSize = 18;
  double _lineHeight = 1.6;
  double _paragraphSpacing = 16;
  double _letterSpacing = 0.0;
  double _margin = 20;
  String _currentFontId = 'system';
  bool _punctuationSqueeze = true;
  bool _baselineAlign = true;
  bool _verticalMode = false;
  bool _loaded = false;

  static const _fontOptions = [
    _FontOption('system', '系统默认', 'system-ui', '永'),
    _FontOption('serif', '思源宋体', 'serif', '永'),
    _FontOption('kaiti', '仓耳今楷', 'KaiTi', '永'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _fontSize = _config.fontSize.value.size;
    _lineHeight = _config.lineHeight.value;
    _paragraphSpacing = _config.paragraphSpacing.value;
    _letterSpacing = _config.letterSpacing.value;
    _margin = _config.padding.value;
    _punctuationSqueeze = _config.punctuationSqueeze.value;
    _baselineAlign = _config.baselineAlign.value;

    final currentFontName = _fontRepo.currentFont.value?.name ?? '';
    if (currentFontName.contains('宋') || currentFontName.contains('serif')) {
      _currentFontId = 'serif';
    } else if (currentFontName.contains('楷') ||
        currentFontName.contains('kai')) {
      _currentFontId = 'kaiti';
    } else {
      _currentFontId = 'system';
    }

    _loaded = true;
    setState(() {});
  }

  String get _fontFamily {
    switch (_currentFontId) {
      case 'serif':
        return 'serif';
      case 'kaiti':
        return 'KaiTi';
      default:
        return 'system-ui, sans-serif';
    }
  }

  Future<void> _selectFont(String id) async {
    setState(() => _currentFontId = id);
    await _fontRepo.setCurrentFont(id);
  }

  Future<void> _reset() async {
    await _config.resetToDefault();
    await _selectFont('system');
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '排版与字体',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _buildPreview(cs),
                const SizedBox(height: 24),
                _buildFontGrid(cs),
                const SizedBox(height: 24),
                _buildSliders(cs),
                const SizedBox(height: 24),
                _buildAdvancedCjk(cs),
                const SizedBox(height: 12),
                _buildReset(cs),
              ],
            )
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  // ==================== Live Preview ====================

  Widget _buildPreview(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(_margin, 24, _margin, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '实时预览',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '春风又绿江南岸，明月何时照我还。',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: _fontSize * 1.05,
                    height: _lineHeight,
                    letterSpacing: _letterSpacing,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: _paragraphSpacing),
                Text(
                  'The spring wind has greened the southern shore again.',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: _fontSize * 0.9,
                    height: _lineHeight,
                    letterSpacing: _letterSpacing,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  // ==================== Font Grid ====================

  Widget _buildFontGrid(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('字体选择'),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: _fontOptions.map((opt) {
                  final active = _currentFontId == opt.id;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectFont(opt.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: active
                              ? cs.primary.withValues(alpha: 0.08)
                              : cs.onSurface.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? cs.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              opt.sample,
                              style: TextStyle(
                                fontFamily: opt.family,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: active ? cs.primary : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Typography Sliders ====================

  Widget _buildSliders(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('排版参数'),
            _sectionCard([
              _sliderItem(
                cs,
                '字号',
                '${_fontSize.toInt()}px',
                _fontSize,
                12,
                32,
                (v) {
                  setState(() => _fontSize = v.roundToDouble());
                },
              ),
              _sliderItem(
                cs,
                '行距',
                _lineHeight.toStringAsFixed(1),
                _lineHeight,
                1.0,
                2.5,
                (v) {
                  setState(() => _lineHeight = v);
                },
                step: 0.1,
              ),
              _sliderItem(
                cs,
                '段间距',
                '${_paragraphSpacing.toInt()}px',
                _paragraphSpacing,
                0,
                24,
                (v) {
                  setState(() => _paragraphSpacing = v.roundToDouble());
                },
                step: 2,
              ),
              _sliderItem(
                cs,
                '字间距',
                '${_letterSpacing.toStringAsFixed(1)}px',
                _letterSpacing,
                -0.5,
                2.0,
                (v) {
                  setState(() => _letterSpacing = v);
                },
                step: 0.1,
              ),
              _sliderItem(cs, '页边距', '${_margin.toInt()}px', _margin, 16, 48, (
                v,
              ) {
                setState(() => _margin = v.roundToDouble());
              }, step: 2),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Advanced CJK ====================

  Widget _buildAdvancedCjk(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    '高级排版',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CJK 优化',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _sectionCard([
              _toggleItem(cs, '标点挤压', '减少中文标点符号周围的空白', _punctuationSqueeze, (
                v,
              ) {
                setState(() => _punctuationSqueeze = v);
              }),
              _toggleItem(cs, '中西文基线对齐', '强制统一行高，避免混排时文字跳动', _baselineAlign, (
                v,
              ) {
                setState(() => _baselineAlign = v);
              }),
              _toggleItem(cs, '竖排模式', '从右向左阅读，适合古籍排版', _verticalMode, (v) {
                setState(() => _verticalMode = v);
              }),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Reset ====================

  Widget _buildReset(ColorScheme cs) {
    return Center(
      child: TextButton(
        onPressed: _reset,
        child: Text(
          '恢复默认设置',
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  // ==================== Shared Widgets ====================

  Widget _sectionLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _sliderItem(
    ColorScheme cs,
    String label,
    String value,
    double current,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    double step = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.08),
              thumbColor: cs.primary,
              overlayColor: cs.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: current.clamp(min, max),
              min: min,
              max: max,
              divisions: step > 0
                  ? ((max - min) / step).round().clamp(1, 1000)
                  : null,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(
    ColorScheme cs,
    String label,
    String desc,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 24,
            child: Switch.adaptive(
              value: value,
              activeThumbColor: DesignTokens.primary,
              activeTrackColor: DesignTokens.primary.withValues(alpha: 0.3),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontOption {
  final String id;
  final String label;
  final String family;
  final String sample;
  const _FontOption(this.id, this.label, this.family, this.sample);
}
