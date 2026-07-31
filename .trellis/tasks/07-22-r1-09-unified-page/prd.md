# R9: 统一阅读页面

## Goal

唯一 `ReaderPage` 入口，`UnifiedReaderShell` 作为唯一壳层，根据 ReadingSession 注入 Builtin/Readium 视口。UI 不感知后端类型。

## Requirements

### 架构

```
ReaderPage（保留现有）
└── UnifiedReaderShell
    ├── ReaderTopChrome
    ├── ReadingViewportHost        # 切换 BuiltinViewport / ReadiumViewport
    ├── ReaderBottomChrome
    ├── ReaderNavigationDrawer
    ├── ReaderNoteSidebar
    ├── ReaderSelectionToolbarLayer
    └── ReaderInteractionLayer
```

### 迁移重点

- `ReaderScaffold` 不再直接要求 `ReaderViewModel` → 改读 `ReadingSnapshot`
- `ReaderContentArea` 移入 Builtin viewport
- 顶部/底部 UI 只读取 `ReadingSnapshot` 和 `ReadingCapabilities`
- 点击区域发送 `ReadingCommand`
- 设置面板调用 `applyPreferences`
- 目录调用 `GoToChapter`
- 亮度遮罩继续由 Flutter 页面层负责

### 壳层策略

- 基于现有 `ReaderChromeShell` 改造注入 `ReadingBackend`
- `ReadiumReaderShell` 在迁移完成后删除

## Acceptance Criteria

- [ ] UI 层零 `flureadium` import
- [ ] UI 层零具体 backend 类型判断
- [ ] 只有一套顶部/底部工具栏
- [ ] 只有一套路由
- [ ] TXT、Builtin EPUB、Readium EPUB 都进入相同页面
- [ ] 检查点：`feat: unify builtin and readium reader presentation`
