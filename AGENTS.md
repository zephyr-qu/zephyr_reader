# CLAUDE.md — 12 Rules

Drop this file in your project root. Claude Code / Codex / Cursor / Hermes all read it. Keep it short — past ~200 lines compliance drops sharply.

## Rules

1. **Think before coding.** State assumptions out loud. Surface tradeoffs. Push back when a simpler approach exists. No silent guesses.
2. **Simplicity first.** Minimum code that solves the stated problem. No speculative features. No abstractions for single-use code.
3. **Surgical changes.** Touch only what the task requires. Don't "improve" adjacent code, comments, or formatting. Match existing style.
4. **Goal-driven execution.** Define success criteria up front, then loop until verified. Prefer stating the goal over dictating steps.
5. **Don't make the model do non-language work.** Retries, routing, rate-limiting, arithmetic, time — write deterministic code, not prompts.
6. **Hard token budget.** Every loop gets a ceiling. If the same 8KB input has been re-chewed for 90 minutes, stop and step back.
7. **Surface conflicts, don't average them.** When two parts of the codebase disagree (two error patterns, two state stores), pick one visibly and explain why. Doing both doubles the bug surface.
8. **Read before you write.** Before adding code, read the nearby code. New functions that duplicate existing ones break silently through import order.
9. **Tests are gated by correctness, not "pass."** A passing test on a function returning a constant is not a passing test. Tie assertions to behavior, not shape.
10. **Long-running operations need checkpoints.** Multi-step refactors and migrations commit between steps so one bad turn doesn't require rewinding six.
11. **Convention beats novelty.** In a codebase with an established pattern, use that pattern even when yours is "better." Two patterns are always worse than either alone.
12. **Fail visibly, not silently.** A migration that "completed successfully" while skipping 14% of records on constraint violations is a bug, not a success. Surface partial failure, skipped rows, truncated output, retry exhaustion.

## Project specifics

- Stack: Flutter (Dart) + Rust (FRB) + flutter_rust_bridge
- 绝对禁区: 严禁读取、修改或建议改动 `frb_generated.rs`、`frb_generated.h`、`lib/src/rust/` 等任何自动生成文件。如需调整 FFI 接口，仅允许修改 Rust 侧源文件并重新执行 `flutter_rust_bridge generate`
- Rust API 规范: 所有导出函数必须返回 `Result<T, AppError>`，禁止 panic 跨越 FFI 边界
- 类型映射: 优先使用 FRB 原生支持的零拷贝类型（如 `Uint8List`, `String`），避免自定义 Struct 的冗余序列化
- 测试策略: Rust 侧单元测试覆盖纯逻辑；Dart 侧仅做集成测试与 UI 绑定验证，不重复测试 Rust 已覆盖的逻辑
- 异步模型: Rust 侧统一使用 `tokio::spawn` + `channel`，Dart 侧通过 FRB Stream/Sink 消费，禁止在 FFI 层阻塞主线程
- Lint: Rust 侧 `cargo clippy -- -D warnings`；Dart 侧 `dart analyze --fatal-infos`，CI 前必须双端通过
- Rust规范: rust 代码规范查看[RUST_ENGINE_SPEC](rust/RUST_ENGINE_SPEC.md)

## Verification checklist

Before returning a task as done:

- [ ] Did I state my assumptions explicitly?
- [ ] Did any change touch code outside the stated scope? If yes, revert or justify.
- [ ] Did any test pass without actually verifying behavior? Re-check assertions.
- [ ] Any partial failure, skipped record, truncated output? Surface it in the summary.
