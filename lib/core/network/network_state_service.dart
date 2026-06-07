import 'dart:io';

import 'package:system_state/system_state.dart';
import 'package:zephyr_reader/core/utils/platform_guard.dart';

/// 网络状态服务
///
/// 单例模式，提供 Wi-Fi 连接状态和移动数据状态的查询与监听。
/// 使用 [SystemState] 获取底层网络信息，非 Android 平台返回默认值。
class NetworkStateService {

  static final NetworkStateService _instance = NetworkStateService._internal();
  static NetworkStateService get instance => _instance;

  NetworkStateService._internal();

  Future<bool> isOnWifi() async => guardAndroid(
    () async => (await SystemState.wifi.getWifi()).isConnected,
    false,
  );

  Future<bool> isConnected() async => guardAndroid(() async {
    final wifiState = await SystemState.wifi.getWifi();
    if (wifiState.isConnected) return true;
    final mobileDataState = await SystemState.mobileData.getMobileDataState();
    return mobileDataState.isMobileDataEnabled;
  }, false);

  Future<WifiState> getWifiState() async => guardAndroid(
    () async => SystemState.wifi.getWifi(),
    WifiState.fromMap({
      'isWifiEnabled': false,
      'isConnected': false,
      'connectedWifiName': null,
    }),
  );

  void listen(void Function(WifiState state) callback) {
    if (!Platform.isAndroid) return;
    SystemState.wifi.listen(callback);
  }
}
