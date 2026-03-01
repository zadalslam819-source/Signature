use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("internal error")]
    InternalError(#[from] anyhow::Error),

    #[error("not found")]
    NotFound,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match &self {
            AppError::InternalError(_) => {
                (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error":"internal"}))).into_response()
            }
            AppError::NotFound => (StatusCode::NOT_FOUND, Json(json!({"error":"not_found"}))).into_response(),
        }
    }
}

