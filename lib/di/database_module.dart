import 'package:injectable/injectable.dart';

import '../core/database/database.dart';

/// 数据库模块配置
///
/// 使用 @module 注解将 AppDatabase 注册到 GetIt 依赖注入容器
/// @singleton 确保整个应用生命周期中只创建一个实例
@module
abstract class DatabaseModule {
  /// 提供 AppDatabase 单例
  ///
  /// 使用 @preResolve 确保在注入前完成异步初始化
  @preResolve
  @singleton
  Future<AppDatabase> get database async => getDatabase();
}
