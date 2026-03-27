//! Rust 引擎性能基准测试
//!
//! 使用 criterion 库进行性能测试，生成 HTML 报告。
//!
//! # 运行方法
//!
//! ```bash
//! cargo bench
//! ```
//!
//! 报告位于 `target/criterion/report/index.html`

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use rust_lib_zephyr_reader::{api, ffi::TypesetConfig};
use std::fs;
use std::hint::black_box;
use std::time::Duration;

/// 生成测试文本（中文）
fn generate_chinese_text(size_kb: usize) -> String {
    let base_text = "这是一段测试文本，用于性能基准测试。";
    let repetitions = (size_kb * 1024) / base_text.len();
    base_text.repeat(repetitions)
}

/// 生成测试文本（英文）
fn generate_english_text(size_kb: usize) -> String {
    let base_text = "This is a test text for performance benchmarking. ";
    let repetitions = (size_kb * 1024) / base_text.len();
    base_text.repeat(repetitions)
}

/// 基准测试：TXT 文件解析
fn bench_txt_parsing(c: &mut Criterion) {
    let mut group = c.benchmark_group("txt_parsing");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    for size in [1, 10, 50].iter() {
        let text = generate_chinese_text(*size);
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join(format!("bench_txt_{}kb.txt", size));
        fs::write(&file_path, &text).unwrap();

        group.throughput(Throughput::Bytes(text.len() as u64));
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}kb", size)),
            &file_path,
            |b, path| {
                b.iter(|| {
                    let _ = api::parse_txt_file(black_box(path.to_string_lossy().to_string()));
                })
            },
        );

        fs::remove_file(file_path).ok();
    }
    for size in [1, 10, 50].iter() {
        let text = generate_english_text(*size);
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join(format!("bench_txt_{}kb.txt", size));
        fs::write(&file_path, &text).unwrap();

        group.throughput(Throughput::Bytes(text.len() as u64));
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}kb", size)),
            &file_path,
            |b, path| {
                b.iter(|| {
                    let _ = api::parse_txt_file(black_box(path.to_string_lossy().to_string()));
                })
            },
        );

        fs::remove_file(file_path).ok();
    }

    group.finish();
}

/// 基准测试：排版处理
fn bench_typesetting(c: &mut Criterion) {
    let mut group = c.benchmark_group("typesetting");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    let config = TypesetConfig {
        page_width: 1080,
        page_height: 1920,
        font_size: 18,
        line_spacing: 1.5,
        letter_spacing: 0.0,
        paragraph_spacing: 1.0,
        first_line_indent: 2,
        language: rust_lib_zephyr_reader::ffi::LanguageType::Auto,
        enable_hyphenation: false,
        hyphenation_language: Some("en".to_string()),
    };

    for size in [1, 5, 10].iter() {
        let text = generate_chinese_text(*size);

        group.throughput(Throughput::Bytes(text.len() as u64));
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}kb", size)),
            &text,
            |b, text| {
                b.iter(|| {
                    let _ = api::typeset_text(
                        black_box(text.clone()),
                        black_box("auto".to_string()),
                        black_box(config.clone()),
                    );
                })
            },
        );
    }

    group.finish();
}

/// 基准测试：分页处理
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
        first_line_indent: 2,
        language: rust_lib_zephyr_reader::ffi::LanguageType::Auto,
        enable_hyphenation: false,
        hyphenation_language: Some("en".to_string()),
    };

    for size in [1, 5, 10].iter() {
        let text = generate_chinese_text(*size);

        group.throughput(Throughput::Bytes(text.len() as u64));
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}kb", size)),
            &text,
            |b, text| {
                b.iter(|| {
                    let _ = api::paginate_all_content(
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

/// 基准测试：文件大小获取
fn bench_file_size(c: &mut Criterion) {
    let mut group = c.benchmark_group("file_size");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(10));

    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("bench_file_size.txt");
    fs::write(&file_path, generate_chinese_text(10)).unwrap();

    group.bench_function("get_file_size", |b| {
        b.iter(|| {
            let _ = api::get_file_size(black_box(file_path.to_string_lossy().to_string()));
        })
    });

    fs::remove_file(file_path).ok();
    group.finish();
}

/// 基准测试：文件分块读取
fn bench_chunk_read(c: &mut Criterion) {
    let mut group = c.benchmark_group("chunk_read");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(10));

    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("bench_chunk_read.txt");
    fs::write(&file_path, generate_chinese_text(100)).unwrap();

    group.bench_function("read_1kb_chunk", |b| {
        b.iter(|| {
            let _ = api::read_file_chunk(
                black_box(file_path.to_string_lossy().to_string()),
                black_box(0),
                black_box(1024),
            );
        })
    });

    group.bench_function("read_10kb_chunk", |b| {
        b.iter(|| {
            let _ = api::read_file_chunk(
                black_box(file_path.to_string_lossy().to_string()),
                black_box(0),
                black_box(10 * 1024),
            );
        })
    });

    fs::remove_file(file_path).ok();
    group.finish();
}

criterion_group!(
    benches,
    bench_txt_parsing,
    bench_typesetting,
    bench_pagination,
    bench_file_size,
    bench_chunk_read,
);

criterion_main!(benches);
