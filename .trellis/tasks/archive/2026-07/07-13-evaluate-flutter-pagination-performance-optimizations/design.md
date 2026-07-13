# 评估报告：Flutter 分页性能优化方向

## 方向 A：Isolate fragment 装箱

### 可行性

**结论：✅ 技术上可行，但工程成本高**

#### 发现

1. **标准 `Isolate` + `ParagraphBuilder`** — ❌ 不可行。`dart:ui` API（包括 `ParagraphBuilder`）不能直接在普通 isolate 中使用，会抛 `native function not found`（[flutter#53985](https://github.com/flutter/flutter/issues/53985)，已开 10 年）。
2. **`dart_ui_isolate` 包** — ✅ 可用。通过 `FlutterEngineGroup` 为 isolate 创建独立的 Flutter 引擎，使其能调用 `dart:ui` 全部 API（包括 `ParagraphBuilder`）。iOS/Android 支持（macOS 不支持）。
3. **`FlutterEngineGroup` 原生** — ✅ 框架原生支持。`FlutterEngineGroup` 可以共享引擎资源创建轻量 isolate，但需要用 platform channel 做 IPC，开发成本较高。
4. **`flutter_isolate` 包** — ✅ 也支持 `dart:ui` 和 platform plugins，但内存比 `FlutterEngineGroup` 重。

#### 预估收益

- 当前主 isolate 装箱：大 TXT（~10万字符）大量页约 **10–30ms**（blocked UI）。
- Isolate 装箱：主 isolate **0ms**（隔离），通过 `SendPort` 传结果回来（约 0.5–2ms 序列化）。
- 收益：**消除装箱 Jank**，但首屏速度不提升（首屏必须在主 isolate 做）。
- 收益仅对大章 expand 阶段（首屏后的后台补全）有意义。

#### 风险

| 风险 | 级别 | 说明 |
| ------ | ------ | ------ |
| 包依赖 | 🟡 | 引入 `dart_ui_isolate`，维护成本 |
| 内存 | 🟢 | FlutterEngineGroup 比全引擎 isolate 轻量 |
| 序列化开销 | 🟡 | `PackedPage[]` 跨 isolate 传输需要序列化/反序列化（~0.5-2ms） |
| Platform plugins | 🟢 | 排版 isolate 不需要 plugins |
| 取消 | 🟡 | isolate 中 `isCancelled` generation 门控需要额外 IPC |
| macOS | 🟢 | 移动端优先，macOS 排版可在主 isolate 做 |

### 方向 A 结论

**No-go for now**。理由：

- 当前大章装箱 10–30ms，用 `yieldEveryBlocks` 已可让出主 isolate，用户感知不到 Jank。
- 工程成本（添加包、entry-point 注解、跨 isolate 序列化、取消逻辑）当前收益不成比例。
- 首屏路径无法受益（TextPainter 必须在主 isolate 渲染树中使用）。
- **推荐条件**：当用户报告大章翻页卡顿、或 instrumentation 显示装箱 > 50ms 时重新评估。

---

## 方向 B：PackedPage 持久化缓存

### 可行性

**结论：✅ 技术上容易，但收益有限**

#### 设计

- 缓存键：`(bookId, chapterIndex, configHash) → List<PackedPage>`
- 存储位置：本地文件（`shared_preferences` / 文件 IO）或复用 Rust sled（需新增 FRB API）
- 序列化：`PackedPage` + `PackedBlockSlice` 需加 `toJson`/`fromJson`（约 100 行代码）
- 缓存命中：`configHash` 自动处理无效化（字号/行高/字体/边距任一变化 → hash 变 → miss）
- 缓存淘汰：LRU（最多保留最近 N 章）

#### 预估收益

- 当前重装耗时：`_paginateFromIr` 中 `getChapterContentIr`（FFI ~1-3ms） + TextPainter 装箱（同章 ~5-15ms）
- 缓存命中后：从本地文件读 ~1-3ms，跳过 FFI + 全部 TextPainter
- 收益：**节省 ~5-15ms** 每次翻章

#### 风险

| 风险 | 级别 | 说明 |
| ------ | ------ | ------ |
| 序列化大小 | 🟢 | PackedPage 主要是 String + int，压缩后每章预估 10-50KB |
| 缓存无效化 | 🟢 | configHash 天然解决 |
| 首次 miss | 🟢 | 同 current behavior |
| sled 可用性 | 🟢 | 已有 sled KV，需加 Dart→Rust→sled 路径 |

### 方向 B 结论

**No-go for now**。理由：

- 同章连续翻页的缓存收益 ~5-15ms，但翻章不是高频操作（用户花几分钟读一章）。
- 用户改变字号后 hash 变化 → miss，常见的"试试大字"场景得不到任何缓存收益。
- 序列化/反序列化 + 文件 IO 本身也有 ~1-3ms 开销。
- **推荐条件**：当 instrumentation 显示同 config 反复重装同章成为热点时重新评估。

---

## 方向 C：保持现状

### 理由

1. 当前首屏装箱 **< 5ms**（2000 chars），用户无感知。
2. 大章 expand 使用 `yieldEveryBlocks` + `onProgress` hook → 首屏已可翻后后台逐块补全，不阻塞 UI。
3. 无用户反馈大章卡顿。
4. 工程复杂度 vs 收益不匹配。

### 量化阈值（何时重新评估）

| 指标 | 阈值 |
| ------ | ------ |
| 主 isolate 装箱耗时 | > 50ms（当前 ~10-30ms） |
| 首屏耗时 | > 16ms（一帧）（当前 ~3-5ms） |
| 用户报告 | 翻页/翻章卡顿 |
| instrumentation | 同 config 重装占比 > 20% 的翻章 |

## 推荐

```
现状（方向 C）←—— 当前 ——→ 未来阈值触发时
                   可考虑 isolate 装箱（A）
                   或 PackedPage 缓存（B）
```

**保持现状，不投入工程资源。** 如果未来 instrumentation 或用户反馈触发阈值，优先方向 A（isolate fragment 装箱）——收益更大，且 `dart_ui_isolate` 生态随时间更成熟。
