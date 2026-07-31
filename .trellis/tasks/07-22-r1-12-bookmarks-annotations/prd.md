# R12: 书签与批注

## Goal

统一书签和批注在两个后端上可用。书签跨引擎恢复、高亮 decoration 显示。

## Requirements

### 书签统一保存

- `bookId / chapterIndex / charOffset / engineHint?`
- Readium 新增书签：获取当前 Locator → 映射 ReadingPosition → 保存 + Locator hint

### 书签跳转

1. 优先有效 Locator → goToLocator
2. 失败则根据逻辑位置重建 Locator
3. 最后降级章节位置

### 高亮（已有→decoration）

- Note ReadingPosition → Readium Locator → ReaderDecoration → applyDecorations

### 新建高亮

- 如果 flureadium 能返回 range Locator → 接入现有笔记保存
- 如果只能展示 decoration → 暂时禁用 Readium 新建高亮
- 不能用不稳定的全书百分比创建批注

## Acceptance Criteria

- [ ] 书签跨重排恢复
- [ ] 删除书签不影响 Locator 进度
- [ ] 已有高亮可显示和跳转（跨引擎）
- [ ] 删除笔记同步删除 decoration
- [ ] 不具备精确选区时 UI 明确禁用新建
- [ ] 检查点：`feat: integrate bookmarks and annotations with readium`
