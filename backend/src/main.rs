mod auth;
mod config;
mod db;
mod dto;
mod errors;
mod handlers;
mod models;
mod routes;
mod services;
mod state;
mod utils;

use std::sync::Arc;
use tokio::net::TcpListener;
use tracing::{info, warn};
use tracing_subscriber::FmtSubscriber;

use crate::config::Config;
use crate::db::init_db_pool;
use crate::routes::create_router;
use crate::state::AppState;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    let subscriber = FmtSubscriber::builder()
        .with_max_level(tracing::Level::INFO)
        .finish();

    tracing::subscriber::set_global_default(subscriber)
        .expect("failed to initialize tracing subscriber");

    let config = Config::from_env()?;

    let pool = match init_db_pool(&config.database_url).await {
        Ok(pool) => {
            info!("database connection established");
            Some(pool)
        }
        Err(err) => {
            warn!("database connection failed, continuing without db: {}", err);
            None
        }
    };

    let app_state = Arc::new(AppState::new(config.clone(), pool));
    let app = create_router(app_state);

    info!("starting server on {}", config.listen);

    let listener = TcpListener::bind(&config.listen).await?;
    axum::serve(listener, app).await?;

    Ok(())
}