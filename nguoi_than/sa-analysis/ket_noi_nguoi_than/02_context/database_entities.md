# Database Entities: Connection Flow (REVISED)

> **Phase:** 2 - ALIO Architecture Context Loading  
> **Date:** 2026-02-13  
> **Revision:** v4.0 - Family Group model + permission_revoked + slot-based connections

---

## 1. Schema Overview

```
┌─────────────────────┐     ┌──────────────────────────┐
│  family_groups (v4)  │     │ family_group_members (v4)│
│  (group lifecycle)   │◄────│ (membership tracking)    │
└────────┬────────────┘     └──────────────────────────┘
         │ FK
┌────────▼────────────┐
│    relationships    │ ← Lookup table (14 types, v2.22)
└────────┬────────────┘
         │ FK                    ┌───────────────────────────┐
┌────────▼────────────┐          │ relationship_inverse_     │
│ connection_invites  │          │ mapping (v2.21)           │
│ (invite tracking)   │          │ Gender-based derivation   │
│ type: add_patient/  │          └───────────────────────────┘
│   add_caregiver     │
└────────┬────────────┘
         │ FK
┌────────▼────────────┐     ┌─────────────────────┐
│ user_emergency_     │◄────│  invite_notifications│
│ contacts (EXTENDED) │     │  (delivery tracking) │
│ + permission_revoked│     └─────────────────────┘
│ + family_group_id   │
└────────┬────────────┘
         │ FK                          
┌────────▼────────────┐     
│ connection_         │     
│ permissions (RBAC)  │     
└────────────────────┘
```

---

## 2. Table Details

### 2.0 family_groups (NEW v4.0)

> **Purpose:** Đại diện 1 nhóm gia đình, liên kết với payment subscription.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | Unique identifier |
| admin_user_id | UUID FK → users | Quản trị viên nhóm |
| subscription_id | UUID FK → subscriptions | Gói thanh toán liên kết |
| name | VARCHAR(100) | Tên nhóm (derived từ gói) |
| status | VARCHAR(20) | 'active', 'expired', 'suspended' |
| created_at | TIMESTAMPTZ | Created time |
| updated_at | TIMESTAMPTZ | Modified time |

**Constraints:**
- `idx_family_groups_admin`: UNIQUE (admin_user_id, status) WHERE status='active'
- `idx_family_groups_subscription`: INDEX (subscription_id)

---

### 2.0.1 family_group_members (NEW v4.0)

> **Purpose:** Tracking thành viên trong nhóm (Patient/Caregiver slots)

| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | Unique identifier |
| family_group_id | UUID FK → family_groups | Nhóm gia đình |
| user_id | UUID FK → users | Thành viên |
| role | VARCHAR(20) | 'patient', 'caregiver' |
| status | VARCHAR(20) | 'active', 'pending', 'removed' |
| joined_at | TIMESTAMPTZ | Thời điểm tham gia |
| removed_at | TIMESTAMPTZ | Thời điểm rời nhóm (nullable) |

**Constraints:**
- `idx_fgm_unique_active`: UNIQUE (family_group_id, user_id, role) WHERE status='active'
- `idx_fgm_user_active_group`: UNIQUE (user_id) WHERE status='active' — **Exclusive Group (BR-057)**

---

### 2.1 relationships (NEW - Lookup)

| Column | Type | Description |
|--------|------|-------------|
| relationship_code | VARCHAR(30) PK | 'con_trai', 'vo', 'khac' |
| name_vi | VARCHAR(100) | 'Con trai', 'Vợ', 'Khác' |
| name_en | VARCHAR(100) | 'Son', 'Wife', 'Other' |
| category | VARCHAR(30) | 'family', 'spouse', 'other' |
| display_order | SMALLINT | UI ordering |
| is_active | BOOLEAN | Soft delete |

**Seed Data:** 14 values (v2.22 — merged ong_noi/ong_ngoai→ong, ba_noi/ba_ngoai→ba, chau_trai/chau_gai→chau)

---

### 2.1.1 relationship_inverse_mapping (NEW v2.21)

> **Purpose:** Gender-based inverse relationship derivation

| Column | Type | Description |
|--------|------|-------------|
| relationship_code | VARCHAR(30) PK,FK | Original relationship |
| target_gender | SMALLINT PK | 0: Nam, 1: Nữ (gender of other party) |
| inverse_code | VARCHAR(30) FK | Derived inverse code |

**Example Data (v2.22):**
- `('chau', 0, 'ong')` → Cháu's sender (Nam) = Ông
- `('chau', 1, 'ba')` → Cháu's sender (Nữ) = Bà

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
| **permission_revoked** | BOOLEAN DEFAULT false | Tắt toàn bộ quyền theo dõi **(v4.0, BR-040)** |
| **family_group_id** | UUID FK → family_groups | Nhóm gia đình liên kết **(v4.0)** |
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
| invite_type | VARCHAR(30) | **v4.0:** `add_patient` / `add_caregiver` |
| relationship_code | VARCHAR(30) FK | Sender mô tả Receiver |
| **inverse_relationship_code** | VARCHAR(30) FK | Receiver mô tả Sender **(v2.13)** |
| initial_permissions | JSONB | 5 permissions at invite time |
| status | SMALLINT | 0:pending, 1:accepted, 2:rejected, 3:cancelled |
| created_at | TIMESTAMPTZ | Created time |
| updated_at | TIMESTAMPTZ | Modified time |

**Constraints:**
- `chk_no_self_invite`: sender_id != receiver_id
- `idx_unique_pending_invite`: UNIQUE (sender_id, receiver_phone, invite_type) WHERE status=0
- `chk_invite_type`: invite_type IN ('add_patient', 'add_caregiver')

---

### 2.4 connection_permissions (NEW - RBAC)

| Column | Type | Description |
|--------|------|-------------|
| permission_id | UUID PK | Unique identifier |
| contact_id | UUID FK → user_emergency_contacts | Which connection |
| permission_type | VARCHAR(30) | 5 types |
| is_enabled | BOOLEAN | ON/OFF |
| updated_at | TIMESTAMPTZ | Last change |
| updated_by | UUID FK | Who changed |

**5 Permission Types (SRS v4.0):**
1. health_overview
2. emergency_alert
3. task_config
4. compliance_tracking
5. encouragement

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

## 4. v4.0 Changes Summary

| Change | Details |
|--------|---------|
| +2 NEW tables | `family_groups`, `family_group_members` |
| +2 ALTER columns | `permission_revoked`, `family_group_id` on `user_emergency_contacts` |
| invite_type enum | `add_caregiver`/`add_patient` → `add_patient`/`add_caregiver` |
| Permissions | 6 → 5 types (removed `proxy_execution` merged into `compliance_tracking`) |
| Exclusive Group | UNIQUE constraint on `user_id` WHERE status='active' (BR-057) |
