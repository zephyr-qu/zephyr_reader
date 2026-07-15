# zs 工作日志

## 2026-07-13

### Phase 7（暂停）

- 完成了：去 spike 命名、ADR/Phase 注释清理、Rust 死代码整肃、PackedPage↔PageDescriptor 合并、typeset_calibrator 死函数清理、api/types.rs 删除、compute_config_hash 删除、core.rs→reader.rs 重命名
- 未完成（P8 合并后继续）：`buildTypesetConfig` 的 `calibration` 参数残留、`TODO(p4-5)` 双语 auto-fetch 等零星清理
- 当前分支：phase/7-cleanup-redundant-code（已提交）
- 待 P8 完成后再合并到 master

### Phase 9-A（完成于 2026-07-15）

- **API 层薄封装化**：15 个 api/*.rs 全部改造完成
- 创建/补齐 9 个 domain service.rs（category, chapter, cover, progress, vocabulary, bilingual, dictionary, note, stats）
- 修复 flutter_rust_bridge.yaml domain 路径（移除 domain::library::*, domain::reader::*, domain::profile::*, domain::language::*）
- FRB codegen 重新生成成功
- 提交：`b59cec7`
- 域名结构已明确为扁平模式（非嵌套），captured 在 `.trellis/spec/backend/directory-structure.md`

### Phase 8（开始于 2026-07-13）

- 滚动模式 Flutter 化：用 IR 统一 scroll 和分页渲染路径
- 目标：删除 `get_epub_chapter_rich_content`、`TypesetConfig` FRB、`RichParagraph` 全链路
- 分支：phase/8-scroll-flutter-migration
