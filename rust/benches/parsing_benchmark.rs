//! Rust 引擎性能基准测试（扩展版）
//!
//! 使用 criterion 库进行性能测试，生成 HTML 报告。
//!
//! # 运行方法
//! ```bash
//! cargo bench
//! ```
//!
//! 报告位于 `target/criterion/report/index.html`
//!
//! # Benchmark Groups
//!
//! | Group | 测量目标 | 数据来源 |
//! |---|---|---|
//! | `txt_parsing` | 合成 TXT parse_book（修复存储初始化） | 生成的中/英文文本 1/10/50KB |
//! | `pagination` | 裸 paginate_all（纯 Rust 计算，无 FFI 开销） | 生成的中文文本 1/5/10KB |
//! | `book_parsing` | 真实 TXT/EPUB 文件 parse_book | fixtures/活的.txt/.epub、small.txt |
//! | `chapter_pagination` | FFI 入口 paginate_chapter（含 Provider 缓存） | fixtures/活的.txt |
//! | `page_fetch` | 同步 get_page_content（高频查缓存） | 同上 |
//! | `search` | FTS5 全文搜索 | 活的.txt 索引后搜索高频词 |

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use rust_lib_zephyr_reader::api;
use rust_lib_zephyr_reader::api::data::chapter;
use rust_lib_zephyr_reader::api::core as api_core;
use rust_lib_zephyr_reader::domain::{LanguageType, TypesetConfig};
use rust_lib_zephyr_reader::text::paginate_all;
use std::fs;
use std::hint::black_box;
use std::path::PathBuf;
use std::time::Duration;
use tempfile::TempDir;

/// fixtures 目录相对路径（从 rust crate 根目录）
const FIXTURES_DIR: &str = "../test/fixtures/";

/// 创建一个单线程 tokio runtime（benchmark 内部使用）
fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 初始化存储 + 返回 temp dir（保证 benchmark 间数据隔离）
fn setup_storage() -> (TempDir, tokio::runtime::Runtime) {
    let rt = runtime();
    let tmp = TempDir::new().unwrap();
    rt.block_on(api::data::init::init_storage(
        tmp.path().to_string_lossy().to_string(),
    ))
    .unwrap();
    (tmp, rt)
}

// ═══════════════════════════════════════════════════════════════
// 原有基准（保留基线）
// ═══════════════════════════════════════════════════════════════

fn generate_chinese_text(size_kb: usize) -> String {
    let base_text = "这是一段测试文本，用于性能基准测试。";
    let repetitions = (size_kb * 1024) / base_text.len();
    base_text.repeat(repetitions)
}

fn generate_english_text(size_kb: usize) -> String {
    let base_text = "This is a test text for performance benchmarking. ";
    let repetitions = (size_kb * 1024) / base_text.len();
    base_text.repeat(repetitions)
}

/// 合成 TXT 解析（已修正：初始化存储以使 parse_book 执行完整路径）
fn bench_txt_parsing(c: &mut Criterion) {
    let (_tmp, rt) = setup_storage();
    let mut group = c.benchmark_group("txt_parsing");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    for size in [1, 10, 50].iter() {
        for (lang, gen_fn) in [
            ("zh", generate_chinese_text as fn(usize) -> String),
            ("en", generate_english_text as fn(usize) -> String),
        ] {
            let text = gen_fn(*size);
            let file_path = std::env::temp_dir().join(format!("synthetic_{}kb_{}.txt", size, lang));
            fs::write(&file_path, &text).unwrap();
            let path_str = file_path.to_string_lossy().to_string();

            group.throughput(Throughput::Bytes(text.len() as u64));
            group.bench_with_input(
                BenchmarkId::new(format!("{}/{}", lang, size), ""),
                &path_str,
                |b, path| {
                    b.iter(|| {
                        rt.block_on(async {
                            let _ = api::parse_book(black_box(path.clone())).await;
                        })
                    })
                },
            );
            let _ = fs::remove_file(&file_path);
        }
    }
    group.finish();
}

/// 裸分页计算（无 FFI 开销）
fn bench_pagination(c: &mut Criterion) {
    let mut group = c.benchmark_group("pagination");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    let config = TypesetConfig {
        page_width: 1080,
        page_height: 1920,
        font_size: 18,
        line_spacing: 1.5,
        letter_spacing: 0.0,
        paragraph_spacing: 1.0,
        auto_space_ratio: 0.25,
        first_line_indent: 2,
        language: LanguageType::Auto,
        // enable_hyphenation: false,
        // hyphenation_language: Some("en".to_string()),
        punctuation_squeeze: true,
        font_family: "Noto Sans SC".into(),
        calibration: None,
    };

    for size in [1, 5, 10].iter() {
        let text = generate_chinese_text(*size);

        group.throughput(Throughput::Bytes(text.len() as u64));
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}kb", size)),
            &text,
            |b, text| {
                b.iter(|| {
                    let _ = paginate_all(
                        black_box(text.clone()),
                        black_box(0),
                        black_box(config.clone()),
                    );
                })
            },
        );
    }
    group.finish();
}

// ═══════════════════════════════════════════════════════════════
// 新增：真实文件解析
// ═══════════════════════════════════════════════════════════════

/// 使用 fixtures 中的真实 TXT/EPUB 文件测量 parse_book
fn bench_book_parsing(c: &mut Criterion) {
    let (_tmp, rt) = setup_storage();
    let mut group = c.benchmark_group("book_parsing");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    let books = [
        ("txt", "small.txt"),
        ("txt", "活着.txt"),
        ("epub", "活着.epub"),
    ];

    for (fmt, name) in &books {
        let path = PathBuf::from(FIXTURES_DIR).join(name);
        let size = fs::metadata(&path).unwrap().len();
        let path_str = path.to_string_lossy().to_string();

        group.throughput(Throughput::Bytes(size));
        group.bench_with_input(
            BenchmarkId::new(*fmt, *name),
            &path_str,
            |b, p| {
                b.iter(|| {
                    rt.block_on(async {
                        let _ = api::parse_book(black_box(p.clone())).await;
                    })
                })
            },
        );
    }
    group.finish();
}

// ═══════════════════════════════════════════════════════════════
// 新增：FFI 入口分页
// ═══════════════════════════════════════════════════════════════

/// 测量 paginate_chapter（真正的 FFI 入口，含 Provider 缓存）
fn bench_chapter_pagination(c: &mut Criterion) {
    let (_tmp, rt) = setup_storage();

    // 一次性 setup：解析书籍写入 DB
    let path = PathBuf::from(FIXTURES_DIR).join("活着.txt");
    let path_str = path.to_string_lossy().to_string();
    rt.block_on(api::parse_book(path_str.clone()))
        .unwrap();

    let config = TypesetConfig::default();

    let mut group = c.benchmark_group("chapter_pagination");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    group.bench_with_input(
        BenchmarkId::new("txt", "活着"),
        &path_str,
        |b, p| {
            b.iter(|| {
                rt.block_on(async {
                    let _ = api_core::paginate_chapter(
                        black_box(p.clone()),
                        0,
                        black_box(config.clone()),
                        None,
                    )
                    .await;
                })
            })
        },
    );
    group.finish();
}

// ═══════════════════════════════════════════════════════════════
// 新增：按需获取页面内容
// ═══════════════════════════════════════════════════════════════

/// 测量 get_page_content（同步，LRU 缓存命中路径）
fn bench_page_fetch(c: &mut Criterion) {
    let (_tmp, rt) = setup_storage();
    let path = PathBuf::from(FIXTURES_DIR).join("活着.txt");
    let path_str = path.to_string_lossy().to_string();
    let config = TypesetConfig::default();
    let config_hash = config.config_hash();

    // setup：解析 + 首次分页（填充 STREAMER_CACHE）
    rt.block_on(api::parse_book(path_str.clone()))
        .unwrap();
    rt.block_on(api_core::paginate_chapter(
        path_str.clone(),
        0,
        config,
        None,
    ))
    .unwrap();
    let mut group = c.benchmark_group("page_fetch");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    group.bench_function("txt/活着_page0", |b| {
        b.iter(|| {
            let _ = api_core::get_page_content(
                black_box(path_str.clone()),
                0,
                black_box(config_hash),
                0,
            );
        })
    });
    group.finish();
}

// ═══════════════════════════════════════════════════════════════
// 新增：FTS5 全文搜索
// ═══════════════════════════════════════════════════════════════

/// 测量 search() FTS5 全文搜索延迟
///
/// setup：解析书籍 → 初始化搜索引擎 → 索引第一章 → 搜索高频词
fn bench_search(c: &mut Criterion) {
    let (_tmp, rt) = setup_storage();
    let path = PathBuf::from(FIXTURES_DIR).join("活着.txt");
    let path_str = path.to_string_lossy().to_string();

    // (1) 解析书籍获取 book_id
    let book_id = rt
        .block_on(api::parse_book(path_str.clone()))
        .unwrap();

    // (2) 初始化搜索引擎
    rt.block_on(api::init_search_engine()).unwrap();

    // (3) 获取第一章内容
    let chapter_content = rt
        .block_on(api_core::get_chapter(path_str.clone(), 0, None))
        .unwrap();
    let chapter_text = match &chapter_content {
        api::ChapterContent::Raw(t) => t.clone(),
        _ => panic!("get_chapter with config=None should return Raw variant"),
    };

    let result = rt
        .block_on(chapter::list_chapters_by_book(book_id.clone()))
        .unwrap();
    let chapter_id = result[0].id.clone();
    let chapter_title = result[0].title.clone();

    // (4) 索引
    rt.block_on(api::index_chapter(
        book_id.clone(),
        chapter_id,
        0,
        chapter_title,
        chapter_text,
    ))
    .unwrap();

    let mut group = c.benchmark_group("search");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    for query in ["活着", "福贵", "家珍"] {
        let q = query.to_string();
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("'{}'", query)),
            &q,
            |b, q| {
                b.iter(|| {
                    rt.block_on(async {
                        let _ = api::search(
                            black_box(book_id.clone()),
                            black_box(q.clone()),
                            10,
                        )
                        .await;
                    })
                })
            },
        );
    }
    group.finish();
}

criterion_group!(
    benches,
    bench_txt_parsing,
    bench_pagination,
    bench_book_parsing,
    bench_chapter_pagination,
    bench_page_fetch,
    bench_search,
);
criterion_main!(benches);
