-- ============================================================================
-- 8_kcnt_invite_type_migration.sql
-- Version: v4.0
-- Purpose: Migrate legacy invite_type values to v4.0 standard
--   patient_to_caregiver → add_caregiver
--   caregiver_to_patient → add_patient
-- ============================================================================
-- IMPORTANT: Run AFTER 7_kcnt_v4_family_groups.sql
-- Script 7 already drops the old constraint and adds new one with v4.0 values.
-- This script migrates existing data to match the new constraint.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. DATA MIGRATION: Update existing records
-- ============================================================================

-- Mapping logic:
-- patient_to_caregiver (Patient mời Caregiver) → add_caregiver (Admin thêm Caregiver)
-- caregiver_to_patient (Caregiver mời Patient) → add_patient (Admin thêm Patient)

UPDATE connection_invites
SET invite_type = 'add_caregiver'
WHERE invite_type = 'patient_to_caregiver';

UPDATE connection_invites
SET invite_type = 'add_patient'
WHERE invite_type = 'caregiver_to_patient';

-- ============================================================================
-- 2. VERIFICATION
-- ============================================================================

DO $$
DECLARE
    legacy_count INTEGER;
    v4_count INTEGER;
BEGIN
    -- Ensure no legacy values remain
    SELECT COUNT(*) INTO legacy_count
    FROM connection_invites
    WHERE invite_type IN ('patient_to_caregiver', 'caregiver_to_patient');

    IF legacy_count > 0 THEN
        RAISE EXCEPTION 'MIGRATION FAILED: % legacy invite_type records still exist', legacy_count;
    END IF;

    -- Count migrated records
    SELECT COUNT(*) INTO v4_count
    FROM connection_invites
    WHERE invite_type IN ('add_patient', 'add_caregiver');

    RAISE NOTICE '✅ invite_type migration complete: % records now using v4.0 values', v4_count;
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (run manually if needed)
-- ============================================================================
-- BEGIN;
-- 
-- -- Reverse data migration
-- UPDATE connection_invites SET invite_type = 'patient_to_caregiver' WHERE invite_type = 'add_caregiver';
-- UPDATE connection_invites SET invite_type = 'caregiver_to_patient' WHERE invite_type = 'add_patient';
-- 
-- -- Restore legacy constraint
-- ALTER TABLE connection_invites DROP CONSTRAINT IF EXISTS chk_invite_type;
-- ALTER TABLE connection_invites ADD CONSTRAINT chk_invite_type CHECK (invite_type IN (
--     'patient_to_caregiver', 'caregiver_to_patient'
-- ));
-- 
-- COMMIT;
