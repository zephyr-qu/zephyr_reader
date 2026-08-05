# ADR-021：用 flutter_readium 替换 flureadium

- **状态**：已完成（代码已切换，真机回归仍按发布阶段执行）
- **日期**：2026-08-03
- **取代**：ADR-020 中对 flureadium 的实现依赖描述
- **保留**：ADR-020 的 EPUB-only MVP 范围和 Locator 位置真理

## 背景

此前 EPUB MVP 直接使用 `flureadium`。该依赖的能力范围包含较多车载、音频和后台播放场景，
与 Zephyr Reader 当前的手机/平板 EPUB 阅读目标不一致。原有接入集中在 Readium ViewModel、
内容 Widget、壳层和测试中，尚未形成需要双引擎兼容的深层业务耦合。

## 决策

直接将依赖替换为 `flutter_readium ^0.3.1`，不保留运行时双引擎或 fallback。

1. 保留 EPUB-only Readium MVP、现有 Flutter 壳层和按 `bookId` 保存的 Locator。
2. 使用 `ReadiumReaderWidget` 作为正文渲染器。
3. 使用 `onReaderStatusChanged`、`onTextLocatorChanged` 和 `onErrorEvent` 驱动生命周期与进度。
4. `EPUBPreferences.fontSize` 使用新包的比例值（`1.0` 表示 100%），`scroll` 表示垂直滚动。
5. 章节边界跳转按出版物 `readingOrder` 计算，不依赖旧的无参数跳章 API。
6. 滚动模式支持上下双向跨阅读资源；滚动到边界后通过 Locator 跳转，不增加上下章按钮。
7. 不承诺跨 spine 的真正连续滚动；章节边界处允许出现一次显式资源切换。

## 不在本次范围

- 车载或 Android Auto 能力迁移
- PDF、CBZ、DIVINA、LCP
- Web 端初始化和 JS bundle
- macOS 原生阅读支持
- Locator 持久化格式重写
- Readium 业务适配层的全面重构

## 后果

优点：依赖边界更贴合移动 EPUB 阅读，移除旧包的导航配置和车载专用耦合，并获得统一的
Readium 状态/Locator 事件流。

代价：新 Widget 不再提供旧的 `onReady`、`onLocatorChanged`、`onTap` 回调，生命周期、点击
和测试必须改为事件流与 Flutter 外层手势；字号和导航 API 也需要适配。

## 验收标准

- `pubspec.lock` 不再包含 `flureadium`，改为 `flutter_readium`
- `lib/` 和 `test/` 不再导入 `flureadium`
- EPUB 定向测试通过
- `dart analyze --fatal-infos` 无迁移引入的编译错误
- Android 真机完成打开、分页、滚动、TOC、Locator 恢复和设置回归
- 迁移失败时不得静默丢失 Locator 或吞掉部分初始化错误

## 修订记录（2026-08-05：滚动模式实现方式）

- **废止**决策第 6 条中"滚动到边界后通过 Locator 跳转"的实现方式（Flutter 手势 hack：
  `Listener` 记录 pointer down/up + 200ms 竞态检测 + `goToLocator` 硬跳章）。该实现抢在原生
  滚动布局生效前消费手势，导致章节内无法连续滚动、一滑就跳章。
- **改为**：
  1. `ReadiumViewModel.open()` 在 `openPublication` 前调用 `setDefaultPreferences(
     EPUBPreferences(scroll: ...))`，原生 WebView 首次创建即处于正确布局
     （scroll / pagination），消除"先分页后热切 scroll"的时序竞争。
  2. 删除 Flutter 层滚动手势 hack（`advanceFromScrollBoundary` /
     `retreatFromScrollBoundary` / `_navigateScrollBoundary` 及 `Listener` 指针分支），
     章节内滚动完全交给原生 WebView（`scroll:true`）。
  3. 章节边界衔接改由原生驱动：scroll 模式滚到资源末尾/开头由原生 ViewPager /
     `goForwardVertical` / `goBackwardVertical` 路径衔接，Flutter 侧不再硬跳 `goToLocator`。
- 决策第 7 条不变：仍不承诺跨 spine 无缝连续滚动，章节边界允许一次显式资源切换。
- 分页模式行为不受影响（横向滑动翻页、tap 显隐控制栏、边缘点击保持现状）。
