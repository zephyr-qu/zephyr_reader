import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';

class TtsSettingsPage extends HookWidget {
  late final TtsService tts = getIt<TtsService>();
  TtsSettingsPage({super.key});

  static const _previewText =
      'The quick brown fox jumps over the lazy dog. 敏捷的棕色狐狸跳过了懒狗。';

  @override
  Widget build(BuildContext context) {
    final speed = useState(1.0);
    final pitch = useState(1.0);
    final pauseBetween = useState(300);
    final bilingualAlternate = useState(true);
    final originalOnly = useState(false);
    final switchInterval = useState(500);
    final backgroundPlay = useState(true);
    final autoPage = useState(true);
    final highlightFollow = useState(true);
    final dimOnLock = useState(false);
    final loaded = useState(false);
    final tts = useMemoized(() => getIt<TtsService>(), []);

    useEffect(() {
      loadSettings(
        speed,
        pitch,
        pauseBetween,
        bilingualAlternate,
        originalOnly,
        switchInterval,
        backgroundPlay,
        autoPage,
        highlightFollow,
        dimOnLock,
        loaded,
      );
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
      ),
      body: loaded.value
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _buildPreviewCard(cs, tts),
                const SizedBox(height: 24),
                _buildVoiceSection(context, cs),
                const SizedBox(height: 24),
                _buildPlaybackSection(
                  context,
                  cs,
                  speed,
                  pitch,
                  pauseBetween,
                  tts,
                ),
                const SizedBox(height: 24),
                _buildBilingualSection(
                  context,
                  cs,
                  bilingualAlternate,
                  originalOnly,
                  switchInterval,
                ),
                const SizedBox(height: 24),
                _buildBehaviorSection(
                  context,
                  cs,
                  backgroundPlay,
                  autoPage,
                  highlightFollow,
                  dimOnLock,
                ),
              ],
            )
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  Future<void> loadSettings(
    ValueNotifier<double> speed,
    ValueNotifier<double> pitch,
    ValueNotifier<int> pauseBetween,
    ValueNotifier<bool> bilingualAlternate,
    ValueNotifier<bool> originalOnly,
    ValueNotifier<int> switchInterval,
    ValueNotifier<bool> backgroundPlay,
    ValueNotifier<bool> autoPage,
    ValueNotifier<bool> highlightFollow,
    ValueNotifier<bool> dimOnLock,
    ValueNotifier<bool> loaded,
  ) async {
    final prefs = getIt<SharedPreferences>();
    speed.value = prefs.getDouble('tts_speed') ?? 1.0;
    pitch.value = prefs.getDouble('tts_pitch') ?? 1.0;
    pauseBetween.value = prefs.getInt('tts_pause_between') ?? 300;
    bilingualAlternate.value = prefs.getBool('tts_bilingual_alternate') ?? true;
    originalOnly.value = prefs.getBool('tts_original_only') ?? false;
    switchInterval.value = prefs.getInt('tts_switch_interval') ?? 500;
    backgroundPlay.value = prefs.getBool('tts_background_play') ?? true;
    autoPage.value = prefs.getBool('tts_auto_page') ?? true;
    highlightFollow.value = prefs.getBool('tts_highlight_follow') ?? true;
    dimOnLock.value = prefs.getBool('tts_dim_on_lock') ?? false;
    loaded.value = true;
    unawaited(tts.setSpeed(speed.value));
    unawaited(tts.setPitch(pitch.value));
    tts.setPauseBetween(pauseBetween.value);
  }

  Future<void> _save(String key, Object value) async {
    final prefs = getIt<SharedPreferences>();
    if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  Future<void> _preview(TtsService tts) async {
    await tts.speak(_previewText);
  }

  Widget _buildPreviewCard(ColorScheme cs, TtsService tts) {
    final isPlaying = tts.isPlaying.value;
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
                onTap: isPlaying ? tts.stop : () => _preview(tts),
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

  Widget _buildVoiceSection(BuildContext context, ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: '语音引擎',
              colorScheme: Theme.of(context).colorScheme,
            ),
            SettingsCard(
              colorScheme: Theme.of(context).colorScheme,
              children: [
                _selectItem(cs, 'TTS 引擎', '系统默认', () {}),
                _selectItem(cs, '英文语音', 'Google US English', () {}),
                _selectItem(cs, '中文语音', '讯飞小燕', () {}),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildPlaybackSection(
    BuildContext context,
    ColorScheme cs,
    ValueNotifier<double> speed,
    ValueNotifier<double> pitch,
    ValueNotifier<int> pauseBetween,
    TtsService tts,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: '播放参数',
              colorScheme: Theme.of(context).colorScheme,
            ),
            SettingsCard(
              colorScheme: Theme.of(context).colorScheme,
              children: [
                SettingsSliderTile(
                  label: '语速',
                  value: '${speed.value.toStringAsFixed(1)}x',
                  current: speed.value,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (v) {
                    speed.value = v;
                    tts.setSpeed(v);
                    _save('tts_speed', v);
                  },
                  colorScheme: cs,
                ),
                SettingsSliderTile(
                  label: '音调',
                  value: pitch.value.toStringAsFixed(1),
                  current: pitch.value,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (v) {
                    pitch.value = v;
                    tts.setPitch(v);
                    _save('tts_pitch', v);
                  },
                  colorScheme: cs,
                ),
                SettingsSliderTile(
                  label: '句间停顿',
                  value: '${pauseBetween.value}ms',
                  current: pauseBetween.value.toDouble(),
                  min: 0,
                  max: 1000,
                  onChanged: (v) {
                    pauseBetween.value = v.toInt();
                    tts.setPauseBetween(v.toInt());
                    _save('tts_pause_between', v.toInt());
                  },
                  step: 50,
                  colorScheme: cs,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildBilingualSection(
    BuildContext context,
    ColorScheme cs,
    ValueNotifier<bool> bilingualAlternate,
    ValueNotifier<bool> originalOnly,
    ValueNotifier<int> switchInterval,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: '双语朗读',
              colorScheme: Theme.of(context).colorScheme,
              tag: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Zephyr 专属',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF6C00),
                  ),
                ),
              ),
            ),
            SettingsCard(
              showDividers: true,
              colorScheme: Theme.of(context).colorScheme,
              children: [
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowsLeftRight,
                  iconColor: MenuItemSemantic.reading.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.reading.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '双语交替朗读',
                  subtitle: '先读英文原文，再读中文译文',
                  value: bilingualAlternate.value,
                  onChanged: (v) {
                    bilingualAlternate.value = v;
                    _save('tts_bilingual_alternate', v);
                  },
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.textAa,
                  iconColor: MenuItemSemantic.reading.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.reading.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '仅朗读原文',
                  subtitle: '跳过译文段落，适合听力训练',
                  value: originalOnly.value,
                  onChanged: (v) {
                    originalOnly.value = v;
                    _save('tts_original_only', v);
                  },
                ),
                SettingsSliderTile(
                  label: '中英切换间隔',
                  value: '${switchInterval.value}ms',
                  current: switchInterval.value.toDouble(),
                  min: 200,
                  max: 1500,
                  onChanged: (v) {
                    switchInterval.value = v.toInt();
                    _save('tts_switch_interval', v.toInt());
                  },
                  step: 100,
                  colorScheme: cs,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    ColorScheme cs,
    ValueNotifier<bool> backgroundPlay,
    ValueNotifier<bool> autoPage,
    ValueNotifier<bool> highlightFollow,
    ValueNotifier<bool> dimOnLock,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: '行为偏好',
              colorScheme: Theme.of(context).colorScheme,
            ),
            SettingsCard(
              showDividers: true,
              colorScheme: Theme.of(context).colorScheme,
              children: [
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.playCircle,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '后台播放',
                  subtitle: '切出应用或锁屏后继续朗读',
                  value: backgroundPlay.value,
                  onChanged: (v) {
                    backgroundPlay.value = v;
                    _save('tts_background_play', v);
                  },
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowRight,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '自动翻页',
                  subtitle: '读完当前章节自动跳转下一章',
                  value: autoPage.value,
                  onChanged: (v) {
                    autoPage.value = v;
                    _save('tts_auto_page', v);
                  },
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.highlighter,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '高亮跟随',
                  subtitle: '朗读时实时高亮当前句子',
                  value: highlightFollow.value,
                  onChanged: (v) {
                    highlightFollow.value = v;
                    _save('tts_highlight_follow', v);
                  },
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.moon,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '息屏时降低音量',
                  subtitle: '节省电量，适合睡前听书',
                  value: dimOnLock.value,
                  onChanged: (v) {
                    dimOnLock.value = v;
                    _save('tts_dim_on_lock', v);
                  },
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.04, end: 0);
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
}
