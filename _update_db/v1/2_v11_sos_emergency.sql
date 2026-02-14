-- ============================================================================
-- SOS EMERGENCY FEATURE - DATABASE MIGRATION
-- Version: 1.0
-- Date: 2026-01-26
-- Service: schedule-service (also creates table in user-service DB)
-- ============================================================================

-- IMPORTANT: Run this migration against the business PostgreSQL database
-- Connection: settings.business_database_url

-- ============================================================================
-- FUNCTION: update_updated_at_column (if not exists)
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column'
    ) THEN
        CREATE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $func$ language 'plpgsql';
    END IF;
END $$;

-- ============================================================================
-- TABLE 1: user_emergency_contacts
-- Purpose: Store emergency contacts for each user (max 5)
-- Owner: user-service
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_emergency_contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(50),
    priority SMALLINT NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    zalo_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_emergency_priority_range CHECK (priority BETWEEN 1 AND 5),
    CONSTRAINT uq_emergency_contact_phone UNIQUE (user_id, phone)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON user_emergency_contacts (user_id, priority);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_active ON user_emergency_contacts (user_id) 
    WHERE is_active = TRUE;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_emergency_contacts_updated_at ON user_emergency_contacts;
CREATE TRIGGER trigger_emergency_contacts_updated_at
    BEFORE UPDATE ON user_emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE user_emergency_contacts IS 'Emergency contacts for SOS feature (max 5 per user)';

-- ============================================================================
-- TABLE 2: sos_events
-- Purpose: Track SOS activation events
-- Owner: schedule-service (shared DB)
-- Retention: 90 days
-- ============================================================================

CREATE TABLE IF NOT EXISTS sos_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Trigger info
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trigger_source VARCHAR(50) NOT NULL DEFAULT 'manual',
    
    -- Location at trigger time
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_accuracy_m DOUBLE PRECISION,
    location_timestamp TIMESTAMPTZ,
    location_source VARCHAR(50),
    
    -- Countdown & Status
    countdown_seconds SMALLINT NOT NULL DEFAULT 30,
    countdown_started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    countdown_completed_at TIMESTAMPTZ,
    
    -- Final status: 0=PENDING, 1=COMPLETED, 2=CANCELLED, 3=FAILED
    status SMALLINT NOT NULL DEFAULT 0,

    cskh_only BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Cancellation details
    cancelled_at TIMESTAMPTZ,
    cancellation_reason VARCHAR(100),
    
    -- Offline handling
    is_offline_triggered BOOLEAN DEFAULT FALSE,
    offline_queue_timestamp TIMESTAMPTZ,
    sync_completed_at TIMESTAMPTZ,
    
    -- Cooldown tracking
    cooldown_bypassed BOOLEAN DEFAULT FALSE,
    
    -- Battery info at trigger
    battery_level_percent SMALLINT,
    
    -- Metadata
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_sos_countdown_range CHECK (countdown_seconds BETWEEN 0 AND 30),
    CONSTRAINT chk_sos_status_values CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_sos_battery_range CHECK (battery_level_percent IS NULL OR battery_level_percent BETWEEN 0 AND 100)
);


-- Index for CSKH to quickly find events that need their attention
CREATE INDEX IF NOT EXISTS idx_sos_events_cskh_only 
ON sos_events (cskh_only, status) 
WHERE cskh_only = true;

COMMENT ON COLUMN sos_events.cskh_only IS 'True when user has 0 emergency contacts - alert goes to CSKH only';


-- NOTE: Partitioning requires PostgreSQL 10+ and is optional for smaller datasets
-- For production with high volume, consider partitioning by triggered_at

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sos_events_user ON sos_events (user_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_sos_events_status ON sos_events (status) WHERE status = 0;
CREATE INDEX IF NOT EXISTS idx_sos_events_cooldown ON sos_events (user_id, countdown_completed_at DESC) 
    WHERE status = 1;
CREATE INDEX IF NOT EXISTS idx_sos_events_location ON sos_events (latitude, longitude) 
    WHERE latitude IS NOT NULL;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_sos_events_updated_at ON sos_events;
CREATE TRIGGER trigger_sos_events_updated_at
    BEFORE UPDATE ON sos_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sos_events IS 'SOS activation events tracking (90-day retention)';

-- ============================================================================
-- TABLE 3: sos_notifications
-- Purpose: Track ZNS/SMS notifications sent per SOS event
-- Owner: schedule-service
-- Retention: 90 days
-- ============================================================================

CREATE TABLE IF NOT EXISTS sos_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES sos_events(event_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Recipient info (denormalized for history)
    recipient_name VARCHAR(100) NOT NULL,
    recipient_phone VARCHAR(20) NOT NULL,
    recipient_type VARCHAR(50) NOT NULL,
    
    -- Notification type
    channel VARCHAR(50) NOT NULL,
    template_id VARCHAR(100),
    
    -- Content (for audit)
    message_content TEXT,
    
    -- Status: 0=PENDING, 1=SENT, 2=DELIVERED, 3=FAILED, 4=RETRY_PENDING
    status SMALLINT NOT NULL DEFAULT 0,
    
    -- Timing
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    
    -- Retry info
    retry_count SMALLINT DEFAULT 0,
    last_retry_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    
    -- Error handling
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- External IDs
    external_message_id VARCHAR(200),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_notification_status CHECK (status IN (0, 1, 2, 3, 4)),
    CONSTRAINT chk_notification_retry_count CHECK (retry_count BETWEEN 0 AND 3)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sos_notifications_event ON sos_notifications (event_id);
CREATE INDEX IF NOT EXISTS idx_sos_notifications_status ON sos_notifications (status) 
    WHERE status IN (0, 4);
CREATE INDEX IF NOT EXISTS idx_sos_notifications_retry ON sos_notifications (next_retry_at) 
    WHERE status = 4;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_sos_notifications_updated_at ON sos_notifications;
CREATE TRIGGER trigger_sos_notifications_updated_at
    BEFORE UPDATE ON sos_notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sos_notifications IS 'ZNS/SMS notification tracking for SOS events';

-- ============================================================================
-- TABLE 4: sos_escalation_calls
-- Purpose: Track escalation calls per SOS event
-- Owner: schedule-service
-- Retention: 90 days
-- ============================================================================

CREATE TABLE IF NOT EXISTS sos_escalation_calls (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES sos_events(event_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Contact info (denormalized)
    contact_name VARCHAR(100) NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    escalation_order SMALLINT NOT NULL,
    
    -- Call type
    call_type VARCHAR(50) NOT NULL,
    
    -- Status: 0=PENDING, 1=CALLING, 2=CONNECTED, 3=NO_ANSWER, 4=BUSY, 5=REJECTED, 6=FAILED, 7=SKIPPED
    status SMALLINT NOT NULL DEFAULT 0,
    
    -- Timing
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connected_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Timeout tracking
    timeout_seconds SMALLINT DEFAULT 20,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_call_status CHECK (status IN (0, 1, 2, 3, 4, 5, 6, 7)),
    CONSTRAINT chk_escalation_order CHECK (escalation_order BETWEEN 1 AND 5)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sos_escalation_calls_event ON sos_escalation_calls (event_id, escalation_order);
CREATE INDEX IF NOT EXISTS idx_sos_escalation_calls_pending ON sos_escalation_calls (status) 
    WHERE status IN (0, 1);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_sos_escalation_calls_updated_at ON sos_escalation_calls;
CREATE TRIGGER trigger_sos_escalation_calls_updated_at
    BEFORE UPDATE ON sos_escalation_calls
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sos_escalation_calls IS 'Escalation call tracking for SOS events';

-- ============================================================================
-- TABLE 5: first_aid_content
-- Purpose: CMS content for First Aid guide
-- Owner: schedule-service / CMS
-- Retention: Permanent
-- ============================================================================

CREATE TABLE IF NOT EXISTS first_aid_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    display_order SMALLINT DEFAULT 0,
    icon_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_first_aid_category ON first_aid_content (category, display_order);
CREATE INDEX IF NOT EXISTS idx_first_aid_active ON first_aid_content (is_active) WHERE is_active = TRUE;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_first_aid_content_updated_at ON first_aid_content;
CREATE TRIGGER trigger_first_aid_content_updated_at
    BEFORE UPDATE ON first_aid_content
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed data
INSERT INTO first_aid_content (category, title, icon_name, display_order, content) VALUES
('cpr', 'Hồi sinh tim phổi (CPR)', 'heart_plus', 1, '## Hướng dẫn CPR

### Bước 1: Kiểm tra phản ứng
- Gọi to và lay vai người bệnh

### Bước 2: Gọi cấp cứu
- Gọi 115 ngay lập tức

### Bước 3: Ép ngực
- Đặt 2 tay chồng lên nhau giữa ngực
- Ép sâu 5-6cm, tốc độ 100-120 lần/phút

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO'),
('stroke', 'Đột quỵ (F.A.S.T)', 'brain', 2, '## Nhận biết đột quỵ - F.A.S.T

### F - Face (Mặt)
- Một bên mặt bị xệ xuống?

### A - Arms (Tay)
- Một cánh tay yếu hoặc không nâng lên được?

### S - Speech (Nói)
- Nói không rõ, khó hiểu?

### T - Time (Thời gian)
- GỌI 115 NGAY LẬP TỨC!

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO'),
('low_sugar', 'Hạ đường huyết', 'sugar', 3, '## Xử lý hạ đường huyết

### Dấu hiệu
- Đổ mồ hôi, run tay
- Chóng mặt, tim đập nhanh
- Đói, yếu sức

### Xử lý ngay
1. Cho uống nước đường hoặc nước trái cây
2. Cho ăn bánh, kẹo
3. Nếu không tỉnh - GỌI 115

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO'),
('fall', 'Té ngã', 'fall', 4, '## Xử lý khi té ngã

### ĐỪNG
- Đừng di chuyển người bệnh ngay
- Đừng cho uống nước nếu không tỉnh

### NÊN
1. Kiểm tra ý thức
2. Kiểm tra vùng đau: đầu, cổ, lưng, tay chân
3. Nếu nghi gãy xương - KHÔNG di chuyển
4. GỌI 115

⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE first_aid_content IS 'First Aid CMS content for SOS feature';

-- ============================================================================
-- VERIFY MIGRATION
-- ============================================================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN (
        'user_emergency_contacts',
        'sos_events',
        'sos_notifications',
        'sos_escalation_calls',
        'first_aid_content'
    );
    
    IF table_count = 5 THEN
        RAISE NOTICE '✅ SOS Migration completed successfully. All 5 tables created.';
    ELSE
        RAISE WARNING '⚠️ SOS Migration incomplete. Only % of 5 tables found.', table_count;
    END IF;
END $$;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================