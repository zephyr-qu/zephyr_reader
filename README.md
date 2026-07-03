# Zephyr Reader - 双语离线阅读器

**纯本地、高性能、双语友好的离线小说阅读器**

Flutter 3.41.2+ · Rust 1.80.0+ · Android 8.0+ / iOS 15+

---

## 📖 项目简介

Zephyr Reader（Zephyr 阅读器）是一款基于 **Flutter + Rust** 架构开发的跨平台双语离线小说阅读器。项目采用纯本地设计，无后台、无广告、无数据收集，专注于中文、英文双语小说的阅读体验。

核心特性：
- 📱 **纯离线使用** - 核心功能 100% 离线可用，仅 WebDAV 同步需要网络
- 🚀 **高性能解析** - Rust 实现文本解析，大文件加载流畅无卡顿
- 📖 **双语排版** - 中文、英文同等优先的排版优化，断词准确、标点规范
- 🌙 **多主题支持** - 亮色/深色/纯黑夜间主题，适配不同阅读环境
- 📐 **设备适配** - 手机、平板双端自适应，横竖屏无缝切换
- 🔄 **WebDAV 同步** - 支持跨设备数据同步与备份

---

## ✨ 核心功能

### 📚 书籍管理
- 支持 TXT、EPUB 格式导入（见 [discuss/READING_BOUNDARIES.md](discuss/READING_BOUNDARIES.md)）
- 批量导入与书籍元数据自动提取
- 书籍列表展示、分类标签、搜索、置顶
- 阅读进度自动记忆与恢复

### 📖 核心阅读
- 上下滚动 / 左右翻页两种阅读模式
- 中文、英文双语排版优化
  - 中文：合理断行，无单字悬空、标点避首避尾
  - 英文：按单词断行，禁止单词跨行拆分
  - 中英混排：行高统一、间距一致
- 字体大小、行间距、字间距、段落间距可调
- 高亮批注、书签标记
- 双语对照阅读（中英对齐）
- 离线词典查词（MDict 格式）
- 全书搜索
- 全屏沉浸阅读，自动隐藏状态栏、导航栏

### 🎨 主题与适配
- 亮色主题 / 深色主题 / 纯黑夜间主题
- 跟随系统深色模式自动切换
- 手机端：单页布局，单手操作便捷
- 平板端：横屏双栏布局，竖屏大屏适配
- 横竖屏切换自动保存进度，无缝过渡

### 🔧 进阶功能
- 阅读统计（日/周/月/总览）
- WebDAV 数据同步（阅读进度、设置、书籍元数据）
- 生词本（复习管理）
- 数据库备份与还原
- 屏幕常亮、亮度调节
- 翻页动画切换

---

## 🏗️ 技术架构

```
┌──────────────────────────────────────────────────────────┐
│                  Flutter 应用层 (UI)                       │
│  ├─ lib/features/{reader,bookshelf,home,statistics,…}/   │
│  │   └─ page/ application/ domain/ data/ (Clean Arch)    │
│  ├─ 路由: go_router                                      │
│  └─ 状态: signals + setState                             │
├────────────────────── flutter_rust_bridge FFI ──────────┤
│                  Rust 核心引擎 (高性能)                    │
│  ├─ 解析: TXT/EPUB + 封面提取                         │
│  ├─ 排版: 中英混排断行 + letter/paragraph/page margin   │
│  ├─ 搜索: FTS5 + jieba 中文分词                         │
│  ├─ 词典: MDict 离线词典 (.mdx/.mdd)                    │
│  └─ 存储: sqlx SQLite + sled KV (排版缓存)              │
├────────────────────────── 本地文件 ─────────────────────┤
│              本地数据层 (Rust 管理)                       │
│  ├─ SQLite: 书籍/章节/进度/笔记/统计/会话                │
│  └─ sled KV: 排版缓存 (非 Hive)                          │
└──────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端 UI** | Flutter 3.41.2+ | 跨平台 UI 框架 |
| **后端逻辑** | Rust 1.80.0+ | 高性能文本解析引擎 |
| **桥接层** | flutter_rust_bridge 2.12.0+ | FFI 桥接，自动生成绑定 |
| **本地存储** | SQLite (sqlx) + sled KV | Rust 管理，Hive 已移除 |
| **状态管理** | signals + signals_flutter | 响应式状态 |
| **依赖注入** | injectable + getIt | DI 框架 |
| **数据类** | freezed | 不可变数据模型 |
| **路由管理** | go_router 14.0.0+ | 官方路由方案 |
| **WebDAV** | webdav_client 1.2.0+ | 同步客户端 |
| **支持平台** | Android 8.0+ / iOS 15+ | API 26+ |

---

## 📁 项目结构

```
zephyr_reader/
├── android/                 # Android 原生配置
├── ios/                     # iOS 原生配置
├── lib/                     # Flutter 主工程
│   ├── main.dart            # 应用入口
│   ├── app.dart             # 应用根组件
│   ├── core/                # 共享基础设施
│   ├── features/            # 功能模块
│   │   ├── article/         # 长文阅读
│   │   ├── bookshelf/       # 书架（导入、分类、详情）
│   │   ├── home/            # 首页（最近阅读、统计概览）
│   │   ├── profile/         # 个人设置
│   │   ├── reader/          # 阅读器（VM Facade + ChapterManager + 5 个独立 Controller）
│   │   ├── search/          # 全书搜索
│   │   ├── statistics/      # 阅读统计（图表、日周月报）
│   │   ├── sync/            # WebDAV 同步 + 备份/还原
│   │   └── vocabulary/      # 生词本（单词管理）
│   ├── shared/              # 共享 UI 组件
│   ├── l10n/                # 国际化
│   ├── gen/                 # FRB 自动生成（勿手动编辑）
│   └── di/                  # 依赖注入（injectable + getIt）
├── rust/                    # Rust 核心引擎
│   ├── Cargo.toml           # Rust 依赖配置
│   ├── flutter_rust_bridge.yaml
│   ├── RUST_ENGINE_SPEC.md  # Rust 编码规范
│   ├── migrations/          # SQLite 迁移
│   └── src/
│       ├── lib.rs           # 库入口
│       ├── api/             # FRB 暴露接口层
│       ├── parser/          # 解析器（TXT/EPUB）
│       ├── storage/         # 存储（SQLite repos + sled KV）
│       ├── search/          # FTS5 全文搜索
│       ├── text/            # 文本处理（断行、排版、章节检测、双语对齐）
│       ├── dictionary/      # 离线词典（MDict .mdx/.mdd）
│       ├── domain/          # 领域类型与错误
│       └── utils/           # 文件 IO、安全校验
├── assets/                  # 静态资源（dictionary.mdx, 图片）
├── test/                    # 单元测试
├── integration_test/        # 集成测试
├── pubspec.yaml             # Flutter 依赖配置
└── README.md                # 项目说明文档
```

---

## 🚀 快速开始

### 环境要求

- **Flutter SDK**: 3.41.2+
- **Rust**: 1.80.0+（最新稳定版）
- **Android SDK**: API 26+（Android 8.0）
- **iOS**: 15.0+
- **Android Studio / Xcode**: 最新稳定版
- **flutter_rust_bridge_codegen**: 可选，仅在修改 Rust API 后重新生成绑定时需要

### 环境搭建

#### 1. 安装 Flutter

```bash
# 下载 Flutter SDK 并配置环境变量
# 参考：https://docs.flutter.dev/get-started/install
```

#### 2. 安装 Rust

```bash
# Windows (PowerShell)
winget install Rustlang.Rust.MSVC

# 或使用 rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 添加 Android 交叉编译目标
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```

#### 3. 安装 flutter_rust_bridge 代码生成工具

```bash
cargo install flutter_rust_bridge_codegen
```

#### 4. 获取项目依赖

```bash
cd zephyr_reader
flutter pub get
```

#### 5. 生成 Rust 桥接代码

```bash
flutter_rust_bridge_codegen build
```

#### 6. 运行应用

```bash
# 连接 Android 设备或启动模拟器
flutter devices

# 运行应用
flutter run
```

---

## 🛠️ 开发指南

### 常用命令

```bash
# 获取依赖
flutter pub get

# 生成 Rust 桥接代码
flutter_rust_bridge_codegen build

# 运行应用（调试模式）
flutter run

# 构建正式版 APK
flutter build apk --release \
  --target-platform android-arm64,android-arm,android-x64 \
  --split-per-abi

# 代码分析
flutter analyze

# 运行单元测试
flutter test

# 运行集成测试
flutter test integration_test/

# 清理编译产物
flutter clean
```

### Rust 相关命令

```bash
# 检查 Rust 代码
cargo check

# Rust 单元测试
cargo test

# Rust lint
cargo clippy
```

### 添加 Rust 函数

1. 在 `rust/src/api/` 目录下创建或编辑模块文件
2. 使用 `#[frb]` 宏标记需要导出的函数（FRB v2 自动扫描所有 `pub fn`）
3. 运行 `flutter_rust_bridge_codegen generate` 重新生成桥接代码
4. 在 Dart 代码中通过 `api/` 路径导入生成的绑定

**示例** (`rust/src/api/example.rs`):

```rust
use crate::domain::AppError;
use flutter_rust_bridge::frb;

/// 纯内存计算 → sync
#[frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// 有 I/O 操作 → async
#[frb]
pub async fn parse_txt_file(file_path: String) -> Result<String, AppError> {
    // 实现解析逻辑
}
```

---

## 📋 项目状态

### 已完成
  | 阶段 | 工作内容 |
  |------|---------|
  | **基础框架** | Flutter 工程 + Rust 引擎 + FRB 桥接 + 主题/路由/DI/设备适配 |
  | **解析引擎** | TXT/EPUB 格式解析、编码检测、章节提取、封面提取 |
  | **存储层** | SQLite (sqlx) + sled KV 排版缓存、Repository 模式、数据库备份/还原 |
  | **阅读核心** | 双语排版、分页渲染、翻页、进度记忆、章节跳转、高亮批注、双语对照高亮 |
  | **排版引擎** | 文本断行、分块排版、标点优化、CSS 适配、lazy/eager 双模式 |
  | **进阶功能** | 全书搜索 (FTS5)、离线词典 (MDict)、双语对齐、TTS 朗读 |
  | **WebDAV** | 数据同步、冲突解决、备份与还原、自动同步、同步历史 |
  | **阅读统计** | 日/周/月/总览统计、阅读会话记录、生词本 |
  | **WiFi 传书** | HTTP 服务器上传 TXT/EPUB，Web 管理页面 |
  | **学习与笔记** | 笔记管理、高亮管理、生词复习、书签管理、分类过滤、导出 |
  | **设置面板** | TTS 朗读设置、排版与字体设置、主题与亮度、其他设置、关于页面 |
  | **国际化** | 中文/英文完整本地化（ARB）、跟随系统区域 |
  | **文章管理** | 长文列表、详情阅读、API 集成 |
  | **UI 组件库** | 自适应布局、空状态、骨架屏、Setting tiles、连接状态提示条 |
  | **集成测试** | `test_driver/e2e_flow_test.dart` 5 组 15 个用例，Page Object 模式 |
  | **FFI 测试修复** | `vocabulary_marker_service_test.dart` 动态 RustLib 初始化 + E2E 套件 |
  | **虚假通过测试** | `vocabulary/home/profile` 重构为动态 RustLib 初始化 + 真实断言 |
  | **零 HookBuilder 测试** | 新增 `bookmark_manage_page` + `book_search_page` 两个信号绑定测试 |
  | **ReaderVM 重构** | VM 从 1000→487 行（-51%），提取 ChapterManager + ReadingSessionManager，删除 SettingsController 镜像层和 FFI 透传，5 个独立 Controller 可单独测试 |

### 进行中（Phase 4 — 引擎完善）

详见 [discuss/PHASE4_SCOPE.md](discuss/PHASE4_SCOPE.md) · [discuss/ROADMAP.md](discuss/ROADMAP.md)

  | 工作 | 说明 | 优先级 |
  |------|------|--------|
  | **Scroll 统一 IR** | 消除 scroll/pagination 双管线 | 🔴 高 |
  | **IR 块基础 CSS** | scroll 与分页段首缩进/段距一致 | 🔴 高 |
  | **Staging 硬保证** | 跨章零可见 loading | 🔴 高 |
  | **Metrics 回传** | Flutter TextPainter 校准 Rust 分页 | 🟠 中 |
  | **双语 feature 模块** | 主链零依赖 | 🟠 中 |

> **不在当前范围**：PDF 阅读、章内搜索 UI、多端账号同步（以 [discuss/READING_BOUNDARIES.md](discuss/READING_BOUNDARIES.md) 为准）。