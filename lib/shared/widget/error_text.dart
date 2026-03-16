import 'package:flutter/material.dart';

/// 标准错误文本显示组件
class ErrorText extends StatelessWidget {
  const ErrorText({super.key, required this.error, this.onRetry});

  /// 错误信息
  final Object error;

  /// 重试回调
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            error.toString(),
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
