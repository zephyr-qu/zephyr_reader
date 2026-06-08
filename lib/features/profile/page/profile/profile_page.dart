import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'profile_header.dart';
import 'package:zephyr_reader/features/profile/page/profile/profile_menu_sections.dart';
import 'profile_stat_item.dart';

/// 个人中心页面。
///
/// 展示用户阅读统计概览，提供主题外观设置、TTS 设置、
/// 排版设置、数据管理等入口。
class ProfilePage extends HookWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => ProfileViewModel());

    useEffect(() {
      vm.loadStats();
      return null;
    }, []);

    final AsyncState<GlobalStats?> globalStats = useSignalValue(vm.globalStats);
    return Scaffold(
      body: Stack(
        children: [
          // Warm decorative wash
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DesignTokens.warmAccent.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 52),
              const ProfileHeader(),
              const SizedBox(height: 24),
              _buildStatsRow(context, globalStats),
              const SizedBox(height: 28),
              const ProfileMenuSections(),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  l10n.appVersionDisplay('1.0.0'),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    AsyncState<GlobalStats?> globalStats,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DesignTokens.warmAccentLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: DesignTokens.warmAccent.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: globalStats.map(
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e) =>
                Center(child: Text('加载失败', style: theme.textTheme.bodyMedium)),
            data: (stats) {
              final hours = stats != null
                  ? (stats.totalReadingTimeSeconds / 3600).round()
                  : 0;
              final chars = stats?.totalCharactersRead ?? 0;
              final completed = stats?.booksCompletedCount ?? 0;
              return Row(
                children: [
                  ProfileStatItem(
                    value: '$hours',
                    label: l10n.readingTime,
                    icon: PhosphorIconsRegular.clock,
                  ),
                  _divider(),
                  ProfileStatItem(
                    value: chars >= 1000
                        ? '${(chars / 1000).toStringAsFixed(1)}K'
                        : '$chars',
                    unit: 'W',
                    label: l10n.readingWords,
                    icon: PhosphorIconsRegular.book,
                  ),
                  _divider(),
                  ProfileStatItem(
                    value: '$completed',
                    label: l10n.booksCompleted,
                    icon: PhosphorIconsRegular.checkCircle,
                  ),
                ],
              );
            },
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.08, end: 0);
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: DesignTokens.warmAccent.withValues(alpha: 0.15),
    );
  }
}
