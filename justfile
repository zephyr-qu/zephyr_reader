# ── Zephyr Reader — dev task runner ──
# Install `just`: https://github.com/casey/just
#   Windows: winget install --id Casey.Just
#   macOS:   brew install just
#   Linux:   cargo install just

# ── Setup ──

setup:
    flutter pub get
    cd rust && cargo fetch

# ── Code Generation ──

gen:
    flutter_rust_bridge_codegen generate
    dart run build_runner build --delete-conflicting-outputs

# ── Lint ──

lint:
    cd rust && cargo clippy --all-targets -- -D warnings
    dart analyze --fatal-infos

# format
fmt:
    cd rust && cargo fmt --all -- --check

# ── Test ──

test:
    cd rust && cargo test
    flutter test

# ── Build ──

build apk:
    flutter build apk --release --target-platform=android-arm64

build ios:
    flutter build ios --release --no-codesign

# ── Clean ──

clean:
    cd rust && cargo clean
    flutter clean
