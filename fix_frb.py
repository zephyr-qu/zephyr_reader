#!/usr/bin/env python3
"""修复 frb_generated.rs 文件，添加 ZeroCopyBuffer 导入"""

file_path = r'F:\App\zephyr_reader\rust\src\frb_generated.rs'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 替换导入
content = content.replace(
    'use flutter_rust_bridge::{Handler, IntoIntoDart};',
    'use flutter_rust_bridge::{Handler, IntoIntoDart, ZeroCopyBuffer};'
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("修复完成！")
