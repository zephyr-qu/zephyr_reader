# Zephyr Reader — 阅读核心边界 v1.5

> **状态**：已冻结 · **EPUB Readium MVP 范围已定义**（2026-07-31）
> 来源：`xinxi.md` → … → [xinxi-round5.md](./xinxi-round5.md)  
> 冲突时以本文为准；技术细节见 [DECISIONS.md](./DECISIONS.md)、[DOMAIN_MODEL.md](./DOMAIN_MODEL.md)。

---

## 一页纸

| 项 | 内容 |
| ---- | ------ |
| **一句话** | 离线手机/平板阅读器：休闲 + 学习（含双语），给爱读书的人。 |
| **主格式** | **EPUB only（当前 MVP）** |
| **默认渲染** | flureadium 封装的 Readium EPUB Navigator |
| **80%** | 打开/渲染稳定 · 目录/翻页/进度可用 · 排版可调 · 恢复可靠 |
| **MVP 进度真理** | Readium Locator（按 `bookId` 保存）— [ADR-020](./adr/020-epub-readium-mvp.md) |
| **技术分工** | Readium 原生视口渲染；Flutter 壳层、设置、目录与状态 |
| **当前阶段** | **EPUB Readium MVP** — [ROADMAP.md](./ROADMAP.md) |
| **明确不做** | PDF 阅读、账号/多端同步、复杂 CSS、章内搜索 UI |

---

## 架构原则

> 在现有臃肿上：**先理清、减冗余** → 再在清晰边界上加 IR/块分页；**保留 staging**。

---

## Must / Should / Won't

### Must

| 类别 | 内容 |
| ------ | ------ |
| 阅读 | EPUB 打开、原生渲染、目录、上/下页、进度与 Locator 恢复 |
| 排版 | 字号、主题即时生效 |
| UI | 返回、工具栏显隐、目录抽屉、设置、基础 TTS |
| 可靠性 | viewport ready 门槛、错误可重试、幂等关闭、退出 flush |
| 场景 | 纯文本 EPUB、含图 EPUB、复杂 CSS EPUB、位置恢复 |

### Should（MVP 后）

- pageTurn 合并为 pagination 皮肤（ADR-002）✅
- **版式像原书（窄义）**：font-family、段首缩进、段间距、基础强调（ADR-010）
- 大章降级 + 提示（Phase 4 目标：scroll→IR 消除降级）
- 主题色（阅读器 accent）
- 双语：设置开关；**独立 feature 模块**（ADR-011）

### Won't

- TXT/Builtin 阅读器（当前 MVP 不做）
- 双引擎策略、位置桥与统一 Backend seam
- 书签、批注、搜索、生词的完整阅读页接入
- PDF 阅读（主仓不投入；文档不对用户承诺）
- **多设备同步、账号**（WebDAV 仅作备份/手动工具，非产品级同步）
- ~~WebView / 完整 HTML 排版引擎~~ → 见下方注释
- CSS float / 多栏 / 复杂表格
- **章内搜索 UI**（全书搜索已覆盖；D4-C）
- 对标微信读书全量能力

> **Phase R1 更新**：原 "WebView / 完整 HTML 排版引擎" 禁令调整为：
> - ✅ 允许封装后的 Readium EPUB Navigator（通过 flureadium 接入 Readium SDK）
> - ❌ 不允许业务代码或 UI 层直接依赖裸 WebView / Platform View
> - ❌ 不在 Readium Adapter 目录外引入 `flureadium` 类型依赖

---

## ADR 索引

| ADR | 内容 |
| ----- | ------ |
| [001](./adr/001-reading-position-truth.md) | charOffset 进度 |
| [002](./adr/002-pageturn-is-pagination-skin.md) | pageTurn 皮肤 |
| [003](./adr/003-block-pagination-ir.md) | IR + 块分页看图 |
| [004](./adr/004-cross-chapter-staging.md) | 保留 staging |
| [005](./adr/005-bilingual-optional.md) | 双语可选 |
| [006](./adr/006-rust-flutter-division.md) | Rust/Flutter 分工 |
| [007](./adr/007-plaintext-segmentation-stability.md) | plainText 分段冻结 |
| [008](./adr/008-ir-image-plain-placeholder.md) | IR 图片 plain 占位 |
| [009](./adr/009-scroll-ir-unification.md) | Scroll 统一 IR |
| [010](./adr/010-block-css-in-ir.md) | IR 块基础 CSS |
| [011](./adr/011-bilingual-feature-module.md) | 双语 feature 模块 |
| [012](./adr/012-staging-prefetch-guarantee.md) | Staging 零 loading |
| [013](./adr/013-flutter-metrics-calibration.md) | Metrics 回传校准 |
| [014](./adr/014-api-path-unification.md) | 分页 API 路径统一 |
| [017](./adr/017-reading-offset-utf16-contract.md) | 阅读坐标统一为 UTF-16 code unit |
| [019](./adr/019-engine-unification.md) | Readium 双引擎统一接入（已被 ADR-020 取代） |
| [020](./adr/020-epub-readium-mvp.md) | EPUB Readium MVP（当前路线；取代 ADR-019） |
---

## North Star 加载路径

```
书籍记录 → EPUB 文件 URI → openPublication
         → ReadiumReaderWidget 原生视口
         → onReady 后订阅事件 + 应用 EPUBPreferences
         → Locator 更新进度 + 节流保存
         → Flutter 壳层接入目录/翻页/设置/TTS
```

---

## 修订记录

| 版本 | 日期 | 说明 |
| ------ | ------ | ------ |
| v1.0 | 2026-06-18 | 第二轮冻结 |
| v1.1 | 2026-06-18 | 第三轮闭环；Phase 0 完成 |
| v1.2 | 2026-06-25 | Phase 4 范围；ADR-009～013；章内搜索降为 Won't |
| v1.3 | 2026-07-03 | Phase 4 退出 → Phase 5 启动；ADR-014；MD 格式残留清除 |
| v1.4 | 2026-07-22 | Phase R1 更新：允许封装的 Readium EPUB Navigator；ADR-019 已通过 |
| v1.5 | 2026-07-31 | 当前路线收敛为 EPUB Readium MVP；ADR-020 取代 ADR-019 |
