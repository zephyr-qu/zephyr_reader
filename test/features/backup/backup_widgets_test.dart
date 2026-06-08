import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zephyr_reader/features/backup/application/backup_view_model.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_action_tile.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_status_card.dart';
import 'package:zephyr_reader/features/backup/page/widgets/restore_confirm_dialog.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// Create a real BackupViewModel with mocked SharedPreferences, then set
/// signal values directly. The optional [BackupApi] param defaults to the
/// real Rust FFI — but we never call API methods in these widget tests.
Future<BackupViewModel> _createVm({
  BackupStatus status = BackupStatus.idle,
  DateTime? lastBackupAt,
  BackupStats? stats,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final vm = BackupViewModel(prefs);
  vm.status.value = status;
  vm.lastBackupAt.value = lastBackupAt;
  vm.currentStats.value = AsyncState.data(stats);
  return vm;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupActionTile', () {
    testWidgets('渲染标题、副标题、图标，触发 onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrapWithApp(
          BackupActionTile(
            icon: PhosphorIconsRegular.download,
            iconBackground: Colors.blue,
            iconColor: Colors.white,
            title: '导出备份',
            subtitle: '从未备份',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('导出备份'), findsOneWidget);
      expect(find.text('从未备份'), findsOneWidget);

      await tester.tap(find.text('导出备份'));
      expect(tapped, isTrue);
    });
  });

  group('BackupStatusCard', () {
    testWidgets('idle + 有备份 → 云勾图标 + 备份时间', (tester) async {
      final vm = await _createVm(
        lastBackupAt: DateTime.now(),
        stats: const BackupStats(
          books: 3,
          chapters: 10,
          notes: 5,
          bookmarks: 0,
          readingSessions: 0,
          readingProgress: 0,
          vocabularyWords: 0,
          categories: 0,
        ),
      );

      await tester.pumpWidget(_wrapWithApp(BackupStatusCard(vm: vm)));
      await tester.pumpAndSettle();

      expect(find.textContaining('上次备份'), findsOneWidget);
      expect(find.textContaining('本书'), findsOneWidget);
    });

    testWidgets('idle + 无备份 → 从未备份', (tester) async {
      final vm = await _createVm();

      await tester.pumpWidget(_wrapWithApp(BackupStatusCard(vm: vm)));
      await tester.pumpAndSettle();

      expect(find.text('尚未进行过备份'), findsOneWidget);
    });

    testWidgets('exporting → 正在备份', (tester) async {
      final vm = await _createVm(status: BackupStatus.exporting);

      await tester.pumpWidget(_wrapWithApp(BackupStatusCard(vm: vm)));
      await tester.pumpAndSettle();

      expect(find.text('备份中…'), findsOneWidget);
    });

    testWidgets('restoring → 正在还原', (tester) async {
      final vm = await _createVm(status: BackupStatus.restoring);

      await tester.pumpWidget(_wrapWithApp(BackupStatusCard(vm: vm)));
      await tester.pumpAndSettle();

      expect(find.text('恢复中…'), findsOneWidget);
    });

    testWidgets('error → 操作失败消息', (tester) async {
      final vm = await _createVm(status: BackupStatus.error);
      vm.errorMessage.value = 'IO 错误';

      await tester.pumpWidget(_wrapWithApp(BackupStatusCard(vm: vm)));
      await tester.pumpAndSettle();

      expect(find.text('操作失败：IO 错误'), findsOneWidget);
    });
  });

  group('RestoreConfirmDialog', () {
    testWidgets('显示还原确认信息', (tester) async {
      final manifest = const BackupManifest(
        appVersion: '1.2.0',
        exportedAt: 1000000,
        dbSize: 4096,
        stats: BackupStats(
          books: 5,
          chapters: 20,
          notes: 10,
          bookmarks: 50,
          readingSessions: 15,
          readingProgress: 100,
          vocabularyWords: 200,
          categories: 3,
        ),
      );

      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showRestoreConfirmDialog(context, manifest),
                child: const Text('打开'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('确认还原'), findsWidgets);
      expect(find.textContaining('1.2.0'), findsOneWidget);
    });
  });
}
