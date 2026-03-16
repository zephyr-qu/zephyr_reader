#!/usr/bin/env python3
"""修复 api/mod.rs 文件，移除 SqliteStorage 依赖"""

file_path = r'F:\App\zephyr_reader\rust\src\api\mod.rs'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # 替换 import
    if 'use crate::storage::{ProgressStorage, SqliteStorage};' in line:
        new_lines.append('use crate::storage::{ProgressStorage, InMemoryStorage};\n')
        i += 1
        continue
    
    # 替换 STORAGE 静态变量
    if 'static STORAGE: OnceCell<Mutex<SqliteStorage>> = OnceCell::new();' in line:
        new_lines.append('static STORAGE: OnceCell<Arc<dyn ProgressStorage>> = OnceCell::new();\n')
        i += 1
        continue
    
    # 替换 Mutex import
    if 'use std::sync::Mutex;' in line and 'Arc' not in line:
        new_lines.append('use std::sync::{Arc, Mutex};\n')
        i += 1
        continue
    
    # 替换 init_storage 函数
    if 'pub fn init_storage(db_path: String)' in line:
        # 跳过旧函数直到找到闭合括号
        new_lines.append('#[frb(sync)]\n')
        new_lines.append('pub fn init_storage(_db_path: String) -> ApiResult<()> {\n')
        new_lines.append('    // 初始化内存存储（不持久化）\n')
        new_lines.append('    let storage = Arc::new(InMemoryStorage::new());\n')
        new_lines.append('    \n')
        new_lines.append('    STORAGE\n')
        new_lines.append('        .set(storage)\n')
        new_lines.append('        .map_err(|_| ParserError::Other("存储已经初始化".to_string()))?;\n')
        new_lines.append('\n')
        new_lines.append('    tracing::info!("内存存储已初始化（不持久化，所有数据已迁移到 Flutter 侧）");\n')
        new_lines.append('    Ok(())\n')
        new_lines.append('}\n')
        
        # 跳过旧函数体
        i += 1
        brace_count = 1
        while i < len(lines) and brace_count > 0:
            if '{' in lines[i]:
                brace_count += lines[i].count('{')
            if '}' in lines[i]:
                brace_count -= lines[i].count('}')
            i += 1
        continue
    
    # 替换 get_storage 函数
    if 'fn get_storage()' in line and 'SqliteStorage' in line:
        new_lines.append('fn get_storage() -> Result<Arc<dyn ProgressStorage>, ParserError> {\n')
        new_lines.append('    STORAGE\n')
        new_lines.append('        .get()\n')
        new_lines.append('        .cloned()\n')
        new_lines.append('        .ok_or_else(|| ParserError::Other("存储未初始化，请先调用 init_storage".to_string()))\n')
        new_lines.append('}\n')
        
        # 跳过旧函数体
        i += 1
        brace_count = 1
        while i < len(lines) and brace_count > 0:
            if '{' in lines[i]:
                brace_count += lines[i].count('{')
            if '}' in lines[i]:
                brace_count -= lines[i].count('}')
            i += 1
        continue
    
    new_lines.append(line)
    i += 1

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("修复完成！")
