# ADR-011：双语抽成独立 Feature 模块

- **状态**：已接受（D7，2026-06-25）
- **日期**：2026-06-25

## 决策

1. 双语（翻译 API、双语 UI、对照高亮）迁入 **独立 feature 模块**（如 `lib/features/bilingual/` 或等价边界）；**主阅读链**（解析 → IR → 分页/staging）**零 import** 双语实现。
2. 双语仍为用户设置项可选（ADR-005 语义不变）；**不是**主加载链 intent 分支。
3. 构建上支持通过 feature flag / `--no-default-features`（或 Dart 等价 conditional import 策略）在开发核心引擎时跳过双语编译与测试。

## 理由

- 架构卫生：Phase 4 改 IR/staging 时不应被翻译 API 耦合拖慢。
- 编译与测试迭代：核心引擎开发者可关闭双语加速反馈循环。
- 为未来 in-tree 插件化（OCR 翻译、离线词典扩展）预留边界。

## 后果

- **接受**：`ReaderViewModel` 等通过窄接口（回调/可选 delegate）挂双语，而非 core 直接依赖 `TranslationViewModel` 实现细节。
- **拒绝**：双语逻辑散落在 `chapter_load_orchestrator` / Rust 主链。
- **不变**：双语 UX 仍可用；仅模块边界调整。

## 关联

- [ADR-005](./005-bilingual-optional.md)、[PHASE4_SCOPE.md](../PHASE4_SCOPE.md) P4-5
- [xinxi-round2.md](../xinxi-round2.md) G4-c → **B**（本轮关闭）
