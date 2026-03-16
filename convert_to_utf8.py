# convert_to_utf8_simple.py
import os
from pathlib import Path

# 常见编码候选列表
ENCODINGS = ['utf-8', 'gbk', 'gb2312', 'iso-8859-1','iso-8859-2', 'windows-1252', 'utf-16', 'big5', 'cp936']

def try_decode(content_bytes):
    """尝试多种编码解码"""
    for enc in ENCODINGS:
        try:
            return content_bytes.decode(enc), enc
        except (UnicodeDecodeError, LookupError):
            continue
    return None, None

def convert_file(file_path):
    """转换单个文件为 UTF-8"""
    try:
        with open(file_path, 'rb') as f:
            raw_data = f.read()

        # 尝试解码
        content, detected_enc = try_decode(raw_data)

        if content is None:
            print(f"✗ 无法解码：{file_path}")
            return False

        # 如果已经是 UTF-8，跳过
        if detected_enc == 'utf-8':
            print(f"✓ 已 UTF-8: {file_path}")
            return True

        # 用 UTF-8 无 BOM 写回
        with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(content)

        print(f"✓ 转换成功：{file_path} ({detected_enc} → UTF-8)")
        return True

    except Exception as e:
        print(f"✗ 错误：{file_path} - {e}")
        return False

def main():
    dart_files = list(Path('lib').rglob('*.dart'))
    print(f"📁 找到 {len(dart_files)} 个 Dart 文件\n")

    success = 0
    failed = 0

    for file_path in dart_files:
        if convert_file(str(file_path)):
            success += 1
        else:
            failed += 1

    print(f"\n{'='*50}")
    print(f"✅ 成功：{success} 个")
    print(f"❌ 失败：{failed} 个")
    print(f"{'='*50}")

if __name__ == '__main__':
    main()