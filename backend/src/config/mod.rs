use serde::Deserialize;
use std::env;

#[derive(Clone, Debug, Deserialize)]
pub struct Config {
    pub listen: String,
    pub database_url: String,
    pub env: String,
    pub jwt_secret: Option<String>,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        // Load .env if present but don't fail if missing
        let _ = dotenvy::dotenv();

        let listen = env::var("BACKEND_LISTEN").unwrap_or_else(|_| "127.0.0.1:8080".to_string());
        let database_url = env::var("DATABASE_URL").unwrap_or_else(|_| "postgres://localhost/postgres".to_string());
        let env = env::var("RUST_ENV").unwrap_or_else(|_| "development".to_string());
        let jwt_secret = env::var("JWT_SECRET").ok();

        Ok(Config {
            listen,
            database_url,
            env,
            jwt_secret,
        })
    }
}
