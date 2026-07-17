---
id: M2
phase: Q2
slug: dictionary-mdx-path-unvalidated
severity: medium
original_id: q2-002
---

# 词典 MDX 文件路径持久化且缺乏完整性校验

## 文件

`lib/features/reader/page/reader_dictionary_panel.dart`

## 描述

`_ensureMdictConfigured` 方法将用户通过文件选择器选取的 MDX 字典路径直接存入 SharedPreferences（键 `SettingsKeys.dictMdxPath`），并在下次应用启动时自动加载。

加载时的检查：
```dart
final savedMdx = prefs.getString(_kPrefMdxPath);
if (savedMdx != null && File(savedMdx).existsSync()) {
```

## 安全问题

1. **路径完整性校验不足**：仅检查文件是否存在（`existsSync()`），没有任何签名、哈希或完整性验证来确保路径未被篡改。
2. **SharedPreferences 可被修改**：在设备已 root 或存在备份恢复攻击的场景下，攻击者可以修改 SharedPreferences 中的数据，将 `dictMdxPath` 指向任意 `.mdx` 文件。
3. **可导致任意文件读取**：通过控制加载的 MDX 文件路径，攻击者可能引导应用读取并解析任意文件。MDX 文件解析器是 Rust FFI 实现——可能存在解析器级漏洞。

## 风险场景

- 设备备份恢复攻击：攻击者修改备份中的 SharedPreferences 设置
- root 设备上本地恶意进程修改 SharedPreferences
- 通过引导解析指向受控路径的 MDX 文件，触发 Rust 侧缓冲区溢出或其他解析器漏洞

## 修复建议

- 对存储的 MDX 路径添加完整性校验（哈希或带签名的引用）
- 限制 MDX 路径只能指向应用沙盒内的预期目录
- 启动时验证路径的合法性，而非仅检查文件存在性

```
PoC-Status: theoretical
Protocol: local
Auth-Required: no
Auth-Roles-Required: anonymous
```
