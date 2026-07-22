# Readium Locator 映射报告

> 基于 flureadium 0.13.2 / flureadium_platform_interface 0.7.1 源码分析

## Locator 完整结构

```dart
class Locator {
  final String href;          // EPUB 内资源路径，如 "OEBPS/chapter1.xhtml"
  final String type;          // MIME type，如 "application/xhtml+xml"
  final String? title;        // 章节/资源标题（可选）
  final Locations? locations; // 位置坐标（可选）
  final LocatorText? text;    // 文本上下文（可选）
}

class Locations {
  final int? position;              // 出版物的页索引（>=1，索引页，非页码）
  final double? progression;        // 在当前资源内的进度（0.0 ~ 1.0）
  final double? totalProgression;   // 在全书的进度（0.0 ~ 1.0）
  final String? cssSelector;        // CSS 选择器，如 "#chapter1 > p:nth-child(3)"
  final DomRange? domRange;         // DOM Range（start/end 的 CSS selector + text offset）
  final List<String> fragments;     // URI 片段，如 ["toc=chapter1"]
  final String? partialCfi;         // 部分 CFI（规范片段标识符）
}

class DomRange {
  final DomPoint start;  // {cssSelector, offset}
  final DomPoint end;    // {cssSelector, offset}
}

class DomPoint {
  final String cssSelector;  // CSS 选择器
  final int offset;          // 在选中元素内的文本偏移（UTF-16 code unit）
}

class LocatorText {
  final String? before;    // 定位点之前的文本
  final String? highlight; // 定位点的文本内容
  final String? after;     // 定位点之后的文本
}
```

## HREF → chapterIndex 映射

### 方法

```text
ReadingOrder 列表（来自 Publication.readingOrder）:
  [0] Link(href="OEBPS/title.xhtml")
  [1] Link(href="OEBPS/chapter1.xhtml")
  [2] Link(href="OEBPS/chapter2.xhtml")
  ...

Locator.href = "OEBPS/chapter1.xhtml#section1"

1. 从 href 中去除 #fragment → "OEBPS/chapter1.xhtml"
2. 在 readingOrder 列表中查找：
   - 完全匹配 href
   - 或匹配 href 的 basename（如 "chapter1.xhtml"）
   - 或匹配 href 的路径后缀
3. 匹配到的索引即为 chapterIndex
```

### 已知问题

- 某些 EPUB 的 readingOrder 结构与用户感知的"章"不完全一致（如包含版权页、目录页等）
- `href` 路径格式可能有前导 `/`，需要 normalize
- 同一资源可能因 `#fragment` 不同被视为不同位置但属于同一 readingOrder 条目

## LocatorText → charOffset 映射

### 正向映射（Locator → charOffset）

**方法 A：纯文本匹配（推荐）**

```text
1. 从 LocatorText 提取上下文字符串：
   context = before + highlight + after
2. 在 readingOrder[chapterIndex] 的 plainText 中查找 context
3. 如果找到唯一匹配 → charOffset = 匹配位置 + before.length
4. 如果找到多个匹配 → 使用 cssSelector/domRange 缩小范围
5. 如果未找到 → 使用 progression 估算
```

**方法 B：CSS Selector + offset（精确）**

```text
1. 使用 locations.cssSelector 定位到 DOM 元素
2. 使用 domRange.start.offset 获取元素内的文本偏移
3. 转换为 plainText 中的 charOffset
   需要：DOM 结构与 plainText 的映射关系
```

### 反向映射（charOffset → Locator）

```text
1. chapterIndex → readingOrder[index].href
2. 在对应资源的 plainText 中，获取 charOffset 附近的文本上下文
   取 before = plainText[max(0, offset-50)..offset]
   取 highlight = plainText[offset..offset+20]
   取 after = plainText[offset+20..offset+100]
3. 构造 Locator：
   href = readingOrder[index].href
   type = "application/xhtml+xml"
   text = LocatorText(before, highlight, after)
   locations = Locations(totalProgression: chapterProgress)
```

### 精度评估

| 场景 | 预期精度 | 说明 |
| ------ | ---------- | ------ |
| plainText 唯一匹配 | ✅ 字符精确 | 上下文字符串在全文唯一 |
| plainText 重复匹配 | ⚠️ 段落级 | 使用 cssSelector + offset 精确定位 |
| 无 text 字段 | ⚠️ 章级 | 回退到 progression 百分比估算 |
| 跨引擎切换 (Builtin→Readium) | ⚠️ 段落级 | 构造 LocatorText 上下文，Readium 尝试匹配 |
| 跨引擎切换 (Readium→Builtin) | ⚠️ 段落级 | 提取 before/highlight/after 在 Builtin plainText 中搜索 |
| emoji/代理对 | ⚠️ 需测试 | UTF-16 offset 需确保一致 |
| 重复文本段落 | ⚠️ 段落级 | 需 cssSelector 辅助消歧 |
| HTML 空白折叠差异 | ⚠️ 需测试 | Readium DOM 文本 vs IR plainText 空白处理可能不同 |

## 跨平台 Locator 格式

当前分析仅限于 Dart 侧数据模型。Android 与 iOS 的 Locator JSON 结构由 Readium SDK 原生组件生成：

- **Android**: RSS (Kotlin Readium SDK) → MethodChannel → Dart
- **iOS**: Readium Swift SDK → MethodChannel → Dart

Dart 端的 `Locator.fromJson` 已处理两种源，格式应一致。如果 iOS 返回的 Locator 缺少字段（如 `before/highlight/after`），需要降级处理。

**策略**：如果跨平台 Locator 格式不一致，引擎 hint 应分平台保存。

## 已知限制

1. **无标准化字符级偏移**：Readium Locator 本质上是 DOM 模型，不是字符模型。`domRange.start.offset` 是元素内文本偏移，不是全文 charOffset。

2. **text 字段缺失**：某些 EPUB/平台可能不提供 `before/highlight/after` 文本上下文，此时只能使用 `totalProgression` 降级。

3. **样式 DOM vs 文本 DOM**：CSS 注入（如字距、段距）可能改变 DOM 渲染，但不影响 DOM 文本内容，因此不影响 Locator/text。

4. **EPUB 指纹变化**：EPUB 重新打包后 `href` 路径可能变化，`readingOrder` 索引可能变化，需验证指纹匹配。

## 推荐回退策略

```text
Locator 恢复：
  ├─ 匹配 publicationFingerprint → 尝试 goToLocator(Locator)
  │    ├─ 成功 → ✅ 精确恢复
  │    └─ 失败 → 降级到 href + progression
  └─ 不匹配 → 丢弃 Locator，使用 chapterIndex + charOffset
              →
              在当前的 readingOrder 中找到对应的 href
              构造 goToLocator 或 skipToPrevious/Next 到目标章
```

## 最低可接受方案

- 同章恢复必须成功（同一 EPUB 同一章节内）
- 字符偏差需要在明确阈值内（推荐：不超过 1 个段落）
- 书签恢复不能跳错章
- 跨引擎切换允许落在相邻段落，但不得只恢复到全书百分比
