-- =============================================================================
-- Migration V2.3: Add symptom_type column to user_symptoms table
-- 
-- Problem: Column symptom_type defined in _Alio_database_create.sql (line 1737) 
-- but missing from staging/production database. This causes:
--   - "column symptom_type does not exist" errors in report queries
--   - "NoneType has no len()" cascading errors in aggregate_daily_reports
--
-- Fix: Add the missing column with matching definition from design spec
-- =============================================================================

BEGIN;

-- Add symptom_type column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_symptoms' 
        AND column_name = 'symptom_type'
    ) THEN
        ALTER TABLE user_symptoms 
            ADD COLUMN symptom_type VARCHAR(150);
        
        COMMENT ON COLUMN user_symptoms.symptom_type IS 
            'Loại triệu chứng: physical, psychological, gastrointestinal, respiratory, cardiovascular, neurological, general, lifestyle, symptom';
        
        RAISE NOTICE 'Added symptom_type column to user_symptoms table';
    ELSE
        RAISE NOTICE 'Column symptom_type already exists in user_symptoms, skipping';
    END IF;
END $$;

-- Recreate index for symptom_type (matches _Alio_database_create.sql)
CREATE INDEX IF NOT EXISTS idx_user_symptoms_type_status 
    ON user_symptoms (user_id, symptom_type);

COMMIT;
