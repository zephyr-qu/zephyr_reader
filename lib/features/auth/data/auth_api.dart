import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/auth/domain/models/user.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

@injectable
@RestApi()
abstract class AuthApi {
  @factoryMethod
  factory AuthApi(Dio dio) = _AuthApi;

  @POST('/login')
  Future<User> login(@Query('email') String email, @Query('pwd') String pwd);
  @GET('/logout')
  Future<void> logout();
}
