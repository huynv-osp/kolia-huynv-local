# Impact Analysis: KOLIA-1517 - Kết nối Người thân

> **Phase:** 3 - Impact Analysis  
> **Date:** 2026-02-02  
> **Revision:** v2.16 - Added Update Pending Invite Permissions API

---

## 1. Impact Summary (v2.0)

| Metric | v1.0 | v2.11 (Current) |
|--------|:----:|:----------------:|
| **Impact Level** | 🟡 MEDIUM | 🟢 **LOW** |
| **Services Affected** | 3 | 3 |
| **New Tables** | 4 | **6 NEW + 1 ALTER** |
| **Schema Reuse** | None | `user_emergency_contacts` |
| **Breaking Changes** | None | None |

---

## 2. Service Impact Matrix

| Service | Impact | Changes | Effort |
|---------|:------:|---------|:------:|
| **user-service** | 🔴 HIGH | 14 gRPC methods, 5 entities, 4 repos, 4 services | 48h |
| **api-gateway-service** | 🟡 MEDIUM | 12 REST endpoints, 1 gRPC client, DTOs | 20h |
| **schedule-service** | 🟡 MEDIUM | 2 Celery tasks, ZNS/SMS integration | 8h |

---

## 3. Database Impact (v2.0 Optimized)

### Schema Changes

| Table | Status | Purpose | Storage Estimate |
|-------|:------:|---------|:----------------:|
| `relationships` | ✅ NEW | Lookup (14 types, v2.22) | ~1KB (static) |
| `connection_permission_types` | ✅ NEW | Permission lookup (6 types) | ~1KB (static) |
| `connection_invites` | ✅ NEW | Invite tracking | ~1MB/month |
| `user_emergency_contacts` | 🔄 EXTEND | +5 columns for caregiver | Existing table |
| `connection_permissions` | ✅ NEW | 6 RBAC flags (FK) | ~300KB |
| `invite_notifications` | ✅ NEW | Delivery tracking | ~3MB/month |
| **`caregiver_report_views`** | ✅ **NEW** | Report read tracking | ~500KB |

### Extended Columns (user_emergency_contacts)

| Column | Type | Purpose |
|--------|------|---------|
| `linked_user_id` | UUID FK | Caregiver's user account |
| `contact_type` | VARCHAR(20) | 'emergency', 'caregiver', 'both', 'disconnected' |
| `relationship_code` | VARCHAR(30) FK | Normalized relationship |
| `invite_id` | UUID FK | Created from which invite |
| `is_viewing` | BOOLEAN | Currently viewing this patient (BR-026) |

### SOS Backward Compatibility ✅

- Existing `user_emergency_contacts` contacts with `contact_type='emergency'` unchanged
- SOS notification flow continues to work
- Rollback script included in migration

---

## 4. API Impact

### New REST Endpoints (15)

| Method | Path | Access |
|--------|------|--------|
| POST | `/api/v1/invites` | Authenticated |
| GET | `/api/v1/invites` | Authenticated |
| DELETE | `/api/v1/invites/{id}` | Authenticated |
| POST | `/api/v1/invites/{id}/accept` | Authenticated |
| POST | `/api/v1/invites/{id}/reject` | Authenticated |
| GET | `/api/v1/connections` | Authenticated |
| DELETE | `/api/v1/connections/{id}` | Authenticated |
| GET | `/api/v1/connections/{id}/permissions` | Authenticated |
| PUT | `/api/v1/connections/{id}/permissions` | Authenticated |
| GET | `/api/v1/connection/permission-types` | Authenticated |
| GET | `/api/v1/connections/viewing` | Authenticated |
| PUT | `/api/v1/connections/viewing` | Authenticated |
| **GET** | **`/api/v1/patients/{id}/blood-pressure-chart`** | **Connection+Perm** |
| **GET** | **`/api/v1/patients/{id}/periodic-reports`** | **Connection+Perm** |
| **PUT** | **`/api/v1/connections/invites/{id}/permissions`** | **Authenticated (v2.16)** |
### New gRPC Methods (16)

```protobuf
service ConnectionService {
  // Invite methods
  CreateInvite, GetInvite, ListInvites,
  AcceptInvite, RejectInvite, CancelInvite,
  // Connection methods
  ListConnections, Disconnect,
  GetPermissions, UpdatePermissions,
  ListPermissionTypes, ListRelationshipTypes,
  // Profile Selection (v2.7)
  GetViewingPatient, SetViewingPatient,
  // Dashboard APIs (v2.11)
  GetBloodPressureChart, GetPatientReports,
  // Update Pending Invite Permissions (v2.16)
  UpdatePendingInvitePermissions
}
```

---

## 5. Notification Impact

### New Notification Scenarios (5)

| Scenario | Channel | Priority |
|----------|---------|:--------:|
| Nhận lời mời | ZNS + Push | HIGH |
| Được chấp nhận | Push | MEDIUM |
| Bị từ chối | Push | LOW |
| Quyền thay đổi | Push | MEDIUM |
| Kết nối bị hủy | Push | HIGH |

### ZNS Template Requirements

| Template | Content |
|----------|---------|
| `invite_to_monitor` | "{Tên} mời bạn theo dõi sức khỏe của họ" |
| `request_to_monitor` | "{Tên} muốn theo dõi sức khỏe của bạn" |

---

## 6. Integration Impact

### Bản tin Hành động

- Add `INVITE_CONNECTION` action type to BR-004
- Position: Đầu danh sách Ưu tiên
- Trigger: User có ≥1 lời mời pending
- Action: Navigate to SCR-01

### Notification Subsystem

- Add 5 notification scenarios
- Reuse existing `notifications` table structure
- Add new `schedule_type` values

---

## 7. Performance Impact

### Expected Load

| Metric | Value |
|--------|-------|
| Invites/day | ~100-500 |
| Active connections | ~50K |
| Permission updates/day | ~50-100 |

### Mitigation Strategies

- Indexes on frequently queried columns
- Partial indexes for status filters
- Kafka for async notification processing

---

## 8. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|:-----------:|:------:|------------|
| ZNS approval delay | Medium | Medium | SMS fallback ready |
| Deep link failures | Low | High | Verify infra Week 1 |
| Permission desync | Low | Medium | Server as truth |
| State machine bugs | Medium | Medium | Comprehensive tests |

---

## 9. Feasibility Score (v2.0)

| Criteria | Weight | Score | Notes |
|----------|:------:|:-----:|-------|
| Architecture Fit | 25% | 5/5 | Reuses existing infrastructure |
| Database Compatibility | 20% | 5/5 | EXTEND user_emergency_contacts |
| API/gRPC Compatibility | 15% | 4/5 | Standard patterns |
| Service Boundary Clarity | 15% | 4/5 | Clear ownership |
| Technology Stack Match | 10% | 5/5 | Vert.x/Java/Postgres |
| Team Expertise | 10% | 4/5 | Similar to SOS |
| Time/Resource | 5% | 4/5 | 70h estimated |
| **Total** | | **88/100** ✅ | Improved from v1.0 (84) |

---

## Conclusion

Feature is **FEASIBLE** with **MEDIUM** impact. No breaking changes to existing functionality. Main risks are external (ZNS approval, deep links) which have mitigation strategies.
