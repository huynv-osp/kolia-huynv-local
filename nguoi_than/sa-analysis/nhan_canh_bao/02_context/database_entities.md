# Database Entities: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-02

---

## Existing Entities (Reuse/Reference)

### user_emergency_contacts (KOLIA-1517)

**Purpose:** Store caregiver connections  
**Relevant Columns:**

| Column | Type | Description |
|--------|------|-------------|
| contact_id | UUID | PK |
| user_id | UUID | Patient ID (FK → users) |
| linked_user_id | UUID | Caregiver ID (FK → users) |
| contact_type | VARCHAR(20) | 'caregiver' | 'both' |
| is_viewing | BOOLEAN | Currently selected patient |

**Use for Alert:** Query active caregivers for patient

---

### connection_permissions (KOLIA-1517)

**Purpose:** RBAC for caregiver permissions  
**Permission #2 = "Nhận cảnh báo khẩn cấp"**

| Column | Type | Description |
|--------|------|-------------|
| permission_id | UUID | PK |
| contact_id | UUID | FK → user_emergency_contacts |
| permission_type_id | INT | FK → connection_permission_types |
| is_enabled | BOOLEAN | Permission state |

**Use for Alert:** Check if caregiver has Permission #2 enabled

---

### user_blood_pressure

**Purpose:** Store BP measurements  
**Relevant for Alert Triggers:**

| Column | Type | Description |
|--------|------|-------------|
| user_id | UUID | Patient ID |
| systolic | INT | Tâm thu (mmHg) |
| diastolic | INT | Tâm trương (mmHg) |
| measurement_time | TIMESTAMPTZ | When measured |

**Use for Alert:** 
- Critical thresholds: systolic <90/>180, diastolic <60/>120
- 7-day average calculation for abnormal alerts

---

### invite_notifications (v2.12)

**Purpose:** Track notification delivery  
**Model for caregiver_alerts:**

| Column | Type | Description |
|--------|------|-------------|
| notification_id | UUID | PK |
| invite_id | UUID | Source event |
| notification_type | VARCHAR(30) | Event type |
| channel | VARCHAR(10) | 'ZNS' | 'PUSH' |
| status | SMALLINT | 0-4 delivery status |
| retry_count | SMALLINT | Max 3 |

---

## New Entities Required

### caregiver_alerts (NEW)

**Purpose:** Store alerts for caregivers  
**Owner:** user-service

```sql
CREATE TABLE IF NOT EXISTS caregiver_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- WHO receives the alert
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- WHO is the patient
    patient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Connection reference (for permission check)
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    
    -- Alert classification (references 4 categories: SOS, HA, MEDICATION, COMPLIANCE)
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
    expires_at TIMESTAMPTZ                    -- 90 days retention (BR-ALT-009)
);

-- Indexes
CREATE INDEX idx_alerts_caregiver_unread ON caregiver_alerts (caregiver_id, status, created_at DESC) 
    WHERE status = 0;
CREATE INDEX idx_alerts_patient ON caregiver_alerts (patient_id, created_at DESC);
CREATE INDEX idx_alerts_type ON caregiver_alerts (caregiver_id, alert_type_id, created_at DESC);  -- ⭐ UI filter by category
CREATE INDEX idx_alerts_priority ON caregiver_alerts (priority, created_at DESC);
CREATE INDEX idx_alerts_expires ON caregiver_alerts (expires_at);
CREATE INDEX idx_alerts_push_pending ON caregiver_alerts (push_status) WHERE push_status IN (0, 3);

-- Debounce index (prevent duplicate alerts within 5 minutes)
CREATE UNIQUE INDEX idx_alerts_debounce 
    ON caregiver_alerts (caregiver_id, patient_id, alert_type_id, date_trunc('minute', created_at / 300 * 300))
    WHERE priority > 0;  -- Exclude SOS (priority=0 has no debounce)

-- Comments
COMMENT ON TABLE caregiver_alerts IS 'Alerts for caregivers about patient health events (US 1.2)';
COMMENT ON COLUMN caregiver_alerts.priority IS '0=Critical/SOS, 1=High, 2=Medium, 3=Low';
COMMENT ON COLUMN caregiver_alerts.payload IS 'Extra data: BP values, medication name, compliance rate, patient notes, etc.';
```

---

### caregiver_alert_types (NEW - Lookup) ⭐ SIMPLIFIED

**Purpose:** Alert category definitions for UI filter (4 categories only)  
**Owner:** user-service

> **Design Decision:** Chỉ lưu 4 loại category khớp với UI filter tabs. Chi tiết loại cảnh báo (BP_CRITICAL vs BP_ABNORMAL) được encode trong `title` và `priority` của `caregiver_alerts`.

```sql
CREATE TABLE IF NOT EXISTS caregiver_alert_types (
    type_id SMALLINT PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,  -- 'SOS', 'HA', 'MEDICATION', 'COMPLIANCE'
    name_vi VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    icon VARCHAR(10),
    display_order SMALLINT DEFAULT 0
);

-- Seed data: 4 CATEGORIES (khớp UI filter tabs)
INSERT INTO caregiver_alert_types (type_id, type_code, name_vi, name_en, icon, display_order) VALUES
(1, 'SOS', 'Khẩn cấp', 'Emergency', '🚨', 1),
(2, 'HA', 'Huyết áp', 'Blood Pressure', '❤️', 2),
(3, 'MEDICATION', 'Thuốc', 'Medication', '💊', 3),
(4, 'COMPLIANCE', 'Tuân thủ', 'Compliance', '📊', 4);

COMMENT ON TABLE caregiver_alert_types IS 'Lookup table for alert categories (4 types matching UI filter)';
```

### API cho FE lấy danh sách categories

```
GET /api/v1/alerts/types

Response:
{
  "types": [
    {"type_id": 1, "type_code": "SOS", "name_vi": "Khẩn cấp", "icon": "🚨"},
    {"type_id": 2, "type_code": "HA", "name_vi": "Huyết áp", "icon": "❤️"},
    {"type_id": 3, "type_code": "MEDICATION", "name_vi": "Thuốc", "icon": "💊"},
    {"type_id": 4, "type_code": "COMPLIANCE", "name_vi": "Tuân thủ", "icon": "📊"}
  ]
}
```

---

## Entity Relationship Diagram

```
users ─────────┬─────────────────────────────────────────┐
    │          │                                         │
    │          │                                         │
    ▼          ▼                                         ▼
caregiver_id  patient_id                            user_emergency_contacts
    │          │                                         │
    │          │                                         │
    └────┬─────┘                                         │
         │                                               │
         ▼                                               ▼
   caregiver_alerts ◄───────────── contact_id ─────────────
         │
         │
         ▼
   caregiver_alert_types (FK: alert_type_id)
```

---

## Data Volume Estimates

| Table | Daily Growth | 90-day Retention |
|-------|:------------:|:----------------:|
| caregiver_alerts | ~5,000 rows | ~450,000 rows |
| caregiver_alert_types | 8 rows (static) | 8 rows |

---

## Partition Strategy

Consider range partitioning by `created_at` for `caregiver_alerts` if volume exceeds estimates:

```sql
CREATE TABLE caregiver_alerts (
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE caregiver_alerts_y2026m02 
    PARTITION OF caregiver_alerts 
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
```
