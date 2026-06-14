import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class LegalSection extends StatelessWidget {
  final String appVersion;

  const LegalSection({super.key, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.otherLegal),
            SettingsCard(
              showDividers: true,
              children: [
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.fileText,
                  semantic: MenuItemSemantic.legal,
                  title: l10n.userAgreement,
                  subtitle: '',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const UserAgreementPage(),
                    ),
                  ),
                ),
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.shieldCheck,
                  semantic: MenuItemSemantic.legal,
                  title: l10n.privacyPolicy,
                  subtitle: '',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.code,
                  semantic: MenuItemSemantic.legal,
                  title: l10n.openSourceLicense,
                  subtitle: l10n.openSourceLicenseDesc,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Zephyr Reader',
                    applicationVersion: appVersion,
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.03, end: 0);
  }
}
