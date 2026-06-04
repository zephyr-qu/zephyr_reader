import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class ProfilePage extends HookWidget {
  late final ProfileViewModel vm = getIt<ProfileViewModel>();
  ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => getIt<ProfileViewModel>(), []);

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
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildStatsRow(context, globalStats),
              const SizedBox(height: 28),
              _buildMenuSections(context),
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
              l10n.profileDisplayName,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(l10n.profileTagline, style: theme.textTheme.bodyMedium),
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
              final books = stats?.booksReadCount ?? 0;
              final streak = stats?.consecutiveReadingDays ?? 0;
              return Row(
                children: [
                  _statItem(
                    context,
                    '$streak',
                    l10n.consecutiveDaysLabel,
                    PhosphorIconsFill.fire,
                  ),
                  _divider(),
                  _statItem(
                    context,
                    '$books',
                    l10n.reading,
                    PhosphorIconsRegular.book,
                  ),
                  _divider(),
                  _statItem(
                    context,
                    '$hours',
                    l10n.readingTime,
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
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      _MenuSectionData(l10n.sectionStudyMgmt, [
        _MenuItemData(
          PhosphorIconsRegular.bookOpen,
          l10n.learningNotes,
          MenuItemSemantic.education,
          () => context.push(RoutePaths.learningNotes),
        ),
        _MenuItemData(
          PhosphorIconsRegular.clockCounterClockwise,
          l10n.readingSessions,
          MenuItemSemantic.reading,
          () => context.push(RoutePaths.readingSessions),
        ),
        _MenuItemData(
          PhosphorIconsRegular.hardDrives,
          l10n.storageSync,
          MenuItemSemantic.success,
          () => context.push(RoutePaths.storageSync),
        ),
      ]),
      _MenuSectionData(l10n.sectionReadingExp, [
        _MenuItemData(
          PhosphorIconsRegular.waveform,
          l10n.ttsSettings,
          MenuItemSemantic.info,
          () => context.push(RoutePaths.ttsSettings),
        ),
        _MenuItemData(
          PhosphorIconsRegular.textB,
          l10n.typographySettings,
          MenuItemSemantic.typography,
          () => context.push(RoutePaths.typographySettings),
        ),
        _MenuItemData(
          PhosphorIconsRegular.palette,
          l10n.themeBrightness,
          MenuItemSemantic.primary,
          () => context.push(RoutePaths.themeBrightness),
        ),
      ]),
      _MenuSectionData(l10n.sectionSystem, [
        _MenuItemData(
          PhosphorIconsRegular.hardDrive,
          l10n.backupRestore,
          MenuItemSemantic.success,
          () => context.push(RoutePaths.localBackup),
        ),
        _MenuItemData(
          PhosphorIconsRegular.dotsThreeOutline,
          l10n.otherSettings,
          MenuItemSemantic.neutral,
          () => context.push(RoutePaths.otherSettings),
        ),
        _MenuItemData(
          PhosphorIconsRegular.info,
          l10n.about,
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
        color: theme.colorScheme.outline,
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
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.appTheme.dividerSubtle,
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
                  style: theme.textTheme.bodyLarge?.copyWith(
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
                    color: item.badge == l10n.synced
                        ? MenuItemSemantic.success
                              .iconColor(theme.brightness)
                              .withValues(alpha: 0.1)
                        : item.semantic
                              .iconColor(theme.brightness)
                              .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item.badge == l10n.synced
                          ? MenuItemSemantic.success.iconColor(theme.brightness)
                          : item.semantic.iconColor(theme.brightness),
                    ),
                  ),
                ),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
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
}
