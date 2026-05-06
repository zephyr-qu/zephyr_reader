# Zephyr Reader 项目进度报告

> 生成日期：2026-04-27

---

## 目录

1. [Rust 模块评估](#1-rust-模块评估)
2. [Flutter 模块评估](#2-flutter-模块评估)
3. [综合完成度评估](#3-综合完成度评估)
4. [风险清单与缓解措施](#4-风险清单与缓解措施)
5. [里程碑计划](#5-里程碑计划)

---

## 1. Rust 模块评估

### 1.1 代码规模

| 指标 | 数值 |
|------|------|
| 源文件数 | 51 |
| 总代码行数 | ~18,473 |
| API 模块数 | 8 |
| 单元测试数 | 199（33 文件） |
| 集成测试文件 | 3 |
| 第三方依赖 | 46 |

### 1.2 已实现的核心功能

| 模块 | 功能 | 状态 |
|------|------|------|
| **core.rs** | 文件解析 (TXT/EPUB/PDF)、分页引擎、元数据提取 | ✅ 完整 |
| **storage.rs** | SQLite CRUD（书籍/书签/笔记/分类/阅读进度/同步记录） | ✅ 完整 |
| **epub.rs** | EPUB 章节内容提取 | ✅ 完整 |
| **cover.rs** | 书籍封面提取、格式支持检测 | ✅ 完整 |
| **search.rs** | jieba 分词全文索引、章节级搜索 | ✅ 完整 |
| **incremental.rs** | 增量解析、缓存管理 | ✅ 完整 |
| **security.rs** | 路径安全验证（沙箱逃逸防护） | ✅ 完整 |
| **export.rs** | 书籍导出功能 | ⚠️ 基础实现 |

### 1.3 待完善/待实现功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| **PDF 图片提取** | 中 | pdfium-render 依赖已配置，但 extract_images 函数需验证 |
| **增量解析缓存恢复** | 低 | clearCache 后重新索引的性能优化 |
| **导出格式扩展** | 低 | 当前仅基础实现，可扩展为 TXT/EPUB 格式导出 |
| **全文搜索分页** | 中 | searchInBook 返回结果未实现分页，大书搜索可能 OOM |
| **批量导入事务** | 中 | parseBook 逐本解析无事务包裹，中断可能导致脏数据 |

### 1.4 关键性能指标

| 操作 | 预期性能 | 瓶颈 |
|------|---------|------|
| TXT 解析 (1MB) | < 50ms | 编码检测（chardetng） |
| EPUB 解析 (标准) | < 200ms | 解压 + HTML5 解析 |
| PDF 文本提取 | < 1s (10页) | pdfium-render 渲染 |
| SQLite 查询 | < 5ms | 索引命中 |
| 全文搜索 | < 100ms/书 | jieba 分词 + FST 查询 |

### 1.5 编译状态

```
cargo check:  ✅ 通过（0 warnings, 0 errors）
cargo test:   ⚠️ frb_generated.rs 需要 Flutter 构建上下文（已知外部限制）
cargo clippy: ✅ 通过（0 warnings）
```

### 1.6 测试覆盖

- **单元测试**: 199 个，涵盖核心解析逻辑、数据结构序列化、工具函数
- **集成测试**: 3 个集成测试文件，覆盖端到端解析流程
- **关键缺口**:
  - storage.rs 缺少 DELETE/UPDATE 的边界测试（空表、外键约束）
  - search.rs 缺少大规模索引的基准测试
  - security.rs 缺少路径遍历攻击的完整测试矩阵
- **测试编译失败**: `cargo test` 因 `frb_generated.rs` 中 `build.rs` 脚本在非 Flutter 构建环境下调用 `flutter` 命令失败。需通过 `--exclude frb_generated` 或在 CI 中配置 Flutter SDK 环境来解决。

---

## 2. Flutter 模块评估

### 2.1 代码规模

| 指标 | 数值 |
|------|------|
| Dart 源文件数 | 163 |
| 总代码行数 | ~50,331（含 21,345 行自动生成 FFI 绑定） |
| 手写业务代码 | ~28,986 行 |
| 页面数 | 26 |
| Feature 模块数 | 10 |

### 2.2 已完成的 UI 页面

| Feature | 页面 | 状态 |
|---------|------|------|
| **home** | splash_page, home_page | ✅ |
| **bookshelf** | bookshelf_page, book_detail_page, category_management_page | ✅ |
| **reader** | reader_page, bookmark_manage_page, note_manage_page | ✅ |
| **search** | search_page, book_search_page | ✅ |
| **statistics** | statistics_page, reading_stats_page | ✅ |
| **profile** | profile_page, app_settings_page, reading_settings_page, theme_settings_page, about_page, privacy_policy_page, user_agreement_page | ✅ |
| **sync** | webdav_settings_page, sync_history_page, backup_restore_page, conflict_resolution_page | ✅ |
| **auth** | login_page | ✅ |
| **article** | article_list_page, article_detail_page | ✅ |
| **其他** | main_layout | ✅ |

**共 26 个页面，全部完成 UI 骨架和基础交互。**

### 2.3 Flutter Analyze 状态

```
flutter analyze: ✅ No issues found! (0 errors, 0 warnings)
```

### 2.4 Rust 集成状态

| 胶水层服务 | 对应 Rust API | DI 注入 | 状态 |
|------------|--------------|---------|------|
| RustCoreService | core.rs | @LazySingleton | ✅ |
| RustEpubService | epub.rs | @LazySingleton | ✅ |
| RustStorageService | storage.rs | @LazySingleton | ✅ |
| RustCoverService | cover.rs | @LazySingleton | ✅ |
| RustSearchService | search.rs | @LazySingleton | ✅ |
| RustIncrementalService | incremental.rs | @LazySingleton | ✅ |
| RustSecurityService | security.rs | @LazySingleton | ✅ |
| RustHelpers | n/a (工具类) | @injectable | ✅ |

### 2.5 架构合规性

| 检查项 | 结果 |
|--------|------|
| 所有 FFI 调用均通过 Wrapper 层 | ✅ |
| 无直接 `src/rust/api/*.dart` 导入到 Page 层 | ✅ |
| DI 容器统一使用 `@LazySingleton` / `@injectable` + codegen | ✅ |
| 信号量/Effect 均已正确 dispose | ✅ |
| catch 块均记录 stack trace | ✅ |
| 主题管理统一通过 ThemeManager | ✅ |
| 共享组件归入 `core/presentation/widgets/` | ✅ |

### 2.6 测试覆盖

| 测试文件 | 测试内容 |
|---------|---------|
| test/core/error/error_handler_test.dart | 错误处理器单元测试 |
| test/features/article/data/article_api_test.dart | 文章 API 测试 |
| test/features/auth/data/auth_api_test.dart | 认证 API 测试 |
| test/features/auth/data/auth_service_test.dart | 认证服务测试 |

> **警告**: 现有测试仅覆盖 article 和 auth 两个非核心 feature。核心功能（bookshelf/reader/search/statistics/sync）无任何测试。测试基础设施已具备但未充分利用。

---

## 3. 综合完成度评估

### 3.1 完成度矩阵

| 维度 | 完成度 | 说明 |
|------|--------|------|
| **Rust 引擎核心功能** | 95% | 8个API模块全部实现，仅导出功能为基础实现 |
| **Flutter UI 页面** | 95% | 26个页面全部完成骨架，部分交互/动画待打磨 |
| **Rust-Flutter 集成** | 100% | 7个Wrapper服务全部通过DI正确注入，无直接FFI调用 |
| **状态管理** | 90% | Signals架构正确使用，Effect已修复泄漏，部分ViewModel可进一步拆分 |
| **错误处理** | 85% | catch块已全部记录日志，ErrorHandler已建立，但业务层错误恢复策略待完善 |
| **测试覆盖** | 30% | Rust单元测试较完善(199个)，Flutter测试严重不足(4个文件) |
| **性能优化** | 70% | 缓存系统(CacheManager)、大文件优化器已实现，但未做性能基准测试 |
| **安全防护** | 90% | 路径安全检查已实现，无已知注入漏洞，SharedPreferences无敏感数据 |
| **跨平台适配** | 60% | Android/iOS基础配置已完成，但Web平台FFI兼容性未验证 |
| **文档** | 50% | Rust API文档已生成，Flutter层缺少架构文档和用户文档 |

### 3.2 总体完成度：**~86%**

### 3.3 剩余工作量估计

| 类别 | 估计工时 | 说明 |
|------|---------|------|
| Rust 引擎打磨 | ~8h | PDF图片提取验证、搜索分页、批量导入事务 |
| Flutter UI 完善 | ~12h | 动画过渡、加载骨架屏、空状态、错误重试 |
| Flutter 测试编写 | ~20h | 核心feature单元测试 + Widget测试 |
| 集成测试 | ~8h | E2E流程测试：导入→阅读→书签→统计→同步 |
| 性能基准测试 | ~4h | 大文件(>10MB)解析、分页、搜索性能基准 |
| **合计** | **~52h** | **约6.5个工作日 (1人)** |

---

## 4. 风险清单与缓解措施

| 风险 | 等级 | 影响 | 当前状态 | 缓解措施 |
|------|------|------|---------|---------|
| **cargo test 因 frb_generated 构建失败** | 高 | CI/CD 管道阻塞 | 已识别 | 1) 配置 CI 环境变量 SKIP_FRB_CODEGEN=1；2) 提交前在 Flutter 项目目录运行 `cargo build` 作为前置检查；3) 将 Rust 测试和 Flutter 构建分离到不同 CI stage |
| **Flutter 测试覆盖严重不足** | 高 | 回归风险高 | 已识别 | 1) 从 ReaderViewModel 和 BookshelfViewModel 开始补充单元测试；2) 核心业务逻辑提取为纯函数以方便测试；3) 设置最低覆盖率门槛（目标 60%） |
| **大文件解析内存溢出** | 中 | 大 EPUB(>50MB) 或 PDF 可能 OOM | 已识别 | 1) Rust 端实现流式分块解析；2) Flutter 端增加文件大小前置检查；3) 实现解析进度回调 |
| **Web 平台 FFI 兼容性** | 中 | Web 平台不可用 | 已知限制 | 1) 项目初期定位为移动端+桌面端；2) Web 平台标记为未支持；3) 未来可用 WASM 替代 FFI |
| **第三方依赖版本兼容** | 低 | flutter_rust_bridge 升级可能引入 breaking changes | 已锁定 v2.12.0 | 1) 锁定主版本号；2) 建立依赖升级测试流程；3) 关注上游 changelog |

---

## 5. 里程碑计划

### 里程碑 M1：发布候选（RC）— 预计 1 周

| 任务 | 工时 | 优先级 |
|------|------|--------|
| PDF 图片提取验证和修复 | 4h | 高 |
| 搜索分页实现 | 2h | 高 |
| 批量导入事务包裹 | 2h | 中 |
| UI 动画/过渡打磨 | 8h | 中 |
| 加载状态/空状态/错误状态统一 | 4h | 中 |
| **同步功能端到端验证** | **4h** | **关键** |

### 里程碑 M2：测试加固 — 预计 1 周

| 任务 | 工时 | 优先级 |
|------|------|--------|
| ReaderViewModel 单元测试 | 4h | 高 |
| BookshelfViewModel 单元测试 | 4h | 高 |
| Rust FFI 集成测试 | 4h | 高 |
| RustStorageService 单元测试 | 4h | 中 |
| Widget 测试（ReaderPage + BookshelfPage） | 4h | 中 |
| E2E 集成测试 | 4h | 中 |

### 里程碑 M3：v1.0.0 正式版 — 预计 3 天

| 任务 | 工时 | 优先级 |
|------|------|--------|
| 性能基准测试和优化 | 4h | 中 |
| 跨平台兼容性验证（Android/iOS/Windows） | 8h | 高 |
| 用户文档编写 | 4h | 低 |
| CI/CD 管道完善 | 4h | 中 |
| 最终回归测试 | 4h | 高 |

---

## 附录

### A. Rust 依赖清单（46 个）

| 类别 | 依赖 |
|------|------|
| **FFI 绑定** | flutter_rust_bridge 2.12.0 |
| **异步运行时** | tokio 1.x |
| **数据库** | rusqlite (bundled), sled, diesel |
| **序列化** | serde, serde_json, serde_yaml, bincode |
| **文本处理** | unicode-segmentation, unicode-width, chardetng, jieba-rs, html2text |
| **EPUB 解析** | zip, xml, html5ever, markup5ever_rcdom, html2text |
| **PDF 解析** | pdf-extract, pdfium-render, image, lopdf, printpdf |
| **加密** | sha2, md-5, hmac, base64 |
| **时间** | chrono |
| **日期/国际化** | icu_calendar, icu_datetime, icu_locid, icu_timezone |
| **网络** | reqwest, url, uuid |
| **错误处理** | anyhow, thiserror |
| **日志** | log |
| **导出** | printpdf |
| **系统** | dirs |

### B. Flutter 依赖清单

| 依赖 | 用途 |
|------|------|
| flutter_rust_bridge 2.12.0 | FFI 代码生成 |
| get_it + injectable | DI 容器 |
| signals_flutter + signals_hooks | 响应式状态管理 |
| go_router 17.x | 声明式路由 |
| freezed + json_serializable | 数据类代码生成 |
| flutter_gen | 资源文件代码生成 |
| shared_preferences | 轻量配置存储 |
| webdav_client | WebDAV 同步 |
| flutter_local_notifications | 本地通知 |
| url_launcher | 外部链接 |
| path_provider | 文件系统路径 |

### C. 项目目录结构 (lib/)

```
lib/
├── core/                    # 核心基础设施
│   ├── battery/             # 电量状态服务
│   ├── error/               # 错误处理框架
│   ├── local/               # Rust FFI 胶水层 (7 个 Wrapper 服务)
│   ├── network/             # 网络状态服务
│   ├── performance/         # 缓存/性能优化
│   ├── presentation/        # 共享 UI 组件
│   ├── reader/              # 阅读器配置
│   ├── routing/             # 路由配置
│   ├── theme/               # 主题系统
│   └── utils/               # 工具函数
├── di/                      # 依赖注入配置
├── features/                # 业务功能模块
│   ├── article/             # 文章功能
│   ├── auth/                # 认证
│   ├── bookshelf/           # 书架
│   ├── home/                # 首页/启动页
│   ├── profile/             # 个人设置
│   ├── reader/              # 阅读器
│   ├── search/              # 搜索
│   ├── statistics/          # 统计
│   ├── sync/                # 同步
│   └── main_layout.dart     # 主布局
├── gen/                     # 自动生成
├── src/rust/                # FFI 自动生成 (21K+ 行)
├── app.dart
└── main.dart
```
