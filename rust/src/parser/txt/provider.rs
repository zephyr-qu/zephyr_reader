// ============================================================
// 文件作用：TXT 按需内容提供器 — TxtContentProvider 基于 mmap 实现
//           零拷贝的按需文本范围读取。
//
// 公有类型/函数：
//   - TxtContentProvider — TXT 文件按需内容提供器
//     - open() — 打开并映射 TXT 文件
//     - read_text_range() — 读取指定字节范围文本
//     - content_length() / format() — 内容长度和格式
//
// 私有函数：
//   - scan_newlines() — 扫描换行符位置
//   - find_utf8_char_start() / find_utf8_char_end() — UTF-8 字符边界查找
//   - safe_slice_bounds() — 对齐切片边界
// ============================================================

//! TXT 按需内容提供器
//!
//! `TxtContentProvider` 基于 mmap 实现零拷贝的按需文本范围读取。
//! 针对 UTF-8 使用字符边界回退，针对 GBK/Big5 等多字节编码使用行对齐切片。

use std::fs::File;

use encoding_rs::{Encoding, UTF_8};
use memmap2::Mmap;

use crate::domain::AppError;
use crate::parser::provider::ChapterContentProvider;
use crate::storage::models::BookFormat;

/// 内存映射文件最大大小（100MB）
const MMAP_MAX_SIZE: u64 = 100 * 1024 * 1024;

/// 切片策略
enum SliceStrategy {
    /// UTF-8 编码：char_indices 回退 ≤3 字节找到合法字符边界
    Utf8,
    /// GBK/Big5 等多字节编码：对齐到最近换行符避免截断字符
    LineAligned {
        /// 预扫描的换行符字节偏移表
        line_offsets: Vec<u64>,
    },
}

/// TXT 文件按需内容提供器
pub struct TxtContentProvider {
    mmap: Mmap,
    encoding: &'static Encoding,
    slice_strategy: SliceStrategy,
}

impl TxtContentProvider {
    /// 打开并映射 TXT 文件
    ///
    /// 在 `open()` 中完成：
    /// 1. mmap 文件映射（零拷贝）
    /// 2. 编码检测（仅前 4KB）
    /// 3. 根据编码构建切片策略
    pub fn open(file_path: &str) -> Result<Self, AppError> {
        let file = File::open(file_path).map_err(|e| AppError::FileReadError {
            path: file_path.into(),
            details: e.to_string(),
        })?;

        let metadata = file.metadata().map_err(|e| AppError::FileReadError {
            path: file_path.into(),
            details: e.to_string(),
        })?;

        let file_len = metadata.len();
        if file_len > MMAP_MAX_SIZE {
            return Err(AppError::FileReadError {
                path: file_path.into(),
                details: format!(
                    "file too large ({}MB), exceeds limit {}MB",
                    file_len / 1024 / 1024,
                    MMAP_MAX_SIZE / 1024 / 1024
                ),
            });
        }
        // SAFETY: 文件以只读方式打开（File::open），映射为只读 Mmap；
        // 文件在映射生命周期内不会被写入或截断（调用方保证）。
        // memmap2 在 Drop 时自动解除映射。
        let mmap = unsafe {
            Mmap::map(&file).map_err(|e| AppError::FileReadError {
                path: file_path.into(),
                details: e.to_string(),
            })?
        };
        if mmap.is_empty() {
            return Ok(Self {
                mmap,
                encoding: UTF_8,
                slice_strategy: SliceStrategy::Utf8,
            });
        }

        // 编码检测（仅前 4096 字节）
        let detect_len = mmap.len().min(4096);
        let encoding = crate::parser::txt::decode::detect_encoding_from_bytes(&mmap[..detect_len])?;

        // 根据编码决定切片策略
        let slice_strategy = if encoding == UTF_8 {
            SliceStrategy::Utf8
        } else {
            let line_offsets = Self::scan_newlines(&mmap);
            SliceStrategy::LineAligned { line_offsets }
        };

        Ok(Self {
            mmap,
            encoding,
            slice_strategy,
        })
    }

    /// 扫描 mmap 中所有换行符的字节位置
    fn scan_newlines(mmap: &[u8]) -> Vec<u64> {
        mmap.iter()
            .enumerate()
            .filter(|(_, b)| **b == b'\n')
            .map(|(i, _)| i as u64)
            .collect()
    }

    /// 找到 ≤pos 的最近 UTF-8 字符边界（向后回退最多 3 字节）
    fn find_utf8_char_start(&self, pos: u64) -> u64 {
        let pos = pos as usize;
        let len = self.mmap.len();
        if pos >= len {
            return len as u64;
        }
        // 如果已经是字符边界（首位字节不是 0x80-0xBF），直接返回
        if self.mmap[pos] & 0xC0 != 0x80 {
            return pos as u64;
        }
        // 向后回退最多 3 字节找到序列头
        for i in 1..=3 {
            let check = pos.saturating_sub(i);
            if self.mmap[check] & 0xC0 != 0x80 {
                return check as u64;
            }
        }
        // 回退失败，保留原始位置（decode 时会自动替换无效序列）
        pos as u64
    }

    /// 找到 ≥pos 的最近 UTF-8 字符边界（向前推进最多 3 字节）
    fn find_utf8_char_end(&self, pos: u64) -> u64 {
        let pos = pos as usize;
        let len = self.mmap.len();
        if pos >= len {
            return len as u64;
        }
        if self.mmap[pos] & 0xC0 != 0x80 {
            return pos as u64;
        }
        for i in 1..=3 {
            let check = (pos + i).min(len);
            if check >= len {
                return len as u64;
            }
            if self.mmap[check] & 0xC0 != 0x80 {
                return check as u64;
            }
        }
        pos as u64
    }

    /// 根据切片策略将 (start, end) 对齐到安全边界
    fn safe_slice_bounds(&self, start: u64, end: u64) -> (u64, u64) {
        match &self.slice_strategy {
            SliceStrategy::Utf8 => {
                let s = self.find_utf8_char_start(start);
                let e = self.find_utf8_char_end(end);
                (s, e)
            }
            SliceStrategy::LineAligned { line_offsets } => {
                if line_offsets.is_empty() {
                    return (0, self.mmap.len() as u64);
                }

                // 二分查找最近的换行符边界
                let s_idx = line_offsets.partition_point(|&o| o < start);
                let e_idx = line_offsets.partition_point(|&o| o <= end);

                let safe_start = if s_idx > 0 {
                    // 换行符后第一个字节
                    line_offsets[s_idx - 1] + 1
                } else {
                    0
                };

                let safe_end = if e_idx < line_offsets.len() {
                    // 换行符本身（包含换行使得 decode 时不会产生多余字符）
                    line_offsets[e_idx]
                } else {
                    self.mmap.len() as u64
                };

                (safe_start, safe_end)
            }
        }
    }
}

impl ChapterContentProvider for TxtContentProvider {
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError> {
        let file_len = self.mmap.len() as u64;
        let start = start.min(file_len);
        let end = end.min(file_len);

        if start >= end {
            return Ok(String::new());
        }

        let (safe_start, safe_end) = self.safe_slice_bounds(start, end);

        // 边界扩展后仍约束在文件范围内
        let safe_start = safe_start.min(file_len);
        let safe_end = safe_end.min(file_len);
        if safe_start >= safe_end {
            return Ok(String::new());
        }

        let slice = &self.mmap[safe_start as usize..safe_end as usize];

        if self.encoding == UTF_8 {
            match std::str::from_utf8(slice) {
                Ok(s) => Ok(s.to_string()),
                Err(_) => {
                    let (decoded, _, _) = self.encoding.decode(slice);
                    Ok(decoded.into_owned())
                }
            }
        } else {
            let (decoded, _, _) = self.encoding.decode(slice);
            Ok(decoded.into_owned())
        }
    }

    fn content_length(&self) -> u64 {
        self.mmap.len() as u64
    }

    fn format(&self) -> BookFormat {
        BookFormat::Txt
    }
}
