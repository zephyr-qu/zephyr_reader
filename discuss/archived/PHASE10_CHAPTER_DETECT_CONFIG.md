# Phase 10 — TXT 章节检测正则可配置化

> 讨论时间：2026-07-15
> 参与者：zs
> 来源：ROADMAP Phase 10 阶段讨论

---

## 动机

当前 `extract_chapters()` 在 `chapter_detect.rs` 中硬编码了 4 组正则模式，按固定优先级
`ZH → ZH_ENUM → EN → DIGIT` 依次尝试，第一个有匹配的 wins。

网文格式多样（日式轻小说、特殊编号、无规律分章），固定模式总有遗漏，且每次调整需修改 Rust 代码+重新编译用户版本。

## 目标

- 将章节检测正则改为可配置，用户可在 Flutter 设置中添加/删除/排序模式
- 首次解析时默认 4 组不改变行为
- 支持"重试分章"——不满意当前分章结果时向下继续尝试
- Rust 侧持久化模式配置

## 设计

### ADR-021：模式持久化 → sqlite app_settings 表

**状态**：已接受 ✅

新增通用设置表：

```sql
CREATE TABLE IF NOT EXISTS app_settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

键 `chapter_detect_patterns` 存储 `JSON<string[]>`（默认 4 组 + 用户自定义）。

理由：

- `parse_book()` 已有 sqlx pool 访问 → 零新依赖
- 通用性：未来其他 Rust 侧设置可复用（TXT 编码首选、引擎参数等）
- 比 `kv_store`（sled，用于可重建缓存）更合理
- 比静态文件更安全（不需管理文件路径+权限）

### ADR-022：模式优先级 — 默认先，用户后

**状态**：已接受 ✅

```
默认(ZH) → 默认(ZH_ENUM) → 默认(EN) → 默认(DIGIT) → 用户模式#0 → 用户模式#1 → ...
```

索引约定：

| 索引 | 模式 |
| ------ | ------ |
| 0 | ZH |
| 1 | ZH_ENUM |
| 2 | EN |
| 3 | DIGIT |
| 100+ | 用户模式 #0..#N |

-1 表示"整书无匹配，全文件做一章"。

### ADR-023：重试分章 — 向下匹配而非重新匹配

**状态**：已接受 ✅

用户点击"重新分章"时，不从 0 重新开始（结果一样），而是从当前
`detect_pattern_index + 1` 继续尝试。

```rust
// 首次解析（parse_book）
extract_chapters_from(content, &patterns, 0)           // 从 ZH 开始

// 重试（redetect_chapters）
extract_chapters_from(content, &patterns, current + 1) // 从下一个开始
```

当前模式索引持久化在 `book_metadata.detect_pattern_index` 字段。

### ADR-024：无 LRU 正则缓存

**状态**：已接受 ✅

TXT 解析是一次性导入操作，正则编译开销 < 1ms/组。不需要 LRU 缓存。

## 数据结构

### app_settings 表

```sql
CREATE TABLE IF NOT EXISTS app_settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

初始化内容：

```json
{
    "chapter_detect_patterns": [
        "(?m)^(?:第\s*)?([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟 0-9]+)\s*[章回卷节部篇集]\s*(.+)?$|^(?:楔子|序[言引]?|前言|引子|尾声|完结|番外|后记|自序|代序|跋|附录|\S+版自序)\s*(.+)?$",
        "(?m)^([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8})\s*[、.．:：]\s*(\S.+)$",
        "(?mi)^(?:Chapter\s+\d+|[IVX]+\.[\s.]|[IVX]+\s+[A-Z]|\bPart\s+\d+|Book\s+\d+|Prologue|Epilogue|Preface|Introduction|Conclusion)\s*:?\s*(.*)$",
        "(?m)^(\d+)[\s.、:：](.+)$"
    ]
}
```

### book_metadata 表 — 新增字段

```sql
ALTER TABLE book_metadata ADD COLUMN detect_pattern_index INTEGER DEFAULT 0;
```

| 值 | 含义 |
| ---- | ------ |
| 0 | ZH 匹配成功 |
| 1 | ZH_ENUM 匹配成功 |
| 2 | EN 匹配成功 |
| 3 | DIGIT 匹配成功 |
| 100+N | 用户模式 #N 匹配成功 |
| -1 | 无匹配（整书一章） |

## 调用链设计

```
parse_book(file_path)
  ↓
读取 app_settings → patterns: Vec<String>
  ↓
读取 book_metadata → start_index (首次=0, 重试=current+1)
  ↓
extract_chapters_from(content, &patterns, start_index)
  ↓
返回 (chapters, used_index)
  ↓
保存 chapters + 更新 detect_pattern_index = used_index
```

### 新 FRB API

```rust
/// 获取当前章节检测模式列表
#[frb]
pub async fn get_chapter_detect_patterns() -> Result<Vec<String>, AppError>;

/// 保存章节检测模式列表
#[frb]
pub async fn set_chapter_detect_patterns(patterns: Vec<String>) -> Result<(), AppError>;

/// 重新检测指定书的章节（"重试分章"）
/// 从当前 detect_pattern_index + 1 开始尝试匹配
#[frb]
pub async fn redetect_chapters(book_id: String) -> Result<(), AppError>;

/// 获取指定书当前使用的检测模式索引
#[frb]
pub async fn get_detect_pattern_index(book_id: String) -> Result<i32, AppError>;
```

## 任务清单

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P1** | `app_settings` 表 migration | 新 sql 迁移文件 |
| 2 | **P1** | `book_metadata.detect_pattern_index` migration | ALTER TABLE |
| 3 | **P1** | `ChapterPatterns` 类型 | Rust 结构体（patterns vec + start index） |
| 4 | **P1** | `extract_chapters_from()` | 新函数：接受 patterns + start_index，返回 chapters + used_index |
| 5 | **P1** | `parse_txt_inner()` 适配 | 接受可选 patterns 参数 |
| 6 | **P1** | `domain/book/service.rs::parse_book()` 适配 | 读取 app_settings，传 patterns 给 parser |
| 7 | **P1** | `get/set_chapter_detect_patterns()` API | FRB 接口 |
| 8 | **P1** | `redetect_chapters()` API | FRB 接口 |
| 9 | **P2** | Flutter 初始化默认模式 | 首次启动时将 4 组内置模式写入 app_settings |
| 10 | **P3** | Flutter 模式编辑 UI | 设置页面添加/删除/排序用户模式 |
| 11 | **P3** | Flutter 重试 UI | 书籍详情页"重新分章"按钮 |

## 验收标准

- [ ] `flutter analyze --fatal-infos` 零错误
- [ ] `cargo clippy -- -D warnings` 零告警
- [ ] 首次解析 TXT 行为不变（4 组默认模式）
- [ ] 用户添加自定义模式后，新导入的 TXT 可使用新模式分章
- [ ] 用户点击"重新分章"后，使用下一个模式重新解析并替换章节
- [ ] 重试后阅读进度不受影响（chapter_index 不变）

## 不做

- 每本书独立 pattern 配置
- 自动 pattern 推荐/学习
- EPUB 章节检测（EPUB 有 TOC，不需要正则）
- LRU 正则缓存
- 首次匹配不满意时自动 fallthrough（用户手动触发）
