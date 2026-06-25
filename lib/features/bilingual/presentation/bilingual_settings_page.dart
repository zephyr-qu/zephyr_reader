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
import 'package:zephyr_reader/features/bilingual/application/bilingual_config.dart';
import 'package:zephyr_reader/features/bilingual/domain/bilingual_service.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

part 'bilingual_settings_sections.dart';
part 'bilingual_settings_widgets.dart';

/// 双语/翻译 API 设置页面。
///
/// 遵循设置页面统一布局规范：
/// SettingsAppBar + [SectionLabel / SettingsCard] + 入场动画。
class BilingualSettingsPage extends HookWidget {
  const BilingualSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = useMemoized(() => getIt<BilingualConfig>());

    final String provider = useSignalValue(config.provider.signal) as String;
    final String apiUrl = useSignalValue(config.apiUrl.signal) as String;
    final String apiKey = useSignalValue(config.apiKey.signal) as String;
    final String model = useSignalValue(config.model.signal) as String;
    final String sourceLang =
        useSignalValue(config.sourceLang.signal) as String;
    final String targetLang =
        useSignalValue(config.targetLang.signal) as String;
    final int timeout = useSignalValue(config.timeoutSeconds.signal) as int;

    final testResult = useState<String?>(null);
    final isTesting = useState(false);
    final isTestSuccess = useState<bool?>(null);

    Future<void> onTestConnection() async {
      isTesting.value = true;
      testResult.value = null;
      isTestSuccess.value = null;
      try {
        final service = getIt<BilingualService>();
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
          _ProviderSection(config: config, provider: provider, l10n: l10n),
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
          _TimeoutSection(config: config, timeout: timeout, l10n: l10n),
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
