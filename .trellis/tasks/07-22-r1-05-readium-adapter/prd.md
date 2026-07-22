# R5: Readium Adapter

## Goal

包装 flureadium 为 `ReadingBackend`，修正当前生命周期问题，实现正式状态机。不再存在独立 Readium 页面壳层。

## Requirements

### 新增文件

```
lib/core/reading/backend/readium/
├── readium_reading_backend.dart     # ReadingBackend 实现
├── readium_reading_viewport.dart    # ReadingViewportAdapter → ReadiumReaderWidget
├── readium_session.dart             # 独占 Flureadium + Publication + Locator
├── readium_preferences_mapper.dart  # EPUBPreferences 映射
├── readium_chapter_mapper.dart      # chapterIndex ↔ href 映射
└── readium_decoration_mapper.dart   # decoration 工具
```

### 生命周期

**打开顺序：** session 创建 → 事件订阅 → openPublication → 创建 ReadiumReaderWidget → 等待 native viewport ready → 应用 EPUBPreferences → 恢复位置 → ready

**关闭顺序：** 标记 closing → 取消未完成打开 → 取当前位置 → 取消所有订阅 → closePublication → 清空 Publication → closed

### 要求

- `close()` 幂等
- 前书事件不污染下书
- 快速退出不留异步回调
- 打开失败不发布 ready
- Platform View 就绪前不得导航
- 重试通过创建新 open generation 完成

## Acceptance Criteria

- [ ] 完整实现 open/close/previous/next/restore
- [ ] 不再存在独立 Readium 页面壳层
- [ ] session 无字符串状态判断
- [ ] 检查点：`feat: implement production readium reading backend`
