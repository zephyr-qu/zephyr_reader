# Zephyr Reader

Flutter + Rust 的离线 EPUB 阅读器。当前产品路线是 **EPUB Readium MVP**：正文由封装后的 `flutter_readium` 渲染，Flutter 负责壳层、设置、目录、书架和状态，Rust 负责导入、元数据、封面、目录及本地存储。

当前边界以 [`discuss/READING_BOUNDARIES.md`](discuss/READING_BOUNDARIES.md) 和 [`discuss/ROADMAP.md`](discuss/ROADMAP.md) 为准；历史 PRD、旧引擎方案和清理报告不代表当前功能。

## 当前能力

- EPUB 导入、元数据与封面提取
- 书架、分类、书籍详情和目录
- Readium EPUB 阅读器、翻页/滚动、Locator 进度恢复
- 字号、主题、阅读排版设置
- 基础书签、阅读统计、基础 TTS
- 本地 SQLite 数据存储、备份/还原
- 中文/英文界面

当前不属于 MVP：TXT/Builtin 阅读器、PDF、裸 WebView、双引擎切换、全文搜索 UI、生词本、笔记/批注、多端账号同步。

## 架构概览

```text
Flutter UI / 状态 / 路由 / 设置
        │ flutter_rust_bridge
        ▼
Rust API（薄 FFI 层）
        ├─ EPUB 导入、元数据、封面、目录
        ├─ 书籍、分类、书签、进度、会话、统计
        └─ SQLite 存储与备份

flutter_readium ── EPUB 原生视口渲染
```

主要目录：

```text
lib/features/        Flutter 功能模块
lib/core/             路由、主题、配置和共享基础设施
lib/src/rust/         FRB 生成代码，禁止手动修改
rust/src/api/         FRB 导出 API
rust/src/domain/      领域模型与仓储
rust/src/parser/      EPUB 导入解析
rust/migrations/      SQLite 迁移
test/                 Dart/Flutter 测试
rust/tests/           Rust 测试
```

## 开发环境与命令

以 `pubspec.yaml` 和 Rust stable toolchain 为准。常用命令：

```bash
flutter pub get
dart analyze --fatal-infos
flutter test

cd rust
cargo check
cargo clippy --lib -- -D warnings
cargo test
```

修改 Rust 的 FRB API 后运行：

```bash
flutter_rust_bridge_codegen generate
```

不要手动编辑 `rust/src/frb_generated.rs`、`rust/src/frb_generated.h` 或 `lib/src/rust/` 下的生成文件；接口调整应修改 `rust/src/api/` 等源文件后重新生成。

## 规范入口

- 产品边界：[`discuss/READING_BOUNDARIES.md`](discuss/READING_BOUNDARIES.md)
- 当前路线：[`discuss/ROADMAP.md`](discuss/ROADMAP.md)
- 领域模型：[`discuss/DOMAIN_MODEL.md`](discuss/DOMAIN_MODEL.md)
- 当前决策记录：[`discuss/adr/`](discuss/adr/)
- 当前 Readium 决策：[`discuss/adr/020-epub-readium-mvp.md`](discuss/adr/020-epub-readium-mvp.md)、[`discuss/adr/021-flutter-readium-migration.md`](discuss/adr/021-flutter-readium-migration.md)
