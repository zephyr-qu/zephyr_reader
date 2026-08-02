// ============================================================
// 文件作用：EPUB 资源路径规范化工具。
//
// 公有类型/函数：
//   - normalize_asset_path() — 折叠路径分量（. / ..）
// ============================================================

//! EPUB 资源路径规范化
//! 供 archive_reader 解析 manifest href 使用。

/// 规范化 archive 内路径：折叠 `.` 与 `..` 分量，返回无前导斜杠的相对路径。
///
/// 例如 `"OEBPS/../mimetype"` → `"mimetype"`，`"text/ch1.xhtml#frag"` 保留原样。
pub fn normalize_asset_path(path: &str) -> String {
    let mut stack: Vec<&str> = Vec::new();
    for part in path.split('/') {
        match part {
            "" | "." => {}
            ".." => {
                stack.pop();
            }
            p => stack.push(p),
        }
    }
    stack.join("/")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_asset_path_collapses_dotdot() {
        assert_eq!(normalize_asset_path("a/./b"), "a/b");
        assert_eq!(normalize_asset_path("a/../b"), "b");
        assert_eq!(normalize_asset_path("a/b/../../c"), "c");
        assert_eq!(normalize_asset_path("OEBPS/../mimetype"), "mimetype");
        assert_eq!(normalize_asset_path("text/ch1.xhtml"), "text/ch1.xhtml");
        assert_eq!(normalize_asset_path(""), "");
    }
}
