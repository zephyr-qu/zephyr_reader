import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/battery/battery_state_service.dart';

/// 阅读页右下角电量和阅读进度指示器。
///
/// 显示当前阅读进度百分比 + 电量百分比 + 充电状态图标。
/// 每 60 秒刷新一次，非 Android 平台隐藏。
class BatteryIndicator extends HookWidget {
  final String progressText;

  const BatteryIndicator({super.key, this.progressText = ''});

  @override
  Widget build(BuildContext context) {
    final level = useState<int>(100);
    final isCharging = useState<bool>(false);
    final supported = useState<bool>(true);

    useEffect(() {
      _update(level, isCharging, supported);
      final timer = Timer.periodic(const Duration(seconds: 60), (_) {
        _update(level, isCharging, supported);
      });
      return timer.cancel;
    }, []);

    if (!supported.value) return const SizedBox.shrink();

    final batteryColor = isCharging.value
        ? const Color(0xFF4CAF50)
        : level.value > 20
            ? Colors.white.withValues(alpha: 0.7)
            : const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progressText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                progressText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text(
            '${level.value}%',
            style: TextStyle(
              color: batteryColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            isCharging.value
                ? PhosphorIconsRegular.lightning
                : PhosphorIconsRegular.batteryFull,
            size: 14,
            color: batteryColor,
          ),
        ],
      ),
    );
  }

  Future<void> _update(
    ValueNotifier<int> level,
    ValueNotifier<bool> isCharging,
    ValueNotifier<bool> supported,
  ) async {
    try {
      final state = await BatteryStateService.instance.getBatteryState();
      level.value = state.batteryLevel;
      isCharging.value = state.isCharging;
    } catch (_) {
      supported.value = false;
    }
  }
}
