import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/auth/data/auth_api.dart';
import 'package:zephyr_reader/features/auth/domain/models/user.dart';

@LazySingleton()
class AuthRepository {
  final AuthApi _api;
  @factoryMethod
  AuthRepository(this._api);

  Future<User> login(String email, String pwd) async {
    try {
      final response = await _api.login(email, pwd);
      return response;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> logout() {
    try {
      return _api.logout();
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
