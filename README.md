# Zephyr Reader - 双语离线阅读器

<div align="center">

**纯本地、高性能、双语友好的安卓离线小说阅读器**

[![Flutter](https://img.shields.io/badge/Flutter-3.22.0+-blue.svg)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Rust-1.75.0+-orange.svg)](https://www.rust-lang.org)
[![Platform](https://img.shields.io/badge/Platform-Android%208.0+-green.svg)](https://www.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## 📖 项目简介

Zephyr Reader（Zephyr 阅读器）是一款基于 **Flutter + Rust** 架构开发的安卓端双语离线小说阅读器。项目采用纯本地设计，无后台、无广告、无数据收集，专注于中文、英文双语小说的阅读体验。

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
- 支持本地 TXT、EPUB 格式文件导入
- 批量导入与书籍元数据自动提取
- 书籍列表展示、重命名、删除管理
- 阅读进度自动记忆与恢复

### 📖 核心阅读
- 上下滚动 / 左右翻页两种阅读模式
- 中文、英文双语排版优化
  - 中文：合理断行，无单字悬空、标点避首避尾
  - 英文：按单词断行，禁止单词跨行拆分
  - 中英混排：行高统一、间距一致
- 字体大小、行间距、字间距、段落间距可调
- 多背景色切换（护眼白、暗夜黑、豆沙绿）
- 全屏沉浸阅读，自动隐藏状态栏、导航栏

### 🎨 主题与适配
- 亮色主题 / 深色主题 / 纯黑夜间主题
- 跟随系统深色模式自动切换
- 手机端：单页布局，单手操作便捷
- 平板端：横屏双栏布局，竖屏大屏适配
- 横竖屏切换自动保存进度，无缝过渡

### 🔧 进阶功能
- 书签标记与管理
- 阅读历史记录
- WebDAV 数据同步（阅读进度、设置、书籍元数据）
- 屏幕常亮、亮度调节
- 翻页动画切换

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────────────┐
│              Flutter 应用层 (UI 与交互)                   │
│  ├─ 页面层：书架、阅读页、设置页、导入页                  │
│  ├─ 路由层：go_router 路由管理                            │
│  ├─ 状态层：主题、设备、阅读设置状态管理                  │
│  └─ 业务服务层：存储、桥接、同步、权限服务                │
└───────────────────────────┬─────────────────────────────┘
                            │ flutter_rust_bridge (FFI)
┌───────────────────────────┴─────────────────────────────┐
│              Rust 核心引擎层 (高性能计算)                  │
│  ├─ FFI 接口层：标准化接口暴露                            │
│  ├─ 解析层：TXT 解析、EPUB 解析、编码检测                  │
│  ├─ 文本处理层：中英断行规则、混排优化、章节提取          │
│  └─ 流式加载层：大文件分块读取、内容分页                  │
└───────────────────────────┬─────────────────────────────┘
                            │ 本地文件读写
┌───────────────────────────┴─────────────────────────────┐
│                本地数据层 (持久化存储)                     │
│  ├─ 文档存储：APP 私有目录的书籍源文件                      │
│  ├─ 键值存储：Hive，存储配置、进度、WebDAV 信息            │
│  └─ 结构化存储：SQLite，存储书籍元数据、章节信息          │
└─────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端 UI** | Flutter 3.22.0+ | 跨平台 UI 框架 |
| **后端逻辑** | Rust 1.75.0+ | 高性能文本解析引擎 |
| **桥接层** | flutter_rust_bridge 2.0.0+ | FFI 桥接，自动生成绑定 |
| **本地存储** | Hive 2.2.3 | 轻量级键值存储 |
| **路由管理** | go_router 14.0.0+ | 官方路由方案 |
| **WebDAV** | webdav_client 1.2.0+ | 同步客户端 |
| **支持平台** | Android 8.0+ | API 26+ |

---

## 📁 项目结构

```
zephyr_reader/
├── android/                 # Android 原生配置
├── lib/                     # Flutter 主工程
│   ├── main.dart            # 应用入口
│   ├── app.dart             # 应用根组件
│   ├── config/              # 全局配置（主题、路由、设备）
│   ├── routes/              # 路由管理
│   ├── common/              # 公共能力（工具、组件、扩展）
│   ├── models/              # 数据模型
│   ├── services/            # 业务服务层
│   │   ├── rust_bridge/     # Flutter-Rust 桥接封装
│   │   ├── storage/         # 本地存储服务
│   │   ├── book/            # 书籍管理业务
│   │   ├── read/            # 阅读核心业务
│   │   └── webdav/          # WebDAV 同步服务
│   ├── pages/               # 页面层（MVVM 结构）
│   │   ├── home/            # 书架首页
│   │   ├── reader/          # 核心阅读页
│   │   ├── import/          # 书籍导入页
│   │   └── setting/         # 全局设置页
│   └── global/              # 全局状态管理
├── native/reader_core/      # Rust 核心引擎
│   ├── Cargo.toml           # Rust 依赖配置
│   ├── flutter_rust_bridge.yaml
│   └── src/
│       ├── lib.rs           # 库入口
│       ├── ffi/             # FFI 接口层
│       ├── parser/          # 解析核心层（TXT/EPUB）
│       ├── text_process/    # 文本处理层（断行、排版）
│       └── stream/          # 流式加载层
├── assets/                  # 静态资源（字体、图标）
├── test/                    # 单元测试
├── integration_test/        # 集成测试
├── pubspec.yaml             # Flutter 依赖配置
├── Cargo.toml               # Rust 工作空间配置
└── README.md                # 项目说明文档
```

---

## 🚀 快速开始

### 环境要求

- **Flutter SDK**: 3.22.0+
- **Rust**: 1.75.0+（最新稳定版）
- **Android SDK**: API 26+（Android 8.0）
- **Android Studio**: Hedgehog 或更高版本

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
# 进入 Rust 目录
cd native/reader_core/

# 检查 Rust 代码
cargo check

# 构建 Rust 库（调试）
cargo build

# 构建 Rust 库（发布）
cargo build --release

# 运行 Rust 测试
cargo test
```

### 添加 Rust 函数

1. 在 `native/reader_core/src/` 目录下创建或编辑模块文件
2. 使用 `#[flutter_rust_bridge::frb]` 宏标记需要导出的函数
3. 运行代码生成器生成桥接代码
4. 在 Dart 代码中通过生成的桥接模块调用

**示例** (`native/reader_core/src/api/simple.rs`):

```rust
/// 问候函数示例
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// 解析 TXT 文件
#[flutter_rust_bridge::frb(async)]
pub fn parse_txt_file(file_path: String) -> Result<BookInfo, AppError> {
    // 实现解析逻辑
}
```

---

## 📋 开发计划

### 阶段划分

| 阶段 | 工作内容 | 优先级 |
|------|---------|--------|
| **第一阶段** | 环境搭建与基础框架（主题、路由、设备适配、桥接配置） | P0 |
| **第二阶段** | Rust 核心解析引擎（TXT/EPUB 解析、编码处理、断行规则） | P0 |
| **第三阶段** | 书籍管理与书架页面（导入、列表、元数据存储） | P0 |
| **第四阶段** | 核心阅读页（文本渲染、翻页、进度记忆、章节跳转） | P0 |
| **第五阶段** | 平板适配与夜间模式完善（自适应布局、主题体系） | P0 |
| **第六阶段** | WebDAV 同步与推荐功能（书签、阅读历史、进阶设置） | P1 |
| **第七阶段** | 测试优化与打包发布（性能优化、兼容性测试、签名打包） | P0 |
| **第八阶段** | 扩展功能（全书搜索、自定义字体、阅读统计） | P2 |

---

## 📄 需求文档

本项目包含完整的开发文档：

- [需求规格说明书](docs/需求规格说明书.md) - 功能需求、非功能需求、验收标准
- [开发设计文档](docs/开发设计文档.md) - 技术架构、模块设计、开发规范

---

## 🔒 隐私与安全

- ✅ **纯本地存储** - 所有数据存储在 APP 私有目录，无数据上传
- ✅ **最小权限** - 仅申请必要的存储权限，无冗余权限
- ✅ **无广告无 SDK** - 纯净无干扰，无第三方 SDK 嵌入
- ✅ **无数据收集** - 不收集任何用户行为数据
- ✅ **WebDAV 加密** - 账号密码本地加密存储

---

## 📝 许可证

本项目采用 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。

---

## 🤝 贡献

本项目为个人自用项目，主要服务于个人阅读需求。如有建议或问题，欢迎提交 Issue。

---

## 📧 联系方式

- 项目仓库：[GitHub](https://github.com/your-username/zephyr_reader)
- 问题反馈：[Issues](https://github.com/your-username/zephyr_reader/issues)

---

<div align="center">

**Zephyr Reader** - 如和风般轻盈的阅读体验

Made with ❤️ by Flutter + Rust

</div>
