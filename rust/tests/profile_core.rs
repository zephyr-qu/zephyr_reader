//! Core operations profiling — measures real-world latency for all critical paths.
//! Uses only public FFI APIs (rust_lib_zephyr_reader::api).
//!
//! Run: cargo test --test profile_core -- --nocapture 2>/dev/null
//! Output: tab-separated rows for report generation.

mod common;

use rust_lib_zephyr_reader::api;
use rust_lib_zephyr_reader::api::core::{
    compute_config_hash, create_pagination_session, dispose_pagination_session, get_chapter,
    get_page_content, paginate_chapter, ChapterContent,
};
use rust_lib_zephyr_reader::api::search;
use rust_lib_zephyr_reader::domain::{LanguageType, TypesetConfig};
use std::fs;
use std::time::Instant;

fn fixture(name: &str) -> std::path::PathBuf {
    let p = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../test/fixtures")
        .join(name);
    assert!(p.exists(), "fixture not found: {}", p.display());
    p
}

fn config() -> TypesetConfig {
    TypesetConfig {
        page_width: 800,
        page_height: 600,
        font_size: 16,
        line_spacing: 1.5,
        language: LanguageType::Mixed,
        ..Default::default()
    }
    .validate_and_fix()
}

fn size_str(bytes: u64) -> String {
    if bytes < 1024 {
        format!("{}B", bytes)
    } else if bytes < 1024 * 1024 {
        format!("{:.1}KB", bytes as f64 / 1024.0)
    } else {
        format!("{:.1}MB", bytes as f64 / (1024.0 * 1024.0))
    }
}

fn ms_str(ms: f64) -> String {
    if ms < 1.0 {
        format!("{:.3}ms", ms)
    } else if ms < 1000.0 {
        format!("{:.2}ms", ms)
    } else {
        format!("{:.3}s", ms / 1000.0)
    }
}

fn row(op: &str, ms: f64, note: &str) {
    println!("  {:<45} {:>10}  {}", op, ms_str(ms), note);
}

async fn scratch_storage() -> tempfile::TempDir {
    let tmp = tempfile::TempDir::new().unwrap();
    let _ = api::data::init::init_storage(tmp.path().to_str().unwrap().to_string()).await;
    tmp
}

fn get_chapter_text(chapter: &ChapterContent) -> &str {
    match chapter {
        ChapterContent::Raw(t) => t,
        ChapterContent::Pages(_) => "<pages>",
    }
}

#[tokio::test]
async fn profile_all() {
    println!();
    println!("╔══════════════════════════════════════════════════════════════════════════╗");
    println!("║              Core Operations Profile (活着.epub / medium.epub)          ║");
    println!("╚══════════════════════════════════════════════════════════════════════════╝");
    println!();

    // ── 1. Book parsing ─────────────────────────────────────────
    println!("── Book Parsing ──────────────────────────────────────────");
    println!("  {:<45} {:>10}  {}", "Operation", "Latency", "Details");
    println!("  {}", "-".repeat(70));

    let books: &[(&str, &str)] = &[
        ("small.txt", "TXT 4.5KB"),
        ("mixed_content.md", "MD 1.7KB"),
        ("mixed_cjk_latin.txt", "TXT 2.5KB"),
        ("pure_cjk.txt", "TXT 4.2KB"),
        ("活着.txt", "TXT 285KB"),
        ("活着.epub", "EPUB 185KB"),
        ("medium.epub", "EPUB 1.2MB"),
        ("小王子.epub", "EPUB 874KB"),
    ];

    let mut parsed_paths: Vec<(String, String)> = Vec::new(); // (file_path, label)

    for (fixture_name, label) in books {
        let _tmp = scratch_storage().await;
        let path = fixture(fixture_name);
        let fp = path.to_str().unwrap().to_string();
        let sz = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);

        let t = Instant::now();
        match api::parse_book(fp.clone()).await {
            Ok(book_id) => {
                let ms = t.elapsed().as_secs_f64() * 1000.0;
                row("parse_book", ms, &format!("{}  book_id={}", size_str(sz), &book_id[..8]));
                parsed_paths.push((fp, label.to_string()));
            }
            Err(e) => {
                let ms = t.elapsed().as_secs_f64() * 1000.0;
                row("parse_book", ms, &format!("{}  ERROR: {}", size_str(sz), e));
            }
        }
    }

    // ── 2. Chapter loading + pagination ─────────────────────────
    println!();
    println!("── Chapter Loading & Pagination (活着.epub) ────────────");
    println!("  {:<45} {:>10}  {}", "Operation", "Latency", "Details");
    println!("  {}", "-".repeat(70));

    let _tmp = scratch_storage().await;
    let path = fixture("活着.epub");
    let fp = path.to_str().unwrap().to_string();
    let _book_id = api::parse_book(fp.clone()).await.expect("parse");
    let cfg = config();

    // 2a. get_chapter (chapter 0)
    let t = Instant::now();
    let chapter0 = get_chapter(fp.clone(), 0, Some(cfg.clone()))
        .await
        .expect("get_chapter ch0");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    let text0 = get_chapter_text(&chapter0);
    row("get_chapter (ch0)", ms, &format!("{}", size_str(text0.len() as u64)));

    // 2b. paginate_chapter cold
    let t = Instant::now();
    let pr = paginate_chapter(fp.clone(), 0, cfg.clone(), None)
        .await
        .expect("paginate_chapter");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("paginate_chapter (cold, ch0)", ms, &format!("{} pages", pr.descriptors.len()));

    // 2c. paginate_chapter cache hit
    let t = Instant::now();
    let pr2 = paginate_chapter(fp.clone(), 0, cfg.clone(), None)
        .await
        .expect("paginate_chapter warm");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    let hit = if pr2.config_hash == pr.config_hash {
        "cache HIT"
    } else {
        "cache MISS"
    };
    row("paginate_chapter (warm, ch0)", ms, &format!("{} pages  {}", pr2.descriptors.len(), hit));

    // 2d. create_pagination_session (replaces paginate_all_content scroll mode)
    let t = Instant::now();
    let (handle, result) = create_pagination_session(fp.clone(), 0, cfg.clone(), None)
        .await
        .expect("pagination_session");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("paginate_all (scroll, ch0)", ms, &format!("{} pages", result.descriptors.len()));
    dispose_pagination_session(handle).expect("dispose");

    // 2e. get_page_content
    let t = Instant::now();
    let _pc = get_page_content(fp.clone(), 0, compute_config_hash(cfg.clone()), 0).expect("get_page_content");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("get_page_content (page 0)", ms, "");

    // ── 3. Cross-chapter switching ──────────────────────────────
    println!();
    println!("── Cross-Chapter Switching (活着.epub, ch0 → ch1) ───────");
    println!("  {:<45} {:>10}  {}", "Operation", "Latency", "Details");
    println!("  {}", "-".repeat(70));

    

    // 3b. paginate switch ch0
    let t = Instant::now();
    let (h0, _) = create_pagination_session(fp.clone(), 0, cfg.clone(), None)
        .await
        .unwrap();
    let tp0 = t.elapsed().as_secs_f64() * 1000.0;
    dispose_pagination_session(h0).unwrap();
    // paginate switch ch1
    let (h1, _) = create_pagination_session(fp.clone(), 1, cfg.clone(), None)
        .await
        .unwrap();
    let tp1 = t.elapsed().as_secs_f64() * 1000.0;
    dispose_pagination_session(h1).unwrap();
    row("paginate session ch0", tp0, "");
    row("paginate session ch1", tp1 - tp0, "switch from ch0");

    // ── 4. Large file ──────────────────────────────────────────
    println!();
    println!("── Large File (medium.epub 1.2MB) ───────────────────────");
    println!("  {:<45} {:>10}  {}", "Operation", "Latency", "Details");
    println!("  {}", "-".repeat(70));

    let _tmp2 = scratch_storage().await;
    let path2 = fixture("medium.epub");
    let fp2 = path2.to_str().unwrap().to_string();
    let _ = api::parse_book(fp2.clone()).await.expect("parse medium");

    let t = Instant::now();
    let _ = paginate_chapter(fp2.clone(), 0, cfg.clone(), None).await;
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("paginate_chapter (cold, ch0)", ms, "medium.epub 1.2MB");

    let t = Instant::now();
    let _ = paginate_chapter(fp2.clone(), 0, cfg.clone(), None).await;
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("paginate_chapter (warm, ch0)", ms, "cache HIT");



    // ── 5. Search engine ────────────────────────────────────────
    println!();
    println!("── Search Indexing & Query ─────────────────────────────");
    println!("  {:<45} {:>10}  {}", "Operation", "Latency", "Details");
    println!("  {}", "-".repeat(70));

    let _tmp3 = scratch_storage().await;
    let path3 = fixture("活着.txt");
    let fp3 = path3.to_str().unwrap().to_string();
    let bid3 = api::parse_book(fp3.clone()).await.expect("parse");
    let _ = search::init_search_engine().await;

    // Index chapter 0
    let ch = get_chapter(fp3.clone(), 0, Some(cfg.clone()))
        .await
        .expect("chapter");
    let ch_text = match &ch {
        ChapterContent::Raw(t) => t.clone(),
        _ => String::new(),
    };
    let t = Instant::now();
    search::index_chapter(bid3.clone(), "ch0".into(), 0, "第一章".into(), ch_text.clone())
        .await
        .expect("index");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("index_chapter (ch0)", ms, &format!("text={}", size_str(ch_text.len() as u64)));

    // Search queries
    for query in &["的", "活着", "富贵"] {
        let t = Instant::now();
        let results = search::search_all_books(query.to_string(), 10, 0)
            .await
            .expect("search");
        let ms = t.elapsed().as_secs_f64() * 1000.0;
        row(&format!("search \"{}\"", query), ms, &format!("{} hits", results.len()));
    }

    // Index stats
    let t = Instant::now();
    let _stats = search::get_index_stats().await.expect("stats");
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("get_index_stats", ms, "");

    // ── 6. Error path ───────────────────────────────────────────
    println!();
    println!("── Error Paths ──────────────────────────────────────────");
    println!("  {:<45} {:>10}  {}", "Operation", "Latency", "Details");
    println!("  {}", "-".repeat(70));

    let t = Instant::now();
    let _ = api::parse_book("/nonexistent/book.txt".into()).await;
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("parse_book (nonexistent)", ms, "expected FileNotFound");

    let t = Instant::now();
    let _ = api::parse_book("/tmp/fake.pdf".into()).await;
    let ms = t.elapsed().as_secs_f64() * 1000.0;
    row("parse_book (unsupported .pdf)", ms, "expected UnsupportedFormat");

    println!();
    println!("╔══════════════════════════════════════════════════════════════════════════╗");
    println!("║                              Profile Complete                          ║");
    println!("╚══════════════════════════════════════════════════════════════════════════╝");
    println!();
}
