#!/usr/bin/env python3
"""修复 api/mod.rs 文件，移除 SqliteStorage 依赖"""

import re

file_path = r'F:\App\zephyr_reader\rust\src\api\mod.rs'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 修改 import - 移除 SqliteStorage，添加 InMemoryStorage
content = content.replace(
    'use crate::storage::{ProgressStorage, SqliteStorage};',
    'use crate::storage::{ProgressStorage, InMemoryStorage};'
)

# 2. 修改 STORAGE 静态变量类型
old_storage = '''static STORAGE: OnceCell<Mutex<SqliteStorage>> = OnceCell::new();'''
new_storage = '''static STORAGE: OnceCell<Arc<dyn ProgressStorage>> = OnceCell::new();'''
content = content.replace(old_storage, new_storage)

# 3. 修改 import 中的 Mutex - 保留但添加 Arc
content = content.replace(
    'use std::sync::Mutex;',
    'use std::sync::{Arc, Mutex};'
)

# 4. 替换 init_storage 函数
old_init = '''#[frb(sync)]
pub fn init_storage(db_path: String) -> ApiResult<()> {
    let storage = SqliteStorage::new(&db_path)
        .map_err(|e| ParserError::Other(format!("初始化存储失败：{}", e)))?;

    STORAGE
        .set(Mutex::new(storage))
        .map_err(|_| ParserError::Other("存储已经初始化".to_string()))?;

    tracing::info!("SQLite 存储已初始化：{}", db_path);
    Ok(())
}'''

new_init = '''/// **注意：此函数现在是 no-op，仅用于向后兼容。**
///
/// 所有持久化存储操作已迁移到 Flutter 侧（使用 Drift 数据库）。
/// Rust 侧现在仅使用内存存储，数据不会持久化。
#[frb(sync)]
pub fn init_storage(_db_path: String) -> ApiResult<()> {
    // 初始化内存存储（不持久化）
    let storage = Arc::new(InMemoryStorage::new());
    
    STORAGE
        .set(storage)
        .map_err(|_| ParserError::Other("存储已经初始化".to_string()))?;

    tracing::info!("内存存储已初始化（不持久化，所有数据已迁移到 Flutter 侧）");
    Ok(())
}'''

content = content.replace(old_init, new_init)

# 5. 替换 get_storage 函数
old_get = '''fn get_storage() -> ApiResult<std::sync::MutexGuard<'static, SqliteStorage>> {
    STORAGE
        .get()
        .ok_or_else(|| ParserError::Other("存储未初始化，请先调用 init_storage".to_string()))?
        .lock()
        .map_err(|e| ParserError::Other(format!("存储锁定失败：{}", e)))
}'''

new_get = '''fn get_storage() -> Result<Arc<dyn ProgressStorage>, ParserError> {
    STORAGE
        .get()
        .cloned()
        .ok_or_else(|| ParserError::Other("存储未初始化，请先调用 init_storage".to_string()))
}'''

content = content.replace(old_get, new_get)

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("修复完成！")
