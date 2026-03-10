-- ============================================================
-- AUTH SERVICE - MISSING INDEXES
-- Date: 2026-03-10
-- Purpose: Fix bottlenecks identified in auth-service performance review
-- ============================================================


-- [1] auth_user: index cho findByIdentifier & findByIdentifierWithActive
-- Vấn đề: composite index (auth_provider, identifier) không dùng được
--         khi query chỉ WHERE identifier = $1 (thiếu leading column)
-- Queries bị ảnh hưởng:
--   AuthUserRepositoryImpl:37  => SELECT * FROM auth_user WHERE identifier = $1
--   AuthUserRepositoryImpl:53  => JOIN users WHERE au.identifier = $1
-- Ảnh hưởng flow: requestOTP + verifyOTP (mỗi request gọi 1-2 lần)
CREATE INDEX IF NOT EXISTS idx_auth_user_identifier_only
    ON auth_user (identifier);


-- [2] user_sessions: composite index cho findByCredentialIdAndDeviceId
-- Vấn đề: chỉ có index (credential_id) đơn, sau đó phải filter device_id
-- Queries bị ảnh hưởng:
--   UserSessionRepositoryImpl:178 => WHERE credential_id=$1 AND device_id=$2 ORDER BY created_at DESC LIMIT 1
--   UserSessionRepositoryImpl:167 => DELETE WHERE credential_id=$1 AND device_id=$2
-- Ảnh hưởng flow: login, logout, verifyJWT session renewal
-- Lưu ý: bảng partition by expires_at, index tự apply xuống tất cả partitions (PG11+)
CREATE INDEX IF NOT EXISTS idx_user_sessions_credential_device
    ON user_sessions (credential_id, device_id);


-- [3] user_sessions: index cho findById (WHERE session_id = $1)
-- Vấn đề: PRIMARY KEY là (session_id, expires_at), query chỉ dùng session_id
--         => PostgreSQL scan toàn bộ partitions vì không prune được
-- Queries bị ảnh hưởng:
--   UserSessionRepositoryImpl:25 => SELECT * FROM user_sessions WHERE session_id = $1
CREATE INDEX IF NOT EXISTS idx_user_sessions_session_id
    ON user_sessions (session_id);


-- [4] blacklisted_tokens: index cho findByUserId (logout flow)
-- Vấn đề: không có index trên user_id => seq scan toàn bảng
-- Queries bị ảnh hưởng:
--   BlacklistedTokenRepositoryImpl:56 => SELECT * FROM blacklisted_tokens WHERE user_id = $1
CREATE INDEX IF NOT EXISTS idx_blacklisted_tokens_user_id
    ON blacklisted_tokens (user_id)
    WHERE user_id IS NOT NULL;


-- ============================================================
-- VERIFY sau khi tạo xong
-- ============================================================
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('auth_user', 'user_sessions', 'blacklisted_tokens')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
