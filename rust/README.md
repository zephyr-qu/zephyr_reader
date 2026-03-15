# Rust 阅读引擎

Zephyr Reader 的高性能双语文本解析引擎，基于 Rust 实现。

## 功能特性

- **TXT 文件解析**
  - 自动编码检测（UTF-8, GBK, GB2312, Big5 等）
  - 中文章节标题自动识别
  - 流式加载，支持大文件

- **EPUB 文件解析**
  - EPUB2/EPUB3 兼容
  - 目录提取
  - 元数据读取（书名、作者、封面）

- **文本处理**
  - 中英文智能断行
  - 标点符号避首避尾
  - 中英文混排优化
  - 章节标题自动检测

- **流式加载**
  - 大文件分块读取
  - 内存回收机制
  - 内容分页输出

## 目录结构

```
rust/
├── src/
│   ├── api/                  # FFI API 接口
│   │   └── mod.rs            # 主要接口函数
│   ├── ffi/                  # FFI 数据类型
│   │   ├── mod.rs
│   │   ├── types.rs          # 数据结构定义
│   │   └── error.rs          # 错误类型定义
│   ├── parser/               # 文件解析器
│   │   ├── mod.rs
│   │   ├── txt/              # TXT 解析
│   │   │   ├── mod.rs
│   │   │   ├── decode.rs     # 编码检测
│   │   │   └── parse.rs      # 内容解析
│   │   └── epub/             # EPUB 解析
│   │       ├── mod.rs
│   │       ├── unzip.rs      # EPUB 解压
│   │       ├── parse.rs      # 内容解析
│   │       └── toc.rs        # 目录提取
│   ├── text_process/         # 文本处理
│   │   ├── mod.rs
│   │   ├── line_break.rs     # 断行规则
│   │   ├── chapter_detect.rs # 章节检测
│   │   └── typeset.rs        # 排版优化
│   ├── stream/               # 流式加载
│   │   ├── mod.rs
│   │   ├── file_stream.rs    # 文件流
│   │   └── page_stream.rs    # 分页流
│   ├── utils/                # 工具函数
│   │   ├── mod.rs
│   │   ├── path_util.rs      # 路径工具
│   │   └── string_util.rs    # 字符串工具
│   └── lib.rs                # 库入口
├── Cargo.toml                # Rust 依赖配置
└── Cargo.lock                # 依赖锁定文件
```

## 环境要求

### 必需工具

1. **Rust 工具链** (1.75.0+)
   ```bash
   # 安装 Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   
   # 验证安装
   rustc --version
   cargo --version
   ```

2. **Android 交叉编译支持** (仅 Android)
   ```bash
   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
   ```

3. **C 编译器**
   - **Windows**: Visual Studio Build Tools 2019+
   - **Linux**: gcc, clang
   - **macOS**: Xcode Command Line Tools

## 构建命令

### 检查编译

```bash
cd rust/
cargo check
```

### 开发构建

```bash
cargo build
```

### 发布构建

```bash
cargo build --release
```

### 生成 FRB 绑定代码

在项目根目录运行：

```bash
flutter_rust_bridge_codegen build
```

### 运行测试

```bash
cargo test
```

## API 接口

### 初始化

```rust
// Dart
await RustLib.init();
```

### 解析书籍

```rust
// Dart
// 自动识别格式
final result = await RustLib.instance.api.parseBookFile(filePath: path);

// 或指定格式
final txtResult = await RustLib.instance.api.parseTxtFile(filePath: path);
final epubResult = await RustLib.instance.api.parseEpubFile(filePath: path);
```

### 获取章节内容

```rust
// Dart
final pages = await RustLib.instance.api.getChapterPages(
  filePath: path,
  chapterId: chapterId,
  config: TypesetConfig(
    pageWidth: 1080,
    pageHeight: 1920,
    fontSize: 18,
    lineSpacing: 1.5,
    // ...
  ),
);
```

### 文本排版

```rust
// Dart
final typeset = RustLib.instance.api.typesetText(
  content: text,
  config: TypesetConfig(
    pageWidth: 1080,
    pageHeight: 1920,
    fontSize: 18,
    lineSpacing: 1.5,
    language: LanguageType.auto,
  ),
);
```

## 数据结构

### BookInfo

```dart
class BookInfo {
  String bookId;          // 书籍唯一标识
  String title;           // 书名
  String author;          // 作者
  int chapterCount;       // 章节数
  int totalCharacters;    // 总字符数
  String filePath;        // 文件路径
  String fileType;        // 文件类型 (txt/epub)
  String? coverPath;      // 封面路径 (EPUB)
}
```

### ChapterInfo

```dart
class ChapterInfo {
  int chapterId;          // 章节 ID
  String title;           // 章节标题
  int startIndex;         // 起始位置
  int endIndex;           // 结束位置
  int contentLength;      // 内容长度
  int index;              // 章节序号
}
```

### PageContent

```dart
class PageContent {
  int chapterId;          // 章节 ID
  int pageIndex;          // 页码
  String content;         // 页面内容
  bool isLastPage;        // 是否最后一页
}
```

### TypesetConfig

```dart
class TypesetConfig {
  int pageWidth;                  // 页面宽度
  int pageHeight;                 // 页面高度
  int fontSize;                   // 字体大小
  double lineSpacing;             // 行间距
  double letterSpacing;           // 字间距
  double paragraphSpacing;        // 段落间距
  int firstLineIndent;            // 首行缩进
  LanguageType language;          // 语言类型
}
```

## 错误处理

所有 API 调用都可能抛出异常，建议使用 try-catch 处理：

```dart
try {
  final result = await RustLib.instance.api.parseBookFile(filePath: path);
  // 处理结果
} catch (e) {
  // 处理错误
  print('解析失败：$e');
}
```

## 性能优化

1. **大文件处理**: 使用流式 API，避免一次性加载整个文件
2. **异步调用**: 所有解析 API 都是异步的，不会阻塞 UI
3. **内存管理**: 及时释放不再使用的页面内容
4. **缓存**: 对已解析的章节进行缓存

## 开发注意事项

1. **编码问题**: TXT 文件会自动检测编码，但建议在导入时告知用户
2. **EPUB 兼容性**: 支持主流 EPUB2/EPUB3 格式，但某些特殊 EPUB 可能无法解析
3. **章节检测**: 使用正则表达式匹配章节标题，可能无法识别所有格式
4. **排版规则**: 中英文混排已优化，但特殊格式可能需要手动调整

## 测试

运行单元测试：

```bash
cargo test
```

测试覆盖：
- 编码检测
- 章节提取
- 断行规则
- 排版优化
- 文件流读取

## 许可证

本项目为个人自用项目，不对外分发。
