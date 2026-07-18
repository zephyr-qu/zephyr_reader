// ============================================================
// 文件作用：从 PNG/JPEG 头部读取 intrinsic 尺寸
//
// 公有类型/函数：
//   - read_image_dimensions() — 从字节头部解析 PNG/JPEG intrinsic 尺寸
//   - resolve_image_dimensions() — 遍历 IR image block 填充 intrinsic 尺寸
// ============================================================

//! 图片 intrinsic 尺寸读取
//! 从 PNG/JPEG 头部轻量解析，无需完整解码

use super::provider::EpubContentProvider;
use crate::pipeline::{ReaderChapterIr, ReaderIrBlockKind};

/// 从 PNG/JPEG 头部读取 intrinsic 尺寸（轻量，无完整解码）。
pub fn read_image_dimensions(bytes: &[u8]) -> Option<(u32, u32)> {
    // PNG: 检查 8-byte signature + IHDR chunk
    if bytes.len() >= 24
        && bytes[0] == 0x89
        && bytes[1] == 0x50
        && bytes[2] == 0x4E
        && bytes[3] == 0x47
    {
        let w = u32::from_be_bytes([bytes[16], bytes[17], bytes[18], bytes[19]]);
        let h = u32::from_be_bytes([bytes[20], bytes[21], bytes[22], bytes[23]]);
        if w > 0 && h > 0 {
            return Some((w, h));
        }
    }

    // JPEG: 扫描 SOF0/SOF1/SOF2 marker
    if bytes.len() >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
        let mut i = 2usize;
        while i + 9 < bytes.len() {
            if bytes[i] != 0xFF {
                i += 1;
                continue;
            }
            let marker = bytes[i + 1];
            if marker == 0xD9 || marker == 0xDA {
                break;
            }
            if i + 3 > bytes.len() {
                break;
            }
            let len = ((bytes[i + 2] as usize) << 8) | (bytes[i + 3] as usize);
            if len < 2 {
                break;
            }
            if matches!(marker, 0xC0..=0xC2) {
                if i + 9 > bytes.len() {
                    break;
                }
                let h = ((bytes[i + 5] as u32) << 8) | (bytes[i + 6] as u32);
                let w = ((bytes[i + 7] as u32) << 8) | (bytes[i + 8] as u32);
                if w > 0 && h > 0 {
                    return Some((w, h));
                }
            }
            i += 2 + len;
        }
    }

    None
}

/// 遍历章 IR 中所有 Image block，从 EPUB 读取原始字节并解析 intrinsic 尺寸。
pub fn resolve_image_dimensions(ir: &mut ReaderChapterIr, provider: &EpubContentProvider) {
    for block in &mut ir.blocks {
        if block.kind != ReaderIrBlockKind::Image {
            continue;
        }
        if block.image_intrinsic_width.is_some() && block.image_intrinsic_height.is_some() {
            continue;
        }
        if let Some(ref asset_id) = block.image_asset_id
            && let Some(data) = provider.read_resource_bytes(asset_id)
            && let Some((w, h)) = read_image_dimensions(&data)
        {
            block.image_intrinsic_width = Some(w);
            block.image_intrinsic_height = Some(h);
            tracing::debug!(
                "[get_chapter_content_ir] image {} intrinsic={}×{}",
                asset_id,
                w,
                h
            );
        }
    }
}
