use axum::routing::post;
use axum::Router;
use std::sync::Arc;

use crate::handlers::auth::{register, login};
use crate::state::AppState;

pub fn create_auth_router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/register", post(register))
        .route("/login", post(login))
}
