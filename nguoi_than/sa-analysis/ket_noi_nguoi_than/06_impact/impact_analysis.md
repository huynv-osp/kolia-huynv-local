# Impact Analysis: Kết nối Người thân (v4.0)

> **Phase:** 6 - Impact Analysis  
> **Date:** 2026-02-13  
> **Overall Impact:** 🟡 MEDIUM (5 services, 8 tables, minor breaking changes)

---

## 1. Impact Summary

| Dimension | Value | Level |
|-----------|-------|:-----:|
| Services Affected | 5 backend + 1 mobile | 🟡 |
| Database Tables | 2 NEW + 1 ALTER + existing | 🟡 |
| New REST APIs | 6 | 🟡 |
| Deprecated APIs | 1 (DELETE /connections/:id) | 🟢 |
| Breaking Changes | invite_type enum values | 🟡 |
| Data Migration | Required (invite_type + new tables) | 🟡 |
| Cross-feature Impact | 3 CRs (Bản tin, Notifications, Reports) | 🟡 |

---

## 2. Breaking Changes Detail

### 2.1 invite_type Enum Migration

| Old Value | New Value | Action |
|-----------|-----------|--------|
| `add_caregiver` | `add_caregiver` | UPDATE existing records |
| `add_patient` | `add_patient` | UPDATE existing records |

**Migration Strategy:** SQL migration script `8_kcnt_invite_type_migration.sql`
- UPDATE existing pending invites
- ALTER CHECK constraint

### 2.2 Deprecated Endpoint

| Endpoint | Replacement | Timeline |
|----------|-------------|----------|
| `DELETE /connections/:id` | `PUT /connections/:contactId/revoke` (soft disconnect) | Removed in v4.0 |
| | `DELETE /family-groups/members/:memberId` (Admin hard remove) | |

---

## 3. Service Impact Matrix

| Service | New Code | Modified Code | Impact |
|---------|:--------:|:-------------:|:------:|
| user-service | 6 files | 4 files | 🔴 |
| api-gateway-service | 6 files | 3 files | 🔴 |
| payment-service | 0 files | 1 file (verify) | 🟡 |
| schedule-service | 1 file | 1 file | 🟡 |
| auth-service | 0 files | 0 files (verify only) | 🟢 |

---

## 4. Database Migration Impact

### 4.1 New Tables

| Table | Rows (estimate) | Impact on Existing |
|-------|:---------------:|---|
| `family_groups` | 1 per Admin | None — new table |
| `family_group_members` | N per group | None — new table |

### 4.2 Altered Tables

| Table | Column | Migration Risk |
|-------|--------|:-------------:|
| `user_emergency_contacts` | +`permission_revoked` BOOLEAN DEFAULT false | 🟢 LOW — additive, default value |
| `user_emergency_contacts` | +`family_group_id` UUID nullable | 🟢 LOW — additive, nullable |
| `connection_invites` | invite_type CHECK constraint | 🟡 MEDIUM — requires data migration |

### 4.3 Migration Order

```
1. Create family_groups table
2. Create family_group_members table
3. ALTER user_emergency_contacts (add columns)
4. Migrate invite_type values
5. ALTER connection_invites CHECK constraint
```

---

## 5. Cross-Feature Impact

### 5.1 CR_001: Bản tin Hành động

| Change | Detail |
|--------|--------|
| New action type | `INVITE_CONNECTION` |
| Priority | Đầu danh sách |
| Trigger | User có pending invite |
| Impact | 🟢 LOW — additive |

### 5.2 CR_002: Phân hệ Notification

| # | Kịch bản | Thay đổi v4.0 |
|:-:|----------|---------------|
| 1 | Nhận lời mời | Content updated: "{Tên Admin} mời..." |
| 2 | Được chấp nhận | Unchanged |
| 3 | Bị từ chối | Unchanged |
| 4 | Quyền thay đổi | **REMOVED** — silent revoke (BR-056) |
| 5 | Kết nối bị hủy | Changed: "Bạn đã bị xoá khỏi nhóm..." |
| **6** | **Thành viên mới vào nhóm** | **NEW (BR-052):** broadcast to ALL members |
| **7** | **Rời nhóm** | **NEW (BR-061):** Admin nhận push |

### 5.3 CR_003: Báo cáo Sức khỏe Notifications

| Impact | Detail |
|--------|--------|
| Change | None — existing logic applies |
| Note | CG push notification for reports still uses permission #1 check |

---

## 6. Payment Integration Impact

| Integration Point | Direction | Impact |
|--------------------|:---------:|:-----:|
| Slot check before invite | KCNT → Payment | 🟡 NEW dependency |
| Slot consume on invite sent | KCNT → Payment | 🟡 NEW dependency |
| Slot free on reject/cancel/remove | KCNT → Payment | 🟡 NEW dependency |
| Package expiry → block invite | Payment → KCNT | 🟡 NEW dependency |
| Admin validation | KCNT → Payment | 🟡 NEW dependency |

**Risk:** payment-service downtime blocks ALL invite operations.  
**Mitigation:** Circuit breaker + clear UX error message.

---

## 7. Backward Compatibility

| Area | Compatible? | Notes |
|------|:-----------:|-------|
| SOS features | ✅ | user_emergency_contacts extensions are additive |
| Existing connections | ✅ | permission_revoked defaults to false |
| Mobile app (old version) | ⚠️ | Old app won't see Family Group screens |
| REST API consumers | ⚠️ | DELETE /connections/:id deprecated |
| gRPC consumers | ✅ | New RPCs are additive |

---

## 8. Stakeholder Impact

| Stakeholder | Impact | Action Required |
|-------------|:------:|-----------------|
| Backend Team | HIGH | Implement 5 service changes |
| Mobile Team | HIGH | New screens, state management |
| DevOps | LOW | Kafka topics, DB migration |
| QA | MEDIUM | Cross-service test scenarios |
| Product | LOW | Review UX changes |
