-- =============================================================================
-- Migration: US 1.2 - Nhận Cảnh Báo Bất Thường
-- Version: v1.5
-- Date: 2026-02-02
-- Description: Create caregiver alerts tables and indexes
-- =============================================================================

-- =============================================================================
-- 1. CREATE LOOKUP TABLE: caregiver_alert_types (4 categories for UI filter)
-- =============================================================================

CREATE TABLE IF NOT EXISTS caregiver_alert_types (
    type_id SMALLINT PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,  -- 'SOS', 'HA', 'MEDICATION', 'COMPLIANCE'
    name_vi VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    icon VARCHAR(10),
    display_order SMALLINT DEFAULT 0
);

-- Seed data: 4 categories matching UI filter tabs
INSERT INTO caregiver_alert_types (type_id, type_code, name_vi, name_en, icon, display_order) VALUES
    (1, 'SOS', 'Khẩn cấp', 'Emergency', '🚨', 1),
    (2, 'HA', 'Huyết áp', 'Blood Pressure', '❤️', 2),
    (3, 'MEDICATION', 'Thuốc', 'Medication', '💊', 3),
    (4, 'COMPLIANCE', 'Tuân thủ', 'Compliance', '📊', 4)
ON CONFLICT (type_id) DO NOTHING;

COMMENT ON TABLE caregiver_alert_types IS 'Lookup table for alert categories (4 types matching UI filter) - US 1.2';

-- =============================================================================
-- 2. CREATE MAIN TABLE: caregiver_alerts
-- =============================================================================

CREATE TABLE IF NOT EXISTS caregiver_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- WHO receives the alert
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- WHO is the patient
    patient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Connection reference (for permission check)
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Alert classification (references 4 categories)
    alert_type_id SMALLINT NOT NULL REFERENCES caregiver_alert_types(type_id),
    priority SMALLINT NOT NULL DEFAULT 1,      -- 0=Critical/SOS, 1=High, 2=Medium, 3=Low
    
    -- Content (sub-type info encoded in title/body)
    title VARCHAR(150) NOT NULL,               -- E.g., "Mẹ - HA 185/125 (THA khẩn cấp)"
    body TEXT,                                 -- Optional longer description
    icon VARCHAR(20),                          -- Set by BE: '🚨', '⚠️', '💛', '💊', '📊'
    color VARCHAR(20),                         -- Set by BE: 'red', 'yellow', 'orange', 'gray'
    
    -- Navigation
    deeplink VARCHAR(200),
    
    -- Extra data (medication name, BP values, patient notes, etc.)
    payload JSONB,
    
    -- Status
    status SMALLINT DEFAULT 0,                -- 0=unread, 1=read
    
    -- Push delivery tracking
    push_status SMALLINT DEFAULT 0,           -- 0=pending, 1=sent, 2=delivered, 3=failed
    push_sent_at TIMESTAMPTZ,
    push_error TEXT,
    
    -- Source reference (which BP record, which medication, etc.)
    source_type VARCHAR(30),                  -- 'blood_pressure', 'medication', 'sos', 'compliance'
    source_id TEXT,                           -- ID in source table (BIGINT or UUID as string)
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP + INTERVAL '90 days',  -- BR-ALT-009
    
    -- Constraints
    CONSTRAINT chk_alert_status CHECK (status IN (0, 1)),
    CONSTRAINT chk_alert_push_status CHECK (push_status IN (0, 1, 2, 3)),
    CONSTRAINT chk_alert_priority CHECK (priority BETWEEN 0 AND 3)
);

-- =============================================================================
-- 3. CREATE INDEXES
-- =============================================================================

-- Fast unread alerts query (for badge count)
CREATE INDEX IF NOT EXISTS idx_alerts_caregiver_unread 
    ON caregiver_alerts (caregiver_id, status, created_at DESC) 
    WHERE status = 0;

-- Patient alerts (for history filtered by patient)
CREATE INDEX IF NOT EXISTS idx_alerts_patient 
    ON caregiver_alerts (patient_id, created_at DESC);

-- ⭐ UI filter by category
CREATE INDEX IF NOT EXISTS idx_alerts_type 
    ON caregiver_alerts (caregiver_id, alert_type_id, created_at DESC);

-- Priority sort (SOS first)
CREATE INDEX IF NOT EXISTS idx_alerts_priority 
    ON caregiver_alerts (priority, created_at DESC);

-- Retention cleanup
CREATE INDEX IF NOT EXISTS idx_alerts_expires 
    ON caregiver_alerts (expires_at);

-- Push retry queue
CREATE INDEX IF NOT EXISTS idx_alerts_push_pending 
    ON caregiver_alerts (push_status) 
    WHERE push_status IN (0, 3);

-- Debounce: 5-minute buckets (prevent duplicate alerts within 5 minutes)
-- Note: SOS (priority=0) excluded from debounce (BR-ALT-005)
CREATE UNIQUE INDEX IF NOT EXISTS idx_alerts_debounce 
    ON caregiver_alerts (
        caregiver_id, 
        patient_id, 
        alert_type_id, 
        (date_trunc('hour', created_at) + 
         INTERVAL '5 min' * FLOOR(EXTRACT(MINUTE FROM created_at) / 5))
    )
    WHERE priority > 0;

-- =============================================================================
-- 4. COMMENTS
-- =============================================================================

COMMENT ON TABLE caregiver_alerts IS 'Health alerts for caregivers (US 1.2 - Nhận Cảnh Báo Bất Thường)';
COMMENT ON COLUMN caregiver_alerts.priority IS '0=Critical/SOS, 1=High, 2=Medium, 3=Low';
COMMENT ON COLUMN caregiver_alerts.payload IS 'Extra data: BP values, medication name, compliance rate, patient notes, etc.';
COMMENT ON COLUMN caregiver_alerts.status IS '0=unread, 1=read';
COMMENT ON COLUMN caregiver_alerts.push_status IS '0=pending, 1=sent, 2=delivered, 3=failed';
COMMENT ON COLUMN caregiver_alerts.expires_at IS '90-day retention per BR-ALT-009';

-- =============================================================================
-- 5. REGISTER BATCH JOB (Celery Beat)
-- =============================================================================

INSERT INTO schedule_jobs (key, name, task, schedule, pattern, queue, enabled, app, description, options, created_at, updated_at) VALUES
(
    'caregiver_alerts_batch_21h',
    'Job cảnh báo Caregiver batch 21:00',
    'schedule_service.tasks.alerts.run_batch_alerts',
    '{"type": "cron", "crontab": {"minute": "0", "hour": "21"}}',
    '0 21 * * *',
    'alerts',
    true,
    'schedule_service',
    'US 1.2: Daily batch evaluation for compliance alerts (tuân thủ thuốc/đo HA kém, bỏ lỡ 3 liều liên tiếp) at 21:00',
    '{"max_retries": 3}',
    NOW(),
    NOW()
)
ON CONFLICT (key) DO UPDATE SET
    name = EXCLUDED.name,
    task = EXCLUDED.task,
    schedule = EXCLUDED.schedule,
    pattern = EXCLUDED.pattern,
    queue = EXCLUDED.queue,
    enabled = EXCLUDED.enabled,
    app = EXCLUDED.app,
    description = EXCLUDED.description,
    options = EXCLUDED.options,
    updated_at = NOW();

-- =============================================================================
-- END OF MIGRATION
-- =============================================================================
