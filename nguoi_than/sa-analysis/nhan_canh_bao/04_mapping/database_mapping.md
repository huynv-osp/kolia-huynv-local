# Database Mapping: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-02

---

## New Tables

### 1. caregiver_alerts

| Column | Type | Nullable | Default | Description |
|--------|------|:--------:|---------|-------------|
| alert_id | UUID | NO | gen_random_uuid() | PK |
| caregiver_id | UUID | NO | - | FK → users |
| patient_id | UUID | NO | - | FK → users |
| contact_id | UUID | YES | - | FK → user_emergency_contacts |
| alert_type_id | SMALLINT | NO | - | FK → caregiver_alert_types (1-4) |
| priority | SMALLINT | NO | 1 | 0=Critical/SOS, 1=High, 2=Medium, 3=Low |
| title | VARCHAR(150) | NO | - | Alert content (sub-type encoded here) |
| body | TEXT | YES | - | Optional longer description |
| icon | VARCHAR(20) | YES | - | Set by BE: 🚨, ⚠️, 💛, 💊, 📊 |
| color | VARCHAR(20) | YES | - | Set by BE: red, yellow, orange, gray |
| deeplink | VARCHAR(200) | YES | - | Navigation link |
| payload | JSONB | YES | - | Extra data (BP values, notes, etc.) |
| status | SMALLINT | NO | 0 | 0=unread, 1=read |
| push_status | SMALLINT | NO | 0 | 0=pending, 1=sent, 2=delivered, 3=failed |
| push_sent_at | TIMESTAMPTZ | YES | - | When push sent |
| push_error | TEXT | YES | - | Error message |
| source_type | VARCHAR(30) | YES | - | blood_pressure, medication, sos, compliance |
| source_id | TEXT | YES | - | ID in source table (BIGINT or UUID as string) |
| created_at | TIMESTAMPTZ | NO | CURRENT_TIMESTAMP | Created time |
| read_at | TIMESTAMPTZ | YES | - | When read |
| expires_at | TIMESTAMPTZ | YES | - | Retention expiry (90 days) |

**Indexes:**

| Index Name | Columns | Condition | Purpose |
|------------|---------|-----------|---------|
| idx_alerts_caregiver_unread | (caregiver_id, status, created_at DESC) | status = 0 | Fast unread query |
| idx_alerts_patient | (patient_id, created_at DESC) | - | Patient alerts |
| idx_alerts_type | (caregiver_id, alert_type_id, created_at DESC) | - | ⭐ UI filter by category |
| idx_alerts_priority | (priority, created_at DESC) | - | Priority sort |
| idx_alerts_expires | (expires_at) | - | Retention cleanup |
| idx_alerts_push_pending | (push_status) | push_status IN (0, 3) | Retry queue |
| idx_alerts_debounce | (caregiver_id, patient_id, alert_type_id, time_bucket) | priority > 0 | 5-min debounce |

**Estimated Size:** ~450,000 rows (90-day retention, 5000/day)

---

### 2. caregiver_alert_types ⭐ SIMPLIFIED (4 Categories)

> **Design Decision:** Chỉ lưu 4 loại category khớp với UI filter tabs.

| Column | Type | Nullable | Default | Description |
|--------|------|:--------:|---------|-------------|
| type_id | SMALLINT | NO | - | PK |
| type_code | VARCHAR(20) | NO | - | Unique code: SOS, HA, MEDICATION, COMPLIANCE |
| name_vi | VARCHAR(50) | NO | - | Vietnamese name |
| name_en | VARCHAR(50) | NO | - | English name |
| icon | VARCHAR(10) | YES | - | Category icon |
| display_order | SMALLINT | YES | 0 | UI sort order |

**Seed Data (4 rows matching UI filter tabs):**

| type_id | type_code | name_vi | name_en | icon | display_order |
|:-------:|-----------|---------|---------|:----:|:-------------:|
| 1 | SOS | Khẩn cấp | Emergency | 🚨 | 1 |
| 2 | HA | Huyết áp | Blood Pressure | ❤️ | 2 |
| 3 | MEDICATION | Thuốc | Medication | 💊 | 3 |
| 4 | COMPLIANCE | Tuân thủ | Compliance | 📊 | 4 |

---

## Existing Tables Used

### user_emergency_contacts

**Purpose:** Get active caregivers for patient  
**Query Pattern:**

```sql
SELECT linked_user_id as caregiver_id
FROM user_emergency_contacts
WHERE user_id = :patient_id
  AND contact_type IN ('caregiver', 'both')
  AND is_active = TRUE
  AND linked_user_id IS NOT NULL;
```

---

### connection_permissions

**Purpose:** Check Permission #2 (BR-ALT-001)  
**Query Pattern:**

```sql
SELECT cp.is_enabled
FROM connection_permissions cp
JOIN connection_permission_types cpt ON cp.permission_type_id = cpt.id
WHERE cp.contact_id = :contact_id
  AND cpt.type_code = 'RECEIVE_EMERGENCY_ALERTS';
```

---

### user_blood_pressure

**Purpose:** Get BP data for threshold evaluation  
**Query Patterns:**

```sql
-- Latest reading
SELECT systolic, diastolic, measurement_time
FROM user_blood_pressure
WHERE user_id = :patient_id
  AND status = 0
ORDER BY measurement_time DESC
LIMIT 1;

-- 7-day average
SELECT AVG(systolic) as avg_systolic, AVG(diastolic) as avg_diastolic
FROM user_blood_pressure
WHERE user_id = :patient_id
  AND status = 0
  AND measurement_time >= NOW() - INTERVAL '7 days';
```

---

### medication_schedules

**Purpose:** Track missed medications  
**Query Pattern:**

```sql
-- Count consecutive misses
SELECT COUNT(*) as missed_count
FROM medication_schedules
WHERE user_id = :patient_id
  AND related_id = :prescription_item_id
  AND status = 0  -- not completed
  AND scheduled_time < NOW()
  AND scheduled_time >= :last_check_time
ORDER BY scheduled_time DESC
LIMIT 3;
```

---

## Migration SQL

```sql
-- Migration: V2026.02.02.1__create_caregiver_alerts.sql

-- 1. Create alert types lookup table (4 CATEGORIES - SRS v1.5)
CREATE TABLE IF NOT EXISTS caregiver_alert_types (
    type_id SMALLINT PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,
    name_vi VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    icon VARCHAR(10),
    display_order SMALLINT NOT NULL DEFAULT 0
);

-- ⭐ SRS v1.5: 4 categories (UI filter tabs)
INSERT INTO caregiver_alert_types (type_id, type_code, name_vi, name_en, icon, display_order)
VALUES
    (1, 'SOS', 'Khẩn cấp', 'Emergency', '🚨', 1),
    (2, 'HA', 'Huyết áp', 'Blood Pressure', '❤️', 2),
    (3, 'MEDICATION', 'Thuốc', 'Medication', '💊', 3),
    (4, 'COMPLIANCE', 'Tuân thủ', 'Compliance', '📊', 4)
ON CONFLICT (type_id) DO NOTHING;

COMMENT ON TABLE caregiver_alert_types IS 'Lookup table for caregiver alert types - 4 categories per SRS v1.5 (US 1.2)';

-- 2. Create main alerts table
CREATE TABLE IF NOT EXISTS caregiver_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES user_emergency_contacts(contact_id) ON DELETE SET NULL,
    alert_type_id SMALLINT NOT NULL REFERENCES caregiver_alert_types(type_id),
    priority SMALLINT NOT NULL DEFAULT 1,
    title VARCHAR(150) NOT NULL,
    body TEXT,  -- Optional longer description
    icon VARCHAR(20),
    color VARCHAR(20),
    deeplink VARCHAR(200),
    payload JSONB,
    status SMALLINT NOT NULL DEFAULT 0,
    push_status SMALLINT NOT NULL DEFAULT 0,
    push_sent_at TIMESTAMPTZ,
    push_error TEXT,
    source_type VARCHAR(30),
    source_id TEXT,  -- TEXT to support both BIGINT (BP/medication) and UUID (SOS)
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP + INTERVAL '90 days',
    
    CONSTRAINT chk_alert_status CHECK (status IN (0, 1)),
    CONSTRAINT chk_alert_push_status CHECK (push_status IN (0, 1, 2, 3)),
    CONSTRAINT chk_alert_priority CHECK (priority BETWEEN 0 AND 3)
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS idx_alerts_caregiver_unread 
    ON caregiver_alerts (caregiver_id, status, created_at DESC) 
    WHERE status = 0;

CREATE INDEX IF NOT EXISTS idx_alerts_patient 
    ON caregiver_alerts (patient_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_type 
    ON caregiver_alerts (alert_type_id);

-- ⭐ UI filter index (filter by type_id = 1/2/3/4 for SOS/HA/MEDICATION/COMPLIANCE)
CREATE INDEX IF NOT EXISTS idx_alerts_filter 
    ON caregiver_alerts (caregiver_id, alert_type_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_priority 
    ON caregiver_alerts (priority, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_expires 
    ON caregiver_alerts (expires_at);

CREATE INDEX IF NOT EXISTS idx_alerts_push_pending 
    ON caregiver_alerts (push_status) 
    WHERE push_status IN (0, 3);

-- Debounce: 5-minute buckets (300 seconds)
CREATE UNIQUE INDEX IF NOT EXISTS idx_alerts_debounce 
    ON caregiver_alerts (
        caregiver_id, 
        patient_id, 
        alert_type_id, 
        (date_trunc('hour', created_at) + 
         INTERVAL '5 min' * FLOOR(EXTRACT(MINUTE FROM created_at) / 5))
    )
    WHERE priority > 0;  -- SOS (priority=0) excluded from debounce

-- 4. Add trigger for updated_at (if needed)
CREATE TRIGGER trigger_alerts_updated_at
    BEFORE UPDATE ON caregiver_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. Comments
COMMENT ON TABLE caregiver_alerts IS 'Health alerts for caregivers (US 1.2 - Nhận Cảnh Báo, SRS v1.5)';
COMMENT ON COLUMN caregiver_alerts.alert_type_id IS 'FK to caregiver_alert_types: 1=SOS, 2=HA, 3=MEDICATION, 4=COMPLIANCE';
COMMENT ON COLUMN caregiver_alerts.priority IS '0=SOS, 1=Critical, 2=High, 3=Medium';
COMMENT ON COLUMN caregiver_alerts.status IS '0=unread, 1=read';
COMMENT ON COLUMN caregiver_alerts.push_status IS '0=pending, 1=sent, 2=delivered, 3=failed';
COMMENT ON COLUMN caregiver_alerts.expires_at IS '90-day retention per BR-ALT-009';
```

