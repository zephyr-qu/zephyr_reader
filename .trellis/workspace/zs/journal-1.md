xTh│# zs 工作日志
Asx│
A6A│## 2026-07-13
hmj│
5yK│### Phase 7（暂停）
2lC│
gWl│- 完成了：去 spike 命名、ADR/Phase 注释清理、Rust 死代码整肃、PackedPage↔PageDescriptor 合并、typeset_calibrator 死函数清理、api/types.rs 删除、compute_config_hash 删除、core.rs→reader.rs 重命名
Ped│- 未完成（P8 合并后继续）：`buildTypesetConfig` 的 `calibration` 参数残留、`TODO(p4-5)` 双语 auto-fetch 等零星清理
Ns9│- 当前分支：phase/7-cleanup-redundant-code（已提交）
Fbp│- 待 P8 完成后再合并到 master
miP│
Mof│### Phase 9（2026-07-14 ~ 至今）
r4Y│
c78│#### 9-A：API 层薄封装化 ✅
BwT│
hTv│- 15 个 api/*.rs 全部改造，创建/补齐 9 个 domain service.rs
-Yq│- 修复 flutter_rust_bridge.yaml，FRB codegen 重新生成成功
UDq│- 提交：`b59cec7`
Nvy│
8SX│#### Flutter import 路径修复 ✅
qbN│
OTm│- 完成 79 处 `library/models.dart` 等错误路径的批量替换
9Mi│- 修复 18 处 `reader/content_ir.dart` → `pipeline/types.dart`
gFV│- 文件已改，待统一提交
Hdz│
uJa│#### Task #2：PaginationSession 接口简化 ✅
mFo│
Ft2│- 假抽象类已合并到具体实现，DI 工厂已删除
U_t│- 属于之前已经完成但 ROADMAP 未标记的工作
lAQ│
fI8│#### Task #3：ChapterPaginationMode.plainText 死变体删除 ✅
Csq│
B2U│- 枚举定义已不再生成（FRB 不输出）
jHk│- `NextChapterStaging.paginationMode` 字段已删除
ZnM│- `ReaderRenderDataSource.sessionMode` getter 已删除
rtx│- 生产代码 3 处残留引用已清理
VXG│- ROADMAP 已更新标记已完成
5_o│
iGu│#### Task #4：LINE_BREAKS_STORE 行断点缓存评估 ✅
67Y│
yvQ│- 经调研，该缓存物已在 Phase 8 删除（`line_breaking.rs` + `char_width.rs` 均无）
cUB│- Flutter 侧 `TextPainter` 完成所有断行
ax8│- ROADMAP 标记已完成
IDh│
SIK│#### Task #1：IR 结构优化 + 纯 Dart 化 ✅
H7I│
lWJ│- 创建 `lib/features/reader/data/ir_types.dart`
cJ-│- 纯 Dart 类：`ReaderIrBlock`、`ReaderInlineRun`、`ReaderChapterIr` 等
IK4│- `convertChapterIrFromFrb()` 边界转换函数
idb│- RustChapterContentRepository 中 FRB 结果立即转换
Go1│- 25+ 消费者文件 import 从 `pipeline/types.dart` 切到 `ir_types.dart`
SCD│- `ReaderIrBlockLayout` 保留在 `packed_page.dart`
DAN│- 静态工具方法从 `IrReaderIrBlock` 迁入 `ReaderIrBlock` 类
D2S│- 生产代码零编译错误
C8f│
0_l│#### Phase 9 完成（2026-07-15）
_mO│
GXJ│- 全部 7 个子任务已完成/评估
XSn│- commit `01ec593`
9bl│- 已合并到 master
QQa│- 新分支 `phase/10-reader-engine` 已创建
RAn│
pPW│### 决策记录
_GY│
REX│**Phase 19 = 测试全面修复**（2026-07-15）
XQc│
IIz│鉴于 Phase 9 以来多次目录重组导致跨层测试大面积断裂，
7k9│决定将测试修复集中到 Phase 19 统一处理。
IEO│其余阶段仅在小改动时顺手修，不作为优先级。
ea1│
t4P│- ROADMAP.md 已更新：Phase 19 从 TBD 改为测试修复
rWh│- 修复范围包括：Rust 集成测试 import、Dart FRB 引用、Widget 测试构造参数
uxb│
7uf│### Phase 10 补丁 + Phase 11-A 前 3 项（2026-07-16）
hC5│
E5Z│#### 4 个假抽象接口清理 ✅
tIx│
s0u│- `ProgressRepository` + `ReaderRenderDataSource` + `ChapterContentRepository` + `BilingualReaderDelegate` 全部合并到具体类
jw7│- 删除 4 个旧文件，更新 DI 配置
w6W│- 提交 `a8638cd`
96e│
In1│#### ROADMAP 更新 ✅
M52│
So7│- Phase 10 项 7（ReaderRepository 删除）状态从 ❌ 改为 ✅
aEp│- Phase 10 项 8（假抽象接口）状态从 ❌ 改为 ✅
Vge│- Phase 11 重写：分为 Flutter 收尾（A）+ Rust 重构（B）
aXj│- Phase 13 移除已迁移到 Phase 11 的项
ggJ│
o9S│#### Phase 11-A1：engine config 迁移 ✅
ska│
tdF│- `ReaderConfig`、`ReaderTypographyDefaults`、`ReadingModeUtils`、`LanguageType`、`ReaderNotice` 五文件从 `features/reader/domain/config/` 迁至 `reader_engine/shared/config/`
p1H│- 更新 39 个文件 import 路径
9yV│- 提交 `1ff046b`
9Ip│
ewz│#### Phase 11-A2：类型搬迁 ✅
cFu│
ZEX│- `ChapterContentRepository` → `reader_engine/data/`
mlE│- `NextChapterStaging` → `reader_engine/shared/`
YF1│- `PaginationEngine` 静态工具重命名为 `PaginationUtils` → `reader_engine/pagination/engine_utils.dart`
0_t│- `PaginationViewportIndex` → `reader_engine/pagination/viewport_index.dart`
8sw│- `PageInfo` → `reader_engine/shared/`
Bvm│- 提交 `1ff046b`
SXo│
rl7│#### Phase 11-A3：删除 ReaderRenderDataSource ✅
vnD│
n6F│- 纯委托类 11KB 删除，所有消费者直接持有 `ChapterContentRepository` + `PaginationSession`
WeS│- `reader_engine/` 现在 **zero imports from `features/reader/`** ✅
KED│- 提交 `d5901d1`
CPZ│
og9│#### 待办：A4 PaginationSession 生命周期统一
J2K│
Jvt│- 推迟到下一 session
b7u│
eJF│### Phase 8（开始于 2026-07-13）
LT7│
FAG│- 滚动模式 Flutter 化：用 IR 统一 scroll 和分页渲染路径
cvN│- 目标：删除 `get_epub_chapter_rich_content`、`TypesetConfig` FRB、`RichParagraph` 全链路
7v8│- 分支：phase/8-scroll-flutter-migration
c2a│
IaW│### Phase 13 核心架构审查（2026-07-18）
5bJ│
WY7│审查结论：核心架构方向正确，不需要推倒重来。但必须先解决 source graph 污染和几个真实竞态。
tYa│
uw0│**发现的 P0 问题：**
Z0Q│- DI config 仍引用已移走的 piolium 证据文件 → 编译错误
kbt│- next/prev staging 共享同一个_stagingGen → 双向预取互相取消
Wsz│- 视口尺寸回传已断开 → session 一直使用 estimated height
zu8│
ukO│**P1 问题：**
GLI│- scroll fetch 会污染当前章 IR
Gat│- scroll 进度被保存成 100%（pageIndex 泄漏）
aDL│- EPUB 嵌套图丢弃、大 HTML 字节切片可切断标签
SkN│- 图片同步 FFI 可能卡顿（Future.microtask 不隔离）
Vyj│
4fu│**P1-P2 问题：**
yB1│- ADR-018 未完成：LayoutSnapshot→PagePlan→PackedPage 两套页模型共存
BNY│- PagePlan 和 PackedPage 都通不过 deletion test
ZMY│
h9x│**Phase 13 重排后的执行顺序：**
c5R│N0A → N0B → N2A → N2B → N3 → N4 → N1/N5
TrG│
MK9│**当前预清理阶段（N0A）：**
P9b│- 净化 source graph（piolium 污染）
rOR│- 重新生成 DI/FRB
E9x│- 增加 source-root gate
_2a│### Phase 13 执行完成（2026-07-18）
Ij9│
cO2│全部 7 个重排任务已完成。commit: 064529e1
4Ud│
cjy│N0A ✅ 净化 source graph（piolium DI 污染修复 + CI gate）
MmU│N0B ✅ 建立可信基线（155 lib test 全过）
bZd│N2A ✅ 修正确性 seam（generation 独立、viewport 修复、scroll progress）
sFU│N2B ✅ ADR-018 收口（renderer/staging/navigation 全部 PagePlan）
r9k│N3 ✅ Rust 健壮性（IR cache LRU、panic audit）
7cF│N4 ✅ 边界压力验证（门禁通过）
avt│N1/N5 ✅ 死代码清扫 + 依赖审计 + ROADMAP 更新
YWM│
k_D│遗留项（Phase 19）：
SYN│- cargo clippy --all-targets 测试侧错误
20f│- 集成测试 import 断裂
6ye│- FRB codegen 验证（需完整 build_runner）
pC6│- sync FFI 真正异步隔离
eRF│来源：architecture-review-20260718-095042.html
hBc│
N6Y│### Phase R1 重规划（2026-07-22）
8Uu│
9Gn│- 取消 PoC 阶段（R1-1 能力探针）
hRB│- CAPABILITY_MATRIX.md + LOCATOR_MAPPING_REPORT.md 已在 commit 79d7d770 产出
UT-│- 正式 Readium 接入计划，15 阶段（R01-R15），约 95-105h
yRh│- 关键决策：Rust DB 表持久化、基于 ReaderChromeShell 合并、R7→R8 顺序、Android Only 真机
QvD│- 旧任务结构 R1-1~R1-8 标记为已删除/取代
dsX│- 新任务结构 R01-R15 已创建为 pending 状态
IK5│- 待用户启动：R1（文档冻结）→ R2（核心模型）→ ...
