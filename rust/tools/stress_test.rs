//! Rust 引擎压测工具
//!
//! 测量大章节排版、大体积书籍导入、批量导入的性能。
//! 输出 JSON 格式结果，方便 CI 解析汇总。
//!
//! # 运行
//! ```bash
//! cargo run --bin stress_test --release -- [options]
//! ```
//!
//! # 选项
//! - `--quick`: 快速模式（减少样本量）
//! - `--pagination`: 只跑排版压测
//! - `--import`: 只跑导入压测
//! - `--batch`: 只跑批量导入压测
//! - `--pipeline`: 只生产阅读路径压测 (paginate_chapter + get_page_content)
//!
//! # 输出格式
//! 每行一个 JSON: `{"test":"...","metric":"...","value":...,"unit":"..."}`

use rust_lib_zephyr_reader::api;
use rust_lib_zephyr_reader::api::core as api_core;
use rust_lib_zephyr_reader::api::data::chapter as api_chapter;
use rust_lib_zephyr_reader::domain::{LanguageType, TypesetConfig};
use rust_lib_zephyr_reader::text::paginate_all;
use std::fs;
use std::hint::black_box;
use std::path::PathBuf;
use std::time::{Duration, Instant};
use tempfile::TempDir;

const FIXTURES_DIR: &str = "../test/fixtures/";

// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

fn runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

fn setup_storage() -> (TempDir, tokio::runtime::Runtime) {
    let rt = runtime();
    let tmp = TempDir::new().unwrap();
    rt.block_on(api::data::init::init_storage(
        tmp.path().to_string_lossy().to_string(),
    ))
    .unwrap();
    (tmp, rt)
}

/// 生成含段落结构的中文文本（行分割计入排版基准，更真实）
fn generate_chinese_text(size_kb: usize) -> String {
    let para =
        "这是一段测试文本，用于性能基准测试。它包含中英文混排、标点符号和段落结构。";
    let repetitions = (size_kb * 1024) / para.len();
    let mut text = String::with_capacity(size_kb * 1024);
    for i in 0..repetitions {
        text.push_str(para);
        if i % 5 == 4 {
            text.push('\n'); // 每 5 段换行
        }
    }
    text
}


fn default_config() -> TypesetConfig {
    TypesetConfig {
        page_width: 1080,
        page_height: 1920,
        font_size: 18,
        line_spacing: 1.5,
        letter_spacing: 0.0,
        paragraph_spacing: 1.0,
        auto_space_ratio: 0.25,
        first_line_indent: 2,
        language: LanguageType::Auto,
        punctuation_squeeze: true,
        font_family: "Noto Sans SC".into(),
        calibration: None,
    }
}

fn result_line(test: &str, metric: &str, value: f64, unit: &str) {
    let json = serde_json::json!({
        "test": test,
        "metric": metric,
        "value": value,
        "unit": unit,
    });
    println!("[RESULT] {}", json);
}

/// 运行 N 次测量，返回平均值和 p99
fn measure_n<F>(n: usize, mut f: F) -> (Duration, Vec<Duration>)
where
    F: FnMut(),
{
    let mut samples = Vec::with_capacity(n);
    for _ in 0..n {
        let start = Instant::now();
        f();
        samples.push(start.elapsed());
    }
    samples.sort();
    let avg = samples.iter().sum::<Duration>().as_secs_f64() / n as f64;
    let p99_idx = ((n as f64) * 0.99).ceil() as usize - 1;
    let p99_idx = p99_idx.min(n - 1);
    let p99 = samples[p99_idx];

    // 打印分布
    let p50 = samples[n / 2];
    let p95_idx = ((n as f64) * 0.95).ceil() as usize - 1;
    let p95_idx = p95_idx.min(n - 1);
    let p95 = samples[p95_idx];

    result_line(
        "measure_n",
        "avg_ms",
        avg * 1000.0,
        "ms",
    );
    result_line(
        "measure_n",
        "p50_ms",
        p50.as_secs_f64() * 1000.0,
        "ms",
    );
    result_line(
        "measure_n",
        "p95_ms",
        p95.as_secs_f64() * 1000.0,
        "ms",
    );
    result_line(
        "measure_n",
        "p99_ms",
        p99.as_secs_f64() * 1000.0,
        "ms",
    );

    (Duration::from_secs_f64(avg), samples)
}

// ═══════════════════════════════════════════════════════════════
// 1. 大章节排版压测
// ═══════════════════════════════════════════════════════════════

fn stress_pagination(sample_size: usize) {
    println!("\n=== [1/3] 大章节排版压测 ===");

    let config = default_config();
    let config_hash = config.config_hash();

    // 1a. 裸 paginate_all 对比 eager vs lazy
    println!("\n--- 1a. paginate_all 纯计算 ---");
    for &size_kb in &[1, 10, 50, 100, 500, 2048] {
        let text = generate_chinese_text(size_kb);
        let mode = if size_kb >= 50 { "lazy" } else { "eager" };
        let samples = measure_n(sample_size, || {
            black_box(paginate_all(
                black_box(text.clone()),
                black_box(0),
                black_box(config.clone()),
            ));
        });
        let pages = paginate_all(text.clone(), 0, config.clone());
        result_line(
            "pagination_stress",
            &format!("paginate_all/{mode}/{size_kb}kb"),
            samples.0.as_secs_f64() * 1000.0,
            "ms",
        );
        result_line(
            "pagination_stress",
            &format!("page_count/{size_kb}kb"),
            pages.len() as f64,
            "pages",
        );
    }

    // 1b. 大章节 FFI 入口 paginate_chapter（含 Provider 缓存、SQLite 查章节边界）
    //    使用真实 fixture 文件以保证数据流完整
    println!("\n--- 1b. paginate_chapter 完整链路 ---");
    {
        let (_tmp, rt) = setup_storage();
        let fixture_path = PathBuf::from(FIXTURES_DIR).join("活着.txt");
        let path_str = fixture_path.to_string_lossy().to_string();

        // 先解析书籍，写入 DB
        rt.block_on(api::parse_book(path_str.clone()))
            .unwrap();

        // 预热：首次调用填充 Provider + LRU
        rt.block_on(api_core::paginate_chapter(
            path_str.clone(),
            0,
            config.clone(),
            None,
        ))
        .unwrap();

        let samples = measure_n(sample_size, || {
            rt.block_on(api_core::paginate_chapter(
                black_box(path_str.clone()),
                0,
                black_box(config.clone()),
                None,
            ))
            .unwrap();
        });
        result_line(
            "pagination_stress",
            "paginate_chapter/活着.txt",
            samples.0.as_secs_f64() * 1000.0,
            "ms",
        );
    }

    // 1c. 连续翻页 — 测量 get_page_content 缓存命中 P99
    println!("\n--- 1c. get_page_content 翻页延迟分布 ---");
    {
        let (_tmp, rt) = setup_storage();
        let fixture_path = PathBuf::from(FIXTURES_DIR).join("活着.txt");
        let path_str = fixture_path.to_string_lossy().to_string();

        rt.block_on(api::parse_book(path_str.clone()))
            .unwrap();
        let result = rt
            .block_on(api_core::paginate_chapter(
                path_str.clone(),
                0,
                config.clone(),
                None,
            ))
            .unwrap();
        let total_pages = result.descriptors.len();
        let pages_to_test = total_pages.min(200);

        let mut latencies = Vec::with_capacity(pages_to_test);
        for page in 0..pages_to_test {
            let start = Instant::now();
            let _ = api_core::get_page_content(
                path_str.clone(),
                0,
                config_hash,
                page as i32,
            );
            latencies.push(start.elapsed());
        }
        latencies.sort();
        let p50 = latencies[pages_to_test / 2];
        let p95 = latencies[((pages_to_test as f64) * 0.95) as usize];
        let p99 = latencies[((pages_to_test as f64) * 0.99) as usize];
        let avg = latencies.iter().sum::<Duration>().as_secs_f64()
            / pages_to_test as f64;

        result_line("page_turn", "pages_tested", pages_to_test as f64, "pages");
        result_line("page_turn", "avg_ms", avg * 1000.0, "ms");
        result_line("page_turn", "p50_ms", p50.as_secs_f64() * 1000.0, "ms");
        result_line("page_turn", "p95_ms", p95.as_secs_f64() * 1000.0, "ms");
        result_line("page_turn", "p99_ms", p99.as_secs_f64() * 1000.0, "ms");
    }
}

// ═══════════════════════════════════════════════════════════════
// 4. 生产阅读路径压测 (paginate_chapter + get_page_content)
// ═══════════════════════════════════════════════════════════════

fn stress_production_pipeline(sample_size: usize) {
    println!("\n=== [4/3] 生产阅读路径压测 ===");

    let config = default_config();
    let config_hash = config.config_hash();
    let large_txt = PathBuf::from(FIXTURES_DIR).join("large.txt");

    if !large_txt.exists() {
        println!("  ⚠ large.txt (51.2MB) not found, partial pipeline only");
    }

    // 4a. paginate_chapter 大章节压测
    println!("\n--- 4a. paginate_chapter 生产路径 ---");
    {
        let (_tmp, rt) = setup_storage();

        if large_txt.exists() {
            let path_str = large_txt.to_string_lossy().to_string();
            let book_id = rt.block_on(api::parse_book(path_str.clone())).unwrap();
            let chapters = rt.block_on(api_chapter::list_chapters_by_book(book_id)).unwrap();

            let (max_ch_idx, max_ch_size) = chapters
                .iter()
                .map(|ch| (ch.chapter_index as i32, ch.end_index - ch.start_index))
                .max_by_key(|&(_, s)| s)
                .unwrap_or((0, 0));
            result_line("pipeline", "large_txt_chapters", chapters.len() as f64, "chapters");
            result_line("pipeline", "largest_chapter_bytes", max_ch_size as f64, "bytes");
            result_line("pipeline", "largest_chapter_idx", max_ch_idx as f64, "idx");

            // 4a-i. paginateChapterPartial (50K chars)
            let t_partial = measure_n(sample_size, || {
                rt.block_on(api_core::paginate_chapter(
                    black_box(path_str.clone()),
                    max_ch_idx as i32,
                    black_box(config.clone()),
                    Some(50000),
                ))
                .unwrap();
            });
            result_line(
                "pipeline_partial",
                "paginate_chapter/50Kchars",
                t_partial.0.as_secs_f64() * 1000.0,
                "ms",
            );

            // 查看 50K partial 产出了多少描述符
            let partial_result = rt.block_on(api_core::paginate_chapter(
                path_str.clone(),
                max_ch_idx as i32,
                config.clone(),
                Some(50000),
            ))
            .unwrap();
            result_line("pipeline_partial", "descriptor_count", partial_result.descriptors.len() as f64, "pages");

            // 4a-ii. paginateChapter 全量
            let t_full = measure_n(sample_size, || {
                rt.block_on(api_core::paginate_chapter(
                    black_box(path_str.clone()),
                    max_ch_idx,
                    black_box(config.clone()),
                    None,
                ))
                .unwrap();
            });
            let full_result = rt.block_on(api_core::paginate_chapter(
                path_str.clone(),
                max_ch_idx,
                config.clone(),
                None,
            ))
            .unwrap();
            result_line("pipeline_full", "paginate_chapter/full", t_full.0.as_secs_f64() * 1000.0, "ms");
            result_line("pipeline_full", "descriptor_count", full_result.descriptors.len() as f64, "pages");
            let pages_to_test = full_result.descriptors.len().min(100);
            let mut latencies = Vec::with_capacity(pages_to_test);
            for page in 0..pages_to_test {
                let start = Instant::now();
                let _ = api_core::get_page_content(
                    path_str.clone(),
                    max_ch_idx as i32,
                    config_hash,
                    page as i32,
                );
                latencies.push(start.elapsed());
            }
            latencies.sort();
            let avg = latencies.iter().sum::<Duration>().as_secs_f64() / pages_to_test as f64;
            let p50 = latencies[pages_to_test / 2];
            let p95 = latencies[((pages_to_test as f64) * 0.95) as usize];
            let p99 = latencies[((pages_to_test as f64) * 0.99) as usize];

            result_line("pipeline_page_turn", "pages_tested", pages_to_test as f64, "pages");
            result_line("pipeline_page_turn", "avg_ms", avg * 1000.0, "ms");
            result_line("pipeline_page_turn", "p50_ms", p50.as_secs_f64() * 1000.0, "ms");
            result_line("pipeline_page_turn", "p95_ms", p95.as_secs_f64() * 1000.0, "ms");
            result_line("pipeline_page_turn", "p99_ms", p99.as_secs_f64() * 1000.0, "ms");

            // 4a-iv. 完整生产流程计时
            println!("\n--- 4a-iv. 完整生产阅读流程 (partial→full→page_turn) ---");
            {
                let big_dir = TempDir::new().unwrap();
                let big_path = big_dir.path().join("big_chapter.txt");
                let big_text = generate_chinese_text(5 * 1024); // 5MB
                fs::write(&big_path, &big_text).unwrap();
                let big_str = big_path.to_string_lossy().to_string();

                // 解析
                rt.block_on(api::parse_book(big_str.clone())).unwrap();

                let pipeline_start = Instant::now();

                // step 1: paginateChapterPartial (50K chars) → ~300ms
                let partial_result = rt
                    .block_on(api_core::paginate_chapter(
                        big_str.clone(),
                        0,
                        config.clone(),
                        Some(50000),
                    ))
                    .unwrap();
                let t_partial_done = Instant::now();

                // step 2: get_page_content for first 5 pages (preload)
                for i in 0..5 {
                    let _ = api_core::get_page_content(
                        big_str.clone(),
                        0,
                        config_hash,
                        i,
                    );
                }
                let t_preload_done = Instant::now();

                // step 3: paginateChapter full
                let full_result = rt
                    .block_on(api_core::paginate_chapter(
                        big_str.clone(),
                        0,
                        config.clone(),
                        None,
                    ))
                    .unwrap();
                let t_full_done = Instant::now();

                // step 4: turn 20 pages
                let pages_avail = full_result.descriptors.len().min(20);
                for i in 0..pages_avail {
                    let _ = api_core::get_page_content(big_str.clone(), 0, config_hash, i as i32);
                }
                let t_finish = Instant::now();

                let partial_ms = t_partial_done.duration_since(pipeline_start).as_secs_f64() * 1000.0;
                let preload_ms = t_preload_done.duration_since(t_partial_done).as_secs_f64() * 1000.0;
                let full_ms = t_full_done.duration_since(t_preload_done).as_secs_f64() * 1000.0;
                let page_turn_ms = t_finish.duration_since(t_full_done).as_secs_f64() * 1000.0;

                result_line("pipeline_full_cycle", "partial_to_first_page_ms", partial_ms, "ms");
                result_line("pipeline_full_cycle", "preload_5_pages_ms", preload_ms, "ms");
                result_line("pipeline_full_cycle", "full_paginate_ms", full_ms, "ms");
                result_line("pipeline_full_cycle", "turn_20_pages_ms", page_turn_ms, "ms");
                result_line("pipeline_full_cycle", "total_ms", pipeline_start.elapsed().as_secs_f64() * 1000.0, "ms");
                result_line("pipeline_full_cycle", "partial_descriptors", partial_result.descriptors.len() as f64, "pages");
                result_line("pipeline_full_cycle", "total_descriptors", full_result.descriptors.len() as f64, "pages");
            }
        } else {
            // large.txt 不存在时用小文件演示流程
            let text = generate_chinese_text(2048); // 2MB
            let small_path = TempDir::new().unwrap().path().join("demo.txt");
            fs::write(&small_path, &text).unwrap();
            let small_str = small_path.to_string_lossy().to_string();
            rt.block_on(api::parse_book(small_str.clone())).unwrap();

            let partial = rt.block_on(api_core::paginate_chapter(
                small_str.clone(), 0, config.clone(), Some(50000),
            )).unwrap();
            let full = rt.block_on(api_core::paginate_chapter(
                small_str.clone(), 0, config.clone(), None,
            )).unwrap();
            result_line("pipeline_fallback", "partial_descriptors", partial.descriptors.len() as f64, "pages");
            result_line("pipeline_fallback", "full_descriptors", full.descriptors.len() as f64, "pages");
        }
    }

    // 4b. LRU 缓存驱逐压力 (STREAMER_CACHE capacity = 4)
    println!("\n--- 4b. LRU 缓存驱逐压力 ---");
    {
        let (_tmp, rt) = setup_storage();
        let syn_dir = TempDir::new().unwrap();
        let syn_paths: Vec<String> = (0..5)
            .map(|i| {
                let text = generate_chinese_text(100);
                let p = syn_dir.path().join(format!("book_{}.txt", i));
                fs::write(&p, &text).unwrap();
                let ps = p.to_string_lossy().to_string();
                rt.block_on(api::parse_book(ps.clone())).unwrap();
                ps
            })
            .collect();

        // 依次分页 5 本书 → 第 1 本应被驱逐 (capacity=4)
        for ps in &syn_paths {
            rt.block_on(api_core::paginate_chapter(
                ps.clone(), 0, config.clone(), None,
            ))
            .unwrap();
        }

        // 重新分页 book_0（应未命中缓存 → 重新创建 PageStreamer + Provider）
        let t_repag = measure_n(sample_size, || {
            rt.block_on(api_core::paginate_chapter(
                black_box(syn_paths[0].clone()),
                0,
                black_box(config.clone()),
                None,
            ))
            .unwrap();
        });
        result_line("pipeline_lru", "repaginate_after_eviction_ms", t_repag.0.as_secs_f64() * 1000.0, "ms");

        // 验证 book_4 仍在缓存中（快速命中）
        let t_hit = measure_n(sample_size, || {
            rt.block_on(api_core::paginate_chapter(
                black_box(syn_paths[4].clone()),
                0,
                black_box(config.clone()),
                None,
            ))
            .unwrap();
        });
        result_line("pipeline_lru", "repaginate_cache_hit_ms", t_hit.0.as_secs_f64() * 1000.0, "ms");

        // 同步 get_page_content 检查 book_0 缓存状态（应返回空）
        let evicted_content = api_core::get_page_content(syn_paths[0].clone(), 0, config_hash, 0);
        result_line("pipeline_lru", "evicted_page_empty", if evicted_content.is_empty() { 1.0 } else { 0.0 }, "flag");

        let hit_content = api_core::get_page_content(syn_paths[4].clone(), 0, config_hash, 0);
        result_line("pipeline_lru", "cached_page_nonempty", if !hit_content.is_empty() { 1.0 } else { 0.0 }, "flag");
    }
}

// ═══════════════════════════════════════════════════════════════
// 2. 大体积书籍导入压测
// ═══════════════════════════════════════════════════════════════

fn stress_book_import(sample_size: usize) {
    println!("\n=== [2/3] 大体积书籍导入压测 ===");

    let tmp_root = TempDir::new().unwrap();

    // 2a. 大 TXT 导入
    println!("\n--- 2a. 大 TXT 解析 (parse_book) ---");

    for &size_kb in &[1024, 10 * 1024] {
        let text = generate_chinese_text(size_kb);
        let path = tmp_root.path().join(format!("large_{}kb.txt", size_kb));
        fs::write(&path, &text).unwrap();
        let path_str = path.to_string_lossy().to_string();
        let file_size = fs::metadata(&path).unwrap().len();

        // 每次测量前初始化全新存储
        let samples = measure_n(sample_size.min(5), || {
            let (_tmp, rt) = setup_storage();
            rt.block_on(api::parse_book(black_box(path_str.clone())))
                .unwrap();
        });
        result_line(
            "book_import",
            &format!("parse_book/{size_kb}kb"),
            samples.0.as_secs_f64() * 1000.0,
            "ms",
        );
        result_line(
            "book_import",
            &format!("file_size/{size_kb}kb"),
            file_size as f64,
            "bytes",
        );
    }

    // 2b. 真实大 EPUB 导入
    println!("\n--- 2b. 真实 EPUB 解析 ---");
    {
        let path = PathBuf::from(FIXTURES_DIR).join("medium.epub");
        let path_str = path.to_string_lossy().to_string();
        let file_size = fs::metadata(&path).unwrap().len();

        let samples = measure_n(sample_size.min(5), || {
            let (_tmp, rt) = setup_storage();
            rt.block_on(api::parse_book(black_box(path_str.clone())))
                .unwrap();
        });
        result_line("book_import", "parse_book/medium.epub", samples.0.as_secs_f64() * 1000.0, "ms");
        result_line("book_import", "file_size/medium.epub", file_size as f64, "bytes");
    }

    // 2c. 超大文件限速验证（验证 parse_book 对 500MB+ 文件的拒绝行为）
    println!("\n--- 2c. 超大文件限速（500MB 拒绝）---");
    {
        let huge_path = tmp_root.path().join("huge_dummy.txt");
        // 创建一个超出限制的大文件（稀疏文件或写入头部）
        let max_file_size: u64 = 500 * 1024 * 1024; // 与 api 中 MAX_FILE_SIZE 一致
        let oversized = max_file_size + 1024;
        // 使用 seek 创建稀疏文件（不消耗实际磁盘空间）
        {
            use std::io::{Seek, Write};
            let mut f = fs::File::create(&huge_path).unwrap();
            f.seek(std::io::SeekFrom::Start(oversized)).unwrap();
            f.write_all(b"x").unwrap();
        }
        let path_str = huge_path.to_string_lossy().to_string();
        let start = Instant::now();
        let result = {
            let (_tmp, rt) = setup_storage();
            rt.block_on(api::parse_book(path_str.clone()))
        };
        let elapsed = start.elapsed();
        match result {
            Err(_) => {
                result_line(
                    "book_import",
                    "huge_file_rejected",
                    elapsed.as_secs_f64() * 1000.0,
                    "ms",
                );
                println!("  ✓ 超大文件正确拒绝");
            }
            Ok(_) => {
                result_line(
                    "book_import",
                    "huge_file_accepted_UNEXPECTED",
                    elapsed.as_secs_f64() * 1000.0,
                    "ms",
                );
                println!("  ⚠ 超大文件未拒绝！安全检查可能失效");
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 3. 批量导入压测
// ═══════════════════════════════════════════════════════════════

fn stress_batch_import(sample_size: usize) {
    println!("\n=== [3/3] 批量导入压测 ===");

    // 每本书 1MB，N 本批量导入
    for &batch_size in &[5, 20, 50] {
        let tmp_root = TempDir::new().unwrap();
        let base = tmp_root.path().join("batch");
        fs::create_dir_all(&base).unwrap();
        let fixture_size_kb = 1024; // 每本 1MB

        // 生成 N 个合成文件
        let text = generate_chinese_text(fixture_size_kb);
        let paths: Vec<String> = (0..batch_size)
            .map(|i| {
                let p = base.join(format!("book_{}.txt", i));
                fs::write(&p, &text).unwrap();
                p.to_string_lossy().to_string()
            })
            .collect();

        // 批量顺序导入，记录总耗时和每本耗时分布
        let total_samples = measure_n(sample_size.min(3), || {
            let (_tmp, rt) = setup_storage();
            for p in &paths {
                rt.block_on(api::parse_book(black_box(p.clone())))
                    .unwrap();
            }
        });

        let per_book = total_samples.0.as_secs_f64() * 1000.0 / batch_size as f64;
        result_line(
            "batch_import",
            &format!("batch_{}/total_ms", batch_size),
            total_samples.0.as_secs_f64() * 1000.0,
            "ms",
        );
        result_line(
            "batch_import",
            &format!("batch_{}/per_book_ms", batch_size),
            per_book,
            "ms",
        );
        result_line(
            "batch_import",
            &format!("batch_{}/count", batch_size),
            batch_size as f64,
            "books",
        );

        // 清理
        drop(tmp_root);
    }
}

// ═══════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let quick = args.iter().any(|a| a == "--quick");
    let run_pagination = args.iter().any(|a| a == "--pagination");
    let run_import = args.iter().any(|a| a == "--import");
    let run_batch = args.iter().any(|a| a == "--batch");
    let run_pipeline = args.iter().any(|a| a == "--pipeline");

    let select_one = run_pagination || run_import || run_batch || run_pipeline;
    let sample_size = if quick { 3 } else { 10 };

    println!("[STRESS] Rust 引擎压测");
    println!("[STRESS] sample_size={}, quick={}", sample_size, quick);

    if !select_one || run_pagination {
        stress_pagination(sample_size);
    }
    if !select_one || run_import {
        stress_book_import(sample_size);
    }
    if !select_one || run_batch {
        stress_batch_import(sample_size);
    }
    if !select_one || run_pipeline {
        stress_production_pipeline(sample_size);
    }

    println!("\n=== 压测完成 ===");
}
