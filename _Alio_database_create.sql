-- =============================================================================
--                            TẬP LỆNH KHỞI TẠO DATABASE HOÀN CHỈNH
--      PHIÊN BẢN 3.12: TÁI CẤU TRÚC BẢNG `schedules` THÀNH CÁC BẢNG CHUYÊN BIỆT
-- =============================================================================
-- MỤC TIÊU:
--   - Hỗ trợ > 1,000,000 người dùng và > 10,000 CCU.
--   - Tích hợp tính năng GameFi, khóa tài khoản, quản lý nhóm gia đình với nhiều supervisor.
--   - Cập nhật trigger để hỗ trợ nhiều supervisor và thông báo dựa trên is_supervisor.
--   - Tối ưu hóa hiệu năng, bảo mật, và khả năng quản trị.
--
-- CÁC NGUYÊN TẮC THIẾT KẾ ĐƯỢC ÁP DỤNG:
--   1. CHUẨN HÓA DỮ LIỆU: Sử dụng bảng danh mục và khóa ngoại.
--   2. TỐI ƯU KIỂU DỮ LIỆU: Sử dụng SMALLINT, NUMERIC khi phù hợp.
--   3. INDEXING THÔNG MINH: Partial Index, Covering Index, BRIN và GIN Index.
--   4. BẢO MẬT: Tách biệt thông tin người dùng, xác thực, không sử dụng RLS.
--   5. PARTITIONING TOÀN DIỆN: Phân vùng cho các bảng lớn.
--   6. TÍNH TOÀN VẸN DỮ LIỆU: Thiết kế PK và ràng buộc logic.
--   7. QUẢN LÝ NGHIỆP VỤ MỞ RỘNG: Hỗ trợ GameFi, nhóm gia đình, nhiều supervisor, bác sĩ, đồng thuận dữ liệu.
-- =============================================================================

-- BƯỚC 1: ĐỊNH NGHĨA FUNCTION TÙY CHỈNH
-- =============================================================================

CREATE FUNCTION update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
COMMENT ON FUNCTION update_updated_at_column IS 'Trigger function tự động cập nhật cột updated_at khi có sự thay đổi bản ghi.';

-- CREATE FUNCTION check_failed_login_attempts() RETURNS trigger
--     LANGUAGE plpgsql
--     AS $$
-- DECLARE
--     failed_count INTEGER;
--     v_user_id UUID;
-- BEGIN
--     IF NEW.is_successful THEN
--         IF NEW.user_id IS NOT NULL THEN
--             UPDATE users
--             SET failed_attempts_count = 0, locked_at = NULL, lockout_reason = NULL
--             WHERE user_id = NEW.user_id AND failed_attempts_count > 0;
--         END IF;
--         RETURN NEW;
--     END IF;

--     IF NEW.user_id IS NULL THEN
--         SELECT user_id INTO v_user_id
--         FROM auth_user
--         WHERE identifier = NEW.identifier AND auth_provider = NEW.auth_provider;
--     ELSE
--         v_user_id := NEW.user_id;
--     END IF;

--     IF v_user_id IS NULL THEN
--         RETURN NEW;
--     END IF;

--     SELECT COUNT(*)
--     INTO failed_count
--     FROM login_attempts
--     WHERE user_id = v_user_id
--       AND is_successful = FALSE
--       AND attempt_time >= NOW() - INTERVAL '1 hour';

--     IF failed_count >= 5 THEN
--         UPDATE users
--         SET is_active = FALSE,
--             failed_attempts_count = failed_count,
--             locked_at = CURRENT_TIMESTAMP,
--             lockout_reason = 'Too many failed login attempts'
--         WHERE user_id = v_user_id AND is_active = TRUE;
--     ELSE
--         UPDATE users
--         SET failed_attempts_count = failed_count
--         WHERE user_id = v_user_id;
--     END IF;

--     RETURN NEW;
-- END;
-- $$;
-- COMMENT ON FUNCTION check_failed_login_attempts IS 'Trigger function to count failed login attempts and lock account after 5 failures within 1 hour.';

-- CREATE FUNCTION notify_family_group_invitation() RETURNS trigger
--     LANGUAGE plpgsql
--     AS $$
-- BEGIN
--     IF NEW.status = 0 AND NEW.user_id IS NOT NULL THEN
--         -- Gửi thông báo đến tất cả supervisor trong nhóm
--         INSERT INTO notifications (notification_id, user_id, notification_type, title, message, priority, related_id, created_at)
--         SELECT gen_random_uuid(),
--                fgm.user_id,
--                3, -- in_app
--                'Yêu cầu tham gia nhóm gia đình',
--                'Người dùng ' || (SELECT full_name FROM users WHERE user_id = NEW.user_id) || ' được mời tham gia nhóm gia đình ' || (SELECT name FROM family_groups WHERE group_id = NEW.group_id) || '. Vui lòng xác nhận.',
--                3,
--                NEW.membership_id,
--                CURRENT_TIMESTAMP
--         FROM family_group_members fgm
--         JOIN users u ON fgm.user_id = u.user_id
--         WHERE fgm.group_id = NEW.group_id
--           AND fgm.status = 1
--           AND u.is_supervisor = TRUE;
--         -- Gửi thông báo đến người được mời
--         INSERT INTO notifications (notification_id, user_id, notification_type, title, message, priority, related_id, created_at)
--         VALUES (
--             gen_random_uuid(),
--             NEW.user_id,
--             3, -- in_app
--             'Yêu cầu tham gia nhóm gia đình',
--             'Bạn được mời tham gia nhóm gia đình ' || (SELECT name FROM family_groups WHERE group_id = NEW.group_id) || '. Vui lòng xác nhận.',
--             3,
--             NEW.membership_id,
--             CURRENT_TIMESTAMP
--         );
--     END IF;
--     RETURN NEW;
-- END;
-- $$;
-- COMMENT ON FUNCTION notify_family_group_invitation IS 'Trigger function to send notifications to all supervisors (is_supervisor = TRUE) and the invited user when invited to a family group.';

-- CREATE FUNCTION log_family_group_change() RETURNS trigger
--     LANGUAGE plpgsql
--     AS $$
-- BEGIN
--     INSERT INTO family_group_audit_log (
--         group_id,
--         membership_id,
--         user_id,
--         action_type,
--         old_status,
--         new_status,
--         details,
--         created_at
--     )
--     VALUES (
--         COALESCE(NEW.group_id, OLD.group_id),
--         NEW.membership_id,
--         COALESCE(NEW.user_id, OLD.user_id),
--         CASE
--             WHEN TG_OP = 'INSERT' THEN 'create'
--             WHEN TG_OP = 'UPDATE' THEN 'update'
--             WHEN TG_OP = 'DELETE' THEN 'delete'
--         END,
--         OLD.status,
--         NEW.status,
--         NULL,
--         CURRENT_TIMESTAMP
--     );
--     RETURN NEW;
-- END;
-- $$;
-- COMMENT ON FUNCTION log_family_group_change IS 'Trigger function to log changes to family_group_members for auditing.';

-- CREATE FUNCTION log_supervisor_action() RETURNS trigger
--     LANGUAGE plpgsql
--     AS $$
-- BEGIN
--     INSERT INTO family_group_audit_log (
--         group_id,
--         membership_id,
--         user_id,
--         action_type,
--         details,
--         created_at
--     )
--     VALUES (
--         NEW.group_id,
--         NULL,
--         NEW.user_id,
--         NEW.action_type,
--         NEW.details,
--         CURRENT_TIMESTAMP
--     );
--     RETURN NEW;
-- END;
-- $$;
-- COMMENT ON FUNCTION log_supervisor_action IS 'Trigger function to log supervisor-specific actions (e.g., viewing health data).';

-- CREATE FUNCTION notify_supervisor_health_update() RETURNS trigger
--     LANGUAGE plpgsql
--     AS $$
-- BEGIN
--     INSERT INTO notifications (notification_id, user_id, notification_type, title, message, priority, related_id, created_at)
--     SELECT gen_random_uuid(),
--            fgm.user_id,
--            3, -- in_app
--            'Cập nhật sức khỏe từ thành viên',
--            'Thành viên ' || (SELECT full_name FROM users WHERE user_id = NEW.user_id) || ' đã cập nhật dữ liệu sức khỏe.',
--            3,
--            NEW.user_id,
--            CURRENT_TIMESTAMP
--     FROM family_group_members fgm
--     JOIN user_configurations uc ON fgm.user_id = uc.user_id
--     JOIN users u ON fgm.user_id = u.user_id
--     WHERE fgm.group_id = (SELECT group_id FROM family_group_members WHERE user_id = NEW.user_id AND status = 1)
--       AND fgm.status = 1
--       AND u.is_supervisor = TRUE
--       AND uc.family_data_sharing->>'health_data' = 'true';
--     RETURN NEW;
-- END;
-- $$;
-- COMMENT ON FUNCTION notify_supervisor_health_update IS 'Trigger function to notify all supervisors (is_supervisor = TRUE) when a group member updates health data.';

-- CREATE FUNCTION notify_supervisor_gamefi_update() RETURNS trigger
--     LANGUAGE plpgsql
--     AS $$
-- BEGIN
--     INSERT INTO notifications (notification_id, user_id, notification_type, title, message, priority, related_id, created_at)
--     SELECT gen_random_uuid(),
--            fgm.user_id,
--            3, -- in_app
--            'Cập nhật GameFi từ thành viên',
--            'Thành viên ' || (SELECT full_name FROM users WHERE user_id = NEW.user_id) || ' đã cập nhật dữ liệu GameFi.',
--            3,
--            NEW.user_id,
--            CURRENT_TIMESTAMP
--     FROM family_group_members fgm
--     JOIN user_configurations uc ON fgm.user_id = uc.user_id
--     JOIN users u ON fgm.user_id = u.user_id
--     WHERE fgm.group_id = (SELECT group_id FROM family_group_members WHERE user_id = NEW.user_id AND status = 1)
--       AND fgm.status = 1
--       AND u.is_supervisor = TRUE
--       AND uc.family_data_sharing->>'gamefi_data' = 'true';
--     RETURN NEW;
-- END;
-- $$;
-- COMMENT ON FUNCTION notify_supervisor_gamefi_update IS 'Trigger function to notify all supervisors (is_supervisor = TRUE) when a group member updates GameFi data.';

-- =============================================================================
-- PHÂN HỆ 6: ĐỊA LÝ & THÔNG TIN CHUNG
-- =============================================================================

CREATE TABLE provinces (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name TEXT NOT NULL,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
);
CREATE INDEX idx_provinces_code ON provinces (code);
CREATE INDEX idx_provinces_name ON provinces (name);
CREATE INDEX idx_provinces_lat_lon ON provinces (lat, lon);

CREATE TABLE communes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    province_id INT NOT NULL REFERENCES provinces(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION
);
CREATE INDEX idx_communes_province_id ON communes (province_id);
CREATE INDEX idx_communes_code ON communes (code);
CREATE INDEX idx_communes_name ON communes (name);
CREATE INDEX idx_communes_lat_lon ON communes (lat, lon);

-- =============================================================================
-- PHÂN HỆ 1: QUẢN LÝ NGƯỜI DÙNG & XÁC THỰC
-- =============================================================================

-- Migration to create admin_users table for managing admin phone numbers
-- This replaces the hardcoded admin phone numbers in AuthConstants.java

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(100),
    birth_date DATE,
    gender SMALLINT, -- 0: Nam, 1: Nữ
    address TEXT,
    province_id INT REFERENCES provinces(id) ON DELETE SET NULL,
    commune_id INT REFERENCES communes(id) ON DELETE SET NULL,
    has_hypertension INT, -- 1-"Tăng huyết áp", 2-"Huyết áp thấp", 3-"Huyết áp không ổn định", 4-"Không"
    feeling SMALLINT DEFAULT 1, -- 1-tuyệt vời, 2-tốt, 3-bình thường, 4-hơi mệt, 5-không khỏe
    title VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    failed_attempts_count INTEGER NOT NULL DEFAULT 0,
    locked_at TIMESTAMPTZ,
    lockout_reason TEXT,
    systolic TEXT,  -- Huyết áp tâm thu
    diastolic TEXT, -- Huyết áp tâm trương
    level SMALLINT DEFAULT 0, -- 0-5: Cấp độ người dùng
    description TEXT,
    avatar_id TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE users
ADD COLUMN systolic TEXT,  -- Huyết áp tâm thu
ADD COLUMN diastolic TEXT; -- Huyết áp tâm trương

CREATE INDEX idx_users_created_at ON users (created_at);
CREATE INDEX idx_users_active ON users (user_id) WHERE is_active = TRUE;
CREATE INDEX idx_users_province_id ON users (province_id);
CREATE INDEX idx_users_commune_id ON users (commune_id);
CREATE INDEX idx_users_level ON users (level);
CREATE INDEX idx_users_failed_attempts ON users (failed_attempts_count) WHERE failed_attempts_count > 0;



CREATE TABLE auth_user (
    credential_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    auth_provider VARCHAR(50) NOT NULL,
    identifier TEXT NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    credential_hash TEXT,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, auth_provider),
    UNIQUE (auth_provider, identifier)
);
CREATE INDEX idx_auth_user_user_id ON auth_user (user_id);
CREATE INDEX idx_auth_user_identifier ON auth_user (auth_provider, identifier);

CREATE TABLE login_attempts (
    id BIGSERIAL,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    identifier TEXT NOT NULL,
    auth_provider VARCHAR(50) NOT NULL,
    attempt_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_successful BOOLEAN NOT NULL,
    ip_address INET,
    user_agent TEXT,
    PRIMARY KEY(id, attempt_time)
) PARTITION BY RANGE (attempt_time);
CREATE INDEX idx_login_attempts_lookup ON login_attempts (identifier, auth_provider, attempt_time DESC);
CREATE INDEX idx_login_attempts_user_id ON login_attempts (user_id, attempt_time DESC) WHERE user_id IS NOT NULL;
CREATE TABLE login_attempts_y2025m09 PARTITION OF login_attempts FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE login_attempts_default PARTITION OF login_attempts DEFAULT;

CREATE TABLE temp_users (
    phone VARCHAR(20) PRIMARY KEY,
    device_id VARCHAR(100) NOT NULL,
    full_name VARCHAR(100),
    birth_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_temp_users_device_id ON temp_users (device_id);

CREATE TABLE otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) NOT NULL UNIQUE,
    otp VARCHAR(10) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempt_count SMALLINT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_otps_expires_at CHECK (expires_at > created_at)
);
CREATE INDEX idx_otps_expires_at ON otps (expires_at);

CREATE TABLE user_sessions (
    session_id UUID DEFAULT gen_random_uuid(),
    credential_id UUID NOT NULL REFERENCES auth_user(credential_id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (session_id, expires_at),
    UNIQUE (access_token, expires_at),
    UNIQUE (refresh_token, expires_at)
) PARTITION BY RANGE (expires_at);
CREATE INDEX idx_user_sessions_active_by_credential ON user_sessions (credential_id);
CREATE TABLE user_sessions_y2025m09 PARTITION OF user_sessions FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE user_sessions_default PARTITION OF user_sessions DEFAULT;

CREATE TABLE blacklisted_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash VARCHAR(800) NOT NULL UNIQUE,
    token_type VARCHAR(20) NOT NULL,
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_blacklisted_tokens_expires_at ON blacklisted_tokens (expires_at);

CREATE TABLE locked_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    locked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_locked_devices_device_id_phone ON locked_devices (device_id, phone);
CREATE INDEX idx_locked_devices_locked_until ON locked_devices (locked_until);
CREATE UNIQUE INDEX unique_locked_devices_global ON locked_devices (device_id);
CREATE UNIQUE INDEX unique_locked_devices_per_user ON locked_devices (device_id, phone);


-- Bảng friend_requests
CREATE TABLE friend_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    phone VARCHAR(20) NOT NULL,
    status SMALLINT DEFAULT 0, -- 0: pending, 1: accepted, 2: rejected, 3: cancelled
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_friend_requests_sender_id ON friend_requests (sender_id);
CREATE INDEX idx_friend_requests_receiver_id ON friend_requests (receiver_id) WHERE receiver_id IS NOT NULL;
CREATE INDEX idx_friend_requests_phone ON friend_requests (phone);
CREATE INDEX idx_friend_requests_status ON friend_requests (status);

-- Bảng friends
CREATE TABLE friends (
    friendship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status SMALLINT DEFAULT 1, -- 1: active, 0: inactive
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, friend_id),
    CONSTRAINT chk_different_users CHECK (user_id != friend_id)
);
CREATE INDEX idx_friends_user_id ON friends (user_id);
CREATE INDEX idx_friends_friend_id ON friends (friend_id);
CREATE INDEX idx_friends_status ON friends (status) WHERE status = 1;

-- Bảng friend_audit_log
CREATE TABLE friend_audit_log (
    log_id BIGSERIAL,
    friendship_id UUID NOT NULL REFERENCES friends(friendship_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    action_type VARCHAR(20) NOT NULL, -- create, delete, view_health, view_gamefi
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_friend_audit_log_friendship_id ON friend_audit_log (friendship_id);
CREATE INDEX idx_friend_audit_log_user_id ON friend_audit_log (user_id);
CREATE INDEX idx_friend_audit_log_target_user_id ON friend_audit_log (target_user_id);
CREATE INDEX idx_friend_audit_log_action_type ON friend_audit_log (action_type);
CREATE TABLE friend_audit_log_y2025m09 PARTITION OF friend_audit_log FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE friend_audit_log_default PARTITION OF friend_audit_log DEFAULT;

CREATE TABLE user_configurations (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true, "in_app": true, "medication_schedules": true, "blood_pressure_schedules": true, "re_examination_schedules": true, "life_style": true, "periodic_reports": true}'::jsonb,
    share_health_data BOOLEAN DEFAULT FALSE,
    share_gamefi_data BOOLEAN DEFAULT FALSE,
    language VARCHAR(10) DEFAULT 'vi',
    timezone VARCHAR(50) DEFAULT 'Asia/Ho_Chi_Minh',
    theme VARCHAR(20) DEFAULT 'light',
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    fcm_token TEXT NULL,
    font_size_app INTEGER DEFAULT 14 NOT NULL,
    voice_style TEXT DEFAULT 'vi-VN-Standard-A'
);
CREATE INDEX idx_user_configurations_user_id ON user_configurations (user_id);
CREATE INDEX idx_user_configurations_share_health ON user_configurations (share_health_data) WHERE share_health_data = TRUE;
CREATE INDEX idx_user_configurations_share_gamefi ON user_configurations (share_gamefi_data) WHERE share_gamefi_data = TRUE;
CREATE INDEX idx_user_configs_notification_prefs_gin ON user_configurations USING GIN (notification_preferences);

CREATE TABLE notifications (
    notification_id UUID DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    notification_type SMALLINT NOT NULL, -- 0: email, 1: sms, 2: push, 3: in_app
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    priority SMALLINT DEFAULT 1, -- 1-5: Độ ưu tiên
    related_id UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    -- CỘT MỚI (hoặc tương đương) ĐỂ XỬ LÝ ICON VÀ ĐIỀU HƯỚNG
    schedule_type VARCHAR(50),          -- Loại lịch (VD: 'heart', 'calendar', 'report')
    action_data JSONB,                  -- Data hành động (VD: 'VIEW_REPORT', 'LOG_MEDICATION')

    PRIMARY KEY(notification_id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_notifications_user_id ON notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications (user_id) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_related_id ON notifications (related_id) WHERE related_id IS NOT NULL;
CREATE TABLE notifications_y2025m09 PARTITION OF notifications FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE notifications_default PARTITION OF notifications DEFAULT;

CREATE TABLE user_feedback (
    feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    feedback_type SMALLINT NOT NULL, -- 0: feature_request, 1: bug_report, 2: general, 3: satisfaction
    title VARCHAR(100),
    description TEXT NOT NULL,
    rating SMALLINT, -- 1-5: Mức độ hài lòng
    status SMALLINT DEFAULT 0, -- 0: Chưa xử lý, 1: Đang xử lý, 2: Đã xử lý
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_user_feedback_user_id ON user_feedback (user_id, created_at DESC);
CREATE INDEX idx_user_feedback_status ON user_feedback (status) WHERE status = 0;


CREATE TABLE admin_users (
    admin_id SERIAL PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    email VARCHAR(255),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

-- Create indexes for better performance
CREATE INDEX idx_admin_users_phone_number ON admin_users(phone_number);
CREATE INDEX idx_admin_users_status ON admin_users(status);
CREATE INDEX idx_admin_users_created_at ON admin_users(created_at);

-- Insert default admin phone numbers from AuthConstants.java
INSERT INTO admin_users (phone_number, full_name, status, notes) VALUES
('0123456789', 'Default Admin 1', 'ACTIVE', 'Migrated from hardcoded constants'),
('0987654321', 'Default Admin 2', 'ACTIVE', 'Migrated from hardcoded constants');

-- Create audit log table for admin changes
CREATE TABLE admin_audit_log (
    audit_id BIGSERIAL,
    admin_id INT REFERENCES admin_users(admin_id),
    action VARCHAR(50) NOT NULL, -- CREATE, UPDATE, DELETE, LOGIN, LOGOUT
    old_values JSONB,
    new_values JSONB,
    performed_by UUID REFERENCES users(user_id),
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    notes TEXT,
    PRIMARY KEY (audit_id, performed_at)
) PARTITION BY RANGE (performed_at);

-- Create partitions for audit log (current month and default)
CREATE TABLE admin_audit_log_y2025m01 PARTITION OF admin_audit_log 
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE admin_audit_log_default PARTITION OF admin_audit_log DEFAULT;

-- Create indexes for audit log
CREATE INDEX idx_admin_audit_log_admin_id ON admin_audit_log(admin_id);
CREATE INDEX idx_admin_audit_log_action ON admin_audit_log(action);
CREATE INDEX idx_admin_audit_log_performed_at ON admin_audit_log(performed_at);
CREATE INDEX idx_admin_audit_log_performed_by ON admin_audit_log(performed_by);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_admin_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER trigger_update_admin_users_updated_at
    BEFORE UPDATE ON admin_users
    FOR EACH ROW
    EXECUTE FUNCTION update_admin_users_updated_at();

-- Create function to log admin changes
CREATE OR REPLACE FUNCTION log_admin_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO admin_audit_log (admin_id, action, new_values, performed_at)
        VALUES (NEW.admin_id, 'CREATE', to_jsonb(NEW), CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO admin_audit_log (admin_id, action, old_values, new_values, performed_at)
        VALUES (NEW.admin_id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO admin_audit_log (admin_id, action, old_values, performed_at)
        VALUES (OLD.admin_id, 'DELETE', to_jsonb(OLD), CURRENT_TIMESTAMP);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically log admin changes
CREATE TRIGGER trigger_log_admin_changes
    AFTER INSERT OR UPDATE OR DELETE ON admin_users
    FOR EACH ROW
    EXECUTE FUNCTION log_admin_changes();

-- Grant necessary permissions (adjust as needed)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON admin_users TO auth_service_user;
-- GRANT SELECT, INSERT ON admin_audit_log TO auth_service_user;
-- GRANT USAGE ON SEQUENCE admin_users_admin_id_seq TO auth_service_user;
-- GRANT USAGE ON SEQUENCE admin_audit_log_audit_id_seq TO auth_service_user;

-- =============================================================================
-- PHÂN HỆ 2: PHÂN QUYỀN (RBAC) & DANH MỤC CHỨC NĂNG
-- =============================================================================

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE permissions (
    permission_id SERIAL PRIMARY KEY,
    permission_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    category VARCHAR(50)
);

CREATE TABLE role_permissions (
    role_id INT NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id INT NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id INT NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- =============================================================================
-- PHÂN HỆ 3: SỨC KHỎE & LỊCH TRÌNH
-- =============================================================================

CREATE TABLE user_health_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    weight_kg NUMERIC(5,1),
    height_cm INTEGER,
    medical_conditions JSONB,
    food_allergies JSONB,
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(15),
    emergency_contact_relation VARCHAR(50),
    dietary_habits TEXT,
    daily_routine TEXT,
    favorite_foods TEXT,
    is_pregnant_or_breastfeeding BOOLEAN,
    blood_pressure_systolic INTEGER,
    blood_pressure_diastolic INTEGER,
    systolic_threshold_lower INTEGER,
    systolic_threshold_upper INTEGER,
    diastolic_threshold_lower INTEGER,
    diastolic_threshold_upper INTEGER,
    physical_activity_level INTEGER,
    diabetes_duration_years INTEGER DEFAULT 0,
    description TEXT,
    last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_user_health_profiles_conditions_gin ON user_health_profiles USING GIN (medical_conditions);


ALTER TABLE user_health_profiles
    ADD COLUMN total_cholesterol_mmol NUMERIC(5,2),
    ADD COLUMN hdl_cholesterol_mmol NUMERIC(5,2),
    ADD COLUMN is_smoker BOOLEAN,
    ADD COLUMN has_diabetes BOOLEAN,
    ADD COLUMN hba1c NUMERIC(4,1),
    ADD COLUMN egfr NUMERIC(5,1),
    ADD COLUMN has_cvd_history BOOLEAN;


CREATE TABLE user_blood_pressure (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    systolic INT NOT NULL,
    diastolic INT NOT NULL,
    heart_rate INT,
    status SMALLINT DEFAULT 0, -- 0: Đang hoạt động, 1: Đã xoá,
    measurement_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    chat_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    additional_info JSONB
);
CREATE INDEX idx_user_blood_pressure_user_id ON user_blood_pressure (user_id);
CREATE INDEX idx_user_blood_pressure_measurement_time ON user_blood_pressure (measurement_time);

CREATE TABLE prescriptions (
    prescription_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    prescription_code VARCHAR(150),
    prescribed_description TEXT,
    status SMALLINT DEFAULT 0, -- 0: Chưa sử dụng, 1: Đang sử dụng, 2: Đã hoàn thành
    created_id UUID REFERENCES users(user_id),  -- v6.0: Who created this record (patient or caregiver)
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_prescriptions_user_id ON prescriptions (user_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_created_id ON prescriptions(created_id) WHERE created_id IS NOT NULL;

CREATE TABLE prescription_items (
    prescription_item_id BIGSERIAL PRIMARY KEY,
    prescription_id BIGINT NOT NULL REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    medicine_name TEXT,
    dosage TEXT,
    instructions TEXT,
    medicine_form VARCHAR(50),

    -- MỚI: Thêm "Tên gợi nhớ" (nickname), cho phép NULL
    nickname VARCHAR(100) NULL,

    -- MỚI: Thêm "Số lượng còn lại" (thay thế cho cột cũ đã comment)
    -- Dùng NUMERIC(9, 2) để đảm bảo độ chính xác (tối đa 999,999.99)
    -- và 2 chữ số thập phân
    remaining_quantity NUMERIC(9, 2) NOT NULL DEFAULT 0,

    -- initial_quantity INTEGER NOT NULL DEFAULT 0,   -- Cột: Tổng số lượng thuốc ban đầu (từ file gốc)

    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    usage_time TEXT,
    recurrence_type VARCHAR(20) DEFAULT 'daily', -- one_time, daily, weekly, monthly, days_a_time
    status SMALLINT DEFAULT 0, -- 0: Chưa sử dụng, 1: Đang sử dụng, 2: Đã hoàn thành, 3: Đã xóa
    created_id UUID REFERENCES users(user_id),  -- v6.0: Who created this record (patient or caregiver)
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_remaining_quantity_range CHECK (remaining_quantity >= 0 AND remaining_quantity < 1000000)
);
CREATE INDEX idx_prescription_items_prescription_id ON prescription_items (prescription_id);
CREATE INDEX idx_prescription_items_active ON prescription_items (prescription_id) WHERE status = 0;
CREATE INDEX IF NOT EXISTS idx_prescription_items_created_id ON prescription_items(created_id) WHERE created_id IS NOT NULL;
CREATE UNIQUE INDEX idx_unique_active_nickname
ON prescription_items (prescription_id, nickname)
WHERE status = 1 AND nickname IS NOT NULL AND nickname != '';


-- =============================================================================
-- BẢNG SỰ KIỆN TÁI KHÁM (PHIÊN BẢN LƯU TRỮ LỊCH HẸN)
-- Đã loại bỏ các trường về kết quả tái khám.
-- =============================================================================

-- Bảng này là nơi lưu trữ mọi thứ về một buổi hẹn tái khám.
CREATE TABLE re_examination_events (
    event_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- THÔNG TIN LỊCH HẸN
    appointment_date DATE NOT NULL,                   -- Ngày hẹn, định dạng YYYY-MM-DD
    appointment_time TIME,                            -- Giờ hẹn, định dạng HH:mm (cho phép NULL nếu chỉ hẹn ngày)
    
    -- THÔNG TIN CHI TIẾT
    specialty VARCHAR(150) NOT NULL,                  -- Chuyên khoa
    doctor_name VARCHAR(100),                         -- Tên bác sĩ
    facility_name VARCHAR(200),              -- Cơ sở y tế
    notes TEXT,                                       -- Ghi chú ban đầu (ví dụ: mang theo xét nghiệm)
    file_ids JSONB DEFAULT '[]'::jsonb,               -- Danh sách file đính kèm
    exam_date VARCHAR(50),                            -- Ngày khám thực sự (định dạng string, ví dụ: "2025-10-08")
    
    -- TRƯỜNG STATUS ĐA TRẠNG THÁI
    status SMALLINT NOT NULL DEFAULT 0,               -- 1: Đang hoạt động, 2: Đã hoàn thành, 3: Đã xoá
    
    -- TIMESTAMPS
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Tạo các index cần thiết
CREATE INDEX idx_rex_events_user_id ON re_examination_events (user_id);
CREATE INDEX idx_rex_events_appointment_date ON re_examination_events (user_id, appointment_date DESC);
CREATE INDEX idx_rex_events_status ON re_examination_events (user_id, status);

-- Kích hoạt trigger update_updated_at cho bảng mới
CREATE TRIGGER trigger_rex_events_update_updated_at
    BEFORE UPDATE ON re_examination_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- KHU VỰC ĐÃ SỬA ĐỔI: TÁCH BẢNG `schedules`
-- =============================================================================

-- Bảng 1: Lịch trình liên quan đến thuốc (Medication)
CREATE TABLE medication_schedules (
    schedule_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    -- Các type: medication, suggestion_medication, collecting_medication_feedback
    type VARCHAR(50) NOT NULL,
    related_id BIGINT REFERENCES prescription_items(prescription_item_id) ON DELETE CASCADE,
    quantity_used NUMERIC(9, 2) DEFAULT 1.0, -- Supports decimal values like 0.5
    scheduled_time TIMESTAMPTZ NOT NULL,
    recurrence_type VARCHAR(20) DEFAULT 'daily', -- one_time, daily, weekly, monthly, days_a_time
    recurrence_end TIMESTAMPTZ,
    reminder_type SMALLINT DEFAULT 0, -- 0: sắp đến giờ, 1: Đã đến giờ, 2: Đã quá giờ
    agent_scenario VARCHAR(50),
    last_run_at TIMESTAMPTZ,
    missed_count INTEGER DEFAULT 0,
    feedback_collection_notified_at  TIMESTAMPTZ ,
    status SMALLINT DEFAULT 0, -- 0: Chưa thực hiện, 1: Đang thực hiện, 2: Đã hoàn thành
    created_id UUID REFERENCES users(user_id),  -- v6.0: Who created this record (patient or caregiver)
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_quantity_used_min CHECK (quantity_used > 0)
);
CREATE INDEX idx_med_schedules_due ON medication_schedules (status, scheduled_time) WHERE (status = 0);
CREATE INDEX idx_med_schedules_upcoming_by_user ON medication_schedules (user_id, scheduled_time DESC) WHERE (status = 0);
CREATE INDEX idx_med_schedules_related_id ON medication_schedules (related_id);
CREATE INDEX IF NOT EXISTS idx_medication_schedules_created_id ON medication_schedules(created_id) WHERE created_id IS NOT NULL;

-- Bảng 2: Lịch trình liên quan đến huyết áp (Blood Pressure)
CREATE TABLE blood_pressure_schedules (
    schedule_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    -- Các type: blood_pressure, suggestion_blood_pressure, collecting_blood_pressure_feedback, send_blood_pressure_report
    type VARCHAR(50) NOT NULL,
    related_id BIGINT,
    scheduled_time TIMESTAMPTZ NOT NULL,
    recurrence_type VARCHAR(20) DEFAULT 'one_time',
    recurrence_end TIMESTAMPTZ,
    reminder_type SMALLINT DEFAULT 0, -- 0: sắp đến giờ, 1: Đã đến giờ, 2: Đã quá giờ
    agent_scenario VARCHAR(50),
    last_run_at TIMESTAMPTZ,
    missed_count INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0, -- 0: Hoạt động, 1: Đang thực hiện, 2: Đã hoàn thành, 3: Huỷ bỏ
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_bp_schedules_due ON blood_pressure_schedules (status, scheduled_time) WHERE (status = 0);
CREATE INDEX idx_bp_schedules_upcoming_by_user ON blood_pressure_schedules (user_id, scheduled_time DESC) WHERE (status = 0);

-- Bảng 3: Lịch trình liên quan đến tái khám (Re-examination)
CREATE TABLE re_examination_schedules (
    schedule_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    -- Các type: re_examination, collect_feedback_re_examination
    type VARCHAR(50) NOT NULL,
    related_id BIGINT REFERENCES re_examination_events(event_id) ON DELETE CASCADE,
    scheduled_time TIMESTAMPTZ NOT NULL,
    recurrence_type VARCHAR(20) DEFAULT 'one_time',
    recurrence_end TIMESTAMPTZ,
    reminder_type SMALLINT DEFAULT 0, -- 0: sắp đến giờ, 1: Đã đến giờ, 2: Đã quá giờ
    agent_scenario VARCHAR(50),
    last_run_at TIMESTAMPTZ,
    missed_count INTEGER DEFAULT 0,
    status SMALLINT DEFAULT 0,  -- 0: Chưa thực hiện, 1: Đang thực hiện, 2: Đã hoàn thành, 3: Đã hủy
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_rex_schedules_due ON re_examination_schedules (status, scheduled_time) WHERE (status = 0);
CREATE INDEX idx_rex_schedules_upcoming_by_user ON re_examination_schedules (user_id, scheduled_time DESC) WHERE (status = 0);
CREATE INDEX idx_rex_schedules_related_id ON re_examination_schedules (related_id);


CREATE TABLE user_medication_feedback (
    feedback_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    prescription_item_id BIGINT NOT NULL,

    -- Dữ liệu được "sao chép" (denormalized) để đảm bảo tính toàn vẹn lịch sử
    -- ngay cả khi đơn thuốc gốc thay đổi hoặc bị xóa.
    medicine_name TEXT NOT NULL,

    nickname VARCHAR(100) NULL,
    remaining_quantity NUMERIC(9, 2) NOT NULL DEFAULT 0,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    
    dosage TEXT NOT NULL,
    instructions TEXT, -- Hướng dẫn có thể không bắt buộc
    medicine_form VARCHAR(50) NOT NULL,
    schedule_time TIMESTAMPTZ NOT NULL, -- thời gian uống thuốc dạng YYYY-MM-DD HH:mm
    -- ĐÃ SỬA ĐỔI Ở ĐÂY: INT -> NUMERIC(9, 2)
    quantity_prescribed NUMERIC(9, 2) NOT NULL DEFAULT 1, -- số lượng thuốc được kê đơn
    status INT NOT NULL DEFAULT 0, -- Trạng thái 0: Chờ phản hồi, 1: Sai liều, 2: Quên uống, 3: Đã uống
    -- ĐÃ SỬA ĐỔI Ở ĐÂY: INT -> NUMERIC(9, 2)
    quantity_taken NUMERIC(9, 2), -- Số lượng thực tế đã uống, chỉ bắt buộc khi status là 1 (Sai liều)
    
    -- v6.0: Who created this record (patient or caregiver)
    created_id UUID REFERENCES users(user_id),
    -- Timestamps quản lý vòng đời của bản ghi
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_feedback_user_id ON user_medication_feedback (user_id);
CREATE INDEX idx_feedback_user_schedule_time ON user_medication_feedback (user_id, schedule_time DESC);
CREATE INDEX idx_feedback_status ON user_medication_feedback (status);

CREATE INDEX idx_user_medication_feedback_user_status ON user_medication_feedback(user_id, status);
CREATE INDEX idx_user_medication_feedback_user_prescription ON user_medication_feedback(user_id, prescription_item_id);
CREATE INDEX idx_user_medication_feedback_prescription_item ON user_medication_feedback(prescription_item_id);
CREATE INDEX idx_user_medication_feedback_user_created ON user_medication_feedback(user_id, created_at);
CREATE INDEX idx_user_medication_feedback_user_schedule ON user_medication_feedback(user_id, schedule_time);
CREATE INDEX idx_user_medication_feedback_optimal ON user_medication_feedback(user_id, status, prescription_item_id, created_at DESC);
CREATE INDEX idx_user_medication_feedback_ownership ON user_medication_feedback(feedback_id, user_id);
CREATE INDEX IF NOT EXISTS idx_user_medication_feedback_created_id ON user_medication_feedback(created_id) WHERE created_id IS NOT NULL;


ALTER TABLE user_medication_feedback
    ALTER COLUMN quantity_prescribed TYPE NUMERIC(9, 2) USING quantity_prescribed::NUMERIC(9, 2),
    ALTER COLUMN quantity_taken TYPE NUMERIC(9, 2) USING quantity_taken::NUMERIC(9, 2);

ALTER TABLE user_medication_feedback
ADD CONSTRAINT uq_user_medication_feedback_entry
UNIQUE (user_id, prescription_item_id, schedule_time);


-- Bảng schedule_jobs quản lý danh mục các job thực hiện
-- 1) Bảng lưu cấu hình job định kỳ
CREATE TABLE IF NOT EXISTS schedule_jobs (
  key TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  task TEXT NOT NULL,
  schedule JSONB NOT NULL, -- ví dụ: {"type":"crontab","minute":"*/1"} hoặc {"type":"interval","every":10}
  pattern TEXT,
  queue TEXT NOT NULL DEFAULT 'default',
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  app TEXT,
  description TEXT,
  options JSONB, -- thêm tuỳ chọn Celery nếu cần (ví dụ: countdown, expires, ...)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2) Trigger cập nhật updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_schedule_jobs_updated_at ON schedule_jobs;
CREATE TRIGGER trg_schedule_jobs_updated_at
BEFORE UPDATE ON schedule_jobs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Seed data: Scheduled jobs (from 1_update_schedule_jobs.sql)
INSERT INTO schedule_jobs (key, name, task, schedule, queue, enabled, app, description) VALUES
('poll_sos_expired_countdowns', 'Poll SOS Expired Countdowns', 'app.tasks.sos_tasks.poll_sos_expired_countdowns', '{"type":"interval","every":10}', 'default', TRUE, 'schedule-service', 'Check and complete SOS events with expired countdowns'),
('caregiver_alerts_batch_21h', 'Caregiver Alerts Batch 21h', 'app.tasks.caregiver_alert_tasks.send_daily_caregiver_alerts', '{"type":"crontab","hour":"21","minute":"0"}', 'default', TRUE, 'schedule-service', 'Send daily caregiver alert summaries at 21:00')
ON CONFLICT (key) DO NOTHING;

-- =============================================================================
-- BẢNG PHẢN HỒI KẾT QUẢ TÁI KHÁM (PHIÊN BẢN CẬP NHẬT CHO PHÉP NULL)
-- =============================================================================

CREATE TABLE user_re_examination_feedback ( 
    feedback_id BIGSERIAL PRIMARY KEY,
    
    -- Liên kết đến người dùng và sự kiện tái khám gốc
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    event_id BIGINT,                                  
    
    -- DỮ LIỆU ĐƯỢC "SAO CHÉP" (DENORMALIZED) TỪ re_examination_events
    appointment_date DATE,                            
    appointment_time TIME,
    specialty VARCHAR(150),                           
    doctor_name VARCHAR(100),
    facility_name VARCHAR(200),
    notes TEXT,                                       -- Ghi chú ban đầu (ví dụ: mang theo xét nghiệm)
    exam_date VARCHAR(50),                            -- Ngày khám thực sự (định dạng string, ví dụ: "2025-10-08")
    
    -- ---- THÔNG TIN KẾT QUẢ (ĐÃ GỘP VÀO 1 CỘT JSONB) ----
    re_examination_results JSONB,
    
    -- TRẠNG THÁI CỦA PHẢN HỒI NÀY
    status SMALLINT NOT NULL DEFAULT 0,               -- 0: Chờ phản hồi, 1: Đã phản hồi
    
    -- TIMESTAMPS
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Ràng buộc: Đảm bảo mỗi sự kiện tái khám chỉ có một phản hồi duy nhất từ người dùng (chỉ khi event_id không null).
    -- Cho phép nhiều feedback với event_id null cho cùng một user (standalone feedback)
    CONSTRAINT uq_user_rex_feedback_event UNIQUE (user_id, event_id) DEFERRABLE
);

-- TẠO CÁC INDEX CẦN THIẾT
CREATE INDEX idx_user_rex_feedback_user_id ON user_re_examination_feedback (user_id);
CREATE INDEX idx_user_rex_feedback_event_id ON user_re_examination_feedback (event_id);
CREATE INDEX idx_user_rex_feedback_status ON user_re_examination_feedback (status);
CREATE INDEX idx_user_rex_feedback_user_date ON user_re_examination_feedback (user_id, appointment_date DESC);
-- Index GIN để tìm kiếm hiệu quả bên trong cột JSONB
CREATE INDEX idx_user_rex_feedback_results_gin ON user_re_examination_feedback USING GIN (re_examination_results);

-- KÍCH HOẠT TRIGGER update_updated_at CHO BẢNG MỚI
CREATE TRIGGER trigger_user_rex_feedback_update_updated_at
    BEFORE UPDATE ON user_re_examination_feedback
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

    

-- =============================================================================
-- PHÂN HỆ 4: CHAT, FILE & TƯƠNG TÁC
-- =============================================================================

CREATE TABLE file_function_types (
    function_type_id SMALLINT PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

INSERT INTO file_function_types (function_type_id, type_name, description) VALUES
(1, 'blood_pressure', 'Ảnh kết quả huyết áp'),
(2, 'medicine', 'Ảnh đơn thuốc'),
(3, 're_exam', 'Ảnh kết quả khám bệnh'),
(4, 'avatar', 'Ảnh đại diện'),
(100, 'tts_audio', 'Text-to-speech generated audio files')
ON CONFLICT (function_type_id) DO UPDATE SET
    type_name = EXCLUDED.type_name,
    description = EXCLUDED.description;


CREATE TABLE chat_history
(
    chat_id BIGINT DEFAULT nextval('chat_history_chat_id_seq'::regclass) NOT NULL,
    agent_id VARCHAR(100) NOT NULL,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    question_text TEXT,
    answer_text TEXT,
    "timestamp" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    feedback_id      BIGINT, 
    interaction_type smallint,
    attachments      JSONB        DEFAULT '[]'::jsonb,
    session_id       UUID,
    task_type        VARCHAR(50),
    voice_output TEXT,

    PRIMARY KEY (agent_id, user_id, chat_id),
    CONSTRAINT fk_chat_history_to_feedback FOREIGN KEY (feedback_id) REFERENCES chat_message_feedback(feedback_id) ON DELETE SET NULL
)
PARTITION BY LIST (agent_id);


CREATE SEQUENCE IF NOT EXISTS chat_history_chat_id_seq;
ALTER TABLE chat_history ALTER COLUMN chat_id SET DEFAULT nextval('chat_history_chat_id_seq'::regclass);
CREATE TABLE chat_agent_0_history PARTITION OF chat_history FOR VALUES IN ('agent_0');
CREATE TABLE chat_history_default PARTITION OF chat_history DEFAULT;
CREATE INDEX idx_chat_history_user_timestamp ON chat_history (agent_id, user_id, "timestamp" DESC)
    INCLUDE (question_text, answer_text);
CREATE INDEX idx_chat_history_feedback_id ON chat_history (feedback_id);
DROP INDEX IF EXISTS idx_chat_history_user_timestamp;
CREATE INDEX idx_chat_history_user_timestamp
ON chat_history (agent_id ASC, user_id ASC, timestamp DESC);


CREATE TABLE files (
    file_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    file_path TEXT NOT NULL UNIQUE,
    mime_type VARCHAR(100) NOT NULL,
    file_size_bytes BIGINT,
    function_type_id SMALLINT REFERENCES file_function_types(function_type_id) ON DELETE SET NULL,
    agent_id VARCHAR(100),
    chat_id BIGINT,
    uploaded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status SMALLINT DEFAULT 0, -- 0: PENDING, 1: ACTIVE
    deleted_at TIMESTAMPTZ, -- xoa luc nao
    FOREIGN KEY (agent_id, user_id, chat_id) REFERENCES chat_history(agent_id, user_id, chat_id) ON DELETE CASCADE
);
CREATE INDEX idx_files_user_id ON files (user_id);
CREATE INDEX idx_files_chat_lookup ON files (agent_id, user_id, chat_id) WHERE agent_id IS NOT NULL;
CREATE INDEX idx_files_function_type_id ON files (function_type_id) WHERE function_type_id IS NOT NULL;

ALTER TABLE files
ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;

CREATE TABLE chat_message_feedback (
    feedback_id BIGSERIAL PRIMARY KEY,
    agent_id VARCHAR(100) NOT NULL,
    user_id UUID NOT NULL,
    chat_id BIGINT NOT NULL,
    feedback_type SMALLINT NOT NULL, -- 0: like, 1: dislike
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (agent_id, user_id, chat_id) REFERENCES chat_history(agent_id, user_id, chat_id) ON DELETE CASCADE,
    UNIQUE (agent_id, user_id, chat_id)
);
CREATE INDEX idx_chat_message_feedback_lookup ON chat_message_feedback (agent_id, user_id, chat_id);

CREATE TABLE prompts (
    id SERIAL PRIMARY KEY,
    prompt TEXT NOT NULL,
    agent_id VARCHAR(100) NOT NULL,
    type VARCHAR(20) DEFAULT 'dev' NOT NULL,
    status INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

create table agent_logs
(
    log_id     bigserial primary key,
    agent_id   varchar(255),
    user_id    uuid not null,
    task_id    uuid,
    task_type  varchar(255),
    metadata   text,
    created_at timestamp with time zone default CURRENT_TIMESTAMP
);

-- CREATE TABLE agent_logs (
--     log_id BIGSERIAL,
--     agent_id VARCHAR(100) NOT NULL,
--     user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
--     chat_id BIGINT,
--     log TEXT NOT NULL,
--     token_count INTEGER NOT NULL,
--     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
--     FOREIGN KEY (agent_id, user_id, chat_id) REFERENCES chat_history(agent_id, user_id, chat_id) ON DELETE CASCADE,
--     PRIMARY KEY (log_id, created_at)
-- ) PARTITION BY RANGE (created_at);
-- CREATE INDEX idx_agent_logs_agent_id ON agent_logs (agent_id);
-- CREATE INDEX idx_agent_logs_chat_id ON agent_logs (chat_id) WHERE chat_id IS NOT NULL;
-- CREATE INDEX idx_agent_logs_created_at ON agent_logs (created_at);
-- CREATE TABLE agent_logs_y2025m09 PARTITION OF agent_logs FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
-- CREATE TABLE agent_logs_default PARTITION OF agent_logs DEFAULT;

create table service_logs
(
    log_id       bigserial
        primary key,
    user_id      uuid not null,
    service_name varchar(255),
    log_type     varchar(100),
    metadata     text,
    created_at   timestamp with time zone default CURRENT_TIMESTAMP
);

CREATE TABLE legal_documents (
    id SERIAL PRIMARY KEY,
    doc_type SMALLINT NOT NULL CHECK (doc_type IN (0, 1)), -- 0: privacy_policy, 1: terms_of_service
    version VARCHAR(20) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    effective_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (doc_type, version)
);

COMMENT ON TABLE legal_documents IS 'Lưu trữ các tài liệu pháp lý như Chính sách bảo mật và Điều khoản sử dụng.';
COMMENT ON COLUMN legal_documents.doc_type IS 'Loại tài liệu: 0 (Chính sách bảo mật), 1 (Điều khoản sử dụng).';
COMMENT ON COLUMN legal_documents.version IS 'Số phiên bản của tài liệu.';
COMMENT ON COLUMN legal_documents.effective_date IS 'Ngày tài liệu có hiệu lực.';

CREATE INDEX idx_legal_documents_effective_date ON legal_documents (effective_date);
CREATE INDEX IF NOT EXISTS idx_legal_docs_doc_type_created_at ON legal_documents (doc_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_legal_docs_version_created_at ON legal_documents (version, created_at DESC);

-- =============================================================================
-- PHÂN HỆ 5: THANH TOÁN & GÓI DỊCH VỤ
-- =============================================================================

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'VND',
    type SMALLINT NOT NULL, -- 0: basic, 1: premium, 2: family
    duration_days INT,
    is_active BOOLEAN DEFAULT TRUE,
    features JSONB
);
CREATE INDEX idx_products_type ON products (type);

CREATE TABLE invite_codes (
    invite_code VARCHAR(20) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    product_id INT REFERENCES products(product_id) ON DELETE SET NULL,
    max_uses INT DEFAULT 0,
    used_count INT DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_invite_codes_user_id ON invite_codes (user_id);
CREATE INDEX idx_invite_codes_expires_at ON invite_codes (expires_at) WHERE expires_at IS NOT NULL;

CREATE TABLE invite_referrals (
    referral_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_code VARCHAR(20) NOT NULL REFERENCES invite_codes(invite_code) ON DELETE CASCADE,
    referrer_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    referred_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reward_type VARCHAR(50),
    reward_value NUMERIC(12, 2),
    status SMALLINT DEFAULT 0, -- 0: Chưa xử lý, 1: Đang xử lý, 2: Đã xử lý
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (invite_code, referred_user_id)
);
CREATE INDEX idx_invite_referrals_referrer_user_id ON invite_referrals (referrer_user_id);
CREATE INDEX idx_invite_referrals_referred_user_id ON invite_referrals (referred_user_id);

CREATE TABLE subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_subscriptions_user_id ON subscriptions (user_id);
CREATE INDEX idx_subscriptions_active ON subscriptions (user_id, product_id, status) WHERE (status = 'active');

CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id),
    amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_orders_user_id ON orders (user_id);

CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    payment_gateway VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    transaction_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_transactions_order_id ON transactions (order_id);

-- =============================================================================
-- PHÂN HỆ 7: GAMEFI
-- =============================================================================

CREATE TABLE game_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    current_coins INTEGER NOT NULL DEFAULT 0,
    current_love_points INTEGER NOT NULL DEFAULT 0,
    alio_happiness_level SMALLINT NOT NULL DEFAULT 2,
    alio_state_json JSONB NOT NULL DEFAULT '{"hunger": 100, "sleep": 100, "energy": 100}'::jsonb,
    tree_growth_stage INTEGER NOT NULL DEFAULT 1,
    tree_health_status SMALLINT NOT NULL DEFAULT 1,
    tree_appearance_json JSONB NOT NULL DEFAULT '{"decorations": [], "color": "green"}'::jsonb,
    last_alio_interaction_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_game_profiles_user_id ON game_profiles(user_id);
CREATE INDEX idx_game_profiles_alio_happiness ON game_profiles(alio_happiness_level);
CREATE INDEX idx_game_profiles_tree_health ON game_profiles(tree_health_status);
CREATE INDEX idx_game_profiles_last_interaction ON game_profiles(last_alio_interaction_time);
CREATE INDEX idx_game_profiles_alio_state ON game_profiles USING GIN (alio_state_json);
CREATE INDEX idx_game_profiles_tree_appearance ON game_profiles USING GIN (tree_appearance_json);

CREATE TABLE mission_definitions (
    id SERIAL PRIMARY KEY,
    mission_name VARCHAR(255) NOT NULL,
    mission_description TEXT NOT NULL,
    category SMALLINT NOT NULL, --1. Nhóm nhiệm vụ hệ thống, 2. Nhóm nhiệm vụ tuân thủ, 3. Nhóm nhiệm vụ thay đổi lối sống, 4. Nhóm nhiệm vụ vận động, 5. Nhóm nhiệm vụ sức khoẻ tinh thần, 6. Nhóm nhiệm vụ giáo dục, 7. Nhóm nhiệm vụ cộng đồng
    base_coins_reward INTEGER NOT NULL DEFAULT 10,
    base_love_points_reward INTEGER NOT NULL DEFAULT 5,
    target_type VARCHAR(100) NOT NULL,
    default_target_value JSONB NOT NULL DEFAULT '{"value": 1}'::jsonb,
    unlock_criteria JSONB,
    associated_game_actions JSONB,
    information JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_mission_definitions_category ON mission_definitions(category);
CREATE INDEX idx_mission_definitions_active ON mission_definitions(is_active) WHERE is_active = true;
CREATE INDEX idx_mission_definitions_unlock_criteria ON mission_definitions USING GIN (unlock_criteria);
CREATE INDEX idx_mission_definitions_game_actions ON mission_definitions USING GIN (associated_game_actions);

CREATE TABLE user_missions (
    id BIGSERIAL,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    mission_definition_id INTEGER NOT NULL REFERENCES mission_definitions(id),
    assigned_date DATE NOT NULL,
    personalized_target JSONB NOT NULL DEFAULT '{"value": 0}'::jsonb,
    current_progress JSONB NOT NULL DEFAULT '{"value": 0}'::jsonb,
    -- Trường 'status' mới được thêm vào
    status SMALLINT NOT NULL DEFAULT 0, -- Trạng thái nhiệm vụ: 0: ĐANG DIỄN RA, 1: ĐÃ HOÀN THÀNH, 2: ĐÃ HẾT HẠN, 3: THẤT BẠI
    is_completed BOOLEAN NOT NULL DEFAULT false,
    completed_at TIMESTAMPTZ,
    coins_earned INTEGER NOT NULL DEFAULT 0,
    love_points_earned INTEGER NOT NULL DEFAULT 0,
    display_priority INTEGER DEFAULT 999 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, assigned_date),
    -- Ràng buộc kiểm tra giá trị của cột 'status'
    CONSTRAINT chk_user_mission_status CHECK (status IN (0, 1, 2, 3)),
    -- Ràng buộc kiểm tra sự nhất quán giữa 'status' và 'is_completed'
    CONSTRAINT chk_completion_status_consistency CHECK (
        (is_completed = TRUE AND status = 1) OR
        (is_completed = FALSE AND status IN (0, 2, 3))
    )

    -- Thêm unique constraint để ngăn chặn duplicate ở database level
    CONSTRAINT uk_user_missions_user_def_date UNIQUE (user_id, mission_definition_id, assigned_date);
) PARTITION BY RANGE (assigned_date);

COMMENT ON COLUMN user_missions.status IS 'Trạng thái hiện tại của nhiệm vụ: 0 (Đang diễn ra), 1 (Đã hoàn thành), 2 (Đã hết hạn), 3 (Thất bại).';

-- Các chỉ mục hiện có 
CREATE INDEX idx_user_missions_user_date ON user_missions(user_id, assigned_date);
CREATE INDEX idx_user_missions_completion ON user_missions(user_id, is_completed, assigned_date);
CREATE INDEX idx_user_missions_definition ON user_missions(mission_definition_id, assigned_date);

-- Chỉ mục mới có thể được thêm để tối ưu truy vấn theo trạng thái
CREATE INDEX idx_user_missions_status ON user_missions(user_id, status, assigned_date);

ALTER TABLE user_missions
ADD CONSTRAINT user_missions_user_mission_date_unique
UNIQUE (user_id, mission_definition_id, assigned_date);

-- Các phân vùng hiện có 
CREATE TABLE user_missions_y2025m08 PARTITION OF user_missions FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE user_missions_default PARTITION OF user_missions DEFAULT;

CREATE TABLE user_streaks (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    streak_type SMALLINT NOT NULL,
    current_streak_count INTEGER NOT NULL DEFAULT 0,
    longest_streak_count INTEGER NOT NULL DEFAULT 0,
    last_activity_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    start_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, streak_type)
);
CREATE INDEX idx_user_streaks_user_type ON user_streaks(user_id, streak_type);
CREATE INDEX idx_user_streaks_activity_date ON user_streaks(last_activity_date);

-- Create indexes for better query performance
CREATE INDEX idx_user_streaks_is_active ON user_streaks(is_active) WHERE is_active = true;
CREATE INDEX idx_user_streaks_start_date ON user_streaks(start_date);

CREATE TABLE game_actions (
    id SERIAL PRIMARY KEY,
    action_name VARCHAR(255) NOT NULL,
    action_description TEXT NOT NULL,
    action_type VARCHAR(100) NOT NULL,
    unlock_criteria JSONB,
    base_coins_reward INTEGER NOT NULL DEFAULT 5,
    base_love_points_reward INTEGER NOT NULL DEFAULT 2,
    cooldown_minutes INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_game_actions_type ON game_actions(action_type);
CREATE INDEX idx_game_actions_active ON game_actions(is_active) WHERE is_active = true;
CREATE INDEX idx_game_actions_unlock_criteria ON game_actions USING GIN (unlock_criteria);

CREATE TABLE user_game_actions_log (
    id BIGSERIAL,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    game_action_id INTEGER NOT NULL REFERENCES game_actions(id),
    action_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    coins_received INTEGER NOT NULL DEFAULT 0,
    love_points_received INTEGER NOT NULL DEFAULT 0,
    game_items_received JSONB,
    alio_state_before JSONB,
    alio_state_after JSONB,
    tree_state_before JSONB,
    tree_state_after JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, action_time)
) PARTITION BY RANGE (action_time);
CREATE INDEX idx_user_game_actions_user_time ON user_game_actions_log(user_id, action_time);
CREATE INDEX idx_user_game_actions_action_id ON user_game_actions_log(game_action_id, action_time);
CREATE TABLE user_game_actions_log_y2025m09 PARTITION OF user_game_actions_log FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE user_game_actions_log_default PARTITION OF user_game_actions_log DEFAULT;

CREATE TABLE game_items (
    id SERIAL PRIMARY KEY,
    item_name VARCHAR(255) NOT NULL,
    item_description TEXT NOT NULL,
    item_type SMALLINT NOT NULL,
    rarity VARCHAR(50) NOT NULL DEFAULT 'common',
    coins_cost INTEGER NOT NULL DEFAULT 0,
    love_points_cost INTEGER NOT NULL DEFAULT 0,
    item_effects_json JSONB,
    is_tradeable BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_game_items_type ON game_items(item_type);
CREATE INDEX idx_game_items_rarity ON game_items(rarity);
CREATE INDEX idx_game_items_active ON game_items(is_active) WHERE is_active = true;
CREATE INDEX idx_game_items_effects ON game_items USING GIN (item_effects_json);

CREATE TABLE user_game_inventory (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    game_item_id INTEGER NOT NULL REFERENCES game_items(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    acquired_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, game_item_id)
);
CREATE INDEX idx_user_game_inventory_user ON user_game_inventory(user_id);
CREATE INDEX idx_user_game_inventory_item ON user_game_inventory(game_item_id);

CREATE TABLE user_posts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    post_content TEXT NOT NULL,
    post_type VARCHAR(50) NOT NULL DEFAULT 'achievement',
    status SMALLINT NOT NULL DEFAULT 0,
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    moderation_notes TEXT,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_user_posts_user_status ON user_posts(user_id, status);
CREATE INDEX idx_user_posts_status_published ON user_posts(status, published_at) WHERE status = 1;
CREATE INDEX idx_user_posts_type ON user_posts(post_type);

CREATE TABLE post_interactions (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL REFERENCES user_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL,
    comment_text TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id, interaction_type)
);
CREATE INDEX idx_post_interactions_post ON post_interactions(post_id);
CREATE INDEX idx_post_interactions_user ON post_interactions(user_id);
CREATE INDEX idx_post_interactions_type ON post_interactions(interaction_type);

CREATE TABLE charity_campaigns (
    id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(255) NOT NULL,
    campaign_description TEXT NOT NULL,
    target_coins INTEGER NOT NULL,
    current_coins_raised INTEGER NOT NULL DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    start_date DATE NOT NULL,
    end_date DATE,
    beneficiary_info JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_charity_campaigns_status ON charity_campaigns(status);
CREATE INDEX idx_charity_campaigns_dates ON charity_campaigns(start_date, end_date);
CREATE INDEX idx_charity_campaigns_beneficiary ON charity_campaigns USING GIN (beneficiary_info);

CREATE TABLE user_charity_contributions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    charity_campaign_id INTEGER NOT NULL REFERENCES charity_campaigns(id),
    coins_donated INTEGER NOT NULL,
    love_points_bonus INTEGER NOT NULL DEFAULT 0,
    donation_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_user_charity_contributions_user ON user_charity_contributions(user_id);
CREATE INDEX idx_user_charity_contributions_campaign ON user_charity_contributions(charity_campaign_id);

-- =============================================================================
-- PHÂN HỆ 6: ĐỊA LÝ & THÔNG TIN CHUNG (TIẾP TỤC)
-- =============================================================================

CREATE TABLE user_location (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    current_latitude DOUBLE PRECISION,
    current_longitude DOUBLE PRECISION,
    current_location_timestamp TIMESTAMPTZ,
    last_latitude DOUBLE PRECISION,
    last_longitude DOUBLE PRECISION,
    last_location_timestamp TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE annual_events (
    event_id SERIAL PRIMARY KEY,
    event_name TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    location_name TEXT,
    address TEXT,
    city TEXT,
    country TEXT,
    event_type TEXT,
    organizer TEXT
);

CREATE TABLE weather_daily (
    date DATE NOT NULL,
    province_id INT REFERENCES provinces(id),
    city TEXT NOT NULL,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    is_dangerous BOOLEAN,
    danger_type TEXT,
    aqi_value INTEGER,
    aqi_level TEXT,
    storm_flag BOOLEAN,
    current_temp NUMERIC(4, 1),
    yesterday_avg_temp NUMERIC(4, 1),
    temp_diff NUMERIC(4, 1),
    change_type TEXT,
    source TEXT,
    raw_response JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date, province_id)
);
CREATE INDEX idx_weather_daily_date ON weather_daily (date);
CREATE INDEX idx_weather_daily_city ON weather_daily (city);
CREATE INDEX idx_weather_daily_province ON weather_daily (province_id);

-- =============================================================================
-- BƯỚC 3: KÍCH HOẠT CÁC TRIGGER
-- =============================================================================

CREATE TRIGGER trigger_users_update_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE user_completed_one_time_missions (
    user_id VARCHAR(36) NOT NULL,
    mission_id VARCHAR(255) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, mission_id)
);

COMMENT ON TABLE user_completed_one_time_missions IS 'Records the completion of missions that can only be performed once by a user.';
COMMENT ON COLUMN user_completed_one_time_missions.user_id IS 'The UUID of the user.';
COMMENT ON COLUMN user_completed_one_time_missions.mission_id IS 'The unique identifier for the one-time mission.';
COMMENT ON COLUMN user_completed_one_time_missions.completed_at IS 'Timestamp of when the mission was completed.';


CREATE TABLE user_potential_mission_targets_by_mood (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    mission_definition_id INTEGER NOT NULL REFERENCES mission_definitions(id) ON DELETE CASCADE,
    mood_state SMALLINT NOT NULL CHECK (mood_state BETWEEN 1 AND 5), -- 1:tuyệt vời, 2:tốt, 3:bình thường, 4:hơi mệt, 5:không khỏe (tương ứng với users.feeling) [1]
    potential_target_value JSONB NOT NULL DEFAULT '{"value": 0}'::jsonb, -- Giá trị mục tiêu tiềm năng cho trạng thái cảm xúc này
    -- *** TRƯỜNG MỚI ĐƯỢC THÊM VÀO ***
    calculation_date DATE NOT NULL, -- Ngày mà giá trị 'potential_target_value' này được tính toán và tạo ra
    -- ********************************
    calculation_parameters JSONB, -- (Tùy chọn) Lưu trữ các tham số đã dùng bởi AGSA/DDA để tính toán giá trị này (vd: cân nặng, chiều cao, HA, v.v.) [5, 6]
    display_priority SMALLINT NOT NULL DEFAULT 1, -- Ưu tiên hiển thị trong danh sách mục tiêu tiềm năng (0: không hiển thị, 1: hiển thị)
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, mission_definition_id, mood_state, calculation_date) -- Đảm bảo mỗi người dùng chỉ có một mục tiêu tiềm năng duy nhất cho mỗi nhiệm vụ, trạng thái cảm xúc và ngày tính toán cụ thể.
);

COMMENT ON TABLE user_potential_mission_targets_by_mood IS 'Lưu trữ các giá trị mục tiêu tiềm năng được cá nhân hóa cho người dùng, dựa trên từng định nghĩa nhiệm vụ, trạng thái cảm xúc và ngày tính toán.';
COMMENT ON COLUMN user_potential_mission_targets_by_mood.user_id IS 'ID của người dùng.';
COMMENT ON COLUMN user_potential_mission_targets_by_mood.mission_definition_id IS 'ID của định nghĩa nhiệm vụ chung.';
COMMENT ON COLUMN user_potential_mission_targets_by_mood.mood_state IS 'Trạng thái cảm xúc của người dùng (tương ứng với users.feeling).';
COMMENT ON COLUMN user_potential_mission_targets_by_mood.potential_target_value IS 'Giá trị mục tiêu tiềm năng được tính toán cho nhiệm vụ và trạng thái cảm xúc cụ thể này.';
COMMENT ON COLUMN user_potential_mission_targets_by_mood.calculation_date IS 'Ngày mà mục tiêu tiềm năng này được tính toán và có hiệu lực.';
COMMENT ON COLUMN user_potential_mission_targets_by_mood.calculation_parameters IS 'Các tham số chi tiết được sử dụng trong thuật toán AGSA/DDA để tính toán giá trị mục tiêu này.';


ALTER TABLE user_potential_mission_targets_by_mood
  ADD CONSTRAINT uq_upmtbm UNIQUE (user_id, mission_definition_id, mood_state, calculation_date);

-- Indexes để tối ưu truy vấn
CREATE INDEX idx_user_potential_targets_user_mission_date ON user_potential_mission_targets_by_mood (user_id, mission_definition_id, calculation_date);
CREATE INDEX idx_user_potential_targets_mood_date ON user_potential_mission_targets_by_mood (mood_state, calculation_date);



-- Migration V9: Add status field to user_potential_mission_targets_by_mood table
-- Purpose: Track active/inactive status of potential mission targets
-- Status values: 1 = active, 2 = inactive

BEGIN;

-- Add status column with default value 1 (active)
ALTER TABLE user_potential_mission_targets_by_mood 
    ADD COLUMN status SMALLINT NOT NULL DEFAULT 1 CHECK (status IN (1, 2));

-- Add comment for the new column
COMMENT ON COLUMN user_potential_mission_targets_by_mood.status IS 'Trạng thái của potential target: 1=active, 2=inactive';

-- Create index for status column to optimize queries
CREATE INDEX idx_user_potential_targets_status ON user_potential_mission_targets_by_mood (status);

-- Create composite index for common query patterns
CREATE INDEX idx_user_potential_targets_user_status_date ON user_potential_mission_targets_by_mood (user_id, status, calculation_date);

COMMIT;

-- =============================================================================
-- SURVEY
-- =============================================================================

CREATE TABLE survey_topics (
    topic_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Mã định danh duy nhất cho chủ đề, sử dụng UUID để tránh đoán ID tuần tự [5].
    topic_name VARCHAR(255) NOT NULL UNIQUE, -- Tên chủ đề khảo sát, ví dụ "Sức khỏe tinh thần".
    description TEXT, -- Mô tả chi tiết về chủ đề.
    is_active BOOLEAN DEFAULT TRUE, -- Trạng thái hoạt động của chủ đề.
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE survey_topics IS 'Lưu trữ danh sách các chủ đề khảo sát khác nhau.';
COMMENT ON COLUMN survey_topics.topic_id IS 'Mã định danh duy nhất cho chủ đề khảo sát.';
COMMENT ON COLUMN survey_topics.topic_name IS 'Tên của chủ đề khảo sát (ví dụ: Sức khỏe tinh thần, Thói quen dinh dưỡng).';
COMMENT ON COLUMN survey_topics.description IS 'Mô tả chi tiết về chủ đề.';
COMMENT ON COLUMN survey_topics.is_active IS 'Trạng thái hoạt động của chủ đề khảo sát.';

CREATE INDEX idx_survey_topics_name ON survey_topics (topic_name);
CREATE INDEX idx_survey_topics_active ON survey_topics (is_active) WHERE is_active = true;

-- Tạo function để tự động cập nhật updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Kích hoạt trigger tự động cập nhật updated_at
CREATE TRIGGER trigger_survey_topics_update_updated_at
BEFORE UPDATE ON survey_topics
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();



CREATE TABLE survey_tasks (
    survey_task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Mã định danh duy nhất cho nhiệm vụ khảo sát, sử dụng UUID [5].
    topic_id UUID NOT NULL REFERENCES survey_topics(topic_id) ON DELETE CASCADE, -- Khóa ngoại liên kết với bảng chủ đề khảo sát.
    task_name VARCHAR(255) NOT NULL, -- Tên ngắn gọn của nhiệm vụ/câu hỏi (ví dụ: "Đánh giá mức độ hài lòng về ứng dụng").
    question_text TEXT NOT NULL, -- Nội dung câu hỏi hoặc hướng dẫn cho nhiệm vụ.
    task_type SMALLINT NOT NULL, -- Loại nhiệm vụ khảo sát để xác định cách thu thập phản hồi (ví dụ: 0: text_input, 1: numeric_input, 2: boolean_input, 3: single_choice, 4: multi_choice, 5: rating_scale, 6: date_input, 7: time_input, 8:single_choice_grid), sử dụng SMALLINT để tối ưu kiểu dữ liệu [4].
    options_json JSONB, -- Lưu trữ các lựa chọn (cho single/multi_choice) hoặc khoảng giá trị (cho numeric/rating). Sử dụng JSONB cho dữ liệu cấu trúc linh hoạt và tối ưu truy vấn với GIN Index [6].
    expected_response_format VARCHAR(50), -- Định dạng phản hồi mong đợi (ví dụ: 'TEXT', 'INTEGER', 'BOOLEAN', 'ARRAY_OF_STRINGS').
    frequency_type SMALLINT DEFAULT 0, -- Tần suất nhiệm vụ được đề xuất (0: one_time, 1: daily, 2: weekly, 3: monthly, 4: ad_hoc).
    is_active BOOLEAN DEFAULT TRUE, -- Trạng thái hoạt động của nhiệm vụ khảo sát.
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    targeting_rules JSONB DEFAULT NULL
);

COMMENT ON TABLE survey_tasks IS 'Định nghĩa các nhiệm vụ khảo sát chi tiết theo chủ đề, bao gồm câu hỏi và cấu trúc phản hồi.';
COMMENT ON COLUMN survey_tasks.survey_task_id IS 'Mã định danh duy nhất cho nhiệm vụ khảo sát.';
COMMENT ON COLUMN survey_tasks.topic_id IS 'Khóa ngoại liên kết với bảng chủ đề khảo sát.';
COMMENT ON COLUMN survey_tasks.task_name IS 'Tên ngắn gọn, dễ hiểu của nhiệm vụ khảo sát.';
COMMENT ON COLUMN survey_tasks.question_text IS 'Nội dung câu hỏi hoặc hướng dẫn cho nhiệm vụ.';
COMMENT ON COLUMN survey_tasks.task_type IS 'Loại nhiệm vụ khảo sát (ví dụ: nhập văn bản, chọn một, thang điểm).';
COMMENT ON COLUMN survey_tasks.options_json IS 'Cấu hình các tùy chọn cho nhiệm vụ (ví dụ: danh sách lựa chọn, giới hạn giá trị).';
COMMENT ON COLUMN survey_tasks.expected_response_format IS 'Định dạng dữ liệu mong đợi từ phản hồi của người dùng.';
COMMENT ON COLUMN survey_tasks.frequency_type IS 'Tần suất nhiệm vụ được đề xuất (ví dụ: một lần, hàng ngày).';
COMMENT ON COLUMN survey_tasks.is_active IS 'Trạng thái hoạt động của nhiệm vụ khảo sát.';

CREATE INDEX idx_survey_tasks_topic_id ON survey_tasks (topic_id);
CREATE INDEX idx_survey_tasks_type ON survey_tasks (task_type);
CREATE INDEX idx_survey_tasks_active ON survey_tasks (is_active) WHERE is_active = TRUE;
CREATE INDEX idx_survey_tasks_options_gin ON survey_tasks USING GIN (options_json);

-- Kích hoạt trigger tự động cập nhật updated_at
CREATE TRIGGER trigger_survey_tasks_update_updated_at
BEFORE UPDATE ON survey_tasks
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


CREATE TABLE user_survey_responses (
    response_id BIGSERIAL, -- Mã định danh duy nhất cho phản hồi khảo sát của người dùng. Sử dụng BIGSERIAL và partitioning cho các bảng lớn [4].
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE, -- Khóa ngoại liên kết với bảng người dùng [8].
    survey_task_id UUID NOT NULL REFERENCES survey_tasks(survey_task_id) ON DELETE CASCADE, -- Khóa ngoại liên kết với bảng nhiệm vụ khảo sát.
    user_mission_id BIGINT NOT NULL, -- **KHÓA NGOẠI MỚI**: Liên kết đến phiên bản nhiệm vụ GameFi cụ thể mà khảo sát này thuộc về [2].
    response_date DATE, -- Ngày nhiệm vụ khảo sát được thực hiện, có thể null khi chưa hoàn thành. Dùng làm khóa phân vùng với giá trị mặc định [2, 7, 9].
    response_data JSONB, -- Dữ liệu phản hồi thực tế của người dùng, có thể null khi chưa hoàn thành. Linh hoạt với JSONB để phù hợp với các loại câu hỏi khác nhau [6].
    status SMALLINT DEFAULT 0, -- Trạng thái thực hiện nhiệm vụ (0: chưa thực hiện, 1: đang thực hiện, 2: đã hoàn thành).
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE, -- Ngày được giao nhiệm vụ, dùng làm partition key thay thế cho response_date.

    feedback_extra_content TEXT,
	created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (response_id, assigned_date) -- Khóa chính kết hợp để hỗ trợ phân vùng theo assigned_date.
) PARTITION BY RANGE (assigned_date); -- Phân vùng theo ngày được giao nhiệm vụ để tối ưu hiệu năng và quản lý dữ liệu [7].

COMMENT ON TABLE user_survey_responses IS 'Lưu trữ phản hồi của người dùng đối với các nhiệm vụ khảo sát được giao.';
COMMENT ON COLUMN user_survey_responses.response_id IS 'Mã định danh duy nhất cho phản hồi khảo sát của người dùng.';
COMMENT ON COLUMN user_survey_responses.user_id IS 'Khóa ngoại liên kết với bảng người dùng.';
COMMENT ON COLUMN user_survey_responses.survey_task_id IS 'Khóa ngoại liên kết với bảng nhiệm vụ khảo sát.';
COMMENT ON COLUMN user_survey_responses.user_mission_id IS 'Khóa ngoại liên kết với phiên nhiệm vụ người dùng (user_missions) mà khảo sát này thuộc về.';
COMMENT ON COLUMN user_survey_responses.response_date IS 'Ngày nhiệm vụ khảo sát được thực hiện, có thể null khi chưa hoàn thành.';
COMMENT ON COLUMN user_survey_responses.response_data IS 'Dữ liệu phản hồi chi tiết từ người dùng, có thể null khi chưa hoàn thành (ví dụ: câu trả lời, giá trị nhập, lựa chọn).';
COMMENT ON COLUMN user_survey_responses.assigned_date IS 'Ngày được giao nhiệm vụ khảo sát, dùng làm khóa phân vùng.';

CREATE INDEX idx_user_survey_responses_user_assigned ON user_survey_responses (user_id, assigned_date DESC);
CREATE INDEX idx_user_survey_responses_user_response_date ON user_survey_responses (user_id, response_date DESC) WHERE response_date IS NOT NULL;
CREATE INDEX idx_user_survey_responses_task_id ON user_survey_responses (survey_task_id);
CREATE INDEX idx_user_survey_responses_user_mission_id ON user_survey_responses (user_mission_id);
CREATE INDEX idx_user_survey_responses_status ON user_survey_responses (status);
CREATE INDEX idx_user_survey_responses_data_gin ON user_survey_responses USING GIN (response_data) WHERE response_data IS NOT NULL; -- Tối ưu tìm kiếm trong dữ liệu JSONB [6].

-- Tạo các phân vùng mẫu cho bảng user_survey_responses, tương tự `login_attempts_y2025m08` và `user_missions_y2025m08` [9, 10].
CREATE TABLE user_survey_responses_y2025m08 PARTITION OF user_survey_responses
FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE user_survey_responses_default PARTITION OF user_survey_responses DEFAULT;

-- Lưu ý: user_mission_id liên kết với user_missions.id
-- Do user_missions có composite primary key (id, assigned_date), 
-- không thể tạo foreign key constraint trực tiếp
-- Ứng dụng cần đảm bảo tính toàn vẹn dữ liệu ở tầng logic

-- Kích hoạt trigger tự động cập nhật updated_at
CREATE TRIGGER trigger_user_survey_responses_update_updated_at
BEFORE UPDATE ON user_survey_responses
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- Bảng danh mục triệu chứng và nhật ký triệu chứng người dùng theo thời gian
-- Removed symptom_definitions: use free-text symptom_name directly in user_symptoms

CREATE TABLE user_symptoms (
    symptom_log_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    symptom_name TEXT NOT NULL, -- Tên triệu chứng, ví dụ: 'Đau đầu', 'Chóng mặt', 'Hoa mắt', 'Mệt mỏi'
    severity_level SMALLINT, -- Mức độ nghiêm trọng (thang đo tùy chọn)
    symptom_type VARCHAR(150), -- Loại triệu chứng: physical, psychological, gastrointestinal, respiratory, cardiovascular, neurological, general
    start_time TIMESTAMPTZ NOT NULL, -- Thời điểm bắt đầu xuất hiện triệu chứng
    end_time TIMESTAMPTZ, -- Thời điểm kết thúc, có thể là NULL nếu đang diễn ra
    duration JSONB, -- JSON lưu thời lượng và đơn vị, ví dụ: {"value": 30, "unit": "minutes"} hoặc {"value": 2, "unit": "days"}
    triggers JSONB, -- Các yếu tố nghi ngờ gây ra triệu chứng, ví dụ: '["căng thẳng", "thiếu ngủ", "ăn mặn"]'
    notes TEXT, -- Ghi chú chi tiết của người dùng
    recorded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Thời điểm bản ghi được tạo
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CHECK (end_time IS NULL OR end_time >= start_time)
);
-- Index phục vụ truy vấn lịch sử theo thời gian và theo tên triệu chứng
CREATE INDEX idx_user_symptoms_user_start_time ON user_symptoms (user_id, start_time DESC);
CREATE INDEX idx_user_symptoms_user_symptom_name ON user_symptoms (user_id, symptom_name);
CREATE INDEX idx_user_symptoms_type_status ON user_symptoms (user_id, symptom_type);

-- Trigger cập nhật updated_at khi update user_symptoms
CREATE OR REPLACE FUNCTION update_timestamp_user_symptoms()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_user_symptoms_timestamp
BEFORE UPDATE ON user_symptoms
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_user_symptoms();

CREATE TABLE report_periodic (
    report_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status SMALLINT DEFAULT 1 NOT NULL, --  1: Hoạt động, 0: Ẩn/Lưu trữ
    report_type SMALLINT DEFAULT 1 NOT NULL, -- 1: Tuần, 2: Tháng
    
    -- THÔNG TIN CỐ ĐỊNH CỦA BÁO CÁO
    user_info JSONB NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- DỮ LIỆU TỔNG HỢP
    user_blood_pressure_info JSONB,
    user_symptoms_info JSONB,
    agent_summary JSONB,
    additional_info JSONB, 
    
    -- TIMESTAMPS
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Ràng buộc đảm bảo ngày kết thúc không thể trước ngày bắt đầu
    CONSTRAINT chk_report_date_range CHECK (end_date >= start_date),

    -- Ràng buộc UNIQUE
    CONSTRAINT uq_report_periodic_user_period UNIQUE (user_id, start_date, end_date)
);

-- TẠO CÁC INDEX CẦN THIẾT
CREATE INDEX idx_report_periodic_user_date_range ON report_periodic (user_id, start_date DESC, end_date DESC);
CREATE INDEX idx_report_periodic_status ON report_periodic (status);
CREATE INDEX idx_report_periodic_user_info_gin ON report_periodic USING GIN (user_info);
CREATE INDEX idx_report_periodic_agent_summary_gin ON report_periodic USING GIN (agent_summary);

-- KÍCH HOẠT TRIGGER TỰ ĐỘNG CẬP NHẬT updated_at
CREATE TRIGGER trigger_report_periodic_update_updated_at
    BEFORE UPDATE ON report_periodic
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TABLE: caregiver_report_views (v2.11 - KOLIA-1517)
-- Purpose: Track which reports have been read by which caregiver (BR-RPT-001)
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS caregiver_report_views (
    id BIGSERIAL PRIMARY KEY,
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    report_id BIGINT NOT NULL REFERENCES report_periodic(report_id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint: 1 caregiver can only mark 1 report as read once
    CONSTRAINT idx_unique_caregiver_report UNIQUE (caregiver_id, report_id)
);

-- Indexes for efficient lookup
CREATE INDEX IF NOT EXISTS idx_crv_caregiver_id ON caregiver_report_views(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_crv_report_id ON caregiver_report_views(report_id);

COMMENT ON TABLE caregiver_report_views IS 'Track report read status per caregiver for Dashboard feature (BR-RPT-001)';
COMMENT ON COLUMN caregiver_report_views.viewed_at IS 'When the caregiver first viewed this report';

-- =============================================================================
-- MIGRATION: Create Symptom Extraction Tracking Table
-- Purpose: Track which chat messages have been analyzed for each user
-- =============================================================================

-- Bảng tracking để đánh dấu message đã phân tích
CREATE TABLE IF NOT EXISTS symptom_extraction_tracking (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Mốc đánh dấu: chat_id cuối cùng đã phân tích
    last_analyzed_chat_id BIGINT NOT NULL DEFAULT 0,
    
    -- Timestamp của message cuối cùng đã phân tích
    last_analyzed_timestamp TIMESTAMPTZ,
    
    -- Số lượng messages đã phân tích trong lần chạy cuối
    last_analyzed_count INTEGER DEFAULT 0,
    
    -- Số triệu chứng tìm thấy trong lần chạy cuối
    last_symptoms_found INTEGER DEFAULT 0,
    
    -- Thời gian chạy phân tích lần cuối
    last_run_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Index cho performance
CREATE INDEX IF NOT EXISTS idx_symptom_tracking_last_run 
ON symptom_extraction_tracking (last_run_at DESC);

CREATE INDEX IF NOT EXISTS idx_symptom_tracking_last_chat 
ON symptom_extraction_tracking (last_analyzed_chat_id);

-- Trigger tự động cập nhật updated_at
CREATE OR REPLACE FUNCTION update_symptom_tracking_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_symptom_tracking_update ON symptom_extraction_tracking;
CREATE TRIGGER trg_symptom_tracking_update
    BEFORE UPDATE ON symptom_extraction_tracking
    FOR EACH ROW
    EXECUTE FUNCTION update_symptom_tracking_timestamp();

-- Comments
COMMENT ON TABLE symptom_extraction_tracking IS 
'Bảng tracking để đánh dấu các chat message đã được phân tích trích xuất triệu chứng, tránh phân tích lại.';

COMMENT ON COLUMN symptom_extraction_tracking.last_analyzed_chat_id IS 
'Chat ID lớn nhất đã được phân tích. Các chat mới sẽ có ID lớn hơn giá trị này.';

COMMENT ON COLUMN symptom_extraction_tracking.last_analyzed_timestamp IS 
'Timestamp của chat message cuối cùng đã phân tích.';
-- =============================================================================
-- 1. APPLICATION SETTINGS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS application_settings (
    setting_id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_name VARCHAR(255) NOT NULL,
    setting_value JSONB NOT NULL,
    value_type VARCHAR(50) NOT NULL, -- string, number, boolean, json, array
    category VARCHAR(100), -- General, Security, Performance, UI, etc.
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE, -- Whether this setting can be accessed by clients
    validation_rules JSONB, -- Rules for validating the value
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_application_settings_key ON application_settings (setting_key);
CREATE INDEX idx_application_settings_category ON application_settings (category);
CREATE INDEX idx_application_settings_public ON application_settings (is_public) WHERE is_public = TRUE;

COMMENT ON TABLE application_settings IS 'Dynamic application configuration settings';
COMMENT ON COLUMN application_settings.is_public IS 'If true, setting can be accessed by client applications';

-- =============================================================================
-- 2. NOTIFICATION TEMPLATES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS notification_templates (
    template_id SERIAL PRIMARY KEY,
    template_key VARCHAR(100) NOT NULL UNIQUE,
    template_name VARCHAR(255) NOT NULL,
    category VARCHAR(100), -- medication, health, gamefi, system, etc.
    title_template TEXT NOT NULL, -- Template with placeholders: "Hello {{user_name}}"
    message_template TEXT NOT NULL,
    notification_type SMALLINT NOT NULL, -- 0: email, 1: sms, 2: push, 3: in_app
    priority SMALLINT DEFAULT 1, -- 1-5
    variables JSONB, -- Available variables: ["user_name", "mission_name", etc.]
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB, -- Additional template metadata
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notification_templates_key ON notification_templates (template_key);
CREATE INDEX idx_notification_templates_category ON notification_templates (category);
CREATE INDEX idx_notification_templates_type ON notification_templates (notification_type);
CREATE INDEX idx_notification_templates_active ON notification_templates (is_active) WHERE is_active = TRUE;

COMMENT ON TABLE notification_templates IS 'Templates for system notifications';
COMMENT ON COLUMN notification_templates.variables IS 'List of available placeholder variables for this template';

-- =============================================================================
-- 3. LOCALIZATION TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS localization_keys (
    key_id SERIAL PRIMARY KEY,
    key_name VARCHAR(255) NOT NULL UNIQUE,
    category VARCHAR(100), -- ui, messages, errors, etc.
    default_value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS localization_translations (
    translation_id SERIAL PRIMARY KEY,
    key_id INTEGER NOT NULL REFERENCES localization_keys(key_id) ON DELETE CASCADE,
    language_code VARCHAR(10) NOT NULL, -- vi, en, fr, etc.
    translated_value TEXT NOT NULL,
    is_reviewed BOOLEAN DEFAULT FALSE,
    reviewed_by UUID REFERENCES users(user_id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (key_id, language_code)
);

CREATE INDEX idx_localization_keys_name ON localization_keys (key_name);
CREATE INDEX idx_localization_keys_category ON localization_keys (category);
CREATE INDEX idx_localization_translations_key ON localization_translations (key_id);
CREATE INDEX idx_localization_translations_lang ON localization_translations (language_code);

COMMENT ON TABLE localization_keys IS 'Master list of localization keys';
COMMENT ON TABLE localization_translations IS 'Translations for each localization key';

-- =============================================================================
-- 4. TRIGGERS FOR AUTO-UPDATE TIMESTAMPS
-- =============================================================================

-- Note: Assumes update_updated_at_column() function already exists
-- If not, create it first:
-- CREATE OR REPLACE FUNCTION update_updated_at_column()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     NEW.updated_at = CURRENT_TIMESTAMP;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- Trigger for application_settings
CREATE TRIGGER trigger_application_settings_update_updated_at
    BEFORE UPDATE ON application_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for notification_templates
CREATE TRIGGER trigger_notification_templates_update_updated_at
    BEFORE UPDATE ON notification_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for localization_keys
CREATE TRIGGER trigger_localization_keys_update_updated_at
    BEFORE UPDATE ON localization_keys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for localization_translations
CREATE TRIGGER trigger_localization_translations_update_updated_at
    BEFORE UPDATE ON localization_translations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 5. INITIAL DATA
-- =============================================================================

-- Insert default application settings
INSERT INTO application_settings (setting_key, setting_name, setting_value, value_type, category, description, is_public) VALUES
('max_upload_size_mb', 'Maximum Upload Size', '{"value": 10}'::jsonb, 'number', 'General', 'Maximum file upload size in MB', TRUE),
('session_timeout_minutes', 'Session Timeout', '{"value": 60}'::jsonb, 'number', 'Security', 'User session timeout in minutes', FALSE),
('items_per_page', 'Items Per Page', '{"value": 20}'::jsonb, 'number', 'UI', 'Default number of items per page', TRUE),
('maintenance_message', 'Maintenance Message', '{"value": "System under maintenance"}'::jsonb, 'string', 'General', 'Default maintenance message', TRUE)
ON CONFLICT (setting_key) DO NOTHING;

-- Insert default notification templates
INSERT INTO notification_templates (template_key, template_name, category, title_template, message_template, notification_type, variables) VALUES
('welcome_user', 'Welcome User', 'system', 'Welcome to Alio Health, {{user_name}}!', 'Thank you for joining us. Start your health journey today!', 3, '["user_name"]'::jsonb),
('medication_reminder', 'Medication Reminder', 'medication', 'Time to take {{medicine_name}}', 'Don''t forget to take {{dosage}} of {{medicine_name}} at {{time}}', 2, '["medicine_name", "dosage", "time"]'::jsonb),
('mission_completed', 'Mission Completed', 'gamefi', 'Mission Completed!', 'Congratulations {{user_name}}! You completed {{mission_name}} and earned {{coins}} coins!', 3, '["user_name", "mission_name", "coins"]'::jsonb)
ON CONFLICT (template_key) DO NOTHING;

-- bảng lưu danh sách voice
CREATE TABLE tts_voices_config (
    id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,

    -- Tên dùng để gọi API (ví dụ: 'Puck', 'Zephyr')
    api_name VARCHAR(100) NOT NULL UNIQUE,

    -- Tên hiển thị thân thiện trên giao diện cấu hình
    display_name VARCHAR(100) NOT NULL,

    -- Đặc điểm chính (từ hình: 'Bright', 'Upbeat')
    characteristic VARCHAR(100) NULL,

    -- Cao độ (từ hình: 'Higher pitch', 'Middle pitch')
    pitch VARCHAR(100) NULL,

    -- ID của file sample (để bạn lưu link/path/id file nghe thử)
    sample_id TEXT NULL,

    -- Dùng để bật/tắt giọng nói này trong phần cấu hình
    is_active BOOLEAN NOT NULL DEFAULT true,

    -- Dấu thời gian
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE tts_voices_config
ADD COLUMN model TEXT;

ALTER TABLE tts_voices_config
ADD COLUMN sample_text TEXT;

-- Step 3: Drop old unique constraint on api_name
ALTER TABLE tts_voices_config
DROP CONSTRAINT IF EXISTS tts_voices_config_api_name_key;

-- Step 4: Add composite unique constraint on (api_name, model)
ALTER TABLE tts_voices_config
ADD CONSTRAINT uk_voice_api_model UNIQUE (api_name, model);



CREATE TABLE IF NOT EXISTS tts_audio_metadata (
    file_id UUID PRIMARY KEY REFERENCES files(file_id) ON DELETE CASCADE,
    voice_api_name VARCHAR(100) NOT NULL,
    model TEXT NOT NULL, -- Cột 'model' được thêm ngay từ đầu
    provider VARCHAR(50) NOT NULL DEFAULT 'google',
    language_code VARCHAR(10) NOT NULL DEFAULT 'vi-VN',
    audio_format VARCHAR(20) NOT NULL DEFAULT 'mp3',
    duration_ms INTEGER,
    answer_text_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Khóa ngoại TỔ HỢP trỏ đến bảng tts_voices_config
    CONSTRAINT fk_tts_voice_model
        FOREIGN KEY (voice_api_name, model)
        REFERENCES tts_voices_config (api_name, model)
        ON UPDATE CASCADE
);

-- Comments
COMMENT ON TABLE tts_audio_metadata IS 'Metadata for TTS-generated audio files, used for caching';
COMMENT ON COLUMN tts_audio_metadata.answer_text_hash IS 'SHA-256 hash of text + voice + model + language for cache lookup';

-- Indexes
-- Index tra cứu cache giờ phải bao gồm cả 'model'
CREATE INDEX IF NOT EXISTS idx_tts_metadata_lookup ON tts_audio_metadata (voice_api_name, model, answer_text_hash);
CREATE INDEX IF NOT EXISTS idx_tts_metadata_created ON tts_audio_metadata (created_at DESC);

ALTER TABLE files
    ADD COLUMN admin_id INTEGER REFERENCES admin_users(admin_id) ON DELETE SET NULL;

ALTER TABLE files
    ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE files
    ADD CONSTRAINT chk_files_owner
        CHECK (user_id IS NOT NULL OR admin_id IS NOT NULL);

CREATE INDEX idx_files_admin_id ON files (admin_id);


-- Tạo bảng danh mục bệnh nền
CREATE TABLE medical_conditions (
    condition_id SERIAL PRIMARY KEY, -- Tự động tăng, khớp với id: number bên FE
    condition_name TEXT NOT NULL,    -- Tên hiển thị của bệnh
    status SMALLINT NOT NULL DEFAULT 1, -- 1: Hoạt động, 2: Ẩn
    priority INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Thêm chú thích cho bảng
COMMENT ON TABLE medical_conditions IS 'Danh mục các bệnh nền (Medical Conditions) hỗ trợ cho Dropdown chọn bệnh.';
COMMENT ON COLUMN medical_conditions.priority IS 'Độ ưu tiên hiển thị. Số càng nhỏ càng hiển thị lên trên (VD: 1, 2, 3...).';

CREATE INDEX idx_medical_conditions_priority ON medical_conditions (priority ASC, condition_name ASC);
-- Trigger tự động cập nhật updated_at
CREATE TRIGGER trigger_medical_conditions_updated_at
    BEFORE UPDATE ON medical_conditions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- -- 1. Bảng định nghĩa phân khúc người dùng
-- CREATE TABLE exercise_user_segments (
--     segment_id SERIAL PRIMARY KEY,
--     segment_code VARCHAR(50) NOT NULL UNIQUE, -- VD: SEG_ELDERLY_HTN_1
--     segment_name VARCHAR(255) NOT NULL,
--     target_mode VARCHAR(50) NOT NULL, -- VD: "target", "mode"
--     health_risks TEXT,
--     activity_constraints TEXT,
--     criteria JSONB NOT NULL, -- Logic phân loại: {"age_range": [60, 100], "bmi_range": [18.5, 24.9], "conditions": ["hypertension"], "activity_level": 1}
--     priority INTEGER DEFAULT 0, -- Độ ưu tiên khi user khớp nhiều segment
--     is_active BOOLEAN DEFAULT TRUE,
--     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
-- );


-- -- 2. Bảng quy tắc an toàn (Safety Filters)
-- CREATE TABLE mission_segment_safety_rules (
--     id SERIAL PRIMARY KEY,
--     mission_id INTEGER NOT NULL,
--     segment_id INTEGER NOT NULL,
    
--     -- Mức độ an toàn: 1=Ưu tiên, 2=Thay thế, 3=Giới hạn, 4=Chặn (Enum)
--     safety_level SMALLINT NOT NULL, 
    
--     -- Ghi chú bổ sung (VD: "Đi chậm", "Hại khớp")
--     note VARCHAR(255),
    
--     updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
--     -- Ràng buộc khóa ngoại
--     CONSTRAINT fk_mission FOREIGN KEY (mission_id) REFERENCES mission_definitions(id) ON DELETE CASCADE,
--     CONSTRAINT fk_segment FOREIGN KEY (segment_id) REFERENCES exercise_user_segments(segment_id) ON DELETE CASCADE,
    
--     -- Đảm bảo mỗi ô trong ma trận chỉ có 1 cấu hình duy nhất
--     CONSTRAINT uq_mission_segment UNIQUE (mission_id, segment_id)
-- );

-- -- Index để query nhanh khi render bảng
-- CREATE INDEX idx_safety_rules_lookup ON mission_segment_safety_rules(mission_id, segment_id);


-- -- 3. Bảng gán mục tiêu theo mood (Target Assignment Matrix)
-- CREATE TABLE mission_mood_configs (
--     id SERIAL PRIMARY KEY,
    
--     -- Link đến bảng nhiệm vụ gốc
--     mission_id INTEGER NOT NULL,
    
--     -- Chế độ mục tiêu (VD: "DURATION_RANGE", "FIXED_TIME")
--     target_mode TEXT NOT NULL,
    
--     -- Cấu hình chi tiết cho từng mood
--     -- Dữ liệu sẽ lưu dạng: Key là Mood Code, Value là {min, max, unit, note}
--     mood_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    
--     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
--     -- Ràng buộc: Mỗi mission chỉ nên có 1 bảng cấu hình mood
--     CONSTRAINT fk_mission_mood FOREIGN KEY (mission_id) REFERENCES mission_definitions(id) ON DELETE CASCADE,
--     CONSTRAINT uq_mission_mood_config UNIQUE (mission_id)
-- );

-- -- Tạo Index cho JSONB để query nhanh nếu cần lọc theo mood
-- CREATE INDEX idx_mission_mood_config_data ON mission_mood_configs USING GIN (mood_config);

-- CREATE TRIGGER trigger_login_attempts_check
--     AFTER INSERT ON login_attempts
--     FOR EACH ROW EXECUTE FUNCTION check_failed_login_attempts();

-- CREATE TRIGGER trigger_temp_users_update_updated_at
--     BEFORE UPDATE ON temp_users
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_auth_user_update_updated_at
--     BEFORE UPDATE ON auth_user
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_family_group_members_update_updated_at
--     BEFORE UPDATE ON family_group_members
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_family_group_members_notify
--     AFTER INSERT ON family_group_members
--     FOR EACH ROW EXECUTE FUNCTION notify_family_group_invitation();

-- CREATE TRIGGER trigger_family_group_members_log
--     AFTER INSERT OR UPDATE OR DELETE ON family_group_members
--     FOR EACH ROW EXECUTE FUNCTION log_family_group_change();

-- CREATE TRIGGER trigger_doctor_patient_assignments_update_updated_at
--     BEFORE UPDATE ON doctor_patient_assignments
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_user_configurations_update_updated_at
--     BEFORE UPDATE ON user_configurations
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_user_feedback_update_updated_at
--     BEFORE UPDATE ON user_feedback
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_user_blood_pressure_update_updated_at
--     BEFORE UPDATE ON user_blood_pressure
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_user_health_profiles_notify
--     AFTER UPDATE ON user_health_profiles
--     FOR EACH ROW EXECUTE FUNCTION notify_supervisor_health_update();

-- CREATE TRIGGER trigger_game_profiles_notify
--     AFTER UPDATE ON game_profiles
--     FOR EACH ROW EXECUTE FUNCTION notify_supervisor_gamefi_update();

-- CREATE TRIGGER trigger_invite_codes_update_updated_at
--     BEFORE UPDATE ON invite_codes
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_invite_referrals_update_updated_at
--     BEFORE UPDATE ON invite_referrals
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_prescriptions_update_updated_at
--     BEFORE UPDATE ON prescriptions
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_prescription_items_update_updated_at
--     BEFORE UPDATE ON prescription_items
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -- Trigger cũ cho bảng schedules (đã bị xóa)
-- -- CREATE TRIGGER trigger_schedules_update_updated_at
-- --     BEFORE UPDATE ON schedules
-- --     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -- Trigger mới cho các bảng schedules đã tách
-- CREATE TRIGGER trigger_med_schedules_update_updated_at
--     BEFORE UPDATE ON medication_schedules
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_bp_schedules_update_updated_at
--     BEFORE UPDATE ON blood_pressure_schedules
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_rex_schedules_update_updated_at
--     BEFORE UPDATE ON re_examination_schedules
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_prompts_update_updated_at
--     BEFORE UPDATE ON prompts
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_subscriptions_update_updated_at
--     BEFORE UPDATE ON subscriptions
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_orders_update_updated_at
--     BEFORE UPDATE ON orders
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER trigger_transactions_update_updated_at
--     BEFORE UPDATE ON transactions
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_game_profiles_updated_at
--     BEFORE UPDATE ON game_profiles
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_mission_definitions_updated_at
--     BEFORE UPDATE ON mission_definitions
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_user_missions_updated_at
--     BEFORE UPDATE ON user_missions
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_user_streaks_updated_at
--     BEFORE UPDATE ON user_streaks
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_game_actions_updated_at
--     BEFORE UPDATE ON game_actions
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_game_items_updated_at
--     BEFORE UPDATE ON game_items
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_user_game_inventory_updated_at
--     BEFORE UPDATE ON user_game_inventory
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_user_posts_updated_at
--     BEFORE UPDATE ON user_posts
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CREATE TRIGGER update_charity_campaigns_updated_at
--     BEFORE UPDATE ON charity_campaigns
--     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- BẢNG TRACKING CHO CÁC KỊCH BẢN NOTIFICATION
-- =============================================================================

-- Bảng theo dõi gợi ý thiết lập lịch (BP, Medication, Re-examination)
CREATE TABLE schedule_setup_suggestion_tracking (
    user_id UUID NOT NULL,
    suggestion_type VARCHAR(50) NOT NULL, -- 'blood_pressure', 'medication', 're_examination'
    last_sent_at TIMESTAMPTZ NOT NULL,
    sent_count INTEGER DEFAULT 1,
    responded_at TIMESTAMPTZ NULL, -- Khi user thực sự tạo schedule
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, suggestion_type),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index cho performance
CREATE INDEX idx_schedule_setup_suggestion_tracking_last_sent ON schedule_setup_suggestion_tracking (suggestion_type, last_sent_at);
CREATE INDEX idx_schedule_setup_suggestion_tracking_user ON schedule_setup_suggestion_tracking (user_id);

-- Bảng theo dõi nhắc nhở bỏ lỡ 3 ngày liên tiếp
CREATE TABLE missed_reminder_tracking (
    user_id UUID NOT NULL,
    feature_type VARCHAR(50) NOT NULL, -- 'blood_pressure', 'medication'
    last_sent_at TIMESTAMPTZ NOT NULL,
    last_check_date DATE NOT NULL, -- Ngày cuối cùng check missed
    missed_days_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, feature_type),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index cho performance
CREATE INDEX idx_missed_reminder_tracking_last_sent ON missed_reminder_tracking (feature_type, last_sent_at);
CREATE INDEX idx_missed_reminder_tracking_check_date ON missed_reminder_tracking (last_check_date);

-- Bảng theo dõi win-back notifications (14+ ngày inactive)
CREATE TABLE winback_notification_tracking (
    user_id UUID NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'blood_pressure', 'medication'
    last_activity_date DATE NOT NULL, -- Ngày hoạt động cuối cùng
    last_sent_at TIMESTAMPTZ NOT NULL,
    sent_count INTEGER DEFAULT 1,
    message_variant INTEGER DEFAULT 1, -- 1-4 cho random message
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, notification_type),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index cho performance
CREATE INDEX idx_winback_notification_tracking_last_sent ON winback_notification_tracking (notification_type, last_sent_at);
CREATE INDEX idx_winback_notification_tracking_activity ON winback_notification_tracking (last_activity_date);

-- Bảng theo dõi xác nhận tiếp tục uống thuốc (3 stages)
CREATE TABLE medication_continuation_tracking (
    prescription_id BIGINT NOT NULL,
    user_id UUID NOT NULL,
    stage INTEGER NOT NULL, -- 1, 2, 3 (day 0, +2, +4)
    sent_at TIMESTAMPTZ NOT NULL,
    responded_at TIMESTAMPTZ NULL,
    response_type VARCHAR(20) NULL, -- 'continue', 'stop', 'modify'
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (prescription_id, stage),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index cho performance
CREATE INDEX idx_medication_continuation_tracking_user ON medication_continuation_tracking (user_id, stage);
CREATE INDEX idx_medication_continuation_tracking_sent ON medication_continuation_tracking (sent_at);

-- Bảng theo dõi thu thập kết quả tái khám (3 stages)
CREATE TABLE re_examination_result_tracking (
    event_id BIGINT NOT NULL,
    user_id UUID NOT NULL,
    stage INTEGER NOT NULL, -- 1, 2, 3 (day +1, +3, +5)
    sent_at TIMESTAMPTZ NOT NULL,
    responded_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, stage),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (event_id) REFERENCES re_examination_events(event_id) ON DELETE CASCADE
);

-- Index cho performance
CREATE INDEX idx_re_examination_result_tracking_user ON re_examination_result_tracking (user_id, stage);
CREATE INDEX idx_re_examination_result_tracking_sent ON re_examination_result_tracking (sent_at);


-- =============================================================================
-- TẠO BẢNG WHITELIST (DANH SÁCH TRẮNG)
-- =============================================================================

CREATE TABLE whitelist (
    phone_number VARCHAR(20) PRIMARY KEY,
    status SMALLINT NOT NULL DEFAULT 1, -- 1: Hoạt động, 0: Không hoạt động
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Thêm các chú thích (comments) để làm rõ ý nghĩa
COMMENT ON TABLE whitelist IS 'Bảng lưu danh sách các số điện thoại được phép (whitelist) cho các tính năng đặc biệt.';
COMMENT ON COLUMN whitelist.phone_number IS 'Số điện thoại (định dạng E.164, ví dụ: +84901234567). Đây là Khóa Chính.';
COMMENT ON COLUMN whitelist.status IS 'Trạng thái của số điện thoại: 1 (Hoạt động), 0 (Không hoạt động).';
COMMENT ON COLUMN whitelist.created_at IS 'Thời điểm số điện thoại được thêm vào.';
COMMENT ON COLUMN whitelist.updated_at IS 'Thời điểm bản ghi được cập nhật lần cuối.';

-- Tạo index để tăng tốc độ truy vấn theo trạng thái
CREATE INDEX idx_whitelist_status ON whitelist (status);

-- Kích hoạt trigger để tự động cập nhật cột `updated_at` khi có thay đổi
-- (Giả định rằng bạn đã tạo function `update_updated_at_column()` từ trước)
CREATE TRIGGER trigger_whitelist_update_updated_at
    BEFORE UPDATE ON whitelist
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- =============================================================================
-- BẢNG AGENT_SETTINGS: CẤU HÌNH CHO CÁC AI AGENTS
-- =============================================================================

CREATE TABLE agent_settings (
    id BIGSERIAL PRIMARY KEY,
    agent_key VARCHAR(100) NOT NULL,                      -- Định danh agent (VD: 'health_assistant')
    task_type VARCHAR(100) NOT NULL,                      -- Loại task (VD: 'chat', 'summary', 'analysis')
    agent_name VARCHAR(150),                              -- Tên hiển thị của agent
    prompt TEXT NOT NULL,                                 -- System prompt cho agent
    agent_config JSONB DEFAULT '{}'::jsonb,               -- Cấu hình agent (model, temperature, max_tokens, etc.)
    description TEXT,                                     -- Mô tả chi tiết về agent
    is_active BOOLEAN DEFAULT TRUE,                       -- Trạng thái hoạt động
    version INTEGER DEFAULT 1,                            -- Phiên bản cấu hình để theo dõi thay đổi
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint cho (agent_key, task_type)
    CONSTRAINT uq_agent_settings_key_task UNIQUE (agent_key, task_type)
);

-- Tạo comment cho bảng
COMMENT ON TABLE agent_settings IS 'Bảng lưu trữ cấu hình các AI agent bao gồm prompt và config theo từng task_type.';

-- Tạo các index cần thiết
CREATE INDEX idx_agent_settings_agent_key ON agent_settings (agent_key);
CREATE INDEX idx_agent_settings_task_type ON agent_settings (task_type);
CREATE INDEX idx_agent_settings_is_active ON agent_settings (is_active) WHERE is_active = TRUE;
CREATE INDEX idx_agent_settings_config_gin ON agent_settings USING GIN (agent_config);

-- Kích hoạt trigger tự động cập nhật updated_at
CREATE TRIGGER trigger_agent_settings_update_updated_at
    BEFORE UPDATE ON agent_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


create table agent_models
(
    id             serial
        primary key,
    model_name     varchar(100) not null
        unique,
    display_name   varchar(150),
    description    text,
    max_tokens     integer,
    context_window integer,
    is_active      boolean                  default true,
    created_at     timestamp with time zone default CURRENT_TIMESTAMP,
    updated_at     timestamp with time zone default CURRENT_TIMESTAMP
);

-- Celery Job -------------------------
CREATE TABLE IF NOT EXISTS celery_job_registry (
	name TEXT PRIMARY KEY,
	task TEXT NOT NULL,
	schedule_type TEXT,
	schedule_pattern TEXT,
	schedule_json TEXT,
	queue TEXT,
	enabled BOOLEAN DEFAULT TRUE,
	app TEXT,
	description TEXT,
	updated_at TIMESTAMPTZ DEFAULT NOW()
)

CREATE TABLE IF NOT EXISTS celery_job_runs (
	task_id TEXT PRIMARY KEY,
	task_name TEXT,
	state TEXT,
	queue TEXT,
	args TEXT,
	kwargs TEXT,
	result TEXT,
	error TEXT,
	traceback TEXT,
	worker_hostname TEXT,
	started_at TIMESTAMPTZ,
	finished_at TIMESTAMPTZ,
	runtime REAL
)

CREATE INDEX IF NOT EXISTS idx_celery_job_runs_task_name 
ON celery_job_runs(task_name)

CREATE INDEX IF NOT EXISTS idx_celery_job_runs_state 
ON celery_job_runs(state)

CREATE INDEX IF NOT EXISTS idx_celery_job_runs_finished_at 
ON celery_job_runs(finished_at DESC NULLS LAST)


-- =============================================================================
-- MODULE: GIÁO DỤC SỨC KHỎE (EDUCATION & KNOWLEDGE BASE)
-- Phiên bản: Final Production Release
-- Database: PostgreSQL
-- =============================================================================

-- 1. Bảng Categories (Danh mục nội dung)
CREATE TABLE edu_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, -- VD: "Dinh dưỡng", "Tim mạch"
    description TEXT,
    icon_url VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'deleted')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX edu_categories_name_case_insensitive_unique 
ON edu_categories (LOWER(name));

-- 2. Bảng Contents (Kho nội dung tổng hợp: Bài viết, Video, Podcast)
CREATE TABLE edu_contents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Phân loại: Mảng ID danh mục. VD: '[1, 5]'
    -- category_ids JSONB DEFAULT '[]'::jsonb,   
    -- Loại nội dung
    content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('article', 'video', 'podcast')),

    -- Thông tin chung
    title VARCHAR(255) NOT NULL, 
    -- thumbnail_url VARCHAR, 
    -- MEDIA & FILE (Quan trọng: Link sang bảng files)
    thumbnail_file_id UUID REFERENCES files(file_id) ON DELETE SET NULL,
    description TEXT, -- Sapo/Mô tả ngắn
    key_takeaway TEXT, -- Nội dung ghi nhớ (Key Takeaway)
    author_name VARCHAR(200),
    shared_url VARCHAR, 


    -- Nội dung chi tiết (Nullable tùy loại)
    body_content TEXT, -- Cho Article
    -- media_url VARCHAR, -- Cho Video/Podcast
    -- Nếu là Internal (MinIO) -> Dùng ID này
    media_file_id UUID REFERENCES files(file_id) ON DELETE SET NULL, 
    audio_links JSONB DEFAULT '{}'::jsonb;
    
    -- Nếu là Youtube -> Dùng Link này
    external_media_id TEXT,
    duration INTEGER DEFAULT 0, -- Giây

    -- Thống kê (Cache từ Trigger)
    -- Thêm CHECK >= 0 để đảm bảo an toàn dữ liệu tuyệt đối
    views_count INTEGER DEFAULT 0 CHECK (views_count >= 0),
    likes_count INTEGER DEFAULT 0 CHECK (likes_count >= 0),
    total_quizzes INTEGER DEFAULT 0 CHECK (total_quizzes >= 0),
    
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'deleted')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2.5. Bảng Map Content - Category (Thay thế cho JSONB)
CREATE TABLE edu_content_category_map (
    content_id UUID REFERENCES edu_contents(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES edu_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (content_id, category_id)
);

-- Index tối ưu truy vấn
-- CREATE INDEX idx_edu_contents_cats ON edu_contents USING GIN (category_ids); -- Tìm theo danh mục (JSONB)
CREATE INDEX idx_edu_contents_created ON edu_contents(created_at DESC); -- Sắp xếp mới nhất
CREATE INDEX idx_edu_contents_type ON edu_contents(content_type); -- Lọc theo loại

-- 3. Bảng Quizzes (Ngân hàng câu hỏi)
CREATE TABLE edu_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Nếu NULL -> Quiz độc lập (Daily Quiz). Nếu có ID -> Quiz gắn bài học.
    content_id UUID REFERENCES edu_contents(id) ON DELETE CASCADE, 
    
    question_text TEXT NOT NULL,
    
    -- Cấu trúc JSON: [{"id": 1, "text": "Đúng"}, {"id": 2, "text": "Sai"}]
    options JSONB NOT NULL, 
    
    correct_option_id INTEGER NOT NULL, 
    explanation TEXT, -- Giải thích đúng sai
    
    appear_time_seconds INTEGER DEFAULT 0, -- Thời điểm hiện popup (cho Video)
    
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'deleted')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_quizzes_content ON edu_quizzes(content_id);

-- 4. Bảng User Interactions (Tương tác người dùng)
CREATE TABLE edu_user_content_interactions (
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    content_id UUID REFERENCES edu_contents(id) ON DELETE CASCADE,
    
    is_liked BOOLEAN DEFAULT FALSE,
    is_completed BOOLEAN DEFAULT FALSE,
    
    progress_seconds INTEGER DEFAULT 0, -- Lưu tiến độ xem video
    last_viewed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (user_id, content_id) -- 1 User chỉ có 1 record tương tác với 1 bài
);
CREATE INDEX idx_interactions_user ON edu_user_content_interactions(user_id);

-- 5. Bảng User Quiz History (Lịch sử làm bài)
CREATE TABLE edu_user_quiz_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES edu_quizzes(id) ON DELETE CASCADE,
    
    selected_option_id INTEGER,
    is_correct BOOLEAN DEFAULT FALSE,
    
    answered_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_quiz_history_user ON edu_user_quiz_history(user_id);
CREATE INDEX idx_quiz_history_quiz ON edu_user_quiz_history(quiz_id);

-- =============================================================================
-- PHẦN TRIGGER: TỰ ĐỘNG HÓA SỐ LIỆU (AUTO-CALCULATION)
-- =============================================================================

-- A. TRIGGER 1: TỰ ĐỘNG ĐẾM SỐ CÂU HỎI (total_quizzes)
-- Logic thông minh: Xử lý cả trường hợp đổi trạng thái Active/Inactive và chuyển Quiz sang bài khác
CREATE OR REPLACE FUNCTION update_quiz_count() RETURNS TRIGGER AS $$
DECLARE
    was_active BOOLEAN;
    is_active BOOLEAN;
BEGIN
    -- Kiểm tra trạng thái bản ghi CŨ (cho UPDATE/DELETE)
    was_active := (TG_OP IN ('UPDATE', 'DELETE') AND OLD.status = 'active' AND OLD.content_id IS NOT NULL);
    
    -- Kiểm tra trạng thái bản ghi MỚI (cho INSERT/UPDATE)
    is_active := (TG_OP IN ('INSERT', 'UPDATE') AND NEW.status = 'active' AND NEW.content_id IS NOT NULL);

    -- 1. GIẢM số lượng ở bài viết CŨ
    -- (Nếu trước đây nó active, mà giờ nó bị xóa, bị ẩn, hoặc bị chuyển đi bài khác)
    IF was_active AND (NOT is_active OR OLD.content_id IS DISTINCT FROM NEW.content_id) THEN
        UPDATE edu_contents SET total_quizzes = total_quizzes - 1 WHERE id = OLD.content_id;
    END IF;

    -- 2. TĂNG số lượng ở bài viết MỚI
    -- (Nếu bây giờ nó active, mà trước đây nó ko có, nó bị ẩn, hoặc nó từ bài khác chuyển tới)
    IF is_active AND (NOT was_active OR OLD.content_id IS DISTINCT FROM NEW.content_id) THEN
        UPDATE edu_contents SET total_quizzes = total_quizzes + 1 WHERE id = NEW.content_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_quiz_count
AFTER INSERT OR UPDATE OR DELETE ON edu_quizzes
FOR EACH ROW
EXECUTE FUNCTION update_quiz_count();


-- B. TRIGGER 2: TỰ ĐỘNG ĐẾM VIEW & LIKE (views_count, likes_count)
-- Logic: View tính theo Unique User (số dòng record), Like tính theo is_liked = true
CREATE OR REPLACE FUNCTION update_interaction_stats() RETURNS TRIGGER AS $$
BEGIN
    -- 1. INSERT (User lần đầu vào xem)
    IF (TG_OP = 'INSERT') THEN
        UPDATE edu_contents 
        SET views_count = views_count + 1,
            likes_count = likes_count + (CASE WHEN NEW.is_liked THEN 1 ELSE 0 END)
        WHERE id = NEW.content_id;

    -- 2. UPDATE (User thả tim / bỏ tim)
    ELSIF (TG_OP = 'UPDATE') THEN
        IF NEW.is_liked IS DISTINCT FROM OLD.is_liked THEN
            UPDATE edu_contents 
            SET likes_count = likes_count + (CASE WHEN NEW.is_liked THEN 1 ELSE -1 END)
            WHERE id = NEW.content_id;
        END IF;

    -- 3. DELETE (Xóa user hoặc xóa lịch sử)
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE edu_contents 
        SET views_count = views_count - 1,
            likes_count = likes_count - (CASE WHEN OLD.is_liked THEN 1 ELSE 0 END)
        WHERE id = OLD.content_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_interactions
AFTER INSERT OR UPDATE OR DELETE ON edu_user_content_interactions
FOR EACH ROW
EXECUTE FUNCTION update_interaction_stats();

-- =============================================================================
-- Phần config app
-- =============================================================================

CREATE TABLE IF NOT EXISTS system_app_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    app_key VARCHAR(100) NOT NULL,
    app_name VARCHAR(255) NOT NULL,

    current_app_version VARCHAR(50),
    current_build_number INTEGER,

    config_app JSONB NOT NULL DEFAULT '{}'::jsonb,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    status VARCHAR(20) DEFAULT 'ACTIVE',
    maintenance_start_time TIMESTAMPTZ,
    retry_hours INTEGER DEFAULT 0,

    created_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    updated_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_app_configs_key ON system_app_configs (app_key);
CREATE INDEX IF NOT EXISTS idx_app_configs_active ON system_app_configs (is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_app_configs_config_gin ON system_app_configs USING GIN (config_app);

CREATE TRIGGER trigger_app_configs_update_updated_at
    BEFORE UPDATE ON system_app_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE system_app_configs 
    ADD CONSTRAINT check_status CHECK (status IN ('ACTIVE', 'INACTIVE'));

COMMENT ON COLUMN system_app_configs.id IS 'Primary key UUID.';
COMMENT ON COLUMN system_app_configs.app_key IS 'Mã định danh duy nhất của app (unique).';
COMMENT ON COLUMN system_app_configs.app_name IS 'Tên hiển thị của app.';
COMMENT ON COLUMN system_app_configs.current_app_version IS 'Version app hiện tại (vd: 1.2.3).';
COMMENT ON COLUMN system_app_configs.current_build_number IS 'Build number hiện tại (optional cho mobile).';
COMMENT ON COLUMN system_app_configs.config_app IS 'JSONB cấu hình hiện tại của app.';
COMMENT ON COLUMN system_app_configs.is_active IS 'Trạng thái bật/tắt record config.';
COMMENT ON COLUMN system_app_configs.created_by IS 'User tạo record config (FK users.user_id).';
COMMENT ON COLUMN system_app_configs.updated_by IS 'User cập nhật gần nhất (FK users.user_id).';
COMMENT ON COLUMN system_app_configs.created_at IS 'Thời điểm tạo record.';
COMMENT ON COLUMN system_app_configs.updated_at IS 'Thời điểm cập nhật gần nhất.';
COMMENT ON COLUMN system_app_configs.status IS 'Trạng thái của bảo trì: ACTIVE (đang hoạt động) hoặc INACTIVE (đang bảo trì).';
COMMENT ON COLUMN system_app_configs.maintenance_start_time IS 'Thời gian bắt đầu bảo trì (nếu có).';
COMMENT ON COLUMN system_app_configs.retry_hours IS 'Số giờ retry khi có lỗi (default 0).';



-- =============================================================================
-- PHÂN HỆ: KẾT NỐI NGƯỜI THÂN (CONNECTION FEATURE)
-- Version: 2.22 (KOLIA-1517) - Normalized permission_types + inverse_relationship_code
--          + relationship_inverse_mapping for gender-based inverse derivation (v2.21)
--          + relationship enum alignment 17→14 values per SRS (v2.22)
-- =============================================================================

-- TABLE: relationships (LOOKUP)
-- Purpose: Standardized relationship types for both SOS and Caregiver features
-- Owner: user-service
CREATE TABLE IF NOT EXISTS relationships (
    relationship_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    category VARCHAR(30) DEFAULT 'family',
    display_order SMALLINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- Seed data (14 types — aligned with SRS prototype v2.22)
INSERT INTO relationships (relationship_code, name_vi, name_en, category, display_order) VALUES
('con_trai', 'Con trai', 'Son', 'family', 1),
('con_gai', 'Con gái', 'Daughter', 'family', 2),
('vo', 'Vợ', 'Wife', 'spouse', 3),
('chong', 'Chồng', 'Husband', 'spouse', 4),
('bo', 'Bố', 'Father', 'family', 5),
('me', 'Mẹ', 'Mother', 'family', 6),
('anh_trai', 'Anh trai', 'Older brother', 'family', 7),
('chi_gai', 'Chị gái', 'Older sister', 'family', 8),
('em_trai', 'Em trai', 'Younger brother', 'family', 9),
('em_gai', 'Em gái', 'Younger sister', 'family', 10),
('ong', 'Ông', 'Grandfather', 'family', 11),
('ba', 'Bà', 'Grandmother', 'family', 12),
('chau', 'Cháu', 'Grandchild', 'family', 13),
('khac', 'Khác', 'Other', 'other', 99)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE relationships IS 'Lookup table for relationship types (SOS + Caregiver)';

-- TABLE: relationship_inverse_mapping (v2.22 - Gender-based Inverse Derivation)
-- Purpose: Derive inverse_relationship_code based on original code + target gender
-- Owner: user-service
CREATE TABLE IF NOT EXISTS relationship_inverse_mapping (
    relationship_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    target_gender SMALLINT NOT NULL,  -- 0: Nam, 1: Nữ (gender of the OTHER party)
    inverse_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    PRIMARY KEY (relationship_code, target_gender)
);

-- Seed data: Mapping logic for all 14 relationship types × 2 genders (v2.22)
INSERT INTO relationship_inverse_mapping (relationship_code, target_gender, inverse_code) VALUES
-- Con → Bố/Mẹ
('con_trai', 0, 'bo'),
('con_trai', 1, 'me'),
('con_gai', 0, 'bo'),
('con_gai', 1, 'me'),
-- Bố/Mẹ → Con
('bo', 0, 'con_trai'),
('bo', 1, 'con_gai'),
('me', 0, 'con_trai'),
('me', 1, 'con_gai'),
-- Anh/Chị → Em
('anh_trai', 0, 'em_trai'),
('anh_trai', 1, 'em_gai'),
('chi_gai', 0, 'em_trai'),
('chi_gai', 1, 'em_gai'),
-- Em → Anh/Chị
('em_trai', 0, 'anh_trai'),
('em_trai', 1, 'chi_gai'),
('em_gai', 0, 'anh_trai'),
('em_gai', 1, 'chi_gai'),
-- Vợ/Chồng
('vo', 0, 'chong'),
('vo', 1, 'khac'),
('chong', 0, 'khac'),
('chong', 1, 'vo'),
-- Ông/Bà → Cháu
('ong', 0, 'chau'),
('ong', 1, 'chau'),
('ba', 0, 'chau'),
('ba', 1, 'chau'),
-- Cháu → Ông/Bà
('chau', 0, 'ong'),
('chau', 1, 'ba'),
-- Khác
('khac', 0, 'khac'),
('khac', 1, 'khac')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE relationship_inverse_mapping IS 'v2.22: Gender-based inverse relationship derivation lookup (14 types)';
COMMENT ON COLUMN relationship_inverse_mapping.target_gender IS '0: Nam, 1: Nữ - giới tính của bên còn lại';
COMMENT ON COLUMN relationship_inverse_mapping.inverse_code IS 'Mối quan hệ inverse được suy ra';

-- =============================================================================
-- v4.0: FAMILY GROUPS (từ 7_kcnt_v4_family_groups.sql)
-- =============================================================================

-- TABLE: family_groups
-- Purpose: Nhóm gia đình linked to payment subscription
-- Owner: user-service
CREATE TABLE IF NOT EXISTS family_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    subscription_id UUID,                    -- Link to payment subscription (nullable nếu free tier)
    name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_fg_admin_id ON family_groups(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_fg_subscription_id ON family_groups(subscription_id);
CREATE INDEX IF NOT EXISTS idx_fg_status ON family_groups(status) WHERE status = 'active';

DROP TRIGGER IF EXISTS trigger_fg_updated_at ON family_groups;
CREATE TRIGGER trigger_fg_updated_at
    BEFORE UPDATE ON family_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE family_groups IS 'v4.0: Nhóm gia đình linked to payment subscription';
COMMENT ON COLUMN family_groups.admin_user_id IS 'Admin = người kích hoạt gói (Payment SRS §2.8)';
COMMENT ON COLUMN family_groups.subscription_id IS 'Link to payment subscription (nullable nếu free tier)';

-- TABLE: family_group_members
-- Purpose: Thành viên nhóm gia đình
-- BR-057: 1 user = 1 nhóm duy nhất (exclusive group constraint)
-- BR-048: 1 user có thể vừa Patient vừa CG (2 role entries)
-- Owner: user-service
CREATE TABLE IF NOT EXISTS family_group_members (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES family_groups(group_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('patient', 'caregiver')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'removed')),
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(group_id, user_id, role)
);

-- BR-057: Exclusive Group — 1 user chỉ thuộc 1 nhóm per role
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_single_group
    ON family_group_members(user_id, role) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_fgm_group_id ON family_group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_fgm_user_id ON family_group_members(user_id);

DROP TRIGGER IF EXISTS trigger_fgm_updated_at ON family_group_members;
CREATE TRIGGER trigger_fgm_updated_at
    BEFORE UPDATE ON family_group_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE family_group_members IS 'v4.0: Family group members with exclusive constraint (BR-057)';
COMMENT ON COLUMN family_group_members.role IS 'patient or caregiver — 1 user can have both roles (BR-048)';

-- TABLE: connection_invites
-- Purpose: Track invite lifecycle (pending/accepted/rejected/cancelled)
-- Owner: user-service
CREATE TABLE IF NOT EXISTS connection_invites (
    invite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    receiver_name VARCHAR(100),
    invite_type VARCHAR(30) NOT NULL,      -- 'add_patient' | 'add_caregiver'
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- v2.13: Receiver mô tả Sender
    family_group_id UUID REFERENCES family_groups(group_id) ON DELETE SET NULL,  -- v5.0: family group UUID
    status SMALLINT DEFAULT 0,              -- 0=pending, 1=accepted, 2=rejected, 3=cancelled
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_invite_type CHECK (invite_type IN ('add_patient', 'add_caregiver')),
    CONSTRAINT chk_invite_status CHECK (status IN (0, 1, 2, 3))
);

CREATE INDEX IF NOT EXISTS idx_invites_sender ON connection_invites (sender_id);
CREATE INDEX IF NOT EXISTS idx_invites_receiver ON connection_invites (receiver_id) WHERE receiver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invites_phone ON connection_invites (receiver_phone);
CREATE INDEX IF NOT EXISTS idx_invites_pending ON connection_invites (status) WHERE status = 0;
CREATE INDEX IF NOT EXISTS idx_invites_family_group ON connection_invites (family_group_id) WHERE family_group_id IS NOT NULL;
-- Create new constraint với invite_type
CREATE UNIQUE INDEX idx_unique_pending_invite 
    ON connection_invites (sender_id, receiver_phone, invite_type) 
    WHERE status = 0;

DROP TRIGGER IF EXISTS trigger_invites_updated_at ON connection_invites;
CREATE TRIGGER trigger_invites_updated_at
    BEFORE UPDATE ON connection_invites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE connection_invites IS 'Connection invite tracking for KOLIA-1517';
COMMENT ON COLUMN connection_invites.status IS '0:pending, 1:accepted, 2:rejected, 3:cancelled';
COMMENT ON COLUMN connection_invites.invite_type IS 'v4.0: add_patient (mời bệnh nhân) or add_caregiver (mời người thân)';
COMMENT ON COLUMN connection_invites.relationship_code IS 'v2.13: Sender mô tả Receiver là [X]';
COMMENT ON COLUMN connection_invites.inverse_relationship_code IS 'v2.13: Receiver mô tả Sender là [X]';

-- =============================================================================
-- PHÂN HỆ: SOS EMERGENCY FEATURE
-- Version: 1.0 (từ v11_sos_emergency.sql)
-- =============================================================================


-- TABLE 1: user_emergency_contacts
-- Purpose: Store emergency contacts for each user (max 5) AND caregiver connections
-- Owner: user-service
-- Extended: KOLIA-1517 Connection Feature (v2.7 - added is_viewing)
CREATE TABLE IF NOT EXISTS user_emergency_contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    priority SMALLINT NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    zalo_enabled BOOLEAN DEFAULT FALSE,
    -- Connection Feature columns (KOLIA-1517)
    linked_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    contact_type VARCHAR(20) DEFAULT 'emergency',  -- 'emergency' | 'caregiver' | 'both'
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    invite_id UUID,  -- FK added after connection_invites table created
    is_viewing BOOLEAN DEFAULT FALSE,  -- v2.7: Currently viewing this patient (BR-026)
    inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- v2.13: Caregiver mô tả Patient
    permission_revoked BOOLEAN DEFAULT FALSE,  -- v4.0: Soft disconnect (BR-040, BR-056)
    family_group_id UUID REFERENCES family_groups(group_id),  -- v4.0: Link to family group
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_emergency_priority_range CHECK (priority BETWEEN 1 AND 5),
    CONSTRAINT uq_emergency_contact_phone UNIQUE (user_id, phone),
    CONSTRAINT chk_contact_type CHECK (contact_type IN ('emergency', 'caregiver', 'both', 'disconnected'))
);

CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON user_emergency_contacts (user_id, priority);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_active ON user_emergency_contacts (user_id) 
    WHERE is_active = TRUE;
-- Connection feature indexes
CREATE INDEX IF NOT EXISTS idx_contacts_linked_user ON user_emergency_contacts (linked_user_id) 
    WHERE linked_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_type ON user_emergency_contacts (user_id, contact_type);
-- Prevent duplicate caregiver connections (BR-007)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_caregiver_connection
    ON user_emergency_contacts (user_id, linked_user_id) 
    WHERE linked_user_id IS NOT NULL AND contact_type IN ('caregiver', 'both');
CREATE INDEX IF NOT EXISTS idx_uec_family_group_id
    ON user_emergency_contacts(family_group_id) WHERE family_group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_uec_permission_revoked
    ON user_emergency_contacts(permission_revoked) WHERE permission_revoked = TRUE;

DROP TRIGGER IF EXISTS trigger_emergency_contacts_updated_at ON user_emergency_contacts;
CREATE TRIGGER trigger_emergency_contacts_updated_at
    BEFORE UPDATE ON user_emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE user_emergency_contacts IS 'Emergency contacts for SOS feature AND caregiver connections (KOLIA-1517)';
COMMENT ON COLUMN user_emergency_contacts.linked_user_id IS 'App user ID if caregiver has account';
COMMENT ON COLUMN user_emergency_contacts.contact_type IS 'emergency (SOS), caregiver (connection), both';
COMMENT ON COLUMN user_emergency_contacts.is_viewing IS 'Currently viewing this patient (only one per user, BR-026)';
COMMENT ON COLUMN user_emergency_contacts.relationship_code IS 'v2.13: Patient (user_id) mô tả Caregiver (linked_user_id) là [X]';
COMMENT ON COLUMN user_emergency_contacts.inverse_relationship_code IS 'v2.13: Caregiver (linked_user_id) mô tả Patient (user_id) là [X]';

-- v2.7: Only ONE is_viewing=true per user (profile selection)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_viewing_patient
    ON user_emergency_contacts (linked_user_id) 
    WHERE is_viewing = TRUE AND contact_type IN ('caregiver', 'both');
CREATE INDEX IF NOT EXISTS idx_contacts_viewing 
    ON user_emergency_contacts (user_id, is_viewing) WHERE is_viewing = TRUE;


-- TABLE 2: sos_events
-- Purpose: Track SOS activation events
-- Owner: schedule-service (shared DB)
-- Retention: 90 days
CREATE TABLE IF NOT EXISTS sos_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Trigger info
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trigger_source VARCHAR(50) NOT NULL DEFAULT 'manual',
    
    -- Location at trigger time
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_accuracy_m DOUBLE PRECISION,
    location_timestamp TIMESTAMPTZ,
    location_source VARCHAR(50),
    
    -- Countdown & Status
    countdown_seconds SMALLINT NOT NULL DEFAULT 30,
    countdown_started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    countdown_completed_at TIMESTAMPTZ,
    
    -- Final status: 0=PENDING, 1=COMPLETED, 2=CANCELLED, 3=FAILED
    status SMALLINT NOT NULL DEFAULT 0,

    cskh_only BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Cancellation details
    cancelled_at TIMESTAMPTZ,
    cancellation_reason VARCHAR(100),
    
    -- Offline handling
    is_offline_triggered BOOLEAN DEFAULT FALSE,
    offline_queue_timestamp TIMESTAMPTZ,
    sync_completed_at TIMESTAMPTZ,
    
    -- Cooldown tracking
    cooldown_bypassed BOOLEAN DEFAULT FALSE,
    
    -- Battery info at trigger
    battery_level_percent SMALLINT,
    
    -- Metadata
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_sos_countdown_range CHECK (countdown_seconds BETWEEN 0 AND 30),
    CONSTRAINT chk_sos_status_values CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_sos_battery_range CHECK (battery_level_percent IS NULL OR battery_level_percent BETWEEN 0 AND 100)
);

CREATE INDEX IF NOT EXISTS idx_sos_events_cskh_only 
ON sos_events (cskh_only, status) 
WHERE cskh_only = true;

COMMENT ON COLUMN sos_events.cskh_only IS 'True when user has 0 emergency contacts - alert goes to CSKH only';

CREATE INDEX IF NOT EXISTS idx_sos_events_user ON sos_events (user_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_sos_events_status ON sos_events (status) WHERE status = 0;
CREATE INDEX IF NOT EXISTS idx_sos_events_cooldown ON sos_events (user_id, countdown_completed_at DESC) 
    WHERE status = 1;
CREATE INDEX IF NOT EXISTS idx_sos_events_location ON sos_events (latitude, longitude) 
    WHERE latitude IS NOT NULL;

DROP TRIGGER IF EXISTS trigger_sos_events_updated_at ON sos_events;
CREATE TRIGGER trigger_sos_events_updated_at
    BEFORE UPDATE ON sos_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sos_events IS 'SOS activation events tracking (90-day retention)';

-- TABLE 3: sos_notifications
-- Purpose: Track ZNS/SMS notifications sent per SOS event
-- Owner: schedule-service
-- Retention: 90 days
CREATE TABLE IF NOT EXISTS sos_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES sos_events(event_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Recipient info (denormalized for history)
    recipient_name VARCHAR(100) NOT NULL,
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_type VARCHAR(50) NOT NULL,
    
    -- Notification type
    channel VARCHAR(50) NOT NULL,
    template_id VARCHAR(100),
    
    -- Content (for audit)
    message_content TEXT,
    
    -- Status: 0=PENDING, 1=SENT, 2=DELIVERED, 3=FAILED, 4=RETRY_PENDING
    status SMALLINT NOT NULL DEFAULT 0,
    
    -- Timing
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    
    -- Retry info
    retry_count SMALLINT DEFAULT 0,
    last_retry_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    
    -- Error handling
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- External IDs
    external_message_id VARCHAR(200),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_notification_status CHECK (status IN (0, 1, 2, 3, 4)),
    CONSTRAINT chk_notification_retry_count CHECK (retry_count BETWEEN 0 AND 3)
);

CREATE INDEX IF NOT EXISTS idx_sos_notifications_event ON sos_notifications (event_id);
CREATE INDEX IF NOT EXISTS idx_sos_notifications_status ON sos_notifications (status) 
    WHERE status IN (0, 4);
CREATE INDEX IF NOT EXISTS idx_sos_notifications_retry ON sos_notifications (next_retry_at) 
    WHERE status = 4;

DROP TRIGGER IF EXISTS trigger_sos_notifications_updated_at ON sos_notifications;
CREATE TRIGGER trigger_sos_notifications_updated_at
    BEFORE UPDATE ON sos_notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sos_notifications IS 'ZNS/SMS notification tracking for SOS events';

-- TABLE 4: sos_escalation_calls
-- Purpose: Track escalation calls per SOS event
-- Owner: schedule-service
-- Retention: 90 days
CREATE TABLE IF NOT EXISTS sos_escalation_calls (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES sos_events(event_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Contact info (denormalized)
    contact_name VARCHAR(100) NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    escalation_order SMALLINT NOT NULL,
    
    -- Call type
    call_type VARCHAR(50) NOT NULL,
    
    -- Status: 0=PENDING, 1=CALLING, 2=CONNECTED, 3=NO_ANSWER, 4=BUSY, 5=REJECTED, 6=FAILED, 7=SKIPPED
    status SMALLINT NOT NULL DEFAULT 0,
    
    -- Timing
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connected_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Timeout tracking
    timeout_seconds SMALLINT DEFAULT 20,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_call_status CHECK (status IN (0, 1, 2, 3, 4, 5, 6, 7)),
    CONSTRAINT chk_escalation_order CHECK (escalation_order BETWEEN 1 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_sos_escalation_calls_event ON sos_escalation_calls (event_id, escalation_order);
CREATE INDEX IF NOT EXISTS idx_sos_escalation_calls_pending ON sos_escalation_calls (status) 
    WHERE status IN (0, 1);

DROP TRIGGER IF EXISTS trigger_sos_escalation_calls_updated_at ON sos_escalation_calls;
CREATE TRIGGER trigger_sos_escalation_calls_updated_at
    BEFORE UPDATE ON sos_escalation_calls
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sos_escalation_calls IS 'Escalation call tracking for SOS events';

-- TABLE 5: first_aid_content
-- Purpose: CMS content for First Aid guide
-- Owner: schedule-service / CMS
-- Retention: Permanent
CREATE TABLE IF NOT EXISTS first_aid_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    display_order SMALLINT DEFAULT 0,
    icon_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_first_aid_category ON first_aid_content (category, display_order);
CREATE INDEX IF NOT EXISTS idx_first_aid_active ON first_aid_content (is_active) WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS trigger_first_aid_content_updated_at ON first_aid_content;
CREATE TRIGGER trigger_first_aid_content_updated_at
    BEFORE UPDATE ON first_aid_content
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed data for first_aid_content
INSERT INTO first_aid_content (category, title, icon_name, display_order, content) VALUES
('cpr', 'Hồi sinh tim phổi (CPR)', 'heart_plus', 1, '## Hướng dẫn CPR

### Bước 1: Kiểm tra phản ứng
- Gọi to và lay vai người bệnh

### Bước 2: Gọi cấp cứu
- Gọi 115 ngay lập tức

### Bước 3: Ép ngực
- Đặt 2 tay chồng lên nhau giữa ngực
- Ép sâu 5-6cm, tốc độ 100-120 lần/phút

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO'),
('stroke', 'Đột quỵ (F.A.S.T)', 'brain', 2, '## Nhận biết đột quỵ - F.A.S.T

### F - Face (Mặt)
- Một bên mặt bị xệ xuống?

### A - Arms (Tay)
- Một cánh tay yếu hoặc không nâng lên được?

### S - Speech (Nói)
- Nói không rõ, khó hiểu?

### T - Time (Thời gian)
- GỌI 115 NGAY LẬP TỨC!

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO'),
('low_sugar', 'Hạ đường huyết', 'sugar', 3, '## Xử lý hạ đường huyết

### Dấu hiệu
- Đổ mồ hôi, run tay
- Chóng mặt, tim đập nhanh
- Đói, yếu sức

### Xử lý ngay
1. Cho uống nước đường hoặc nước trái cây
2. Cho ăn bánh, kẹo
3. Nếu không tỉnh - GỌI 115

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO'),
('fall', 'Té ngã', 'fall', 4, '## Xử lý khi té ngã

### ĐỪNG
- Đừng di chuyển người bệnh ngay
- Đừng cho uống nước nếu không tỉnh

### NÊN
1. Kiểm tra ý thức
2. Kiểm tra vùng đau: đầu, cổ, lưng, tay chân
3. Nếu nghi gãy xương - KHÔNG di chuyển
4. GỌI 115

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE first_aid_content IS 'First Aid CMS content for SOS feature';

-- =============================================================================
-- PHÂN HỆ: KẾT NỐI NGƯỜI THÂN (tiếp) - PERMISSION TYPES, PERMISSIONS & NOTIFICATIONS
-- Version: 2.13 (KOLIA-1517)
-- =============================================================================

-- TABLE: connection_permission_types (LOOKUP) - NEW in v2.1
-- Purpose: Permission types lookup (similar to relationships pattern)
-- Owner: user-service
CREATE TABLE IF NOT EXISTS connection_permission_types (
    permission_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    description TEXT,
    icon VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    display_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Seed data (6 types)
INSERT INTO connection_permission_types (permission_code, name_vi, name_en, description, icon, display_order) VALUES
('health_overview', 'Xem tổng quan sức khỏe', 'View Health Overview', 'Chỉ số HA, báo cáo', 'heart', 1),
('emergency_alert', 'Nhận cảnh báo khẩn cấp', 'Receive Emergency Alerts', 'Cảnh báo HA bất thường, SOS', 'bell', 2),
('task_config', 'Thiết lập nhiệm vụ tuân thủ', 'Configure Tasks', 'Tạo/sửa nhiệm vụ tuân thủ', 'settings', 3),
('compliance_tracking', 'Theo dõi kết quả tuân thủ', 'Track Compliance', 'Xem lịch sử tuân thủ', 'check-circle', 4),
('proxy_execution', 'Thực hiện nhiệm vụ thay', 'Proxy Execution', 'Đánh dấu hoàn thành', 'user-check', 5),
('encouragement', 'Gửi lời động viên', 'Send Encouragement', 'Gửi tin nhắn', 'message-circle-heart', 6)
ON CONFLICT DO NOTHING;
COMMENT ON TABLE connection_permission_types IS 'Lookup table for connection permission types';

-- TABLE: connection_permissions (RBAC)
-- Purpose: 6 granular permissions per connection (FK to connection_permission_types)
-- Owner: user-service
CREATE TABLE IF NOT EXISTS connection_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    permission_code VARCHAR(30) NOT NULL REFERENCES connection_permission_types(permission_code),
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    
    CONSTRAINT uq_permission_per_contact UNIQUE (contact_id, permission_code)
);

CREATE INDEX IF NOT EXISTS idx_permissions_contact ON connection_permissions (contact_id);
CREATE INDEX IF NOT EXISTS idx_permissions_code ON connection_permissions (permission_code);

DROP TRIGGER IF EXISTS trigger_permissions_updated_at ON connection_permissions;
CREATE TRIGGER trigger_permissions_updated_at
    BEFORE UPDATE ON connection_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE connection_permissions IS 'RBAC permissions for caregiver connections (FK to connection_permission_types)';


-- TABLE: invite_notifications (v2.12)
-- Purpose: Track ZNS/SMS/Push delivery for connection events (BR-004)
-- Owner: schedule-service
-- Changes v2.12: Added notification_type, cancelled status (4), idempotency
CREATE TABLE IF NOT EXISTS invite_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id UUID NOT NULL REFERENCES connection_invites(invite_id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL DEFAULT 'INVITE_CREATED',  -- v2.12
    channel VARCHAR(10) NOT NULL,           -- 'ZNS' | 'SMS' | 'PUSH'
    status SMALLINT DEFAULT 0,              -- 0=pending, 1=sent, 2=delivered, 3=failed, 4=cancelled
    retry_count SMALLINT DEFAULT 0,         -- max 3 retries (BR-004)
    deep_link_sent BOOLEAN DEFAULT FALSE,   -- true for new users (BR-003)
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,               -- v2.12: when notification was cancelled
    error_message TEXT,
    external_message_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_notif_channel CHECK (channel IN ('ZNS', 'SMS', 'PUSH')),
    CONSTRAINT chk_notif_status CHECK (status IN (0, 1, 2, 3, 4)),  -- v2.12: added 4=cancelled
    CONSTRAINT chk_notif_type CHECK (notification_type IN (
        'INVITE_CREATED', 
        'INVITE_ACCEPTED', 
        'INVITE_REJECTED', 
        'CONNECTION_DISCONNECTED'
    )),
    CONSTRAINT chk_retry_max CHECK (retry_count <= 3)
);

CREATE INDEX IF NOT EXISTS idx_invite_notif_invite ON invite_notifications (invite_id);
CREATE INDEX IF NOT EXISTS idx_invite_notif_pending ON invite_notifications (status) WHERE status IN (0, 3);
CREATE INDEX IF NOT EXISTS idx_invite_notif_retry ON invite_notifications (retry_count) WHERE status = 3 AND retry_count < 3;
CREATE INDEX IF NOT EXISTS idx_invite_notif_type ON invite_notifications (notification_type);

-- v2.12: Unique constraint for idempotency (prevent duplicate notifications)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_invite_notification 
    ON invite_notifications (invite_id, notification_type, channel) 
    WHERE status IN (0, 1, 2);

COMMENT ON TABLE invite_notifications IS 'ZNS/SMS/Push delivery tracking for connection events (v2.12)';
COMMENT ON COLUMN invite_notifications.status IS '0:pending, 1:sent, 2:delivered, 3:failed, 4:cancelled';
COMMENT ON COLUMN invite_notifications.notification_type IS 'Event type: INVITE_CREATED, INVITE_ACCEPTED, etc.';
COMMENT ON COLUMN invite_notifications.deep_link_sent IS 'True for new users (BR-003)';
COMMENT ON COLUMN invite_notifications.cancelled_at IS 'When notification was cancelled (if status=4)';

-- =============================================================================
-- PHÂN HỆ: CAREGIVER ALERTS (US 1.2 - Nhận Cảnh Báo Bất Thường)
-- =============================================================================

-- TABLE: caregiver_alert_types (Lookup - 4 categories for UI filter)
-- Owner: user-service
CREATE TABLE IF NOT EXISTS caregiver_alert_types (
    type_id SMALLINT PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,  -- 'SOS', 'HA', 'MEDICATION', 'COMPLIANCE'
    name_vi VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    icon VARCHAR(10),
    display_order SMALLINT DEFAULT 0
);

-- Seed data: 4 categories matching UI filter tabs
INSERT INTO caregiver_alert_types (type_id, type_code, name_vi, name_en, icon, display_order) VALUES
    (1, 'SOS', 'Khẩn cấp', 'Emergency', '🚨', 1),
    (2, 'HA', 'Huyết áp', 'Blood Pressure', '❤️', 2),
    (3, 'MEDICATION', 'Thuốc', 'Medication', '💊', 3),
    (4, 'COMPLIANCE', 'Tuân thủ', 'Compliance', '📊', 4)
ON CONFLICT (type_id) DO NOTHING;

COMMENT ON TABLE caregiver_alert_types IS 'Lookup table for alert categories (4 types matching UI filter) - US 1.2';

-- TABLE: caregiver_alerts (Main alerts table)
-- Owner: user-service
CREATE TABLE IF NOT EXISTS caregiver_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- WHO receives the alert
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- WHO is the patient
    patient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Connection reference (for permission check)
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Alert classification (references 4 categories)
    alert_type_id SMALLINT NOT NULL REFERENCES caregiver_alert_types(type_id),
    priority SMALLINT NOT NULL DEFAULT 1,      -- 0=Critical/SOS, 1=High, 2=Medium, 3=Low
    
    -- Content (sub-type info encoded in title/body)
    title VARCHAR(150) NOT NULL,               -- E.g., "Mẹ - HA 185/125 (THA khẩn cấp)"
    body TEXT,                                 -- Optional longer description
    icon VARCHAR(20),                          -- Set by BE: '🚨', '⚠️', '💛', '💊', '📊'
    color VARCHAR(20),                         -- Set by BE: 'red', 'yellow', 'orange', 'gray'
    
    -- Navigation
    deeplink VARCHAR(200),
    
    -- Extra data (medication name, BP values, patient notes, etc.)
    payload JSONB,
    
    -- Status
    status SMALLINT DEFAULT 0,                -- 0=unread, 1=read
    
    -- Push delivery tracking
    push_status SMALLINT DEFAULT 0,           -- 0=pending, 1=sent, 2=delivered, 3=failed
    push_sent_at TIMESTAMPTZ,
    push_error TEXT,
    
    -- Source reference (which BP record, which medication, etc.)
    source_type VARCHAR(30),                  -- 'blood_pressure', 'medication', 'sos', 'compliance'
    source_id TEXT,                           -- ID in source table (BIGINT or UUID as string)
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP + INTERVAL '90 days',  -- BR-ALT-009
    
    -- Constraints
    CONSTRAINT chk_alert_status CHECK (status IN (0, 1)),
    CONSTRAINT chk_alert_push_status CHECK (push_status IN (0, 1, 2, 3)),
    CONSTRAINT chk_alert_priority CHECK (priority BETWEEN 0 AND 3)
);

-- Fast unread alerts query (for badge count)
CREATE INDEX IF NOT EXISTS idx_alerts_caregiver_unread 
    ON caregiver_alerts (caregiver_id, status, created_at DESC) 
    WHERE status = 0;

-- Patient alerts (for history filtered by patient)
CREATE INDEX IF NOT EXISTS idx_alerts_patient 
    ON caregiver_alerts (patient_id, created_at DESC);

-- UI filter by category
CREATE INDEX IF NOT EXISTS idx_alerts_type 
    ON caregiver_alerts (caregiver_id, alert_type_id, created_at DESC);

-- Priority sort (SOS first)
CREATE INDEX IF NOT EXISTS idx_alerts_priority 
    ON caregiver_alerts (priority, created_at DESC);

-- Retention cleanup
CREATE INDEX IF NOT EXISTS idx_alerts_expires 
    ON caregiver_alerts (expires_at);

-- Push retry queue
CREATE INDEX IF NOT EXISTS idx_alerts_push_pending 
    ON caregiver_alerts (push_status) 
    WHERE push_status IN (0, 3);

-- Debounce: 5-minute buckets (prevent duplicate alerts within 5 minutes)
-- Note: SOS (priority=0) excluded from debounce (BR-ALT-005)
-- 
-- PostgreSQL requires IMMUTABLE functions for index expressions.
-- Instead of date_trunc (which is STABLE, not IMMUTABLE for TIMESTAMPTZ),
-- we use epoch-based calculation which is IMMUTABLE.

-- Create immutable function for 5-minute bucket calculation
CREATE OR REPLACE FUNCTION alert_debounce_bucket(ts TIMESTAMPTZ)
RETURNS BIGINT AS $$
    -- Convert to epoch and divide by 300 seconds (5 minutes)
    -- This creates a bucket ID that represents 5-minute intervals
    SELECT FLOOR(EXTRACT(EPOCH FROM ts) / 300)::BIGINT;
$$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;

COMMENT ON FUNCTION alert_debounce_bucket IS 'Calculate 5-minute bucket ID for alert debounce (BR-ALT-005)';

-- Create unique index using the immutable function
CREATE UNIQUE INDEX IF NOT EXISTS idx_alerts_debounce 
    ON caregiver_alerts (
        caregiver_id, 
        patient_id, 
        alert_type_id, 
        alert_debounce_bucket(created_at)
    )
    WHERE priority > 0;

COMMENT ON TABLE caregiver_alerts IS 'Health alerts for caregivers (US 1.2 - Nhận Cảnh Báo Bất Thường)';
COMMENT ON COLUMN caregiver_alerts.priority IS '0=Critical/SOS, 1=High, 2=Medium, 3=Low';
COMMENT ON COLUMN caregiver_alerts.payload IS 'Extra data: BP values, medication name, compliance rate, patient notes, etc.';
COMMENT ON COLUMN caregiver_alerts.status IS '0=unread, 1=read';
COMMENT ON COLUMN caregiver_alerts.push_status IS '0=pending, 1=sent, 2=delivered, 3=failed';
COMMENT ON COLUMN caregiver_alerts.expires_at IS '90-day retention per BR-ALT-009';

-- =============================================================================
-- US 1.3: ENCOURAGEMENT MESSAGES (Gửi Lời Động Viên)
-- Version: 2.24 (KOLIA-1520) - Caregiver → Patient messaging
-- =============================================================================

CREATE TABLE IF NOT EXISTS encouragement_messages (
    -- Primary Key
    encouragement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Sender/Receiver Relationship
    sender_id UUID NOT NULL,               -- Caregiver user_id
    patient_id UUID NOT NULL,              -- Patient user_id
    contact_id UUID NOT NULL,              -- Connection reference
    
    -- Message Content (BR-002: max 150 Unicode chars)
    content VARCHAR(150) NOT NULL,
    
    -- Relationship metadata (Perspective Display Standard v2.23)
    -- relationship_display = How PATIENT refers to CAREGIVER
    sender_name VARCHAR(100),              -- e.g., "Huy" (Caregiver's display name)
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    relationship_display VARCHAR(100),     -- e.g., "Con gái" (Patient's perspective)
    
    -- Status Tracking
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    
    -- Timestamps
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    CONSTRAINT fk_enc_sender FOREIGN KEY (sender_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_enc_patient FOREIGN KEY (patient_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_enc_contact FOREIGN KEY (contact_id) 
        REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    
    -- Business Rule Constraints
    CONSTRAINT chk_enc_content_length CHECK (char_length(content) <= 150),
    CONSTRAINT chk_enc_different_users CHECK (sender_id != patient_id)
);

-- Index for Patient modal (unread messages, newest first)
CREATE INDEX IF NOT EXISTS idx_enc_patient_unread 
    ON encouragement_messages (patient_id, is_read, sent_at DESC) 
    WHERE is_read = FALSE;

-- Index for 24h window query (Patient list)
CREATE INDEX IF NOT EXISTS idx_enc_patient_recent 
    ON encouragement_messages (patient_id, sent_at DESC);

-- Index for daily quota check (BR-001: max 10/day/patient)
-- Note: Use timestamp range query instead of DATE() to leverage this index
-- Query pattern: WHERE sender_id = ? AND patient_id = ? AND sent_at >= date_trunc('day', now()) AND sent_at < date_trunc('day', now()) + interval '1 day'
CREATE INDEX IF NOT EXISTS idx_enc_quota 
    ON encouragement_messages (sender_id, patient_id, sent_at);

-- Index for sender history (Caregiver view)
CREATE INDEX IF NOT EXISTS idx_enc_sender 
    ON encouragement_messages (sender_id, sent_at DESC);

-- Trigger for updated_at
CREATE TRIGGER trigger_enc_messages_updated_at
    BEFORE UPDATE ON encouragement_messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE encouragement_messages IS 'Encouragement messages from Caregiver to Patient (US 1.3 - Gửi Lời Động Viên)';
COMMENT ON COLUMN encouragement_messages.sender_id IS 'Caregiver who sent the message';
COMMENT ON COLUMN encouragement_messages.patient_id IS 'Patient who receives the message';
COMMENT ON COLUMN encouragement_messages.content IS 'Message content, max 150 Unicode chars (BR-002)';
COMMENT ON COLUMN encouragement_messages.relationship_display IS 'How Patient refers to Caregiver (Perspective Standard v2.23)';
COMMENT ON COLUMN encouragement_messages.sent_at IS 'Timestamp when message was sent (for 24h window filter)';

-- =============================================================================
--                            KẾT THÚC SCRIPT KHỞI TẠO
-- ============================================================================

