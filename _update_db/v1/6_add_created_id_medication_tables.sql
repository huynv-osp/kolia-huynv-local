-- ============================================================================
-- CREATED_ID MIGRATION - Track who created medication records
-- Version: 1.0
-- Date: 2026-02-07
-- Purpose: Add created_id (UUID, nullable, FK to users.user_id) to
--          prescriptions, prescription_items, medication_schedules,
--          user_medication_feedback tables.
--          Distinguishes patient self-actions from caregiver-initiated actions.
-- ============================================================================

-- ============================================================================
-- STEP 1: Add created_id column to 4 tables
-- ============================================================================

-- prescriptions
ALTER TABLE prescriptions
ADD COLUMN IF NOT EXISTS created_id UUID REFERENCES users(user_id);

-- prescription_items
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS created_id UUID REFERENCES users(user_id);

-- medication_schedules
ALTER TABLE medication_schedules
ADD COLUMN IF NOT EXISTS created_id UUID REFERENCES users(user_id);

-- user_medication_feedback
ALTER TABLE user_medication_feedback
ADD COLUMN IF NOT EXISTS created_id UUID REFERENCES users(user_id);

-- ============================================================================
-- STEP 2: Add indexes for query performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_prescriptions_created_id
    ON prescriptions(created_id) WHERE created_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_prescription_items_created_id
    ON prescription_items(created_id) WHERE created_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_medication_schedules_created_id
    ON medication_schedules(created_id) WHERE created_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_medication_feedback_created_id
    ON user_medication_feedback(created_id) WHERE created_id IS NOT NULL;

-- ============================================================================
-- STEP 3: Backfill existing records (patient self-created)
-- ============================================================================

UPDATE prescriptions SET created_id = user_id WHERE created_id IS NULL;

-- prescription_items doesn't have user_id directly, must JOIN through prescriptions
UPDATE prescription_items pi
SET created_id = p.user_id
FROM prescriptions p
WHERE pi.prescription_id = p.prescription_id
  AND pi.created_id IS NULL;

UPDATE medication_schedules SET created_id = user_id WHERE created_id IS NULL;
UPDATE user_medication_feedback SET created_id = user_id WHERE created_id IS NULL;

-- ============================================================================
-- STEP 4: Add comments
-- ============================================================================

COMMENT ON COLUMN prescriptions.created_id IS 'User who created this record. If = user_id → patient self-action. If ≠ user_id → caregiver action.';
COMMENT ON COLUMN prescription_items.created_id IS 'User who created this record. If = user_id → patient self-action. If ≠ user_id → caregiver action.';
COMMENT ON COLUMN medication_schedules.created_id IS 'User who created this record. If = user_id → patient self-action. If ≠ user_id → caregiver action.';
COMMENT ON COLUMN user_medication_feedback.created_id IS 'User who created this record. If = user_id → patient self-action. If ≠ user_id → caregiver action.';

-- ============================================================================
-- VERIFY MIGRATION
-- ============================================================================

DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND column_name = 'created_id'
    AND table_name IN (
        'prescriptions',
        'prescription_items',
        'medication_schedules',
        'user_medication_feedback'
    );

    IF col_count = 4 THEN
        RAISE NOTICE '✅ created_id Migration v1.0 completed successfully.';
        RAISE NOTICE '   Tables: prescriptions, prescription_items, medication_schedules, user_medication_feedback';
        RAISE NOTICE '   All existing records backfilled with created_id = user_id';
    ELSE
        RAISE WARNING '⚠️ Migration incomplete. Only % of 4 tables have created_id column.', col_count;
    END IF;
END $$;

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
/*
ALTER TABLE user_medication_feedback DROP COLUMN IF EXISTS created_id;
ALTER TABLE medication_schedules DROP COLUMN IF EXISTS created_id;
ALTER TABLE prescription_items DROP COLUMN IF EXISTS created_id;
ALTER TABLE prescriptions DROP COLUMN IF EXISTS created_id;
*/
