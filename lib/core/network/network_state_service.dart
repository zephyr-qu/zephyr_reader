/// 网络状态服务
///
/// 使用 system_state 包检测网络连接状态
library;

import 'dart:io';

import 'package:system_state/system_state.dart';

/// 网络状态服务单例
class NetworkStateService {
  static final NetworkStateService _instance =
      NetworkStateService._internal();

  factory NetworkStateService() => _instance;

  NetworkStateService._internal();

  /// 检查是否为 WiFi 网络
  Future<bool> isOnWifi() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final state = await SystemState.wifi.getWifi();
      return state.isConnected;
    } catch (e) {
      // 如果无法获取网络状态，默认返回 false
      return false;
    }
  }

  /// 检查是否有网络连接 (WiFi 或移动数据)
  Future<bool> isConnected() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final wifiState = await SystemState.wifi.getWifi();
      if (wifiState.isConnected) {
        return true;
      }
      final mobileDataState = await SystemState.mobileData.getMobileDataState();
      return mobileDataState.isMobileDataEnabled;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前 WiFi 状态
  Future<WifiState> getWifiState() async {
    if (!Platform.isAndroid) {
      return WifiState.fromMap({
        'isWifiEnabled': false,
        'isConnected': false,
        'connectedWifiName': null,
      });
    }
    try {
      return await SystemState.wifi.getWifi();
    } catch (e) {
      return WifiState.fromMap({
        'isWifiEnabled': false,
        'isConnected': false,
        'connectedWifiName': null,
      });
    }
  }

  /// 监听 WiFi 状态变化
  void listen(void Function(WifiState state) callback) {
    if (!Platform.isAndroid) {
      return;
    }
    SystemState.wifi.listen(callback);
  }
}
