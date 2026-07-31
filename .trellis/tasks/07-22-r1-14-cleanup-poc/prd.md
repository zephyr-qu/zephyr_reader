# R14: 清理 PoC 与重复代码

## Goal

彻底删除 PoC 阶段引入的独立代码，保留正式平台的插件配置和 flureadium 依赖。

## 删除清单

### 文件

- `lib/readium_poc/` 整个目录
- `lib/features/reader/epub/readium_reader_page.dart`
- `lib/features/reader/epub/readium_reader_shell.dart`

### 迁移/删除

- `lib/features/reader/epub/readium_view_model.dart` → 功能移至 ReadiumSession
- `lib/features/reader/epub/readium_reader_content.dart` → 功能移至 ReadiumViewport

### 清理

- `/readium-poc` 路由
- `readiumPoc` / `readiumPocReader` 代码引用
- 书架中的 PoC 入口和测试按钮
- 重复 Chrome shell
- 无消费者的 DI 注册
- PoC Android 配置残留

### 保留

- Android/iOS 正式插件配置
- `flureadium` pubspec 依赖
- 不修改 FRB 生成文件

## Acceptance Criteria

- [ ] `rg "readium_poc|ReadiumReaderPage|ReadiumReaderShell|readiumPoc" lib/` 生产代码零结果
- [ ] Android/iOS 构建通过
- [ ] `flutter analyze --fatal-infos` 通过
- [ ] 检查点：`chore: remove readium poc and duplicate reader paths`
