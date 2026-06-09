import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 翻译 API 设置页面。
///
/// 允许用户配置翻译服务提供商、API 地址、密钥等。
/// 支持 OpenAI-compatible 和自定义 API。
class TranslationSettingsPage extends HookWidget {
  const TranslationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = useMemoized(() => getIt<TranslationConfig>());

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

    Future<void> testConnection() async {
      isTesting.value = true;
      testResult.value = null;
      try {
        final service = getIt<TranslationService>();
        await service.translate(
          text: 'Hello, how are you?',
          sourceLang: 'en',
          targetLang: targetLang,
        );
        testResult.value = l10n.translationTestSuccess;
      } catch (e) {
        testResult.value = l10n.translationTestFailed(e.toString());
      } finally {
        isTesting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translationApi),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '翻译 API 说明',
            onPressed: () => _showHelp(context, l10n),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 服务提供商
          SectionLabel(label: l10n.translationProvider),
          SettingsCard(
            children: [
              _buildDropdown(
                context,
                value: provider,
                items: const ['openai', 'custom'],
                labels: const ['OpenAI', l10nCustom],
                onChanged: (v) => config.provider.value = v,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // API 地址
          SectionLabel(label: l10n.translationApiUrl),
          SettingsCard(
            children: [
              _buildTextField(
                controller: useTextEditingController(text: apiUrl),
                hint: 'https://api.openai.com',
                enabled: true,
                obscureText: false,
                onChanged: (v) => config.apiUrl.value = v,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // API Key
          SectionLabel(label: l10n.translationApiKey),
          SettingsCard(
            children: [
              _buildTextField(
                controller: useTextEditingController(text: apiKey),
                hint: 'sk-...',
                enabled: true,
                obscureText: true,
                onChanged: (v) => config.apiKey.value = v,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 模型（仅 OpenAI）
          if (provider == 'openai') ...[
            SectionLabel(label: l10n.translationModel),
            SettingsCard(
              children: [
                _buildTextField(
                  controller: useTextEditingController(text: model),
                  hint: 'gpt-4o-mini',
                  enabled: true,
                  obscureText: false,
                  onChanged: (v) => config.model.value = v,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 源语言
          SectionLabel(label: l10n.translationSourceLang),
          SettingsCard(
            children: [
              _buildDropdown(
                context,
                value: sourceLang,
                items: const ['auto', 'zh', 'en'],
                labels: [l10n.translationAutoDetect, '中文', 'English'],
                onChanged: (v) => config.sourceLang.value = v,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 目标语言
          SectionLabel(label: l10n.translationTargetLang),
          SettingsCard(
            children: [
              _buildDropdown(
                context,
                value: targetLang,
                items: const ['zh', 'en'],
                labels: const ['中文', 'English'],
                onChanged: (v) => config.targetLang.value = v,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 超时
          SectionLabel(label: l10n.translationTimeout),
          SettingsCard(
            children: [
              _buildTextField(
                controller: useTextEditingController(text: timeout.toString()),
                hint: '30',
                enabled: true,
                obscureText: false,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final sec = int.tryParse(v);
                  if (sec != null && sec > 0) {
                    config.timeoutSeconds.value = sec;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 测试连接
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isTesting.value ? null : testConnection,
              icon: isTesting.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate),
              label: Text(l10n.translationTest),
            ),
          ),
          if (testResult.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                testResult.value!,
                style: TextStyle(
                  color: testResult.value == l10n.translationTestSuccess
                      ? Colors.green
                      : Colors.red[400],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: const InputDecoration(border: InputBorder.none),
      items: List.generate(items.length, (i) {
        return DropdownMenuItem(value: items[i], child: Text(labels[i]));
      }),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    required bool obscureText,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  void _showHelp(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('翻译 API 配置说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('支持的翻译服务：'),
              SizedBox(height: 8),
              Text('• OpenAI：兼容任何 OpenAI API 格式的服务'),
              Text('  （包括 Azure OpenAI、本地 LLM 等）'),
              SizedBox(height: 4),
              Text('• 自定义：通用 REST API，需自行拼接请求'),
              SizedBox(height: 12),
              Text('使用提示：'),
              SizedBox(height: 8),
              Text('• 建议使用 gpt-4o-mini，性价比高'),
              Text('• API Key 仅存储在本地设备'),
              Text('• 翻译仅供阅读参考，质量取决于 API'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 占位，避免编译问题；实际从 l10n 取
const l10nCustom = 'Custom';
