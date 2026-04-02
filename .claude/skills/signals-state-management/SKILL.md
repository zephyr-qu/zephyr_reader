---
name: signals-state-management
description: 使用 signals_flutter 和 signals_hooks 进行 Flutter 状态管理。当用户需要创建响应式状态、ViewModel、计算属性、Hook 组件、副作用处理或异步数据流时使用此技能。适用于 Flutter 项目中的状态管理场景，包括 signal、computed、effect、asyncSignal、computedAsync 等核心 API。
---

# Signals 状态管理

使用 `signals_flutter` 和 `signals_hooks` 进行 Flutter 响应式状态管理。

## 核心特性

- **细粒度响应式**: 自动追踪依赖，仅更新需要更新的部分
- **惰性求值**: 信号仅在读取时计算，未订阅时不触发
- **手术式渲染**: Widget 树仅标记需要更新的部分
- **100% Dart 原生**: 支持 Flutter Web、Mobile、Desktop

---

## 基础 API

### Signal - 基础信号

```dart
import 'package:signals_flutter/signals_flutter.dart';

// 创建信号
final count = signal(0);
final text = signal('');
final isEnabled = signal(false);

// 读取值
print(count.value); // 0

// 写入值
count.value = 1;

// 强制更新（触发所有 effect 和 computed）
count.set(2, force: true);

// peek - 读取但不订阅（用于 effect 中避免循环）
final effectCount = signal(0);
effect(() {
  print(count.value); // 订阅 count
  effectCount.value = effectCount.peek() + 1; // 不订阅 effectCount
});
```

### Computed - 计算信号

```dart
// 基础计算
final count = signal(0);
final doubleCount = computed(() => count.value * 2);
final fullName = computed(() => '${firstName.value} ${lastName.value}');

// 强制重新计算
fullName.recompute();

// 自动销毁（无监听者时自动 dispose）
final autoComputed = computed(() => count.value, autoDispose: true);

// 销毁回调
autoComputed.onDispose(() => print('已销毁'));
```

### Effect - 副作用

```dart
// 基础 effect
final count = signal(0);
final stopper = effect(() {
  print('count: ${count.value}');
});

// 带清理回调
final stopper = effect(() {
  print('值：${count.value}');
  return () => print('清理资源');
}, onDispose: () => print('已销毁'));

// 销毁 effect
stopper();

// untracked - 在回调中不订阅信号
final fn = () => effectCount.value + 1;
effect(() {
  print(count.value);
  effectCount.value = untracked(fn); // 不订阅 fn 中的信号
});
```

### Batch - 批量更新

```dart
final name = signal('Jane');
final surname = signal('Doe');
final fullName = computed(() => '${name.value} ${surname.value}');

effect(() => print(fullName.value));

// 批量更新，只在回调结束时触发一次 effect
batch(() {
  name.value = 'John';
  surname.value = 'Doe 2';
});
```

---

## 异步信号

### AsyncSignal - 异步状态容器

```dart
import 'package:signals_flutter/signals_flutter.dart';

// 创建异步信号
final user = asyncSignal<User?>(AsyncState.data(null));
final items = asyncSignal<List<Item>>(AsyncState.loading());

// 状态访问
user.value.map(
  data: (data) => Text('欢迎，${data.name}'),
  error: (error, stack) => Text('错误：$error'),
  loading: () => CircularProgressIndicator(),
);

// 或使用 switch
Watch(builder: (context) {
  final state = user.value;
  return switch (state) {
    DataState() => Text('欢迎，${state.data.name}'),
    ErrorState() => Text('错误：${state.error}'),
    LoadingState() => CircularProgressIndicator(),
  };
});
```

### FutureSignal - Future 信号

```dart
// 创建方式 1: futureSignal
final future = futureSignal(() async => await fetchData());

// 创建方式 2: 扩展方法
final future = Future.delayed(Duration(seconds: 1), () => 1).toSignal();

// 带依赖（依赖变化时自动重置）
final count = signal(0);
final future = futureSignal(
  () async => await fetchById(count.value),
  dependencies: [count],
);

// 控制方法
future.reset();    // 重置为初始状态
future.refresh();  // 重新加载，保持当前状态
future.reload();   // 设置为 Loading 状态

// 访问值
final value = future.value.value; // 1 或 null
final peekValue = future.peek();  // 不订阅
```

### StreamSignal - Stream 信号

```dart
// 创建方式 1: streamSignal
final stream = streamSignal(() => Stream.periodic(Duration(seconds: 1), (i) => i));

// 创建方式 2: 扩展方法
final stream = Stream.value(1).toSignal();

// 带依赖
final count = signal(0);
final stream = streamSignal(
  () async* {
    final value = count.value;
    yield value;
  },
  dependencies: [count],
);

// 控制方法
stream.reset();
stream.refresh();
stream.reload();
```

### ComputedAsync - 异步计算

```dart
// computedAsync - 跨异步间隙追踪信号
final movieId = signal('id');
late final movie = computedAsync(() => fetchMovie(movieId.value));

// ⚠️ 注意：信号必须在 await 之前调用
// 错误示例：
// computedAsync(() async {
//   final id = movieId.value; // ❌ 在 await 后调用，无法追踪
//   await Future.delayed(Duration(seconds: 1));
//   return fetchMovie(id);
// });

// 正确示例：
// computedAsync(() async {
//   final id = movieId.value; // ✅ 在 await 之前调用
//   await Future.delayed(Duration(seconds: 1));
//   return fetchMovie(id);
// });

// computedFrom - 通过参数传递依赖
final movie = computedFrom([movieId], (args) => fetchMovie(args.first));
```

---

## Flutter Hooks 集成

使用 `signals_hooks` 在 HookWidget 中使用 signals。

### 基础 Hooks

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

class Example extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // useSignal - 创建信号（自动 rebuild）
    final count = useSignal(0);
    
    // useComputed - 创建计算信号
    final doubleCount = useComputed(() => count.value * 2);
    
    // useSignalEffect - 副作用（自动清理）
    useSignalEffect(() {
      debugPrint('count: $count, double: $doubleCount');
    });
    
    return Scaffold(
      body: Center(child: Text('Count: $count, Double: $doubleCount')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### 绑定现有信号

```dart
class Example extends HookWidget {
  final Signal<int> count;
  const Example(this.count, {super.key});
  
  @override
  Widget build(BuildContext context) {
    // useExistingSignal - 绑定现有信号（自动 rebuild）
    final counter = useExistingSignal(count);
    
    // useSignalValue - 直接获取信号值
    final value = useSignalValue(count);
    
    return Text('Count: $counter');
  }
}
```

### 异步 Hooks

```dart
class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // useFutureSignal - Future 信号
    final future = useFutureSignal(
      () => Future.delayed(Duration(seconds: 1), () => 1)
    );
    
    // useStreamSignal - Stream 信号
    final stream = useStreamSignal(
      () => Stream.periodic(Duration(seconds: 1), (i) => i)
    );
    
    // useAsyncSignal - 通用异步信号
    final signal = useAsyncSignal<int>(AsyncState.loading());
    
    // useAsyncComputed - 异步计算
    final count = useSignal(0);
    final future = useAsyncComputed(
      () async {
        await Future.delayed(Duration(seconds: 1));
        return count.value * 2;
      },
      dependencies: [count],
    );
    
    return future.value.map(
      data: (v) => Text('$v'),
      error: (e, s) => Text('$e'),
      loading: () => CircularProgressIndicator(),
    );
  }
}
```

### 集合 Hooks

```dart
class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // useListSignal - List 信号
    final list = useListSignal([1, 2, 3]);
    
    // useSetSignal - Set 信号
    final set = useSetSignal({1, 2, 3});
    
    // useMapSignal - Map 信号
    final map = useMapSignal({'a': 1, 'b': 2});
    
    return Text('List: ${list.value}, Set: ${set.value}, Map: ${map.value}');
  }
}
```

### Flutter 互操作

```dart
class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // ValueNotifier -> Signal
    final notifier = useValueNotifier(0);
    final signal = useValueNotifierToSignal(notifier);
    
    // ValueListenable -> Signal
    final listenable = useValueNotifier(0);
    final signal = useValueListenableToSignal(listenable);
    
    return Text('${signal.value}');
  }
}
```

---

## Flutter 集成

### SignalsMixin - 状态管理 Mixin

```dart
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

class CounterWidget extends StatefulWidget {
  @override
  _CounterWidgetState createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> with SignalsMixin {
  // 自动 dispose 的信号
  late final counter = createSignal(0);
  late final isEven = createComputed(() => counter.value.isEven);
  late final isOdd = createComputed(() => counter.value.isOdd);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Counter: $counter, even=$isEven, odd=$isOdd'),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Watch 组件

```dart
import 'package:signals_flutter/signals_flutter.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I.get<MyViewModel>();
    
    return Watch(
      builder: (context) {
        final state = vm.user.value;
        if (state.isLoading) return CircularProgressIndicator();
        if (state.hasError) return Text('错误：${state.error}');
        if (state.hasData) return Text('欢迎，${state.data!.name}');
        return SizedBox.shrink();
      },
    );
  }
}
```

---

## ViewModel 模式

```dart
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

@injectable
class AuthViewModel {
  final AuthRepository _repo;
  AuthViewModel(this._repo);

  // 异步状态
  final user = asyncSignal<User?>(AsyncState.data(null));
  
  // 表单输入
  final email = signal('');
  final password = signal('');

  // 计算属性
  bool get canSubmit => email.value.isNotEmpty && password.value.length >= 6;
  bool get isLoading => user.value.isLoading;
  bool get hasError => user.value.hasError;

  // 业务方法
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
```

---

## 常见模式

### 表单验证

```dart
class FormViewModel {
  final email = signal('');
  final password = signal('');
  
  bool get isEmailValid => RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
      .hasMatch(email.value);
  bool get isPasswordValid => password.value.length >= 6;
  bool get canSubmit => isEmailValid && isPasswordValid;
  
  void updateEmail(String value) => email.value = value;
  void updatePassword(String value) => password.value = value;
}
```

### 列表分页加载

```dart
class ListViewModel {
  final ArticleRepository _repo;
  ListViewModel(this._repo);

  final items = asyncSignal<List<Article>>(AsyncState.data([]));
  final page = signal(1);
  final isLoadingMore = signal(false);
  final hasMore = signal(true);

  Future<void> load() async {
    items.value = AsyncState.loading();
    try {
      final data = await _repo.getArticles();
      items.value = AsyncState.data(data);
      hasMore.value = data.isNotEmpty;
    } catch (e) {
      items.value = AsyncState.error(e);
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final newItems = await _repo.getPage(page.value + 1);
      items.value = AsyncState.data([...items.value.data ?? [], ...newItems]);
      page.value++;
      hasMore.value = newItems.isNotEmpty;
    } finally {
      isLoadingMore.value = false;
    }
  }
}
```

### 搜索防抖

```dart
class SearchViewModel {
  final SearchRepository _repo;
  SearchViewModel(this._repo);

  final query = signal('');
  final results = asyncSignal<List<Item>>(AsyncState.data([]));
  Timer? _debounce;

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 300), () {
      search(value);
    });
  }

  Future<void> search(String q) async {
    results.value = AsyncState.loading();
    try {
      results.value = AsyncState.data(await _repo.search(q));
    } catch (e) {
      results.value = AsyncState.error(e);
    }
  }

  void dispose() {
    _debounce?.cancel();
  }
}
```

### 全局配置

```dart
@Singleton()
class AppConfig {
  final SharedPreferences prefs;
  AppConfig(this.prefs);

  final themeMode = signal<ThemeMode>(ThemeMode.system);
  final enableDebugLogging = signal<bool>(true);
  final apiTimeout = signal<int>(30000);
  final defaultPageSize = signal<int>(20);

  @PostConstruct()
  Future<void> init() async {
    themeMode.value = ThemeMode.values[prefs.getInt('theme') ?? 0];
    enableDebugLogging.value = prefs.getBool('debug') ?? false;
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    prefs.setInt('theme', mode.index);
  }

  void setDebugLogging(bool enabled) {
    enableDebugLogging.value = enabled;
    prefs.setBool('debug', enabled);
  }
}
```

### Connect - 连接 Stream 到 Signal

```dart
final s = signal(0);
final c = connect(s);

final s1 = Stream.value(1);
final s2 = Stream.value(2);

// 链式添加 streams
c.from(s1).from(s2);
// 或使用操作符
c << s1 << s2;

// 取消所有订阅
c.dispose();
```

---

## 最佳实践

### 1. 状态组织

| 类型 | 用途 | 示例 |
|------|------|------|
| 局部信号 | 组件内状态 | 表单输入、UI 状态 |
| ViewModel 信号 | 页面/功能状态 | 列表数据、用户信息 |
| 全局信号 | 应用级配置 | 主题、语言、设置 |

### 2. 依赖管理

```dart
// ✅ 推荐：在 await 前读取信号
computedAsync(() async {
  final id = itemId.value; // 追踪依赖
  await Future.delayed(Duration(seconds: 1));
  return fetchItem(id);
});

// ❌ 避免：在 await 后读取
computedAsync(() async {
  await Future.delayed(Duration(seconds: 1));
  final id = itemId.value; // 无法追踪依赖
  return fetchItem(id);
});

// ✅ 替代：使用 computedFrom
computedFrom([itemId], (args) => fetchItem(args.first));
```

### 3. 资源清理

```dart
// HookWidget - 自动清理
useSignalEffect(() {
  // 自动在 dispose 时清理
});

// StatefulWidget - 手动清理
class _State extends State<MyWidget> with SignalsMixin {
  late final stopper = effect(() {});
  
  @override
  void dispose() {
    stopper(); // 手动清理
    super.dispose();
  }
}

// SignalsMixin - 自动清理
class _State extends State<MyWidget> with SignalsMixin {
  late final signal = createSignal(0); // 自动 dispose
}
```

### 4. 避免循环

```dart
// ❌ 错误：信号循环
effect(() {
  count.value = count.value + 1; // 无限循环
});

// ✅ 正确：使用 untracked
effect(() {
  effectCount.value = untracked(() => effectCount.peek() + 1);
});
```

### 5. 测试

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_hooks/signals_hooks.dart';

void main() {
  testWidgets('useSignal', (tester) async {
    late Signal<int> state;
    await tester.pumpWidget(
      HookBuilder(builder: (context) {
        state = useSignal(42);
        return GestureDetector(
          onTap: () => state.value++,
          child: Text('$state', textDirection: TextDirection.ltr),
        );
      }),
    );

    expect(state.value, 42);
    expect(find.text('42'), findsOneWidget);

    await tester.tap(find.text('42'));
    await tester.pumpAndSettle();

    expect(state.value, 43);
    expect(find.text('43'), findsOneWidget);
  });
}
```

---

## 参考文件

- `lib/features/auth/application/auth_view_model.dart` - 认证 ViewModel 示例
- `lib/features/article/application/article_view_model.dart` - 列表 ViewModel 示例
- `lib/core/app_config.dart` - 全局配置示例
- `signals.md` - Signals 核心 API 文档
- `signals_hooks.md` - Flutter Hooks 集成文档
