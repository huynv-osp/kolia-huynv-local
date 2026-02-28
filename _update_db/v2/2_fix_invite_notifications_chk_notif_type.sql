-- ============================================================================
-- FIX: invite_notifications chk_notif_type constraint
-- Date: 2026-02-28
-- Issue: MEMBER_REMOVED event violates chk_notif_type constraint
-- Fix: Add 'MEMBER_REMOVED' to allowed notification_type values
-- ============================================================================

ALTER TABLE invite_notifications 
DROP CONSTRAINT IF EXISTS chk_notif_type;

ALTER TABLE invite_notifications 
ADD CONSTRAINT chk_notif_type CHECK (notification_type IN (
    'INVITE_CREATED', 
    'INVITE_ACCEPTED', 
    'INVITE_REJECTED', 
    'CONNECTION_DISCONNECTED',
    'MEMBER_REMOVED'
));

-- Update comment
COMMENT ON COLUMN invite_notifications.notification_type IS 'Event type: INVITE_CREATED, INVITE_ACCEPTED, INVITE_REJECTED, CONNECTION_DISCONNECTED, MEMBER_REMOVED';

-- Verify
DO $$ BEGIN
    RAISE NOTICE '✅ chk_notif_type updated: added MEMBER_REMOVED';
END $$;
