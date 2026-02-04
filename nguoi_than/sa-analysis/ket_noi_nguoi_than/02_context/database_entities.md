# Database Entities: Connection Flow (REVISED)

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-04  
> **Revision:** v2.23 - Schema optimized + inverse relationship + is_viewing

---

## 1. Schema Overview

```
┌─────────────────────┐
│    relationships    │ ← Lookup table (17 types)
└────────┬────────────┘
         │ FK                    ┌───────────────────────────┐
┌────────▼────────────┐          │ relationship_inverse_     │
│ connection_invites  │          │ mapping (v2.21)           │
│ (invite tracking)   │          │ Gender-based derivation   │
└────────┬────────────┘          └───────────────────────────┘
         │ FK
┌────────▼────────────┐     ┌─────────────────────┐
│ user_emergency_     │◄────│  invite_notifications│
│ contacts (EXTENDED) │     │  (delivery tracking) │
└────────┬────────────┘     └─────────────────────┘
         │ FK                          
┌────────▼────────────┐     
│ connection_         │     
│ permissions (RBAC)  │     
└────────────────────┘

---

## 2. Table Details

### 2.1 relationships (NEW - Lookup)

| Column | Type | Description |
|--------|------|-------------|
| relationship_code | VARCHAR(30) PK | 'con_trai', 'vo', 'khac' |
| name_vi | VARCHAR(100) | 'Con trai', 'Vợ', 'Khác' |
| name_en | VARCHAR(100) | 'Son', 'Wife', 'Other' |
| category | VARCHAR(30) | 'family', 'spouse', 'other' |
| display_order | SMALLINT | UI ordering |
| is_active | BOOLEAN | Soft delete |

**Seed Data:** 17 values (14 from SRS + anh_trai, chi_gai, khac)

---

### 2.1.1 relationship_inverse_mapping (NEW v2.21)

> **Purpose:** Gender-based inverse relationship derivation

| Column | Type | Description |
|--------|------|-------------|
| relationship_code | VARCHAR(30) PK,FK | Original relationship |
| target_gender | SMALLINT PK | 0: Nam, 1: Nữ (gender of other party) |
| inverse_code | VARCHAR(30) FK | Derived inverse code |

**Example Data:**
- `('chau_trai', 0, 'ong_noi')` → Cháu trai's sender (Nam) = Ông nội
- `('chau_trai', 1, 'ba_noi')` → Cháu trai's sender (Nữ) = Bà nội

---

### 2.2 user_emergency_contacts (EXTEND existing)

**Existing columns** (SOS - unchanged):
- contact_id, user_id, name, phone, relationship, priority, is_active, zalo_enabled

**New columns:**

| Column | Type | Description |
|--------|------|-------------|
| linked_user_id | UUID FK → users | App user ID (nullable) |
| contact_type | VARCHAR(20) | 'emergency', 'caregiver', 'both', 'disconnected' |
| relationship_code | VARCHAR(30) FK | Patient mô tả Caregiver |
| **inverse_relationship_code** | VARCHAR(30) FK | Caregiver mô tả Patient **(v2.13)** |
| **is_viewing** | BOOLEAN | Đánh dấu Patient đang được xem **(v2.7)** |
| invite_id | UUID FK | Created from which invite |

---

### 2.3 connection_invites (NEW)

| Column | Type | Description |
|--------|------|-------------|
| invite_id | UUID PK | Unique identifier |
| sender_id | UUID FK → users | Who sent |
| receiver_phone | VARCHAR(20) | Recipient phone |
| receiver_id | UUID FK → users | If existing user (nullable) |
| receiver_name | VARCHAR(100) | Display name |
| invite_type | VARCHAR(30) | patient_to_caregiver / caregiver_to_patient |
| relationship_code | VARCHAR(30) FK | Sender mô tả Receiver |
| **inverse_relationship_code** | VARCHAR(30) FK | Receiver mô tả Sender **(v2.13)** |
| initial_permissions | JSONB | 6 permissions at invite time |
| status | SMALLINT | 0:pending, 1:accepted, 2:rejected, 3:cancelled |
| created_at | TIMESTAMPTZ | Created time |
| updated_at | TIMESTAMPTZ | Modified time |

**Constraints:**
- `chk_no_self_invite`: sender_id != receiver_id
- `idx_unique_pending_invite`: UNIQUE (sender_id, receiver_phone, invite_type) WHERE status=0

---

### 2.4 connection_permissions (NEW - RBAC)

| Column | Type | Description |
|--------|------|-------------|
| permission_id | UUID PK | Unique identifier |
| contact_id | UUID FK → user_emergency_contacts | Which connection |
| permission_type | VARCHAR(30) | 6 types |
| is_enabled | BOOLEAN | ON/OFF |
| updated_at | TIMESTAMPTZ | Last change |
| updated_by | UUID FK | Who changed |

**6 Permission Types:**
1. health_overview
2. emergency_alert
3. task_config
4. compliance_tracking
5. proxy_execution
6. encouragement

---

### 2.5 invite_notifications (NEW)

| Column | Type | Description |
|--------|------|-------------|
| notification_id | UUID PK | Unique identifier |
| invite_id | UUID FK | Which invite |
| channel | VARCHAR(10) | ZNS, SMS, PUSH |
| status | SMALLINT | 0:pending, 1:sent, 2:delivered, 3:failed |
| retry_count | SMALLINT | Max 3 (BR-004) |
| deep_link_sent | BOOLEAN | For new users (BR-003) |
| sent_at | TIMESTAMPTZ | When sent |
| error_message | TEXT | Error details |

---

## 3. SOS Backward Compatibility

| SOS Feature | Status |
|-------------|:------:|
| Create emergency contact | ✅ |
| List contacts | ✅ |
| SOS notification | ✅ |
| Escalation calls | ✅ |
