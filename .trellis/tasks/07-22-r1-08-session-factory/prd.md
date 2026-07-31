# R8: 统一 SessionFactory

## Goal

`ReadingSessionFactory` 将引擎策略转化为有作用的 scoped `ReadingSession`。现有 `ReaderSessionFactory`（`reader_session.dart`）升级为统一版本。

## Requirements

### ReadingSessionFactory

```dart
class ReadingSessionFactory {
  final ReadingBackendPolicy policy;
  final BuiltinReadingBackendFactory builtinFactory;
  final ReadiumReadingBackendFactory readiumFactory;

  Future<ReadingSession> create(ReadingOpenRequest request);
}
```

### ReadingSession

```dart
class ReadingSession {
  final ReadingBackend backend;
  final ReadingViewportAdapter viewport;
  final ReaderFeatureCoordinator features;
}
```

### ReaderFeatureCoordinator

管理引擎无关功能：

- 阅读计时
- 自动保存（含 force flush on exit/background）
- 书签同步
- 目录数据
- 错误消息聚合
- 设置同步

### 退出标准

- 每本书拥有独立 session
- session 关闭后 backend 和 viewport 都释放
- DI 不再把单例 Flureadium 暴露给页面
- 同时快速打开两本书不会共享状态

## Acceptance Criteria

- [ ] ReadingSessionFactory 实现
- [ ] ReadingSession 生命周期完整（创建→使用→释放）
- [ ] DI 不将 Flureadium 作为单例暴露给页面
- [ ] 检查点：`refactor: create scoped multi-backend reading sessions`
