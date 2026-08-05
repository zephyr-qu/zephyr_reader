# Zephyr Reader Rust 层

Rust 是 Flutter 的本地能力层，通过 `flutter_rust_bridge` 暴露薄 API。当前实现围绕 EPUB Readium MVP，不再承担正文排版或 TXT 阅读。

## 职责

- EPUB 导入：解析书名、作者、章节和封面路径
- 封面提取与本地文件管理
- 书籍、分类、书签、进度、会话、统计和词典管理
- SQLite 迁移、仓储和备份/还原
- FRB API 的错误转换与异步边界

EPUB 正文视口与阅读排版由 Flutter 侧的 `flutter_readium` 承担。Rust 不应重新引入 Builtin 分页器、TXT 解析器或第二套阅读位置模型。

## 目录

```text
src/api/              FRB 导出 API，保持薄封装
src/domain/           领域模型、仓储、业务服务
src/parser/epub/      EPUB 导入、目录和资源读取
src/infra/            SQLite 连接池、初始化和备份基础设施
src/common/           错误与安全工具
migrations/           SQLite schema 迁移
tests/                Rust 集成测试
```

当前 API 模块：`backup`、`book`、`bookmark`、`category`、`cover`、`dictionary`、`engine_position`、`progress`、`session`、`stats`。

## 开发约束

- FFI 导出函数使用 `Result<T, AppError>`，不让 panic 穿过边界
- 不在 FFI 调用中执行阻塞操作；异步工作使用 Tokio
- 优先使用 FRB 可直接映射的 `String`、`Vec<u8>` 等类型
- 禁止手动修改 FRB 生成文件；修改 API 源文件后运行 codegen

## 常用命令

```bash
cargo check
cargo clippy --lib -- -D warnings
cargo test
```

仓库级验证还应运行：

```bash
dart analyze --fatal-infos
flutter test
```

## 规范入口

当前产品边界、路线和架构决策见仓库根目录的 [`discuss/`](../discuss/)：

- [`READING_BOUNDARIES.md`](../discuss/READING_BOUNDARIES.md)
- [`ROADMAP.md`](../discuss/ROADMAP.md)
- [`adr/020-epub-readium-mvp.md`](../discuss/adr/020-epub-readium-mvp.md)
- [`adr/021-flutter-readium-migration.md`](../discuss/adr/021-flutter-readium-migration.md)
