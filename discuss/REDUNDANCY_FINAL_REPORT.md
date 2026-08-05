# 冗余清理最终报告

> 合并自历史报告：`archived/redundancy/REDUNDANCY_REPORT.md`、`REDUNDANCY_REPORT_RUST.md`、`REDUNDANCY_REPORT_V2.md` 和 `REDUNDANCY_PLAN.md`。
>
> 本文是当前清理结论，不是产品路线。产品范围以 `READING_BOUNDARIES.md`、`ROADMAP.md` 和 ADR-020/021 为准。

## 结论摘要

项目已经从“Builtin + Readium + TXT/EPUB 多路线”收敛为 EPUB Readium MVP。历史清理已移除大批无调用代码、旧生成物、TXT/Builtin 管线、全文搜索和生词本模块；当前 Rust 主要负责导入、元数据、封面、目录、存储和业务 API，Flutter/Readium 负责正文视口与阅读壳层。

当前不应恢复或继续维护：

- TXT 阅读器、Builtin 排版和 Rust 分页/IR 管线
- 双引擎切换、跨引擎位置映射和旧 Readium PoC 方案
- 已退出的全文搜索 UI、生词本、笔记/批注链路
- WiFi 传书空壳、旧翻译适配器链和 wordlist JSON 资产

## 已完成清理

### Rust

- 删除旧 `pipeline/`、Builtin 富文本解析和 IR 缓存模块。
- 删除 TXT 解析、章节检测和旧内容提供者链。
- 删除无调用的旧 FRB API、仓储函数和中间人 service。
- 删除搜索、生词本、笔记等已退出功能的无调用写入面。
- 删除仅服务旧管线的 Cargo 依赖。
- 保留 EPUB 导入所需的 `parser/epub` 活跃模块：归档读取、元数据、目录和资源路径处理。

### Flutter

- 删除旧 Builtin 阅读链、搜索、生词本、笔记和 WiFi 传书 UI。
- 删除旧 FRB 生成物和无调用组件。
- 清理未使用的 pub 依赖、SettingsKeys 和 l10n 键。
- 阅读正文统一由 `flutter_readium` 的 Readium 视口承载。

### 文档与资产

- 旧架构、PoC、FFI 候选和冗余扫描报告移至 `discuss/archived/`。
- 当前入口文档不再把历史能力描述为当前功能。
- 旧 wordlist JSON、WiFi 上传页面等无调用资产已移除。

## 当前保留项

以下内容虽然部分 API 尚未接入完整 UI，但仍属于当前代码或数据边界，不能仅因调用次数少就删除：

- EPUB 元数据、封面和目录解析
- 书籍、分类、书签、进度、会话和统计存储
- 词典资源管理 API
- 备份/还原和 WebDAV 数据链路
- `rust/src/api/` 的当前 FRB 接口及其生成绑定

删除这些内容需要单独更新领域模型、数据库兼容策略和产品边界。

## 当前验证原则

新增清理必须同时满足：

1. 没有生产调用方、测试调用方或生成边界依赖。
2. 不属于 `READING_BOUNDARIES.md` 的 Must 能力。
3. 不破坏现有数据库迁移和已安装用户的数据兼容。
4. Rust 清理后通过 `cargo clippy --lib -- -D warnings` 与 Rust 测试。
5. Flutter 清理后通过 `dart analyze --fatal-infos` 与相关 Flutter 测试。
6. 修改 FRB API 后重新运行 codegen，禁止手改生成文件。

## 不再作为待办的历史候选

历史报告中的以下候选已经被当前路线否定或完成，不应重新加入 ROADMAP：

- 恢复 TXT/Builtin 阅读器
- 恢复双引擎统一和跨引擎 Locator 映射
- 重新接入全文正文索引、生词本写入和笔记选区链
- 用旧 Rust IR 管线替代 Readium 视口

如果未来确实恢复其中任何一项，必须新建 ADR，并同步更新边界、领域模型、测试和数据迁移方案。

## 历史来源

- [`archived/redundancy/REDUNDANCY_REPORT.md`](archived/redundancy/REDUNDANCY_REPORT.md)
- [`archived/redundancy/REDUNDANCY_REPORT_RUST.md`](archived/redundancy/REDUNDANCY_REPORT_RUST.md)
- [`archived/redundancy/REDUNDANCY_REPORT_V2.md`](archived/redundancy/REDUNDANCY_REPORT_V2.md)
- [`archived/redundancy/REDUNDANCY_PLAN.md`](archived/redundancy/REDUNDANCY_PLAN.md)
