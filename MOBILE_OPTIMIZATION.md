# Zephyr Reader — Mobile Optimization Analysis

## 12. 待办事项 (2026-06-02 审查)

> 已完成项已从本文档删除，仅保留 🟡 部分完成 与 ❌ 未完成 项。
> 2026-06-02 审计：RepaintBoundary / shouldRepaint / SharedPrefs 防抖 / Timer 审计均已确认无需改动，已移除。


### 7. Navigation & Deep Linking

- 🟡 滚动位置保留 — ShellRoute 外 reader 路由导致卸载全部 tab 页，需架构级改动（VM 生命周期 / IndexedStack / KeepAlive），单独排期


### 10. Platform-Specific

- 🟡 Edge-to-edge — 未审计