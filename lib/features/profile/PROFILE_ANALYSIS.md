# Profile Feature 深度分析报告

> 分析基准：`lib/features/profile/`
> 文件数：12（3 ViewModel + 9 Page）
> 检测日期：2026-06-03

---

## 1. 架构总览

```
profile/
├── application/
│   └── profile_view_model.dart               ← 个人页 VM（~35 行）
├── page/
│   ├── profile_page.dart                     ← 个人主页（~415 行）
│   ├── about_page.dart                       ← 关于页（~370 行）
│   ├── typography_settings_page.dart         ← 排版字体设置（~560 行）
│   ├── tts_settings_page.dart                ← TTS 朗读设置（~530 行）
│   ├── user_agreement_page.dart              ← 用户协议（~155 行）
│   ├── privacy_policy_page.dart              ← 隐私政策（~160 行）
│   ├── theme_brightness/
│   │   ├── theme_brightness_view_model.dart  ← 主题 VM（~63 行）
│   │   └── theme_brightness_page.dart        ← 主题/亮度设置（~525 行）
│   └── other_settings/
│       ├── other_settings_view_model.dart    ← 其他设置 VM（~66 行）
│       └── other_settings_page.dart          ← 其他设置页（~592 行）
```

**DI 注册**：
- `ProfileViewModel` → `@LazySingleton` ✅
- `ThemeBrightnessViewModel` → `factory`（每次 getIt 新实例）
- `OtherSettingsViewModel` → `factory`

---

## 2. P0 级问题

### 2.1 `ProfileViewModel.loadStats()` — 已加载数据后永远跳过刷新

```dart
Future<void> loadStats() async {
  if (globalStats.value is AsyncData || vocabStats.value is AsyncData) return;
  await _doLoadStats();
}
```

一旦一次加载成功，`AsyncData` 状态**永久阻止后续 `loadStats()` 调用**。Pull-to-refresh、从其他页面返回、或者用户手动刷新都**不会重新加载**。Stats 数据仅在页面首次创建时加载一次，之后永久缓存。这在 webDAV 同步或其他后台变更后会产生过时数据。

### 2.2 排版/字体设置和 TTS 设置全部使用 `useState` 而非 Signal

`typography_settings_page.dart` 和 `tts_settings_page.dart` 完全使用 `ValueNotifier` + `useState` 管理状态，而非项目统一的 Signal 模式。

```dart
final fontSize = useState(18.0);
final lineHeight = useState(1.6);   // 共 9 个 useState
```

这与项目其他模块的 `@injectable` + Signal 模式割裂。这些设置也未持久化到 `ReaderConfig`（排版）或 `SharedPreferences`（TTS）——仅在内存中修改，**退出页面后更改丢失**。

### 2.3 排版恢复默认功能会重置已持久化的 ReaderConfig

```dart
// typography_settings_page.dart:167-169
await config.resetToDefault();
await fontRepo.setCurrentFont('system');
```

`resetToDefault()` 清空了 `ReaderConfig` 中所有已持久化的排版设置。但如果用户在退出前没有「恢复默认」，则在 UI 中修改的值不会持久化。

### 2.4 TTS 语音引擎选型 — `_selectItem` 全部空函数

```dart
_selectItem(cs, 'TTS 引擎', '系统默认', () {}),
_selectItem(cs, '英文语音', 'Google US English', () {}),
_selectItem(cs, '中文语音', '讯飞小燕', () {}),
```

三个 `onTap` 全部是 `() {}`，用户点击无任何响应。这是假实现。

### 2.5 用户协议和隐私政策页面 — 100% 硬编码中文法律文本

两个页面共约 50 段法律条文全部硬编码中文。由于法律文本的特殊性（需要法务审核），仅存在于 Dart 源码中意味着：
- 无法在不发版的情况下修改
- 无英文版本
- 文本若有法律风险，不能热修复

---

## 3. 国际化（i18n）问题

Profile 模块**两极分化**：

### 3.1 使用 l10n 的文件 ✅

| 文件 | 状态 |
|------|------|
| `profile_page.dart` | 全部使用 `l10n.xxx` ✅ |
| `about_page.dart` | 几乎全部使用 `l10n.xxx` ✅ |

### 3.2 硬编码严重的文件

`typography_settings_page.dart`：
```dart
title: '排版与字体',
title: '实时预览',
title: '字体选择',
title: '排版参数',
title: '高级排版',
subtitle: 'CJK 优化',
title: '标点挤压',
...
'恢复默认设置'
```
约 15 处硬编码中文。全部使用 `useState` 而非 Signal，状态管理方式也与 l10n 割裂（Consumer Widget 无法感知 locale 切换）。

`tts_settings_page.dart`：
```dart
title: '朗读设置',
'停止试听', '试听当前配置', '修改后自动刷新',
'TTS 引擎', '英文语音', '中文语音',
'语速', '音调', '句间停顿',
'双语朗读', '仅朗读原文', '中英切换间隔',
'后台播放', '自动翻页', '高亮跟随', '息屏时降低音量'
```
约 25 处硬编码中文。

`other_settings_page.dart`：约 20 处硬编码中文（`'其他设置'`, `'应用行为'`, `'界面语言'`, `'通知与提醒'`, `'实验性功能'`, `'危险操作'`, 所有弹窗标题和按钮等）。

`user_agreement_page.dart`、`privacy_policy_page.dart`：全部法律文本硬编码中文。

`theme_brightness_page.dart`：使用 l10n ✅

---

## 4. ViewModel 设计缺陷

### 4.1 `ProfileViewModel` — `AsyncState` 阻止刷新（见 §2.1）

### 4.2 `ThemeBrightnessViewModel._initialized` 防重复

```dart
bool _initialized = false;
Future<void> initialize() async {
  if (_initialized) return;
  _initialized = true;
  ...
}
```

仅赋值一次，但无 dispose 机制重置。如果页面被销毁后重建，VM 却是 `factory` 新实例，所以 `_initialized` 是新的 false → 重新初始化。这实际上是正确的行为。但 `factory` 意味着每次页面 push 都创建新 VM，丢失上次状态。

### 4.3 `OtherSettingsViewModel` — `resetAllSettings` 未重置界面语言

```dart
Future<void> resetAllSettings() async {
  await getIt<ReaderConfig>().resetToDefault();
  notificationsEnabled.value = true;
  startupCheckEnabled.value = true;
  markdownPreview.value = false;
}
```

语言设置（`localeCode` / `localeLabel`）、主题设置未被重置。语义上「重置所有设置」未覆盖全部设置项。

### 4.4 `ViewModel.dispose()` 缺失

三个 ViewModel 均无 `dispose()` 方法。虽然 `@LazySingleton` 和 `factory` 各有相应的生命周期管理。

---

## 5. UI/UX 问题

### 5.1 排版预览和 TTS 预览使用 `state` 而非 Signal 驱动

所有滑块/Toggle 修改影响预览：`typography_settings_page` 中用 `AnimatedContainer`（✅ 平滑过渡），但状态变更后只会由 `useState` 触发 build 重建，不会降低性能但不够「Signal 原生」。

### 5.2 TTS 预览卡片固定深色渐变

```dart
gradient: const LinearGradient(
  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
```

固定深蓝色渐变。暗色模式下不可见问题不大（本身就是深色），但如果用户使用 AMOLED 主题，渐变边界可能产生色带。

### 5.3 排版字体选择用 `GestureDetector` 无 ripple

`typography_settings_page.dart:297` — 字体网格中的每个选项使用 `GestureDetector`。

### 5.4 `_buildVersionFooter` 中「检查更新」和「反馈问题」是空函数

```dart
GestureDetector(onTap: () {}, child: Text('检查更新')),
GestureDetector(onTap: () {}, child: Text('反馈问题')),
```

点击无反应。两个假实现入口。

### 5.5 语言选择 BottomSheet 不刷新 UI

```dart
tm.locale.value = code;    // 切换语言
Navigator.pop(context);     // 关闭 sheet
```

语言切换后需要 `OtherSettingsPage` 重建以应用新 locale，但当前页面不会自动刷新（没有 `useEffect` 监听 `tm.locale`）。用户需要手动返回再进入。

### 5.6 暗色模式下 badge 样式

`typography_settings_page` 中 `CJK 优化` badge：
```dart
const Color(0xFFFFF3E0),  // Badge 背景
const Color(0xFFEF6C00),  // Badge 文字
```
暗色模式下浅橙色背景发亮。同样出现在 `tts_settings_page:321` 的 `Zephyr 专属` badge。

### 5.7 用户协议和隐私政策使用硬编码版本

```dart
'最后更新：2026 年 3 月 31 日'
```

在 Dart 源码中硬编码。如果协议更新（即使只改日期），需要发版。

---

## 6. 代码层统一建议

### 6.1 `_buildSection` 在用户协议和隐私政策页面完全相同

```dart
// user_agreement_page.dart:124-153
// privacy_policy_page.dart:128-157
完全相同的 _buildSection 方法，复制粘贴。
```

应提取为共享 widget。

### 6.2 三个页面使用相同的 `useState` 模式而非 Signal

`typography_settings_page`、`tts_settings_page`、`other_settings_page` 都使用 `useState` 管理界面状态。与其他模块的 Signal 模式不一致。

### 6.3 多页面使用相同 AppBar 标题样式

```dart
title: Text('排版与字体', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, ...))
title: Text('朗读设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, ...))
title: Text('其他设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, ...))
```

标题样式在 3 个页面重复定义。应提取为共享的 `pageTitleStyle` 或 `SettingsPageAppBar`。

### 6.4 法律页面共用 ListView + Card 结构

`user_agreement_page` 和 `privacy_policy_page` 结构完全相同，只有内容数据不同。可抽象为 `LegalPage(content: List<LegalSection>)`。

---

## 7. 假实现 / stub 分析

| 类型 | 位置 | 说明 |
|------|------|------|
| **TTS 引擎选择** | `tts_settings_page.dart:226-228` | 三个 `_selectItem(..., () {})` — 点击无响应 |
| **检查更新** | `other_settings_page.dart:405-414` | `GestureDetector(onTap: () {}, ...)` |
| **反馈问题** | `other_settings_page.dart:423-433` | `GestureDetector(onTap: () {}, ...)` |
| **Profile stats 静态化** | `ProfileViewModel.loadStats()` | 加载一次后 `AsyncData` 阻止所有后续刷新 |
| **排版设置非持久化** | `typography_settings_page` | 所有用 `useState` 的排版参数修改后不持久化到 `ReaderConfig`，退出页面丢失 |
| **TTS 设置不持久** | `tts_settings_page` | `useState` 修改的参数仅在页面生命周期内存活，不会通过 SharedPreferences 回写 |

---

## 8. 潜在问题

### 8.1 用户协议 — 存储权限声明

```dart
'  • 存储权限：用于读取和保存小说文件'
```

在 Android 11+ 中存储权限已经细分（MediaStore / MANAGE_EXTERNAL_STORAGE），此声明可能不准确。

### 8.2 隐私政策 — 数据路径固定

```dart
'存储位置：/storage/emulated/0/Documents/ZephyrReader/'
```

Android 10+ 不能直接写公共目录。实际路径应通过 `getExternalStorageDirectory()` 获取，不同设备/SDK 不同。

### 8.3 版本号硬编码

```dart
'Flutter 3.41.2 · Rust 1.82.0 · FRB 2.12.0'
```

在 `_buildVersionFooter` 中硬编码。每升级 Flutter/Rust SDK 都需要手动修改。

### 8.4 `AboutPage` 使用 `useFuture` 加载 `PackageInfo`

```dart
final packageInfo = useFuture(
  useMemoized(() => PackageInfo.fromPlatform()),
);
```

`useFuture` 在 widget rebuild 时不会重新执行（`useMemoized` 保证了 Future 只创建一次）。但如果 Future 失败，UI 永远显示 `l10n.unknownVersion`，无重试机制。

### 8.5 `tz.` license 页可能非常大

`showLicensePage` 会显示所有 Flutter 包的 License。如果项目依赖多，列表可能非常长，在小屏设备上 UX 差。

### 8.6 TTS 设置 `SharedPreferences` key 与 `persistedSignal` 体系不统一

TTS 设置使用硬编码字符串 Key（`'tts_speed'`, `'tts_pitch'` 等），而项目其他设置使用 `SettingsKeys` 常量定义。不一致。

---

## 9. 测试覆盖分析

| 组件 | 单元测试 | Widget 测试 | 错误态测试 |
|------|---------|-------------|-----------|
| `ProfileViewModel` | ✅ `test/features/profile/application/profile_view_model_test.dart` | N/A | ❌ |
| `ThemeBrightnessViewModel` | ❌ | N/A | ❌ |
| `OtherSettingsViewModel` | ❌ | N/A | ❌ |
| `ProfilePage` | N/A | ❌ | ❌ |
| `AboutPage` | N/A | ❌ | ❌ |
| `ThemeBrightnessPage` | N/A | ❌ | ❌ |
| `OtherSettingsPage` | N/A | ❌ | ❌ |
| `TypographySettingsPage` | N/A | ❌ | ❌ |
| `TtsSettingsPage` | N/A | ❌ | ❌ |
| `UserAgreementPage` | N/A | ❌ | ❌ |
| `PrivacyPolicyPage` | N/A | ❌ | ❌ |

---

## 10. 优化清单

| 优先级 | 类别 | 项目 |
|--------|------|------|
| **P0** | Bug | `ProfileViewModel.loadStats()` AsyncData 永远阻止后续刷新 |
| **P0** | Bug | 排版/字体设置使用 useState → 修改后退出页面丢失 |
| **P0** | Bug | TTS 语音引擎 `_selectItem(..., () {})` 三个空壳 |
| **P0** | 假实现 | `_buildVersionFooter` 中「检查更新」「反馈问题」空函数 |
| **P1** | 持久化 | 排版参数更改后同步写入 `ReaderConfig` |
| **P1** | 持久化 | TTS 参数更改后同步写入 SharedPreferences（当前只读不写） |
| **P1** | 持久化 | TTS SharedPreferences key 迁移到 `SettingsKeys` |
| **P1** | i18n | `typography_settings_page.dart` 全部硬编码迁移至 l10n |
| **P1** | i18n | `tts_settings_page.dart` 全部硬编码迁移至 l10n |
| **P1** | i18n | `other_settings_page.dart` 全部硬编码迁移至 l10n |
| **P1** | i18n | `user_agreement_page.dart` + `privacy_policy_page.dart` 支持 locale 切换 |
| **P1** | 代码 | `_buildSection` 在法律页提取共享 widget |
| **P1** | 代码 | 版本信息字符串提取到动态源而非硬编码 |
| **P1** | 代码 | 存储路径声明从硬编码改为动态获取 |
| **P1** | 测试 | 添加 `ThemeBrightnessViewModel` 单元测试 |
| **P1** | 测试 | 添加 `OtherSettingsViewModel` 单元测试 |
| **P1** | 测试 | Widget 渲染快照测试 |
| **P2** | UI | 语言切换后自动刷新当前页面 |
| **P2** | UI | `CJK 优化` / `Zephyr 专属` badge 暗色模式适配 |
| **P2** | UI | 排版字体网格 `GestureDetector` → `InkWell` |
| **P2** | UI | AppBar 标题样式提取共享组件 |
| **P2** | UX | 法律页面支持外部法律文本 asset |
| **P2** | UX | `AboutPage` PackageInfo 加载失败重试 |
| **P2** | Architecture | TTS/排版设置页面迁移到 Signal + VM 模式 |
| **P2** | Architecture | `ThemeBrightnessViewModel` 生命周期管理（factory → 其他） |
