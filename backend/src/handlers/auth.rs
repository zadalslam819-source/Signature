use axum::{extract::State, Json};
use sqlx::Row;
use std::sync::Arc;

use crate::dto::{RegisterRequest, RegisterResponse, LoginRequest, LoginResponse};
use crate::errors::AppError;
use crate::state::AppState;
use crate::utils::password::{hash_password, verify_password};
use crate::auth::jwt::create_jwt;
use uuid::Uuid;

pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<RegisterRequest>,
) -> Result<Json<RegisterResponse>, AppError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("database not connected"))
        .map_err(|e| AppError::InternalError(e))?;

    // Check existing
    let exists = sqlx::query("SELECT id FROM users WHERE username = $1 OR email = $2")
        .bind(&payload.username)
        .bind(&payload.email)
        .fetch_optional(pool.as_ref())
        .await
        .map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;

    if exists.is_some() {
        return Err(AppError::InternalError(anyhow::anyhow!("user already exists")));
    }

    let password_hash = hash_password(&payload.password).map_err(|e| AppError::InternalError(e))?;

    let row = sqlx::query("INSERT INTO users (username, email, password_hash) VALUES ($1,$2,$3) RETURNING id, username, email, created_at")
        .bind(&payload.username)
        .bind(&payload.email)
        .bind(&password_hash)
        .fetch_one(pool.as_ref())
        .await
        .map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;

    let id: Uuid = row.try_get("id").map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;
    let username: String = row.try_get("username").map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;
    let email: String = row.try_get("email").map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;

    Ok(Json(RegisterResponse { id: id.to_string(), username, email }))
}

pub async fn login(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("database not connected"))
        .map_err(|e| AppError::InternalError(e))?;

    let row = sqlx::query("SELECT id, username, email, password_hash FROM users WHERE username = $1 OR email = $1")
        .bind(&payload.username_or_email)
        .fetch_optional(pool.as_ref())
        .await
        .map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;

    let row = match row {
        Some(r) => r,
        None => return Err(AppError::NotFound),
    };

    let id: Uuid = row.try_get("id").map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;
    let password_hash: String = row.try_get("password_hash").map_err(|e| AppError::InternalError(anyhow::anyhow!(e)))?;

    let ok = verify_password(&password_hash, &payload.password).map_err(|e| AppError::InternalError(e))?;
    if !ok {
        return Err(AppError::NotFound);
    }

    let secret = state.config.jwt_secret.clone().ok_or_else(|| anyhow::anyhow!("jwt secret not configured")).map_err(|e| AppError::InternalError(e))?;

    let token = create_jwt(id, &secret).map_err(|e| AppError::InternalError(e))?;

    Ok(Json(LoginResponse { token }))
}
