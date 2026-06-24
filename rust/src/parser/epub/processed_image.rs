//! EPUB 图片 decode + resize → 字节或本地缓存路径（M4.2）。

use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

use image::imageops::FilterType;
use image::ImageFormat as ImgFormat;
use xxhash_rust::xxh3::xxh3_64;

use super::asset_registry::EpubAssetRegistry;
use super::unzip::EpubFile;
use crate::domain::AppError;

fn image_cache_root() -> Result<PathBuf, AppError> {
    let base = dirs::cache_dir().ok_or_else(|| AppError::InternalError {
        reason: "system cache directory unavailable".into(),
    })?;
    let dir = base.join("zephyr_reader").join("epub_images");
    fs::create_dir_all(&dir).map_err(|e| AppError::FileWriteError {
        path: dir.to_string_lossy().into(),
        details: e.to_string().into(),
    })?;
    Ok(dir)
}

fn cache_path(root: &Path, file_path: &str, asset_id: &str, max_width_px: u32) -> PathBuf {
    let key = format!("{file_path}\0{asset_id}\0{max_width_px}");
    let hash = xxh3_64(key.as_bytes());
    root.join(format!("{hash:016x}.jpg"))
}

/// 从 EPUB manifest 读取图片原始字节（与 scroll 富文本路径同一 lookup 逻辑）。
pub fn read_epub_image_bytes(file_path: &str, asset_id: &str) -> Result<Vec<u8>, AppError> {
    if asset_id.is_empty() {
        return Err(AppError::InvalidInput {
            reason: "asset_id must not be empty".into(),
        });
    }
    let mut epub = EpubFile::open(file_path)?;
    let registry = EpubAssetRegistry::from_manifest(epub.resources());
    registry
        .read_bytes(&mut epub, asset_id)
        .ok_or_else(|| AppError::NotFound {
            entity: format!("epub image asset {asset_id}"),
        })
}

fn encode_resized_image(img: image::DynamicImage, max_width_px: u32) -> Result<Vec<u8>, AppError> {
    let processed = if img.width() > max_width_px {
        img.resize(max_width_px, u32::MAX, FilterType::Triangle)
    } else {
        img
    };

    let mut jpeg_buf = Vec::new();
    if processed
        .write_to(&mut Cursor::new(&mut jpeg_buf), ImgFormat::Jpeg)
        .is_ok()
        && !jpeg_buf.is_empty()
    {
        return Ok(jpeg_buf);
    }

    let mut png_buf = Vec::new();
    processed
        .write_to(&mut Cursor::new(&mut png_buf), ImgFormat::Png)
        .map_err(|e| AppError::InternalError {
            reason: format!("image encode failed: {e}").into(),
        })?;
    Ok(png_buf)
}

/// 读取 EPUB 图片，按需缩放，返回 JPEG/PNG 字节供 Flutter `Image.memory` 使用。
///
/// 若 `image` crate 无法解码（如部分 CMYK JPEG），回退为 EPUB 内原始字节，
/// 由 Flutter 引擎解码（与 scroll 模式一致）。
pub fn get_processed_epub_image_bytes(
    file_path: &str,
    asset_id: &str,
    max_width_px: u32,
) -> Result<Vec<u8>, AppError> {
    let max_width_px = max_width_px.max(1);
    let bytes = read_epub_image_bytes(file_path, asset_id)?;

    match image::load_from_memory(&bytes) {
        Ok(img) => encode_resized_image(img, max_width_px),
        Err(e) => {
            tracing::warn!(
                asset_id = %asset_id,
                error = %e,
                "image crate decode failed; returning raw EPUB bytes for Flutter decoder"
            );
            Ok(bytes)
        }
    }
}

/// 读取 EPUB manifest 图片，按需缩放并写入磁盘缓存，返回本地文件路径。
pub fn get_processed_epub_image(
    file_path: &str,
    asset_id: &str,
    max_width_px: u32,
) -> Result<String, AppError> {
    if asset_id.is_empty() {
        return Err(AppError::InvalidInput {
            reason: "asset_id must not be empty".into(),
        });
    }
    let max_width_px = max_width_px.max(1);
    let cache_root = image_cache_root()?;
    let out_path = cache_path(&cache_root, file_path, asset_id, max_width_px);
    if out_path.is_file() {
        return Ok(out_path.to_string_lossy().into());
    }

    let processed_bytes = get_processed_epub_image_bytes(file_path, asset_id, max_width_px)?;

    if let Some(parent) = out_path.parent() {
        fs::create_dir_all(parent).map_err(|e| AppError::FileWriteError {
            path: parent.to_string_lossy().into(),
            details: e.to_string().into(),
        })?;
    }

    let is_jpeg = processed_bytes.len() >= 2
        && processed_bytes[0] == 0xFF
        && processed_bytes[1] == 0xD8;
    let write_path = if is_jpeg {
        out_path.clone()
    } else {
        out_path.with_extension("png")
    };

    fs::write(&write_path, &processed_bytes).map_err(|e| AppError::FileWriteError {
        path: write_path.to_string_lossy().into(),
        details: format!("image cache write failed for {asset_id}: {e}").into(),
    })?;

    Ok(write_path.to_string_lossy().into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn empty_asset_id_rejected() {
        let err = get_processed_epub_image("/tmp/x.epub", "", 800).unwrap_err();
        assert!(matches!(err, AppError::InvalidInput { .. }));
    }

    #[test]
    fn load_image_bytes_from_medium_epub_if_present() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../test/fixtures/medium.epub");
        if !path.exists() {
            return;
        }
        let path_str = path.to_string_lossy();
        let epub = EpubFile::open(&path_str).expect("open medium.epub");
        let image_id = epub
            .resources()
            .iter()
            .find(|(_, item)| item.mime.to_ascii_lowercase().starts_with("image/"))
            .map(|(id, _)| id.clone());
        let Some(asset_id) = image_id else {
            eprintln!("SKIP: medium.epub has no image resources");
            return;
        };

        let bytes = read_epub_image_bytes(&path_str, &asset_id)
            .unwrap_or_else(|e| panic!("read_epub_image_bytes failed for {asset_id}: {e}"));
        assert!(!bytes.is_empty(), "image bytes should not be empty");

        let processed = get_processed_epub_image_bytes(&path_str, &asset_id, 400)
            .unwrap_or_else(|e| panic!("get_processed_epub_image_bytes failed: {e}"));
        assert!(!processed.is_empty(), "processed bytes should not be empty");
    }
}
