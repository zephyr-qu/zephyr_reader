mod common;

#[test]
fn test_temp_file_exists() {
    let (_dir, path) = common::create_temp_file("check.txt", "test");
    assert!(std::path::Path::new(&path).exists());
}

#[test]
fn test_empty_file_creation() {
    let (_dir, path) = common::create_temp_file("empty.txt", "");
    assert!(std::path::Path::new(&path).exists());

    let content = std::fs::read_to_string(&path).unwrap();
    assert_eq!(content, "");
}

#[test]
fn test_utf8_content() {
    let (_dir, path) = common::create_temp_file("utf8.txt", "中文内容 🎉");
    let content = std::fs::read_to_string(&path).unwrap();
    assert_eq!(content, "中文内容 🎉");
}
