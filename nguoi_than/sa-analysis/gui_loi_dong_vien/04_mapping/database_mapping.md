# Database Mapping: US 1.3 - Gửi Lời Động Viên

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-04  
> **Source:** SRS-Gửi-Lời-Động-Viên_v1.3

---

## New Tables

### 1. encouragement_messages

| Column | Type | Nullable | Default | Description |
|--------|------|:--------:|---------|-------------|
| encouragement_id | UUID | NO | gen_random_uuid() | PK |
| sender_id | UUID | NO | - | FK → users (Caregiver) |
| patient_id | UUID | NO | - | FK → users (Patient) |
| contact_id | UUID | NO | - | FK → user_emergency_contacts |
| content | VARCHAR(150) | NO | - | Message content (BR-002: max 150 chars) |
| sender_name | VARCHAR(100) | YES | - | Denormalized: e.g., "Huy" |
| relationship_code | VARCHAR(30) | YES | - | FK → relationships (e.g., "daughter") |
| relationship_display | VARCHAR(100) | YES | - | Denormalized: e.g., "Con gái" (Patient's perspective) |
| is_read | BOOLEAN | NO | FALSE | Read status |
| read_at | TIMESTAMPTZ | YES | - | When read |
| sent_at | TIMESTAMPTZ | NO | CURRENT_TIMESTAMP | When sent |
| created_at | TIMESTAMPTZ | NO | CURRENT_TIMESTAMP | Created time |
| updated_at | TIMESTAMPTZ | NO | CURRENT_TIMESTAMP | Updated time |

**Constraints:**

| Constraint | Definition | Purpose |
|------------|------------|---------|
| PK | encouragement_id | Primary key |
| FK_sender | sender_id → users(user_id) | Cascading delete |
| FK_patient | patient_id → users(user_id) | Cascading delete |
| FK_contact | contact_id → user_emergency_contacts(contact_id) | Cascading delete |
| FK_relationship | relationship_code → relationships(relationship_code) | Ensures valid code |
| CHK_content_length | char_length(content) <= 150 | BR-002 enforcement |
| CHK_different_users | sender_id != patient_id | Prevent self-message |

**Indexes:**

| Index Name | Columns | Condition | Purpose |
|------------|---------|-----------|---------| 
| idx_enc_patient_unread | (patient_id, is_read, sent_at DESC) | is_read = FALSE | Fast unread query for modal |
| idx_enc_patient_recent | (patient_id, sent_at DESC) | sent_at > NOW() - 24h | 24h window query |
| idx_enc_quota | (sender_id, patient_id, sent_at) | - | Daily quota check (timestamp range) |

**Estimated Size:**
- ~30,000 rows/day (at scale)
- 90-day retention → ~2.7M rows max

---

## Existing Tables Used

### 1. user_emergency_contacts

**Purpose:** Get connection info + relationship metadata

**Query Pattern (Get Relationship for Display):**

```sql
SELECT 
    uec.contact_id,
    uec.linked_user_id AS caregiver_id,
    uec.user_id AS patient_id,
    uec.relationship_code,           -- daughter
    uec.inverse_relationship_code,   -- mother
    r_inv.name_vi AS inverse_relationship_display,  -- "Con gái" (Patient calls Caregiver)
    u.full_name AS caregiver_display_name
FROM user_emergency_contacts uec
JOIN relationships r_inv ON r_inv.relationship_code = uec.inverse_relationship_code
JOIN users u ON u.user_id = uec.linked_user_id
WHERE uec.contact_id = :contact_id
  AND uec.is_active = TRUE;
```

> ⚠️ **IMPORTANT:** `relationship_display` stored in `encouragement_messages` should be
> from **Patient's perspective** (how Patient refers to Caregiver, i.e., `inverse_relationship_display`).
> This matches the Perspective Display Standard (v2.23).

---

### 2. connection_permissions

**Purpose:** Check Permission #6 (encouragement)

**Query Pattern:**

```sql
SELECT is_enabled
FROM connection_permissions
WHERE contact_id = :contact_id
  AND permission_code = 'encouragement';
```

---

### 3. connection_permission_types

**Purpose:** Verify permission code exists

**Seeded Data (Already in DB):**

```sql
INSERT INTO connection_permission_types (permission_code, name_vi, name_en, description, icon, display_order)
VALUES ('encouragement', 'Gửi động viên', 'Send Encouragement', 
        'Cho phép gửi tin nhắn động viên và nhắc nhở', 'message-circle-heart', 6);
```

> ✅ Permission #6 đã tồn tại, không cần migration cho lookup table

---

## Migration SQL

```sql
-- =============================================================================
-- Migration: V2026.02.04.1__create_encouragement_messages.sql
-- Feature: US 1.3 - Gửi Lời Động Viên
-- Author: SA Workflow
-- Date: 2026-02-04
-- =============================================================================

-- 1. Create main table
CREATE TABLE IF NOT EXISTS encouragement_messages (
    encouragement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Sender/Receiver relationship
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    
    -- Content (BR-002: max 150 Unicode chars)
    content VARCHAR(150) NOT NULL,
    
    -- Relationship metadata (denormalized for display efficiency)
    -- ⚠️ relationship_display shows how PATIENT refers to CAREGIVER (Perspective Standard v2.23)
    sender_name VARCHAR(100),                                       -- e.g., "Huy" (Caregiver's display name)
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),  -- FK: ensures valid code
    relationship_display VARCHAR(100),                              -- e.g., "Con gái" (Patient's perspective)
    
    -- Status tracking
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    
    -- Timestamps
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_enc_content_length CHECK (char_length(content) <= 150),
    CONSTRAINT chk_enc_different_users CHECK (sender_id != patient_id)
);

-- 2. Create indexes

-- Index for Patient modal (unread messages, recent first)
CREATE INDEX IF NOT EXISTS idx_enc_patient_unread 
    ON encouragement_messages (patient_id, is_read, sent_at DESC) 
    WHERE is_read = FALSE;

-- Index for 24h window query
CREATE INDEX IF NOT EXISTS idx_enc_patient_recent 
    ON encouragement_messages (patient_id, sent_at DESC)
    WHERE sent_at > CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- Index for daily quota check (BR-001: 10/day/patient)
-- Note: Use timestamp range query instead of DATE() (IMMUTABLE requirement)
CREATE INDEX IF NOT EXISTS idx_enc_quota 
    ON encouragement_messages (sender_id, patient_id, sent_at);

-- Index for sender history (optional, for Caregiver view)
CREATE INDEX IF NOT EXISTS idx_enc_sender 
    ON encouragement_messages (sender_id, sent_at DESC);

-- 3. Add trigger for updated_at
CREATE TRIGGER trigger_enc_messages_updated_at
    BEFORE UPDATE ON encouragement_messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 4. Comments
COMMENT ON TABLE encouragement_messages IS 'Encouragement messages from Caregiver to Patient (US 1.3 - Gửi Lời Động Viên)';
COMMENT ON COLUMN encouragement_messages.content IS 'Message content, max 150 Unicode chars (BR-002)';
COMMENT ON COLUMN encouragement_messages.relationship_display IS 'How Patient refers to Caregiver (Perspective Standard v2.23)';
COMMENT ON COLUMN encouragement_messages.is_read IS 'Read status for modal display';

-- =============================================================================
-- Grant permissions
-- =============================================================================
-- Note: Uncomment if app_user role exists in your environment
-- GRANT SELECT, INSERT, UPDATE ON encouragement_messages TO app_user;
```

---

## Query Patterns

### 1. Create Encouragement (with denormalization)

```sql
-- Step 1: Get relationship metadata
WITH connection_info AS (
    SELECT 
        uec.contact_id,
        u.full_name AS sender_name,
        uec.inverse_relationship_code AS relationship_code,
        r.name_vi AS relationship_display
    FROM user_emergency_contacts uec
    JOIN users u ON u.user_id = uec.linked_user_id
    JOIN relationships r ON r.relationship_code = uec.inverse_relationship_code
    WHERE uec.contact_id = :contact_id
)
-- Step 2: Insert message
INSERT INTO encouragement_messages (
    sender_id, patient_id, contact_id, content,
    sender_name, relationship_code, relationship_display
)
SELECT 
    :sender_id, :patient_id, :contact_id, :content,
    ci.sender_name, ci.relationship_code, ci.relationship_display
FROM connection_info ci
RETURNING encouragement_id;
```

### 2. Get Unread Messages (Patient Modal)

```sql
SELECT 
    encouragement_id,
    sender_name,
    relationship_display,
    content,
    sent_at
FROM encouragement_messages
WHERE patient_id = :patient_id
  AND is_read = FALSE
  AND sent_at > NOW() - INTERVAL '24 hours'
ORDER BY sent_at DESC;
```

### 3. Check Daily Quota (BR-001)

```sql
SELECT COUNT(*) AS today_count
FROM encouragement_messages
WHERE sender_id = :sender_id
  AND patient_id = :patient_id
  AND sent_at >= date_trunc('day', now())
  AND sent_at < date_trunc('day', now()) + interval '1 day';
```

### 4. Batch Mark as Read

```sql
UPDATE encouragement_messages
SET is_read = TRUE,
    read_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE encouragement_id = ANY(:ids)
  AND patient_id = :patient_id
  AND is_read = FALSE;
```

---

## Data Retention

| Policy | Value | Implementation |
|--------|-------|----------------|
| Message Retention | 90 days | Scheduled job to DELETE old records |
| Modal Display Window | 24 hours | Query filter on sent_at |
| Quota Reset | Daily at 00:00 UTC+7 | Timestamp range query on sent_at |

---

## Entity Relationship Diagram

```
┌─────────────────────┐
│       users         │
│  (sender/patient)   │
└─────────┬───────────┘
          │ 1:N
          ▼
┌─────────────────────────────────┐
│   encouragement_messages (NEW)  │
│   - encouragement_id (PK)       │
│   - sender_id (FK → users)      │
│   - patient_id (FK → users)     │
│   - contact_id (FK → uec)       │
│   - content (max 150)           │
│   - sender_name (denorm)        │
│   - relationship_display (denorm)│
│   - is_read, read_at            │
│   - sent_at, created_at         │
└────────────────┬────────────────┘
                 │
                 │ FK
                 ▼
┌─────────────────────────────────┐
│   user_emergency_contacts       │
│   (Connection Registry)         │
└─────────────────────────────────┘
```

---

## Next Steps

➡️ Proceed to Phase 5: Feasibility Assessment
