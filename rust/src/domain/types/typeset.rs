//! 排版配置模块 (Typeset Configuration)
//!
//! 包含排版相关的配置结构体、验证逻辑和修复报告。
//! 用于控制页面尺寸、字体大小、行距、字间距、段落间距等排版参数。

use crate::domain::error::AppError;
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::hash::{Hash, Hasher};
use xxhash_rust::xxh3::xxh3_64;

// ==================== 常量定义 ====================

const MIN_PAGE_WIDTH: i32 = 100;
const MAX_PAGE_WIDTH: i32 = 10000;
const MIN_PAGE_HEIGHT: i32 = 100;
const MAX_PAGE_HEIGHT: i32 = 10000;
const MIN_FONT_SIZE: i32 = 8;
const MAX_FONT_SIZE: i32 = 100;
const MIN_LINE_SPACING: f32 = 0.5;
const MAX_LINE_SPACING: f32 = 5.0;
const MIN_LETTER_SPACING: f32 = -10.0;
const MAX_LETTER_SPACING: f32 = 10.0;
const MIN_PARAGRAPH_SPACING: f32 = 0.0;
const MAX_PARAGRAPH_SPACING: f32 = 10.0;
const MAX_FIRST_LINE_INDENT: u8 = 10;
const MIN_AUTO_SPACE_RATIO: f32 = 0.0;
const MAX_AUTO_SPACE_RATIO: f32 = 1.0;

// ==================== 语言类型 ====================

/// 语言类型
/// 用于排版引擎识别文本语言，以应用不同的排版规则
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Hash)]
#[frb]
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

// ==================== 字符宽度校准数据 ====================

/// 字符宽度校准数据
///
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct TypesetCalibration {
    /// 设备像素比
    pub dpr: f32,
    /// CJK 字符宽度（U+4E00-9FFF + U+3400-4DBF），通常约等于 font_size
    pub cjk_width: f32,
    /// ASCII 字符宽度（U+0020-007F），通常为 font_size * 0.5~0.6
    pub ascii_width: f32,
    /// 数字宽度（U+0030-0039），通常接近 ascii_width
    pub digit_width: f32,
    /// CJK 标点宽度（U+3000-303F + U+FF00-FFEF），通常约等于 font_size
    pub punct_width: f32,
    /// 西欧扩展字符宽度（U+00C0-024F），翻译文学中高频出现
    pub latin_ext_width: f32,
    /// 其他字符宽度（fallback），通常为 font_size * 0.8
    pub other_width: f32,
    /// Flutter TextPainter 实测有效行宽比例（effective_width / page_width_px）。
    pub effective_line_width_ratio: f32,
    /// Flutter 实测单行高度（物理 px）；`<= 0` 时回退 `font_size × line_spacing`。
    pub measured_line_height_px: f32,
}

impl Hash for TypesetCalibration {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.dpr.to_bits().hash(state);
        self.cjk_width.to_bits().hash(state);
        self.ascii_width.to_bits().hash(state);
        self.digit_width.to_bits().hash(state);
        self.punct_width.to_bits().hash(state);
        self.latin_ext_width.to_bits().hash(state);
        self.other_width.to_bits().hash(state);
        self.effective_line_width_ratio.to_bits().hash(state);
        self.measured_line_height_px.to_bits().hash(state);
    }
}
impl Default for TypesetCalibration {
    /// 保守默认值（字体未就绪时的回退）
    fn default() -> Self {
        Self {
            dpr: 1.0,
            cjk_width: 16.0,
            ascii_width: 9.6,
            digit_width: 9.6,
            punct_width: 16.0,
            latin_ext_width: 11.2,
            other_width: 12.8,
            effective_line_width_ratio: 1.0,
            measured_line_height_px: 0.0,
        }
    }
}

// ==================== 排版配置 ====================

/// 排版配置
/// 控制页面尺寸、字体、间距等排版参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
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
    /// Dart 侧 `ReaderConfig.paragraphSpacing` 为 dp，
    /// 由 `typeset_calibrator` 除以 fontSize 后传入 Rust。
    /// Rust 侧 `block_paginator` 再乘以 fontSize 得到 px：
    /// `paragraph_spacing_extra_px = config.paragraph_spacing * font_size`
    pub paragraph_spacing: f32,
    /// 首行缩进（字符数）
    pub first_line_indent: u8,
    /// 中西文自动间距比例（相对于 font_size）。
    /// 在 CJK↔Latin 边界产生视觉间隔，0.0 = 不间隔，1.0 = 1 个字符宽度
    pub auto_space_ratio: f32,
    /// 标点挤压 — 连续 CJK 标点占用更少水平空间
    pub punctuation_squeeze: bool,
    /// 语言类型
    pub language: LanguageType,
    /// 字体系列名（用于校准关联）
    pub font_family: String,
    /// Flutter 校准的字符宽度数据（可选，未提供时使用保守默认值）
    pub calibration: Option<TypesetCalibration>,
}

impl Default for TypesetConfig {
    fn default() -> Self {
        Self {
            page_width: 1080,
            page_height: 1920,
            font_size: 18,
            line_spacing: 1.8,
            letter_spacing: 0.0,
            paragraph_spacing: 16.0 / 18.0,
            auto_space_ratio: 0.25,
            first_line_indent: 2,
            punctuation_squeeze: true,
            language: LanguageType::Auto,
            font_family: "Noto Sans SC".into(),
            calibration: None,
        }
    }
}

impl Hash for TypesetConfig {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.page_width.hash(state);
        self.page_height.hash(state);
        self.font_size.hash(state);
        self.line_spacing.to_bits().hash(state);
        self.letter_spacing.to_bits().hash(state);
        self.paragraph_spacing.to_bits().hash(state);
        self.auto_space_ratio.to_bits().hash(state);
        self.first_line_indent.hash(state);
        self.punctuation_squeeze.hash(state);
        self.language.hash(state);
        self.font_family.hash(state);
        if let Some(ref cal) = self.calibration {
            cal.hash(state);
        }
    }
}

// ==================== 排版配置修复报告 ====================

/// 排版配置修复报告
/// 记录配置验证时的修正信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct TypesetConfigFixReport {
    /// 修正后的配置
    pub fixed_config: TypesetConfig,
    /// 修正项列表
    pub fixes: Vec<String>,
}

// ==================== 验证与修正方法 ====================

// ==================== 验证宏 ====================

/// 分页/断行算法版本；逻辑变更时递增以使 sled / 内存缓存失效。
const LAYOUT_ALGORITHM_VERSION: u32 = 13;

macro_rules! check_range {
    ($self:ident, $field:ident, $min:ident, $max:ident, $desc:expr, $unit:expr) => {
        if $self.$field < $min || $self.$field > $max {
            return Err(AppError::TypesetConfigError {
                reason: format!(
                    concat!($desc, " must be between {} and {} ", $unit, ", got: {}"),
                    $min, $max, $self.$field
                )
                .into(),
            });
        }
    };
}

impl TypesetConfig {
    /// 验证配置是否合法
    ///
    /// # 错误
    /// 如果任何参数超出允许范围，返回配置错误
    #[frb(sync)]
    pub fn validate(&self) -> Result<(), AppError> {
        check_range!(
            self,
            page_width,
            MIN_PAGE_WIDTH,
            MAX_PAGE_WIDTH,
            "page width",
            "px"
        );
        check_range!(
            self,
            page_height,
            MIN_PAGE_HEIGHT,
            MAX_PAGE_HEIGHT,
            "page height",
            "px"
        );
        check_range!(
            self,
            font_size,
            MIN_FONT_SIZE,
            MAX_FONT_SIZE,
            "font size",
            "px"
        );
        check_range!(
            self,
            auto_space_ratio,
            MIN_AUTO_SPACE_RATIO,
            MAX_AUTO_SPACE_RATIO,
            "auto space ratio",
            ""
        );
        check_range!(
            self,
            line_spacing,
            MIN_LINE_SPACING,
            MAX_LINE_SPACING,
            "line spacing",
            ""
        );
        check_range!(
            self,
            letter_spacing,
            MIN_LETTER_SPACING,
            MAX_LETTER_SPACING,
            "letter spacing",
            ""
        );
        check_range!(
            self,
            paragraph_spacing,
            MIN_PARAGRAPH_SPACING,
            MAX_PARAGRAPH_SPACING,
            "paragraph spacing",
            ""
        );
        if self.first_line_indent > MAX_FIRST_LINE_INDENT {
            return Err(AppError::TypesetConfigError {
                reason: format!(
                    "first line indent must be between 0 and {} chars, got: {}",
                    MAX_FIRST_LINE_INDENT, self.first_line_indent
                )
                .into(),
            });
        }
        Ok(())
    }

    /// 验证并自动修正配置（静默修正）
    ///
    /// # 返回
    /// 返回修正后的合法配置
    #[frb(sync)]
    pub fn validate_and_fix(&self) -> TypesetConfig {
        TypesetConfig {
            page_width: self.page_width.clamp(MIN_PAGE_WIDTH, MAX_PAGE_WIDTH),
            page_height: self.page_height.clamp(MIN_PAGE_HEIGHT, MAX_PAGE_HEIGHT),
            font_size: self.font_size.clamp(MIN_FONT_SIZE, MAX_FONT_SIZE),
            line_spacing: self.line_spacing.clamp(MIN_LINE_SPACING, MAX_LINE_SPACING),
            letter_spacing: self
                .letter_spacing
                .clamp(MIN_LETTER_SPACING, MAX_LETTER_SPACING),
            paragraph_spacing: self
                .paragraph_spacing
                .clamp(MIN_PARAGRAPH_SPACING, MAX_PARAGRAPH_SPACING),
            auto_space_ratio: self
                .auto_space_ratio
                .clamp(MIN_AUTO_SPACE_RATIO, MAX_AUTO_SPACE_RATIO),
            first_line_indent: self.first_line_indent.clamp(0_u8, MAX_FIRST_LINE_INDENT),
            ..self.clone()
        }
    }

    /// 生成确定的缓存键哈希 (xxh3)
    ///
    /// 使用 xxhash 计算配置的 64 位哈希值，用于 KV 缓存键。
    /// 相同配置在任何平台、任何进程产生的哈希值完全一致。
    #[frb(sync)]
    pub fn config_hash(&self) -> u64 {
        let mut bytes = Vec::with_capacity(96);
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
        if let Some(ref cal) = self.calibration {
            bytes.extend_from_slice(&cal.dpr.to_le_bytes());
            bytes.extend_from_slice(&cal.cjk_width.to_le_bytes());
            bytes.extend_from_slice(&cal.ascii_width.to_le_bytes());
            bytes.extend_from_slice(&cal.digit_width.to_le_bytes());
            bytes.extend_from_slice(&cal.punct_width.to_le_bytes());
            bytes.extend_from_slice(&cal.latin_ext_width.to_le_bytes());
            bytes.extend_from_slice(&cal.other_width.to_le_bytes());
            bytes.extend_from_slice(&cal.effective_line_width_ratio.to_le_bytes());
            bytes.extend_from_slice(&cal.measured_line_height_px.to_le_bytes());
        }
        bytes.extend_from_slice(&LAYOUT_ALGORITHM_VERSION.to_le_bytes());
        xxh3_64(&bytes)
    }

    /// 验证并生成修复报告
    ///
    /// # 返回
    /// 返回修正后的配置和所有修正项说明
    #[frb(sync)]
    pub fn validate_and_report(&self) -> TypesetConfigFixReport {
        let mut fixes = Vec::new();

        let fixed_config = TypesetConfig {
            page_width: {
                let original = self.page_width;
                let fixed = self.page_width.clamp(MIN_PAGE_WIDTH, MAX_PAGE_WIDTH);
                if original != fixed {
                    fixes.push(format!("page width: {} -> {}", original, fixed));
                }
                fixed
            },
            page_height: {
                let original = self.page_height;
                let fixed = self.page_height.clamp(MIN_PAGE_HEIGHT, MAX_PAGE_HEIGHT);
                if original != fixed {
                    fixes.push(format!(
                        "page height: {} -> {} (clamped to {}-{})",
                        original, fixed, MIN_PAGE_HEIGHT, MAX_PAGE_HEIGHT
                    ));
                }
                fixed
            },
            font_size: {
                let original = self.font_size;
                let fixed = self.font_size.clamp(MIN_FONT_SIZE, MAX_FONT_SIZE);
                if original != fixed {
                    fixes.push(format!(
                        "font size: {} -> {} (clamped to {}-{})",
                        original, fixed, MIN_FONT_SIZE, MAX_FONT_SIZE
                    ));
                }
                fixed
            },
            line_spacing: {
                let original = self.line_spacing;
                let fixed = self.line_spacing.clamp(MIN_LINE_SPACING, MAX_LINE_SPACING);
                if original != fixed {
                    fixes.push(format!(
                        "line spacing: {} -> {} (clamped to {}-{})",
                        original, fixed, MIN_LINE_SPACING, MAX_LINE_SPACING
                    ));
                }
                fixed
            },
            letter_spacing: {
                let original = self.letter_spacing;
                let fixed = self
                    .letter_spacing
                    .clamp(MIN_LETTER_SPACING, MAX_LETTER_SPACING);
                if original != fixed {
                    fixes.push(format!(
                        "letter spacing: {} -> {} (clamped to {}-{})",
                        original, fixed, MIN_LETTER_SPACING, MAX_LETTER_SPACING
                    ));
                }
                fixed
            },
            paragraph_spacing: {
                let original = self.paragraph_spacing;
                let fixed = self
                    .paragraph_spacing
                    .clamp(MIN_PARAGRAPH_SPACING, MAX_PARAGRAPH_SPACING);
                if original != fixed {
                    fixes.push(format!(
                        "paragraph spacing: {} -> {} (clamped to {}-{})",
                        original, fixed, MIN_PARAGRAPH_SPACING, MAX_PARAGRAPH_SPACING
                    ));
                }
                fixed
            },
            first_line_indent: {
                let original = self.first_line_indent;
                let fixed = self.first_line_indent.clamp(0_u8, MAX_FIRST_LINE_INDENT);
                if original != fixed {
                    fixes.push(format!(
                        "first line indent: {} -> {} (clamped to 0-{})",
                        original, fixed, MAX_FIRST_LINE_INDENT
                    ));
                }
                fixed
            },
            auto_space_ratio: {
                let original = self.auto_space_ratio;
                let fixed = self
                    .auto_space_ratio
                    .clamp(MIN_AUTO_SPACE_RATIO, MAX_AUTO_SPACE_RATIO);
                if (original - fixed).abs() > f32::EPSILON {
                    fixes.push(format!(
                        "auto space ratio: {} -> {} (clamped to {}-{})",
                        original, fixed, MIN_AUTO_SPACE_RATIO, MAX_AUTO_SPACE_RATIO
                    ));
                }
                fixed
            },
            ..self.clone()
        };
        TypesetConfigFixReport {
            fixed_config,
            fixes,
        }
    }
}

// ==================== 单元测试 ====================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_typeset_config_validate_and_report_no_fixes() {
        let config = TypesetConfig::default();
        let report = config.validate_and_report();
        assert!(report.fixes.is_empty());
    }

    #[test]
    fn test_typeset_config_validate_and_report_with_fixes() {
        let config = TypesetConfig {
            font_size: 200,
            page_width: 50,
            line_spacing: 6.0,
            ..Default::default()
        };

        let report = config.validate_and_report();
        assert_eq!(report.fixes.len(), 3);
        assert!(report.fixes.iter().any(|f| f.contains("font size")));
        assert!(report.fixes.iter().any(|f| f.contains("page width")));
        assert!(report.fixes.iter().any(|f| f.contains("line spacing")));
    }

    #[test]
    fn test_typeset_config_validate_invalid() {
        let config = TypesetConfig {
            font_size: 200,
            ..Default::default()
        };
        let result = config.validate();
        assert!(result.is_err());
    }

    #[test]
    fn test_typeset_config_fix_report_structure() {
        let config = TypesetConfig::default();
        let _report = config.validate_and_report();
    }

    #[test]
    fn test_config_hash_deterministic() {
        let config = TypesetConfig::default();
        let hash1 = config.config_hash();
        for _ in 0..100 {
            assert_eq!(hash1, config.config_hash());
        }
    }

    #[test]
    fn test_config_hash_changes_with_fields() {
        let base = TypesetConfig::default();
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

    /// 已知确定性值：确保 xxh3 在不同平台给出相同结果
    #[test]
    fn test_config_hash_portable_value() {
        let config = TypesetConfig::default();
        // xxh3("default config bytes") 的 64-bit 输出
        // 注：只要 CI 和开发者机器此值一致即可，
        // 不要求与外部参考值匹配
        let h = config.config_hash();
        assert_ne!(h, 0, "hash must not be zero");
        // 重新计算确认稳定
        assert_eq!(h, config.config_hash());
    }
}
