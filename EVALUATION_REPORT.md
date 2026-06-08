# Zephyr Reader — 基线评估报告

> 评估日期：2026-06-08
> 对比基准：多看阅读 / 微信读书
> 架构：Flutter (Dart) + Rust (FRB) + SQLite + sled

---

## 1. 功能完备性评估

### 1.1 导入解析

| 功能 | 状态 | 备注 |
|------|------|------|
| TXT 解析 | ✅ 已完成 | chardetng 自动编码检测，正则章节识别，UTF-8 安全切片 |
| EPUB 解析 | ✅ 已完成 | spine 读取、TOC 提取、富文本渲染、封面元数据 |
| Markdown 解析 | ✅ 已完成 | comrak 渲染 → HTML → RichParagraph 管道 |
| PDF 解析 | ⚠️ 部分完成 | Rust 侧 pdfium-render 解析完成；**Dart 侧未接入**（标记 TODO） |
| 封面提取与缓存 | ✅ 已完成 | 注册表模式 + EPUB/PDF 封面提取 + DB 路径缓存 |
| 500MB 大文件处理 | ✅ 已设计 | `MAX_FILE_SIZE = 500MB`，chunked reading（8KB 块），mmap 支持 |

**缺口：** ⚠️ PDF 阅读在 UI 层处于不可用状态（Rust API 就绪，`get_pdf_page`/`get_pdf_total_pages` Dart 侧未调用）。

---

### 1.2 排版引擎

| 功能 | 状态 | 备注 |
|------|------|------|
| 标点避首避尾（禁则处理） | ✅ 已完成 | `typeset.rs` 单次遍历 O(n) 实现 |
| 中西文自动间距 | ✅ 已完成 | `AUTO_SPACE_RATIO = 0.25`，不修改存储文本 |
| 首行缩进 + 段间距控制 | ✅ 已完成 | `TypesetConfig.firstLineIndent`/`paragraphSpacing` |
| 字体/行距/页边距实时调整 | ✅ 已完成 | `TypesetConfig` 全参可调，hash 驱动的缓存失效 |
| 标点挤压 (Punctuation Squeeze) | ✅ 已完成 | `TypesetConfig.punctuationSqueeze` |
| 连字符断行 (Hyphenation) | ✅ 已完成 | `hyphenation` crate 内嵌 en-US 词典 |
| 自定义 CSS 样式注入 | ✅ 已完成 | `css.rs` 解析器 + `rich_text.rs` 样式合并 |
| 字符宽度校准 (Flutter → Rust) | ✅ 已完成 | `TypesetCalibration` 6 区间定长数组传递 |
| 惰性分页（50K 字符阈值） | ✅ 已完成 | 大章节不预计算所有行偏移，按需加载 |

**评价：** 排版引擎功能覆盖全面，已达到甚至超过多看/微信读书的排版能力基准。

---

### 1.3 阅读体验

| 功能 | 状态 | 备注 |
|------|------|------|
| 翻页流畅度 (60fps) | ✅ 设计达标 | 4 层缓存（Provider LRU 16 + Streamer LRU 4 + chapter sled + layout sled） |
| 阅读进度保存/恢复 | ✅ 已完成 | `ReadingProgress` DB 持久化 |
| 目录跳转 | ✅ 已完成 | 章节列表 Widget（支持多级 EPU B缩进） |
| 亮度/背景色切换 | ⚠️ 需确认 | ReaderConfig 中有相关信号，需验证 UI 集成度 |
| 仿真翻页动画 | ❌ 未实现 | 仅基础翻页过渡 |
| 听书功能 (TTS) | ⚠️ 骨架 | `TtsSettingsPage` 存在，**无实际 TTS 引擎集成** |
| 双语对照模式 | ✅ 引擎完成/⚠️ UI 待确认 | `align_bilingual_content` + 高亮配对完整；双语阅读 UI 需验证 |

**缺口：** TTS 引擎缺失；翻页动画单一。

---

### 1.4 笔记与搜索

| 功能 | 状态 | 备注 |
|------|------|------|
| 全文关键词搜索 (FTS5) | ✅ 已完成 | SQLite FTS5 + jieba-rs 中文分词 |
| 搜索高亮 + 片段返回 | ✅ 已完成 | `SearchResult.snippet` 含上下文片段 |
| 高亮/批注笔记 | ✅ 已完成 | `Note` CRUD，配色选项 |
| 书签管理 | ✅ 已完成 | `Bookmark` CRUD，时间维度浏览 |
| 双语高亮配对 | ✅ 已完成 | 中英高亮通过 `paired_note_id` 关联 |
| 手写批注 | ❌ 未实现 | |
| 笔记导出 (Markdown/PDF) | ❌ 未实现 | |
| 搜索历史持久化 | ⚠️ 缺失 | 纯内存 `List<String>`，重启丢失 |

---

### 1.5 数据同步与持久化

| 功能 | 状态 | 备注 |
|------|------|------|
| 本地 SQLite 持久化 | ✅ 已完成 | sqlx 连接池，迁移管理（2 个 migration） |
| 排版 KV 缓存 (sled) | ✅ 已完成 | LRU + 版本校验 + config_hash 失效 |
| WebDAV 同步 | ⚠️ 有已知问题 | 无冲突检测、部分失败遮蔽、缺少进度条 |
| 本地备份/还原 | ✅ 已完成 | manifest 嵌入 db、自动快照、semver 兼容性检查 |
| 云端备份与恢复 | ❌ 未实现 | |
| 同步数据类型 | ⚠️ 不完整 | 仅同步 progress/bookmarks/bookshelf，缺笔记/生词/词典配置 |

---

### 1.6 词典

| 功能 | 状态 | 备注 |
|------|------|------|
| MDict (.mdx/.mdd) | ✅ 已完成 | rs-mdict 引擎，支持精确/前缀查询 |
| 音频提取 | ✅ 已完成 | .mdd → WAV/SPX/MP3 字节返回 |
| 中文分词 | ✅ 已完成 | jieba-rs 编译期嵌入词典 |

---

### 1.7 统计

| 功能 | 状态 | 备注 |
|------|------|------|
| 阅读时长追踪 | ✅ 已完成 | `ReadingSession` + 每日聚合 |
| 阅读趋势图/热力图 | ✅ 已完成 | 折线图 + 周热力图 |
| 生词统计 | ✅ 已完成 | 4 种状态 (new/learning/mastered/ignored) 统计 |
| 全局阅读统计 | ✅ 已完成 | `GlobalStats` + 读书时长/本数/笔记数 |
| 阅读趋势图触摸交互 | ⚠️ 缺失 | 触摸查询被禁用 |

---

## 2. 性能基准评估

### 2.1 可测试的指标

| 指标 | 达标线 | 优秀线 | 当前状态 |
|------|--------|--------|----------|
| **首屏加载 (TTI)** | < 500ms | < 200ms | ⚠️ 未测量（有基准框架但未运行） |
| **章节切换耗时** | < 1s | < 300ms | ✅ 设计达标（4 层缓存 + lazy pagination） |
| **翻页帧率** | ≥ 55 fps | ≥ 60 fps | ⚠️ 未测量 |
| **内存占用 (RSS)** | < 150MB | < 80MB | ⚠️ 未测量 |
| **大文件处理** | 100MB | 500MB+ | ✅ 设计达标（`MAX_FILE_SIZE = 500MB`） |
| **搜索响应速度** | < 2s | < 500ms | ⚠️ 未测量（FTS5 + jieba 分词） |
| **FFI 通信开销** | < 10ms/次 | < 5ms/次 | ⚠️ 未测量 |

### 2.2 架构确保的性能特征

- **缓存层次**: Provider LRU (16) → PageStreamer LRU (4) → Chapter Content (sled KV) → Layout Cache (sled KV)
- **惰性分页**: 50K 字符阈值触发的懒加载模式，大章节首屏无等待
- **Chunked reading**: 8KB 块级读取，避免大文件全量进内存
- **缓存失效**: config_hash (xxh3) 驱动的精确缓存失效，排版参数变化自动重算
- **零拷贝 FFI**：优先 Uint8List/String，避免冗余 struct 序列化

### 2.3 基准测试现状

```
cargo bench           → 有基准框架（parsing_benchmark.rs），但正式结果未记录
TTI/内存/FFI 开销     → 无测量手段
```

**评价：** 架构设计充分考虑了性能，但**缺乏量化的性能验证数据**。需要补充基准运行和分析。

---

## 3. 工程质量评估

### 3.1 测试覆盖

| 层级 | 统计 | 状态 |
|------|------|------|
| Rust lib tests | **147 passed / 0 failed / 8 ignored** | ✅ |
| Rust integration tests | 11 套集成测试，其中 **search_test 4 套失败** | ⚠️ |
| Dart unit tests | **44 测试加载失败**（FFI 编译期类型转换错误） | ❌ |
| Widget tests | 10 个 widget 测试文件 | ⚠️ 存在加载问题 |
| Feature tests | statistics/backup/sync 各有单元测试 | ⚠️ 覆盖不完整 |

**Rust test 详情：**

| 测试套件 | 结果 |
|----------|------|
| `--lib`（单元测试） | 147 passed, 8 ignored ✅ |
| `api_test` | 27 passed ✅ |
| `unit_text_test` | 10 passed ✅ |
| `bilingual_test` | 8 passed ✅ |
| `vocabulary_test` | 6 passed ✅ |
| `progress_test` | 5 passed ✅ |
| `storage_test` | 7 passed ✅ |
| `api_chapter_test` | 5 passed ✅ |
| `text_rich_test` | 5 passed ✅ |
| `search_test` | **12 passed, 4 failed** ❌ |

**search_test 失败详情：**

```
failures:
    test_clear_all_index      — 清除后应无搜索结果
    test_get_index_stats      — 断言 left(17) == right(1): 应增加 1 本书
    test_search_all_books     — 应该找到搜索结果
    test_search_relevance     — 应该有搜索结果
```

**Dart 测试加载失败：** 由 `frb_generated.dart` 中的 FFI 类型转换引发（`InvalidType` → `FunctionType` 转换），这是 flutter_test 的运行环境与 FRB 生成的 NRVO 代码之间的编译期不兼容。

### 3.2 静态分析

| 检查 | 结果 | 状态 |
|------|------|------|
| `cargo clippy -- -D warnings` | **33 errors** | ❌ 需清理 |
| `dart analyze --fatal-infos` | **1 error / 4 warnings / 7 info** | ⚠️ 1 个编译错误 |

**clippy 33 errors 典型分布：**

- `collapsible_if` — 可合并的嵌套 if
- `needless_lifetimes` — 多余生命周期标注
- `comparison_chain` — 可简化的比较链
- `single_match` — 可简化的 match

**Dart analyze error：**

```
test/features/reader/page/widgets/reader_render_config_test.dart:22:5
  The named parameter 'searchMatchHighlight' isn't defined.
```

### 3.3 代码质量亮点

- **统一错误类型**：`AppError` 枚举覆盖 14+ 类错误，所有 FFI 函数返回 `Result<T, AppError>`
- **架构分层清晰**：API/Domain/Parser/Storage/Text/Search 六层分离
- **缓存版本控制**：`LAYOUT_CACHE_VERSION = 2` 配合版本校验
- **安全防护**：路径验证（`validate_file_path_async`）、文件大小上限（500MB）
- **i18n 基础设施**：ARB 文件 + 代码生成本地化
- **完整的分析文档**：每个 feature 有独立分析报告

### 3.4 代码质量问题

| 问题 | 严重度 | 说明 |
|------|--------|------|
| `word_count` 死数据 | P1 | 全局只写不读，MD 处 `text.len()` 语义错误 |
| `VocabularyMarkerService` 注入不一致 | P2 | page 层通过 `getIt<>()` 直接获取 |
| `BackupPage` 路由缺失 | P0 | 配置文件定义但 router 未注册 |
| `UserAgreement`/`PrivacyPolicy` 硬编码 | P2 | 50+ 段法律条文中文硬编码 |
| `检查更新`/`反馈问题` 空函数 | P0 | `onTap: () {}` — 假实现 |
| `SearchHistoryService` 无持久化 | P2 | 纯内存，重启丢失 |
| `FileStorage` 同步 `listSync()` | P2 | 可能阻塞 UI 线程 |
| `NavigationMode` 死枚举 | P3 | 定义但从未使用 |
| `Chapter` 构造重复 6 次 | P2 | 样板代码 |
| PDF 章节 `word_count` 语义错误 | P1 | 字节长度表示"字数" |

---

## 4. 各 Feature 成熟度总览

| Feature | Rust 引擎 | Dart UI | 测试覆盖 | 已知问题 | 成熟度 |
|---------|-----------|---------|----------|----------|--------|
| TXT 导入解析 | ✅ | ✅ | ✅ | — | **稳定** |
| EPUB 导入解析 | ✅ | ✅ | ✅ | — | **稳定** |
| MD 导入解析 | ✅ | ✅ | ⚠️ 有限 | — | **可用** |
| PDF 导入解析 | ✅ | ❌ 未接入 | ❌ | Dart 侧 TODO | **不可用** |
| 排版引擎 | ✅ | ✅ | ⚠️ 有限 | — | **稳定** |
| 分页阅读 | ✅ | ✅ | ⚠️ 有限 | — | **可用** |
| 全文搜索 | ✅ | ✅ | ❌ 4 失败 | FTS5 集成测试失败 | **不稳定** |
| 笔记/高亮 | ✅ | ✅ | ⚠️ 有限 | — | **可用** |
| 书签 | ✅ | ✅ | ✅ | — | **稳定** |
| 词典 (MDict) | ✅ | ⚠️ 部分 | ⚠️ 有限 | — | **可用** |
| 双语对照 | ✅ | ⚠️ 待确认 | ✅ Rust 测试 | — | **可用** |
| 阅读统计 | ✅ | ✅ | ⚠️ 不完整 | — | **可用** |
| WebDAV 同步 | N/A | ⚠️ 有缺陷 | ⚠️ 有限 | 无冲突检测/进度条 | **可用但脆弱** |
| 本地备份/还原 | ✅ | ✅ | ✅ | — | **稳定** |
| 个人中心 | N/A | ✅ | ⚠️ 有限 | 假实现项 | **可用** |
| 生词本 | ✅ | ✅ | ⚠️ 有限 | — | **可用** |

**成熟度定义：**
- **稳定**：功能完整，测试覆盖，已知问题较少
- **可用**：核心功能正常，少量未修复问题
- **不稳定**：测试失败或已知功能性 Bug
- **不可用**：关键路径断裂（PDF）

---

## 5. 差距分析与改进建议

### 5.1 功能性差距

| 优先级 | 缺失功能 | 工作量估计 | 影响 |
|--------|----------|------------|------|
| **P0** | PDF 阅读 UI 接入 | 小（API 已就绪） | 格式支持完整 |
| **P0** | TTS 听书功能 | 大（需选择引擎 + 集成） | 听书场景 |
| **P0** | 搜索集成测试修复 | 小（4 个断言错误） | CI 全绿 |
| **P1** | 笔记导出 | 中 | 数据可迁移性 |
| **P1** | 云端同步/备份 | 大 | 跨设备场景 |
| **P2** | 仿真翻页动画 | 中 | 用户体验 |
| **P2** | 搜索历史持久化 | 小 | 用户体验 |

### 5.2 工程质量改进建议

| 优先级 | 项目 | 说明 |
|--------|------|------|
| **P0** | 修复 clippy 33 warnings | 阻塞 `-D warnings` CI |
| **P0** | 修复 search_test 4 个失败 | 搜索功能回归 |
| **P0** | 修复 Dart 测试加载失败 | 测试基础设施问题 |
| **P1** | 运行并记录正式基准测试 | 量化性能指标 |
| **P1** | 清除死代码（word_count, NavigationMode 等） | 减少维护负担 |
| **P1** | 修复 BackupPage 路由缺失 | 导航断裂 |
| **P1** | 修复"检查更新"/"反馈问题"空函数 | P0 假实现 |

### 5.3 性能验证建议

- `cargo bench` 运行并记录结果到文档
- 增加 TTI（首屏加载）测量脚本
- 增加 FFI 调用开销测量（Dart 侧计时）
- 使用 Android Profiler / Xcode Instruments 测量内存

---

## 6. 综合评价

| 维度 | 得分 | 评语 |
|------|------|------|
| **功能完备性** | ★★★★☆ | 核心阅读功能完整，排版引擎超出同类水平；短板在 PDF/TTS/云端同步 |
| **架构质量** | ★★★★★ | Rust/Dart 分层清晰，缓存层次设计专业，错误处理统一 |
| **性能设计** | ★★★★☆ | 架构到位但缺量化验证 |
| **测试覆盖** | ★★☆☆☆ | Rust lib 测试好（147 pass），集成/Dart 测试存在断裂 |
| **代码整洁** | ★★★☆☆ | 有冗余代码和死数据需清理，clippy 33 errors |
| **文档** | ★★★★★ | 各 feature 分析文档、架构图、冗余分析、包体积分析齐全 |

**总体判断：Zephyr Reader 在排版引擎和 Rust 核心功能上已达到生产级品质，部分模块（TXT/EPUB 解析、排版、笔记）成熟度可对标多看阅读。主要的工程质量短板在测试断裂和 clippy 警告上，功能性短板在 PDF/TTS/云端同步三个位置。**
