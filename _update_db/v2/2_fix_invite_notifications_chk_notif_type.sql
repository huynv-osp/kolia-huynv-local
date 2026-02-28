-- ============================================================================
-- FIX: invite_notifications constraints for expanded event types
-- Date: 2026-02-28
-- Issues:
--   1. MEMBER_REMOVED violates chk_notif_type (only 4 values allowed)
--   2. DISCONNECTED/MEMBER_REMOVED pass connection_id/group_id as invite_id
--      → FK to connection_invites fails
-- Fixes:
--   1. Add 'MEMBER_REMOVED' to chk_notif_type
--   2. Drop FK constraint since invite_id now stores group_id/connection_id too
-- ============================================================================

-- Fix 1: Update notification_type constraint
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

-- Fix 2: Drop FK constraint on invite_id
-- Reason: invite_id column now stores different reference IDs:
--   - INVITE_*: actual invite_id from connection_invites
--   - CONNECTION_DISCONNECTED: connection_id (contact_id)
--   - MEMBER_REMOVED: group_id from family_groups
ALTER TABLE invite_notifications 
DROP CONSTRAINT IF EXISTS invite_notifications_invite_id_fkey;

-- Update comments
COMMENT ON TABLE invite_notifications IS 'Notification delivery tracking for connection events (v2.12+). invite_id stores reference ID (invite/connection/group depending on event type)';
COMMENT ON COLUMN invite_notifications.invite_id IS 'Reference ID: invite_id for INVITE_*, connection_id for DISCONNECTED, group_id for MEMBER_REMOVED';
COMMENT ON COLUMN invite_notifications.notification_type IS 'Event type: INVITE_CREATED, INVITE_ACCEPTED, INVITE_REJECTED, CONNECTION_DISCONNECTED, MEMBER_REMOVED';

-- Verify
DO $$ BEGIN
    RAISE NOTICE '✅ invite_notifications fixed:';
    RAISE NOTICE '   - chk_notif_type: added MEMBER_REMOVED';
    RAISE NOTICE '   - FK invite_id → connection_invites: dropped (now polymorphic reference)';
END $$;
