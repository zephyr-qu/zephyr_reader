import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';

class TtsSettingsPage extends StatefulWidget {
  const TtsSettingsPage({super.key});

  @override
  State<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends State<TtsSettingsPage> {
  final _tts = getIt<TtsService>();

  double _speed = 1.0;
  double _pitch = 1.0;
  int _pauseBetween = 300;
  bool _bilingualAlternate = true;
  bool _originalOnly = false;
  int _switchInterval = 500;
  bool _backgroundPlay = true;
  bool _autoPage = true;
  bool _highlightFollow = true;
  bool _dimOnLock = false;
  bool _loaded = false;

  static const _previewText =
      'The quick brown fox jumps over the lazy dog. 敏捷的棕色狐狸跳过了懒狗。';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speed = prefs.getDouble('tts_speed') ?? 1.0;
      _pitch = prefs.getDouble('tts_pitch') ?? 1.0;
      _pauseBetween = prefs.getInt('tts_pause_between') ?? 300;
      _bilingualAlternate = prefs.getBool('tts_bilingual_alternate') ?? true;
      _originalOnly = prefs.getBool('tts_original_only') ?? false;
      _switchInterval = prefs.getInt('tts_switch_interval') ?? 500;
      _backgroundPlay = prefs.getBool('tts_background_play') ?? true;
      _autoPage = prefs.getBool('tts_auto_page') ?? true;
      _highlightFollow = prefs.getBool('tts_highlight_follow') ?? true;
      _dimOnLock = prefs.getBool('tts_dim_on_lock') ?? false;
      _loaded = true;
    });
    unawaited(_tts.setSpeed(_speed));
    unawaited(_tts.setPitch(_pitch));
    _tts.setPauseBetween(_pauseBetween);
  }

  Future<void> _save(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  Future<void> _preview() async {
    await _tts.speak(_previewText);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '朗读设置',
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
                _buildPreviewCard(cs),
                const SizedBox(height: 24),
                _buildVoiceSection(cs),
                const SizedBox(height: 24),
                _buildPlaybackSection(cs),
                const SizedBox(height: 24),
                _buildBilingualSection(cs),
                const SizedBox(height: 24),
                _buildBehaviorSection(cs),
              ],
            )
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  // ==================== Preview Card ====================

  Widget _buildPreviewCard(ColorScheme cs) {
    final isPlaying = _tts.isPlaying.value;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            _previewText,
            style: TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: isPlaying ? _tts.stop : _preview,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? PhosphorIconsFill.stop : PhosphorIconsFill.play,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isPlaying ? '停止试听' : '试听当前配置',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '修改后自动刷新',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  // ==================== Section Wrappers ====================

  Widget _sectionLabel(String label, {String? tag}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.4,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF6C00),
                ),
              ),
            ),
          ],
        ],
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

  // ==================== Voice & Engine Section ====================

  Widget _buildVoiceSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('语音引擎'),
            _sectionCard([
              _selectItem(cs, 'TTS 引擎', '系统默认', () {}),
              _selectItem(cs, '英文语音', 'Google US English', () {}),
              _selectItem(cs, '中文语音', '讯飞小燕', () {}),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Playback Parameters Section ====================

  Widget _buildPlaybackSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('播放参数'),
            _sectionCard([
              _sliderItem(
                cs,
                '语速',
                '${_speed.toStringAsFixed(1)}x',
                _speed,
                0.5,
                2.0,
                (v) {
                  setState(() => _speed = v);
                  _tts.setSpeed(v);
                  _save('tts_speed', v);
                },
              ),
              _sliderItem(
                cs,
                '音调',
                _pitch.toStringAsFixed(1),
                _pitch,
                0.5,
                2.0,
                (v) {
                  setState(() => _pitch = v);
                  _tts.setPitch(v);
                  _save('tts_pitch', v);
                },
              ),
              _sliderItem(
                cs,
                '句间停顿',
                '${_pauseBetween}ms',
                _pauseBetween.toDouble(),
                0,
                1000,
                (v) {
                  setState(() => _pauseBetween = v.toInt());
                  _tts.setPauseBetween(v.toInt());
                  _save('tts_pause_between', v.toInt());
                },
                step: 50,
              ),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Bilingual Section ====================

  Widget _buildBilingualSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('双语朗读', tag: 'Zephyr 专属'),
            _sectionCard([
              _toggleItem(cs, '双语交替朗读', '先读英文原文，再读中文译文', _bilingualAlternate, (
                v,
              ) {
                setState(() => _bilingualAlternate = v);
                _save('tts_bilingual_alternate', v);
              }),
              _toggleItem(cs, '仅朗读原文', '跳过译文段落，适合听力训练', _originalOnly, (v) {
                setState(() => _originalOnly = v);
                _save('tts_original_only', v);
              }),
              _sliderItem(
                cs,
                '中英切换间隔',
                '${_switchInterval}ms',
                _switchInterval.toDouble(),
                200,
                1500,
                (v) {
                  setState(() => _switchInterval = v.toInt());
                  _save('tts_switch_interval', v.toInt());
                },
                step: 100,
              ),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Behavior Section ====================

  Widget _buildBehaviorSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('行为偏好'),
            _sectionCard([
              _toggleItem(cs, '后台播放', '切出应用或锁屏后继续朗读', _backgroundPlay, (v) {
                setState(() => _backgroundPlay = v);
                _save('tts_background_play', v);
              }),
              _toggleItem(cs, '自动翻页', '读完当前章节自动跳转下一章', _autoPage, (v) {
                setState(() => _autoPage = v);
                _save('tts_auto_page', v);
              }),
              _toggleItem(cs, '高亮跟随', '朗读时实时高亮当前句子', _highlightFollow, (v) {
                setState(() => _highlightFollow = v);
                _save('tts_highlight_follow', v);
              }),
              _toggleItem(cs, '息屏时降低音量', '节省电量，适合睡前听书', _dimOnLock, (v) {
                setState(() => _dimOnLock = v);
                _save('tts_dim_on_lock', v);
              }),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ==================== Shared Widgets ====================

  Widget _sliderItem(
    ColorScheme cs,
    String label,
    String value,
    double current,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    double step = 0.1,
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

  Widget _selectItem(
    ColorScheme cs,
    String label,
    String current,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              current,
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
