import 'dart:io';

import 'package:system_state/system_state.dart';
import 'package:zephyr_reader/core/utils/platform_guard.dart';

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
