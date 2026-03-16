# 编码规范 - UTF-8 唯一编码

## 📋 规范说明

本项目 **严格使用 UTF-8 编码（无 BOM）**，禁止使用其他任何编码格式。

## 🎯 为什么使用 UTF-8

1. **跨平台兼容** - Windows、macOS、Linux 统一编码
2. **国际化支持** - 完美支持中文、英文、emoji 等所有 Unicode 字符
3. **版本控制友好** - Git 默认使用 UTF-8
4. **工具链支持** - 所有现代编辑器和开发工具都支持 UTF-8

## 📁 配置文件

项目已包含以下配置文件来确保编码统一：

### 1. `.gitattributes`
强制 Git 使用 UTF-8 编码处理所有文本文件：
```
*.dart text eol=lf encoding=UTF-8
*.rs text eol=lf encoding=UTF-8
*.md text eol=lf encoding=UTF-8
```

### 2. `.editorconfig`
统一编辑器的编码设置：
```
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
```

## 🛠️ 修复乱码文件

### 方法 1：使用修复脚本

运行项目中的 `fix_all_encoding.py` 脚本：

```bash
python fix_all_encoding.py
```

该脚本会：
- 扫描所有文本文件（Dart、Rust、Markdown、YAML 等）
- 自动检测并修复非 UTF-8 编码
- 将所有文件转换为 UTF-8（无 BOM，Unix 换行）

### 方法 2：手动修复单个文件

使用 `fix_single_file.py` 修复特定文件：

```bash
python fix_single_file.py lib/features/reader/page/reader_page_new.dart
```

### 方法 3：使用编辑器

**VS Code**:
1. 打开文件
2. 点击右下角编码显示（如 "GBK"）
3. 选择 "Save with Encoding"
4. 选择 "UTF-8"

**IntelliJ IDEA / Android Studio**:
1. File → File Properties → File Encoding
2. 选择 "UTF-8"
3. 勾选 "Transparent native-to-ascii conversion"

## ✅ 编码检查清单

在提交代码前，请确保：

- [ ] 所有新增文件使用 UTF-8 编码
- [ ] 没有 BOM（字节顺序标记）
- [ ] 使用 Unix 换行符（LF，不是 CRLF）
- [ ] 文件末尾有换行符

## 🚫 常见错误

### 错误 1：中文乱码
```
错误示例：Ã¤Ã¶Ã¼（UTF-8 被误当 Latin-1 读取）
正确：äöü（UTF-8）
```

### 错误 2：标点符号乱码
```
错误示例：â€""（UTF-8 被误当 CP1252 读取）
正确："""（UTF-8）
```

### 错误 3：中文标点乱码
```
错误示例：ï¼Œ（UTF-8 被误当 ISO-8859-1 读取）
正确：，（UTF-8）
```

## 🔧 编辑器配置

### VS Code 设置
```json
{
  "files.encoding": "utf8",
  "files.eol": "\n",
  "files.insertFinalNewline": true,
  "files.trimTrailingWhitespace": true
}
```

### IntelliJ IDEA 设置
1. Settings → Editor → Code Style → General
2. 勾选 "Ensure line feed at file end on Save"
3. 设置 "Line separator" 为 "Unix and OSX"

### Git 配置
```bash
# 全局配置 Git 使用 UTF-8
git config --global core.autocrlf input
git config --global core.quotepath false
git config --global gui.encoding utf-8
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8
```

## 📝 换行符规范

| 平台 | 换行符 | 本项目使用 |
|------|--------|-----------|
| Windows | CRLF (`\r\n`) | ❌ |
| Unix/Linux | LF (`\n`) | ✅ |
| macOS (现代) | LF (`\n`) | ✅ |

**统一使用 LF（Unix 换行符）的原因：**
- Git 跨平台一致
- 减少版本控制差异
- 符合现代开发规范

## 🔍 检测编码问题

### 使用 Python 检测
```python
import chardet

with open('file.dart', 'rb') as f:
    result = chardet.detect(f.read())
    print(f"编码：{result['encoding']}, 置信度：{result['confidence']}")
```

### 使用 file 命令（Linux/macOS）
```bash
file -i filename.dart
# 输出：filename.dart: text/plain; charset=utf-8
```

### 使用 Notepad++
1. 打开文件
2. 查看 "编码" 菜单
3. 确认 "UTF-8" 被选中（不是 "UTF-8-BOM"）

## 📚 相关资源

- [UTF-8 维基百科](https://zh.wikipedia.org/wiki/UTF-8)
- [Git 编码配置](https://git-scm.com/docs/gitattributes)
- [EditorConfig 规范](https://editorconfig.org/)

## ⚠️ 违规处理

发现非 UTF-8 编码的文件：
1. 立即转换为 UTF-8
2. 在 PR 中说明原因
3. 更新本文档防止再次发生

---

**最后更新**: 2026 年 3 月 16 日  
**维护者**: Zephyr Reader 团队
