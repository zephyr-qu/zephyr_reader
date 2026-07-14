// ============================================================
// 文件作用：排版配置定义
//
// 公有类型/函数：
//   - enum LanguageType — 语言类型（Chinese / English / Mixed / Auto）
//   - struct TypesetConfig — 排版配置（页面尺寸、字体、间距等）
//   - TypesetConfig::validate() — 校验配置合法性
//   - TypesetConfig::config_hash() — 生成缓存键哈希（xxh3）
// ============================================================

use serde::{Deserialize, Serialize};

// ==================== 语言类型 ====================

/// 语言类型
/// 用于排版引擎识别文本语言，以应用不同的排版规则
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Hash)]
pub enum LanguageType {
    /// 中文
    Chinese,
    /// 英文
    English,
    /// 中英混合
    Mixed,
    /// 自动检测
    Auto,
}

// ==================== 排版配置 ====================

/// 排版配置
/// 控制页面尺寸、字体、间距等排版参数
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypesetConfig {
    /// 页面宽度（像素）
    pub page_width: i32,
    /// 页面高度（像素）
    pub page_height: i32,
    /// 字体大小（像素）
    pub font_size: i32,
    /// 行间距（倍数）
    pub line_spacing: f32,
    /// 字间距（像素）
    pub letter_spacing: f32,
    /// 段落间距（相对于 font_size 的倍数）。
    pub paragraph_spacing: f32,
    /// 首行缩进（字符数）
    pub first_line_indent: u8,
    /// 中西文自动间距比例（相对于 font_size）。
    pub auto_space_ratio: f32,
    /// 标点挤压 — 连续 CJK 标点占用更少水平空间
    pub punctuation_squeeze: bool,
    /// 语言类型
    pub language: LanguageType,
    /// 字体系列名（用于校准关联）
    pub font_family: String,
}

impl TypesetConfig {
    /// 验证配置是否合法
    pub fn validate(&self) -> Result<(), crate::domain::AppError> {
        let min_page_width = 100;
        let max_page_width = 10000;
        let min_page_height = 100;
        let max_page_height = 10000;
        let min_font_size = 8;
        let max_font_size = 100;
        let min_line_spacing = 0.5f32;
        let max_line_spacing = 5.0f32;
        let min_letter_spacing = -10.0f32;
        let max_letter_spacing = 10.0f32;
        let min_paragraph_spacing = 0.0f32;
        let max_paragraph_spacing = 10.0f32;
        let min_auto_space_ratio = 0.0f32;
        let max_auto_space_ratio = 1.0f32;
        let max_first_line_indent: u8 = 10;

        if self.page_width < min_page_width || self.page_width > max_page_width {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "page width must be between {} and {} px, got: {}",
                    min_page_width, max_page_width, self.page_width
                ),
            });
        }
        if self.page_height < min_page_height || self.page_height > max_page_height {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "page height must be between {} and {} px, got: {}",
                    min_page_height, max_page_height, self.page_height
                ),
            });
        }
        if self.font_size < min_font_size || self.font_size > max_font_size {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "font size must be between {} and {} px, got: {}",
                    min_font_size, max_font_size, self.font_size
                ),
            });
        }
        if self.auto_space_ratio < min_auto_space_ratio
            || self.auto_space_ratio > max_auto_space_ratio
        {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "auto space ratio must be between {} and {}, got: {}",
                    min_auto_space_ratio, max_auto_space_ratio, self.auto_space_ratio
                ),
            });
        }
        if self.line_spacing < min_line_spacing || self.line_spacing > max_line_spacing {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "line spacing must be between {} and {}, got: {}",
                    min_line_spacing, max_line_spacing, self.line_spacing
                ),
            });
        }
        if self.letter_spacing < min_letter_spacing || self.letter_spacing > max_letter_spacing {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "letter spacing must be between {} and {}, got: {}",
                    min_letter_spacing, max_letter_spacing, self.letter_spacing
                ),
            });
        }
        if self.paragraph_spacing < min_paragraph_spacing
            || self.paragraph_spacing > max_paragraph_spacing
        {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "paragraph spacing must be between {} and {}, got: {}",
                    min_paragraph_spacing, max_paragraph_spacing, self.paragraph_spacing
                ),
            });
        }
        if self.first_line_indent > max_first_line_indent {
            return Err(crate::domain::AppError::TypesetConfigError {
                reason: format!(
                    "first line indent must be between 0 and {} chars, got: {}",
                    max_first_line_indent, self.first_line_indent
                ),
            });
        }
        Ok(())
    }

    /// 生成确定的缓存键哈希 (xxh3)
    ///
    /// 使用 xxhash 计算配置的 64 位哈希值，用于 KV 缓存键。
    pub fn config_hash(&self) -> u64 {
        use xxhash_rust::xxh3::xxh3_64;
        // 分页/断行算法版本；逻辑变更时递增以使缓存失效。
        const LAYOUT_ALGORITHM_VERSION: u32 = 14;

        let mut bytes = Vec::with_capacity(64);
        bytes.extend_from_slice(&self.page_width.to_le_bytes());
        bytes.extend_from_slice(&self.page_height.to_le_bytes());
        bytes.extend_from_slice(&self.font_size.to_le_bytes());
        bytes.extend_from_slice(&self.line_spacing.to_le_bytes());
        bytes.extend_from_slice(&self.letter_spacing.to_le_bytes());
        bytes.extend_from_slice(&self.paragraph_spacing.to_le_bytes());
        bytes.extend_from_slice(&self.auto_space_ratio.to_le_bytes());
        bytes.push(self.first_line_indent);
        bytes.push(self.punctuation_squeeze as u8);
        bytes.push(self.language as u8);
        bytes.extend_from_slice(self.font_family.as_bytes());
        bytes.extend_from_slice(&LAYOUT_ALGORITHM_VERSION.to_le_bytes());
        xxh3_64(&bytes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_typeset_config_validate_invalid() {
        let config = TypesetConfig {
            page_width: 1080,
            page_height: 1920,
            font_size: 200,
            line_spacing: 1.8,
            letter_spacing: 0.0,
            paragraph_spacing: 0.0,
            auto_space_ratio: 0.25,
            first_line_indent: 2,
            punctuation_squeeze: true,
            language: LanguageType::Auto,
            font_family: "Noto Sans SC".into(),
        };
        let result = config.validate();
        assert!(result.is_err());
    }

    #[test]
    fn test_config_hash_deterministic() {
        let config = TypesetConfig {
            page_width: 1080,
            page_height: 1920,
            font_size: 18,
            line_spacing: 1.8,
            letter_spacing: 0.0,
            paragraph_spacing: 0.0,
            auto_space_ratio: 0.25,
            first_line_indent: 2,
            punctuation_squeeze: true,
            language: LanguageType::Auto,
            font_family: "Noto Sans SC".into(),
        };
        let hash1 = config.config_hash();
        for _ in 0..100 {
            assert_eq!(hash1, config.config_hash());
        }
    }

    #[test]
    fn test_config_hash_changes_with_fields() {
        let base = TypesetConfig {
            page_width: 1080,
            page_height: 1920,
            font_size: 18,
            line_spacing: 1.8,
            letter_spacing: 0.0,
            paragraph_spacing: 0.0,
            auto_space_ratio: 0.25,
            first_line_indent: 2,
            punctuation_squeeze: true,
            language: LanguageType::Auto,
            font_family: "Noto Sans SC".into(),
        };
        let base_hash = base.config_hash();

        let different_font = TypesetConfig {
            font_size: 20,
            ..base.clone()
        };
        assert_ne!(
            base_hash,
            different_font.config_hash(),
            "font_size change must affect hash"
        );

        let different_width = TypesetConfig {
            page_width: 800,
            ..base.clone()
        };
        assert_ne!(
            base_hash,
            different_width.config_hash(),
            "page_width change must affect hash"
        );

        let different_spacing = TypesetConfig {
            line_spacing: 2.0,
            ..base.clone()
        };
        assert_ne!(
            base_hash,
            different_spacing.config_hash(),
            "line_spacing change must affect hash"
        );

        let different_ident = TypesetConfig {
            first_line_indent: 0,
            ..base.clone()
        };
        assert_ne!(
            base_hash,
            different_ident.config_hash(),
            "first_line_indent change must affect hash"
        );

        let different_lang = TypesetConfig {
            language: LanguageType::English,
            ..base.clone()
        };
        assert_ne!(
            base_hash,
            different_lang.config_hash(),
            "language change must affect hash"
        );

        let different_auto_space = TypesetConfig {
            auto_space_ratio: 0.5,
            ..base.clone()
        };
        assert_ne!(
            base_hash,
            different_auto_space.config_hash(),
            "auto_space_ratio change must affect hash"
        );
    }
}
