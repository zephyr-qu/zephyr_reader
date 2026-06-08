import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/features/sync/application/services/sync_models.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_config_service.dart';
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 显示 WebDAV 配置对话框。
///
/// 允许用户输入/编辑服务器地址、用户名、密码和远程路径。
Future<void> showWebDavConfigDialog(
  BuildContext context,
  StorageSyncViewModel viewModel,
) async {
  final config = await viewModel.getConfig();
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;

  final serverController = TextEditingController(text: config?.baseUrl ?? '');
  final usernameController = TextEditingController(
    text: config?.username ?? '',
  );
  final passwordController = TextEditingController(
    text: config?.password ?? '',
  );
  final remotePathController = TextEditingController(
    text: config?.remotePath ?? '/zephyr_reader',
  );
  var selectedPreset = null as WebDavPreset?;
  final formKey = GlobalKey<FormState>();

  if (!context.mounted) return;

  await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(l10n.webdavConfig),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectPreset,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: WebDavConfigService.getPresets().map((preset) {
                    final isSelected = selectedPreset?.name == preset.name;
                    return ChoiceChip(
                      label: Text(preset.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedPreset = preset;
                            if (preset.baseUrl.isNotEmpty) {
                              serverController.text = preset.baseUrl;
                            }
                            remotePathController.text = preset.remotePath;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: serverController,
                  decoration: InputDecoration(
                    labelText: l10n.serverUrl,
                    hintText: 'https://dav.jianguoyun.com/dav',
                    prefixIcon: const Icon(PhosphorIconsRegular.cloud),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.serverUrlRequired;
                    }
                    if (!value.startsWith('http://') &&
                        !value.startsWith('https://')) {
                      return l10n.serverUrlInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    prefixIcon: const Icon(PhosphorIconsRegular.user),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.usernameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remotePathController,
                  decoration: InputDecoration(
                    labelText: l10n.remotePath,
                    hintText: '/zephyr_reader',
                    prefixIcon: const Icon(PhosphorIconsRegular.folder),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.remotePathRequired;
                    }
                    if (!value.startsWith('/')) {
                      return l10n.remotePathInvalid;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          if (config != null)
            TextButton(
              onPressed: () async {
                await viewModel.clearConfig();
                if (!context.mounted) return;
                Navigator.of(context).pop(false);
                if (!context.mounted) return;
                showInfoSnack(context, l10n.configCleared);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.clearConfig),
            ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await viewModel.saveConfig(
                  WebDavConfig(
                    baseUrl: serverController.text,
                    username: usernameController.text,
                    password: passwordController.text,
                    remotePath: remotePathController.text,
                  ),
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
                if (!context.mounted) return;
                showSuccessSnack(context, l10n.configSaved);
              } catch (_) {
                if (!context.mounted) return;
                showErrorSnack(context, l10n.saveConfigFailed);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );

  serverController.dispose();
  usernameController.dispose();
  passwordController.dispose();
  remotePathController.dispose();
}
