import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 翻译 API 设置页面。
///
/// 遵循设置页面统一布局规范：
/// SettingsAppBar + [SectionLabel / SettingsCard] + 入场动画。
class TranslationSettingsPage extends HookWidget {
  const TranslationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = useMemoized(() => getIt<TranslationConfig>());

    final String provider =
        useSignalValue(config.provider.signal) as String;
    final String apiUrl =
        useSignalValue(config.apiUrl.signal) as String;
    final String apiKey =
        useSignalValue(config.apiKey.signal) as String;
    final String model =
        useSignalValue(config.model.signal) as String;
    final String sourceLang =
        useSignalValue(config.sourceLang.signal) as String;
    final String targetLang =
        useSignalValue(config.targetLang.signal) as String;
    final int timeout =
        useSignalValue(config.timeoutSeconds.signal) as int;

    final testResult = useState<String?>(null);
    final isTesting = useState(false);
    final isTestSuccess = useState<bool?>(null);

    Future<void> onTestConnection() async {
      isTesting.value = true;
      testResult.value = null;
      isTestSuccess.value = null;
      try {
        final service = getIt<TranslationService>();
        await service.translate(
          text: 'Hello',
          targetLang: targetLang,
          sourceLang: sourceLang == 'auto' ? null : sourceLang,
        );
        testResult.value = l10n.translationTestSuccess;
        isTestSuccess.value = true;
      } catch (e) {
        testResult.value = l10n.translationTestFailed(e);
        isTestSuccess.value = false;
      } finally {
        isTesting.value = false;
      }
    }

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.translationApi),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _ProviderSection(
            config: config,
            provider: provider,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          _ApiSection(
            config: config,
            apiUrl: apiUrl,
            apiKey: apiKey,
            model: model,
            provider: provider,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          _LangSection(
            config: config,
            sourceLang: sourceLang,
            targetLang: targetLang,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          _TimeoutSection(
            config: config,
            timeout: timeout,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          _TestSection(
            l10n: l10n,
            isTesting: isTesting.value,
            testResult: testResult.value,
            isTestSuccess: isTestSuccess.value,
            onTest: onTestConnection,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section widgets
// ══════════════════════════════════════════════════════════════════════════════

class _ProviderSection extends StatelessWidget {
  final TranslationConfig config;
  final String provider;
  final AppLocalizations l10n;

  const _ProviderSection({
    required this.config,
    required this.provider,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.translationProvider),
        SettingsCard(
          children: [
            _SelectTile(
              icon: PhosphorIconsRegular.cloud,
              label: l10n.translationProvider,
              value: provider == 'openai' ? 'OpenAI' : l10nCustom,
              onTap: () => _showSheet(
                context,
                title: l10n.translationProvider,
                options: [
                  ('OpenAI', 'openai', PhosphorIconsRegular.cloud),
                  (l10nCustom, 'custom', PhosphorIconsRegular.code),
                ],
                current: provider,
                onSelected: (v) => config.provider.value = v,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03, end: 0);
  }
}

class _ApiSection extends StatelessWidget {
  final TranslationConfig config;
  final String apiUrl;
  final String apiKey;
  final String model;
  final String provider;
  final AppLocalizations l10n;

  const _ApiSection({
    required this.config,
    required this.apiUrl,
    required this.apiKey,
    required this.model,
    required this.provider,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.translationApiUrl),
        SettingsCard(
          showDividers: true,
          children: [
            _InputTile(
              icon: PhosphorIconsRegular.link,
              label: l10n.translationApiUrl,
              hint: 'https://api.openai.com',
              initialValue: apiUrl,
              obscureText: false,
              onChanged: (v) => config.apiUrl.value = v,
            ),
            _InputTile(
              icon: PhosphorIconsRegular.key,
              label: l10n.translationApiKey,
              hint: 'sk-...',
              initialValue: apiKey,
              obscureText: true,
              onChanged: (v) => config.apiKey.value = v,
            ),
            if (provider == 'openai')
              _InputTile(
                icon: PhosphorIconsRegular.magicWand,
                label: l10n.translationModel,
                hint: 'gpt-4o-mini',
                initialValue: model,
                obscureText: false,
                onChanged: (v) => config.model.value = v,
              ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 60.ms).slideY(
      begin: 0.03,
      end: 0,
    );
  }
}

class _LangSection extends StatelessWidget {
  final TranslationConfig config;
  final String sourceLang;
  final String targetLang;
  final AppLocalizations l10n;

  const _LangSection({
    required this.config,
    required this.sourceLang,
    required this.targetLang,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (sourceLang) {
      'zh' => '中文',
      'en' => 'English',
      _ => l10n.translationAutoDetect,
    };
    final targetLabel = targetLang == 'zh' ? '中文' : 'English';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.translationSourceLang),
        SettingsCard(
          showDividers: true,
          children: [
            _SelectTile(
              icon: PhosphorIconsRegular.arrowLeft,
              label: l10n.translationSourceLang,
              value: sourceLabel,
              onTap: () => _showSheet(
                context,
                title: l10n.translationSourceLang,
                options: [
                  (l10n.translationAutoDetect, 'auto',
                      PhosphorIconsRegular.arrowLeft),
                  ('中文', 'zh', PhosphorIconsRegular.arrowLeft),
                  ('English', 'en', PhosphorIconsRegular.arrowLeft),
                ],
                current: sourceLang,
                onSelected: (v) => config.sourceLang.value = v,
              ),
            ),
            _SelectTile(
              icon: PhosphorIconsRegular.arrowRight,
              label: l10n.translationTargetLang,
              value: targetLabel,
              onTap: () => _showSheet(
                context,
                title: l10n.translationTargetLang,
                options: [
                  ('中文', 'zh', PhosphorIconsRegular.arrowRight),
                  ('English', 'en', PhosphorIconsRegular.arrowRight),
                ],
                current: targetLang,
                onSelected: (v) => config.targetLang.value = v,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 120.ms).slideY(
      begin: 0.03,
      end: 0,
    );
  }
}

class _TimeoutSection extends StatelessWidget {
  final TranslationConfig config;
  final int timeout;
  final AppLocalizations l10n;

  const _TimeoutSection({
    required this.config,
    required this.timeout,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.translationTimeout),
        SettingsCard(
          children: [
            SettingsSliderTile(
              label: l10n.translationTimeout,
              value: '${timeout}s',
              current: timeout.toDouble(),
              min: 5,
              max: 120,
              step: 5,
              onChanged: (v) => config.timeoutSeconds.value = v.toInt(),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 180.ms).slideY(
      begin: 0.03,
      end: 0,
    );
  }
}

class _TestSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isTesting;
  final String? testResult;
  final bool? isTestSuccess;
  final VoidCallback onTest;

  const _TestSection({
    required this.l10n,
    required this.isTesting,
    this.testResult,
    this.isTestSuccess,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isTesting ? null : onTest,
            icon: isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.translate, size: 18),
            label: Text(l10n.translationTest),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DesignTokens.radius(RadiusSize.md),
                ),
              ),
            ),
          ),
        ),
        if (testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTestSuccess == true
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsFill.warningCircle,
                  size: 14,
                  color: isTestSuccess == true
                      ? DesignTokens.success
                      : DesignTokens.error,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    testResult!,
                    style: TextStyle(
                      color: isTestSuccess == true
                          ? DesignTokens.success
                          : DesignTokens.error,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 240.ms).slideY(
      begin: 0.03,
      end: 0,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ══════════════════════════════════════════════════════════════════════════════

/// 图标 + 标题 + 当前值 + 右箭头 → 点击弹起底部面板。
class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBox(context, icon, cs),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// 图标 + 标签 + 内联文本输入。
class _InputTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String initialValue;
  final bool obscureText;
  final ValueChanged<String> onChanged;

  const _InputTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.obscureText,
    required this.onChanged,
  });

  @override
  State<_InputTile> createState() => _InputTileState();
}

class _InputTileState extends State<_InputTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_InputTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _iconBox(context, widget.icon, cs),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              obscureText: widget.obscureText,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                border: InputBorder.none,
                isDense: true,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helpers
// ══════════════════════════════════════════════════════════════════════════════

Widget _iconBox(BuildContext context, IconData icon, ColorScheme cs) {
  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.sm)),
    ),
    child: Icon(icon, size: 16, color: cs.onPrimaryContainer),
  );
}

void _showSheet(
  BuildContext context, {
  required String title,
  required List<(String label, String value, IconData icon)> options,
  required String current,
  required ValueChanged<String> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(ctx)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          for (final (label, value, icon) in options)
            InkWell(
              onTap: () {
                onSelected(value);
                Navigator.pop(ctx);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: value == current
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: value == current
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: value == current
                            ? Theme.of(ctx).colorScheme.primary
                            : Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (value == current)
                      Icon(
                        PhosphorIconsFill.checkCircle,
                        size: 20,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

/// 占位，避免编译问题；实际从 l10n 取
const l10nCustom = 'Custom';
