use axum::routing::get;
use axum::Router;
use std::sync::Arc;

use crate::handlers::health::health_handler;
use crate::state::AppState;

pub mod auth;
use crate::routes::auth::create_auth_router;

pub fn create_router(state: Arc<AppState>) -> Router {
    Router::new()
    .route("/health", get(health_handler))
    .nest("/api/auth", create_auth_router())
        .with_state(state)
}
