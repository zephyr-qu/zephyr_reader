use rust_lib_zephyr_reader::domain::{RichTextSpan, SpanStyle};
use rust_lib_zephyr_reader::text::parse_html_to_rich_text;

#[test]
fn test_parse_empty_html() {
    let result = parse_html_to_rich_text("");
    assert!(result.is_ok());
    let paragraphs = result.unwrap();
    assert!(paragraphs.is_empty());
}

#[test]
fn test_parse_empty_paragraph() {
    let result = parse_html_to_rich_text("<p></p>").unwrap();
    assert!(
        result.is_empty(),
        "empty <p> should not produce a paragraph"
    );

    let result = parse_html_to_rich_text("<p>   </p>").unwrap();
    assert!(
        result.is_empty(),
        "whitespace-only <p> should not produce a paragraph"
    );
}

#[test]
fn test_parse_simple_text() {
    let html = "<p>Hello World</p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let para = &result[0];
    assert!(!para.is_image);
    assert!(!para.spans.is_empty());
    let text = para.full_text();
    assert!(text.contains("Hello World"));
    assert!(para.spans[0].is_plain());
}

#[test]
fn test_parse_multiple_paragraphs() {
    let html = "<p>First</p><p>Second</p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 2);
    assert!(result[0].full_text().contains("First"));
    assert!(result[1].full_text().contains("Second"));
}

#[test]
fn test_parse_with_styles() {
    let html = "<p><b>Bold</b> and <i>Italic</i></p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let spans = &result[0].spans;
    assert!(spans.len() >= 2, "expected at least 2 formatted spans");

    // Find the Bold span
    let bold_span = spans
        .iter()
        .find(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _)));
    assert!(bold_span.is_some(), "expected a Bold span");
    assert!(bold_span.unwrap().text().contains("Bold"));

    // Find the Italic span
    let italic_span = spans
        .iter()
        .find(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Italic, _)));
    assert!(italic_span.is_some(), "expected an Italic span");
    assert!(italic_span.unwrap().text().contains("Italic"));
}

#[test]
fn test_parse_mixed_style_plain() {
    // Ensure plain text between styled segments is preserved
    let html = "<p>Start <b>middle</b> end</p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let text = result[0].full_text();
    assert!(text.contains("Start"));
    assert!(text.contains("middle"));
    assert!(text.contains("end"));
}

#[test]
fn test_parse_heading() {
    let html = "<h1>Title</h1>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let para = &result[0];
    assert!(para.is_heading);
    assert_eq!(para.heading_level, 1);
    assert!(para.full_text().contains("Title"));

    let html = "<h2>Subtitle</h2>";
    let result = parse_html_to_rich_text(html).unwrap();
    let para = &result[0];
    assert!(para.is_heading);
    assert_eq!(para.heading_level, 2);

    let html = "<h3>Section</h3>";
    let result = parse_html_to_rich_text(html).unwrap();
    let para = &result[0];
    assert!(para.is_heading);
    assert_eq!(para.heading_level, 3);
}

#[test]
fn test_parse_link() {
    let html = r#"<p><a href="https://example.com">Link</a></p>"#;
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let spans = &result[0].spans;
    let link_span = spans
        .iter()
        .find(|s| matches!(s, RichTextSpan::Link { .. }));
    assert!(link_span.is_some(), "expected a Link span");
    if let RichTextSpan::Link { data, url } = link_span.unwrap() {
        assert!(data.text.contains("Link"));
        assert_eq!(url, "https://example.com");
    }
}

#[test]
fn test_parse_image() {
    let html = r#"<p><img src="image.png" alt="test"/></p>"#;
    let result = parse_html_to_rich_text(html).unwrap();
    // img inside <p> produces an independent image paragraph
    assert_eq!(result.len(), 1);
    let para = &result[0];
    assert!(para.is_image);
    assert_eq!(para.image_src.as_deref(), Some("image.png"));
    assert_eq!(para.image_alt.as_deref(), Some("test"));
}

#[test]
fn test_parse_image_outside_paragraph() {
    let html = r#"<img src="cover.jpg" alt="cover"/>"#;
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let para = &result[0];
    assert!(para.is_image);
    assert_eq!(para.image_src.as_deref(), Some("cover.jpg"));
    assert_eq!(para.image_alt.as_deref(), Some("cover"));
}

#[test]
fn test_parse_nested_tags() {
    // Nested <b><i> produces a Bold span (outer tag wins); the BoldItalic
    // variant is not emitted by the current implementation.
    let html = "<p><b><i>Bold Italic</i></b></p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let spans = &result[0].spans;
    let bold_span = spans
        .iter()
        .find(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _)));
    assert!(
        bold_span.is_some(),
        "expected a Bold span from nested <b><i>"
    );
    assert!(bold_span.unwrap().text().contains("Bold Italic"));
}

#[test]
fn test_parse_bold_via_strong() {
    let html = "<p><strong>Strong emphasis</strong></p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let bold_span = result[0]
        .spans
        .iter()
        .find(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _)));
    assert!(bold_span.is_some(), "expected a Bold span from <strong>");
    assert!(bold_span.unwrap().text().contains("Strong emphasis"));
}

#[test]
fn test_parse_italic_via_em() {
    let html = "<p><em>Emphasis</em></p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let italic_span = result[0]
        .spans
        .iter()
        .find(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Italic, _)));
    assert!(italic_span.is_some(), "expected an Italic span from <em>");
    assert!(italic_span.unwrap().text().contains("Emphasis"));
}

#[test]
fn test_parse_line_break() {
    let html = "<p>Line1<br/>Line2</p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let text = result[0].full_text();
    assert!(text.contains("Line1"));
    assert!(text.contains("Line2"));
}

#[test]
fn test_parse_list_item() {
    let html = "<li>Item text</li>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let text = result[0].full_text();
    assert!(text.contains("Item text"));
}

#[test]
fn test_parse_heading_within_paragraph() {
    // Headings produce standalone heading paragraphs
    let html = "<p>intro</p><h1>Chapter</h1><p>body</p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 3);
    assert!(!result[0].is_heading);
    assert!(result[1].is_heading);
    assert_eq!(result[1].heading_level, 1);
    assert!(!result[2].is_heading);
}

#[test]
fn test_parse_full_text_aggregation() {
    let html = "<p>Hello <b>beautiful</b> world</p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let text = result[0].full_text();
    assert!(text.contains("Hello"));
    assert!(text.contains("beautiful"));
    assert!(text.contains("world"));
}

#[test]
fn test_parse_image_without_alt() {
    let html = r#"<img src="photo.jpg"/>"#;
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let para = &result[0];
    assert!(para.is_image);
    assert_eq!(para.image_src.as_deref(), Some("photo.jpg"));
    // alt should be empty string (default) which makes Some("")
    assert_eq!(para.image_alt.as_deref(), Some(""));
}

#[test]
fn test_parse_multiple_images() {
    let html = r#"<img src="a.png"/><img src="b.png"/>"#;
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 2);
    assert!(result[0].is_image);
    assert!(result[1].is_image);
}

#[test]
fn test_parse_style_with_multiple_spans() {
    let html = "<p><b>A</b>, <b>B</b>, and <i>C</i></p>";
    let result = parse_html_to_rich_text(html).unwrap();
    assert_eq!(result.len(), 1);
    let bold_spans: Vec<_> = result[0]
        .spans
        .iter()
        .filter(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _)))
        .collect();
    assert_eq!(bold_spans.len(), 2, "expected two Bold spans");
    assert!(bold_spans[0].text().contains("A"));
    assert!(bold_spans[1].text().contains("B"));
}
