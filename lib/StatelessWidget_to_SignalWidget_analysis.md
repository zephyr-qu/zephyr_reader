# StatelessWidget → SignalWidget 适配分析

> **结论：无需替换。** 全库 80+ 个 StatelessWidget，无一在 `build()` 中读取 `.value`。

## 扫描总结

所有 StatelessWidget 遵循同一模式：

```
HookWidget（页面层）
  ├─ useSignalValue() 订阅信号 → 得到普通 Dart 值
  ├─ 调用 ViewModel 方法触发变更
  └─ 将普通值/回调传给子 StatelessWidget
```

**无需引入 `SignalWidget`**——组件层不感知信号存在，职责单一。

## 详细情况

| Widget | ViewModel 参数 | build() 中读 `.value`? |
|---|---|---|
| `SearchHistoryView` | `SearchViewModel` | ❌ 仅调方法 |
| `VocabWordListView` | `VocabularyViewModel` | ❌ 仅调方法 |
| 其余 80+ 个 | 无 VM 参数 | N/A |

## 建议

保持当前架构：

```
页面层（HookWidget）    ← 负责信号订阅
  └─ 组件层（StatelessWidget） ← 只渲染纯值
```
