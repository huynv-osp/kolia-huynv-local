-- ============================================================================
-- CONNECTION FLOW FEATURE - DATABASE MIGRATION (REVISED v2.23)
-- Version: 2.23
-- Date: 2026-02-04
-- Purpose: Schema optimized + permission_types + is_viewing + caregiver_report_views
--          + invite_notifications enhanced (notification_type, cancelled status, idempotency)
--          + inverse_relationship_code for bidirectional relationship awareness (v2.13)
--          + relationship_inverse_mapping for gender-based inverse derivation (v2.21)
--          + inverse_relationship_display for UI perspective display (v2.23)
-- ============================================================================

-- ============================================================================
-- TABLE 1: relationships (LOOKUP)
-- Purpose: Standardized relationship types for both SOS and Caregiver features
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS relationships (
    relationship_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    category VARCHAR(30) DEFAULT 'family',
    display_order SMALLINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- Seed data (17 types)
INSERT INTO relationships (relationship_code, name_vi, name_en, category, display_order) VALUES
('con_trai', 'Con trai', 'Son', 'family', 1),
('con_gai', 'Con gái', 'Daughter', 'family', 2),
('anh_trai', 'Anh trai', 'Older brother', 'family', 3),
('chi_gai', 'Chị gái', 'Older sister', 'family', 4),
('em_trai', 'Em trai', 'Younger brother', 'family', 5),
('em_gai', 'Em gái', 'Younger sister', 'family', 6),
('chau_trai', 'Cháu trai', 'Grandson', 'family', 7),
('chau_gai', 'Cháu gái', 'Granddaughter', 'family', 8),
('bo', 'Bố', 'Father', 'family', 9),
('me', 'Mẹ', 'Mother', 'family', 10),
('ong_noi', 'Ông nội', 'Paternal grandfather', 'family', 11),
('ba_noi', 'Bà nội', 'Paternal grandmother', 'family', 12),
('ong_ngoai', 'Ông ngoại', 'Maternal grandfather', 'family', 13),
('ba_ngoai', 'Bà ngoại', 'Maternal grandmother', 'family', 14),
('vo', 'Vợ', 'Wife', 'spouse', 15),
('chong', 'Chồng', 'Husband', 'spouse', 16),
('khac', 'Khác', 'Other', 'other', 99)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE relationships IS 'Lookup table for relationship types (SOS + Caregiver)';

-- ============================================================================
-- TABLE 1.1: relationship_inverse_mapping (v2.21 - Gender-based Inverse)
-- Purpose: Derive inverse_relationship_code based on gender
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS relationship_inverse_mapping (
    relationship_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    target_gender SMALLINT NOT NULL,  -- 0: Nam, 1: Nữ
    inverse_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    PRIMARY KEY (relationship_code, target_gender)
);

-- Seed data: 34 mappings (17 relationships × 2 genders)
INSERT INTO relationship_inverse_mapping (relationship_code, target_gender, inverse_code) VALUES
('con_trai', 0, 'bo'),
('con_trai', 1, 'me'),
('con_gai', 0, 'bo'),
('con_gai', 1, 'me'),
('chau_trai', 0, 'ong_noi'),
('chau_trai', 1, 'ba_noi'),
('chau_gai', 0, 'ong_noi'),
('chau_gai', 1, 'ba_noi'),
('bo', 0, 'con_trai'),
('bo', 1, 'con_gai'),
('me', 0, 'con_trai'),
('me', 1, 'con_gai'),
('ong_noi', 0, 'chau_trai'),
('ong_noi', 1, 'chau_gai'),
('ba_noi', 0, 'chau_trai'),
('ba_noi', 1, 'chau_gai'),
('ong_ngoai', 0, 'chau_trai'),
('ong_ngoai', 1, 'chau_gai'),
('ba_ngoai', 0, 'chau_trai'),
('ba_ngoai', 1, 'chau_gai'),
('anh_trai', 0, 'em_trai'),
('anh_trai', 1, 'em_gai'),
('chi_gai', 0, 'em_trai'),
('chi_gai', 1, 'em_gai'),
('em_trai', 0, 'anh_trai'),
('em_trai', 1, 'chi_gai'),
('em_gai', 0, 'anh_trai'),
('em_gai', 1, 'chi_gai'),
('vo', 0, 'chong'),
('vo', 1, 'vo'),
('chong', 0, 'chong'),
('chong', 1, 'vo'),
('khac', 0, 'khac'),
('khac', 1, 'khac')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE relationship_inverse_mapping IS 'Gender-based inverse relationship derivation (v2.21)';
COMMENT ON COLUMN relationship_inverse_mapping.target_gender IS '0: Nam, 1: Nữ (gender of sender)';
COMMENT ON COLUMN relationship_inverse_mapping.inverse_code IS 'The derived inverse relationship code';

-- ============================================================================
-- TABLE 2: connection_invites
-- Purpose: Track invite lifecycle (pending/accepted/rejected)
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS connection_invites (
    invite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    receiver_name VARCHAR(100),
    invite_type VARCHAR(30) NOT NULL,      -- 'patient_to_caregiver' | 'caregiver_to_patient'
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- v2.13: Receiver mô tả Sender
    initial_permissions JSONB,              -- Generated by service layer from connection_permission_types
    status SMALLINT DEFAULT 0,              -- 0=pending, 1=accepted, 2=rejected, 3=cancelled
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_no_self_invite CHECK (sender_id != receiver_id),
    CONSTRAINT chk_invite_type CHECK (invite_type IN ('patient_to_caregiver', 'caregiver_to_patient')),
    CONSTRAINT chk_invite_status CHECK (status IN (0, 1, 2, 3))  -- 0=pending, 1=accepted, 2=rejected, 3=cancelled
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invites_sender ON connection_invites (sender_id);
CREATE INDEX IF NOT EXISTS idx_invites_receiver ON connection_invites (receiver_id) WHERE receiver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invites_phone ON connection_invites (receiver_phone);
CREATE INDEX IF NOT EXISTS idx_invites_pending ON connection_invites (status) WHERE status = 0;
-- Create new constraint với invite_type
CREATE UNIQUE INDEX idx_unique_pending_invite 
    ON connection_invites (sender_id, receiver_phone, invite_type) 
    WHERE status = 0;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_invites_updated_at ON connection_invites;
CREATE TRIGGER trigger_invites_updated_at
    BEFORE UPDATE ON connection_invites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE connection_invites IS 'Connection invite tracking for KOLIA-1517';
COMMENT ON COLUMN connection_invites.status IS '0:pending, 1:accepted, 2:rejected, 3:cancelled';
COMMENT ON COLUMN connection_invites.invite_type IS 'patient_to_caregiver or caregiver_to_patient';
COMMENT ON COLUMN connection_invites.relationship_code IS 'v2.13: Sender mô tả Receiver là [X]';
COMMENT ON COLUMN connection_invites.inverse_relationship_code IS 'v2.13: Receiver mô tả Sender là [X]';

-- ============================================================================
-- EXTEND: user_emergency_contacts (ADD COLUMNS)
-- Purpose: Support both SOS contacts AND caregiver connections
-- Backward compatible with SOS feature
-- ============================================================================

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS linked_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL;

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS contact_type VARCHAR(20) DEFAULT 'emergency';  -- 'emergency' | 'caregiver' | 'both'

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS relationship_code VARCHAR(30) REFERENCES relationships(relationship_code);

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS invite_id UUID REFERENCES connection_invites(invite_id) ON DELETE SET NULL;

-- NEW v2.7: is_viewing column for profile selection (BR-026)
ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS is_viewing BOOLEAN DEFAULT FALSE;

-- NEW v2.13: inverse_relationship_code for bidirectional awareness
-- relationship_code = Patient (user_id) mô tả Caregiver (linked_user_id)
-- inverse_relationship_code = Caregiver (linked_user_id) mô tả Patient (user_id)
ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code);

-- Add constraint for contact_type
DO $$ BEGIN
    ALTER TABLE user_emergency_contacts
    ADD CONSTRAINT chk_contact_type CHECK (contact_type IN ('emergency', 'caregiver', 'both', 'disconnected'));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- MIGRATE: relationship (old) → relationship_code (new)
-- Purpose: Migrate existing SOS contacts to use relationships lookup
-- ============================================================================

-- Step 1: Migrate existing data từ relationship cũ sang relationship_code mới
-- (Chỉ chạy nếu cột 'relationship' tồn tại - backward compatible)
DO $$ 
BEGIN
    -- Check if column exists before migrating
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_emergency_contacts' AND column_name = 'relationship'
    ) THEN
        EXECUTE '
            UPDATE user_emergency_contacts SET relationship_code = 
                CASE 
                    WHEN LOWER(TRIM(relationship)) IN (''con trai'', ''con_trai'') THEN ''con_trai''
                    WHEN LOWER(TRIM(relationship)) IN (''con gái'', ''con_gai'') THEN ''con_gai''
                    WHEN LOWER(TRIM(relationship)) IN (''anh trai'', ''anh_trai'') THEN ''anh_trai''
                    WHEN LOWER(TRIM(relationship)) IN (''chị gái'', ''chi_gai'') THEN ''chi_gai''
                    WHEN LOWER(TRIM(relationship)) IN (''em trai'', ''em_trai'') THEN ''em_trai''
                    WHEN LOWER(TRIM(relationship)) IN (''em gái'', ''em_gai'') THEN ''em_gai''
                    WHEN LOWER(TRIM(relationship)) IN (''cháu trai'', ''chau_trai'') THEN ''chau_trai''
                    WHEN LOWER(TRIM(relationship)) IN (''cháu gái'', ''chau_gai'') THEN ''chau_gai''
                    WHEN LOWER(TRIM(relationship)) IN (''bố'', ''bo'', ''cha'') THEN ''bo''
                    WHEN LOWER(TRIM(relationship)) IN (''mẹ'', ''me'', ''má'') THEN ''me''
                    WHEN LOWER(TRIM(relationship)) IN (''ông nội'', ''ong_noi'') THEN ''ong_noi''
                    WHEN LOWER(TRIM(relationship)) IN (''bà nội'', ''ba_noi'') THEN ''ba_noi''
                    WHEN LOWER(TRIM(relationship)) IN (''ông ngoại'', ''ong_ngoai'') THEN ''ong_ngoai''
                    WHEN LOWER(TRIM(relationship)) IN (''bà ngoại'', ''ba_ngoai'') THEN ''ba_ngoai''
                    WHEN LOWER(TRIM(relationship)) IN (''vợ'', ''vo'') THEN ''vo''
                    WHEN LOWER(TRIM(relationship)) IN (''chồng'', ''chong'') THEN ''chong''
                    ELSE ''khac''
                END
            WHERE relationship IS NOT NULL 
              AND relationship_code IS NULL
        ';
        RAISE NOTICE '✅ Migrated relationship → relationship_code';
    ELSE
        RAISE NOTICE 'ℹ️ Column "relationship" does not exist, skipping migration.';
    END IF;
END $$;

-- Step 2: Drop old relationship column (nếu tồn tại)
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS relationship;

-- Indexes for caregiver queries
CREATE INDEX IF NOT EXISTS idx_contacts_linked_user 
    ON user_emergency_contacts (linked_user_id) WHERE linked_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_type 
    ON user_emergency_contacts (user_id, contact_type);

-- ============================================================================
-- CONSTRAINT: Prevent duplicate caregiver connections (BR-007 extended)
-- Scenario: A đang theo dõi B → A không thể tạo thêm connection với B nữa
-- Note: Chỉ apply cho caregiver connections, không apply cho emergency contacts
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_caregiver_connection
    ON user_emergency_contacts (user_id, linked_user_id) 
    WHERE linked_user_id IS NOT NULL 
      AND contact_type IN ('caregiver', 'both');

COMMENT ON COLUMN user_emergency_contacts.linked_user_id IS 'App user ID if caregiver has account';
COMMENT ON COLUMN user_emergency_contacts.contact_type IS 'emergency (SOS), caregiver (connection), both';
COMMENT ON COLUMN user_emergency_contacts.is_viewing IS 'Currently viewing this patient (only one per user)';
COMMENT ON COLUMN user_emergency_contacts.relationship_code IS 'v2.13: Patient (user_id) mô tả Caregiver (linked_user_id) là [X]';
COMMENT ON COLUMN user_emergency_contacts.inverse_relationship_code IS 'v2.13: Caregiver (linked_user_id) mô tả Patient (user_id) là [X]';

-- ============================================================================
-- CONSTRAINT: Only ONE is_viewing=true per user (BR-026)
-- Ensures Caregiver can only view one Patient at a time
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_viewing_patient
    ON user_emergency_contacts (user_id) 
    WHERE is_viewing = TRUE 
      AND contact_type IN ('caregiver', 'both');

CREATE INDEX IF NOT EXISTS idx_contacts_viewing 
    ON user_emergency_contacts (user_id, is_viewing) WHERE is_viewing = TRUE;

-- ============================================================================
-- TABLE 3: connection_permission_types (LOOKUP) - NEW in v2.1
-- Purpose: Permission types lookup (similar to relationships pattern)
-- Owner: user-service
-- ============================================================================

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
('health_overview', 'Xem tổng quan sức khỏe', 'View Health Overview', 'Cho phép xem chỉ số huyết áp, tâm trạng và hoạt động gần đây', 'heart', 1),
('emergency_alert', 'Nhận cảnh báo khẩn cấp', 'Receive Emergency Alerts', 'Nhận thông báo khi có tình huống khẩn cấp', 'bell', 2),
('task_config', 'Cấu hình nhiệm vụ', 'Configure Tasks', 'Cho phép tạo và chỉnh sửa lịch nhắc nhở đo huyết áp, uống thuốc', 'settings', 3),
('compliance_tracking', 'Theo dõi tuân thủ', 'Track Compliance', 'Xem lịch sử hoàn thành nhiệm vụ và mức độ tuân thủ', 'check-circle', 4),
('proxy_execution', 'Thực hiện thay mặt', 'Proxy Execution', 'Cho phép ghi nhận dữ liệu sức khỏe thay cho bệnh nhân', 'user-check', 5),
('encouragement', 'Gửi động viên', 'Send Encouragement', 'Cho phép gửi tin nhắn động viên và nhắc nhở', 'message-circle-heart', 6)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE connection_permission_types IS 'Lookup table for connection permission types';

-- ============================================================================
-- TABLE 4: connection_permissions (RBAC)
-- Purpose: 6 granular permissions per connection (FK to connection_permission_types)
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS connection_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    permission_code VARCHAR(30) NOT NULL REFERENCES connection_permission_types(permission_code),
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    
    CONSTRAINT uq_permission_per_contact UNIQUE (contact_id, permission_code)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_permissions_contact ON connection_permissions (contact_id);
CREATE INDEX IF NOT EXISTS idx_permissions_code ON connection_permissions (permission_code);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_permissions_updated_at ON connection_permissions;
CREATE TRIGGER trigger_permissions_updated_at
    BEFORE UPDATE ON connection_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE connection_permissions IS 'RBAC permissions for caregiver connections (FK to connection_permission_types)';

-- ============================================================================
-- TRIGGER: Auto-create permissions on caregiver contact creation (BR-009)
-- Uses connection_permission_types lookup for dynamic permission codes
-- ============================================================================

CREATE OR REPLACE FUNCTION create_default_connection_permissions()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.contact_type IN ('caregiver', 'both') AND NEW.linked_user_id IS NOT NULL THEN
        -- Insert all active permission types from lookup table
        INSERT INTO connection_permissions (contact_id, permission_code, is_enabled)
        SELECT NEW.contact_id, cpt.permission_code, TRUE
        FROM connection_permission_types cpt
        WHERE cpt.is_active = TRUE
        ON CONFLICT (contact_id, permission_code) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_default_permissions ON user_emergency_contacts;
CREATE TRIGGER trigger_create_default_permissions
    AFTER INSERT ON user_emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION create_default_connection_permissions();

-- ============================================================================
-- TABLE 5: invite_notifications (v2.12)
-- Purpose: Track ZNS/SMS/Push delivery for connection events (BR-004)
-- Owner: schedule-service
-- Changes v2.12: Added notification_type, cancelled status (4), idempotency constraint
-- ============================================================================

CREATE TABLE IF NOT EXISTS invite_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id UUID NOT NULL REFERENCES connection_invites(invite_id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL DEFAULT 'INVITE_CREATED',  -- NEW v2.12
    channel VARCHAR(10) NOT NULL,           -- 'ZNS' | 'SMS' | 'PUSH'
    status SMALLINT DEFAULT 0,              -- 0=pending, 1=sent, 2=delivered, 3=failed, 4=cancelled
    retry_count SMALLINT DEFAULT 0,         -- max 3 retries (BR-004)
    deep_link_sent BOOLEAN DEFAULT FALSE,   -- true for new users (BR-003)
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,               -- NEW v2.12: when notification was cancelled
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invite_notif_invite ON invite_notifications (invite_id);
CREATE INDEX IF NOT EXISTS idx_invite_notif_pending ON invite_notifications (status) WHERE status IN (0, 3);
CREATE INDEX IF NOT EXISTS idx_invite_notif_retry ON invite_notifications (retry_count) WHERE status = 3 AND retry_count < 3;
CREATE INDEX IF NOT EXISTS idx_invite_notif_type ON invite_notifications (notification_type);

-- NEW v2.12: Unique constraint for idempotency (prevent duplicate notifications)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_invite_notification 
    ON invite_notifications (invite_id, notification_type, channel) 
    WHERE status IN (0, 1, 2);

COMMENT ON TABLE invite_notifications IS 'ZNS/SMS/Push delivery tracking for connection events (v2.12)';
COMMENT ON COLUMN invite_notifications.status IS '0:pending, 1:sent, 2:delivered, 3:failed, 4:cancelled';
COMMENT ON COLUMN invite_notifications.notification_type IS 'Event type: INVITE_CREATED, INVITE_ACCEPTED, INVITE_REJECTED, CONNECTION_DISCONNECTED';
COMMENT ON COLUMN invite_notifications.deep_link_sent IS 'True for new users (BR-003)';
COMMENT ON COLUMN invite_notifications.cancelled_at IS 'When notification was cancelled (if status=4)';

-- ============================================================================
-- TABLE 6: caregiver_report_views (v2.11)
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

-- ============================================================================
-- VERIFY MIGRATION
-- ============================================================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN (
        'relationships',
        'relationship_inverse_mapping',
        'connection_permission_types',
        'connection_invites',
        'connection_permissions',
        'invite_notifications',
        'caregiver_report_views'
    );
    
    IF table_count = 7 THEN
        RAISE NOTICE '✅ Connection Flow Migration v2.23 completed successfully.';
        RAISE NOTICE '   Tables: relationships, relationship_inverse_mapping, connection_permission_types, connection_invites, connection_permissions, invite_notifications, caregiver_report_views';
        RAISE NOTICE '   Extended: user_emergency_contacts (+7 columns incl. is_viewing, inverse_relationship_code)';
        RAISE NOTICE '   v2.12: invite_notifications +notification_type, +cancelled_at, +idempotency constraint';
        RAISE NOTICE '   v2.13: +inverse_relationship_code for bidirectional relationship awareness';
        RAISE NOTICE '   v2.21: +relationship_inverse_mapping for gender-based inverse derivation';
        RAISE NOTICE '   v2.23: perspective display standard with inverse_relationship_display';
    ELSE
        RAISE WARNING '⚠️ Migration incomplete. Only % of 7 new tables found.', table_count;
    END IF;
END $$;

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
/*
DROP TRIGGER IF EXISTS trigger_create_default_permissions ON user_emergency_contacts;
DROP FUNCTION IF EXISTS create_default_connection_permissions();
DROP TABLE IF EXISTS caregiver_report_views;
DROP TABLE IF EXISTS invite_notifications;
DROP TABLE IF EXISTS connection_permissions;
DROP TABLE IF EXISTS connection_permission_types;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS inverse_relationship_code;  -- v2.13
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS is_viewing;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS invite_id;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS relationship_code;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS contact_type;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS linked_user_id;
ALTER TABLE connection_invites DROP COLUMN IF EXISTS inverse_relationship_code;  -- v2.13
DROP TABLE IF EXISTS connection_invites;
DROP TABLE IF EXISTS relationships;
*/

