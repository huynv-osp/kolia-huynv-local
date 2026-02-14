-- =============================================================================
-- Migration: Add family_group_id to connection_invites
-- Version: v5.0
-- Purpose: Link invites to specific family groups
-- Depends on: family_groups table (from 7_kcnt_v4_family_groups.sql)
-- =============================================================================

-- Step 1: Add column
ALTER TABLE connection_invites
ADD COLUMN IF NOT EXISTS family_group_id UUID REFERENCES family_groups(group_id);

-- Step 2: Index for group-based queries
CREATE INDEX IF NOT EXISTS idx_invites_family_group
    ON connection_invites(family_group_id) WHERE family_group_id IS NOT NULL;

-- Step 3: Comment
COMMENT ON COLUMN connection_invites.family_group_id 
    IS 'v5.0: The family group this invite belongs to';


ALTER TABLE connection_invites DROP COLUMN IF EXISTS initial_permissions;

-- Verification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'connection_invites' 
        AND column_name = 'family_group_id'
    ) THEN
        RAISE NOTICE '✅ connection_invites.family_group_id added successfully';
    ELSE
        RAISE WARNING '❌ connection_invites.family_group_id NOT found';
    END IF;
END $$;
