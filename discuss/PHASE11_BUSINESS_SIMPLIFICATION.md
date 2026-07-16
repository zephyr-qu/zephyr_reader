# Phase 11 — 业务下沉和业务简化

> 讨论时间：2026-07-15
> 参与者：zs
> 来源：ROADMAP Phase 11 + 架构复核讨论

---

## 动机

经过 Phase 9（Rust 目录重组）、Phase 10（TXT 章节检测配置化）的架构调整后，
Phase 11 聚焦业务逻辑层面的质量提升。

当前 Rust 侧有 13 个 service 文件 + 10 个 repo 文件 + 16 个 API 文件，
随着业务增长，出现了：

- Service 层做了本应在 repo/SQL 层做的事（级联、for 循环 SQL）
- 多个 FRB 接口的功能可以合并（Flutter 侧用 if/else 分支选调不同 API）
- 成对的 FRB 调用缺乏事务保护

## 目标

做一次全库审查扫描，使用判断框架筛选需要下沉和简化的代码，逐一整改。
重点是**收益明确、改动可控**的项。

## 判断框架

### 方向 A：业务下沉（代码放到正确的层）

**应该下沉到 repo/SQL 的：**

| 模式 | 示例 | 下沉方式 |
| ------ | ------ | --------- |
| 级联操作 | 逐表调 delete 删书的相关数据 | `ON DELETE CASCADE` 或 repo 层事务 |
| for 循环 SQL | foreach 调 repo 逐条 insert/update | 单条批量 SQL（如 INSERT INTO ... VALUES (...)） |
| 纯中间人 | service 只调一个 repo 方法、无业务逻辑 | 合并到 API 层直接调 repo |

**不该下沉的（留在 service 层）：**

| 模式 | 示例 |
| ------ | ------ |
| 跨模块编排 | 删书→删搜索索引（book + search 两个领域） |
| 有业务规则的操作 | 分类删除前检查是否还有书关联 |
| 计算/转换 | 从笔记统计估算阅读时长 |

### 方向 B：业务简化（减少 FRB 调用次数）

**应该聚合的：**

| 模式 | 示例 | 聚合方式 |
| ------ | ------ | --------- |
| 同屏数据多表 | 书架列表 + 进度 + 分类 | 单接口 `listBookshelfBooks(Optional<category>, Optional<status>)` |
| API爆炸型多接口 | 7 个书架相关 API 筛选变体 | 合并为一个带可选参数 |
| 成对写操作 | 存进度 + 记会话 | 在 Rust 侧一个事务内完成 |

**不该聚合的：**

| 模式 | 示例 |
| ------ | ------ |
| 不同生命周期 | 导入书 vs 提取封面（封面失败不阻塞导入） |
| 需用户交互 | 分页中等待用户操作 |
| 类型不同独立使用 | 获取阅读设置 vs 开始阅读 |
| 强行聚合导致参数复杂 | 无关逻辑塞进一个函数 |

## 启动方式

Phase 11 启动时执行以下步骤：

1. **扫描**：系统审查所有 `service.rs` 和 `api/*.rs` 文件
2. **筛选**：用判断框架标注待整改项
3. **整改**：逐项修改，每项独立 commit
4. **验证**：`cargo clippy -- -D warnings` + `flutter analyze --fatal-infos`

## 已知案例（启动时正式扫描确认）

### 疑似可下沉

| 文件 | 怀疑 |
| ------ | ------ |
| `domain/book/service.rs` `delete_book` | 逐表 delete + 手动删封面，检查是否有 `ON DELETE CASCADE` 但被 service 绕过的 |
| `domain/progress/service.rs` | **已确认：无业务逻辑**，1 个 repo 调用，API 层直接调 repo 即可 |
| `domain/stats/service.rs` | 检查是否只是 repo 的包皮 |
| `domain/chapter/service.rs` | 同上 |

### 疑似可聚合

| API 组合 | 理由 |
| --------- | ------ |
| `list_bookshelf_books` × `list_bookshelf_books_by_status` × `list_bookshelf_books_by_category` × `list_bookshelf_books_by_category_and_status` | 4 个 API 合并为 1 个带可选参数 |
| `progress_api.upsertProgress` + `session_api.createSession` | 成对出现，需事务保护 |

## 验收标准

- [ ] `cargo clippy -- -D warnings` 零告警
- [ ] `flutter analyze --fatal-infos` 零错误
- [ ] 书架加载功能正常（合并 API 后不变）
- [ ] 阅读状态保存正常（事务合并后不变）
- [ ] 删除书籍的级联清理完整
- [ ] 不引入新的抽象层（不为了下沉而下沉）

## 不做

- 不引入新的设计模式/框架
- 不修改 parser/infra 等非业务层的代码
- 不修改 Flutter UI 层代码
- 不做代码格式化/重命名等 cosmetic 修改
