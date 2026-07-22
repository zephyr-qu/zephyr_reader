# R4: Builtin Adapter

## Goal

将现有 ReaderSession/ReaderViewModel/PaginationEngine/ScrollEngine 等包装为 `ReadingBackend`。行为完全不变，不重写现有阅读逻辑。

## Requirements

### 新增文件

```
lib/core/reading/backend/builtin/
├── builtin_reading_backend.dart    # ReadingBackend 实现
└── builtin_reading_viewport.dart   # ReadingViewportAdapter 实现 → ReaderContentArea
```

### 映射表

| ReadingBackend 方法 | Builtin 实现 |
| --- | --- |
| open | ReaderViewModel.initialize |
| NextPage | loadPage / 下一章 |
| PreviousPage | 上一页 / 上一章 |
| GoToChapter | jumpToChapter |
| GoToPosition | jumpToPosition |
| snapshot.position | chapterIndex + charOffset 当前值 |
| applyPreferences | 更新 ReaderConfig 并重排 |
| close | resetForNewBook |

### 原则

- 不重写 `PaginationEngine`
- Adapter 是现有实现的正式入口
- TXT 行为不变
- Builtin EPUB 行为不变
- 页面迁移完成后，不再直接消费 ReaderViewModel

## Acceptance Criteria

- [ ] TXT 行为不变
- [ ] Builtin EPUB 行为不变
- [ ] pagination、scroll、书签、批注、staging 均不回归
- [ ] 同一 backend contract test 可验证其生命周期
- [ ] 检查点：`refactor: expose builtin reader through reading backend`
