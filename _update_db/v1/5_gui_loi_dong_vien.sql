-- =============================================================================
-- Migration: V2026.02.04.1__create_encouragement_messages.sql
-- Feature: US 1.3 - Gửi Lời Động Viên (Encouragement Messages)
-- Author: Feature Analysis Workflow
-- Date: 2026-02-04
-- =============================================================================

-- =============================================================================
-- 1. CREATE TABLE: encouragement_messages
-- =============================================================================
-- Purpose: Store encouragement messages from Caregiver to Patient
-- Retention: 90 days (batch job cleanup)

CREATE TABLE IF NOT EXISTS encouragement_messages (
    -- Primary Key
    encouragement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Sender/Receiver Relationship
    sender_id UUID NOT NULL,               -- Caregiver user_id
    patient_id UUID NOT NULL,              -- Patient user_id
    contact_id UUID NOT NULL,              -- Connection reference
    
    -- Message Content (BR-002: max 150 Unicode chars)
    content VARCHAR(150) NOT NULL,
    
    -- ==========================================================================
    -- RELATIONSHIP FIELDS (Perspective Display Standard v2.23)
    -- ==========================================================================
    -- ⚠️ CRITICAL: These fields store the PATIENT'S PERSPECTIVE
    -- 
    -- Example Scenario:
    --   Patient = Bà Lan (Mẹ)
    --   Caregiver = Cô Huy (Con gái của Bà Lan)
    --
    -- Field Values:
    --   sender_name = "Huy" (Caregiver's display name)
    --   relationship_code = "con_gai" (Caregiver's role - raw code)
    --   relationship_display = "Con gái" (How Patient calls Caregiver)
    --
    -- UI Display in Patient Modal:
    --   "💬 Lời động viên từ Huy (Con gái)"
    -- ==========================================================================
    sender_name VARCHAR(100),              -- Caregiver's display name (e.g., "Huy")
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- FK: ensures valid code
    relationship_display VARCHAR(100),     -- Patient's perspective: how Patient calls Caregiver (e.g., "Con gái")
    
    -- Status Tracking
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    
    -- Timestamps
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    CONSTRAINT fk_enc_sender FOREIGN KEY (sender_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_enc_patient FOREIGN KEY (patient_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_enc_contact FOREIGN KEY (contact_id) 
        REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    
    -- Business Rule Constraints
    CONSTRAINT chk_enc_content_length CHECK (char_length(content) <= 150),
    CONSTRAINT chk_enc_different_users CHECK (sender_id != patient_id)
);

-- =============================================================================
-- 2. CREATE INDEXES
-- =============================================================================

-- Index for Patient modal query (unread messages in 24h, newest first)
CREATE INDEX IF NOT EXISTS idx_enc_patient_unread 
    ON encouragement_messages (patient_id, is_read, sent_at DESC) 
    WHERE is_read = FALSE;

-- Index for 24h window query (Patient list)
CREATE INDEX IF NOT EXISTS idx_enc_patient_recent 
    ON encouragement_messages (patient_id, sent_at DESC);

-- Index for daily quota check (BR-001: max 10/day/patient)
-- Note: Use timestamp range query instead of DATE() to leverage this index
-- Query pattern: WHERE sender_id = ? AND patient_id = ? AND sent_at >= date_trunc('day', now()) AND sent_at < date_trunc('day', now()) + interval '1 day'
CREATE INDEX IF NOT EXISTS idx_enc_quota 
    ON encouragement_messages (sender_id, patient_id, sent_at);

-- Index for sender history (Caregiver view - optional)
CREATE INDEX IF NOT EXISTS idx_enc_sender 
    ON encouragement_messages (sender_id, sent_at DESC);

-- =============================================================================
-- 3. CREATE TRIGGER for updated_at
-- =============================================================================

DROP TRIGGER IF EXISTS trigger_enc_messages_updated_at ON encouragement_messages;
CREATE TRIGGER trigger_enc_messages_updated_at
    BEFORE UPDATE ON encouragement_messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 4. TABLE COMMENTS
-- =============================================================================

COMMENT ON TABLE encouragement_messages IS 
    'Encouragement messages from Caregiver to Patient (US 1.3 - Gửi Lời Động Viên)';

COMMENT ON COLUMN encouragement_messages.encouragement_id IS 
    'Primary key - unique message identifier';

COMMENT ON COLUMN encouragement_messages.sender_id IS 
    'Caregiver who sent the message (FK to users)';

COMMENT ON COLUMN encouragement_messages.patient_id IS 
    'Patient who receives the message (FK to users)';

COMMENT ON COLUMN encouragement_messages.contact_id IS 
    'Connection relationship reference (FK to user_emergency_contacts)';

COMMENT ON COLUMN encouragement_messages.content IS 
    'Message content, max 150 Unicode chars including emoji (BR-002)';

COMMENT ON COLUMN encouragement_messages.sender_name IS 
    'Denormalized: Caregiver display name at send time';

COMMENT ON COLUMN encouragement_messages.relationship_display IS 
    'Denormalized: How Patient refers to Caregiver (Perspective Standard v2.23)';

COMMENT ON COLUMN encouragement_messages.is_read IS 
    'Read status for modal display';

COMMENT ON COLUMN encouragement_messages.sent_at IS 
    'Timestamp when message was sent (for 24h window filter)';

-- =============================================================================
-- 5. GRANT PERMISSIONS
-- =============================================================================

-- Note: Uncomment if app_user role exists in your environment
-- GRANT SELECT, INSERT, UPDATE ON encouragement_messages TO app_user;

-- =============================================================================
-- 6. ESTIMATED TABLE SIZE
-- =============================================================================
-- Assumptions:
--   - ~30,000 messages/day at scale
--   - 90-day retention
--   - ~2.7M rows maximum
--   - ~400 bytes/row average
--   - Total: ~1GB storage
