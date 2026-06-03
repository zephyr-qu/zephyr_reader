import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:zephyr_reader/core/network/network_state_service.dart';

/// 连接状态横幅
///
/// 在页面顶部显示一个细条，指示当前是否离线。
/// 仅在没有连接时出现，连接恢复后自动消失。
class ConnectivityBanner extends HookWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isOnline = useState<bool>(true);
    final timer = useRef<Timer?>(null);

    useEffect(() {
      _checkConnectivity(isOnline);
      timer.value = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkConnectivity(isOnline);
      });
      return () => timer.value?.cancel();
    }, []);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedCrossFade(
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  '网络不可用',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isOnline.value
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        Expanded(child: child),
      ],
    );
  }

  Future<void> _checkConnectivity(ValueNotifier<bool> isOnline) async {
    final connected = await NetworkStateService().isConnected();
    if (connected != isOnline.value) {
      isOnline.value = connected;
    }
  }
}
