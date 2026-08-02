# Flutter import 路径修复 — 实施计划

## 执行顺序

### Step 1: 🔧 更新 FRB codegen 配置 + 重新生成 (5 min)

1. 在 `flutter_rust_bridge.yaml` 的 `rust_input` 中追加 `crate::domain::wordlist`
2. 运行 `flutter_rust_bridge_codegen generate`
3. 确认 `lib/src/rust/api/` 下生成新的 wordlist 相关函数

### Step 2: 📝 批量替换所有错误 API import (15 min)

使用 sed 批量替换以下 import 路径（每个替换只在 import 行中匹配，不影响代码）：

```
library/book_api.dart  → api/book.dart
library/category_api.dart → api/category.dart
library/import_api.dart → api/book.dart
library/epub_api.dart → api/book.dart
library/cover_api.dart → api/cover.dart
library/chapter_api.dart → api/chapter.dart
reader/reader_api.dart → api/reader.dart
reader/pagination.dart → api/reader.dart
reader/session.dart → api/session.dart
reader/progress.dart → api/progress.dart
reader/bookmark.dart → api/bookmark.dart
profile/note_api.dart → api/note.dart
profile/vocab_api.dart → api/vocab.dart
profile/stats_api.dart → api/stats.dart
language/bilingual_api.dart → api/bilingual.dart
language/dictionary_api.dart → api/dictionary.dart
language/vocab_scanner.dart → api/vocab.dart
search/api.dart → api/search.dart
infra/backup.dart → api/backup.dart
```

### Step 3: 📝 替换 reader/content_ir.dart → pipeline/types.dart

4 个文件需要将 `reader/content_ir.dart` 替换为 `pipeline/types.dart`。
18 个文件使用此路径。

### Step 4: 📝 替换 reader/rich_text.dart → pipeline/types.dart

4 个文件需要将 `reader/rich_text.dart` 替换为 `pipeline/types.dart`。

### Step 5: 📝 替换 library/models.dart → domain 模型 (15 min)

使用基于分析脚本的结果，将 79 处 `library/models.dart` 替换为领域特定的模型导入。按使用的类型自动判断目标 domain：

| 使用的类型 | 目标 domain 文件 |
| ----------- | ----------------- |
| Book, BookFormat, BookStatus, BookWithProgress, BookshelfBook, ImageFormat | `domain/book/models.dart` |
| Bookmark | `domain/bookmark/models.dart` |
| Category | `domain/category/models.dart` |
| Chapter | `domain/chapter/models.dart` |
| Dictionary, DictEntry, DictSearchResult | `domain/dictionary/models.dart` |
| Note, NoteStats, NoteType, NoteWithBook | `domain/note/models.dart` |
| ReadingProgress | `domain/progress/models.dart` |
| ReadingSession | `domain/sessions/models.dart` |
| GlobalStats, ReadingStats | `domain/stats/models.dart` |
| Vocab, VocabStats, VocabStatus | `domain/vocabulary/models.dart` |
| BackupStats, BackupManifest | `domain/backup/models.dart` |
| BilingualAlignment, BilingualHighlightPair, BilingualHighlightParams | `domain/bilingual/models.dart` |
| ChapterContentIr, ContentBlock, RichTextSpan, SearchResult, TextBlock, SpanStyle 等 | `pipeline/types.dart` |

### Step 6: 📝 替换 language/models.dart → domain/dictionary/models.dart

1 个文件 `reader_dictionary_panel.dart`。

### Step 7: ✅ 验证 (2 min)

- `cd rust && cargo clippy -- -D warnings`
- `cd / && flutter analyze --fatal-infos`

## 回滚点

每完成一个 Step 可独立 commit：

```
git add -A && git commit -m "fix(flutter): correct rust FRB import paths for <step>"
```

## 使用脚本说明

为避免手动修改 100+ 文件，使用 sed 或 Python 批量替换。

### Python 批量替换脚本

```python
import os
import re

# 需要替换的 import 路径映射
IMPORT_MAP = {
    'library/book_api.dart': 'api/book.dart',
    'library/category_api.dart': 'api/category.dart',
    'library/import_api.dart': 'api/book.dart',
    'library/epub_api.dart': 'api/book.dart',
    'library/cover_api.dart': 'api/cover.dart',
    'library/chapter_api.dart': 'api/chapter.dart',
    'reader/reader_api.dart': 'api/reader.dart',
    'reader/pagination.dart': 'api/reader.dart',
    'reader/session.dart': 'api/session.dart',
    'reader/progress.dart': 'api/progress.dart',
    'reader/bookmark.dart': 'api/bookmark.dart',
    'profile/note_api.dart': 'api/note.dart',
    'profile/vocab_api.dart': 'api/vocab.dart',
    'profile/stats_api.dart': 'api/stats.dart',
    'language/bilingual_api.dart': 'api/bilingual.dart',
    'language/dictionary_api.dart': 'api/dictionary.dart',
    'language/vocab_scanner.dart': 'api/vocab.dart',
    'search/api.dart': 'api/search.dart',
    'infra/backup.dart': 'api/backup.dart',
    'reader/content_ir.dart': 'pipeline/types.dart',
    'reader/rich_text.dart': 'pipeline/types.dart',
    'language/models.dart': 'domain/dictionary/models.dart',
}

def fix_imports(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    for old, new in IMPORT_MAP.items():
        content = re.sub(
            r'(import[\s\S]*?src/rust/)' + re.escape(old),
            r'\1' + new,
            content
        )
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False
```

然后运行逐个 fix。
