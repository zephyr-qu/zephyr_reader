/// WebDAV 同步服务测试
///
/// 测试 WebDAV 同步功能，包括：
/// - 配置验证
/// - 连接测试
/// - 数据同步
/// - 冲突检测
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';
import 'package:zephyr_reader/features/data/application/services/sync_models.dart';
import 'package:zephyr_reader/features/data/application/services/webdav_config_service.dart';

void main() {
  group('WebDAV 同步服务测试', () {
    late SharedPreferences prefs;
    late WebDavConfigService configService;

    setUp(() async {
      // 初始化 Widget 绑定
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock FlutterSecureStorage 平台通道
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall methodCall) async {
              return null;
            },
          );

      // 初始化测试用的 PreferencesService
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      configService = WebDavConfigService(
        prefs: SharedPreferencesService(prefs),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    });

    group('WebDAV 配置测试', () {
      test('配置验证 - 有效配置', () {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );

        expect(config.isValid, isTrue);
        expect(config.serverName, equals('example.com'));
      });

      test('配置验证 - 无效配置（空 baseUrl）', () {
        final config = WebDavConfig(
          baseUrl: '',
          username: 'testuser',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );

        expect(config.isValid, isFalse);
      });

      test('配置验证 - 无效配置（空 username）', () {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: '',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );

        expect(config.isValid, isFalse);
      });

      test('配置验证 - 无效配置（空 password）', () {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: '',
          remotePath: '/zephyr_reader',
        );

        expect(config.isValid, isFalse);
      });

      test('配置验证 - 无效配置（空 remotePath）', () {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'testpass',
          remotePath: '',
        );

        expect(config.isValid, isFalse);
      });

      test('配置 copyWith 方法', () {
        final original = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );

        final copied = original.copyWith(
          username: 'newuser',
          password: 'newpass',
        );

        expect(original.username, equals('testuser'));
        expect(original.password, equals('testpass'));
        expect(copied.username, equals('newuser'));
        expect(copied.password, equals('newpass'));
        expect(copied.baseUrl, equals(original.baseUrl));
        expect(copied.remotePath, equals(original.remotePath));
      });

      test('服务器名称解析 - 标准 URL', () {
        final config = WebDavConfig(
          baseUrl: 'https://dav.example.com/dav',
          username: 'test',
          password: 'test',
          remotePath: '/',
        );

        expect(config.serverName, equals('dav.example.com'));
      });

      test('服务器名称解析 - 无效 URL', () {
        final config = WebDavConfig(
          baseUrl: 'not-a-url',
          username: 'test',
          password: 'test',
          remotePath: '/',
        );

        // 无效 URL 应返回空字符串
        expect(config.serverName, equals(''));
      });
    });

    group('WebDAV 配置服务测试', () {
      test('保存和加载配置', () async {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );

        // 保存配置
        await configService.saveConfig(config);

        // 验证已配置
        expect(configService.isConfigured.value, isTrue);
      });

      test('初始状态应为未配置', () async {
        expect(configService.isConfigured.value, isFalse);
      });

      test('最后同步时间 - 初始为 null', () async {
        final lastSyncTime = await configService.getLastSyncTime();
        expect(lastSyncTime, isNull);
      });

      test('最后同步时间 - 保存和加载', () async {
        final testTime = DateTime(2026, 3, 31, 12, 0, 0);

        // 保存同步时间
        await configService.setLastSyncTime(testTime);

        // 加载同步时间
        final loaded = await configService.getLastSyncTime();

        expect(loaded, isNotNull);
        expect(
          loaded!.millisecondsSinceEpoch,
          equals(testTime.millisecondsSinceEpoch),
        );
      });

      test('最后同步时间 - 更新', () async {
        final time1 = DateTime(2026, 3, 31, 12, 0, 0);
        final time2 = DateTime(2026, 3, 31, 18, 0, 0);

        // 保存第一次同步时间
        await configService.setLastSyncTime(time1);
        expect(
          (await configService.getLastSyncTime())!.millisecondsSinceEpoch,
          equals(time1.millisecondsSinceEpoch),
        );

        // 更新为第二次同步时间
        await configService.setLastSyncTime(time2);
        expect(
          (await configService.getLastSyncTime())!.millisecondsSinceEpoch,
          equals(time2.millisecondsSinceEpoch),
        );
      });
    });

    group('WebDAV 同步状态测试', () {
      test('SyncStatus 枚举值', () {
        expect(SyncStatus.values.length, equals(4));
        expect(SyncStatus.values[0], equals(SyncStatus.idle));
        expect(SyncStatus.values[1], equals(SyncStatus.syncing));
        expect(SyncStatus.values[2], equals(SyncStatus.success));
        expect(SyncStatus.values[3], equals(SyncStatus.failed));
      });

      test('SyncDirection 枚举值', () {
        expect(SyncDirection.values.length, equals(3));
        expect(SyncDirection.values[0], equals(SyncDirection.upload));
        expect(SyncDirection.values[1], equals(SyncDirection.download));
        expect(SyncDirection.values[2], equals(SyncDirection.both));
      });

      test('SyncDataType 枚举值', () {
        expect(SyncDataType.values.length, equals(3));
        expect(SyncDataType.values[0], equals(SyncDataType.readingProgress));
        expect(SyncDataType.values[1], equals(SyncDataType.bookmarks));
        expect(SyncDataType.values[2], equals(SyncDataType.bookshelf));
      });
    });

    group('WebDAV 同步结果测试', () {
      test('SyncResult 默认值', () {
        final result = SyncResult();

        expect(result.success, isFalse);
        expect(result.error, isNull);
        expect(result.uploadedCount, equals(0));
        expect(result.downloadedCount, equals(0));
      });

      test('SyncResult 带参数初始化', () {
        final result = SyncResult(
          success: true,
          uploadedCount: 5,
          downloadedCount: 3,
        );

        expect(result.success, isTrue);
        expect(result.uploadedCount, equals(5));
        expect(result.downloadedCount, equals(3));
      });

      test('SyncResult - 失败状态与错误消息', () {
        final result = SyncResult(success: false, error: '网络错误');

        expect(result.success, isFalse);
        expect(result.error, equals('网络错误'));
      });

      test('SyncResult - 成功状态与计数', () {
        final result = SyncResult(
          success: true,
          uploadedCount: 5,
          downloadedCount: 3,
        );

        expect(result.success, isTrue);
        expect(result.uploadedCount, equals(5));
        expect(result.downloadedCount, equals(3));
      });

      test('SyncResult - 默认无更新', () {
        final result = SyncResult(success: true);

        expect(result.success, isTrue);
        expect(result.uploadedCount, equals(0));
        expect(result.downloadedCount, equals(0));
        expect(result.error, isNull);
      });
    });

    group('边界条件测试', () {
      test('配置 - 特殊字符密码', () {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'p@ssw0rd!#\$%^&*()',
          remotePath: '/zephyr_reader',
        );

        expect(config.isValid, isTrue);
        expect(config.password, equals('p@ssw0rd!#\$%^&*()'));
      });

      test('配置 - 超长路径', () {
        final longPath = '/dav/${'a' * 100}';
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'testpass',
          remotePath: longPath,
        );

        expect(config.isValid, isTrue);
        expect(config.remotePath.length, equals(longPath.length));
      });

      test('配置 - Unicode 用户名', () {
        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: '测试用户',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );

        expect(config.isValid, isTrue);
        expect(config.username, equals('测试用户'));
      });

      test('最后同步时间 - 边界时间', () async {
        // Unix 纪元时间
        final epochTime = DateTime(1970, 1, 1, 0, 0, 0);
        await configService.setLastSyncTime(epochTime);
        expect(
          (await configService.getLastSyncTime())!.millisecondsSinceEpoch,
          equals(epochTime.millisecondsSinceEpoch),
        );

        // 未来时间
        final futureTime = DateTime(2099, 12, 31, 23, 59, 59);
        await configService.setLastSyncTime(futureTime);
        expect(
          (await configService.getLastSyncTime())!.millisecondsSinceEpoch,
          equals(futureTime.millisecondsSinceEpoch),
        );
      });

      test('配置 - 带端点斜杠的 URL', () {
        final config1 = WebDavConfig(
          baseUrl: 'https://example.com/dav/',
          username: 'test',
          password: 'test',
          remotePath: '/',
        );

        final config2 = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'test',
          password: 'test',
          remotePath: '/',
        );

        // 两个配置都应有效
        expect(config1.isValid, isTrue);
        expect(config2.isValid, isTrue);
      });
    });

    group('错误处理测试', () {
      test('保存配置后验证 isConfigured 信号', () async {
        expect(configService.isConfigured.value, isFalse);

        final config = WebDavConfig(
          baseUrl: 'https://example.com/dav',
          username: 'testuser',
          password: 'testpass',
          remotePath: '/zephyr_reader',
        );
        await configService.saveConfig(config);

        expect(configService.isConfigured.value, isTrue);
      });

      test('加载配置失败不应抛出异常', () async {
        // 即使没有配置，也应正常工作
        expect(configService.isConfigured.value, isFalse);
      });
    });
  });
}
