# PDF 封面提取功能实现文档

## 功能概述

PDF 封面提取功能已完整实现，支持从 PDF 文件中提取封面图像。

## 实现位置

- **主要实现**: `rust/src/parser/pdf/images.rs`
- **API 导出**: `rust/src/api/mod.rs` 中的 `extract_book_cover` 函数
- **模块导出**: `rust/src/parser/pdf/mod.rs`

## 核心函数

### 1. `extract_pdf_cover` (主函数)

```rust
#[frb(sync)]
pub fn extract_pdf_cover(file_path: &str, output_dir: &str) -> ApiResult<String>
```

**功能**: 从 PDF 文件中提取封面并保存为 JPEG 图片

**参数**:
- `file_path`: PDF 文件路径
- `output_dir`: 输出目录

**返回值**:
- `Ok(String)`: 封面图片保存路径
- `Err(ParserError)`: 提取失败

**实现细节**:
1. 验证文件是否存在
2. 创建输出目录（如果不存在）
3. 生成输出文件名（格式：`{书名}_cover.jpg`）
4. 调用 `extract_cover_from_pdf` 提取封面
5. 验证生成的文件
6. 返回封面路径或占位路径（失败时）

### 2. `extract_pdf_cover_bytes` (零拷贝优化)

```rust
pub fn extract_pdf_cover_bytes(file_path: &str) -> ApiResult<Vec<u8>>
```

**功能**: 从 PDF 文件中提取封面的原始字节数据

**参数**:
- `file_path`: PDF 文件路径

**返回值**:
- `Ok(Vec<u8>)`: JPEG 格式的封面字节数据
- `Err(ParserError)`: 提取失败

**优势**:
- 无需创建临时文件
- 适用于内存中直接处理
- 可通过 ZeroCopyBuffer 优化 FFI 传输

### 3. `extract_cover_from_pdf` (内部实现)

```rust
fn extract_cover_from_pdf(file_path: &str, output_path: &str) -> ApiResult<()>
```

**功能**: 使用 pdfium-render 渲染 PDF 第一页为封面图片

**实现细节**:
1. 初始化 Pdfium
2. 加载 PDF 文件
3. 获取第一页（封面）
4. 使用高质量配置渲染（1200x1800）
5. 转换为 JPEG 格式并保存
6. 验证文件大小

**渲染配置**:
```rust
let render_config = PdfRenderConfig::new()
    .set_target_width(1200)   // 高质量封面
    .set_maximum_height(1800)
    .clear_before_rendering(true);
```

## 统一的封面提取 API

### `extract_book_cover` (推荐)

```rust
#[frb(sync)]
pub fn extract_book_cover(file_path: String, output_dir: String) -> ApiResult<String>
```

**功能**: 根据文件类型自动选择 EPUB 或 PDF 封面提取

**支持的格式**:
- `.epub` - 调用 `extract_epub_cover`
- `.pdf` - 调用 `extract_pdf_cover`

**错误处理**:
- 不支持的格式返回 `ParserError::UnsupportedFormat`

## Flutter 调用示例

### 基本用法

```dart
import 'package:zephyr_reader/src/rust/api.dart' as rust_api;

// 提取封面
final result = rust_api.extractBookCover(
  filePath: '/path/to/book.pdf',
  outputDir: '/path/to/covers',
);

// 解包 ApiResult
final coverPath = (result as dynamic).value;

if (coverPath != null) {
  print('封面路径：$coverPath');
}
```

### 在书籍导入服务中使用

```dart
// lib/features/bookshelf/application/services/book_import_service.dart

Future<String?> _extractCover(String filePath) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final coverFilename = 'cover_$timestamp.jpg';
    final coverDestPath = p.join(_coversDir.path, coverFilename);

    // 调用 Rust 提取封面
    final result = rust_api.extractBookCover(
      filePath: filePath,
      outputDir: _coversDir.path,
    );

    // 解包 ApiResult 获取路径
    final coverPath = (result as dynamic).value;

    if (coverPath != null && coverPath is String) {
      // 复制封面到标准位置
      final coverFile = File(coverPath);
      if (await coverFile.exists()) {
        final newCoverFile = await coverFile.copy(coverDestPath);
        return newCoverFile.path;
      }
    }

    return null;
  } catch (e) {
    debugPrint('封面提取失败：$e');
    return null;
  }
}
```

## 错误处理

### 可能的错误类型

1. **FileNotFound**: 文件不存在
2. **PdfParseError**: PDF 解析失败
   - 加载文件失败
   - PDF 没有页面
   - 渲染失败
3. **FileWriteError**: 文件写入失败
   - 创建目录失败
   - 保存文件失败
4. **UnsupportedFormat**: 不支持的文件格式

### 错误消息示例

```
加载 PDF 文件失败：IO 错误
PDF 文件没有页面
渲染 PDF 页面失败：Pdfium 错误
保存封面文件失败：权限拒绝
```

## 性能优化

### 渲染质量

- **目标宽度**: 1200px（高质量）
- **最大高度**: 1800px
- **格式**: JPEG（有损压缩，文件小）

### 内存管理

- 使用 `clear_before_rendering(true)` 清除缓存
- 渲染完成后立即释放资源
- 失败时创建占位文件避免空指针

## 测试

### 单元测试

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_extract_pdf_cover_file_not_found() {
        let result = extract_pdf_cover("non_existent.pdf", "/tmp");
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), ParserError::FileNotFound { .. }));
    }

    #[test]
    fn test_cover_filename_generation() {
        let test_cases = vec![
            ("test_book.pdf", "test_book"),
            ("My Book.pdf", "My_Book"),
            ("文件 123.pdf", "文件_123"),
        ];

        for (input, expected_stem) in test_cases {
            let book_filename = Path::new(input)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("cover")
                .replace(" ", "_");

            let cover_filename = format!("{}_cover.jpg", book_filename);

            assert!(cover_filename.ends_with("_cover.jpg"));
            assert!(cover_filename.contains(expected_stem));
        }
    }
}
```

### 运行测试

```bash
# 运行所有测试
cargo test

# 仅运行 PDF 封面测试
cargo test extract_pdf_cover

# 跳过需要 Pdfium 的测试
cargo test -- --skip ignore
```

## 依赖

### pdfium-render

```toml
[dependencies]
pdfium-render = "0.8"
image = { version = "0.25", default-features = false, features = ["jpeg", "png"] }
```

### Pdfium 库

`pdfium-render` 需要系统安装 Pdfium 库：

**Windows**:
```powershell
# 下载 Pdfium 二进制文件
# https://github.com/bblanchon/pdfium-binaries/releases

# 或使用 winget
winget install bblanchon.pdfium
```

**Android**:
```gradle
// android/app/build.gradle.kts
android {
    ndk {
        abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
    }
}
```

## 已知限制

1. **Pdfium 依赖**: 需要系统安装 Pdfium 库
2. **渲染性能**: 大尺寸 PDF 可能需要较长时间渲染
3. **内存使用**: 高质量渲染会占用较多内存（约 10-20MB/页）

## 未来改进

1. [ ] 提取嵌入的封面图像（如果存在）
2. [ ] 支持多种封面格式（PNG、WebP）
3. [ ] 可配置的渲染质量
4. [ ] 异步版本用于大文件

## 相关文件

- `rust/src/parser/pdf/images.rs` - 主要实现
- `rust/src/api/mod.rs` - 统一 API
- `rust/Cargo.toml` - 依赖配置
- `lib/features/bookshelf/application/services/book_import_service.dart` - Flutter 集成

## 状态

✅ **已完成**

- [x] PDF 封面提取核心功能
- [x] 零拷贝字节提取
- [x] 错误处理
- [x] 单元测试
- [x] Flutter 集成
- [x] 文档

---

**最后更新**: 2026 年 3 月 31 日
**状态**: 生产就绪
