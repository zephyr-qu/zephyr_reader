# R11: 排版设置映射

## Goal

`ReadingPreferences` → `EPUBPreferences` 纯映射模块。只使用 flureadium 已支持的 preference。

## Requirements

### 映射表

| 统一设置 | Readium EPUBPreferences | 备注 |
| --- | --- | --- |
| 字号 | fontSize | 即时生效 |
| 行距 | lineHeight | 即时生效 |
| 字体 | fontFamily | |
| 页边距 | Readium page margins | |
| 主题 | light/sepia/dark | 背景+文字颜色切换 |
| 文字对齐 | text alignment | |
| 阅读模式 | scroll/paginated | 切换后翻页行为改变 |
| 亮度 | Flutter BrightnessMask | 应用层实现 |

### 规则

- 只使用 flureadium 已支持的 preference
- 不支持项依据 capability 禁用
- 设置失败必须显示错误，不能静默忽略
- 重排前保存 Locator，重排后恢复
- 配置变更使用 debounce
- 旧配置变更不得覆盖新配置

## Acceptance Criteria

- [ ] 字号、行距、主题即时生效
- [ ] 设置后不跳章
- [ ] 设置后恢复位置在可接受范围
- [ ] pagination/scroll 切换稳定
- [ ] Android/iOS 表现一致或显式记录差异
- [ ] 检查点：`feat: map shared reader preferences to readium`
