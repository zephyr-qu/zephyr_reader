# Zephyr Reader — 阅读核心边界 v1.5

> **状态**：已冻结 · **EPUB Readium MVP 范围已定义**（2026-07-31）
> 来源：历史需求问卷与后续 ADR；当前冲突以本文、`DOMAIN_MODEL.md` 和 `DECISIONS.md` 为准。
> 冲突时以本文为准；技术细节见 [DECISIONS.md](./DECISIONS.md)、[DOMAIN_MODEL.md](./DOMAIN_MODEL.md)。

---

## 一页纸

| 项 | 内容 |
| ---- | ------ |
| **一句话** | 离线手机/平板阅读器：休闲 + 学习（含双语），给爱读书的人。 |
| **主格式** | **EPUB only（当前 MVP）** |
| **默认渲染** | flutter_readium 封装的 Readium EPUB Navigator |
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

### Should（MVP 后候选，未立项）

- pageTurn 合并为 pagination 皮肤（ADR-002）✅
- **版式像原书（窄义）**：font-family、段首缩进、段间距、基础强调（ADR-010）
- 阅读体验细节优化（需新建或更新 ADR 后实施）
- 主题色（阅读器 accent）
- 已退出能力的恢复（包括双语）必须重新立项，不能从历史 ADR 直接恢复

### Won't

- TXT/Builtin 阅读器（当前 MVP 不做）
- 双引擎策略、位置桥与统一 Backend seam
- 书签、批注、搜索、生词的完整阅读页接入
- PDF 阅读（主仓不投入；文档不对用户承诺）
- **多设备同步、账号**（当前仅支持本地备份/还原）
- ~~WebView / 完整 HTML 排版引擎~~ → 见下方注释
- CSS float / 多栏 / 复杂表格
- **章内搜索 UI**（当前不提供全文搜索链）
- 对标微信读书全量能力

> **Phase R1 更新**：原 "WebView / 完整 HTML 排版引擎" 禁令调整为：
> - ✅ 允许封装后的 Readium EPUB Navigator（通过 flutter_readium 接入 Readium SDK）
> - ❌ 不允许业务代码或 UI 层直接依赖裸 WebView / Platform View
> - ❌ 不在 Readium Adapter 目录外引入 `flutter_readium` 类型依赖

---

## ADR 索引

| ADR | 内容 |
| ----- | ------ |
| [020](./adr/020-epub-readium-mvp.md) | EPUB Readium MVP（当前路线；取代 ADR-019） |
| [021](./adr/021-flutter-readium-migration.md) | 用 flutter_readium 替换 flureadium |
| [022](./adr/022-flutter-readium-preference-ack.md) | 等待原生 EPUB 偏好提交并重建布局 |

历史 ADR-001～019 已移至 [`archived/adr/`](archived/adr/)，保留用于追溯。
---

## North Star 加载路径

```
书籍记录 → EPUB 文件 URI → openPublication
         → ReadiumReaderWidget 原生视口
         → reader status ready 后订阅事件 + 应用 EPUBPreferences
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
| v1.6 | 2026-08-03 | 以 flutter_readium 替换 flureadium；新增 ADR-021 |
