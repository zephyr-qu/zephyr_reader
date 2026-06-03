import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/features/sync/application/services/sync_models.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_config_service.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';

Future<void> showWebDavConfigDialog(
  BuildContext context,
  WebDavConfigHost host,
) async {
  final config = await host.getConfig();

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

  if (!context.mounted) return;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('配置 WebDAV'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择预设', style: TextStyle(fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'https://dav.jianguoyun.com/dav',
                  prefixIcon: Icon(PhosphorIconsRegular.cloud),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入服务器地址';
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return '请输入完整的 URL（包含 http:// 或 https://）';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: '用户',
                  prefixIcon: Icon(PhosphorIconsRegular.user),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入用户名';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(PhosphorIconsRegular.lockSimple),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入密码';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: remotePathController,
                decoration: const InputDecoration(
                  labelText: '远程目录',
                  hintText: '/zephyr_reader',
                  prefixIcon: Icon(PhosphorIconsRegular.folder),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入远程目录';
                  if (!value.startsWith('/')) return '远程目录应以 / 开头';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          if (config != null)
            TextButton(
              onPressed: () async {
                await host.clearConfig();
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
                if (!context.mounted) return;
                showInfoSnack(context, '配置已清除');
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('清除配置'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );

  if (result == true) {
    final serverValid =
        serverController.text.isNotEmpty &&
        (serverController.text.startsWith('http://') ||
            serverController.text.startsWith('https://'));
    final usernameValid = usernameController.text.isNotEmpty;
    final passwordValid = passwordController.text.isNotEmpty;
    final remotePathValid =
        remotePathController.text.isNotEmpty &&
        remotePathController.text.startsWith('/');

    if (!serverValid || !usernameValid || !passwordValid || !remotePathValid) {
      if (!context.mounted) return;
      showErrorSnack(context, '请填写完整的配置信息');
      return;
    }

    try {
      await host.saveConfig(
        WebDavConfig(
          baseUrl: serverController.text,
          username: usernameController.text,
          password: passwordController.text,
          remotePath: remotePathController.text,
        ),
      );
      if (!context.mounted) return;
      showSuccessSnack(context, 'WebDAV 配置已保存');
    } catch (_) {
      if (!context.mounted) return;
      showErrorSnack(context, '保存配置失败');
    }
  }

  serverController.dispose();
  usernameController.dispose();
  passwordController.dispose();
  remotePathController.dispose();
}
