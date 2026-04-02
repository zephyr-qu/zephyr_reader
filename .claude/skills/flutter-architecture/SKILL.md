---
name: flutter-architecture
description: Flutter 项目架构分析和最佳实践指南。当用户需要分析项目架构、了解目录结构、实施 Clean Architecture、或进行架构优化时使用此技能。
---

# Flutter 架构分析与优化指南

## 当前项目架构分析

### 现有结构（已优化）

```
lib/
├── core/                    # 核心模块（所有基础设施和共享代码）
│   ├── error/              # 错误处理（ApiError 密封类）
│   ├── local/              # 本地存储（FileStorage、SharedPreferences）
│   ├── network/            # 网络配置（Dio、拦截器）
│   ├── presentation/       # UI 展示层
│   │   └── widgets/        # 通用组件（ErrorText、LoadingIndicator）
│   ├── routing/            # 路由配置（GoRouter、路由常量）
│   ├── theme/              # 主题配置（ThemeData、DesignTokens）
│   ├── utils/              # 工具类（Logging）
│   └── app_config.dart     # 应用配置
├── di/                     # 依赖注入
│   ├── app_module.dart
│   ├── service_locator.dart
│   └── service_locator.config.dart
├── features/               # 功能模块（按业务划分）
│   ├── article/           # 文章功能
│   ├── auth/              # 认证功能
│   ├── home/              # 主页功能
│   └── profile/           # 个人中心
├── gen/                    # 生成代码（flutter_gen）
├── app.dart                # 应用入口 Widget
└── main.dart               # 应用入口
```

### Feature 内部结构

```
features/auth/
├── application/            # ViewModel/状态管理
│   └── auth_view_model.dart
├── data/                   # 数据层
│   ├── auth_api.dart      # Retrofit API 定义
│   ├── auth_api.g.dart    # 生成代码
│   └── auth_service.dart  # Repository 实现
├── domain/                 # 领域层
│   ├── models/            # 领域模型
│   │   └── user.dart
│   └── auth_repository.dart # Repository 接口
└── page/                   # UI 层
    └── login_page.dart
```

---

## 架构优点 ✅

1. **Clean Architecture 分层**: domain/data/application/page 分层清晰
2. **依赖注入**: 使用 get_it + injectable
3. **状态管理**: 使用 signals_flutter
4. **类型安全路由**: go_router 配合命名路由
5. **代码生成**: retrofit + json_serializable
6. **统一错误处理**: ApiError 密封类
7. **主题系统**: 完整的 DesignTokens 系统

---

## 优化建议 📋

### 1. ✅ 已完成：目录结构优化

**优化内容：** 将 `shared/` 目录合并到 `core/`，明确职责边界

**优化前：**
```
lib/
├── core/        # 核心基础设施
└── shared/      # 共享资源（职责不清）
```

**优化后：**
```
lib/
├── core/
│   ├── presentation/
│   │   └── widgets/    # 通用 UI 组件
│   ├── utils/          # 工具类
│   ├── network/        # 网络层
│   ├── local/          # 本地存储
│   ├── theme/          # 主题系统
│   ├── routing/        # 路由配置
│   └── error/          # 错误处理
└── features/           # 功能模块
```

**已执行的操作：**
1. ✅ 创建 `core/presentation/widgets/` 目录
2. ✅ 移动 `shared/widget/*` → `core/presentation/widgets/`
3. ✅ 创建 `core/utils/` 目录
4. ✅ 移动 `shared/utils/*` → `core/utils/`
5. ✅ 更新所有导入路径
6. ✅ 删除空的 `shared/` 目录
7. ✅ Flutter analyze 验证通过

**导入路径变更：**
```dart
// 之前
import 'package:my_app/shared/utils/logging.dart';
import 'package:my_app/shared/widget/error_text.dart';

// 之后
import 'package:my_app/core/utils/logging.dart';
import 'package:my_app/core/presentation/widgets/error_text.dart';
```

---

### 2. Feature 内部结构优化

#### 问题：feature 内部结构不完整

```dart
// ❌ 当前：缺少明确的领域用例层
features/auth/
├── application/
├── data/
├── domain/
│   ├── models/
│   └── repository.dart    // 只有接口
└── page/

// ✅ 建议：添加 usecases 层
features/auth/
├── application/           # ViewModel + UseCases
│   ├── view_models/
│   │   └── auth_vm.dart
│   └── usecases/
│       ├── login_usecase.dart
│       └── logout_usecase.dart
├── data/
│   ├── datasources/       # 明确数据源
│   │   ├── auth_remote_ds.dart
│   │   └── auth_local_ds.dart
│   ├── models/           # DTO 模型（与 domain models 分离）
│   │   └── user_dto.dart
│   └── repositories/     # Repository 实现
│       └── auth_repo_impl.dart
├── domain/
│   ├── entities/         # 领域实体（纯业务对象）
│   │   └── user.dart
│   ├── repositories/     # Repository 接口
│   │   └── auth_repo.dart
│   └── usecases/         # 领域用例（可选，复杂业务时添加）
│       └── login.dart
└── presentation/         # UI 层
    ├── pages/
    ├── widgets/
    └── controllers/      # 或 view_models/
```

### 3. ✅ 已完成：依赖注入优化

**优化内容：** 将 DI 模块按功能分组，明确职责边界

**优化前：**
```dart
// ❌ 所有依赖集中在 NetworkModule
@module
abstract class NetworkModule {
  @LazySingleton()
  Dio get dio;

  @LazySingleton()
  AuthApi get authApi;

  @LazySingleton()
  ArticleApi get articleApi;
}
```

**优化后：**
```
lib/
├── core/
│   ├── core_module.dart           # 核心基础设施
│   └── network/network_module.dart # 仅 Dio 配置
└── features/
    ├── auth/data/auth_module.dart      # 认证功能依赖
    └── article/data/article_module.dart # 文章功能依赖
```

**模块职责：**

| 模块 | 职责 | 注册的依赖 |
|------|------|-----------|
| `CoreModule` | 核心基础设施 | `SharedPreferences`, `FileStorage` |
| `NetworkModule` | Dio 核心配置 | `Dio`（含拦截器） |
| `AuthModule` | 认证功能 | `AuthApi` |
| `ArticleModule` | 文章功能 | `ArticleApi` |

**依赖注入流程图：**
```
Dio (NetworkModule)
  ├── AuthApi (AuthModule) → AuthService → AuthRepository → AuthViewModel
  └── ArticleApi (ArticleModule) → ArticleService → ArticleRepository → ArticleViewModel
```

**已执行的操作：**
1. ✅ 创建 `core/core_module.dart`
2. ✅ 重构 `core/network/network_module.dart`
3. ✅ 创建 `features/auth/data/auth_module.dart`
4. ✅ 创建 `features/article/data/article_module.dart`
5. ✅ 运行 `build_runner build`
6. ✅ `flutter analyze` 验证通过

---

### 4. ✅ 已完成：ViewModel 基类

**优化内容：** 创建统一的 ViewModel 基类，管理信号效应和资源清理

**优化前：**
```dart
// ❌ 每个 ViewModel 手动管理 effect 清理
class AuthViewModel {
  final stoppers = <Stopper>[];

  AuthViewModel() {
    stoppers.add(effect(() { ... }));
  }

  void dispose() {
    for (final stopper in stoppers) {
      stopper();
    }
  }
}
```

**优化后：**
```dart
// ✅ 继承 BaseViewModel，自动管理资源
abstract class BaseViewModel {
  // 自动管理 effect/watch 清理
  @protected
  void addEffect(void Function() effectFn, {void Function()? onDispose});

  @protected
  void addWatch<T>(
    T Function() signalFn,
    void Function(T value) callback,
  );

  // 统一 dispose 方法
  @mustCallSuper
  void dispose();

  @protected
  void onDispose();
}

// 使用示例
class AuthViewModel extends BaseViewModel {
  AuthViewModel() {
    addEffect(() {
      print('User changed: ${user.value}');
    });

    addWatch(() => email.value, (value) {
      print('Email: $value');
    });
  }

  final user = asyncSignal<User?>(AsyncState.data(null));
  final email = signal('');

  @override
  void onDispose() {
    print('AuthViewModel disposed');
  }
}
```

**文件结构：**
```
lib/
└── shared/
    └── view_models/
        └── base_view_model.dart  # ViewModel 基类
```

**核心功能：**
1. ✅ `addEffect()` - 添加 effect 并自动管理清理
2. ✅ `addWatch()` - 添加信号监听
3. ✅ `addDisposable()` - 添加自定义清理回调
4. ✅ `dispose()` - 统一释放资源
5. ✅ `onDispose()` - 子类释放回调

**已执行的操作：**
1. ✅ 创建 `shared/view_models/base_view_model.dart`
2. ✅ 更新 `AuthViewModel extends BaseViewModel`
3. ✅ 更新 `ArticleViewModel extends BaseViewModel`
4. ✅ `flutter analyze` 验证通过

---

### 5. 路由优化

```dart
// ❌ 当前：硬编码路径和 context.go
context.go('/articles');

// ✅ 建议：类型安全导航
// lib/core/routing/app_router.dart
extension GoRouterExt on BuildContext {
  Future<void> goToLogin() => goNamed(RouteNames.login);
  Future<void> goToHome() => goNamed(RouteNames.home);
  Future<void> goToArticleDetail(int id) => 
      goNamed(RouteNames.articleDetail, pathParams: {'id': '$id'});
}

// ✅ 或使用路由参数对象
class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const articleDetail = '/articles/:id';
}

class ArticleDetailRoute {
  final int id;
  const ArticleDetailRoute({required this.id});
  
  String get path => '/articles/$id';
  String get name => RouteNames.articleDetail;
}

// 使用
context.go(ArticleDetailRoute(id: 1).path);
```

#### 问题：路由守卫逻辑分散

```dart
// ✅ 建议：集中路由守卫
class AuthGuard extends GoRouterRedirect {
  final Signal<bool> isAuthenticated;
  
  const AuthGuard(this.isAuthenticated);
  
  @override
  String? redirect(BuildContext context, GoRouterState state) {
    final requiresAuth = state.matchedLocation.requiresAuth;
    if (requiresAuth && !isAuthenticated.value) {
      return RoutePaths.login;
    }
    return null;
  }
}

// 扩展路径配置
extension RoutePathExt on String {
  bool get requiresAuth => [
    RoutePaths.home,
    RoutePaths.profile,
  ].contains(this);
}
```

### 4. 错误处理优化

#### 问题：错误类型缺少国际化消息

```dart
// ✅ 建议：添加错误消息映射
sealed class ApiError implements Exception {
  const ApiError();
  
  String message(BuildContext context) {
    return switch (this) {
      _Timeout() => context.l10n.errorTimeout,
      _Offline() => context.l10n.errorOffline,
      _Unauthorized() => context.l10n.errorUnauthorized,
      _Unknown(msg: final m) => m ?? context.l10n.errorUnknown,
    };
  }
}

// ✅ 或使用 Result/Either 模式
sealed class Result<T> {
  const Result();
  
  factory Result.success(T data) => _Success(data);
  factory Result.failure(ApiError error) => _Failure(error);
  
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiError error) failure,
  });
}

// ViewModel 中使用
Future<void> login() async {
  user.value = AsyncState.loading();
  final result = await _loginUseCase.execute(email.value, password.value);
  
  result.when(
    success: (data) => user.value = AsyncState.data(data),
    failure: (error) => user.value = AsyncState.error(error),
  );
}
```

### 5. 状态管理优化

#### 问题：全局信号缺少统一管理

```dart
// ❌ 当前：全局信号分散
final isAuthenticated = signal<bool>(false, autoDispose: true);

// ✅ 建议：创建全局状态 store
// lib/core/state/global_state.dart
class GlobalState {
  final isAuthenticated = signal(false);
  final currentUser = asyncSignal<User?>(AsyncState.data(null));
  final themeMode = signal(ThemeMode.system);
  
  void logout() {
    isAuthenticated.value = false;
    currentUser.value = AsyncState.data(null);
  }
}

@LazySingleton()
GlobalState get globalState => GlobalState();
```

#### 问题：ViewModel 缺少统一基类

```dart
// ✅ 建议：创建 ViewModel 基类
abstract class BaseViewModel {
  final disposeBag = <Stopper>[];
  
  void dispose() {
    for (final stopper in disposeBag) {
      stopper();
    }
    disposeBag.clear();
    onDispose();
  }
  
  @mustCallSuper
  void onDispose() {}
  
  @protected
  Stopper addStopper(Stopper stopper) {
    disposeBag.add(stopper);
    return stopper;
  }
}

// 使用
class AuthViewModel extends BaseViewModel {
  AuthViewModel(this._repo) {
    addStopper(effect(() {
      print('User changed: ${user.value}');
    }));
  }
}
```

### 6. 网络层优化

#### 问题：Token 管理未实现

```dart
// ✅ 建议：添加 Token 管理
// lib/core/network/auth_interceptor.dart
class AuthInterceptor extends Interceptor {
  final GlobalState _state;
  final TokenStorage _tokenStorage;
  
  AuthInterceptor(this._state, this._tokenStorage);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token 过期，刷新或登出
      _handleTokenExpired();
    }
    handler.next(err);
  }
}

// lib/core/storage/token_storage.dart
class TokenStorage {
  final SharedPreferences _prefs;
  
  TokenStorage(this._prefs);
  
  String? getToken() => _prefs.getString('token');
  Future<void> saveToken(String token) => _prefs.setString('token', token);
  Future<void> clearToken() => _prefs.remove('token');
}
```

### 7. 本地存储优化

#### 问题：缺少统一的存储抽象

```dart
// ✅ 建议：创建存储抽象层
// lib/core/storage/storage.dart
abstract class Storage {
  Future<T?> get<T>(String key);
  Future<void> set<T>(String key, T value);
  Future<void> delete(String key);
  Future<void> clear();
}

// lib/core/storage/shared_prefs_storage.dart
class SharedPreferencesStorage implements Storage {
  final SharedPreferences _prefs;
  
  @override
  Future<T?> get<T>(String key) async {
    return _prefs.get(key) as T?;
  }
  
  @override
  Future<void> set<T>(String key, T value) async {
    switch (T) {
      case int:
        await _prefs.setInt(key, value as int);
      case String:
        await _prefs.setString(key, value as String);
      // ...
    }
  }
}

// 使用 SecureStorage 存储敏感数据
class SecureStorage implements Storage {
  final FlutterSecureStorage _storage;
  // ...
}
```

### 8. 测试支持优化

#### 问题：缺少测试基础设施

```dart
// ✅ 建议：添加测试基础设施
// test/fixtures/user_fixture.dart
class UserFixture {
  static User createValidUser({
    int id = 1,
    String name = 'Test User',
  }) => User(id: id, name: name);
}

// test/mocks/auth_repository_mock.dart
class MockAuthRepository extends Mock implements AuthRepository {}

// test/helpers/test_helper.dart
class TestHelper {
  static Future<void> setupTest() async {
    await configureDependencies();
    // 注册 mock
    getIt.registerLazySingleton<AuthRepository>(
      () => MockAuthRepository(),
    );
  }
  
  static void tearDownTest() {
    getIt.reset();
  }
}
```

### 9. 构建配置优化

#### 问题：缺少环境配置

```dart
// ✅ 建议：添加环境配置
// lib/core/config/flavor.dart
enum Flavor {
  dev,
  staging,
  prod;
  
  String get baseUrl => switch (this) {
    Flavor.dev => 'https://dev.api.com',
    Flavor.staging => 'https://staging.api.com',
    Flavor.prod => 'https://api.com',
  };
  
  bool get isDebug => this == Flavor.dev;
}

// lib/core/config/app_flavor.dart
class AppFlavor {
  static Flavor? _flavor;
  
  static void init(Flavor flavor) => _flavor = flavor;
  static Flavor get current => _flavor ?? Flavor.dev;
}

// main_dev.dart
void main() {
  AppFlavor.init(Flavor.dev);
  runApp(const MyApp());
}
```

### 10. 代码规范优化

#### 建议：添加架构约束

```dart
// ✅ 使用 build_verify 验证架构
// test/build_test.dart
@Tags(['golden'])
void testArchitecture() {
  // 验证 feature 之间不互相依赖
  // 验证 domain 层不依赖 data 层
  // 验证页面只依赖 application 层
}

// ✅ 添加 lint 规则
// analysis_options.yaml
linter:
  rules:
    - prefer_final_locals
    - avoid_print
    - prefer_single_quotes
```

---

## 优先级建议

| 优先级 | 优化项 | 工作量 | 收益 | 状态 |
|--------|--------|--------|------|------|
| 🔴 高 | 统一 core/shared 职责 | 中 | 高 | ✅ 已完成 |
| 🔴 高 | 完善 DI 模块分组 | 中 | 高 | ✅ 已完成 |
| 🔴 高 | ViewModel 基类 | 低 | 中 | ✅ 已完成 |
| 🔴 高 | 添加 Token 管理 | 中 | 高 | ⏳ 待处理 |
| 🟡 中 | 类型安全路由导航 | 低 | 中 | ⏳ 待处理 |
| 🟢 低 | 添加 UseCase 层 | 高 | 中 | ⏳ 待处理 |
| 🟢 低 | 环境配置 | 中 | 低 | ⏳ 待处理 |
| 🟢 低 | 测试基础设施 | 中 | 中 | ⏳ 待处理 |

---

## 快速开始

### ✅ 第一步：整理 core/shared（已完成）

```bash
# 已执行
mv lib/shared/utils lib/core/utils
mv lib/shared/widget lib/core/presentation/widgets
rmdir lib/shared
```

**新的目录结构：**
```
lib/
├── core/
│   ├── presentation/
│   │   └── widgets/    # ErrorText, LoadingIndicator
│   ├── utils/          # Logging
│   ├── local/          # FileStorage
│   ├── network/        # Dio, 拦截器
│   ├── theme/          # 主题系统
│   ├── routing/        # 路由配置
│   └── error/          # 错误处理
└── features/
```

### ✅ 第二步：完善 DI 模块分组（已完成）

**新的 DI 模块结构：**
```
lib/
├── core/
│   ├── core_module.dart           # SharedPreferences, FileStorage
│   └── network/
│       └── network_module.dart    # Dio 配置（含拦截器）
└── features/
    ├── auth/data/
    │   ├── auth_api.dart          # Retrofit API 定义
    │   ├── auth_service.dart      # Repository 实现
    │   └── auth_module.dart       # DI 模块
    └── article/data/
        ├── article_api.dart       # Retrofit API 定义
        ├── article_service.dart   # Repository 实现
        └── article_module.dart    # DI 模块
```

**依赖注册顺序：**
```
1. SharedPreferences (CoreModule)
2. FileStorage (自动注册)
3. Dio (NetworkModule)
4. AuthApi (AuthModule) ← 依赖 Dio
5. ArticleApi (ArticleModule) ← 依赖 Dio
6. AuthService → AuthRepository (自动注册)
7. ArticleService → ArticleRepository (自动注册)
8. AuthViewModel (自动注册) ← 依赖 AuthRepository
9. ArticleViewModel (自动注册) ← 依赖 ArticleRepository
10. AppConfig (自动注册) ← 依赖 SharedPreferences
```

**已执行的操作：**
1. ✅ 创建 `core/core_module.dart`
2. ✅ 重构 `core/network/network_module.dart`（仅保留 Dio）
3. ✅ 创建 `features/auth/data/auth_module.dart`
4. ✅ 创建 `features/article/data/article_module.dart`
5. ✅ 运行 `dart run build_runner build --delete-conflicting-outputs`
6. ✅ `flutter analyze` 验证通过

### ✅ 第三步：创建 ViewModel 基类（已完成）

**ViewModel 基类使用：**
```dart
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../shared/view_models/base_view_model.dart';

@injectable
class AuthViewModel extends BaseViewModel {
  final AuthRepository _repo;

  AuthViewModel(this._repo) {
    // 初始化 effect 监听（自动清理）
    addEffect(() {
      if (user.value.hasValue) {
        debugPrint('用户已登录：${user.value.value?.name}');
      }
    });

    // 监听信号变化
    addWatch(() => email.value, (value) {
      debugPrint('邮箱输入：$value');
    });
  }

  final user = asyncSignal<User?>(AsyncState.data(null));
  final email = signal('');

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

  @override
  void onDispose() {
    debugPrint('AuthViewModel 已释放');
    super.onDispose();
  }
}
```

**已执行的操作：**
1. ✅ 创建 `shared/view_models/base_view_model.dart`
2. ✅ 更新 `AuthViewModel extends BaseViewModel`
3. ✅ 更新 `ArticleViewModel extends BaseViewModel`
4. ✅ `flutter analyze` 验证通过

### 第四步：添加 Token 管理（待处理）

```dart
// lib/core/routing/router_extension.dart
extension AppRouterExt on BuildContext {
  void goToLogin() => goNamed(RouteNames.login);
  void goToHome() => goNamed(RouteNames.home);
  void goToProfile() => goNamed(RouteNames.profile);
  void goBack() => pop();
}
```

---

## 参考资源

- [Clean Architecture in Flutter](https://resocoder.com/flutter-clean-architecture-tdd/)
- [Flutter Best Practices](https://github.com/flutter/flutter/wiki/Flutter-Best-Practices)
- [Effective Dart](https://dart.dev/effective-dart)
