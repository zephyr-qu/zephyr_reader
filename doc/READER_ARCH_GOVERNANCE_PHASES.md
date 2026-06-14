# Reader Module 架构治理 — 后续阶段计划

已完成 Phase 1（Repository 抽象接口提取），本文档记录剩余治理阶段。

---

## Phase 2: `core/reader/` → `features/reader/domain/`

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

**风险**：低 — 纯搬移，无逻辑变更。需要确认无其他 feature 依赖 `core/reader/`。

---

## Phase 3: 拆分 `ReaderPageState` — 按 VM 分属的信号组

**目标**：消除 5 个子 VM 共享同一个可变状态对象的隐式耦合。

**现状**：

```dart
class ReaderPageState {
  final bookId = signal<String>('');           // → ChapterViewModel
  final chapterIndex = signal<int>(0);          // → ChapterViewModel, ReadingSessionManager
  final currentCharOffset = signal<int>(0);     // → ChapterViewModel, ReadingSessionManager
  final chapterContent = asyncSignal<String>…;  // → ChapterViewModel
  final readingMode = signal<ReadingMode>(…);   // → ReaderViewModel, TranslationViewModel
  final pendingJumpCharOffset = signal<int?>(null); // → ChapterViewModel
}
```

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

## Phase 4: 拆分 `reader_page.dart`

**目标**：将 606 行、25 个信号订阅的单体 widget 拆分为可维护的模块。

**现状问题**：
- 三种渲染模式（scroll/bilingual/paginated）的 builder 内联在同一个 `build()` 中
- Toolbar 显示/隐藏 + 自动隐藏 timer 逻辑混在 widget 层
- Toast → SnackBar 的 `useSignalEffect` 在 `build()` 中声明
- 25 个 `useSignalValue` 订阅散落在 `build()` 开头

**方案**：

```
reader_page.dart（～250 行，仅保留编排逻辑）
  ├── widgets/reader_content_area.dart  → 三种渲染模式 builder 提取
  ├── widgets/reader_toolbar_handler.dart → toolbar 显示/隐藏/auto-hide
  └── widgets/reader_toast_handler.dart  → toast effect + snackbar
```

**步骤**：
1. 提取 `_buildContentArea()` 为独立 `ReaderContentArea` widget
2. 提取 toast effect 为 `ReaderToastHandler` widget（或在 Scaffold 外层包装）
3. 提取 toolbar timer 逻辑为 `ReaderToolbarController`（非 widget）
4. 整理 `build()` 中的信号订阅，按功能分组
5. 删除无用的 `b_` 前缀变量（改用 `useSignalValue` 内联）

**影响范围**：~4 新文件，1 修改文件。

**风险**：低 — 纯提取，逻辑不变。

---

## Phase 5: `ReaderViewModel` DI 自动注入子 VM

**目标**：使子 VM 可单独测试、可单独替换。

**现状**：

```dart
ReaderViewModel({...}) {
  chapterManager = ChapterViewModel(_repo, _config, state);
  sessionManager = ReadingSessionManager(state, chapterManager);
  bookmarks = BookmarkViewModel(state);
  annotations = AnnotationViewModel(state);
  translation = TranslationViewModel(state);
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
- `data/translation/translation_cache.dart:56` — "SHA256" 注释改为 "Adler-32"
- `data/vocabulary_marker_service.dart:26-35` — 更新或删除 TODO（多词库管理页面）
- `data/renderer/find_render_box.dart`（989B）— 合并到调用方或删除
- `data/pagination_engine.dart` 中 `PageInfo` 是否可迁入 `domain/`（与 Phase 2 联动）

**影响范围**：~4 文件。

**风险**：极低。

---

## 各阶段推荐顺序和依赖关系

```
Phase 1 ✅ 已完成
   │
   ▼
Phase 2 (core→feature 迁移) ──→ Phase 6（部分联动）
   │
   ▼
Phase 3 (ReaderPageState 拆分) ── 可并行
   │
   ▼
Phase 4 (reader_page.dart 拆分) ── 依赖 Phase 3 的信号拆分
   │
   ▼
Phase 5 (DI 自动注入) ── 依赖 Phase 3
   │
   ▼
Phase 6 (遗留清理) ── 随时可做
```

**建议**：Phase 2 → Phase 6（部分）→ Phase 3 → Phase 4 → Phase 5。Phase 6 中 SHA256 注释可随时改。
