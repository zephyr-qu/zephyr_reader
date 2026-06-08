/// Wi-Fi 状态
class WifiState {
  final bool isConnected;
  final bool isEnabled;
  final String? connectedWifiName;

  const WifiState({
    required this.isConnected,
    required this.isEnabled,
    this.connectedWifiName,
  });

  factory WifiState.fromMap(Map<String, dynamic> map) => WifiState(
    isConnected: map['isConnected'] as bool,
    isEnabled: map['isWifiEnabled'] as bool,
    connectedWifiName: map['connectedWifiName'] as String?,
  );
}

/// 网络状态服务
///
/// 单例模式，提供 Wi-Fi 连接状态和移动数据状态的查询与监听。
/// 注意：当前返回假数据，system_state 插件因 Kotlin 版本不兼容暂不可用。
class NetworkStateService {
  static final NetworkStateService _instance = NetworkStateService._internal();
  static NetworkStateService get instance => _instance;

  NetworkStateService._internal();

  Future<bool> isOnWifi() async => false;

  Future<bool> isConnected() async => false;

  Future<WifiState> getWifiState() async =>
      const WifiState(isConnected: false, isEnabled: false);

  void listen(void Function(WifiState state) callback) {
    // Not supported without system_state plugin
  }
}
