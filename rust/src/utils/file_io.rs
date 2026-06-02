use crate::domain::AppError;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};

const MMAP_THRESHOLD: usize = 1024 * 1024;

/// 读取文本块（UTF-8），适用于显示文本内容
pub fn read_text_chunk(
    file_path: &str,
    start_pos: i64,
    chunk_size: i64,
) -> Result<String, AppError> {
    let (file, file_size) = open_and_get_size(file_path)?;
    let start = start_pos as usize;
    let chunk = chunk_size as usize;
    let actual_chunk = calculate_actual_chunk(start, chunk, file_size);
    if actual_chunk == 0 {
        return Ok(String::new());
    }
    if file_size > MMAP_THRESHOLD {
        read_text_mmap(file, file_size, start, actual_chunk)
    } else {
        read_text_io(file, start, actual_chunk)
    }
}

fn open_and_get_size(file_path: &str) -> Result<(File, usize), AppError> {
    let file =
        File::open(file_path).map_err(|e| AppError::file_read_error(file_path, e.to_string()))?;
    let file_size = file
        .metadata()
        .map_err(|e| {
            AppError::file_read_error(file_path, format!("Failed to get file size: {}", e))
        })?
        .len() as usize;
    Ok((file, file_size))
}

fn calculate_actual_chunk(start_pos: usize, chunk_size: usize, file_size: usize) -> usize {
    if start_pos >= file_size {
        return 0;
    }
    chunk_size.min(file_size - start_pos)
}

fn read_text_mmap(
    file: File,
    file_size: usize,
    start: usize,
    chunk_size: usize,
) -> Result<String, AppError> {
    let lookback = std::cmp::min(start, 3);
    let mmap_start = start - lookback;
    let mmap_len = std::cmp::min(chunk_size + lookback, file_size - mmap_start);

    if mmap_len == 0 {
        return Ok(String::new());
    }

    // SAFETY: 内存映射是只读的，文件在此期间不会被写入或截断（调用方保证）。
    // memmap2 在 Drop 时自动解除映射，无需手动管理。
    let mmap = unsafe {
        memmap2::MmapOptions::new()
            .len(mmap_len)
            .offset(mmap_start as u64)
            .map(&file)
            .map_err(|e| {
                AppError::file_read_error("(memory map)", format!("Memory map failed: {}", e))
            })?
    };

    let offset = mmap[lookback..]
        .iter()
        .position(|&b| (b & 0xC0) != 0x80)
        .unwrap_or(0);
    let (content, _encoding, had_errors) = encoding_rs::UTF_8.decode(&mmap[lookback + offset..]);

    if had_errors {
        tracing::warn!(
            "Decoding errors encountered in text chunk at offset {}",
            start
        );
    }

    Ok(content.into_owned())
}

fn read_text_io(mut file: File, start: usize, chunk_size: usize) -> Result<String, AppError> {
    let lookback = std::cmp::min(start, 3);
    let read_start = start - lookback;
    let read_len = chunk_size + lookback;

    file.seek(SeekFrom::Start(read_start as u64))
        .map_err(|e| AppError::file_read_error("(io)", format!("Seek failed: {}", e)))?;

    let mut buffer = vec![0u8; read_len];
    let bytes_read = file
        .read(&mut buffer)
        .map_err(|e| AppError::file_read_error("(io)", format!("Read failed: {}", e)))?;

    buffer.truncate(bytes_read);

    let truncate_to = buffer[lookback..]
        .iter()
        .position(|&b| (b & 0xC0) != 0x80)
        .map(|pos| lookback + pos)
        .unwrap_or(buffer.len());

    let (content, _encoding, had_errors) = encoding_rs::UTF_8.decode(&buffer[truncate_to..]);

    if had_errors {
        tracing::warn!(
            "Decoding errors encountered in text chunk at offset {}",
            start
        );
    }

    Ok(content.into_owned())
}

/// 获取文件大小
pub async fn get_file_size(file_path: &str) -> Result<i64, AppError> {
    let metadata = tokio::fs::metadata(file_path)
        .await
        .map_err(|e| AppError::file_read_error(file_path, e.to_string()))?;
    Ok(metadata.len() as i64)
}

/// 读取文件文本块（带 UTF-8 安全边界对齐）
///
/// 内部使用 `read_text_chunk` 同步读取，通过 `spawn_blocking` 避免阻塞 async 运行时。
pub async fn read_file_chunk(
    file_path: &str,
    start_pos: i64,
    chunk_size: i64,
) -> Result<String, AppError> {
    if start_pos < 0 {
        return Err(AppError::invalid_input(
            "read start position cannot be negative",
        ));
    }
    if chunk_size <= 0 {
        return Err(AppError::invalid_input("read size must be positive"));
    }
    const MAX_CHUNK_SIZE: i64 = 10 * 1024 * 1024;
    if chunk_size > MAX_CHUNK_SIZE {
        return Err(AppError::invalid_input(format!(
            "single read size cannot exceed {} MB",
            MAX_CHUNK_SIZE / 1024 / 1024
        )));
    }

    let file_path = file_path.to_string();
    tokio::task::spawn_blocking(move || read_text_chunk(&file_path, start_pos, chunk_size))
        .await
        .map_err(|e| AppError::task_panic("file io", e.to_string()))?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_read_text_chunk() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_chunk.txt");

        let content = "Hello, World! This is a test file.";
        std::fs::write(&file_path, content).unwrap();

        let chunk = read_text_chunk(file_path.to_str().unwrap(), 0, 5).unwrap();
        assert_eq!(chunk, "Hello");

        let chunk = read_text_chunk(file_path.to_str().unwrap(), 7, 5).unwrap();
        assert_eq!(chunk, "World");

        let _ = std::fs::remove_file(file_path);
    }

    #[test]
    fn test_read_chunk_with_chinese() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_chinese.txt");

        let content = "这是一段中文测试文本";
        std::fs::write(&file_path, content).unwrap();

        let chunk = read_text_chunk(file_path.to_str().unwrap(), 0, 9).unwrap();
        assert_eq!(chunk, "这是一");

        let _ = std::fs::remove_file(file_path);
    }

    #[test]
    fn test_read_chunk_mid_character() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_mid_char.txt");

        // "你" = E4 BD A0, "好" = E5 A5 BD
        // 从 "你" 的第二字节开始读，应该能正确跳过不完整的开头
        let content = "你好世界";
        std::fs::write(&file_path, content).unwrap();

        // 从偏移 1 开始读（"你" 的中间），应该正确跳过不完整的 "你"
        let chunk = read_text_chunk(file_path.to_str().unwrap(), 1, 5).unwrap();
        // 期望：跳过不完整的"你"，读到"好"
        assert_eq!(chunk, "好");

        let _ = std::fs::remove_file(file_path);
    }

    #[tokio::test]
    async fn test_get_file_size_normal() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_size.txt");
        std::fs::write(&file_path, b"Hello World").unwrap();
        let size = get_file_size(file_path.to_str().unwrap()).await.unwrap();
        assert_eq!(size, 11);
        let _ = std::fs::remove_file(file_path);
    }

    #[tokio::test]
    async fn test_read_file_chunk_rejects_negative_start() {
        let result = read_file_chunk("dummy.txt", -1, 100).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_read_file_chunk_rejects_zero_chunk() {
        let result = read_file_chunk("dummy.txt", 0, 0).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_read_file_chunk_rejects_oversized_chunk() {
        let result = read_file_chunk("dummy.txt", 0, 11 * 1024 * 1024).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_read_file_chunk_normal() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_chunk_async.txt");
        std::fs::write(&file_path, b"Hello World").unwrap();
        let chunk = read_file_chunk(file_path.to_str().unwrap(), 0, 5)
            .await
            .unwrap();
        assert_eq!(chunk, "Hello");
        let _ = std::fs::remove_file(file_path);
    }
}
