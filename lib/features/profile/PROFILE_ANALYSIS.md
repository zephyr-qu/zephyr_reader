# Profile Feature 深度分析报告（未修复清单）

> 分析基准：`lib/features/profile/`
> 文件数：13（4 ViewModel + 9 Page）
> 检测日期：2026-06-06
> 说明：本文档仅列出 **仍存在** 的问题。已修复项从原文档移除，不再保留。

## 架构总览

```
lib/features/profile/
├── application/
│   ├── profile_view_model.dart         — loadStats + AsyncState
│   ├── tts_settings_view_model.dart    — TTS 设置 (persistedSignal)
│   └── other_settings.dart             — 其他设置
└── page/
    ├── profile_page.dart
    ├── typography_settings_page.dart
    ├── tts_settings_page.dart
    └── other_settings/
        ├── other_settings_page.dart
        └── other_settings_view_model.dart
```

<br />

## ❌ 未修复问题

### 1. 用户协议和隐私政策页面 — 100% 硬编码中文法律文本

**位置**: `user_agreement_page.dart`、`privacy_policy_page.dart`

共约 50 段法律条文全部硬编码中文。无法在不发版的情况下修改，无英文版本。

### 2. 「检查更新」「反馈问题」是空函数

**位置**: `other_settings_page.dart:409-440`

两个 `GestureDetector(onTap: () {}, ...)`，点击无反应。

### 3. 法律页面硬编码「最后更新」日期

`'最后更新：2026 年 3 月 31 日'` 在 Dart 源码中硬编码。

### 4. 法律页面共用结构未抽象

用户协议和隐私政策结构完全相同，只有内容数据不同。可抽象为 `LegalPage(content: List<LegalSection>)`。

### 5. 版本号硬编码

**位置**: `other_settings_page.dart:399`

`'Flutter 3.41.2 · Rust 1.82.0 · FRB 2.12.0'`，每升级 SDK 需手动修改。

### 6. `AboutPage` 使用 `useFuture` 加载 `PackageInfo`，无重试

`useFuture(useMemoized(() => PackageInfo.fromPlatform()))` — Future 失败后永远显示 unknown。

### 7. License 页可能非常大

`showLicensePage` 在小屏设备上 UX 差。

### 8. 测试覆盖严重不足

- `ProfileViewModel` — 单元测试 ✅, Widget 测试 ❌
- `OtherSettingsViewModel` — 单元测试 ❌, Widget 测试 ❌
- `TtsSettingsViewModel` — 单元测试 ❌, Widget 测试 ❌
- 4 个页面 — 单元测试 ❌, Widget 测试 ❌

仅 `ProfileViewModel` 有单元测试。

