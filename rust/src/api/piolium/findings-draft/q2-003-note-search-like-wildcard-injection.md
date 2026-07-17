---
id: q2-003
phase: Q2
slug: note-search-like-wildcard-injection
severity: low
---

# Missing LIKE Wildcard Escaping in Note Search

## Location

- `src/domain/note/note_repo.rs` (lines 234-240) — `search`

## Description

The `search` function in `NoteRepository` passes user-supplied `query` directly into a SQL `LIKE` clause **without escaping `%` or `_` wildcards**. This allows a user to unintentionally match more records than intended.

```rust
pub async fn search(pool: &SqlitePool, query: &str,) -> Result<Vec<Note>, AppError> {
    let pattern = format!("%{}%", query);   // ❌ no escaping
    Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE content LIKE ?1 OR selected_text LIKE ?1 ORDER BY created_at DESC",
    )
    .bind(&pattern)
    .fetch_all(pool)
    .await?)
}
```

Compare with the properly escaped implementation in `BookRepository::search` and `VocabRepository::search`:

```rust
// vocab_repo.rs — properly escaped
let escaped = keyword.replace('%', r"\%").replace('_', r"\_");
let pattern = format!("%{}%", escaped);
```

## Impact

- A search for `100%` will match notes containing `100x` for any suffix `x` due to `%` being interpreted as a wildcard
- A search for `test_1` will also match `testX1` due to `_` matching any single character
- In a local app, this is primarily a data leakage/correctness issue rather than a security vulnerability

## Attacker Control

User-supplied search input from the Flutter UI layer.

## Runtime

Local application process.

## Trust Boundary

User input to database query.

## Reachability

**reachable** — `search_notes` is a public `#[frb]` function.

## Recommendation

Add wildcard escaping identical to the pattern used in `VocabRepository::search`:
```rust
let escaped = query.replace('%', r"\%").replace('_', r"\_");
let pattern = format!("%{}%", escaped);
```
And add `ESCAPE '\'` to the SQL query.
