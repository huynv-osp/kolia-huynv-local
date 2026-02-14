-- ============================================================================
-- Migration: Drop chk_no_self_invite constraint
-- Version: v5.1
-- Date: 2026-02-14
-- Purpose: Allow Admin to self-invite per SRS A1.3 (BR-048, BR-049)
--          Admin can add themselves as Patient or Caregiver in their own group
-- ============================================================================

ALTER TABLE connection_invites DROP CONSTRAINT IF EXISTS chk_no_self_invite;

-- Verify
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'chk_no_self_invite'
    ) THEN
        RAISE NOTICE '✅ chk_no_self_invite constraint dropped successfully';
    ELSE
        RAISE WARNING '⚠️ chk_no_self_invite constraint still exists';
    END IF;
END $$;
