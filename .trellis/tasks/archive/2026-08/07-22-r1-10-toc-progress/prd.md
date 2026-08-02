# R10: 目录与进度

## Goal

统一目录模型和进度持久化，两个 engine 共享同一套目录 UI 和进度保存逻辑。

## Requirements

### 统一目录模型

```dart
class ReadingChapter {
  final String id;
  final int index;
  final String title;
}
```

### 章节来源

- Builtin：现有章节数据库
- Readium：`Publication.tableOfContents` / `readingOrder`
- Readium 需要建立 `chapterIndex ↔ href ↔ Link` 映射

### 进度保存规则

- 页面显示 `totalProgression`
- 持久化仍保存 `ReadingPosition`
- Locator 事件节流保存（不每帧写数据库）
- 退出时强制 flush
- 后台时强制 flush

### 退出标准

- 目录高亮当前章节
- 目录跳转后进度正确
- 杀进程重开恢复
- 快速翻页不产生乱序写入
- 旧 Locator 不覆盖更新后的进度

## Acceptance Criteria

- [ ] 目录高亮当前章节
- [ ] 目录跳转后进度正确
- [ ] 杀进程重开恢复
- [ ] 快速翻页不会产生乱序写入
- [ ] 检查点：`feat: unify readium navigation and progress persistence`
