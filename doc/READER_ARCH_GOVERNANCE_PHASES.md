# Reader Module 架构治理 — 后续阶段计划

已完成的治理工作：
- **Phase 1** ✅ Repository 抽象接口提取
- **Phase 4** ✅ `reader_page.dart` 拆分（见下表）

本文档记录剩余治理阶段。

## 当前状态总览

| 阶段 | 状态 | 证据 |
|------|------|------|
| Phase 2 (core/reader → features/reader) | ✅ 已完成 | 4 文件已迁移；53+ import 路径已更新；DI 注册路径已通过 build_runner 重新生成 |
| Phase 3.1 (readingMode → ReaderViewModel) | ✅ 已完成 | `readingMode` signal 已从 `ReaderPageState` 移到 `ReaderViewModel`；`ChapterLoadRequest` 增加 `readingMode` 字段以传递到 orchestrator；`TranslationViewModel.setTranslationContent` 移除 readingMode 依赖；4 widget 消费者切换到 `vm.readingMode` |
| Phase 3.2 (chapter signals → ChapterViewModel) | ⏳ 待办 | **15 文件** 依赖 `bookId/chapterIndex/currentCharOffset/chapterContent/pendingJumpCharOffset`；跨 5 个分层 |
| Phase 4 (reader_page.dart 拆分) | ✅ 已完成 | `reader_page.dart` 27 行（薄壳），7 个独立 widget 文件 |
| Phase 5 (DI 自动注入) | ⏳ 待办 | `ReaderViewModel` 构造函数内 `new` 子 VM |
| Phase 6 (遗留清理) | ⏳ 待办 | 4 项全部仍未动 |

---

## Phase 2: `core/reader/` → `features/reader/domain/` ✅

**目标**：消除架构异味 — 将阅读器专属逻辑从 `core/` 迁回 `features/reader/`。

**迁移清单**：

```
core/reader/
  reader_config.dart        → features/reader/domain/config/reader_config.dart
  tts_service.dart          → features/reader/domain/service/tts_service.dart
  custom_font_service.dart  → features/reader/domain/service/custom_font_service.dart
  models/font_info.dart     → features/reader/domain/model/font_info.dart
```

**影响范围**：~8 个文件，涉及所有引用 `core/reader/` 的 import。

**步骤**：
1. 在 `features/reader/domain/` 下创建 `config/`、`service/`、`model/` 子目录
2. 复制/迁移文件，保持类名和 public API 不变
3. 全局更新 import 路径（`ast_edit` codemod）
4. 删除 `core/reader/` 原文件
5. 更新 DI 注册（`app_module.dart` 中的 binding 路径）
6. `dart analyze` 验证


**完成时间**：本次会话（2026-06）。

**实际产出**：
- `lib/core/reader/reader_config.dart` → `lib/features/reader/domain/config/reader_config.dart`
- `lib/core/reader/tts_service.dart` → `lib/features/reader/domain/service/tts_service.dart`
- `lib/core/reader/custom_font_service.dart` → `lib/features/reader/domain/service/custom_font_service.dart`
- `lib/core/reader/models/font_info.dart` → `lib/features/reader/domain/model/font_info.dart`
- 53+ import 路径已通过 codemod 统一更新
- DI 注册路径（`service_locator.config.dart`）通过 `build_runner build` 重新生成
- `lib/core/reader/` 目录已删除

**实测范围**：实际涉及 53+ 文件，比计划文档估算的 ~8 文件大一个数量级。建议下期 PR 规划时重新评估依赖图。
**风险**：低 — 纯搬移，无逻辑变更。需要确认无其他 feature 依赖 `core/reader/`。

---

## Phase 3: 拆分 `ReaderPageState` — 按 VM 分属的信号组

**目标**：消除 5 个子 VM 共享同一个可变状态对象的隐式耦合。

**现状**（实际代码 2026-06）：

```dart
class ReaderPageState {
  final bookId = signal<String>('');           // → ChapterViewModel
  final chapterIndex = signal<int>(0);          // → ChapterViewModel, ReadingSessionManager
  final currentCharOffset = signal<int>(0);     // → ChapterViewModel, ReadingSessionManager
  final chapterContent = asyncSignal<String>…;  // → ChapterViewModel
  final pendingJumpCharOffset = signal<int?>(null); // → ChapterViewModel
}

**方案**：将信号按所有者拆分到各子 VM 内部，VM 之间通过方法调用而非共享信号通信。

| 信号 | 当前使用者 | 归属 |
|---|---|---|
| `bookId` | ChapterVM, SessionManager | → ChapterVM |
| `chapterIndex` | ChapterVM, SessionManager | → ChapterVM，SessionManager 通过方法参数接收 |
| `currentCharOffset` | ChapterVM, SessionManager | → ChapterVM |
| `chapterContent` | ChapterVM | → ChapterVM |
| `readingMode` | ReaderVM, TranslationVM | → ReaderVM，TranslationVM 通过参数接收 |
| `pendingJumpCharOffset` | ChapterVM | → ChapterVM |

**步骤**：
1. `ChapterViewModel` 内部声明自己的 signals，暴露只读 signal 给外部
2. `ReadingSessionManager` 改为方法参数接收 `chapterIndex`/`charOffset`
3. `TranslationViewModel` 改为从构造函数/方法接收 `readingMode`
4. 删除 `ReaderPageState` 类
5. `ReaderViewModel` 不再持有 `ReaderPageState`，改为直接访问各子 VM 的信号
6. `reset()` 逻辑分散到各子 VM

**影响范围**：~6 文件，主要是 application 层。

**风险**：中高 — 信号所有权变更可能引入时序问题。需要逐个 VM 迁移，不可一次性全改。

---

## Phase 4: 拆分 `reader_page.dart` ✅

**目标**：将 606 行、25 个信号订阅的单体 widget 拆分为可维护的模块。

**完成时间**：在归档时（2026-06）已落地。

**实际产出**（`lib/features/reader/core/presentation/`）：

| 文件 | 行数 | 职责 |
|------|------|------|
| `reader_page.dart` | 27 | 薄壳，构造 `ReaderShell` |
| `reader_shell.dart` | 112 | 顶层编排 |
| `reader_scaffold.dart` | 171 | Scaffold 框架 |
| `reader_content_area.dart` | 269 | 三种渲染模式 builder |
| `reader_chrome.dart` | 160 | 工具栏/目录/封面容器 |
| `reader_interaction_layer.dart` | 138 | toast / snackbar / selection |
| `reader_tts_helpers.dart` | 32 | TTS 辅助 |
| `reader_ui_state.dart` | 43 | UI 局部 state |

---

## Phase 5: `ReaderViewModel` DI 自动注入子 VM

**目标**：使子 VM 可单独测试、可单独替换。

**现状**（实际代码 2026-06）：

```dart
ReaderViewModel({...}) {
  chapterManager = ChapterViewModel(_repo, _config, state);
  sessionManager = ReadingSessionManager(state, chapterManager);
  bookmarks = BookmarkViewModel(state);
  annotations = AnnotationViewModel(state);
  translation = TranslationViewModel(state, ...);
}
```

**方案**：子 VM 改为由 DI 容器注入，`ReaderViewModel` 只做编排。

**步骤**：
1. 为每个子 VM 添加 `@injectable` 注解（部分已是 `@Injectable`）
2. `ReaderViewModel` 构造函数参数改为接受各子 VM 实例
3. 移除 `ReaderViewModel` 内部的 `new XXXViewModel()` 调用
4. `ReaderViewModel.initialize()` 中的编排逻辑保持不变
5. 更新测试：子 VM 可单独 mock

**影响范围**：~8 文件。

**风险**：中 — DI 配置变更，`ReadingSessionManager` 依赖 `ChapterViewModel` 构成循环，需要调整构造顺序或用 `late`。

---

## Phase 6: 遗留清理

**目标**：低风险小问题集中清理。

**清单**：
- `data/translation/translation_cache.dart:55` — 注释 "简单 SHA256 摘要" 改为 "Adler-32 摘要"（实际实现就是 Adler-32）
- `data/vocabulary_marker_service.dart:26-35` — 3 处 TODO 需更新或删除（多词库管理页面）
- `data/renderer/find_render_box.dart`（989B）— 合并到调用方或删除
- `data/pagination_engine.dart` 中 `PageInfo` 是否可迁入 `domain/`（与 Phase 2 联动）

**影响范围**：~4 文件。

**风险**：极低。

---

## 各阶段推荐顺序和依赖关系

```
Phase 1 ✅ 已完成
Phase 4 ✅ 已完成
   │
   ▼
Phase 2 (core→feature 迁移) ──→ Phase 6（部分联动）
   │
   ▼
Phase 3 (ReaderPageState 拆分) ── 可并行
   │
   ▼
Phase 5 (DI 自动注入) ── 依赖 Phase 3
   │
   ▼
Phase 6 (遗留清理) ── 随时可做
```

**建议**：Phase 6（独立小清理）→ Phase 2 → Phase 3 → Phase 5。Phase 4 已完成，无需再动。
