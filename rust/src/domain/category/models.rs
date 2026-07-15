use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
/// 书籍分类标签
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Category {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub sort_order: i64,
    pub is_system: bool,
}
impl Category {
    /// 创建书籍分类标签
    ///
    /// - `id` 自动生成
    /// - `is_system` 默认为 `false`（用户自定义分类）
    pub fn new(
        name: &str,
        color: &str,
        sort_order: i64,
        description: Option<String>,
        is_system: bool,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.to_string(),
            description,
            color: color.to_string(),
            sort_order,
            is_system,
        }
    }
}
