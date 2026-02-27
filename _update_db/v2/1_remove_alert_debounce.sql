-- =============================================================================
-- Migration: Remove Alert Debounce Constraint
-- Version: v2.1
-- Date: 2026-02-27
-- Description: Drop idx_alerts_debounce unique index and alert_debounce_bucket function.
--              The 5-minute debounce was blocking multiple WRONG_DOSE alerts
--              for different medications reported in the same time window
--              because it only used alert_type_id (=3 for all medications)
--              without source_id to differentiate drugs.
-- =============================================================================

-- Step 1: Drop the unique index
DROP INDEX IF EXISTS idx_alerts_debounce;

-- Step 2: Drop the helper function (no longer needed)
DROP FUNCTION IF EXISTS alert_debounce_bucket(TIMESTAMPTZ);
