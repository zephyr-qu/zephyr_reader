use std::path::PathBuf;

/// Returns the path to a fixture file in `test/fixtures/`.
pub fn fixture_path(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../test/fixtures")
        .join(name)
}

/// Require a fixture file to exist. Returns `None` (with a skip message)
/// if the fixture is missing, allowing the test to skip gracefully.
pub fn require_fixture(name: &str) -> Option<PathBuf> {
    let p = fixture_path(name);
    if p.exists() {
        Some(p)
    } else {
        eprintln!("SKIP: missing fixture {name} at {}", p.display());
        None
    }
}
