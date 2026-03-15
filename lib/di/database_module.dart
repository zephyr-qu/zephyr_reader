import 'package:injectable/injectable.dart';

import '../core/database/database.dart';

@module
abstract class DatabaseModule {
  @preResolve
  @singleton
  Future<AppDatabase> get database async => await openDatabase();
}