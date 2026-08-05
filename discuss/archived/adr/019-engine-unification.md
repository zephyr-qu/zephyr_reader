# ADR-019：阅读器引擎统一 — 双引擎共用一个阅读入口

> **已取代**：本 ADR 是历史双引擎方案。当前路线由 [ADR-020](./020-epub-readium-mvp.md) 取代，依赖迁移由 [ADR-021](./021-flutter-readium-migration.md) 记录。

- **状态**：已被 [ADR-020](./020-epub-readium-mvp.md) 取代（保留为历史设计）
- **日期**：2026-07-19（初稿）/ 2026-07-22（重写为 Phase R1 方案）
- **关联**：[ADR-006](./006-rust-flutter-division.md)、[DOMAIN_MODEL.md](../DOMAIN_MODEL.md)、[ROADMAP.md](../ROADMAP.md)、[READING_BOUNDARIES.md](../READING_BOUNDARIES.md)
- **取代**：本 ADR 早期草稿（大型 `ReaderEngine` 接口方案已废弃）

---

## 问题

项目已有两条阅读器实现路径：

| 引擎 | 技术栈 | 适合格式 | 功能完整度 |
| ------ | -------- | --------- | ----------- |
| **Builtin（自研）** | Rust IR → Flutter `TextPainter` | TXT + EPUB（自研渲染管线） | 完整 |
| **Readium（正式）** | `flureadium` 封装 Readium SDK | EPUB（原生渲染器） | 正式 |

当前两条路径完全隔离：

- 两套页面入口（`ReaderPage` vs `ReadiumReaderPage`）
- 两套壳层
- 两套 ViewModel
- 两套路由

用户在书架点开 EPUB 书籍，必须由代码/路由硬编码决定走哪条路径。两条路径的 UI 外观、工具栏、交互方式都不一致。

**目标**：一个统一的阅读入口，引擎差异对用户完全透明。

---

## 决策

### 1. 三小接口而非一个大接口

**原方案（已废弃）**：定义大型 `ReaderEngine` 接口，内含十几个 Signal 和 `Widget buildContent()`。

问题：

- 把 `PaginationEngine`、`IR`、`ScrollEngine` 等 Builtin 内部概念强加给 Readium
- 接口过于臃肿，Readium 适配大量方法无合理实现
- 接口设计先于能力验证

**现方案**：拆分为三个迷你接口，每个只负责自己的 seam。

#### 1a. 阅读后端 — `ReadingBackend`

```dart
abstract interface class ReadingBackend {
  ReadingBackendKind get kind;
  ReadingCapabilities get capabilities;

  ValueListenable<ReadingSnapshot> get snapshot;

  Future<void> open(ReadingOpenRequest request);
  Future<void> execute(ReadingCommand command);
  Future<void> applyPreferences(ReadingPreferences preferences);
  Future<void> close();
}
```

所有导航统一为 `ReadingCommand` sealed class：

```dart
sealed class ReadingCommand { const ReadingCommand(); }

final class PreviousPage extends ReadingCommand {}
final class NextPage extends ReadingCommand {}
final class PreviousChapter extends ReadingCommand {}
final class NextChapter extends ReadingCommand {}
final class GoToPosition extends ReadingCommand { final ReadingPosition position; }
final class GoToChapter extends ReadingCommand { final String chapterId; }
```

#### 1b. 原子状态快照 — `ReadingSnapshot`

```dart
class ReadingSnapshot {
  final ReadingStatus status;
  final String bookTitle;
  final String chapterTitle;
  final double totalProgress;
  final ReadingPosition? position;
  final String? errorMessage;
}
```

每页一次看到内部一致的一份状态，而不是分别订阅可能不同步的多个信号。

#### 1c. 正文视口 — `ReadiumViewportAdapter`

```dart
abstract interface class ReadingViewportAdapter {
  Widget buildViewport(BuildContext context);
}
```

允许 Readium 使用原生 Platform View，Builtin 使用现有的 Flutter renderer。

视口只处理：渲染、原生选择事件、生命周期、向后端报告位置变化。工具栏、设置面板、目录等不放在这里。

### 2. 位置模型

**领域真理**：`ReadingPosition(chapterIndex, charOffsetUtf16)` — 不变，不改。

**Readium Locator**：作为 Adapter 私有位置存储，不进入领域持久化模型。

```dart
class ReadiumPositionHint {
  final String href;
  final String locatorJson;
  final String publicationFingerprint;
}
```

持久化结构：

```
ReadingPosition
├── chapterIndex
├── charOffsetUtf16          # 领域真理
└── engineHint?              # 恢复加速，非跨功能真理
    ├── engineKind
    ├── publicationFingerprint
    └── opaqueLocator
```

规则：

1. 书签、笔记、搜索、TTS 继续使用 `chapterIndex + charOffsetUtf16`
2. Readium Locator 只能作为快速恢复提示
3. Locator 与当前 EPUB 指纹不匹配时必须丢弃
4. Locator 恢复失败时退回逻辑位置
5. 不能只保存 `totalProgression`
6. 不持久化 Readium 页码

### 3. 能力模型

```dart
class ReadingCapabilities {
  final bool pagination;
  final bool continuousScroll;
  final bool precisePosition;
  final bool textSelection;
  final bool annotations;
  final bool nativeTts;
  final bool customFont;
  final bool letterSpacing;
  final bool paragraphSpacing;
  final bool firstLineIndent;
}
```

UI 根据 capability 决定显示、禁用并解释、使用降级实现、或者走应用层功能。

不能使用空实现，不能静默忽略设置。

### 4. 引擎选择策略

```dart
enum ReadingBackendKind {
  builtin,
  readium,
}

class ReadingBackendPolicy {
  ReadingBackendKind select({
    required BookFormat format,
    required String bookId,
    required PlatformCapabilities platform,
  });
}
```

策略优先级：

```
本书显式选择
    ↓
全局 EPUB 策略
    ↓
平台是否支持 Readium
    ↓
Readium 是否曾对此书启动失败
    ↓
默认 Builtin
```

配置选项：

- `builtinOnly` — 全部走 Builtin（默认）
- `readiumForEpub` — EPUB 走 Readium，TXT 走 Builtin
- `perBook` — 按书籍配置逐本选择

失败回退：Publication 打不开时提示用户后允许切换 Builtin；不静默自动换引擎。

### 5. 架构变更

```
前置（两套独立路径）:
  ReaderPage ─→ ReaderShell ─→ ReaderScaffold
                                     ├── ReaderViewModel (Builtin)
                                     ├── ReaderContentArea
                                     │     ├── BrightnessMask
                                     │     └── BatteryIndicator
                                     ├── ReaderTopChrome
                                     ├── ReaderTapZoneLayer
                                     └── ReaderBottomChrome

  ReadiumReaderPage ─→ ReadiumReaderShell ─→ [重复的壳层]

Phase R1 目标:
  ReaderPage (唯一入口)
       │
       ▼
  ReaderSessionFactory
       │
       ├── EnginePolicy
       │      ├── builtin
       │      └── readium
       │
       ▼
  ReadingBackend
       │
       ├── BuiltinReadingAdapter
       │      └── ReaderViewModel + PaginationEngine + ScrollEngine
       │
       └── ReadiumReadingAdapter
              └── Flureadium + Publication + Locator
       │
       ▼
  UnifiedReaderShell
       ├── ReaderChrome
       ├── ReaderViewportHost
       ├── ReaderBottomChrome
       ├── ReaderNavigationDrawer
       ├── ReaderNoteSidebar
       └── ReaderInteractionLayer
```

### 6. 用语统一

- **Builtin（而非"TXT 引擎"）**：自研引擎同时支持 TXT 和 EPUB
- **Readium（而非"Readium 引擎"）**：首期只接 EPUB
- **BuiltinReadingAdapter**：包装现有 ReaderViewModel
- **ReadiumReadingAdapter**：包装 flureadium

---

## 理由

### 为什么用三个小接口而非一个大接口

| 维度 | 大接口方案 | 三小接口方案 |
| ------ | ------------ | -------------- |
| seam | PaginationEngine 层 | 阅读会话行为层 |
| Readium 适配 | 大量方法无合理实现 | 每个接口职责清晰 |
| Signal 同步 | 需要外部编排 | 原子 snapshot |
| 测试 | mock 一整个大接口 | 按接口分别 mock |
| 演进 | 新增方法影响所有引擎 | 接口稳定后少改 |

### 为什么 charOffset 仍是领域真理

已有完整工具链：

- 书签、笔记、搜索、TTS 全部基于 `chapterIndex + charOffset`
- 跨引擎切换的唯一可靠坐标系
- UTF-16 偏移在 FRB 和 Flutter 之间天然匹配
- Readium Locator 缺少标准化的字符级别定位

### 为什么 Readium Locator 不是领域真理

- Locator 格式在不同平台（Android/iOS）可能不同
- 依赖 EPUB 出版物的内部内容结构
- flureadium 版本升级可能改变 Locator 格式
- 保存 Locator 作为快速恢复提示已足够

### 为什么 Readium 能力必须显式暴露

不要假装两个引擎能力相同。

- 不支持的功能应该直接不显示或显示"暂不支持"，而不是显示后不生效
- `ReadingCapabilities` 让 UI 层无需知道具体引擎类型
- 新增引擎时 UI 自动适应 capability 变化

---

## 后果

### 正面

1. 一条路由、一个入口：用户感知不到引擎切换
2. 引擎可插拔：新增引擎无需改 UI
3. 壳层零重复：UnifiedReaderShell 是唯一壳层
4. 渐进迁移：Readium 功能逐个补齐，不影响现有用户
5. 能力可见：不支持的引擎功能不会静默失效

### 负面

1. 接口设计需保持稳定（但比大接口更容易维护）
2. 双引擎意味着双倍 bug 面
3. 部分设置（字号/行距）在 Readium 和 Builtin 上行为可能不完全一致
4. 位置互转需要维护复杂映射逻辑

### 不做

- 不引入第三引擎（PDF/漫画）— Readium 稳定后再评估
- 不改 Rust 侧管线 — Builtin 继续服务 TXT 和未切换的 EPUB
- 不影响 Phase 13 质量攻坚 — Readium 统一是独立轨道

---

## 实施计划

### Phase R1：Readium 双引擎统一接入（15 阶段计划）

> **注意**：以下为 R1-R15 概述，每阶段详细要求见对应任务 PRD（`.trellis/tasks/07-22-r1-??-*/prd.md`）。

| 阶段 | 名称 | 工作量 | 说明 |
|------|------|--------|------|
| R1 | 冻结正式架构 | ~2h | ADR-019 Accepted，文档对齐，声明 seam
| R2 | 多引擎核心模型 | ~5h | lib/core/reading/ 纯 Dart seam 文件
| R3 | 引擎位置持久化 | ~8h | reading_engine_positions 表 + FRB API
| R4 | Builtin Adapter | ~10h | 包装 ReaderVM → ReadingBackend
| R5 | Readium Adapter | ~14h | Flureadium 生命周期封装
| R6 | 位置桥 | ~8h | Locator ↔ ReadingPosition 映射
| R7 | 引擎策略与回退 | ~3h | ReadingBackendPolicy + 每书覆盖
| R8 | SessionFactory | ~5h | 带 scope 的 scoped ReadingSession
| R9 | 统一阅读页面 | ~12h | UnifiedReaderShell，唯一壳层
| R10 | 目录与进度 | ~5h | ReadingChapter + 节流持久化
| R11 | 排版设置映射 | ~3h | ReadingPreferences → EPUBPreferences
| R12 | 书签与批注 | ~6h | 统一书签 + decoration 桥
| R13 | TTS/搜索/生词 | ~3h | 应用层功能适配
| R14 | 清理 PoC | ~2h | 删除 PoC 文件和路由
| R15 | 全量验证 | ~12h | 契约测试 + 真机 + 门禁
|
**合计：约 95-105h**

> 依赖：R1→R2→R3→(R4,R5→R6)→R7→R8→R9→(R10,R11,R12,R13)→R14→R15

---

R1-R15 各阶段取代了原 R1-0~R1-8。PoC 阶段已取消，Readium 作为 EPUB 正式后端实施。
---

## 演进注意

1. **Readium 是正式后端（按可删除设计）**：不阻塞其他 Phase
2. **允许删除**：如果 Readium 维护成本超过收益，可删除 `ReadiumReadingAdapter` 而不断裂 UI
3. **接口最小化**：只包含两个引擎都有意义的操作
4. **`lib/features/reader/epub/` 路径规划**：统一后应移至 `lib/core/reading/backend/readium/`，使 features/ 不再直接感知引擎实现
