# R7: 引擎策略与回退

## Goal

`ReadingBackendPolicy` 根据书籍格式、用户配置、失败历史决定使用哪个引擎。禁用 UI 层写 `if (book.format == epub)`。

## Requirements

### 策略类

```dart
class ReadingBackendPolicy {
  ReadingBackendKind select(Book book, ReaderSettings settings);
}
```

### 优先级（高→低）

1. 本书显式选择（`book_reading_backend:{bookId}`）
2. 全局 EPUB 策略
3. 平台是否支持 Readium
4. Readium 是否曾对此书启动失败
5. 默认 Builtin

### 失败处理

Readium 打开失败时统一错误页面提供：

- 重试
- 使用兼容模式（Builtin）打开
- 返回书架

**不要静默回退** — 用户需要知道排版引擎已改变。

### 每本书覆盖

`book_reading_backend:{bookId}` 存储偏好。

## Acceptance Criteria

- [ ] 引擎决策只存在一个地方（ReadingBackendPolicy）
- [ ] EPUB 默认 Readium
- [ ] 用户可以逐本切换 Builtin
- [ ] 切换时转换并恢复逻辑位置
- [ ] 回退不删除原进度和书签
- [ ] 检查点：`feat: select and fallback reading backends`
