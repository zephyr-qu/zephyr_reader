import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 个人中心菜单区域。
class ProfileMenuSections extends StatelessWidget {
  const ProfileMenuSections({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;

    final sections = [
      _SectionData(
        label: l10n.sectionStudyMgmt,
        items: [
          _SectionItem(
            icon: PhosphorIconsRegular.bookmarkSimple,
            title: l10n.vocabularyBook,
            semantic: MenuItemSemantic.education,
            onTap: () => context.push(AppRoute.vocabulary.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.bookOpen,
            title: l10n.learningNotes,
            semantic: MenuItemSemantic.education,
            onTap: () => context.push(AppRoute.learningNotes.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.clockCounterClockwise,
            title: l10n.readingSessions,
            semantic: MenuItemSemantic.reading,
            onTap: () => context.push(AppRoute.readingSessions.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.hardDrives,
            title: l10n.storageSync,
            semantic: MenuItemSemantic.success,
            onTap: () => context.push(AppRoute.storageSync.path),
          ),
        ],
      ),
      _SectionData(
        label: l10n.sectionReadingExp,
        items: [
          _SectionItem(
            icon: PhosphorIconsRegular.waveform,
            title: l10n.ttsSettings,
            semantic: MenuItemSemantic.info,
            onTap: () => context.push(AppRoute.ttsSettings.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.textB,
            title: l10n.typographySettings,
            semantic: MenuItemSemantic.typography,
            onTap: () => context.push(AppRoute.typographySettings.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.bookOpen,
            title: l10n.dictionary,
            semantic: MenuItemSemantic.primary,
            onTap: () => context.push(AppRoute.dictionarySettings.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.translate,
            title: l10n.translationApi,
            semantic: MenuItemSemantic.info,
            onTap: () => context.push(AppRoute.translationApi.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.palette,
            title: l10n.themeBrightness,
            semantic: MenuItemSemantic.primary,
            onTap: () => context.push(AppRoute.themeBrightness.path),
          ),
        ],
      ),
      _SectionData(
        label: l10n.sectionSystem,
        items: [
          _SectionItem(
            icon: PhosphorIconsRegular.hardDrive,
            title: l10n.backupRestore,
            semantic: MenuItemSemantic.success,
            onTap: () => context.push(AppRoute.localBackup.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.dotsThreeOutline,
            title: l10n.otherSettings,
            semantic: MenuItemSemantic.neutral,
            onTap: () => context.push(AppRoute.otherSettings.path),
          ),
          _SectionItem(
            icon: PhosphorIconsRegular.info,
            title: l10n.about,
            semantic: MenuItemSemantic.about,
            onTap: () => context.push(AppRoute.about.path),
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          const SizedBox(height: 24),
          SectionLabel(label: section.label),
          SettingsCard(
            showDividers: true,
            children: section.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return SettingsNavigationTile(
                    icon: item.icon,
                    iconColor: item.semantic.iconColor(brightness),
                    iconBackground: item.semantic.iconBackground(brightness),
                    title: item.title,
                    subtitle: '',
                    onTap: item.onTap,
                  )
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

class _SectionData {
  final String label;
  final List<_SectionItem> items;
  const _SectionData({required this.label, required this.items});
}

class _SectionItem {
  final IconData icon;
  final String title;
  final MenuItemSemantic semantic;
  final VoidCallback onTap;
  const _SectionItem({
    required this.icon,
    required this.title,
    required this.semantic,
    required this.onTap,
  });
}
