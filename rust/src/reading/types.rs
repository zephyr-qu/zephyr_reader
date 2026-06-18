//! FRB-exposed types owned by the reading module.
//!
//! `PaginationSessionHandle` 由 FFI 直接 `pub use` 给 Dart，因此留在与 `api/core.rs` 同 crate 的
//! 子模块里（FRB 类型必须出现在带 `#[frb]` 标注的 crate 中）。`api/core.rs` 继续 `pub use` 转出。

use flutter_rust_bridge::frb;

/// Handle to a server-side pagination session (file/chapter/config binding).
#[derive(Debug, Clone)]
#[frb]
pub struct PaginationSessionHandle {
    pub session_id: u64,
}
