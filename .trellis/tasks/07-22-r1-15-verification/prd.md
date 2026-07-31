# R15: 全量验证与正式启用

## Goal

全量质量门禁通过后正式启用 Readium 作为 EPUB 默认后端。

## Requirements

### Backend contract tests

同一套行为契约测试两个 backend：

- open / ready / failed / close 幂等
- previous / next / goToChapter / goToPosition
- preference update / 状态快照顺序 / 快速切书
- close 后不得继续发事件

### 位置映射测试

- 中文、emoji、UTF-16 surrogate pair、重复文本
- HTML 空白折叠、图片占位符、fragment href
- Locator 缺少 text、Locator 损坏、EPUB 文件变化
- Builtin → Readium → Builtin round-trip

### Widget tests

- 同一壳层注入 Builtin backend 和 Readium fake backend
- capability 控制设置项
- 加载/错误/重试界面一致
- 点击区域发送正确 command

### Android 真机验证（20+ 用例）

- TXT 正常打开；EPUB 默认 Readium；EPUB 手动切 Builtin
- 关闭并恢复；杀进程恢复
- 目录跳转；搜索结果跳转；添加/删除书签
- 字号/行距/主题即时生效；pagination/scroll 切换
- 快速连续翻页；快速返回书架；连续打开两本 EPUB
- 后台/前台恢复；横竖屏切换
- 图片密集 EPUB；复杂 CSS EPUB；损坏 EPUB 错误和回退

### 最终门禁

- `flutter analyze --fatal-infos`
- UI 层零 `flureadium` import
- 生产路径零 PoC 引用
- 所有失败可见，无静默降级

## Acceptance Criteria

- [ ] Backend contract tests 通过
- [ ] 位置映射全面覆盖
- [ ] Widget tests 验证壳层统一性
- [ ] Android 真机 20+ 用例全部通过
- [ ] 最终门禁零告警
- [ ] 检查点：`feat: enable readium as the default epub backend (R15)`
