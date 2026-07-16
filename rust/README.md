# Rust 阅读引擎

Zephyr Reader 的高性能阅读引擎，基于 Rust 实现，提供书籍解析、文本处理、全文搜索和本地数据库存储等功能。

## 功能特性

### 📖 书籍解析

- **TXT 文件解析**
  - 自动编码检测（UTF-8, GBK, GB2312, Big5 等）
  - 中文章节标题自动识别
  - 内容提供者模式（支持按需读取）
  - 流式解析（支持大文件）
- **EPUB 文件解析**
  - EPUB2/EPUB3 兼容
  - 目录提取
  - 元数据读取（书名、作者、封面）
  - 富文本内容解析（支持 HTML 标签）
  - 内容提供者模式

### 🎨 文本处理

- **智能排版**
  - 中英文智能断行
  - 标点符号避首避尾
  - 中英文混排优化
  - 英文连字支持（Hyphenation）
- **分页处理**
  - 智能分页算法
  - 页面边界计算
  - 分页缓存优化
- **双语对齐**
  - 中英文内容智能对齐
  - 相似度阈值控制
  - 段落级对齐算法
- **章节处理**
  - 章节标题自动检测
  - 章节内容提取
  - 富文本段落解析
- **CSS 样式处理**
  - CSS 属性解析
  - 样式应用到文本
  - 富文本样式支持

### 🔍 全文搜索

- 基于 SQLite FTS5 + jieba-rs 分词
- 章节内容索引
- 书籍内搜索
- 高性能查询
- 中文分词支持

### 🗄️ 本地存储

- 书籍管理（CRUD）
- 章节管理
- 阅读进度跟踪
- 书签管理
- 阅读统计与会话
- 书籍分类
- 笔记管理
- 生词本管理
- KV 键值存储

### 📚 词典引擎

- MDict 词典格式支持
- 快速词汇查询
- 分词支持
- 生词本集成

### 🖼️ 封面提取

- EPUB 封面提取
- 格式支持检测

## 目录结构

```
rust/
├── src/
│   ├── api/                          # FRB 薄封装层 — FFI 函数委托到 domain
│   │   ├── mod.rs
│   │   ├── backup.rs                 # 数据库备份与还原
│   │   ├── bilingual.rs              # 双语对齐
│   │   ├── book.rs                   # 书籍管理
│   │   ├── bookmark.rs               # 书签管理
│   │   ├── category.rs               # 分类管理
│   │   ├── chapter.rs                # 章节管理
│   │   ├── chapter_detect.rs         # TXT 章节检测配置
│   │   ├── cover.rs                  # 封面提取
│   │   ├── dictionary.rs             # 词典查询
│   │   ├── note.rs                   # 笔记管理
│   │   ├── progress.rs               # 阅读进度
│   │   ├── reader.rs                 # 章节读取
│   │   ├── search.rs                 # 全文搜索
│   │   ├── session.rs                # 阅读会话
│   │   ├── stats.rs                  # 阅读统计
│   │   └── vocab.rs                  # 生词管理
│   │
│   ├── common/                       # 共享类型
│   │   ├── mod.rs
│   │   ├── error.rs                  # AppError 统一错误类型
│   │   └── security.rs               # 文件路径安全验证
│   │
│   ├── domain/                       # 领域层 — 业务逻辑 + 仓储
│   │   ├── mod.rs
│   │   ├── backup/                   # 备份
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── service.rs
│   │   ├── bilingual/                # 双语对齐引擎
│   │   │   ├── engine.rs
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── service.rs
│   │   ├── book/                     # 书籍
│   │   │   ├── book_repo.rs
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── service.rs
│   │   ├── bookmark/                 # 书签
│   │   │   ├── bookmark_repo.rs
│   │   │   ├── mod.rs
│   │   │   └── models.rs
│   │   ├── category/                 # 分类
│   │   │   ├── category_repo.rs
│   │   │   ├── mod.rs
│   │   │   └── models.rs
│   │   ├── chapter/                  # 章节
│   │   │   ├── chapter_repo.rs
│   │   │   ├── mod.rs
│   │   │   └── models.rs
│   │   ├── chapter_detect/           # TXT 章节检测
│   │   │   ├── constants.rs
│   │   │   ├── detector.rs
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── repo.rs
│   │   ├── cover/                    # 封面提取
│   │   │   ├── engine.rs
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── service.rs
│   │   ├── dictionary/               # 词典引擎
│   │   │   ├── dictionary_repo.rs
│   │   │   ├── engine.rs
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── service.rs
│   │   ├── note/                     # 笔记
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   ├── note_repo.rs
│   │   │   └── service.rs
│   │   ├── progress/                 # 阅读进度
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── progress_repo.rs
│   │   ├── search/                   # 搜索引擎（FTS5 + jieba）
│   │   │   ├── engine.rs
│   │   │   ├── mod.rs
│   │   │   └── models.rs
│   │   ├── sessions/                 # 阅读会话
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── session_repo.rs
│   │   ├── stats/                    # 阅读统计
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── stats_repo.rs
│   │   ├── vocab/                    # 生词
│   │   │   ├── mod.rs
│   │   │   ├── models.rs
│   │   │   └── vocab_repo.rs
│   │   └── wordlist/                 # 生词扫描
│   │       ├── mod.rs
│   │       ├── vocab_scanner.rs
│   │       ├── vocabulary.rs
│   │       └── wordlists.rs
│   │
│   ├── infra/                        # 基础设施
│   │   ├── mod.rs
│   │   ├── init.rs                  # 应用初始化
│   │   ├── kv_store.rs               # KV 存储（redb）
│   │   └── manager.rs                # 存储管理器（SQLite + redb）
│   │
│   ├── parser/                       # 文件解析器
│   │   ├── mod.rs
│   │   ├── provider.rs               # 内容提供者 trait
│   │   ├── registry.rs               # 解析器注册表
│   │   ├── types.rs                  # 共享类型
│   │   ├── txt/                      # TXT 解析
│   │   │   ├── mod.rs
│   │   │   ├── chapter_detect.rs     # 章节检测
│   │   │   ├── content_ir.rs         # IR 解析
│   │   │   ├── decode.rs             # 编码检测
│   │   │   ├── parse.rs              # 内容解析
│   │   │   └── provider.rs           # TXT 内容提供者
│   │   └── epub/                     # EPUB 解析
│   │       ├── mod.rs
│   │       ├── asset_registry.rs     # 资源注册
│   │       ├── content_ir.rs         # IR 解析
│   │       ├── css.rs                # CSS 样式
│   │       ├── parse.rs              # 内容解析
│   │       ├── processed_image.rs    # 图片处理
│   │       ├── provider.rs           # EPUB 内容提供者
│   │       ├── rich_text.rs          # 富文本解析
│   │       ├── toc.rs                # 目录提取
│   │       └── unzip.rs              # EPUB 解压
│   │
│   ├── pipeline/                     # IR 处理管线
│   │   ├── mod.rs
│   │   ├── chapter_ir.rs             # 章节 IR 加载（redb 缓存）
│   │   ├── plain_projection.rs       # 纯文本投影
│   │   └── types.rs                  # IR 类型定义
│   │
│   ├── lib.rs                        # 库入口
│   └── frb_generated.rs              # FRB 生成代码
│
├── migrations/                       # 数据库迁移
├── benches/                            # 性能基准测试
├── tests/                              # 集成测试
├── Cargo.toml                          # Rust 依赖配置
└── Cargo.lock                          # 依赖锁定文件
```

## 数据结构

### 核心类型

#### ParseResult

```
pub struct ParseResult {
    pub book_info: BookInfo,
    pub chapters: Vec<ChapterInfo>,
    pub metadata: BookMetadata,
}
```

#### BookMetadata

```
pub struct BookMetadata {
    pub title: String,
    pub author: String,
    pub description: String,
    pub publisher: String,
    pub language: String,
    pub cover_path: Option<String>,
}
```

#### PageContent

```
pub struct PageContent {
    pub chapter_index: i32,
    pub page_index: i32,
    pub content: String,
    pub is_last_page: bool,
    pub start_offset: i64,
    pub end_offset: i64,
}
```

#### TypesetConfig

```
pub struct TypesetConfig {
    pub page_width: i32,
    pub page_height: i32,
    pub font_size: i32,
    pub line_spacing: f64,
    pub letter_spacing: f64,
    pub paragraph_spacing: f64,
    pub first_line_indent: i32,
    pub language: String,
}
```

### 数据库类型

#### DbBookRecord

```
pub struct DbBookRecord {
    pub book_id: String,
    pub title: String,
    pub author: String,
    pub file_path: String,
    pub file_type: String,
    pub cover_path: Option<String>,
    pub chapter_count: i32,
    pub total_characters: i64,
    pub status: DbBookStatus,
    pub is_pinned: bool,
    pub created_at: i64,
    pub updated_at: i64,
}
```

#### DbChapter

```
pub struct DbChapter {
    pub chapter_id: String,
    pub book_id: String,
    pub title: String,
    pub chapter_index: i32,
    pub start_offset: i64,
    pub end_offset: i64,
    pub content_length: i64,
}
```

#### DbReadingProgress

```
pub struct DbReadingProgress {
    pub book_id: String,
    pub chapter_index: i32,
    pub chapter_id: Option<String>,
    pub progress: f64,
    pub character_offset: i64,
    pub last_read_at: i64,
}
```

#### DbBookmark

```
pub struct DbBookmark {
    pub bookmark_id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub character_offset: i64,
    pub note: String,
    pub created_at: i64,
}
```

### 搜索类型

#### SearchResult

```
pub struct SearchResult {
    pub book_id: String,
    pub chapter_id: String,
    pub chapter_index: String,
    pub chapter_title: String,
    pub snippet: String,
    pub position: i64,
    pub score: f32,
    pub char_offset: i64,
}
```

### 双语对齐类型

#### AlignedSegment

```
pub struct AlignedSegment {
    pub chinese: String,
    pub english: String,
    pub similarity_score: f32,
    pub chinese_position: usize,
    pub english_position: usize,
}

#### BilingualAlignment
```

pub struct BilingualAlignment {
pub segments: Vec<AlignedSegment>,
pub unmatched\_chinese: Vec<String>,
pub unmatched\_english: Vec<String>,
}

```

## 性能优化

### 解析优化

1. **增量解析**: 使用 `parseLocalBookIncremental` 支持缓存，避免重复解析
2. **流式加载**: 大文件使用流式 API，避免一次性加载

### 存储优化

1. **布局缓存**: 排版结果缓存到数据库，加速重复访问
2. **批量操作**: 使用批量保存接口减少数据库事务
3. **索引优化**: 数据库索引优化查询性能

### 搜索优化

1. **倒排索引**: 基于 SQLite FTS5 的倒排索引
2. **限制结果**: 使用 `limit` 参数限制搜索结果数量
3. **增量索引**: 支持增量更新搜索索引

### 内存管理

1. **分页加载**: 使用分页 API 按需加载内容
2. **及时释放**: 不再使用的页面内容及时释放
3. **缓存清理**: 定期清理过期缓存 (`cleanupExpiredLayoutCache`)

### 引擎优化（2026-05）

近期完成的 Rust 引擎内存与分配优化：

- **双语对齐**: 句子分割改用字节索引追踪，消除逐字 String 分配；grapheme 预分后复用，对齐窗口扫描中不再重复 Unicode 分词
- **分页引擎**: 页面内容预构建为 `page_contents: Vec<String>`，翻页时直接克隆而非逐行拼接；全文 `char_indices` 一次计算段落复用
- **搜索引擎**: 索引分块改为直接 char_indices 边界切分，避免 `Vec<char>` 中间分配；批量 INSERT 使用 `QueryBuilder::push_values` 减少 SQLite round-trip

优化详情见源码注释（`compute_line_breaks_from_indices`、`levenshtein_distance_graphemes`、`calculate_similarity_graphemes`）。

## 开发注意事项

1. **编码问题**: TXT 文件会自动检测编码，但建议在导入时告知用户
2. **EPUB 兼容性**: 支持主流 EPUB2/EPUB3 格式，但某些特殊 EPUB 可能无法解析
3. **章节检测**: 使用正则表达式匹配章节标题，可能无法识别所有格式
4. **排版规则**: 中英文混排已优化，但特殊格式可能需要手动调整
5. **安全限制**: 使用安全工具设置允许访问的目录
6. **初始化顺序**:
   - 必须先调用 `init_app()` 初始化应用
   - 存储层需要调用 `init_storage()` 初始化数据库
   - 搜索引擎需要调用 `init_search_engine()` 初始化
   - 词典引擎需要确保词典文件存在
7. **内容提供者模式**: 解析器使用内容提供者模式，支持按需加载内容，避免一次性加载大文件
8. **解析器注册表**: 使用 `registry.rs` 管理所有解析器实例，支持动态扩展
9. **KV 存储**: `kv_store.rs` 提供键值存储功能，用于缓存和配置
10. **布局缓存仓储**: `layout_cache_repo.rs` 专门管理排版缓存，加速重复访问
```

