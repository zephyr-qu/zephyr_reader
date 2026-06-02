use std::{collections::HashMap, sync::LazyLock};

use regex::Regex;

#[derive(Debug, Clone)]
pub struct CssRule {
    pub selectors: Vec<String>,
    pub declarations: HashMap<String, String>,
}

const CSS_FONT_SIZES: &[(&str, f32)] = &[
    ("xx-small", 9.0),
    ("x-small", 10.0),
    ("small", 13.0),
    ("medium", 16.0),
    ("large", 18.0),
    ("x-large", 24.0),
    ("xx-large", 32.0),
];

type StyleMap = HashMap<String, Vec<CssRule>>;

pub fn build_style_map(rules: &[CssRule]) -> StyleMap {
    let mut map: StyleMap = HashMap::new();

    for rule in rules {
        for selector in &rule.selectors {
            let s = selector.trim();
            if s.is_empty() {
                continue;
            }
            if let Some(tag) = s.strip_prefix('.') {
                map.entry(format!(".{tag}")).or_default().push(rule.clone());
            } else {
                map.entry(s.to_string()).or_default().push(rule.clone());
            }
        }
    }

    map
}

static CSS_RULE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)([^{}]+)\{([^{}]*)\}").unwrap());
static CSS_DECL_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"([\w-]+)\s*:\s*(.*?)\s*(?:;|$)").unwrap());

pub fn parse_css(css: &str) -> Vec<CssRule> {
    let rule_re = &*CSS_RULE_RE;
    let decl_re = &*CSS_DECL_RE;

    let mut rules = Vec::new();

    for cap in rule_re.captures_iter(css) {
        let selector_text = cap[1].trim();
        let body = cap[2].trim();

        let selectors: Vec<String> = selector_text
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        let mut declarations = HashMap::new();
        for dcap in decl_re.captures_iter(body) {
            let name = dcap[1].trim().to_lowercase();
            let value = dcap[2].trim().to_string();
            if !name.is_empty() && !value.is_empty() {
                declarations.insert(name, value);
            }
        }

        for sel in selectors {
            let clean_sel = simplify_selector(&sel);
            if !clean_sel.is_empty() {
                rules.push(CssRule {
                    selectors: vec![clean_sel],
                    declarations: declarations.clone(),
                });
            }
        }
    }

    rules
}

fn simplify_selector(sel: &str) -> String {
    let sel = sel.trim();
    if sel.is_empty() {
        return String::new();
    }

    let parts: Vec<&str> = sel.split_whitespace().collect();
    if parts.len() > 1 {
        return parts.last().unwrap_or(&"").to_string();
    }

    sel.to_string()
}

pub fn resolve_font_size(value: &str, parent_px: f32) -> Option<f32> {
    let value = value.trim().to_lowercase();

    if let Some((_, px)) = CSS_FONT_SIZES.iter().find(|(k, _)| *k == value) {
        return Some(*px);
    }

    if let Some(v) = value.strip_suffix("px") {
        return v.trim().parse::<f32>().ok();
    }

    if let Some(v) = value.strip_suffix("pt") {
        return v.trim().parse::<f32>().ok().map(|pt| pt * 1.333);
    }

    if let Some(v) = value.strip_suffix("em") {
        return v.trim().parse::<f32>().ok().map(|em| em * parent_px);
    }

    if let Some(v) = value.strip_suffix("rem") {
        return v.trim().parse::<f32>().ok().map(|rem| rem * 16.0);
    }

    if let Some(v) = value.strip_suffix('%') {
        return v
            .trim()
            .parse::<f32>()
            .ok()
            .map(|pct| parent_px * pct / 100.0);
    }

    None
}

pub fn resolve_color(value: &str) -> Option<String> {
    let value = value.trim().to_lowercase();

    if value.starts_with('#') {
        let hex = value.trim_start_matches('#');
        if hex.len() == 3 || hex.len() == 6 {
            return Some(value);
        }
    }

    if value.starts_with("rgb") {
        static RGB_RE: LazyLock<Regex> =
            LazyLock::new(|| Regex::new(r"rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)").unwrap());
        let re = &*RGB_RE;
        if let Some(cap) = re.captures(&value) {
            let r = cap[1].parse::<u8>().ok()?;
            let g = cap[2].parse::<u8>().ok()?;
            let b = cap[3].parse::<u8>().ok()?;
            return Some(format!("#{r:02x}{g:02x}{b:02x}"));
        }
    }

    let named: &[(&str, &str)] = &[
        ("black", "#000000"),
        ("white", "#ffffff"),
        ("red", "#ff0000"),
        ("blue", "#0000ff"),
        ("green", "#008000"),
        ("gray", "#808080"),
        ("grey", "#808080"),
        ("maroon", "#800000"),
        ("purple", "#800080"),
        ("navy", "#000080"),
        ("teal", "#008080"),
        ("olive", "#808000"),
        ("silver", "#c0c0c0"),
        ("lime", "#00ff00"),
        ("yellow", "#ffff00"),
        ("aqua", "#00ffff"),
        ("fuchsia", "#ff00ff"),
        ("orange", "#ffa500"),
        ("pink", "#ffc0cb"),
        ("brown", "#a52a2a"),
    ];

    if let Some((_, hex)) = named.iter().find(|(k, _)| *k == value.as_str()) {
        return Some(hex.to_string());
    }

    None
}

/// Extract CSS from HTML `<style>` tags
pub fn extract_inline_css(html: &str) -> String {
    static STYLE_RE: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"(?si)<style[^>]*>(.*?)</style>").unwrap());
    let re = &*STYLE_RE;
    re.captures_iter(html)
        .map(|cap| cap[1].trim().to_string())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_css_single_rule() {
        let css = "p { color: red; font-size: 16px; }";
        let rules = parse_css(css);
        assert_eq!(rules.len(), 1);
        assert_eq!(rules[0].selectors[0], "p");
        assert_eq!(rules[0].declarations.get("color").unwrap(), "red");
    }

    #[test]
    fn test_parse_css_multiple_rules() {
        let css = "h1 { color: blue; } p { font-size: 14px; }";
        let rules = parse_css(css);
        assert_eq!(rules.len(), 2);
    }

    #[test]
    fn test_resolve_color_hex() {
        assert_eq!(resolve_color("#ff0000"), Some("#ff0000".to_string()));
        assert_eq!(resolve_color("red"), Some("#ff0000".to_string()));
        assert_eq!(resolve_color("rgb(255, 0, 0)"), Some("#ff0000".to_string()));
        assert_eq!(resolve_color("unknown"), None);
    }
}

pub fn resolve_float(value: &str, parent_px: f32) -> Option<f32> {
    let value = value.trim().to_lowercase();

    if let Some(v) = value.strip_suffix("px") {
        return v.trim().parse::<f32>().ok();
    }
    if let Some(v) = value.strip_suffix("em") {
        return v.trim().parse::<f32>().ok().map(|em| em * parent_px);
    }
    if let Some(v) = value.strip_suffix('%') {
        return v
            .trim()
            .parse::<f32>()
            .ok()
            .map(|pct| parent_px * pct / 100.0);
    }
    if value == "normal" {
        return Some(1.2);
    }

    value.parse::<f32>().ok()
}
