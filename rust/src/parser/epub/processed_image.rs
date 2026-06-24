//! EPUB 图片 decode + resize → 本地缓存路径（M4.2）。

use std::fs;
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

    let mut epub = EpubFile::open(file_path)?;
    let registry = EpubAssetRegistry::from_manifest(epub.resources());
    let bytes = registry
        .read_bytes(&mut epub, asset_id)
        .ok_or_else(|| AppError::NotFound {
            entity: format!("epub image asset {asset_id}"),
        })?;

    let img = image::load_from_memory(&bytes).map_err(|e| AppError::InternalError {
        reason: format!("image decode failed for {asset_id}: {e}").into(),
    })?;

    let processed = if img.width() > max_width_px {
        img.resize(max_width_px, u32::MAX, FilterType::Triangle)
    } else {
        img
    };

    if let Some(parent) = out_path.parent() {
        fs::create_dir_all(parent).map_err(|e| AppError::FileWriteError {
            path: parent.to_string_lossy().into(),
            details: e.to_string().into(),
        })?;
    }

    // 统一 JPEG 缓存，减小体积。
    processed
        .save_with_format(&out_path, ImgFormat::Jpeg)
        .map_err(|e| AppError::FileWriteError {
            path: out_path.to_string_lossy().into(),
            details: e.to_string().into(),
        })?;

    Ok(out_path.to_string_lossy().into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_asset_id_rejected() {
        let err = get_processed_epub_image("/tmp/x.epub", "", 800).unwrap_err();
        assert!(matches!(err, AppError::InvalidInput { .. }));
    }
}
