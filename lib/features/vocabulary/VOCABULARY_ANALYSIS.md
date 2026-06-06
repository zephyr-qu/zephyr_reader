# Vocabulary Feature 深度分析报告

> 分析基准：`lib/features/vocabulary/`
> 检测日期：2026-06-05

***

1\. 架构总览

```
vocabulary/
├── application/
│   └── vocabulary_view_model.dart         ← 生词 VM（~75 行，AsyncSignal）
├── page/
│   ├── vocabulary_page.dart               ← 生词本页面（HookWidget，inline 四态逻辑已提取）
│   └── widgets/
│       ├── vocab_list_item_tile.dart       ← 增强词条卡片（Dismissible + PopupMenu + 动画）
│       ├── vocab_stats_row.dart            ← 筛选 chips 两行（状态 + 词库）
│       ├── vocab_status_chip.dart          ← 状态标签彩色 pill
│       └── vocab_word_list_view.dart       ← 四态列表：loading/error/empty/list
```

**增强后的 VocabListItemTile 结构**：

```
[Dismissible] → [Container(card)]
 ├─ 状态圆点 (8×8 colored circle)
 ├─ 词 + /拼音/
 ├─ translation（新移植）
 ├─ 📖 bookTitle [wordList badge]（新移植）
 └─ PopupMenuButton<VocabStatus> → VocabStatusChip
   + stagger fadeIn animate（新移植）
```

**页面结构**：

```
VocabularyPage
 ├── AppBar（返回 + "生词本" + 刷新）
 ├── VocabStatsRow
 │   ├── 状态筛选行：全部/未学/学习中/已忽略/已掌握（含计数）
 │   └── 词库筛选行：全部词库/CET-4/CET-6/IELTS/TOEFL
 └── Expanded → ListView
     └── VocabListItemTile（增强版）
```

> 现在 vocabulary 模块是所有生词功能的 canonical 实现。learning\_notes 不再包含任何生词逻辑。

<br />

5\. 测试覆盖分析

### 现有测试

| 文件                                                         | 类型        | 覆盖内容                                                                                                                                                |
| ---------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test/features/vocabulary/vocabulary_view_model_test.dart` | 单元测试      | 初始状态（1） + FFI 依赖（5） + 错误路径（2）                                                                                                                       |
| `test/widget/vocab_components_test.dart`                   | Widget 测试 | `VocabStatusChip`（4 statuses）、`VocabListItemTile`（8 场景：基本、translation、wordList badge、bookTitle、无拼音、无 meta row、Dismissible 弹窗）、`VocabStatsRow`（3 场景） |
| `test/widget/vocabulary_page_test.dart`                    | Widget 测试 | 信号绑定机制验证（hooks 库）                                                                                                                                   |

### 覆盖率缺口

| 组件                    | 单元测试         | Widget 测试 | 错误态 | 说明                                 |
| --------------------- | ------------ | --------- | --- | ---------------------------------- |
| ViewModel 初始状态        | ✅ 2          | —         | —   | initial values                     |
| loadWords/refresh     | ⚠️ 4 skipped | —         | ✅ 1 | 需要 Rust FFI mock                   |
| list items (enhanced) | —            | ✅ 8       | —   | translation, badge, dot, animation |
| Dismissible dialog    | —            | ✅ 1       | —   | swipe + confirm + cancel + confirm |
| VocabStatsRow         | —            | ✅ 3       | ✅   | 正常/空/高亮                            |
| VocabStatusChip       | —            | ✅ 4       | —   | 所有状态                               |
| empty state           | —            | —         | —   | 需要 page 集成测试                       |
| Page composition      | —            | —         | —   | 需要 Rust FFI mock                   |

## 7.5 `vocabulary_page_test.dart` 仍然测试 hooks 库

`test/widget/vocabulary_page_test.dart` 测试的是 `useSignal`、`useSignalEffect`、`useSignalValue` 等第三方库的行为，不是 `VocabularyPage` widget 本身。无法验证空态渲染、筛选交互、WordList 显示等业务逻辑。

***

## 8. 剩余问题总览（2026-06-05 i18n 修复后）

> i18n 5 项（#1–5）已全部修复 ✅。以下为仍待处理的 **12 项**。

| #  | 优先级    | 类别 | 问题                                                               | 涉及文件                        | 详见   |
| -- | ------ | -- | ---------------------------------------------------------------- | --------------------------- | ---- |
| 10 | **P2** | 测试 | FFI 测试 mock，移除 `skip: 'requires Rust bridge'`                    | 测试文件                        | §5   |
| 11 | **P2** | 测试 | `vocabulary_page_test.dart` 测试的是 hooks 库行为，非 `VocabularyPage` 自身 | `vocabulary_page_test.dart` | §7.5 |
| 12 | **P2** | 测试 | Page composition 集成测试（空态/筛选/列表联动）                                | 测试文件                        | §6   |

