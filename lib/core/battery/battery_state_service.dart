import 'package:battery_plus/battery_plus.dart' as battery_plus;

/// 电池状态
class BatteryState {
  final int batteryLevel;
  final bool isCharging;

  const BatteryState({
    required this.batteryLevel,
    required this.isCharging,
  });
}

/// 电池状态服务
///
/// 基于 battery_plus 插件，提供设备电量与充电状态的查询和监听。
class BatteryStateService {
  static final BatteryStateService _instance = BatteryStateService._internal();
  static BatteryStateService get instance => _instance;

  final battery_plus.Battery _battery = battery_plus.Battery();

  BatteryStateService._internal();

  Future<bool> isCharging() async {
    final state = await _battery.batteryState;
    return state == battery_plus.BatteryState.charging ||
        state == battery_plus.BatteryState.full;
  }

  Future<int> getBatteryLevel() => _battery.batteryLevel;

  Future<BatteryState> getBatteryState() async {
    final results = await Future.wait([
      _battery.batteryLevel,
      _battery.batteryState,
    ]);
    final level = results[0] as int;
    final state = results[1] as battery_plus.BatteryState;
    return BatteryState(
      batteryLevel: level,
      isCharging: state == battery_plus.BatteryState.charging ||
          state == battery_plus.BatteryState.full,
    );
  }

  /// 监听电池充电状态变化（不包含电量值变化）
  void listen(void Function(BatteryState state) callback) {
    _battery.onBatteryStateChanged.listen((state) {
      callback(BatteryState(
        batteryLevel: 0, // 流事件不含当前电量，需额外查询
        isCharging: state == battery_plus.BatteryState.charging ||
            state == battery_plus.BatteryState.full,
      ));
    });
  }
}
