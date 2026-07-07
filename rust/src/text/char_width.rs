//! 字符宽度查找表
//! 基于 Flutter TextPainter 校准值的字符宽度查询，用于精确文本排版

use crate::domain::types::typeset::TypesetCalibration;

/// 字符宽度查找表
///
/// 基于 Flutter TextPainter 实测校准值，为每个 Unicode 区间提供精确的字符宽度。
/// 使用定长数组 `[f32; 7]`，无堆分配；`char_width()` 标记 `#[inline(always)]`，
/// 确保热路径零函数调用开销。
#[derive(Debug, Clone, Copy)]
pub struct CharWidthTable {
    widths: [f32; 7],
}

impl CharWidthTable {
    /// 从校准数据创建字符宽度查找表
    ///
    /// 根据 Flutter TextPainter 实测的各类字符宽度值，构建定长宽度数组
    pub fn from_calibration(cal: &TypesetCalibration) -> Self {
        Self {
            widths: [
                cal.cjk_width,       // [0] CJK + CJK Ext-A
                cal.ascii_width,     // [1] ASCII
                cal.digit_width,     // [2] 数字
                cal.punct_width,     // [3] CJK 标点 + 全角
                cal.latin_ext_width, // [4] Latin Extended
                cal.other_width,     // [5] fallback
                0.0,                 // [6] reserved
            ],
        }
    }

    pub fn from_optional_calibration(cal: Option<&TypesetCalibration>, font_size_px: f32) -> Self {
        match cal {
            Some(cal) => Self::from_calibration(cal),
            None => {
                let factor = (font_size_px / 16.0).max(0.1);
                Self::from_calibration(&TypesetCalibration::default()).scaled(factor)
            }
        }
    }

    pub fn scaled(&self, factor: f32) -> Self {
        Self {
            widths: self.widths.map(|w| w * factor),
        }
    }

    #[inline(always)]
    pub fn char_width(&self, ch: char) -> f32 {
        // 注意 match 顺序：数字区间是 ASCII 的子集，必须放在 ASCII 之前
        match ch {
            '\u{4E00}'..='\u{9FFF}' | '\u{3400}'..='\u{4DBF}' => self.widths[0],
            '\u{0030}'..='\u{0039}' => self.widths[2],
            '\u{0020}'..='\u{007F}' => self.widths[1],
            '\u{3000}'..='\u{303F}' | '\u{FF00}'..='\u{FFEF}' => self.widths[3],
            '\u{00C0}'..='\u{024F}' => self.widths[4],
            _ => self.widths[5],
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_cal() -> TypesetCalibration {
        TypesetCalibration {
            dpr: 2.0,
            cjk_width: 32.0,
            ascii_width: 19.2,
            digit_width: 19.2,
            punct_width: 32.0,
            latin_ext_width: 22.0,
            other_width: 25.6,
            ..TypesetCalibration::default()
        }
    }

    #[test]
    fn test_cjk_range() {
        let tbl = CharWidthTable::from_calibration(&test_cal());
        assert_eq!(tbl.char_width('中'), 32.0);
        assert_eq!(tbl.char_width('文'), 32.0);
        assert_eq!(tbl.char_width('\u{4E00}'), 32.0);
    }

    #[test]
    fn test_ascii_range() {
        let tbl = CharWidthTable::from_calibration(&test_cal());
        assert_eq!(tbl.char_width('a'), 19.2);
        assert_eq!(tbl.char_width('Z'), 19.2);
        assert_eq!(tbl.char_width(' '), 19.2);
    }

    #[test]
    fn test_digit_range() {
        let tbl = CharWidthTable::from_calibration(&test_cal());
        assert_eq!(tbl.char_width('0'), 19.2);
        assert_eq!(tbl.char_width('9'), 19.2);
    }

    #[test]
    fn test_latin_ext_range() {
        let tbl = CharWidthTable::from_calibration(&test_cal());
        assert_eq!(tbl.char_width('é'), 22.0); // U+00E9
        assert_eq!(tbl.char_width('ñ'), 22.0); // U+00F1
        assert_eq!(tbl.char_width('ü'), 22.0); // U+00FC
        assert_eq!(tbl.char_width('Ō'), 22.0); // U+014C
    }

    #[test]
    fn test_fallback() {
        let tbl = CharWidthTable::from_calibration(&test_cal());
        assert_eq!(tbl.char_width('→'), 25.6); // U+2192 → fallback
        assert_eq!(tbl.char_width('\u{2500}'), 25.6); // box drawing → fallback
    }

    #[test]
    fn test_constant_width_within_range() {
        let tbl = CharWidthTable::from_calibration(&test_cal());
        assert_eq!(tbl.char_width('中'), tbl.char_width('文'));
        assert_eq!(tbl.char_width('a'), tbl.char_width('Z'));
        assert_eq!(tbl.char_width('0'), tbl.char_width('9'));
    }
}
