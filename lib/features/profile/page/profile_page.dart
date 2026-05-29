import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ProfilePage extends HookWidget {
  final ProfileViewModel vm;

  const ProfilePage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          _buildMenuSections(context),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Zephyr Reader v1.0.0',
              style: theme.textTheme.labelLarge,
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
        CircleAvatar(
          radius: 28,
          backgroundColor: DesignTokens.warmAccent,
          child: Text(
            '书',
            style: theme.textTheme.headlineMedium?.copyWith(
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
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text('阅读是一种生活态度', style: theme.textTheme.bodyMedium),
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
            error: (e) =>
                Center(child: Text('加载失败', style: theme.textTheme.bodyMedium)),
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

  Widget _buildMenuSections(BuildContext context) {
    final sections = [
      _MenuSectionData('学习与管理', [
        _MenuItemData(
          PhosphorIconsRegular.bookOpen,
          '学习与笔记',
          MenuItemSemantic.education,
          () => context.push(RoutePaths.learningNotes),
        ),
        _MenuItemData(
          PhosphorIconsRegular.clockCounterClockwise,
          '阅读会话',
          MenuItemSemantic.reading,
          () => context.push(RoutePaths.readingSessions),
        ),
        _MenuItemData.withBadge(
          PhosphorIconsRegular.arrowsClockwise,
          '数据同步',
          MenuItemSemantic.success,
          '已同步',
          () => context.push(RoutePaths.sync),
        ),
        _MenuItemData(
          PhosphorIconsRegular.hardDrives,
          '存储与同步',
          MenuItemSemantic.success,
          () => context.push(RoutePaths.storageSync),
        ),
      ]),
      _MenuSectionData('阅读体验', [
        _MenuItemData(
          PhosphorIconsRegular.waveform,
          '朗读设置',
          MenuItemSemantic.info,
          () => context.push(RoutePaths.ttsSettings),
        ),
        _MenuItemData(
          PhosphorIconsRegular.textB,
          '排版与字体',
          MenuItemSemantic.typography,
          () => context.push(RoutePaths.typographySettings),
        ),
        _MenuItemData(
          PhosphorIconsRegular.palette,
          '主题与亮度',
          MenuItemSemantic.primary,
          () => context.push(RoutePaths.themeBrightness),
        ),
      ]),
      _MenuSectionData('系统', [
        _MenuItemData(
          PhosphorIconsRegular.dotsThreeOutline,
          '其他设置',
          MenuItemSemantic.neutral,
          () => context.push(RoutePaths.otherSettings),
        ),
        _MenuItemData(
          PhosphorIconsRegular.info,
          '关于',
          MenuItemSemantic.about,
          () => context.push(RoutePaths.about),
        ),
      ]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Padding(
            padding: EdgeInsets.only(
              left: 4,
              bottom: 10,
              top: sections.first == section ? 0 : 20,
            ),
            child: _buildSectionLabel(context, section),
          ),
          _buildSection(context, section),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, _MenuSectionData section) {
    final theme = Theme.of(context);
    return Text(
      section.label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildSection(BuildContext context, _MenuSectionData section) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: section.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildMenuItem(context, item, idx)
              .animate()
              .fadeIn(duration: 300.ms, delay: (150 + idx * 60).ms)
              .slideX(begin: 0.03, end: 0);
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItemData item, int index) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.semantic.iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: item.semantic.iconBackground(theme.brightness),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: item.semantic.iconColor(theme.brightness),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (item.badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.badge == '已同步'
                        ? MenuItemSemantic.success.iconColor(theme.brightness).withValues(
                            alpha: 0.1,
                          )
                        : item.semantic.iconColor(theme.brightness).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item.badge == '已同步'
                          ? MenuItemSemantic.success.iconColor(theme.brightness)
                          : item.semantic.iconColor(theme.brightness),
                    ),
                  ),
                ),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSectionData {
  final String label;
  final List<_MenuItemData> items;
  const _MenuSectionData(this.label, this.items);
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final MenuItemSemantic semantic;
  final String? badge;
  final VoidCallback onTap;
  const _MenuItemData(this.icon, this.title, this.semantic, this.onTap)
    : badge = null;
  const _MenuItemData.withBadge(
    this.icon,
    this.title,
    this.semantic,
    this.badge,
    this.onTap,
  );
}
