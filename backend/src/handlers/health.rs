use axum::{extract::State, Json};
use std::sync::Arc;

use crate::dto::HealthDto;
use crate::state::AppState;

pub async fn health_handler(State(_state): State<Arc<AppState>>) -> Json<HealthDto> {
    Json(HealthDto { status: "ok".to_string() })
}
