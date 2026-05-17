import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
for row in conn.execute("SELECT * FROM dictionary_meta"):
    print(row)
print("---Sample entries---")
for row in conn.execute("SELECT simplified, pinyin, definitions FROM dictionary_entries LIMIT 3"):
    print(row)
print("---FTS test 'hello'---")
for row in conn.execute("SELECT simplified FROM dictionary_fts WHERE dictionary_fts MATCH 'hello' LIMIT 3"):
    print(row)
conn.close()
