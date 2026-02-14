-- ============================================================================
-- KCNT v4.0: Family Groups + Soft Disconnect Migration
-- Version: 4.0
-- Date: 2026-02-13
-- JIRA: KOLIA-1517
-- Purpose: Add family_groups, family_group_members tables.
--          Extend user_emergency_contacts with permission_revoked, family_group_id.
--          Extend connection_invites invite_type CHECK for v4.0 enum values.
-- Dependencies: 3_database-nguoi_than.sql (v2.22)
-- ============================================================================

-- ============================================================================
-- 1. CREATE TABLE: family_groups
-- v4.0: Nhóm gia đình liên kết với gói thanh toán
-- Admin = người kích hoạt gói (Payment SRS §2.8)
-- ============================================================================

CREATE TABLE IF NOT EXISTS family_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    subscription_id UUID,
    name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_fg_admin_id ON family_groups(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_fg_subscription_id ON family_groups(subscription_id);
CREATE INDEX IF NOT EXISTS idx_fg_status ON family_groups(status) WHERE status = 'active';

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_fg_updated_at ON family_groups;
CREATE TRIGGER trigger_fg_updated_at
    BEFORE UPDATE ON family_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE family_groups IS 'v4.0: Nhóm gia đình linked to payment subscription';
COMMENT ON COLUMN family_groups.admin_user_id IS 'Admin = người kích hoạt gói (Payment SRS §2.8)';
COMMENT ON COLUMN family_groups.subscription_id IS 'Link to payment subscription (nullable nếu free tier)';


-- ============================================================================
-- 2. CREATE TABLE: family_group_members
-- v4.0: Thành viên nhóm gia đình
-- BR-057: 1 user = 1 nhóm duy nhất (exclusive group constraint)
-- BR-048: 1 user có thể vừa Patient vừa CG (2 role entries)
-- ============================================================================

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

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_fgm_updated_at ON family_group_members;
CREATE TRIGGER trigger_fgm_updated_at
    BEFORE UPDATE ON family_group_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE family_group_members IS 'v4.0: Family group members with exclusive constraint (BR-057)';
COMMENT ON COLUMN family_group_members.role IS 'patient or caregiver — 1 user can have both roles (BR-048)';


-- ============================================================================
-- 3. ALTER TABLE: user_emergency_contacts
-- v4.0: Add soft disconnect support (permission_revoked) and group linkage
-- ============================================================================

-- v4.0: Tắt quyền theo dõi — connection giữ nguyên, restorable (BR-040)
ALTER TABLE user_emergency_contacts
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- v4.0: Link connection to its family group
ALTER TABLE user_emergency_contacts
ADD COLUMN IF NOT EXISTS family_group_id UUID REFERENCES family_groups(group_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_uec_family_group_id
    ON user_emergency_contacts(family_group_id) WHERE family_group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_uec_permission_revoked
    ON user_emergency_contacts(permission_revoked) WHERE permission_revoked = TRUE;

COMMENT ON COLUMN user_emergency_contacts.permission_revoked IS 'v4.0: Soft disconnect — TRUE = tắt quyền theo dõi, connection giữ (BR-040, BR-056 silent)';
COMMENT ON COLUMN user_emergency_contacts.family_group_id IS 'v4.0: Link to family group that created this connection';


-- ============================================================================
-- 4. ALTER CONSTRAINT: connection_invites.invite_type
-- v4.0: Thêm enum values cho Admin-only model, giữ nguyên legacy values
-- ============================================================================

-- Drop old constraint
ALTER TABLE connection_invites
DROP CONSTRAINT IF EXISTS chk_invite_type;

-- Add new constraint (v4.0 only — legacy values migrated by script 8)
ALTER TABLE connection_invites
ADD CONSTRAINT chk_invite_type CHECK (invite_type IN (
    'add_patient',            -- v4.0: Admin mời bệnh nhân vào nhóm
    'add_caregiver'           -- v4.0: Admin mời người thân vào nhóm
));

COMMENT ON COLUMN connection_invites.invite_type IS 'v4.0: add_patient (mời bệnh nhân) or add_caregiver (mời người thân)';


-- ============================================================================
-- 5. VERIFICATION
-- ============================================================================

DO $$
DECLARE
    new_table_count INTEGER;
    col_count INTEGER;
BEGIN
    -- Check new tables
    SELECT COUNT(*) INTO new_table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('family_groups', 'family_group_members');

    -- Check new columns on user_emergency_contacts
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'user_emergency_contacts'
    AND column_name IN ('permission_revoked', 'family_group_id');

    IF new_table_count = 2 AND col_count = 2 THEN
        RAISE NOTICE '✅ KCNT v4.0 Migration completed successfully.';
        RAISE NOTICE '   Tables: +family_groups, +family_group_members';
        RAISE NOTICE '   Columns: +permission_revoked, +family_group_id (on user_emergency_contacts)';
        RAISE NOTICE '   Constraint: invite_type extended (add_patient, add_caregiver)';
    ELSE
        RAISE WARNING '⚠️ KCNT v4.0 Migration incomplete. Tables=%, Columns=%', new_table_count, col_count;
    END IF;
END $$;


-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
/*
-- 1. Revert user_emergency_contacts columns
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS permission_revoked;
ALTER TABLE user_emergency_contacts DROP COLUMN IF EXISTS family_group_id;

-- 2. Revert invite_type constraint to v2.22
ALTER TABLE connection_invites DROP CONSTRAINT IF EXISTS chk_invite_type;
ALTER TABLE connection_invites ADD CONSTRAINT chk_invite_type
    CHECK (invite_type IN ('add_patient', 'add_caregiver'));

-- 3. Drop new tables (order matters due to FK)
DROP TABLE IF EXISTS family_group_members;
DROP TABLE IF EXISTS family_groups;
*/
