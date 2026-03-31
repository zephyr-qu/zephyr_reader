# SystemState Plugin

A comprehensive Flutter plugin for monitoring and controlling essential device states on Android. Access battery information, volume controls, Wi-Fi connectivity, mobile data status, and Bluetooth functionality—all from a single, easy-to-use interface.

> ⚠️ **Platform Limitation**: This plugin currently supports **Android only**. Attempting to use it on iOS or Web will throw a `PlatformException`. iOS and Web support are planned for future releases.

## Table of Contents

- [Features](#features)
- [Platform Support & Compatibility](#platform-support--compatibility)
- [Installation](#installation)
- [Required Permissions](#required-permissions)
- [Usage](#usage)
  - [Battery Monitoring](#battery-monitoring)
  - [Volume Control](#volume-control)
  - [Wi-Fi Management](#wi-fi-management)
  - [Mobile Data Monitoring](#mobile-data-monitoring)
  - [Bluetooth Management](#bluetooth-management)
  - [Advanced Examples](#advanced-examples)
- [Error Handling](#error-handling)
- [API Reference](#api-reference)
- [Future Roadmap](#future-roadmap)
- [Contributing](#contributing)
- [Resources](#resources)
- [License](#license)

## Features

### 🔋 Battery Monitoring

- Retrieve battery level, temperature, and charging status
- Real-time battery state change notifications
- Monitor battery health and power consumption

### 🔊 Volume Control

- Get current system volume
- Set volume levels programmatically
- Listen to volume changes in real-time

### 📶 Wi-Fi Management

- Check Wi-Fi enabled/connected status
- Retrieve connected network name (SSID)
- Toggle Wi-Fi state
- Real-time Wi-Fi state monitoring

### 📱 Mobile Data Monitoring

- Check mobile data enabled status
- Retrieve SIM operator name
- Get network operator and type (3G, 4G, 5G, etc.)
- Monitor mobile data state changes

### 🔵 Bluetooth Management

- Check Bluetooth enabled status
- Enable/disable Bluetooth programmatically
- Retrieve paired and connected devices
- Real-time Bluetooth state monitoring
- Device connection/disconnection events

## Platform Support & Compatibility

| Feature     | Android | iOS  | Web  |
| ----------- | ------- | ---- | ---- |
| Battery     | ✅       | 🔜    | 🔜    |
| Volume      | ✅       | 🔜    | 🔜    |
| Wi-Fi       | ✅       | 🔜    | 🔜    |
| Mobile Data | ✅       | 🔜    | 🔜    |
| Bluetooth   | ✅       | 🔜    | 🔜    |

### Requirements

- **Flutter**: >=2.5.0
- **Android**: >=5.0 (API 21 - Lollipop)
- **Dart**: >=2.12.0

### Known Issues

- Android 10+ (API 29+): Wi-Fi SSID access requires location services to be enabled
- Android 12+ (API 31+): Additional Bluetooth permissions (`BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`) are required
- Bluetooth device discovery is not yet available in the current version

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  system_state: ^1.3.2
```

Install the package:

```bash
flutter pub get
```

## Required Permissions

Add the necessary permissions to your `android/app/src/main/AndroidManifest.xml`:

### Volume Control

```xml
<!-- Required to modify system audio settings -->
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

### Wi-Fi

```xml
<!-- Required to read Wi-Fi connection state -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- Required to enable/disable Wi-Fi -->
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>

<!-- Required to get Wi-Fi SSID on Android 6.0+ (API 23+) 
     Note: Location services must be enabled on the device -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### Mobile Data

```xml
<!-- Required to check network status and connectivity -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- Required to retrieve SIM operator and network information -->
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
```

### Bluetooth

```xml
<!-- Basic Bluetooth permissions (Android 11 and below) -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>

<!-- Required for Android 12+ (API 31+) to connect and get device info -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>

<!-- Required for device discovery and location-based Bluetooth info -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

## Usage

### Import the Package

```dart
import 'package:system_state/system_state.dart';
```

### Battery Monitoring

```dart
// Get current battery state
Future<void> getBatteryState() async {
  try {
    final state = await SystemState.battery.getBatteryState();
    print("Battery Level: ${state.batteryLevel}%");
    print("Temperature: ${state.temperature}°C");
    print("Is Charging: ${state.isCharging}");
    print("Battery Health: ${state.health}");
  } on PlatformException catch (e) {
    print("Platform Error: ${e.message}");
  } catch (e) {
    print("Error: $e");
  }
}

// Listen to battery changes
void listenBatteryState() {
  SystemState.battery.listen((state) {
    print("Battery Level: ${state.batteryLevel}%");
    if (state.batteryLevel < 20 && !state.isCharging) {
      print("⚠️ Low battery! Consider enabling power saving mode.");
    }
  });
}
```

### Volume Control

```dart
// Get current volume
Future<void> getVolume() async {
  try {
    final volume = await SystemState.volume.getCurrentVolume();
    print("Current Volume: $volume");
  } on PlatformException catch (e) {
    print("Platform Error: ${e.message}");
  }
}

// Set volume (range typically 0-15 on Android)
Future<void> setVolume(int level) async {
  try {
    await SystemState.volume.setVolume(level);
    print("Volume set to: $level");
  } on PlatformException catch (e) {
    print("Failed to set volume: ${e.message}");
  }
}

// Listen to volume changes
void listenVolumeChanges() {
  SystemState.volume.listen((volume) {
    print("Volume changed to: $volume");
  });
}
```

### Wi-Fi Management

```dart
// Get Wi-Fi state
Future<void> getWifiState() async {
  try {
    final state = await SystemState.wifi.getWifiState();
    print("Wi-Fi Enabled: ${state.isWifiEnabled}");
    print("Connected: ${state.isConnected}");
    print("Network Name: ${state.connectedWifiName ?? 'Not connected'}");
  } on PlatformException catch (e) {
    print("Error: ${e.message}");
    if (e.code == 'PERMISSION_DENIED') {
      print("Location permission required to access Wi-Fi SSID");
    }
  }
}

// Toggle Wi-Fi
Future<void> toggleWifi(bool enable) async {
  try {
    await SystemState.wifi.setWifiEnabled(enable);
    print("Wi-Fi ${enable ? 'enabled' : 'disabled'}");
  } on PlatformException catch (e) {
    print("Failed to toggle Wi-Fi: ${e.message}");
  }
}

// Listen to Wi-Fi changes
void listenWifiState() {
  SystemState.wifi.listen((state) {
    print("Wi-Fi Status: ${state.isWifiEnabled ? 'ON' : 'OFF'}");
    if (state.isConnected) {
      print("Connected to: ${state.connectedWifiName}");
    }
  });
}
```

### Mobile Data Monitoring

```dart
// Get mobile data state
Future<void> getMobileDataState() async {
  try {
    final state = await SystemState.mobileData.getMobileDataState();
    print("Mobile Data Enabled: ${state.isMobileDataEnabled}");
    print("SIM Operator: ${state.simOperator ?? 'N/A'}");
    print("Network Operator: ${state.networkOperator ?? 'N/A'}");
    print("Network Type: ${state.networkType}"); // e.g., "4G", "5G"
  } on PlatformException catch (e) {
    print("Error: ${e.message}");
  }
}

// Listen to mobile data changes
void listenMobileDataState() {
  SystemState.mobileData.listen((state) {
    print("Mobile Data: ${state.isMobileDataEnabled ? 'ON' : 'OFF'}");
    print("Connection Type: ${state.networkType}");
  });
}
```

### Bluetooth Management

```dart
// Get Bluetooth state
Future<void> getBluetoothState() async {
  try {
    final state = await SystemState.bluetooth.getBluetoothState();
    print("Bluetooth Enabled: ${state.isBluetoothEnabled}");
    print("Paired Devices: ${state.pairedDevices.length}");
    
    for (var device in state.connectedDevices) {
      print("Connected: ${device.name} (${device.address})");
    }
  } on PlatformException catch (e) {
    print("Error: ${e.message}");
    if (e.code == 'PERMISSION_DENIED') {
      print("Bluetooth permissions required (BLUETOOTH_CONNECT for Android 12+)");
    }
  }
}

// Toggle Bluetooth
Future<void> toggleBluetooth(bool enable) async {
  try {
    await SystemState.bluetooth.setBluetoothEnabled(enable);
    print("Bluetooth ${enable ? 'enabled' : 'disabled'}");
  } on PlatformException catch (e) {
    print("Failed to toggle Bluetooth: ${e.message}");
  }
}

// Listen to Bluetooth changes
void listenBluetoothState() {
  SystemState.bluetooth.listen((state) {
    print("Bluetooth: ${state.isBluetoothEnabled ? 'ON' : 'OFF'}");
    print("Connected Devices: ${state.connectedDevices.length}");
    
    for (var device in state.connectedDevices) {
      print("  - ${device.name}");
    }
  });
}
```

### Advanced Examples

#### Toggle Wi-Fi on Low Battery

```dart
void enablePowerSavingMode() {
  SystemState.battery.listen((batteryState) {
    if (batteryState.batteryLevel < 20 && !batteryState.isCharging) {
      // Disable Wi-Fi to save battery
      SystemState.wifi.setWifiEnabled(false);
      print("🔋 Power saving: Wi-Fi disabled due to low battery");
    } else if (batteryState.batteryLevel > 30 || batteryState.isCharging) {
      // Re-enable Wi-Fi when battery is sufficient
      SystemState.wifi.setWifiEnabled(true);
      print("✅ Battery sufficient: Wi-Fi enabled");
    }
  });
}
```

#### Automatic Volume Adjustment

```dart
void adjustVolumeBasedOnTime() {
  final hour = DateTime.now().hour;
  
  if (hour >= 22 || hour < 7) {
    // Night time: reduce volume
    SystemState.volume.setVolume(3);
    print("🌙 Night mode: Volume reduced");
  } else {
    // Day time: normal volume
    SystemState.volume.setVolume(10);
    print("☀️ Day mode: Volume normalized");
  }
}
```

#### Monitor Network Connectivity

```dart
void monitorConnectivity() {
  SystemState.wifi.listen((wifiState) {
    SystemState.mobileData.listen((mobileState) {
      if (!wifiState.isConnected && !mobileState.isMobileDataEnabled) {
        print("⚠️ No internet connection available");
      } else if (wifiState.isConnected) {
        print("📶 Connected via Wi-Fi: ${wifiState.connectedWifiName}");
      } else if (mobileState.isMobileDataEnabled) {
        print("📱 Connected via Mobile Data: ${mobileState.networkType}");
      }
    });
  });
}
```

## Error Handling

### Common Errors and Solutions

1. **Permission Denied**

   - **Cause**: Required permissions not declared in `AndroidManifest.xml`
   - **Solution**: Add all necessary permissions for the features you're using

2. **Platform Exception**

   - **Cause**: Feature not supported on current platform (iOS/Web)
   - **Solution**: Wrap calls in platform checks:

   ```dart
   if (Platform.isAndroid) {
     final state = await SystemState.wifi.getWifiState();
   }
   ```

3. **Location Services Required**

   - **Cause**: Trying to access Wi-Fi SSID without location services on Android 6.0+
   - **Solution**: Request location permission and ensure location services are enabled

4. **Bluetooth Connection Failed**

   - **Cause**: Missing `BLUETOOTH_CONNECT` permission on Android 12+
   - **Solution**: Add Android 12+ Bluetooth permissions to manifest

### Best Practices

```dart
Future<void> safeGetWifiState() async {
  try {
    final state = await SystemState.wifi.getWifiState();
    // Handle success
  } on PlatformException catch (e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        print("Please grant location permission to access Wi-Fi info");
        break;
      case 'UNSUPPORTED_PLATFORM':
        print("This feature is only available on Android");
        break;
      default:
        print("Error: ${e.message}");
    }
  } catch (e) {
    print("Unexpected error: $e");
  }
}
```

## API Reference

### Battery

- `Battery.getBatteryState()` → `Future<BatteryState>` - Get current battery information
- `Battery.listen(void Function(BatteryState) callback)` → Monitor battery changes

### Volume

- `Volume.getCurrentVolume()` → `Future<int>` - Get current volume level (0-15)
- `Volume.setVolume(int level)` → `Future<void>` - Set volume level
- `Volume.listen(void Function(int) callback)` → Monitor volume changes

### Wi-Fi

- `WiFi.getWifiState()` → `Future<WiFiState>` - Get current Wi-Fi state
- `WiFi.setWifiEnabled(bool enabled)` → `Future<void>` - Toggle Wi-Fi
- `WiFi.listen(void Function(WiFiState) callback)` → Monitor Wi-Fi state changes

### Mobile Data

- `MobileData.getMobileDataState()` → `Future<MobileDataState>` - Get mobile data state and network info
- `MobileData.listen(void Function(MobileDataState) callback)` → Monitor mobile data changes

### Bluetooth

- `Bluetooth.getBluetoothState()` → `Future<BluetoothState>` - Get Bluetooth state and device list
- `Bluetooth.setBluetoothEnabled(bool enabled)` → `Future<void>` - Toggle Bluetooth
- `Bluetooth.listen(void Function(BluetoothState) callback)` → Monitor Bluetooth state changes

### Data Models

```dart
class BatteryState {
  final int batteryLevel;        // 0-100
  final double temperature;      // in Celsius
  final bool isCharging;
  final String health;           // "good", "overheat", etc.
}

class WiFiState {
  final bool isWifiEnabled;
  final bool isConnected;
  final String? connectedWifiName; // SSID
}

class MobileDataState {
  final bool isMobileDataEnabled;
  final String? simOperator;
  final String? networkOperator;
  final String networkType;      // "3G", "4G", "5G", etc.
}

class BluetoothState {
  final bool isBluetoothEnabled;
  final List<BluetoothDevice> pairedDevices;
  final List<BluetoothDevice> connectedDevices;
}

class BluetoothDevice {
  final String name;
  final String address;          // MAC address
  final bool isConnected;
}
```

## Future Roadmap

- 🛫 **Airplane Mode**: Check and toggle airplane mode status
- 🍎 **iOS Support**: Implementation using CoreBluetooth and iOS-specific APIs for battery, volume, and connectivity features
- 🌐 **Web Support**: Browser-based controls using Web Bluetooth API and Web Audio API
- 🔍 **Device Discovery**: Scan for and list nearby Bluetooth devices with automatic pairing capabilities
- 📍 **Location Services**: Enhanced location-based features and geofencing support
- 🎯 **Additional Controls**: NFC state management, mobile hotspot control, and cellular signal strength monitoring
- 🔔 **Do Not Disturb**: Monitor and control Do Not Disturb mode
- 🌙 **Dark Mode**: Detect and monitor system dark mode changes

**Coming in v2.0:**

- Device discovery will enable automatic scanning for nearby Bluetooth devices with filtering options
- iOS support will bring feature parity across platforms
- Enhanced error handling with more descriptive exception types

## Contributing

We welcome contributions from the community! Here's how you can help:

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/your-repo/system_state/issues)
2. Create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Device and Android version
   - Code samples if applicable

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request with a clear description

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Add tests for new features
- Update documentation for API changes

### Development Setup

```bash
# Clone the repository
git clone https://github.com/your-repo/system_state.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run example app
cd example
flutter run
```

## Resources

### Official Documentation

- [Flutter Plugin Development](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Android API Documentation](https://developer.android.com/reference)

### Android-Specific Resources

- [Android Wi-Fi API](https://developer.android.com/reference/android/net/wifi/WifiManager)
- [Android Bluetooth API](https://developer.android.com/guide/topics/connectivity/bluetooth)
- [Android Battery Manager](https://developer.android.com/reference/android/os/BatteryManager)
- [Android Audio Manager](https://developer.android.com/reference/android/media/AudioManager)
- [Android Telephony Manager](https://developer.android.com/reference/android/telephony/TelephonyManager)

### Support & Community

- [GitHub Issues](https://github.com/your-repo/system_state/issues) - Bug reports and feature requests
- [API Documentation](https://pub.dev/documentation/system_state/latest/) - Complete API reference
- [Example App](https://github.com/your-repo/system_state/tree/main/example) - Working examples

## License

This project is licensed under the [MIT License](LICENSE).

```
MIT License

Copyright (c) 2026 Shamil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

**Maintained by**: Shamil
**Version**: 1.3.2  
**Last Updated**: February 2026
**Package**: [pub.dev/packages/system_state](https://pub.dev/packages/system_state)
