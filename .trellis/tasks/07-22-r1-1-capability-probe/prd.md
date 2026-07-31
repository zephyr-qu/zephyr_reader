# R1-1：Readium 能力探针

## Goal

在真机上系统验证 Readium（flureadium）的关键能力，产出两份文档：

1. `discuss/readium/CAPABILITY_MATRIX.md` — 能力评估矩阵
2. `discuss/readium/LOCATOR_MAPPING_REPORT.md` — Locator 格式与映射报告

基于验证结果形成 Go/No-Go 决策：是否继续正式并轨。

## Background

PoC 阶段已在 Android 上成功渲染 EPUB（见 `feature/readium-poc` 分支），但以下关键能力尚未系统验证：

- Locator 恢复精度与跨平台一致性
- 目录跳转可靠性
- 字号/行距/主题即时更新
- decorations API 可用性
- 选区事件的精确度
- 快速翻页和状态管理稳定性

这些能力直接影响位置桥设计（R1-2）和 Adapter 实现（R1-4）。

## Requirements

### 1. 代码分析（无需真机）

- 读取 flureadium 0.13.2 的类型定义，确定所有公开 API
- 分析 ReadiumViewModel 当前实现，标注已知能力
- 分析现有 PoC 代码，标注已知限制和 bug
- 分析 `EPUBPreferences` 支持哪些设置项
- 分析 `Locator` 数据结构（所有字段）
- 分析 `Publication.tableOfContents` 结构
- 分析 `applyDecorations` 接口
- 确定原生 Platform View 的生命周期行为

### 2. 真机验证矩阵（需要用户执行）

#### 2A. 基础渲染（3 类 EPUB）

| 测试 | 说明 | 判定标准 |
| ------ | ------ | ---------- |
| 纯文本 EPUB | 无 CSS/图片的简单 EPUB | 正常渲染、可翻页 |
| 图片密集 EPUB | 每页多张图的 EPUB | 图片正常加载显示 |
| 复杂 CSS EPUB | 含字体/布局/样式的 EPUB | 排版可读、无布局溢出 |

#### 2B. Locator 能力

| 测试 | 说明 | 判定标准 |
| ------ | ------ | ---------- |
| 获取当前 Locator | `getCurrentLocator()` 返回非空 | 字段完整 |
| Locator JSON 序列化 | Locator 可序列化为 JSON 后反序列化 | round-trip 不变 |
| 关闭后 Locator 恢复 | 保存 Locator → 关闭 → 重新打开 → goToLocator | 位置几乎一致 |
| 目录跳转 | Publication.tableOfContents → goToLocator | 跳转正确章 |
| 不同 EPUB Locator 格式 | 对比 3 类 EPUB 的 Locator 字段 | 结构一致 |

#### 2C. 偏好设置即时更新

| 测试 | 说明 | 判定标准 |
| ------ | ------ | ---------- |
| 字号 | EPUBPreferences.fontSize | 即时生效 |
| 行距 | EPUBPreferences.lineHeight | 即时生效 |
| 主题 | EPUBPreferences.theme | 背景/文字颜色切换 |
| pagination↔scroll | EPUBPreferences.scrollMode | 切换后翻页行为改变 |
| 横竖屏旋转 | 设备旋转 | 布局自适应 |

#### 2D. Decorations 能力

| 测试 | 说明 | 判定标准 |
| ------ | ------ | ---------- |
| applyDecorations 基本调用 | 传入 decoration 列表无错误 | 不抛异常 |
| 高亮 decoration 可见 | decoration 在页面上显示 | 渲染正确 |
| 删除 decoration | 清除 decoration 列表 | 高亮消失 |

#### 2E. 选区事件

| 测试 | 说明 | 判定标准 |
| ------ | ------ | ---------- |
| 选区回调触发 | 选中文字后有回调 | 收到 Locator |
| Locator 精确度 | Locator 是否包含精确位置 | 有文本上下文 |
| 选区跨平台一致 | Android vs iOS | 结构无差异 |

#### 2F. 稳定性

| 测试 | 说明 | 判定标准 |
| ------ | ------ | ---------- |
| 连续快速翻页 | 5+ 页/秒持续 10 秒 | 不崩溃、不串页 |
| 返回后 native view 释放 | pop → 检查 memory | 不泄漏 |
| 重复打开不同 EPUB | 开 A → 关 → 开 B → 关 → 开 A | 不串状态 |
| 后台恢复 | home → 暂停 → 恢复 | 位置不变 |

### 3. 产出文档

#### CAPABILITY_MATRIX.md

每项能力标注：

| 能力 | Builtin | Readium (Android) | Readium (iOS) | 备注 |
| ------ | --------- | ------------------- | --------------- | ------ |
| 分页 | ✅ | ? | ? | |
| 连续滚动 | ✅ | ? | ? | |
| 精确位置 | ✅ | ? | ? | |
| 文本选区 | ✅ | ? | ? | |
| 高亮 | ✅ | ? | ? | |
| TTS | ✅ | ? | ? | 应用层 |
| 自定义字体 | ✅ | ? | ? | |
| 字间距 | ✅ | ? | ? | |
| 段间距 | ✅ | ? | ? | |
| 段首缩进 | ✅ | ? | ? | |

#### LOCATOR_MAPPING_REPORT.md

- Locator 完整结构分析
- href → chapterIndex 映射方法
- 文本 quote → charOffset 精度评估
- 跨平台 Locator 格式差异（如有）
- 已知限制

## Acceptance Criteria

- [ ] CAPABILITY_MATRIX.md 已创建，包含所有能力项
- [ ] 代码分析部分完成（flureadium API 枚举、已知限制记录）
- [ ] 真机测试说明提供给用户
- [ ] LOCATOR_MAPPING_REPORT.md 已创建
- [ ] Go/No-Go 决策已完成

## Notes

- 代码分析部分无需真机，我能完成
- 真机测试需要用户在 Android/iOS 上运行
- 产出文档路径：`discuss/readium/CAPABILITY_MATRIX.md` 和 `discuss/readium/LOCATOR_MAPPING_REPORT.md`
- R1-1 不修改任何生产代码
