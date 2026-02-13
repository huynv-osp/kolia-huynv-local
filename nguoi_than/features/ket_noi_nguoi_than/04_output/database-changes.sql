-- =============================================================================
-- Database Changes: KOLIA-1517 - Kết nối Người thân (v4.0)
-- Phase: 4 - Output (Feature Analysis)
-- Date: 2026-02-13
-- SRS Version: v4.0
-- Revision: v4.0 - Family Group tables, invite_type update, soft disconnect
-- Note: Column names, FKs, and types MUST match 3_database-nguoi_than.sql (v2.22)
--       users table: PK = user_id UUID (NOT id BIGINT)
-- =============================================================================

-- =========================================
-- SECTION A: EXISTING TABLES (v2.22)
-- Source: docs/_update_db/3_database-nguoi_than.sql
-- Referenced here for completeness only.
-- =========================================

-- A1. Relationships (v2.22 — 14 types)
CREATE TABLE IF NOT EXISTS relationships (
    relationship_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    category VARCHAR(30) DEFAULT 'family',
    display_order SMALLINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- A2. Relationship Inverse Mapping (v2.21)
CREATE TABLE IF NOT EXISTS relationship_inverse_mapping (
    relationship_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    target_gender SMALLINT NOT NULL,  -- 0: Nam, 1: Nữ
    inverse_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    PRIMARY KEY (relationship_code, target_gender)
);

-- A3. Connection Invites (v2.22, MODIFIED v4.0)
CREATE TABLE IF NOT EXISTS connection_invites (
    invite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    receiver_name VARCHAR(100),
    invite_type VARCHAR(30) NOT NULL,
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    initial_permissions JSONB,
    status SMALLINT DEFAULT 0,  -- 0=pending, 1=accepted, 2=rejected, 3=cancelled
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_no_self_invite CHECK (sender_id != receiver_id),
    CONSTRAINT chk_invite_type CHECK (invite_type IN (
        'patient_to_caregiver', 'caregiver_to_patient',  -- legacy
        'add_patient', 'add_caregiver'                    -- v4.0
    )),
    CONSTRAINT chk_invite_status CHECK (status IN (0, 1, 2, 3))
);

-- A4. user_emergency_contacts (extended in each version)
-- Original: contact_id, user_id, name, phone, ...
-- v2.x additions: linked_user_id, contact_type, relationship_code, invite_id, is_viewing, inverse_relationship_code
-- v4.0 additions: permission_revoked, family_group_id (Section B)

-- A5. Connection Permission Types (v2.1 — 6 types)
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

INSERT INTO connection_permission_types (permission_code, name_vi, name_en, description, icon, display_order) VALUES
('health_overview', 'Xem tổng quan sức khỏe', 'View Health Overview', 'Chỉ số HA, báo cáo', 'heart', 1),
('emergency_alert', 'Nhận cảnh báo khẩn cấp', 'Receive Emergency Alerts', 'Cảnh báo HA bất thường, SOS', 'bell', 2),
('task_config', 'Thiết lập nhiệm vụ tuân thủ', 'Configure Tasks', 'Tạo/sửa nhiệm vụ tuân thủ', 'settings', 3),
('compliance_tracking', 'Theo dõi kết quả tuân thủ', 'Track Compliance', 'Xem lịch sử tuân thủ', 'check-circle', 4),
('proxy_execution', 'Thực hiện nhiệm vụ thay', 'Proxy Execution', 'Đánh dấu hoàn thành', 'user-check', 5),
('encouragement', 'Gửi lời động viên', 'Send Encouragement', 'Gửi tin nhắn', 'message-circle-heart', 6)
ON CONFLICT DO NOTHING;

-- A6. Connection Permissions (v2.1)
CREATE TABLE IF NOT EXISTS connection_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    permission_code VARCHAR(30) NOT NULL REFERENCES connection_permission_types(permission_code),
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),

    CONSTRAINT uq_permission_per_contact UNIQUE (contact_id, permission_code)
);

-- A7. Invite Notifications (v2.12)
CREATE TABLE IF NOT EXISTS invite_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id UUID NOT NULL REFERENCES connection_invites(invite_id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL DEFAULT 'INVITE_CREATED',
    channel VARCHAR(10) NOT NULL,
    status SMALLINT DEFAULT 0,
    retry_count SMALLINT DEFAULT 0,
    deep_link_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    error_message TEXT,
    external_message_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_notif_channel CHECK (channel IN ('ZNS', 'SMS', 'PUSH')),
    CONSTRAINT chk_notif_status CHECK (status IN (0, 1, 2, 3, 4)),
    CONSTRAINT chk_notif_type CHECK (notification_type IN (
        'INVITE_CREATED', 'INVITE_ACCEPTED', 'INVITE_REJECTED', 'CONNECTION_DISCONNECTED'
    )),
    CONSTRAINT chk_retry_max CHECK (retry_count <= 3)
);

-- A8. Caregiver Report Views (v2.11)
CREATE TABLE IF NOT EXISTS caregiver_report_views (
    id BIGSERIAL PRIMARY KEY,
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    report_id BIGINT NOT NULL REFERENCES report_periodic(report_id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT idx_unique_caregiver_report UNIQUE (caregiver_id, report_id)
);


-- =========================================
-- SECTION B: NEW TABLES & CHANGES (v4.0)
-- Family Group model + UEC extensions
-- Migration file: docs/_update_db/7_kcnt_v4_family_groups.sql
-- =========================================

-- B1. Family Groups (NEW v4.0)
CREATE TABLE IF NOT EXISTS family_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    subscription_id UUID,
    name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- B2. Family Group Members (NEW v4.0)
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

-- BR-057: Exclusive Group
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_single_group
    ON family_group_members(user_id, role) WHERE status = 'active';

-- B3. ALTER user_emergency_contacts (v4.0)
ALTER TABLE user_emergency_contacts
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

ALTER TABLE user_emergency_contacts
ADD COLUMN IF NOT EXISTS family_group_id UUID REFERENCES family_groups(group_id);

-- B4. UPDATE invite_type CHECK constraint
ALTER TABLE connection_invites DROP CONSTRAINT IF EXISTS chk_invite_type;
ALTER TABLE connection_invites ADD CONSTRAINT chk_invite_type CHECK (invite_type IN (
    'patient_to_caregiver', 'caregiver_to_patient',
    'add_patient', 'add_caregiver'
));


-- =========================================
-- SECTION C: ROLLBACK SCRIPT
-- =========================================
/*
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS permission_revoked;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS family_group_id;
ALTER TABLE connection_invites DROP CONSTRAINT IF EXISTS chk_invite_type;
ALTER TABLE connection_invites ADD CONSTRAINT chk_invite_type
    CHECK (invite_type IN ('patient_to_caregiver', 'caregiver_to_patient'));
DROP TABLE IF EXISTS family_group_members;
DROP TABLE IF EXISTS family_groups;
*/
