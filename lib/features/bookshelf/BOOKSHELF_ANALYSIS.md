# Bookshelf Feature 深度分析报告

> 分析基准：`lib/features/bookshelf/` — 17 个文件
> 最后更新：2026-06-06

***

## 1. 架构总览

```
bookshelf/
├── application/
│   ├── bookshelf_view_model.dart           ← 书架 VM（@injectable, ~457 行）
│   ├── book_detail_view_model.dart         ← 书籍详情 VM（@injectable, ~67 行）
│   └── bookshelf_sort_type_ext.dart        ← 排序枚举 l10n 扩展
├── page/
│   ├── bookshelf_page.dart                 ← 书架主页面（HookWidget, ~630 行）
│   ├── book_detail_page.dart               ← 书籍详情页（HookWidget, ~170 行）
│   ├── category_management_page.dart        ← 分类管理页（HookWidget, ~457 行）
│   ├── wifi_transfer_page.dart             ← WiFi 传书页（HookWidget, ~318 行）
│   ├── book_detail_dialogs.dart            ← 弹窗工具函数（3 个函数）
│   └── widgets/ (13 个)
│       ├── bookshelf_book_content.dart     ← 书籍列表/网格渲染
│       ├── bookshelf_status_tabs.dart      ← 状态筛选 tab
│       ├── bookshelf_category_chips.dart   ← 分类筛选 chips
│       ├── bookshelf_batch_toolbar.dart    ← 批量操作工具栏
│       ├── book_cover.dart                 ← 统一封面组件
│       └── book_detail_*.dart              ← 书籍详情子组件（7 个）
```

**VM 生命周期**：

- `BookshelfViewModel` — `@injectable` 单例，被 `BookshelfPage` + `CategoryManagementPage` 消费 ✅
- `BookDetailViewModel` — `@injectable` + `getIt(param1: bookId)`，**仅被** **`BookDetailPage`** **一个 Widget 消费**

***

### 5.4 `reloadBooks()` 全量加载 + Dart 侧排序 ✅ 已修复

每次调用 `reloadBooks()` 都通过 FFI 获取完整书籍列表，然后在 Dart 侧排序。对于 >1000 本书的用户，每次搜索输入、切换状态（即使未实现）、refresh 都触发全量加载。搜索模式走 `searchBooks` API 是后端过滤，但其他操作都是全量。

***

<br />

7\. 测试覆盖分析

### 现有测试

| 文件                                                             | 类型        | 覆盖内容      | 局限性                              |
| -------------------------------------------------------------- | --------- | --------- | -------------------------------- |
| `test/features/bookshelf/bookshelf_view_model_test.dart`       | 单元测试      | 5 个初始状态断言 | 未使用 SharedPreferences mock，不完整   |
| `test/features/bookshelf/bookshelf_view_model_state_test.dart` | 单元测试      | 10 个状态机测试 | 覆盖 search/category/status 状态转换 ✅ |
| `test/features/bookshelf/semaphore_test.dart`                  | 单元测试      | 3 个信号量测试  | 独立工具测试 ✅                         |
| `test/widget/bookshelf_widgets_test.dart`                      | Widget 测试 | 尚未读取      | —                                |
| `test/widget/bookshelf_page_test.dart`                         | Widget 测试 | 尚未读取      | —                                |

### 覆盖率缺口

| 组件                         | 单元测试  | Widget 测试 | 错误态 | 说明         |
| -------------------------- | ----- | --------- | --- | ---------- |
| `BookshelfViewModel`       | ✅ 状态机 | N/A       | ❌   | API 错误路径未测 |
| `BookDetailViewModel`      | ❌     | N/A       | ❌   | 全无测试       |
| `BookshelfPage`            | N/A   | ❌         | ❌   | <br />     |
| `BookshelfBookContent`     | N/A   | ❌         | ❌   | 加载/错误/空态边界 |
| `scanFolder` 逻辑            | ❌     | N/A       | ❌   | 进度/并发/错误   |
| `batchUpdateStatus`        | ❌     | N/A       | ❌   | <br />     |
| `CategoryManagementPage`   | N/A   | ❌         | ❌   | <br />     |
| `WifiTransferPage`         | N/A   | ❌         | ❌   | <br />     |
| `book_detail_dialogs.dart` | ❌     | ❌         | ❌   | 3 个弹窗函数    |

## 8. 待解决问题

1. **§6.5 —** **`CategoryManagementPage._CategoryColor`** **缺乏防御解析**（P2）\
   异常颜色字符串返回 null，调用方 `category.colorValue` 未提供 fallback。
2. **§7 — 测试覆盖率缺口**（P2）\
   以下组件缺少单元 / Widget 测试：
   - `BookDetailViewModel` — 全无测试
   - `scanFolder` 逻辑 — 进度 / 并发 / 错误路径
   - `batchUpdateStatus` — 批量状态变换
   - `BookshelfViewModel` API 错误路径
   - `BookshelfBookContent` — 加载 / 错误 / 空态边界
   - `CategoryManagementPage` — Widget 测试
   - `WifiTransferPage` — Widget 测试
   - `book_detail_dialogs.dart` — 3 个弹窗函数

