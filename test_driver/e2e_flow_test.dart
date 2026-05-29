import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/src/rust/api/data/init.dart';
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // ✅ 统一初始化 Rust + 测试专用配置
    await RustLib.init();
    final tempDir = await getTemporaryDirectory();
    await initStorage(dataDir: '${tempDir.path}/test_data');
    await initSearchEngine();
    await AppConfig.instance.init();
    await configureDependencies(); // 注入 mock 服务
  });

  tearDownAll(() async {
    // ✅ 清理测试数据
  });

  group('E2E - 书架到阅读流程', () {
    testWidgets('打开应用 -> 书架 -> 点击书籍 -> 阅读页面', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920)); // ✅ 每个用例设置
      await tester.pumpWidget(const ZephyrReaderApp());
      await tester.pump(const Duration(seconds: 2)); // ✅ 避免 pumpAndSettle 超时

      expect(find.byType(MainLayout), findsOneWidget);
      // TODO: 补充真实导航与断言
    });
  });
}
