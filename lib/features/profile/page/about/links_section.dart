import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 关于页面的链接区域。
///
/// 显示检查更新、用户协议、隐私政策、开源许可等相关链接。
class LinksSection extends StatelessWidget {
  final List<(IconData, String, String?, bool)> links;
  final String version;

  const LinksSection({super.key, required this.links, required this.version});

  void _handleTap(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context)!;
    if (title == l10n.aboutCheckUpdate) {
      // TODO: 接入检查更新逻辑
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('v$version ${l10n.aboutLatestVersion}')),
      );
    } else if (title == l10n.aboutUserAgreement) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const UserAgreementPage()),
      );
    } else if (title == l10n.aboutPrivacyPolicy) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
      );
    } else if (title == l10n.aboutOpenSourceLicense) {
      showLicensePage(
        context: context,
        applicationName: 'Zephyr Reader',
        applicationVersion: 'v$version',
      );
    } else if (title == l10n.aboutFeedback) {
      _launchUrl(
        context,
        'https://github.com/Zephyr-Reader/zephyr-reader/issues',
      );
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.aboutCannotOpenLink}: $url',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: DesignTokens.warmAccent.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: links.asMap().entries.map((entry) {
            final i = entry.key;
            final (icon, title, subtitle, isExternal) = entry.value;
            final isLast = i == links.length - 1;
            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTap(context, title),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: DesignTokens.warmAccent.withValues(
                                    alpha: 0.08,
                                  ),
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
                              color: DesignTokens.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              size: 17,
                              color: DesignTokens.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (subtitle != null)
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            isExternal
                                ? PhosphorIconsRegular.arrowSquareOut
                                : PhosphorIconsRegular.caretRight,
                            size: 16,
                            color: DesignTokens.warmAccent.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
