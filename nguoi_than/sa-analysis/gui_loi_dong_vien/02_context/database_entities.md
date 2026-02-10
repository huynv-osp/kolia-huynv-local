# Database Entities: US 1.3 - Gửi Lời Động Viên

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-04  
> **Source:** Alio_database_create.sql

---

## Existing Tables (Reuse)

### 1. connection_permission_types

**Purpose:** Lookup table for permission types (6 types)

| permission_code | name_vi | display_order |
|-----------------|---------|:-------------:|
| health_overview | Xem tổng quan sức khỏe | 1 |
| emergency_alert | Nhận cảnh báo khẩn cấp | 2 |
| task_config | Cấu hình nhiệm vụ | 3 |
| compliance_tracking | Theo dõi tuân thủ | 4 |
| proxy_execution | Thực hiện thay mặt | 5 |
| **encouragement** | **Gửi động viên** | **6** |

> ✅ Permission #6 (`encouragement`) đã tồn tại, không cần thêm

---

### 2. connection_permissions

**Purpose:** RBAC permissions per connection

| Column | Type | Description |
|--------|------|-------------|
| permission_id | UUID | PK |
| contact_id | UUID | FK → user_emergency_contacts |
| permission_code | VARCHAR(30) | FK → connection_permission_types |
| is_enabled | BOOLEAN | Permission switch |

**Query Pattern (Permission Check):**

```sql
SELECT is_enabled
FROM connection_permissions
WHERE contact_id = :contact_id
  AND permission_code = 'encouragement';
```

---

### 3. user_emergency_contacts

**Purpose:** Connection registry for Caregiver-Patient relationships

| Column | Type | Description |
|--------|------|-------------|
| contact_id | UUID | PK |
| user_id | UUID | Patient |
| linked_user_id | UUID | Caregiver |
| relationship_code | VARCHAR | Patient calls Caregiver [X] |
| inverse_relationship_code | VARCHAR | Caregiver calls Patient [X] |
| contact_type | VARCHAR | 'caregiver', 'both' |

**Query Pattern (Get Relationship Info):**

```sql
SELECT 
    uec.contact_id,
    uec.user_id AS patient_id,
    uec.linked_user_id AS caregiver_id,
    r1.name_vi AS relationship_display,      -- How Patient calls Caregiver
    r2.name_vi AS inverse_relationship_display, -- How Caregiver calls Patient
    u.full_name AS caregiver_name
FROM user_emergency_contacts uec
JOIN relationships r1 ON uec.relationship_code = r1.relationship_code
JOIN relationships r2 ON uec.inverse_relationship_code = r2.relationship_code
JOIN users u ON uec.linked_user_id = u.user_id
WHERE uec.contact_id = :contact_id;
```

---

### 4. relationships

**Purpose:** Master lookup for relationship types (14 types, v2.22)

| Column | Type | Description |
|--------|------|-------------|
| relationship_code | VARCHAR | PK |
| name_vi | VARCHAR | Vietnamese name |
| name_en | VARCHAR | English name |
| category | VARCHAR | 'parent', 'child', 'spouse', 'sibling', 'other' |

---

### 5. users

**Purpose:** User profiles

| Column | Type | Description |
|--------|------|-------------|
| user_id | UUID | PK |
| full_name | VARCHAR(100) | Display name |
| feeling | SMALLINT | Mood (1-5) |

---

## New Table Required

### encouragement_messages

**Purpose:** Store encouragement messages from Caregiver to Patient

**Design Considerations:**
- Denormalize relationship info for display efficiency
- Track read status for modal/list display
- 24h window for modal display

**Detailed Schema:** See `04_mapping/database_mapping.md`

---

## Entity Relationship

```
┌─────────────────────┐
│       users         │
│  (Patient)          │
└─────────┬───────────┘
          │ 1:N
          ▼
┌─────────────────────────────────┐
│   user_emergency_contacts       │
│   (Connection Registry)         │
└─────────┬───────────────────────┘
          │ 1:N
          ▼
┌─────────────────────────────────┐     ┌─────────────────────────┐
│   connection_permissions        │────►│ connection_permission_  │
│   (RBAC)                        │     │ types (Lookup)          │
└─────────┬───────────────────────┘     └─────────────────────────┘
          │
          │ Check permission_code = 'encouragement'
          ▼
┌─────────────────────────────────┐
│   encouragement_messages (NEW)  │
│   - sender_id (Caregiver)       │
│   - patient_id (Patient)        │
│   - contact_id (Connection)     │
│   - content (max 150 chars)     │
│   - relationship_display        │
│   - is_read, sent_at            │
└─────────────────────────────────┘
```

---

## Next Steps

➡️ Proceed to Phase 3: Functional Requirements Extraction
