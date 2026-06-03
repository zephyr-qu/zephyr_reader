

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/network/wifi_transfer_service.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';

class WifiTransferPage extends HookWidget {
  const WifiTransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = useMemoized(() => getIt<WifiTransferService>());
    final isRunning = useState(false);
    final logs = useState<List<TransferLogEntry>>([]);
    final logsRef = useRef<ScrollController>(ScrollController());

    useEffect(() {
      final subs = <StreamSubscription<dynamic>>[
        service.statusStream.listen((running) {
          isRunning.value = running;
        }),
        service.logStream.listen((entry) {
          logs.value = [entry, ...logs.value];
        }),
      ];
      return () {
        for (final s in subs) {
          s.cancel();
        }
        logsRef.value.dispose();
      };
    }, []);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi 传书'),
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
            tooltip: isRunning.value ? '停止服务器' : '启动服务器',
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
                  showInfoSnack(context, '链接已复制到剪贴板');
                }
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            '传输记录',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (logs.value.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      PhosphorIconsRegular.wifiSlash,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isRunning.value ? '等待文件上传…' : '启动服务器开始传输',
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? Colors.green.withValues(alpha: 0.3)
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
                  color: isRunning ? Colors.green : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isRunning ? '服务器运行中' : '服务器已停止',
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
                  const Icon(
                    PhosphorIconsRegular.link,
                    size: 20,
                    color: Colors.green,
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
                    icon: const Icon(PhosphorIconsRegular.copySimple, size: 20),
                    onPressed: onCopyUrl,
                    tooltip: '复制链接',
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
                label: const Text('停止服务器'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[300],
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(PhosphorIconsRegular.playCircle),
                label: const Text('启动服务器'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '连接与电脑相同的 Wi-Fi 网络，在浏览器中打开上方地址即可传输文件。',
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  Text(entry.message, style: const TextStyle(fontSize: 13)),
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
