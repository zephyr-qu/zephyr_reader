import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/features/profile/page/profile/profile_menu_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class ProfileMenuSections extends StatelessWidget {
  const ProfileMenuSections({super.key});

  @override
  Widget build(BuildContext context) {
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
          PhosphorIconsRegular.bookOpen,
          l10n.dictionary,
          MenuItemSemantic.primary,
          () => context.push(RoutePaths.dictionarySettings),
        ),
        MenuItemData(
          PhosphorIconsRegular.translate,
          l10n.translationApi,
          MenuItemSemantic.info,
          () => context.push(RoutePaths.translationApi),
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
