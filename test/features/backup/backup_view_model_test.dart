import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart';

// ===== Mocks =====

class _MockSharedPreferences extends Mock implements SharedPreferences {
  _MockSharedPreferences() {
    when(() => getInt(any())).thenReturn(null);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
  }
}

void main() {
  late _MockSharedPreferences mockPrefs;
  late BackupViewModel vm;

  setUp(() {
    mockPrefs = _MockSharedPreferences();
    vm = BackupViewModel(mockPrefs);
  });

  group('initial state', () {
    test('starts idle with null error', () {
      expect(vm.status.value, BackupStatus.idle);
      expect(vm.errorMessage.value, isNull);
      expect(vm.lastBackupAt.value, isNull);
      expect(vm.lastBackupSize.value, 0);
    });
  });

  group('initialize()', () {
    test('keeps null when no backup recorded', () async {
      await vm.initialize();
      expect(vm.lastBackupAt.value, isNull);
      expect(vm.lastBackupSize.value, 0);
    });
  });

  group('dismissResult()', () {
    test('resets to idle and clears error', () async {
      vm.status.value = BackupStatus.error;
      vm.errorMessage.value = 'some error';

      await vm.dismissResult();

      expect(vm.status.value, BackupStatus.idle);
      expect(vm.errorMessage.value, isNull);
    });
  });

  group('isBackupStale', () {
    test('true when lastBackupAt is null', () {
      expect(vm.isBackupStale, isTrue);
    });

    test('false within 7 days', () {
      vm.lastBackupAt.value = DateTime.now().subtract(const Duration(days: 3));
      expect(vm.isBackupStale, isFalse);
    });

    test('true after 7 days', () {
      vm.lastBackupAt.value = DateTime.now().subtract(const Duration(days: 10));
      expect(vm.isBackupStale, isTrue);
    });
  });
}
