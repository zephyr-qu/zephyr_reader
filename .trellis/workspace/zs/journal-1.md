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

### R10 前置：阅读进度 + 阅读会话接入（2026-08-02）✅

用户要求优先接入阅读会话与阅读进度（原先均为零调用/零写入）。

**Rust 侧：**

- 重建 `api/progress.rs`（e30fec01 曾删除）：`upsert_progress` + `get_progress`，注册到 api/mod.rs
- `StatsRepository::aggregate_session`：会话结束时按 (book_id, date) 增量聚合 reading_stats（遵守不变量）
- `create_session` 现在会同时聚合每日统计 → 统计页/主页图表不再恒 0
- 新增集成测试：create_session 两次会话的时长/字符数/会话数/last_session_id 断言
- 修复 `flutter_rust_bridge.yaml` 残留的已删模块（note/vocab/wordlist/search）→ FRB codegen 恢复可运行

**Dart 侧（ReadiumViewModel + ReaderShell）：**

- 进度双写：SharedPreferences Locator（恢复精度）保留 + 新增 Rust `reading_progress`（书架进度/统计）
- Locator→进度映射：href→flattenToc 下标；charOffset = totalProgression × total_chars（未知时退回页码位置）
- 阅读会话按章节分段：进入章节开启、章节切换 finalize、close/flush finalize；`ReadingSession` 由 `createSession` 记录
- `flush()` + AppLifecycleListener：后台/被杀时强制结束会话并保存，恢复后开启新会话（会话边界语义）
- 持久化调用全部尽力而为（失败静默），不中断阅读流程；注入点 `persistProgress`/`sessionRecorder` 供测试

**测试与门禁：**

- 新增 3 个 VM 行为测试（章节切换结束会话、close 写进度、flush 幂等）
- 修复 4 个预存在失败：测试缺少 fontFamily/readerBgColorIndex stub（fc1410b9 引入 config 读取时未同步）
- 全绿：dart analyze --fatal-infos / flutter test 15 / cargo clippy -D warnings / cargo test 101

**已知限制（后续 R10 处理）：**

- 阅读进度表 `reading_time_seconds` 由节流保存累计，粒度约 2s
- 进程被杀瞬间（无 flush 机会）最多丢失 2s 进度
- charOffset 为估算值（totalProgression × 全书字符数），非精确字符位置
- `find_by_date_range`/GlobalStats 今日统计存在 sqlx DateTime 编码类型不匹配（TEST_FINDINGS.md 已记录）

### R10 追加：Locator 全量迁移 Rust（2026-08-02）✅

用户要求：SharedPreferences 的 Locator JSON 恢复不能全迁移到 Rust 吗？

**架构依据（ADR-019）**：Locator 本就是"引擎私有位置存储，不进入领域持久化模型；只能作为快速恢复提示；与 EPUB 指纹不匹配时必须丢弃"。R3 迁移已建 `reading_engine_positions` 表（注释即"存储 Readium Locator JSON"），但 repo/API 从未实现（零代码引用该表）。

**实现：**

- 新建 `rust/src/domain/engine_positions/`（EnginePositionHint 模型 + EnginePositionHintRepository，每本书一行整体覆盖写）
- 新建 `rust/src/api/engine_position.rs`：`save_engine_position` / `get_engine_position`
- FRB codegen 重新生成（yaml 增加 engine_positions::models）
- ReadiumViewModel 移除 SharedPreferences 读写（`_positionPrefix`、setString/getString 全删），阅读流程零 SharedPreferences
- 保存：逻辑位置 upsert_progress + Locator JSON → EnginePositionHint（engine_kind='readium'，fingerprint=publication.metadata.identifier，两处独立 try 互不阻塞——恢复提示比逻辑投影更重要）
- 恢复：open() 先 await 元数据再读 hint；fingerprint 不匹配 → 丢弃 → 退回目录首章
- 注入点：enginePositionSaver / enginePositionLoader（命名参数签名，顶层默认函数）

**测试：**

- Rust：3 个集成测试（roundtrip / 覆盖写 / 未知书 None）
- Dart：3 个新测试（close 存 hint 且 opaque 可反解回 Locator、指纹匹配恢复、指纹不匹配丢弃退回目录首章）
- 全绿：cargo test 104 / clippy 0 / dart analyze 0 / flutter test 18

**注意**：编辑 readium_view_model.dart 时 replace 锚点漂移误删过 Bookmarks+会话跟踪段（191 行），已恢复；教训：大范围替换前先 read 拿新鲜锚点。

### 接线补齐：touch_book + 书签位置 + 读完标记（2026-08-02）✅

用户拍板做 P0/P1/P2a，P2b（死 API 清理）先讲解待确认。

- **P0 touch_book**：books.last_opened_at 全库无写入方 → 新增 `BookRepository::update_last_opened` + `touch_book` FRB API；ReadiumViewModel.open() 成功后 `unawaited(_touchBook())`（静默失败）。修复书架"最近阅读"排序选项 + service 默认排序。注意：首页"最近阅读"条实际走 reading_progress.last_read_at（上一轮已接好），books.last_opened_at 驱动书架 lastRead 排序——测试断言的是后者（list_bookshelf_books sortBy=last_opened_at）。新增集成测试。
- **P1 书签位置**：addBookmark 的 chapterIndex/charOffset 从硬编码 0 改为 `_chapterIndexForHref`/`_charOffsetFor`。
- **P2a 读完自动标状态**：进度保存时 isCompleted 首次为 true（transition + `_lastIsCompleted` 种子防重复/防已读完书重标）→ `updateBookStatus(BookStatus.completed)`。种子来自 _loadBookMetadata 的 detail.progress.isCompleted。

全绿：cargo test 105 / clippy 0 / dart analyze 0 / flutter test 18。

**P2b 待确认**：stats 4 个零调用 API（get_today_reading_stats / get_reading_stats_by_range / get_reading_stats_by_days / update_daily_stats）——讲解后由用户决定是否删。

### P2b：stats 死 API 清理完成（2026-08-02）✅

用户确认删除 4 个零调用 stats API。

- 删除：`get_today_reading_stats` / `get_reading_stats_by_range` / `get_reading_stats_by_days` / `update_daily_stats`
- 删除对应 repo 方法：`find_by_today` / `find_by_range` / `find_by_days` / `update_by_daily`（`SQL_UPSERT_READING_STATS` 保留给 aggregate_session）
- 保留：`get_global_reading_stats` + `get_reading_stats_by_days_with_fill`（唯一存活读接口）
- **update_daily_stats 删除的意义**：它是唯一"直接写 reading_stats"的入口，违反不变量（只在会话结束时由 sessions 聚合）——删除后不变量才真正成立（唯一写入路径 = create_session）
- FRB codegen 重新生成；api_stats_test.rs 重写为 3 个测试（fill 补零形状 / fill 包含会话聚合数据 / global）
- **踩坑**：聚合测试原用 `days_with_fill` 断言被并行测试遮蔽（fill 按日期折叠一天一行）→ 改为直接 sqlx 查 reading_stats 表断言，稳定 4/4
- 全绿：cargo test 102 / clippy 0 / dart analyze 0 / flutter test 18

### 排版与字体设置页补全（2026-08-02）✅

用户指出：应用设置页「排版与字体」（profile → typography_settings_page）是空的——只有实时预览卡片，零控件（注释 "font service removed"，fontId 硬编码 'system'）。

**新增/修改：**

- **ReaderConfig 新字段**：`fontWeight`（persistedDouble，300-700，默认 400，Readium 支持）+ `readingMode`（persistedEnum 分页/滚动，此前只在 VM 内是瞬态信号）
- **ReadiumViewModel**：open() 时从 config 种子 readingMode；setReadingMode 持久化到 config；_applyPreferences 的 fontWeight 从 null 改为 config.fontWeight.value（真正作用于 Readium）
- **typography_settings_page.dart 重建**：字体选择（System/Serif/Noto Serif SC，复用 FontTile）+ 字号 slider（80-200%）+ 字重 slider（300-700）+ 页边距 slider（8-40）+ 阅读模式（分页/滚动）——全部映射同一份 ReaderConfig 持久化信号，与阅读器底部面板共享
- **typography_preview.dart**：fontId 硬编码 → 真实 config（fontFamily 映射打包的 Noto Serif SC、fontWeight、fontSize、padding），预览随设置实时变化
- **l10n**：新增 fontFamily（字体）/fontWeight（字重）键 + gen-l10n 重新生成
- **测试**：新增 typography_settings_page_test（4 个：渲染全部分区 / 字体选择 / 阅读模式 / 字号 slider）；reader VM 测试补 readingMode/fontWeight stub（12 个全过）

**踩坑**：①设置页 ListView 懒加载，测试 600px 视口只渲染预览卡 → 用 tall viewport（physicalSize 1080×2800）一次性渲染所有分区；②flutter_animate 预览动画遗留定时器 → pumpAndSettle；③persistedString/fontWeight 150ms debounce 定时器 → 交互后 pump 300ms；④pi-lens 的 config.readingMode 未定义提示是旧索引假阳性（dart analyze 通过）。

**不做**：行距/字间距/段间距——flureadium 0.13.3 的 EPUBPreferences 不支持（3be5b7ec 已裁），加了就是假控件。

全绿：dart analyze 0 / flutter test 22。

### REDUNDANCY_REPORT_V2 全量清理完成（2026-08-02）✅

REDUNDANCY_REPORT_V2 的 A/B/C/D 四类清理项全部执行完毕，5 个 commit，共删 ~8,000 行 + 15 个依赖 + 60KB 资产。

- **A 死文件**（4e85e5c5）：GoReadingEmptyState / SelectionChip / AppThemeExtension（含 app_theme.dart extensions 块 + import + 注释）
- **D1 翻译链**（28f0ddd7）：DictionaryConfig/DictionaryModule/DictionaryService/2 Translator 整链删；DI 经 build_runner 重新生成（dictionary_module 带 @module）；translation.* 8 key 删
- **D2 WiFi 传书**（28f0ddd7）：service/page/html 资产 + AppRoute.wifiTransfer + DI + 菜单项删；**发现并修复**：bookshelf 菜单 'settings' 项原无 switch case（死项），_showSettingsSheet 误挂在 wifi case → 移到 settings case 恢复功能
- **C2 SettingsKeys**（28f0ddd7）：dictMddPath/currentFont/wifiTransferPort + translation.* 共 11 个死 key
- **B 依赖**（7127804a）：15 个未用依赖（runtime 10 + dev 5）；shimmer/flutter_widget_from_html/ffigen 仅注释/生成物提及，无真实 import
- **C1 l10n 死键**（dce633b5）：269 个死 key（en/zh 各 594→325），词边界脚本 + 二次人工核对；gen-l10n 重新生成
- **D3 wordlist**（168e7800）：4 个 JSON（60KB）删

**踩坑**：①route_constants 枚举最后一项删后需改 `;` 结尾；②bookshelf_page 多处 replace 误删闭合括号 → analyze 报错逐步修复；③python3 heredoc 输出乱码但操作成功（Windows 终端编码）；④appName/gridView/share 等"看似活跃"key 实为死（UI 硬编码或换用其他 key）。

**发现的结构问题（已顺带修复）**：bookshelf 'settings' 菜单项点击无效（switch 无该 case）——已把 _showSettingsSheet 从 wifi case 移到 settings case。

全绿：dart analyze 0 / flutter test 22 / cargo clippy 0 / cargo test 102。

### 修复阅读器滚动模式（2026-08-05）✅

任务 08-04-fix-scroll-mode：滚动模式被实现成"上下翻页"（每滑一次跳一章），章节内不能滚。

- **根因 A**：项目从不调 `FlutterReadium.setDefaultPreferences()` → 原生 WebView 以分页模式创建，ready 后才热切 scroll，重建与手势检测竞争
- **根因 B**：`readium_reader_content.dart` 的 Listener 手势 hack（48px + 200ms + goToLocator）抢在原生滚动前消费手势成跳章
- **修复**：open() 前 setDefaultPreferences(scroll) 预置正确模式；删除手势 hack 与 3 个边界方法；边界衔接交原生 goForwardVertical；测试与 ADR-021 更新
- **提交**：fc24fc81（含迁移分支 WIP 整体 checkpoint）
- **门禁**：dart analyze 0 / flutter test 25 全绿 / cargo clippy 0 / cargo test 99 passed
- **待真机验证**：scroll 章节内连续滚动、滚到章尾原生是否自动衔接（若不自动需轻量边界信号兜底，design.md 有预案）
