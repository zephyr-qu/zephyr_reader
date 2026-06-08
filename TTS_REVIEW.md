# TTS 实现审查报告

> 审查日期：2026-06-08
> 范围：`lib/core/reader/tts_service.dart` + `lib/features/profile/` TTS 设置 + `lib/features/reader/` 阅读器 TTS

---

## 架构总览

```
lib/
├── core/reader/tts_service.dart          ← TTS 引擎封装 (FlutterTts + signals)
├── features/
│   ├── profile/
│   │   ├── application/tts_settings_view_model.dart  ← 持久化设置信号 (9 items)
│   │   └── page/tts/
│   │       ├── tts_settings_page.dart       ← 设置页主页面
│   │       ├── playback_section.dart        ← 语速/音调/句间停顿
│   │       ├── bilingual_section.dart       ← 双语交替/原文优先/切换间隔
│   │       ├── behavior_section.dart        ← 后台播放/自动翻页/高亮跟随/息屏变暗
│   │       ├── tts_preview_card.dart        ← 试听卡片
│   │       └── select_item_tile.dart        ← 语音/引擎选择器条目
│   └── reader/
│       ├── page/reader_page.dart            ← _toggleTts → speak(c) / stop()
│       └── page/widgets/reader_bottom_toolbar.dart  ← TTS 按钮 + 状态色
├── core/theme/reader_theme_extension.dart  ← ttsActiveColor 主题色
├── di/service_locator.config.dart          ← TtsService + TtsSettingsViewModel 注册
├── l10n/app_*.arb                          ← 20+ TTS 专有 l10n key
└── core/settings/settings_keys.dart        ← 10 个 tts_* 设置 key
```

**依赖**：`flutter_tts: ^4.2.5`

---

## ✅ 做对了的部分

### 1. 设置 UI 完整

9 个设置项每个都有独立的 UI+Sections，全部通过 `persistedSignal` 自动持久化到 SharedPreferences：

| 设置 | 类型 | UI 位置 |
|------|------|---------|
| 语速 (0.5–2.0x) | double | PlaybackSection slider |
| 音调 (0.5–2.0) | double | PlaybackSection slider |
| 句间停顿 (0–1000ms) | int | PlaybackSection slider |
| 双语交替朗读 | bool | BilingualSection toggle |
| 仅朗读原文 | bool | BilingualSection toggle |
| 中英切换间隔 | int | BilingualSection slider |
| 后台播放 | bool | BehaviorSection toggle |
| 自动翻页 | bool | BehaviorSection toggle |
| 高亮跟随 | bool | BehaviorSection toggle |
| 息屏降低音量 | bool | BehaviorSection toggle |

### 2. DI 与服务生命周期

- `TtsService` — `@lazySingleton`，全应用共享实例
- `TtsSettingsViewModel` — `@injectable` 工厂，每次页面重建新实例

### 3. 初始化解耦

`Completer<void> _ready` 确保所有 `speak/pause/resume/stop` 在 `_tts` 完成初始化前 await，不会在 init 完成前发出命令。

### 4. 错误处理

`setCompletionHandler` + `setErrorHandler` 都会正确复位 `isPlaying.value = false`、`isPaused.value = false`，防止状态信号泄漏。

### 5. 主题集成

`ReaderThemeExtension.ttsActiveColor` 在亮色/深色/护眼色三套主题中均有定义，底部工具栏 TTS 按钮激活时会渲染此色。

---

## ❌ 发现的问题

### P0 — 功能性 Bug

#### 1. `resume()` 方法调用错误

**文件**：`lib/core/reader/tts_service.dart:62`

```dart
Future<void> resume() async {
  await _ready.future;
  if (isPlaying.value && isPaused.value) {
    await _tts.speak('');   // ← BUG：空字符串不会恢复播放
    isPaused.value = false;
  }
}
```

`flutter_tts` 4.x 提供 `_tts.resume()` 方法。`speak('')` 会立即完成（"朗读"了一个空字符串），然后触发 `setCompletionHandler` 把 `isPlaying` 也设为 `false`。调用 `resume()` 后实际结果是**完全停止**而非恢复。

**修复**：改为 `await _tts.resume();`

#### 2. 阅读器 TTS 只能全量朗读/停止，无暂停恢复

**文件**：`lib/features/reader/page/reader_page.dart:543-551`

```dart
void _toggleTts(ReaderViewModel vm, TtsService ttsService) {
  final c = vm.chapterContent.value.value;
  if (c == null || c.isEmpty) return;
  if (ttsService.isPlaying.value) {
    ttsService.stop();       // ← 点一下直接停止
  } else {
    ttsService.speak(c);     // ← 再点从开头重读
  }
}
```

- **无暂停**：读者栏的 TTS 按钮只有 speak/stop 两种状态，`pause()` 和 `resume()` 方法从来不被调用。
- **每次重读从头**：`speak()` 内部先调 `stop()`，再调 `_tts.speak(text)`，所以每次 toggle 都从章节开头朗读，不记住上次位置。
- **大章节无分段**：整个章节文本一次性传入 `flutter_tts`，对于 TXT 长章节（50K+ 字符）可能导致 TTS 引擎 OOM 或卡死。

---

### P1 — 功能缺失 / 虚假配置

#### 3. 双语设置项是死配置

**文件**：`lib/features/profile/application/tts_settings_view_model.dart:34-52`

`bilingualAlternate`、`originalOnly`、`switchInterval` 三个设置被持久化、有完整 UI（含"Zephyr 专属"徽章），但**没有任何代码读取这些设置**——`TtsService` 不提供 bilingual 相关方法，`ReaderPage._toggleTts` 也不检查这些值。用户在设置页切换了双语模式，实际朗读时完全没效果。

#### 4. `backgroundPlay` 无实际实现

`BehaviorSection` 有后台播放开关，但 `TtsService` 没有配置 `AudioSession` 的类别（如 Android 的 `AudioManager.STREAM_MUSIC` 或 iOS 的后台音频模式）。插件默认前台工作，App 切到后台后朗读可能被系统中断。

#### 5. `autoPage` 和 `highlightFollow` 无实际实现

类似的——设置持久化、UI 齐全，但 `TtsService` 不触发翻页操作，`ReaderPage` 也没有监听 TTS 进度来滚动到当前朗读位置。

#### 6. 语音选择器标签硬编码

**文件**：`lib/features/profile/page/tts/tts_settings_page.dart:186,193`

```dart
value: 'Google US English',   // ← Android/iOS 不一定有这个引擎
value: '讯飞小燕',             // ← 仅部分 Android 设备默认
```

这些是静态字符串，不通过 `getVoices()` 获取的引擎名称动态显示。用户在 iOS 上看到 "Google US English" 可能根本不可用。

---

### P2 — 代码质量

#### 7. 无测试覆盖

| 组件 | 单元测试 | Widget 测试 |
|------|---------|------------|
| `TtsService` | ❌ | ❌ |
| `TtsSettingsViewModel` | ❌ | ❌ |
| TTS 设置页 | ❌ | ❌ |
| 阅读器 TTS 交互 | ❌ | ❌ |

#### 8. SettingsPage `useEffect` 竞态

**文件**：`lib/features/profile/page/tts/tts_settings_page.dart:36-41`

```dart
useEffect(() {
  unawaited(tts.setSpeed(vm.speed.value));   // ← fire-and-forget
  unawaited(tts.setPitch(vm.pitch.value));
  tts.setPauseBetween(vm.pauseBetween.value);
  return null;
}, []);
```

如果页面在 async 完成前被 dispose（快速导航），`TtsService` 仍会收到这些设置调用。虽然 `_ready` guard 防止了 `_tts` 未初始化的问题，但语义上已经不属于该页面的操作了。

#### 9. `speak()` 重复停止

```dart
Future<void> speak(String text) async {
  await _ready.future;
  await stop();       // ← 先 stop
  isPlaying.value = true;
  await _tts.speak(text);
}
```

`speak()` 总是先调用 `stop()`。如果是同一段文本的"重新朗读"场景合理，但对于"切换章节后继续朗读"的场景，应该支持无缝过渡而非先停止再开始。

#### 10. `_normalizedRate` 计算可能不准

```dart
double get _normalizedRate => (currentSpeed.value - 0.5) / 1.5;
```

`flutter_tts` 的 `setSpeechRate` 在各平台上接受的范围不同（Android 0.0–1.0 映射到系统语速，iOS/Web 可能预期不同）。当前计算把用户设置的 0.5–2.0 线性映射到 0.0–1.0，但引擎的实际效果未经测试验证。

---

## 修复建议

| 优先级 | 问题 | 修复方案 | 工作量 |
|--------|------|---------|--------|
| **P0** | `resume()` 用 `speak('')` | 改为 `_tts.resume()` | 1 行 |
| **P0** | 阅读器 TTS 无暂停 | `_toggleTts` 增加 pause/resume 分支 | 小 |
| **P0** | 大章节不分段 | 将章节文本按句子分割后逐个 `speak`，句间用 pauseBetween 停顿 | 中 |
| **P1** | 双语设置死配置 | 移除 bilingual 设置 UI 或实现实际的交替朗读逻辑 | 中 |
 | **P1** | 语音选择器标签硬编码 | 动态从 `getVoices()` 结果获取当前活跃语音名 | 小 |
 | **P2** | 测试不完整 | 已有 `test/core/reader/tts_service_test.dart`（3 group, 12 tests），但 `resume` 方法零测试、mock 不验证引擎调用、双语 VM/阅读器交互零覆盖 | 小 |

---

## 总结

TTS 的**设置 UI 和持久化层完成度高**（9 项设置、完整的 i18n、主题集成），但**核心的控制逻辑和阅读器集成存在断裂**：

- `resume()` 方法因 API 调用错误实际不可用
- 阅读器只有 speak/stop 两种状态，无暂停/恢复/位置记忆
- 双语、后台播放、自动翻页、高亮跟随四个设置项是 **"假实现"**（有 UI 无逻辑）
- 语音选择器标签硬编码平台依赖值

整体上 TTS 可以工作（能朗读、能调速），但处于 **"可用的骨架"** 阶段，对标多看/微信读书的 TTS（支持暂停/恢复、句子级高亮跟随、后台播放、双语交替）需要上述 P0+P1 的修复才能达到。
