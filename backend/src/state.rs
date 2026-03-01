use std::sync::Arc;

use sqlx::PgPool;

use crate::config::Config;

#[derive(Clone)]
pub struct AppState {
    pub config: Config,
    pub pool: Option<Arc<PgPool>>,
}

impl AppState {
    pub fn new(config: Config, pool: Option<PgPool>) -> Self {
        Self {
            config,
            pool: pool.map(Arc::new),
        }
    }
}