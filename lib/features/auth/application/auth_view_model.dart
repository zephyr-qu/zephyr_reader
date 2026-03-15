import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/auth/domain/models/user.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../domain/auth_repository.dart';


@injectable
class AuthViewModel {
  final AuthRepository _repo;
  AuthViewModel(this._repo);

  final user = asyncSignal<User?>(AsyncState.data(null));
  final email = signal('');
  final password = signal('');

  bool get canSubmit => email.value.isNotEmpty && password.value.length >= 6;

  Future<void> login() async {
    user.value = AsyncState.loading();
    try {
      final data = await _repo.login(email.value, password.value);
      user.value = AsyncState.data(data);
    } catch (e) {
      user.value = AsyncState.error(e);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    user.value = AsyncState.data(null);
  }
}