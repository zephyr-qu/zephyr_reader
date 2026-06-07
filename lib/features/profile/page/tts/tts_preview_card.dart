import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// TTS 语音预览卡片，显示当前朗读文本及播放/停止控制。
///
/// 使用渐变背景突出显示当前朗读状态，提供播放和停止按钮。
/// 用于 TTS 设置页面的语音效果预览区域。
class TtsPreviewCard extends StatelessWidget {
  final String text;
  final bool isPlaying;
  final String playLabel;
  final String stopLabel;
  final String autoLabel;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const TtsPreviewCard({
    super.key,
    required this.text,
    required this.isPlaying,
    required this.playLabel,
    required this.stopLabel,
    required this.autoLabel,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.85),
            cs.primary.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            text,
            style: TextStyle(fontSize: 14, height: 1.6, color: cs.onPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: isPlaying ? onStop : onPlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? PhosphorIconsFill.stop : PhosphorIconsFill.play,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isPlaying ? stopLabel : playLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onPrimary,
                ),
              ),
              const Spacer(),
              Text(
                autoLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onPrimary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }
}
