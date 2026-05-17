import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
# Exact match test
print("=== Exact match '你好' ===")
for row in conn.execute("SELECT simplified, pinyin, definitions FROM dictionary_entries WHERE simplified = '你好'"):
    print(row)
print("=== Exact match 'hello' (definition search) ===")
for row in conn.execute("SELECT simplified, pinyin, definitions FROM dictionary_entries WHERE definitions LIKE '%hello%' LIMIT 5"):
    print(row)
print("=== FTS match 'hello' ===")
for row in conn.execute("SELECT simplified FROM dictionary_fts WHERE dictionary_fts MATCH 'hello' LIMIT 5"):
    print(repr(row[0]))
print("=== FTS match '你好' ===")
for row in conn.execute("SELECT simplified FROM dictionary_fts WHERE dictionary_fts MATCH '你好' LIMIT 5"):
    print(repr(row[0]))
conn.close()
