import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/format_utils.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'profile_header.dart';
import 'profile_menu_widgets.dart';
import 'profile_stat_item.dart';

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
              final total = stats?.totalBooksCount ?? 0;
              return Row(
                children: [
                  ProfileStatItem(
                    value: '$hours',
                    label: l10n.readingTime,
                    icon: PhosphorIconsRegular.clock,
                  ),
                  _divider(),
                  ProfileStatItem(
                    value: formatChars(chars, l10n),
                    label: l10n.readingWords,
                    icon: PhosphorIconsRegular.book,
                  ),
                  _divider(),
                  ProfileStatItem(
                    value: total > 0 ? '$completed/$total' : '$completed',
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

  Widget _buildMenuSections(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      MenuSectionData(l10n.sectionStudyMgmt, [
        MenuItemData(
          PhosphorIconsRegular.bookmarkSimple,
          l10n.vocabularyBook,
          MenuItemSemantic.education,
          () => context.push(RoutePaths.vocabulary),
        ),
        MenuItemData(
          PhosphorIconsRegular.bookOpen,
          l10n.learningNotes,
          MenuItemSemantic.education,
          () => context.push(RoutePaths.learningNotes),
        ),
        MenuItemData(
          PhosphorIconsRegular.clockCounterClockwise,
          l10n.readingSessions,
          MenuItemSemantic.reading,
          () => context.push(RoutePaths.readingSessions),
        ),
        MenuItemData(
          PhosphorIconsRegular.hardDrives,
          l10n.storageSync,
          MenuItemSemantic.success,
          () => context.push(RoutePaths.storageSync),
        ),
      ]),
      MenuSectionData(l10n.sectionReadingExp, [
        MenuItemData(
          PhosphorIconsRegular.waveform,
          l10n.ttsSettings,
          MenuItemSemantic.info,
          () => context.push(RoutePaths.ttsSettings),
        ),
        MenuItemData(
          PhosphorIconsRegular.textB,
          l10n.typographySettings,
          MenuItemSemantic.typography,
          () => context.push(RoutePaths.typographySettings),
        ),
        MenuItemData(
          PhosphorIconsRegular.palette,
          l10n.themeBrightness,
          MenuItemSemantic.primary,
          () => context.push(RoutePaths.themeBrightness),
        ),
      ]),
      MenuSectionData(l10n.sectionSystem, [
        MenuItemData(
          PhosphorIconsRegular.hardDrive,
          l10n.backupRestore,
          MenuItemSemantic.success,
          () => context.push(RoutePaths.localBackup),
        ),
        MenuItemData(
          PhosphorIconsRegular.dotsThreeOutline,
          l10n.otherSettings,
          MenuItemSemantic.neutral,
          () => context.push(RoutePaths.otherSettings),
        ),
        MenuItemData(
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
            child: ProfileSectionLabel(label: section.label),
          ),
          ProfileSection(
            children: section.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return ProfileMenuItem(item: item, index: idx)
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (150 + idx * 60).ms)
                  .slideX(begin: 0.03, end: 0);
            }).toList(),
          ),
        ],
      ],
    );
  }
}
