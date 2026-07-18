// ============================================================
// 文件作用：Parser registry — Format-to-parser mapping via free functions。
//
// 公有类型/函数：
//   - parser_for_format() — 根据 BookFormat 返回对应的 Parser
//   - format_from_extension() — 根据文件扩展名返回 BookFormat
//   - parser_for_file() — 根据文件路径返回对应的 Parser
// ============================================================

//! Parser registry
//! Format-to-parser mapping via free functions

use crate::domain::AppError;
use crate::domain::book::BookFormat;

use crate::parser::Parser;

/// 根据 BookFormat 返回对应的 Parser
pub fn parser_for_format(format: BookFormat) -> Parser {
    match format {
        BookFormat::Txt => Parser::Txt(crate::parser::txt::TxtParser),
        BookFormat::Epub => Parser::Epub(crate::parser::epub::EpubParser),
    }
}

/// 根据文件扩展名返回对应的 BookFormat
pub fn format_from_extension(ext: &str) -> Result<BookFormat, AppError> {
    let bytes = ext.as_bytes();
    if bytes.len() <= 8 {
        let mut buf = [0u8; 8];
        for (i, &b) in bytes.iter().enumerate() {
            buf[i] = b.to_ascii_lowercase();
        }
        match &buf[..bytes.len()] {
            b"txt" | b"text" => Ok(BookFormat::Txt),
            b"epub" => Ok(BookFormat::Epub),
            _ => Err(AppError::UnsupportedFormat {
                format: format!("Unknown format: {}", ext),
            }),
        }
    } else {
        Err(AppError::UnsupportedFormat {
            format: format!("Unknown format: {}", ext),
        })
    }
}

/// 根据文件路径返回对应的 Parser
pub fn parser_for_file(path: &str) -> Result<Parser, AppError> {
    let ext = std::path::Path::new(path)
        .extension()
        .and_then(|ext| ext.to_str())
        .ok_or_else(|| AppError::UnsupportedFormat {
            format: "Cannot identify file extension".to_string(),
        })?;
    let format = format_from_extension(ext)?;
    Ok(parser_for_format(format))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parser_for_format() {
        assert!(matches!(parser_for_format(BookFormat::Txt), Parser::Txt(_)));
        assert!(matches!(
            parser_for_format(BookFormat::Epub),
            Parser::Epub(_)
        ));
    }

    #[test]
    fn test_format_from_extension() {
        assert!(matches!(format_from_extension("txt"), Ok(BookFormat::Txt)));
        assert!(matches!(format_from_extension("text"), Ok(BookFormat::Txt)));
        assert!(matches!(format_from_extension("TXT"), Ok(BookFormat::Txt)));
        assert!(matches!(
            format_from_extension("epub"),
            Ok(BookFormat::Epub)
        ));
        assert!(matches!(
            format_from_extension("EPUB"),
            Ok(BookFormat::Epub)
        ));
        assert!(format_from_extension("pdf").is_err());
        assert!(format_from_extension("md").is_err());
        assert!(format_from_extension("unknown").is_err());
    }

    #[test]
    fn test_parser_for_file() {
        assert!(matches!(parser_for_file("book.txt"), Ok(Parser::Txt(_))));
        assert!(matches!(parser_for_file("book.epub"), Ok(Parser::Epub(_))));
        assert!(parser_for_file("book.pdf").is_err());
        assert!(parser_for_file("book.md").is_err());
        assert!(parser_for_file("book.unknown").is_err());
        assert!(parser_for_file("").is_err());
    }

    #[test]
    fn test_parser_name() {
        let parser = parser_for_format(BookFormat::Txt);
        assert_eq!(parser.name(), "TXT Parser");
        let parser = parser_for_format(BookFormat::Epub);
        assert_eq!(parser.name(), "EPUB Parser");
    }

    #[test]
    fn test_supported_formats() {
        let parser = parser_for_format(BookFormat::Txt);
        assert!(parser.supported_formats().contains(&"txt"));
    }
}
