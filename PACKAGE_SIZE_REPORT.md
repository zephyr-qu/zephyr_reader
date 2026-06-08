# 包体积分析报告

> 分析时间：2026-06-08

## 1. 资产资源 (直接打进 APK/IPA)

| 资源 | 大小 | 体积占比 | 压缩建议 |
|------|------|---------|---------|
| `assets/fonts/NotoSerifSC-Regular.ttf` | **24.0 MB** | ~40% | 改用子集字体（仅包含用到的字符） |
| `assets/fonts/LXGWWenKai-Regular.ttf` | **15.0 MB** | ~25% | 同上；或只保留一种字体 |
| `assets/dictionary.mdx` | **9.9 MB** | ~17% | 考虑首次运行时按需下载 |
| `assets/wordlists/*.json` (4 个) | ~68 KB | <1% | 可忽略 |
| `assets/html/wifi_upload_page.html` | 4 KB | <1% | 可忽略 |
| **assets 合计** | **~49 MB** | | |

**影响结论：** 两个中文字体 + 字典文件合计约 **49MB**，占 APK 非代码部分的绝大部分。

### 优化方向

| 方案 | 减负 | 代价 |
|------|------|------|
| 字体子集化（只保留用到的常用汉字子集） | -20~35 MB | 需工具链（pyftsubset），中文变化不大时安全 |
| 仅保留一种字体 | -15 MB | 用户选择减少 |
| 字典按需下载 | -10 MB | 需要网络 + 离线不可用 |

---

## 2. Rust 原生库 (Native .so)

### 构建产物尺寸（debug 构建的 `.so`，未 strip）

| ABI | debug .so | debug .a | release stripped |
|-----|-----------|----------|-----------------|
| **arm64-v8a** | 343 MB | 843 MB | **~37 MB** |
| **armeabi-v7a** | 308 MB | 663 MB | **~20 MB** |
| x86 (debug only) | 326 MB | 655 MB | ~40 MB |
| x86_64 (debug only) | 345 MB | 847 MB | ~40 MB |

> Release 构建通过 `stripDebugDebugSymbols` 将 arm64-v8a 的 343 MB → **40 MB**（减负 88%）。

### 上游依赖贡献（按 ABI 分摊估算）

| 依赖 | debug .a 尺寸 | release so 贡献 | 说明 |
|------|--------------|-----------------|------|
| **pdfium_render** | ~35 MB (arm64) | ~10-15 MB | PDF 渲染引擎，最重的依赖 |
| **libsqlite3-sys** | ~5 MB | ~1-2 MB | SQLite 内嵌 |
| **zstd-sys** | ~3-6 MB | ~1-2 MB | 压缩库 |
| **onig_sys** | ~2 MB | ~0.5 MB | 正则库 |
| **ring** | ~1 MB | ~0.3 MB | 加密库 |
| 用户代码 + FRB | — | ~20 MB | 实际业务逻辑 |

**release 合计（2 个 ABI）： arm64-v8a ~37 MB + armeabi-v7a ~20 MB = ~57 MB**

### 更多优化

| 方案 | 减负 | 风险 |
|------|------|------|
| 加 LTO + `opt-level = "z"` in release profile | -20% so 尺寸 | 构建时间增加 |
| 仅打包 arm64-v8a（放弃 armeabi-v7a） | -20 MB | 老旧 32 位设备不可用 |
| 使用 Android App Bundle（split APK by ABI） | 用户只下载对应 ABI | 需切换到 AAB 分发 |

---

## 3. Flutter 依赖包（代码与资源）

### 图标字体（随 APK 打包）

| 包 | 包含字体 | 合计 |
|----|---------|------|
| `phosphoricons_flutter` | 6 个变体（Bold/Fill/Light/Thin/Duotone/Regular × ~0.5 MB） | **~3 MB** |
| `line_icons` | 1 个 TTF ~370 KB | **~370 KB** |

**影响：** 6 种 Phosphor 变体用得不多可以只留 2-3 个（Bold + Regular + Fill）。

### 代码体积（Dart → DEX）

| 包 | 估算 DEX 贡献 |
|----|--------------|
| `fl_chart` | ~200 KB |
| `flutter_svg` | ~100 KB |
| `flutter_animate` | ~100 KB |
| `flutter_tts` | ~50 KB + 平台原生库 |
| `webdav_client` | ~100 KB |
| **生成代码** `app_localizations*.dart` | ~180 KB |

---

## 4. Android 构建配置问题

| 问题 | 状态 | 影响 |
|------|------|------|
| **Release 使用 debug signing** | ❌ | 无法发布到 Play Store |
| **无 ProGuard/R8 混淆** | ❌ | DEX 未压缩，可缩小 ~20-30% |
| **无 split APK / AAB** | ❌ | 用户下载全部 ABI 而非仅自己的 |
| Debug 构建 4 个 ABI 全部打包 | ❗合理 | debug 不需要优化 |
| Release 仅 arm64-v8a + armeabi-v7a | ✅ 正确 | |

---

## 5. 汇总：Release APK 体积估算

| 类别 | 大小 |
|------|------|
| Rust .so（arm64-v8a，strip 后） | ~37 MB |
| Rust .so（armeabi-v7a，strip 后） | ~20 MB |
| 字体 NotoSerifSC | 24 MB |
| 字体 LXGWWenKai | 15 MB |
| dictionary.mdx | 10 MB |
| icon fonts（phosphoricons + line_icons） | ~3.4 MB |
| Flutter DEX + framework | ~15 MB |
| **合计（未优化）** | **~124 MB** |
| **合计（单字体 + AAB）** | **~85 MB** |

> 注：如果使用 App Bundle（AAB），用户只下载自己 ABI 对应的 so + 资源，arm64-v8a 单包约 **87 MB**（双字体）或 **50 MB**（单字体+字典按需下载）。

---

## 6. 优先级建议

| 优先级 | 行动 | 预估减负 |
|--------|------|---------|
| P0 | 字体子集化（去掉罕见汉字，仅保留 CJK 常用字 ~6,700 字 → ~5 MB/套） | -25~35 MB |
| P0 | 启用 ProGuard/R8 `minifyEnabled=true` | -3~5 MB DEX |
| P1 | 字典改为首次按需下载 | -10 MB |
| P1 | 图标字体只保留 2-3 个 Phosphor 变体 | -1.5~2 MB |
| P2 | Cargo profile LTO + `opt-level = "z"` | -5~10 MB .so |
| P2 | Android App Bundle 替代 APK | 用户侧减半 |
| P3 | 放弃 armeabi-v7a 只打 arm64 | -20 MB |
