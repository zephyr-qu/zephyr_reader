import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/network/wifi_transfer_service.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// WiFi 传书页面。
///
/// 通过局域网 HTTP 服务从电脑端上传书籍文件到应用。
/// 使用 [WifiTransferService] 管理 HTTP 服务。
class WifiTransferPage extends HookWidget {
  const WifiTransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = useMemoized(() => getIt<WifiTransferService>());
    final isRunning = useSignal(service.isRunning);
    final logs = useSignal<List<TransferLogEntry>>([]);
    final scrollCtrl = useMemoized(() => ScrollController());

    useEffect(() {
      final subs = <StreamSubscription<dynamic>>[
        service.statusStream.listen((running) {
          isRunning.value = running;
        }),
        service.logStream.listen((entry) {
          final updated = [entry, ...logs.value];
          if (updated.length > 200) updated.length = 200;
          logs.value = updated;
        }),
      ];
      return () {
        for (final s in subs) {
          s.cancel();
        }
        scrollCtrl.dispose();
      };
    }, []);

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wifiPageTitle),
        actions: [
          IconButton(
            icon: Icon(
              isRunning.value
                  ? PhosphorIconsFill.stopCircle
                  : PhosphorIconsFill.playCircle,
              color: isRunning.value ? Colors.green : colorScheme.primary,
            ),
            onPressed: () async {
              if (isRunning.value) {
                await service.stop();
              } else {
                await service.start();
              }
            },
            tooltip: isRunning.value
                ? l10n.wifiStopServer
                : l10n.wifiStartServer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ServerCard(
            isRunning: isRunning.value,
            url: service.url,
            onStart: () => service.start(),
            onStop: () => service.stop(),
            onCopyUrl: () {
              if (service.url.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: service.url));
                if (context.mounted) {
                  showInfoSnack(context, l10n.wifiLinkCopied);
                }
              }
            },
          ),
          const SizedBox(height: 24),
          SectionLabel(label: l10n.wifiTransferLog),
          if (logs.value.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      PhosphorIconsRegular.wifiSlash,
                      size: IconSize.hero,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isRunning.value
                          ? l10n.wifiWaitUpload
                          : l10n.wifiStartServerPrompt,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            ...logs.value.map((entry) => _LogItem(entry: entry)),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final bool isRunning;
  final String url;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCopyUrl;

  const _ServerCard({
    required this.isRunning,
    required this.url,
    required this.onStart,
    required this.onStop,
    required this.onCopyUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? (theme.brightness == Brightness.dark
                        ? Colors.green[300]!
                        : Colors.green)
                    .withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning
                      ? (theme.brightness == Brightness.dark
                            ? Colors.green[300]!
                            : Colors.green)
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isRunning ? l10n.wifiServerRunning : l10n.wifiServerStopped,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isRunning) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.link,
                    size: IconSize.leading,
                    color: theme.brightness == Brightness.dark
                        ? Colors.green[300]!
                        : Colors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      url,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      PhosphorIconsRegular.copySimple,
                      size: IconSize.leading,
                    ),
                    onPressed: onCopyUrl,
                    tooltip: l10n.wifiCopyLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(PhosphorIconsRegular.stopCircle),
                label: Text(l10n.wifiStopServer),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.brightness == Brightness.dark
                      ? Colors.red[200]
                      : Colors.red[300],
                  side: BorderSide(
                    color:
                        (theme.brightness == Brightness.dark
                                ? Colors.red[200]
                                : Colors.red[300])!
                            .withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(PhosphorIconsRegular.playCircle),
                label: Text(l10n.wifiStartServer),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.wifiInstruction,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final TransferLogEntry entry;

  const _LogItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: entry.isError
              ? Colors.red.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              entry.isError
                  ? PhosphorIconsRegular.warningCircle
                  : entry.fileName != null
                  ? PhosphorIconsRegular.fileArrowUp
                  : PhosphorIconsRegular.info,
              size: 18,
              color: entry.isError ? Colors.red[300] : Colors.green[300],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.message,
                    style: theme.textTheme.labelLarge?.copyWith(),
                  ),
                  if (entry.fileName != null)
                    Text(
                      entry.fileName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              entry.formattedTime,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
