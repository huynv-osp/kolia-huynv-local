# Database Mapping: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-13  
> **Revision:** v4.0 — Added family_groups, family_group_members, ALTER user_emergency_contacts (+permission_revoked, +family_group_id)

---

## 1. Schema Strategy

| Approach | Description |
|----------|-------------|
| **Extend** | user_emergency_contacts (+permission_revoked, +family_group_id) |
| **Reuse** | relationships lookup for SOS + Caregiver |
| **Keep** | connection_invites, connection_permissions, invite_notifications |
| **NEW** | **family_groups** (nhóm gia đình) |
| **NEW** | **family_group_members** (thành viên nhóm) |

---

## 2. Table Summary

| Table | Status | v4.0 Change |
|-------|:------:|:-----------:|
| relationships | ✅ Existing | No change |
| relationship_inverse_mapping | ✅ Existing | No change |
| user_emergency_contacts | 🔄 ALTER | +`permission_revoked`, +`family_group_id` |
| connection_invites | 🟡 UPDATE | invite_type enum update (add_patient/add_caregiver) |
| connection_permission_types | ✅ Existing | No change (6 types giữ nguyên) |
| connection_permissions | ✅ Existing | No change |
| invite_notifications | ✅ Existing | No change |
| caregiver_report_views | ✅ Existing | No change |
| **family_groups** | 🆕 **NEW** | Admin+subscription based |
| **family_group_members** | 🆕 **NEW** | Members with role constraints |

**Total: 2 NEW + 1 ALTER + 1 UPDATE + 6 KEEP = 10 tables**

---

## 3. SQL Changes (v4.0)

### 3.1 NEW: family_groups

```sql
CREATE TABLE IF NOT EXISTS family_groups (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id BIGINT NOT NULL REFERENCES users(id),
    subscription_id BIGINT,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### 3.2 NEW: family_group_members

```sql
CREATE TABLE IF NOT EXISTS family_group_members (
    id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES family_groups(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id),
    role VARCHAR(20) NOT NULL CHECK (role IN ('patient', 'caregiver')),
    joined_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(group_id, user_id, role)
);

-- BR-057: Exclusive Group (1 user = 1 group per role)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_single_group 
ON family_group_members(user_id, role);
```

### 3.3 ALTER: user_emergency_contacts (v4.0)

```sql
-- v4.0: Soft disconnect support
ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- v4.0: Link to family group
ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS family_group_id BIGINT REFERENCES family_groups(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_family_group 
ON user_emergency_contacts(family_group_id) WHERE family_group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_emergency_contacts_permission_revoked 
ON user_emergency_contacts(permission_revoked) WHERE permission_revoked = TRUE;
```

### 3.4 UPDATE: connection_invites (invite_type constraint)

```sql
-- v4.0: Update invite_type enum to support new types
ALTER TABLE connection_invites 
DROP CONSTRAINT IF EXISTS chk_invite_type;

ALTER TABLE connection_invites 
ADD CONSTRAINT chk_invite_type CHECK (invite_type IN (
    'patient_to_caregiver',   -- legacy
    'caregiver_to_patient',   -- legacy
    'add_patient',            -- v4.0: Admin adds Patient
    'add_caregiver'           -- v4.0: Admin adds Caregiver
));
```

---

## 4. Existing Tables (UNCHANGED from v2.x)

### 4.1 relationships (14 types)
> No changes — existing lookup with 14 relationship types.

### 4.2 relationship_inverse_mapping (28 mappings)
> No changes — existing gender-based inverse lookup.

### 4.3 connection_permission_types (6 types)
> No changes — **giữ nguyên 6 permissions** theo quyết định.

| Code | Name (VI) | Order |
|------|-----------|:-----:|
| health_overview | Xem tổng quan sức khỏe | 1 |
| emergency_alert | Nhận cảnh báo khẩn cấp | 2 |
| task_config | Cấu hình nhiệm vụ | 3 |
| compliance_tracking | Theo dõi tuân thủ | 4 |
| proxy_execution | Thực hiện thay mặt | 5 |
| encouragement | Gửi động viên | 6 |

### 4.4 connection_invites
> Structure unchanged. `initial_permissions` nullable (v5.0 simplified form).

### 4.5 connection_permissions
> Structure unchanged.

### 4.6 invite_notifications
> Structure unchanged.

### 4.7 caregiver_report_views
> Structure unchanged.

---

## 5. Triggers (UPDATED)

### Auto-create permissions on accept (KEEP)

```sql
-- Existing trigger: create_default_permissions()
-- Works correctly for v4.0 — auto-creates 6 permissions for new connections
-- No change needed
```

---

## 6. Business Rules Coverage (v4.0)

| BR | Table(s) | Implementation |
|----|----------|----------------|
| BR-006 | connection_invites | chk_no_self_invite |
| BR-007 | connection_invites | idx_unique_pending |
| BR-009 | connection_permissions | trigger default (ALL ON) |
| BR-028 | relationships + FK | relationship_code |
| BR-039 | connection_permissions | App logic (bypass in batch revoke) |
| **BR-041** | **N/A (app logic)** | **Admin role check via payment-service** |
| **BR-047** | **N/A (app logic)** | **Slot check via payment-service** |
| **BR-056** | **user_emergency_contacts** | **permission_revoked = TRUE (silent)** |
| **BR-057** | **family_group_members** | **idx_user_single_group (UNIQUE)** |

---

## 7. Table Summary (Final v4.0)

| Table | Status | Columns | Indexes |
|-------|:------:|:-------:|:-------:|
| relationships | Existing | 6 | 0 |
| relationship_inverse_mapping | Existing | 3 | 1 |
| connection_invites | UPDATE | 12 | 5 |
| user_emergency_contacts | ALTER | +2 | +2 |
| connection_permissions | Existing | 5 | 1 |
| connection_permission_types | Existing | 7 | 0 |
| invite_notifications | Existing | 13 | 5 |
| caregiver_report_views | Existing | 4 | 3 |
| **family_groups** | **NEW** | **5** | **0** |
| **family_group_members** | **NEW** | **5** | **2** |

> **Migration file:** `docs/_update_db/9_kcnt_v4_family_groups.sql`
