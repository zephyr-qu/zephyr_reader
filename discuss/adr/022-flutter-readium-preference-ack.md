# ADR-022：等待 flutter_readium 的原生 EPUB 偏好提交

- **状态**：已接受
- **日期**：2026-08-23
- **关联**：[ADR-021](./021-flutter-readium-migration.md)

## 背景

阅读模式切换通过 `EPUBPreferences.scroll` 进入 Readium 原生 Navigator。应用层已经串行
调用 `setEPUBPreferences`，但 `flutter_readium` 的 `ReadiumReaderWidget` 只发起
MethodChannel 调用便立即返回；同时，Readium 当前分页器对运行时文本对齐偏好不会可靠地
重新排版。若业务层不等待原生提交完成，对齐选项会造成“点击有反馈但正文不变化”的误导。

## 决策

在仓库内保留 `flutter_readium` 0.3.1 的最小可复现补丁，并通过
`dependency_overrides` 使用它：

1. `ReadiumReaderWidget.setEPUBPreferences` 更新本地模式状态并触发 Widget 重建。
2. 等待 `_channel.setEPUBPreferences` 完成后再返回，让业务层的偏好队列真正覆盖原生提交。
3. 阅读模式切换时预置/提交新的偏好并重建一次 `ReadiumReaderWidget`，通过当前
   Locator 恢复位置。允许保留文本对齐设置；业务层必须等待原生偏好提交完成后，才能
   将本次设置更新视为成功。
4. 修补本地插件 Android Platform View 的生命周期：只有仍是当前 reader 的旧视图才可以
   关闭共享 Navigator，避免替换视图时旧视图 dispose 误关新视图。
5. 不修改 Readium Kotlin/Swift toolkit，不增加 Flutter 长滚动或跨 spine 拼接逻辑。

该副本保留原插件许可证和源码结构；后续上游修复后，可删除 override，恢复 hosted 依赖并
用同一组阅读模式回归测试验证。

## 后果

- 分页和滚动切换的完成语义一致；文本对齐属于允许的排版设置，并受原生提交确认约束。
- 依赖副本需要随 `flutter_readium` 升级维护；升级时必须重新确认该补丁仍然存在或已被上游吸收。
- Readium 原生滚动仍按章节资源工作，不承诺跨 spine 的长滚动。
