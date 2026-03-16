# fix_mojibake.py
# 用于修复 UTF-8 被错误解码后保存的乱码文件

import os
from pathlib import Path
from typing import Optional, Tuple

# 常见错误编码组合（原始 UTF-8 被误当这些编码读取后保存）
WRONG_ENCODINGS = [
    'latin-1',      # ISO-8859-1
    'cp1252',       # Windows-1252
    'cp1251',       # Windows-1251
    'iso-8859-1',
    'iso-8859-2',
    'gbk',
    'gb2312',
    'cp936',
]

def detect_mojibake_pattern(text: str) -> Optional[str]:
    """检测乱码模式"""
    # 典型 UTF-8 双重编码特征
    patterns = [
        ('Ã¤', 'ä'), ('Ã¶', 'ö'), ('Ã¼', 'ü'),  # 德语变音
        ('æ', ''), ('¥', ''), ('§', ''),  # 中文乱码特征
        ('Ã©', 'é'), ('Ã¨', 'è'), ('Ã ', 'à'),  # 法语重音
    ]
    for pattern, _ in patterns:
        if pattern in text:
            return 'utf-8-double-encoded'
    return None

def try_fix_double_encoding(content: str) -> Optional[str]:
    """尝试修复双重编码"""
    try:
        # 方法 1: UTF-8 → Latin-1 → UTF-8（最常见）
        bytes_latin = content.encode('latin-1')
        text_utf8 = bytes_latin.decode('utf-8')
        if text_utf8.isprintable() or any('\u4e00' <= c <= '\u9fff' for c in text_utf8):
            return text_utf8
    except:
        pass

    try:
        # 方法 2: UTF-8 → CP1252 → UTF-8
        bytes_cp1252 = content.encode('cp1252')
        text_utf8 = bytes_cp1252.decode('utf-8')
        if text_utf8.isprintable() or any('\u4e00' <= c <= '\u9fff' for c in text_utf8):
            return text_utf8
    except:
        pass

    try:
        # 方法 3: 直接尝试 GBK
        bytes_gbk = content.encode('gbk')
        text_utf8 = bytes_gbk.decode('utf-8')
        if any('\u4e00' <= c <= '\u9fff' for c in text_utf8):
            return text_utf8
    except:
        pass

    return None

def fix_file(file_path: str) -> Tuple[bool, str]:
    """修复单个文件"""
    try:
        # 1. 读取原始字节
        with open(file_path, 'rb') as f:
            raw_bytes = f.read()

        # 2. 尝试直接用 UTF-8 解码（如果已经是正确的）
        try:
            text = raw_bytes.decode('utf-8')
            if any('\u4e00' <= c <= '\u9fff' for c in text):
                return True, "已是 UTF-8"
        except:
            pass

        # 3. 尝试用各种错误编码读取，再转 UTF-8
        for wrong_enc in WRONG_ENCODINGS:
            try:
                # 用错误编码解码
                wrong_text = raw_bytes.decode(wrong_enc)
                # 尝试反向修复
                fixed_text = try_fix_double_encoding(wrong_text)
                if fixed_text:
                    # 写回 UTF-8
                    with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
                        f.write(fixed_text)
                    return True, f"{wrong_enc} → UTF-8"
            except:
                continue

        # 4. 如果都不行，尝试直接修复当前文件内容
        try:
            current_text = raw_bytes.decode('utf-8', errors='ignore')
            fixed_text = try_fix_double_encoding(current_text)
            if fixed_text:
                with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
                    f.write(fixed_text)
                return True, "double-encoding fixed"
        except:
            pass

        return False, "无法修复"

    except Exception as e:
        return False, f"错误：{e}"

def main():
    # 配置要修复的目录
    target_dirs = ['lib']

    all_files = []
    for dir_path in target_dirs:
        if os.path.exists(dir_path):
            all_files.extend(Path(dir_path).rglob('*.dart'))

    print(f"📁 找到 {len(all_files)} 个 Dart 文件\n")
    print(f"{'文件':<60} {'状态':<20}")
    print("=" * 80)

    success = 0
    failed = 0
    skipped = 0

    for file_path in all_files:
        file_str = str(file_path)
        # 缩短显示路径
        display_path = file_str if len(file_str) < 58 else "..." + file_str[-55:]

        ok, msg = fix_file(file_str)

        if ok:
            print(f"✅ {display_path:<58} {msg}")
            success += 1
        elif msg == "已是 UTF-8":
            print(f"⏭️  {display_path:<58} {msg}")
            skipped += 1
        else:
            print(f"❌ {display_path:<58} {msg}")
            failed += 1

    print("=" * 80)
    print(f"✅ 成功修复：{success} 个")
    print(f"⏭️  已跳过：{skipped} 个")
    print(f"❌ 修复失败：{failed} 个")
    print(f"📊 总计：{len(all_files)} 个")

if __name__ == '__main__':
    main()