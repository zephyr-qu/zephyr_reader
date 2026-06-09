# TTS 待修复问题（截至 2026-06-09）

审查自 [TTS_REVIEW.md](./TTS_REVIEW.md)，P0 三问题已修复，以下为仍存在的问题。

## P1 — 功能缺失

### 1. 双语设置死配置

**涉及文件**：
- `lib/features/profile/application/tts_settings_view_model.dart` — `bilingualAlternate`、`originalOnly`、`switchInterval` 三个 persistedSignal
- `lib/features/profile/page/tts/bilingual_section.dart` — BilingualSection widget（**未导入 tts_settings_page**，死代码）
- `lib/core/reader/tts_service.dart` — 无任何双语交替/仅原文逻辑

**现状**：三个设置持久化 + UI 完备，但：
  - `BilingualSection` 不在 `tts_settings_page` 中渲染
  - `TtsService.speakSentences` 不检查这些值
  - 朗读时完全无交替效果

### 2. `backgroundPlay` 无实际实现

**涉及文件**：
- `lib/core/reader/tts_service.dart` — 无 `AudioSession` 配置
- `lib/features/profile/page/tts/behavior_section.dart` — BehaviorSection widget（**未导入 tts_settings_page**，死代码）

**现状**：`flutter_tts` 默认前台工作，App 切后台可能被系统中断朗读。

### 3. `autoPage`/`highlightFollow` 无实际实现

**涉及文件**：
- `lib/features/profile/application/tts_settings_view_model.dart` — `autoPage`、`highlightFollow` persistedSignal
- `lib/features/reader/page/reader_page.dart` — `_toggleTts`/`_startTts` 不消费这两个设置
- `lib/core/reader/tts_service.dart` — `currentSentenceIndex` 和 `currentText` 信号无消费者

**现状**：设置持久化 + UI 齐全，但阅读器在 TTS 朗读时不翻页、不高亮跟随朗读位置。

---

## P2 — 代码质量

### 4. SettingsPage `useEffect` 竞态

**文件**：`lib/features/profile/page/tts/tts_settings_page.dart:34-39`

```dart
useEffect(() {
  unawaited(tts.setSpeed(vm.speed.value));
  unawaited(tts.setPitch(vm.pitch.value));
  tts.setPauseBetween(vm.pauseBetween.value);
  return null;
}, []);
```

**风险**：页面 dispose 后设置仍可能下发。`_ready` guard 防止了 NPE，但语义上已不属于该页面操作。

### 5. `_normalizedRate` 平台兼容性未验证

**文件**：`lib/core/reader/tts_service.dart:202`

```dart
double get _normalizedRate => (currentSpeed.value - 0.5) / 1.5;
```

用户 0.5–2.0 线性映射到 0.0–1.0，但 `flutter_tts.setSpeechRate` 在不同平台（Android/iOS/Web）的行为未测试验证。

---

## 死代码

| 文件 | 说明 |
|------|------|
| `lib/features/profile/page/tts/bilingual_section.dart` | 未导入 `tts_settings_page.dart` |
| `lib/features/profile/page/tts/behavior_section.dart` | 同上 |

---

## 测试覆盖缺口

| 组件 | 单元测试 | Widget 测试 |
|------|---------|------------|
| TTS 设置页交互 | ❌ | ❌ |
| 阅读器 TTS 三态切换（pause/resume） | ❌ | ❌ |
| 句子队列自动推进 | ❌（mock 不触发 completionHandler） | ❌ |
