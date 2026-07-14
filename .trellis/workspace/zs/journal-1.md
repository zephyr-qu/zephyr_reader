# zs 工作日志

## 2026-07-13

### Phase 7（暂停）

- 完成了：去 spike 命名、ADR/Phase 注释清理、Rust 死代码整肃、PackedPage↔PageDescriptor 合并、typeset_calibrator 死函数清理、api/types.rs 删除、compute_config_hash 删除、core.rs→reader.rs 重命名
- 未完成（P8 合并后继续）：`buildTypesetConfig` 的 `calibration` 参数残留、`TODO(p4-5)` 双语 auto-fetch 等零星清理
- 当前分支：phase/7-cleanup-redundant-code（已提交）
- 待 P8 完成后再合并到 master

### Phase 8（开始于 2026-07-13）

- 滚动模式 Flutter 化：用 IR 统一 scroll 和分页渲染路径
- 目标：删除 `get_epub_chapter_rich_content`、`TypesetConfig` FRB、`RichParagraph` 全链路
- 分支：phase/8-scroll-flutter-migration
