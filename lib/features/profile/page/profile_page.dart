import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ProfilePage extends HookWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = useMemoized(() => getIt<ProfileViewModel>());

    useEffect(() {
      vm.loadStats();
      return null;
    }, []);

    final AsyncState<GlobalStats?> globalStats = useSignalValue(vm.globalStats);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 52),
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildStatsRow(context, globalStats),
          const SizedBox(height: 28),
          _buildMenuGrid(context),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Zephyr Reader v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: DesignTokens.warmAccent,
          child: Text(
            '书',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '书友',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '阅读是一种生活态度',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildStatsRow(
    BuildContext context,
    AsyncState<GlobalStats?> globalStats,
  ) {
    final theme = Theme.of(context);

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
            error: (e) => Center(
              child: Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            data: (stats) {
              final hours = stats != null
                  ? (stats.totalReadingTimeSeconds / 3600).round()
                  : 0;
              final books = stats?.booksReadCount ?? 0;
              final streak = stats?.consecutiveReadingDays ?? 0;
              return Row(
                children: [
                  _statItem(context, '$streak', '连续天数', PhosphorIconsFill.fire),
                  _divider(),
                  _statItem(context, '$books', '在读', PhosphorIconsRegular.book),
                  _divider(),
                  _statItem(
                    context,
                    '$hours',
                    '阅读时长',
                    PhosphorIconsRegular.clock,
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

  Widget _statItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: DesignTokens.warmAccent),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: DesignTokens.warmAccent.withValues(alpha: 0.15),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final items = [
      _MenuItemData(
        PhosphorIconsRegular.book,
        '阅读设置',
        () => context.push(RoutePaths.readingSettings),
      ),
      _MenuItemData(
        PhosphorIconsRegular.gearSix,
        '应用设置',
        () => context.push(RoutePaths.appSettings),
      ),
      _MenuItemData(
        PhosphorIconsRegular.bookmark,
        '生词本',
        () => context.push(RoutePaths.vocabulary),
      ),
      _MenuItemData(
        PhosphorIconsRegular.clockCounterClockwise,
        '阅读会话',
        () => context.push(RoutePaths.readingSessions),
      ),
      _MenuItemData(
        PhosphorIconsRegular.hardDrives,
        '缓存管理',
        () => context.push(RoutePaths.cacheManage),
      ),
      _MenuItemData(
        PhosphorIconsRegular.arrowsClockwise,
        '数据同步',
        () => context.push(RoutePaths.sync),
      ),
      _MenuItemData(
        PhosphorIconsRegular.info,
        '关于',
        () => context.push(RoutePaths.about),
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _menuCard(context, items[i], i)),
                const SizedBox(width: 8),
                if (i + 1 < items.length)
                  Expanded(child: _menuCard(context, items[i + 1], i + 1))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _menuCard(BuildContext context, _MenuItemData item, int index) {
    final theme = Theme.of(context);
    return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(item.icon, size: 24, color: DesignTokens.warmAccent),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: (150 + index * 60).ms)
        .slideY(begin: 0.06, end: 0);
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _MenuItemData(this.icon, this.title, this.onTap);
}
