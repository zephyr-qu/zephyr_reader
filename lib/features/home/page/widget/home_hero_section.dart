import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// Hero 卡片：有书/空态共用同一布局结构
class _HeroCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _HeroCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(Spacing.md.value),
      decoration: BoxDecoration(
        gradient: _heroGradientFor(theme),
        borderRadius: BorderRadius.circular(RadiusSize.md.value),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          SizedBox(width: Spacing.md.value),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: Spacing.xs.value),
                Text(
                  subtitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: Spacing.md.value),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DesignTokens.warmAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RadiusSize.sm.value,
                        ),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 首屏 Hero 区域的渐变背景（按主题亮度自适应）
LinearGradient _heroGradientFor(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  final baseColor = isDark
      ? Color.lerp(DesignTokens.warmAccent, Colors.black, 0.4)!
      : DesignTokens.warmAccent;
  return LinearGradient(
    colors: [baseColor, baseColor.withValues(alpha: 0.7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

final _heroCoverPlaceholder = Container(
  color: Colors.white.withValues(alpha: 0.3),
  child: Icon(
    PhosphorIconsRegular.bookOpenText,
    size: 28,
    color: Colors.white.withValues(alpha: 0.6),
  ),
);

/// 首页顶部 Hero 区域组件。
///
/// 有书籍时显示封面和当前阅读书目的快捷入口卡片；
/// 无书籍时显示空态引导（导入书籍按钮）。

class HomeHeroSection extends StatelessWidget {
  final Book? book;

  const HomeHeroSection({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (book case final b?) {
      return _HeroCard(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(RadiusSize.sm.value),
          child: SizedBox(
            width: 72,
            height: 100,
            child: b.coverPath != null
                ? Image.file(
                    File(resolveCoverPath(b.coverPath!)!),
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    errorBuilder: (_, _, _) => _heroCoverPlaceholder,
                  )
                : _heroCoverPlaceholder,
          ),
        ),
        title: b.title,
        subtitle: b.author ?? l10n.unknownAuthor,
        buttonLabel: l10n.continueReading,
        onPressed: () => context.pushNamed(
          AppRoute.reader.name,
          pathParameters: {'bookId': b.bookId, 'chapterId': '0'},
        ),
      );
    }
    return _HeroCard(
      leading: Icon(
        PhosphorIconsRegular.bookOpenText,
        size: 36,
        color: Colors.white.withValues(alpha: 0.9),
      ),
      title: l10n.startReadingJourney,
      subtitle: l10n.exploreNewWorld,
      buttonLabel: l10n.goToBookshelf,
      onPressed: () => context.pushNamed(AppRoute.bookshelf.name),
    );
  }
}
