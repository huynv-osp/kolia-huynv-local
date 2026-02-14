-- ============================================================================
-- Migration: Merge proxy_execution → compliance_tracking (6→5 permissions)
-- SRS v4.0: proxy_execution functionality absorbed into compliance_tracking
-- Date: 2026-02-14
-- ============================================================================

-- Clear any aborted transaction
ROLLBACK;

BEGIN;

-- ============================================================================
-- Step 1: Delete all existing proxy_execution permission entries from connections
-- This removes granted proxy_execution permissions from all active connections.
-- These capabilities are now covered by compliance_tracking.
-- ============================================================================
DELETE FROM connection_permissions
WHERE permission_code = 'proxy_execution';

-- ============================================================================
-- Step 2: Update compliance_tracking display info
-- Now covers both "theo dõi tuân thủ" + "thực hiện thay"
-- ============================================================================
UPDATE connection_permission_types
SET name_vi = 'Theo dõi & thực hiện nhiệm vụ tuân thủ',
    name_en = 'Track & Execute Compliance',
    description = 'Xem kết quả & thực hiện thay nhiệm vụ'
WHERE permission_code = 'compliance_tracking';

-- ============================================================================
-- Step 3: Delete proxy_execution from lookup table
-- ============================================================================
DELETE FROM connection_permission_types
WHERE permission_code = 'proxy_execution';

-- ============================================================================
-- Step 4: Re-order encouragement from display_order 6 → 5
-- ============================================================================
UPDATE connection_permission_types
SET display_order = 5
WHERE permission_code = 'encouragement';

-- ============================================================================
-- Verification queries (run manually to confirm)
-- ============================================================================
-- SELECT permission_code, name_vi, display_order FROM connection_permission_types ORDER BY display_order;
-- Expected: 5 rows, no proxy_execution, encouragement at display_order=5
--
-- SELECT COUNT(*) FROM connection_permissions WHERE permission_code = 'proxy_execution';
-- Expected: 0

COMMIT;
