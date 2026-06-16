part of 'translation_settings_page.dart';

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
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 60.ms)
        .slideY(begin: 0.03, end: 0);
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
                      (
                        l10n.translationAutoDetect,
                        'auto',
                        PhosphorIconsRegular.arrowLeft,
                      ),
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
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 120.ms)
        .slideY(begin: 0.03, end: 0);
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
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 180.ms)
        .slideY(begin: 0.03, end: 0);
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
                    borderRadius: BorderRadius.circular(RadiusSize.md.value),
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
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 240.ms)
        .slideY(begin: 0.03, end: 0);
  }
}
