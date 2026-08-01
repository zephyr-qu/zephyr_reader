# ADR-020：当前路线收敛为 EPUB Readium MVP

- **状态**：已通过
- **日期**：2026-07-31
- **取代**：[ADR-019](./019-engine-unification.md) 作为当前实施路线
- **保留**：ADR-019 作为未来重新评估双引擎时的历史设计

## 背景

双引擎统一方案需要同时维护 Builtin、Readium、位置桥、能力模型和统一壳层，
超出当前 MVP 的验证目标。当前分支已经删除 Builtin 阅读 UI，并以 flureadium
直接承载 EPUB 正文。继续让路线文档声称“双引擎正在接入”会造成实现、测试和验收标准分叉。

## 决策

当前产品路线收敛为 **EPUB-only Readium MVP**：

1. 阅读入口只接受 EPUB；TXT 阅读不属于当前 MVP。
2. 正文只由封装后的 `ReadiumReaderWidget` 渲染，不恢复 Builtin 渲染链。
3. 页面保留一套 Readium 壳层，接入目录、翻页、进度、排版设置、主题和基础 TTS。
4. MVP 位置恢复使用按 `bookId` 保存的 Readium Locator；不保存页码。
5. 原生 viewport `onReady` 是应用设置、订阅状态和发布 ready 的硬门槛。
6. 打开、重试和关闭必须具备明确状态；关闭必须幂等，退出后不得回写 UI。

## 当前 Must

- EPUB 文件打开并稳定渲染正文
- 原生 viewport ready 后应用字号与主题
- 目录展示、当前章高亮和目录跳转
- 上一页、下一页、阅读进度
- Locator 节流保存、退出 flush、重新打开恢复
- 错误可见且可重试
- 页面返回、工具栏显隐和设置入口

## 当前 Won't

- TXT/Builtin 阅读器
- 双引擎策略、SessionFactory 和跨引擎切换
- Locator 与 `chapterIndex + charOffset` 双向映射
- PDF、漫画、账号同步
- 书签、批注、搜索、生词等完整学习功能接入

## 后果

- 优点：缩短可验证链路，MVP 可以围绕真实 EPUB 原生渲染做设备回归。
- 代价：ADR-001/017 的 charOffset 位置契约暂不覆盖 MVP 阅读恢复；未来恢复
  搜索、笔记或多引擎时必须重新引入稳定位置映射。
- 迁移：ADR-019 与 R1-R15 不再是当前执行计划，不删除其文档和历史提交。

## 退出标准

- Android/iOS 至少各完成纯文本、含图和复杂 CSS EPUB 的打开与翻页回归。
- 快速退出、连续重试、旋转/后台恢复不产生崩溃或旧事件回写。
- 字号、主题、目录跳转和 Locator 恢复在真机生效。
- `flutter analyze --fatal-infos` 与 EPUB 阅读定向测试通过。
