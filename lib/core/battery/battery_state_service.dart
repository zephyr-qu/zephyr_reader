/// 电池状态
class BatteryState {
  final int batteryLevel;
  final int temperature;
  final bool isCharging;

  const BatteryState({
    required this.batteryLevel,
    required this.temperature,
    required this.isCharging,
  });

  factory BatteryState.fromMap(Map<String, dynamic> map) => BatteryState(
    batteryLevel: map['level'] as int,
    temperature: map['temperature'] as int,
    isCharging: map['isCharging'] as bool,
  );
}

/// 电池状态服务
///
/// 单例模式，提供设备充电状态和电量的查询与监听。
/// 注意：当前返回假数据，system_state 插件因 Kotlin 版本不兼容暂不可用。
class BatteryStateService {
  static final BatteryStateService _instance = BatteryStateService._internal();
  static BatteryStateService get instance => _instance;

  BatteryStateService._internal();

  Future<bool> isCharging() async => false;

  Future<int> getBatteryLevel() async => 0;

  Future<BatteryState> getBatteryState() async =>
      const BatteryState(batteryLevel: 0, temperature: 0, isCharging: false);

  void listen(void Function(BatteryState state) callback) {
    // Not supported without system_state plugin
  }
}
