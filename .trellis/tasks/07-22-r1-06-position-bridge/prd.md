# R6: 实现位置桥

## Goal

实现 Readium Locator ↔ `ReadingPosition` 双向映射，支持精确、上下文推断、近似三个精度级别。

## Requirements

### Readium → ReadingPosition 映射顺序

1. Locator `href` → EPUB reading order → 章节 index
2. Locator 文本上下文 → plainText 定位 → UTF-16 charOffset
3. 文本上下文不足时使用 `progression` 估算
4. 输出精度标记

```dart
class PositionMappingResult {
  final ReadingPosition position;
  final PositionPrecision precision; // exact / contextual / approximate
}
```

### ReadingPosition → Readium 恢复顺序

1. 读取有效 Locator hint → `goToLocator`
2. Locator 无效 → 根据 chapter href 构造 Locator
3. 有文本上下文 → 增加 range/fragment
4. 无精确位置 → 章节内 progression
5. 最后降级到章节开头

### 必测边界

- 中文、英文、emoji、UTF-16 代理对
- 重复句子、HTML 空白折叠
- 图片 `\uFFFC`、同一 XHTML 多目录节点
- fragment href、EPUB 文件替换后失效
- Locator JSON 损坏

## Acceptance Criteria

- [ ] 不会恢复到错误章节
- [ ] 映射失败显式返回 PositionMappingError
- [ ] 不允许默认返回 charOffset=0 掩盖失败
- [ ] 书签恢复达到章节正确、段落接近
- [ ] totalProgression 只作为最后降级
- [ ] 检查点：`feat: bridge readium locators to logical reading positions`
