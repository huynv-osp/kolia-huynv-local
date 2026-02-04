# Database Mapping: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-04  
> **Revision:** v2.23 - Added relationship_inverse_mapping table (v2.21) + perspective display standard (BR-036)

---

## 1. Schema Strategy

| Approach | Description |
|----------|-------------|
| **Extend** | user_emergency_contacts (add columns incl. is_viewing) |
| **Reuse** | relationships lookup for both SOS + Caregiver |
| **Keep Separate** | connection_invites (invite lifecycle) |
| **Keep Separate** | invite_notifications (delivery tracking) |

---

## 2. Table Summary

| Table | Status | Tables (Before) |
|-------|:------:|:---------------:|
| relationships | ✅ NEW | - |
| user_emergency_contacts | 🔄 EXTEND | (existing) |
| connection_permission_types | ✅ NEW | 1 |
| connection_invites | ✅ NEW | 1 |
| connection_permissions | ✅ NEW | 1 |
| invite_notifications | ✅ NEW | 1 |

**Total: 1 ALTER + 5 NEW = 6 tables affected**

---

## 3. SQL Migrations

### 3.1 relationships (Lookup Table)

```sql
CREATE TABLE relationships (
    relationship_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    category VARCHAR(30) DEFAULT 'family',
    display_order SMALLINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO relationships VALUES
('con_trai', 'Con trai', 'Son', 'family', 1, true),
('con_gai', 'Con gái', 'Daughter', 'family', 2, true),
('anh_trai', 'Anh trai', 'Older brother', 'family', 3, true),
('chi_gai', 'Chị gái', 'Older sister', 'family', 4, true),
('em_trai', 'Em trai', 'Younger brother', 'family', 5, true),
('em_gai', 'Em gái', 'Younger sister', 'family', 6, true),
('chau_trai', 'Cháu trai', 'Grandson', 'family', 7, true),
('chau_gai', 'Cháu gái', 'Granddaughter', 'family', 8, true),
('bo', 'Bố', 'Father', 'family', 9, true),
('me', 'Mẹ', 'Mother', 'family', 10, true),
('ong_noi', 'Ông nội', 'Paternal grandfather', 'family', 11, true),
('ba_noi', 'Bà nội', 'Paternal grandmother', 'family', 12, true),
('ong_ngoai', 'Ông ngoại', 'Maternal grandfather', 'family', 13, true),
('ba_ngoai', 'Bà ngoại', 'Maternal grandmother', 'family', 14, true),
('vo', 'Vợ', 'Wife', 'spouse', 15, true),
('chong', 'Chồng', 'Husband', 'spouse', 16, true),
('khac', 'Khác', 'Other', 'other', 99, true);
```

### 3.1.1 relationship_inverse_mapping (NEW v2.21)

> **Purpose:** Gender-based inverse relationship derivation lookup

```sql
CREATE TABLE IF NOT EXISTS relationship_inverse_mapping (
    relationship_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    target_gender SMALLINT NOT NULL,  -- 0: Nam, 1: Nữ (gender of the OTHER party)
    inverse_code VARCHAR(30) NOT NULL REFERENCES relationships(relationship_code),
    PRIMARY KEY (relationship_code, target_gender)
);

-- Seed data examples:
INSERT INTO relationship_inverse_mapping VALUES
('con_trai', 0, 'bo'),       -- Receiver (con trai) → Sender là Nam = Bố
('con_trai', 1, 'me'),       -- Receiver (con trai) → Sender là Nữ = Mẹ
('chau_trai', 0, 'ong_noi'), -- Receiver (cháu trai) → Sender là Nam = Ông nội
('chau_trai', 1, 'ba_noi'),  -- Receiver (cháu trai) → Sender là Nữ = Bà nội
-- ... (full 34 mappings in migration file)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE relationship_inverse_mapping IS 'v2.21: Gender-based inverse relationship derivation lookup';
COMMENT ON COLUMN relationship_inverse_mapping.target_gender IS '0: Nam, 1: Nữ - giới tính của bên còn lại';
```

> **Use Case:** Derive `inverse_relationship_code` at invite creation time:
> ```sql
> SELECT inverse_code FROM relationship_inverse_mapping 
> WHERE relationship_code = 'chau_trai' AND target_gender = 0; -- Returns 'ong_noi'
> ```

### 3.2 Extend user_emergency_contacts

```sql
ALTER TABLE user_emergency_contacts
ADD COLUMN IF NOT EXISTS linked_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS contact_type VARCHAR(20) DEFAULT 'emergency',
ADD COLUMN IF NOT EXISTS relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
ADD COLUMN IF NOT EXISTS inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- v2.13
ADD COLUMN IF NOT EXISTS invite_id UUID,
ADD COLUMN IF NOT EXISTS is_viewing BOOLEAN DEFAULT FALSE;

-- v2.13: Semantic comments
-- relationship_code = Patient (user_id) mô tả Caregiver (linked_user_id) là [X]
-- inverse_relationship_code = Caregiver (linked_user_id) mô tả Patient (user_id) là [X]

-- Constraint
ALTER TABLE user_emergency_contacts
ADD CONSTRAINT chk_contact_type CHECK (contact_type IN ('emergency','caregiver','both'));

-- Unique constraint: Only ONE is_viewing=true per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_viewing_patient
ON user_emergency_contacts (user_id) WHERE is_viewing = TRUE AND contact_type IN ('caregiver','both');

-- Index for caregiver lookups
CREATE INDEX IF NOT EXISTS idx_contacts_linked ON user_emergency_contacts (linked_user_id)
WHERE linked_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_contacts_type ON user_emergency_contacts (user_id, contact_type);
CREATE INDEX IF NOT EXISTS idx_contacts_viewing ON user_emergency_contacts (user_id, is_viewing) WHERE is_viewing = TRUE;
```

> **NEW (v2.7):** `is_viewing` column đánh dấu Patient nào đang được Caregiver chọn xem.  
> Constraint đảm bảo mỗi user chỉ có tối đa 1 row với `is_viewing=true`.

### 3.3 connection_invites

```sql
CREATE TABLE connection_invites (
    invite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    receiver_name VARCHAR(100),
    invite_type VARCHAR(30) NOT NULL,
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    inverse_relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- v2.13
    initial_permissions JSONB,  -- Generated by service layer from connection_permission_types
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_no_self_invite CHECK (sender_id != receiver_id),
    CONSTRAINT chk_invite_type CHECK (invite_type IN ('patient_to_caregiver','caregiver_to_patient')),
    CONSTRAINT chk_invite_status CHECK (status IN (0,1,2,3))
);

-- v2.13: Semantic comments
-- relationship_code = Sender mô tả Receiver là [X]
-- inverse_relationship_code = Receiver mô tả Sender là [X]

CREATE INDEX idx_invites_sender ON connection_invites (sender_id);
CREATE INDEX idx_invites_receiver ON connection_invites (receiver_id);
CREATE INDEX idx_invites_pending ON connection_invites (status) WHERE status = 0;
CREATE UNIQUE INDEX idx_unique_pending ON connection_invites (sender_id, receiver_phone) WHERE status = 0;
```

### 3.4 connection_permission_types (NEW in v2.1)

```sql
CREATE TABLE connection_permission_types (
    permission_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    description TEXT,
    icon VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    display_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO connection_permission_types VALUES
('health_overview', 'Xem tổng quan sức khỏe', 'View Health Overview', NULL, NULL, true, 1),
('emergency_alert', 'Nhận cảnh báo khẩn cấp', 'Receive Emergency Alerts', NULL, NULL, true, 2),
('task_config', 'Cấu hình nhiệm vụ', 'Configure Tasks', NULL, NULL, true, 3),
('compliance_tracking', 'Theo dõi tuân thủ', 'Track Compliance', NULL, NULL, true, 4),
('proxy_execution', 'Thực hiện thay mặt', 'Proxy Execution', NULL, NULL, true, 5),
('encouragement', 'Gửi động viên', 'Send Encouragement', NULL, NULL, true, 6);
```

### 3.5 connection_permissions

```sql
CREATE TABLE connection_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    permission_code VARCHAR(30) NOT NULL REFERENCES connection_permission_types(permission_code),
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    
    CONSTRAINT uq_perm_unique UNIQUE (contact_id, permission_code)
);

CREATE INDEX idx_perms_contact ON connection_permissions (contact_id);
CREATE INDEX idx_perms_code ON connection_permissions (permission_code);
```

### 3.6 invite_notifications (v2.12)

```sql
CREATE TABLE invite_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id UUID NOT NULL REFERENCES connection_invites(invite_id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL DEFAULT 'INVITE_CREATED',  -- v2.12
    channel VARCHAR(10) NOT NULL,
    status SMALLINT DEFAULT 0,              -- 0=pending, 1=sent, 2=delivered, 3=failed, 4=cancelled
    retry_count SMALLINT DEFAULT 0,
    deep_link_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,               -- v2.12: when notification was cancelled
    error_message TEXT,
    external_message_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_channel CHECK (channel IN ('ZNS','SMS','PUSH')),
    CONSTRAINT chk_notif_status CHECK (status IN (0,1,2,3,4)),  -- v2.12: added 4=cancelled
    CONSTRAINT chk_notif_type CHECK (notification_type IN (
        'INVITE_CREATED', 
        'INVITE_ACCEPTED', 
        'INVITE_REJECTED', 
        'CONNECTION_DISCONNECTED'
    )),
    CONSTRAINT chk_retry CHECK (retry_count <= 3)
);

CREATE INDEX idx_notif_invite ON invite_notifications (invite_id);
CREATE INDEX idx_notif_pending ON invite_notifications (status) WHERE status IN (0,3);
CREATE INDEX idx_notif_type ON invite_notifications (notification_type);

-- v2.12: Unique constraint for idempotency (prevent duplicate notifications)
CREATE UNIQUE INDEX idx_unique_invite_notification 
    ON invite_notifications (invite_id, notification_type, channel) 
    WHERE status IN (0, 1, 2);
```

> **v2.12 Changes:**
> - `notification_type` column to distinguish event types
> - `cancelled_at` column for cancel audit
> - `status = 4` (cancelled) support
> - Idempotency constraint to prevent duplicate notifications

---

## 4. Triggers

### Auto-create permissions on accept

```sql
-- Add FK after connection_invites exists
ALTER TABLE user_emergency_contacts
ADD CONSTRAINT fk_invite FOREIGN KEY (invite_id)
REFERENCES connection_invites(invite_id) ON DELETE SET NULL;

-- Trigger: create permissions when caregiver contact created (uses lookup)
CREATE OR REPLACE FUNCTION create_default_permissions()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.contact_type IN ('caregiver','both') AND NEW.linked_user_id IS NOT NULL THEN
        INSERT INTO connection_permissions (contact_id, permission_code, is_enabled)
        SELECT NEW.contact_id, cpt.permission_code, TRUE
        FROM connection_permission_types cpt
        WHERE cpt.is_active = TRUE
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_default_perms
AFTER INSERT ON user_emergency_contacts
FOR EACH ROW EXECUTE FUNCTION create_default_permissions();
```

---

## 5. Business Rules Coverage

| BR | Table | Implementation |
|----|-------|----------------|
| BR-001 | connection_invites | invite_type column |
| BR-004 | invite_notifications | retry_count, channel |
| BR-006 | connection_invites | chk_no_self_invite |
| BR-007 | connection_invites | idx_unique_pending |
| BR-009 | connection_permissions | trigger default |
| BR-028 | relationships + FK | relationship_code |
| BR-RPT-001 | caregiver_report_views | is_read tracking |

---

## 6. Report Read Tracking (v2.11)

> **NEW TABLE:** Track which reports have been read by which caregiver

### 6.1 Table: caregiver_report_views

```sql
CREATE TABLE caregiver_report_views (
    id BIGSERIAL PRIMARY KEY,
    
    -- References
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    report_id BIGINT NOT NULL REFERENCES report_periodic(report_id) ON DELETE CASCADE,
    
    -- Metadata
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint: 1 caregiver can only mark 1 report as read once
    CONSTRAINT idx_unique_caregiver_report UNIQUE (caregiver_id, report_id)
);

-- Indexes for efficient lookup
CREATE INDEX idx_crv_caregiver_id ON caregiver_report_views(caregiver_id);
CREATE INDEX idx_crv_report_id ON caregiver_report_views(report_id);
```

### 6.2 Query Patterns

```sql
-- Check if report is read
SELECT EXISTS (
    SELECT 1 FROM caregiver_report_views 
    WHERE caregiver_id = {caregiver_id} AND report_id = {report_id}
) AS is_read;

-- Mark as read (idempotent)
INSERT INTO caregiver_report_views (caregiver_id, report_id)
VALUES ({caregiver_id}, {report_id})
ON CONFLICT (caregiver_id, report_id) DO NOTHING;

-- Get unread count for a patient's reports
SELECT COUNT(*) FROM report_periodic pr
WHERE pr.user_id = {patient_id}
AND NOT EXISTS (
    SELECT 1 FROM caregiver_report_views crv 
    WHERE crv.report_id = pr.report_id AND crv.caregiver_id = {caregiver_id}
);
```

### 6.3 Table Summary Update

| Table | Status | Columns | Indexes |
|-------|:------:|:-------:|:-------:|
| relationships | NEW | 6 | 0 |
| **relationship_inverse_mapping** | **NEW v2.21** | **3** | **1** |
| connection_invites | NEW | **12** | 5 |
| user_emergency_contacts | EXTEND | **+6** | +3 |
| connection_permissions | NEW | 5 | 1 |
| invite_notifications | **v2.12** | **13** | **5** |
| **caregiver_report_views** | **NEW** | **4** | **3** |

> **v2.12:** invite_notifications enhanced with notification_type, cancelled_at, idempotency  
> **v2.13:** inverse_relationship_code added to connection_invites and user_emergency_contacts  
> **v2.21:** relationship_inverse_mapping table for gender-based inverse derivation  
> **v2.23:** inverse_relationship_display field for UI perspective display (see api_mapping.md)
