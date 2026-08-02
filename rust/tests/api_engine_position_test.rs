//! 阅读引擎位置提示 API 集成测试
//!
//! 验证 Readium Locator JSON（引擎私有恢复提示）的保存/读取/覆盖语义。

mod common;

use rust_lib_zephyr_reader::api::engine_position;
use rust_lib_zephyr_reader::domain::engine_positions::models::EnginePositionHint;

fn make_hint(book_id: &str, fingerprint: &str, opaque: &str) -> EnginePositionHint {
    EnginePositionHint {
        book_id: book_id.to_string(),
        engine_kind: "readium".to_string(),
        publication_fingerprint: fingerprint.to_string(),
        opaque_position: opaque.to_string(),
        updated_at: chrono::Utc::now(),
    }
}

#[tokio::test]
async fn test_save_and_get_engine_position() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("ep_book_roundtrip").await;

    let hint = make_hint(
        "ep_book_roundtrip",
        "epub-fingerprint-1",
        r#"{"href":"chapter.xhtml","type":"application/xhtml+xml"}"#,
    );
    engine_position::save_engine_position(hint).await.unwrap();

    let loaded = engine_position::get_engine_position("ep_book_roundtrip".to_string())
        .await
        .unwrap()
        .expect("应能读取已保存的引擎位置提示");
    assert_eq!(loaded.engine_kind, "readium");
    assert_eq!(loaded.publication_fingerprint, "epub-fingerprint-1");
    assert!(loaded.opaque_position.contains("chapter.xhtml"));
}

#[tokio::test]
async fn test_engine_position_upsert_overwrites_per_book() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("ep_book_upsert").await;

    engine_position::save_engine_position(make_hint(
        "ep_book_upsert",
        "fp-a",
        r#"{"href":"page-1.xhtml"}"#,
    ))
    .await
    .unwrap();
    engine_position::save_engine_position(make_hint(
        "ep_book_upsert",
        "fp-b",
        r#"{"href":"page-2.xhtml"}"#,
    ))
    .await
    .unwrap();

    let loaded = engine_position::get_engine_position("ep_book_upsert".to_string())
        .await
        .unwrap()
        .expect("覆盖写后仍应可读");
    assert_eq!(loaded.publication_fingerprint, "fp-b");
    assert!(loaded.opaque_position.contains("page-2.xhtml"));
}

#[tokio::test]
async fn test_get_engine_position_unknown_book_returns_none() {
    common::init_logger();
    common::init_test_storage().await;

    let loaded = engine_position::get_engine_position("ep_book_unknown".to_string())
        .await
        .unwrap();
    assert!(loaded.is_none(), "未保存过位置的书籍应返回 None");
}
