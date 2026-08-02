# R2: 多引擎核心模型

## Goal

建立 lib/core/reading/ 目录结构，定义所有双引擎共享的纯 Dart seam 模型。不 import Flutter Widget、flureadium 或 ReaderViewModel。

## Requirements

### 目录结构

```
lib/core/reading/
├── backend/
│   ├── reading_backend.dart          # abstract interface — open/close/execute/applyPreferences
│   ├── reading_backend_kind.dart     # enum { builtin, readium }
│   ├── reading_backend_policy.dart   # 策略选择（骨架，R7 完善）
│   ├── reading_capabilities.dart     # 能力模型
│   ├── reading_command.dart          # sealed class 导航命令
│   ├── reading_open_request.dart     # 打开请求参数
│   └── reading_snapshot.dart         # 原子快照
├── position/
│   ├── reading_position.dart         # chapterIndex + charOffsetUtf16
│   ├── engine_position_hint.dart     # 引擎私有位置加速
│   └── position_mapping_error.dart   # 显式映射错误
└── preferences/
    └── reading_preferences.dart      # 统一设置模型
```

### 定义约束

- 所有文件纯 Dart，不引入 Flutter widget
- 不 import `flureadium`
- 不 import `ReaderViewModel`
- 所有错误为显式类型，不能通过字符串判断
- `ReadingCommand` 使用 sealed class

## Acceptance Criteria

- [ ] `lib/core/reading/` 目录创建，包含所有模型文件
- [ ] 文件通过 `dart analyze` 零错误
- [ ] 不 import Flutter widget / flureadium / ReaderViewModel
- [ ] 检查点：`feat: define engine-neutral reading backend seam`
