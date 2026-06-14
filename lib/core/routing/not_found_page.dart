import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';

/// 404 页面
///
/// 当用户导航到不存在的路由时展示的错误页面。
/// 显示未找到的路径并提供一个返回书架的按钮。
class NotFoundPage extends StatelessWidget {
  final String path;

  const NotFoundPage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.warningCircle,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text('未找到页面: $path'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoute.bookshelf.path),
              child: const Text('返回书架'),
            ),
          ],
        ),
      ),
    );
  }
}
