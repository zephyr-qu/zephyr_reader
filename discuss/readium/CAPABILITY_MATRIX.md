# Readium 能力评估矩阵

> 基于 flureadium 0.13.2 API 分析和 feature/readium-poc 分支 PoC 代码分析
> 状态标记：✅ 已确认 | ⚠️ 部分支持 | ❌ 不支持 | ? 需真机验证

## 基础能力

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| EPUB 打开 | ✅ | ✅ | ✅ | `openPublication()` 已验证工作 |
| TXT 格式 | ✅ | ❌ | ❌ | Readium 不处理 TXT |
| PDF | ❌ | ✅ (sketch) | ✅ (sketch) | `renderFirstPage()` 可用，但非本期目标 |
| 分页 (pagination) | ✅ | ✅ | ? | Android PoC 已验证分页正常 |
| 连续滚动 | ✅ | ✅ | ? | `verticalScroll` 偏好设置在 `EPUBPreferences` 中 |
| 翻页动画 | ✅ | ✅ (native) | ? | Readium 使用原生 WKWebView/AndroidWebView 自带动画 |
| 目录导航 | ✅ | ✅ | ? | `Publication.tableOfContents` + `locatorFromLink` + `goToLocator` |
| 前后章节 | ✅ | ✅ | ? | `skipToNext()` / `skipToPrevious()` 已实现 |
| 返回后恢复 | ✅ | ? | ? | 需真机验证 `closePublication` → `openPublication` + `goToLocator` |

## 位置能力

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| 当前 Locator | ✅ | ✅ | ? | `getCurrentLocator()` 可用 |
| Locator JSON 序列化 | ✅ | ✅ | ? | `Locator.fromJson/toJson` 已验证 |
| goToLocator | ✅ | ✅ | ? | `goToLocator(Locator)` + `goByLink` |
| 文本上下文 (LocatorText) | N/A | ✅ | ? | `before/highlight/after` 字段可用 |
| Progression | N/A | ✅ | ? | `locations.totalProgression` 已验证 |
| CSS Selector | N/A | ✅ | ? | `locations.cssSelector` 可用 |
| DOM Range | N/A | ✅ | ? | `locations.domRange` 可用 |
| Fragment 位置 | N/A | ✅ | ? | `locations.fragments` 可用 |
| getLocatorFragments | N/A | ✅ | ? | 可获取片段级精确 Locator |
| isLocatorVisible | N/A | ✅ | ? | 可检查 Locator 是否可见 |

## 渲染控制

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| 字号 | ✅ | ✅ | ? | `EPUBPreferences.fontSize` |
| 字体族 | ✅ | ✅ | ? | `EPUBPreferences.fontFamily` |
| 字重 | ✅ | ✅ | ? | `EPUBPreferences.fontWeight` |
| 行距 | ✅ | ⚠️ | ? | `EPUBPreferences` 无 `lineHeight` 字段；需 CSS 注入 |
| 背景色 | ✅ | ✅ | ? | `EPUBPreferences.backgroundColor` |
| 文字颜色 | ✅ | ✅ | ? | `EPUBPreferences.textColor` |
| 页边距 | ✅ | ✅ | ? | `EPUBPreferences.pageMargins` |
| 字间距 | ✅ | ❌ | ? | `EPUBPreferences` 无此字段 |
| 段间距 | ✅ | ❌ | ? | `EPUBPreferences` 无此字段 |
| 段首缩进 | ✅ | ❌ | ? | `EPUBPreferences` 无此字段 |
| 竖排 | ❌ | ❌ | ? | 两引擎均不原生支持 |
| 横排 RTL | ✅ | ✅ | ? | `readingProgression` 在 publication 中 |

## Decorations / 高亮

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| applyDecorations | ✅ | ✅ | ? | `applyDecorations(id, list)` 可用 |
| DecorationStyle.highlight | ✅ | ✅ | ? | 背景高亮样式 |
| DecorationStyle.underline | ✅ | ✅ | ? | 下划线样式 |
| 高亮颜色自定义 | ✅ | ✅ | ? | `ReaderDecorationStyle.tint` |
| 删除 decoration | ✅ | ✅ | ? | 传空列表清除 |
| 选区创建 | ✅ | ? | ? | 需要原生选区事件支持 |

## TTS / 音频

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| TTS 启用 | ✅ (应用层) | ✅ | ? | `ttsEnable()` 可用 |
| 播放/暂停/停止 | ✅ | ✅ | ? | `play/pause/stop/resume` |
| 前后句跳转 | ✅ | ✅ | ? | `next/previous` |
| TTS 语音选择 | ✅ | ✅ | ? | `ttsGetAvailableVoices` + `ttsSetVoice` |
| TTS 高亮同步 | ✅ | ✅ | ? | `setDecorationStyle` |
| TTS 从指定位置开始 | ✅ | ✅ | ? | `play(fromLocator)` |
| 跨章连续 TTS | ✅ | ❌ | ? | 需应用层编排，Readium 原生 stop 在章尾 |

## 导航配置

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| 边缘点击导航 | ✅ | ✅ | ? | `ReaderNavigationConfig.enableEdgeTapNavigation` |
| 滑动导航 | ✅ | ✅ | ? | `ReaderNavigationConfig.enableSwipeNavigation` |
| 禁用文字选择 | ✅ | ✅ | ? | `ReaderNavigationConfig.disableTextSelection` |
| 禁用双击缩放 | N/A | ✅ | ? | `ReaderNavigationConfig.disableDoubleTapZoom` |

## 生命周期

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| close() 幂等 | ✅ | ✅ | ? | `closePublication()` 已验证 |
| 切书取消旧状态 | ✅ | ? | ? | 需验证订阅管理 |
| 快速退出不泄漏 | ✅ | ? | ? | Platform View 释放需验证 |
| 重复打开不同 EPUB | ✅ | ? | ? | 不串状态需验证 |
| onReady 回调 | N/A | ✅ | ? | Platform View 创建后触发 |
| Stream 订阅 | N/A | ✅ | ? | `onReaderStatusChanged` / `onTextLocatorChanged` / `onErrorEvent` |
| 横竖屏旋转 | ✅ | ✅ | ? | `OrientationHandlerMixin` 内置处理 |
| 后台恢复 | ✅ | ? | ? | `ReaderLifecycleMixin` 处理 |
| WakeLock | N/A | ✅ | ? | `WakelockManagerMixin` 内置 |

---

## 总结

### 已确认可用的能力

- EPUB 打开/关闭
- 左右翻页 (goLeft/goRight)
- 前后章节 (skipToNext/skipToPrevious)
- Locator 获取与恢复 (getCurrentLocator/goToLocator)
- 目录跳转 (tableOfContents + locatorFromLink)
- 字号/字体/字重/背景色/文字颜色 (EPUBPreferences)
- 高亮 decorations (applyDecorations)
- 页边距 (pageMargins)
- 导航配置 (边缘点击/滑动/禁用选择)
- TTS 基本能力 (enable/play/pause/stop)
- Platform View 生命周期 (onReady/close/dispose)

### 需要真机验证的能力

- iOS 全部能力
- 连续滚动 (verticalScroll)
- 关闭后 Locator 恢复精度
- 选区事件和精确 Locator
- 快速连续翻页稳定性
- 重复打开不同 EPUB 不串状态
- 后台恢复后位置保持
- Platform View 释放/泄漏检查

### 明确不支持的能力

- 字间距 / 段间距 / 段首缩进（EPUBPreferences 无对应字段）
- 这些设置需要通过 CSS 注入或其他手段降级处理
