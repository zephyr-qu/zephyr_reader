# CLAUDE.md — 12 Rules

Drop this file in your project root. Claude Code / Codex / Cursor / Hermes all read it. Keep it short — past \~200 lines compliance drops sharply.

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

FRB 自动生成文件禁区：

- 绝不手动修改 frb\_generated.rs、frb\_generated.h 或 lib/src/rust/ 下的生成代码。
- 接口调整仅通过修改 Rust 源文件 (rust/src/api/...) 并重新运行 flutter\_rust\_bridge\_codegen generate 实现。

Rust API 健壮性：

- 所有 FFI 导出函数签名必须为 pub fn xxx(...) -> Result\<T, AppError>。
- &#x20;严禁 panic! 跨越边界，所有错误必须转换为 AppError 变体。

性能与类型映射：

- 优先使用零拷贝类型（Vec<u8> ↔ Uint8List, String ↔ String）。
- 避免不必要的自定义 Struct 序列化开销。

异步与并发模型：

- Rust 侧：tokio::spawn + channel (mpsc/broadcast)。
- Dart 侧：通过 FRB 生成的 Stream/Sink 消费数据。
- 严禁在 FFI 调用中执行阻塞操作。

测试与质量门禁：

-  Rust: cargo clippy -- -D warnings + 单元测试覆盖纯逻辑。
- &#x20;Dart: dart analyze --fatal-infos + 集成/UI 测试验证绑定。
- 测试纪律: 发现生产代码 Bug 时，仅记录在文档/TODO 中，严禁为了通过测试而临时修改生产逻辑。

GIT铁律：

- Git 操作限制：在任何情况下，严禁执行 git reset、git revert、git checkout . 或任何可能丢弃用户本地未提交更改的 Git 命令。
- 代码恢复策略：如果建议的代码修改导致问题，提供修复补丁（Patch）或增量修改建议，由用户手动决定是否应用或回退。

编码与提交规范：

- 在大型任务（如重构、新功能实现）执行完毕后，主动提醒或协助准备本地提交（Commit），确保进度存档。
-
  在使用脚本（Python/Bash等）批量修改文本文件时，必须显式指定 UTF-8 编码，严禁依赖系统默认编码，防止中文注释或字符串乱码。

## Launching Dart and Flutter Applications

- Always pass the `--print-dtd` flag to `dart` or `flutter` when spawning an
  application.
- For `dart` applications, always pass the `--observe` flag to enable the app to
  be connected to.
- Both `--print-dtd` and `--observe` must come before the script name or path
  when spawning `dart` applications: `dart --observe --print-dtd bin/main.dart`.

## Verification checklist

Before returning a task as done:

- [ ] Did I state my assumptions explicitly?
- [ ] Did any change touch code outside the stated scope? If yes, revert or justify.
- [ ] Did any test pass without actually verifying behavior? Re-check assertions.
- [ ] Any partial failure, skipped record, truncated output? Surface it in the summary.

