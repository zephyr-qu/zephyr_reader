//! YAML frontmatter extraction for Markdown files

/// Extract title from YAML frontmatter or first H1 heading
pub fn extract_title(content: &str) -> Option<String> {
    if let Some(frontmatter) = extract_frontmatter(content) {
        for line in frontmatter.lines() {
            let line = line.trim();
            if let Some(val) = line.strip_prefix("title:").or(line.strip_prefix("title：")) {
                let val = val.trim().trim_matches('"').trim_matches('\'').to_string();
                if !val.is_empty() {
                    return Some(val);
                }
            }
        }
    }

    // Fallback: first H1 heading
    for line in content.lines() {
        let trimmed = line.trim();
        if let Some(heading) = trimmed.strip_prefix("# ") {
            return Some(heading.trim().to_string());
        }
    }

    None
}

/// Extract author from YAML frontmatter
pub fn extract_author(content: &str) -> Option<String> {
    if let Some(frontmatter) = extract_frontmatter(content) {
        for line in frontmatter.lines() {
            let line = line.trim();
            if let Some(val) = line
                .strip_prefix("author:")
                .or(line.strip_prefix("author："))
            {
                let val = val.trim().trim_matches('"').trim_matches('\'').to_string();
                if !val.is_empty() {
                    return Some(val);
                }
            }
        }
    }
    None
}

/// Extract YAML frontmatter block between `---` delimiters
fn extract_frontmatter(content: &str) -> Option<&str> {
    let content = content.trim();
    if !content.starts_with("---") {
        return None;
    }

    let end = content[3..].find("\n---")?;
    Some(&content[3..3 + end])
}
