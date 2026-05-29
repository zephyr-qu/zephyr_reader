import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class WebDavStatusDot extends HookWidget {
  final bool isConfigured;
  final bool isTesting;
  final bool? testResult;

  const WebDavStatusDot({
    super.key,
    required this.isConfigured,
    required this.isTesting,
    required this.testResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(() {
      if (isTesting) {
        controller.repeat(reverse: true);
        return controller.stop;
      } else {
        controller.stop();
        return null;
      }
    }, [isTesting]);

    Color color;
    bool pulse;
    String tooltip;

    if (isTesting) {
      color = Colors.amber;
      pulse = true;
      tooltip = '连接测试中…';
    } else if (testResult == true) {
      color = Colors.green;
      pulse = false;
      tooltip = '连接正常';
    } else if (testResult == false) {
      color = Colors.red;
      pulse = false;
      tooltip = '连接失败';
    } else if (isConfigured) {
      color = theme.colorScheme.secondary;
      pulse = false;
      tooltip = '已配置（未测试）';
    } else {
      color = Colors.grey;
      pulse = false;
      tooltip = '未配置';
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final opacity = pulse
              ? (0.4 + 0.6 * (1 - math.cos(controller.value * math.pi)) / 2)
              : 1.0;
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: pulse
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6 * opacity),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }
}
