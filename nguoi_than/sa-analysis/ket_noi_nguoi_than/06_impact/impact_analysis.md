# Impact Analysis: KOLIA-1517 (REVISED v2.13)

> **Phase:** 6 - Impact Analysis  
> **Date:** 2026-01-30  
> **Revision:** v2.13 - Added Patient BP Thresholds to Blood Pressure Chart API
> **Impact Level:** 🟢 LOW (reduced from MEDIUM)

---

## 1. Impact Summary

| Factor | Before | After (Optimized) |
|--------|:------:|:-----------------:|
| **New Tables** | 4 | **5 + 1 ALTER** |
| **Schema Reuse** | None | `user_emergency_contacts` |
| **Code Duplication** | Yes | Minimized |
| **Impact Level** | 🟡 MEDIUM | 🟢 **LOW** |

---

## 2. Database Impact

### Tables

| Table | Status | Purpose |
|-------|:------:|---------|
| relationships | ✅ NEW | Lookup (17 types) |
| connection_permission_types | ✅ NEW | Permission lookup (6 types) |
| user_emergency_contacts | 🔄 EXTEND | Add 4 columns |
| connection_invites | ✅ NEW | Invite tracking |
| connection_permissions | ✅ NEW | RBAC (FK to permission_types) |
| invite_notifications | ✅ NEW | Delivery tracking |

### Storage Estimate

| Table | Records/Month | Impact |
|-------|:-------------:|:------:|
| relationships | 17 (static) | ~1KB |
| connection_permission_types | 6 (static) | ~1KB |
| connection_invites | ~10K | ~1MB |
| connection_permissions | 6 per connection | ~300KB |
| invite_notifications | ~30K | ~3MB |

---

## 3. Service Impact Matrix

| Service | Impact | Reason |
|---------|:------:|--------|
| user-service | 🟡 MEDIUM | Entities, repos, services |
| api-gateway-service | 🟢 LOW | REST handlers only |
| schedule-service | 🟢 LOW | Notification tasks |

---

## 4. SOS Feature Compatibility

| SOS Function | Status | Notes |
|--------------|:------:|-------|
| Create contact | ✅ | contact_type='emergency' |
| List contacts | ✅ | WHERE is_active=TRUE |
| SOS notification | ✅ | Uses sos_notifications |
| Escalation | ✅ | No change |

**Zero breaking changes to SOS!**

---

## 5. Business Rules Coverage

| BR | Implementation | ✅ |
|----|----------------|:--:|
| BR-001 | invite_type column | ✅ |
| BR-004 | invite_notifications.retry_count | ✅ |
| BR-006 | chk_no_self_invite | ✅ |
| BR-007 | idx_unique_pending_invite | ✅ |
| BR-009 | trigger_create_default_permissions | ✅ |
| BR-028 | relationship_code FK | ✅ |

---

## 6. Risk Reduction

| Risk | Before | After |
|------|:------:|:-----:|
| Schema duplication | 🔴 HIGH | 🟢 LOW |
| SOS regression | 🟡 MEDIUM | 🟢 NONE |
| Maintenance cost | 🟡 MEDIUM | 🟢 LOW |

---

## 7. v2.13 Changes: Patient BP Thresholds in Chart API

> **Added:** 2026-01-30  
> **Feature:** Include patient's BP target thresholds in Blood Pressure Chart API response

### 7.1 Impact Level: 🟢 LOW

| Factor | Impact |
|--------|:------:|
| Services affected | 2 (user-service, api-gateway) |
| Database changes | 0 (READ from existing `health_profile`) |
| Proto changes | 1 message added |
| API breaking changes | 0 (additive only) |

### 7.2 Changes Made

| Layer | File | Change |
|-------|------|--------|
| **Proto** | `connection_service.proto` | Added `PatientTargetThresholds` message |
| **Service** | `DashboardServiceImpl.java` | Query thresholds from `health_profile` |
| **gRPC** | `ConnectionServiceGrpcImpl.java` | Map thresholds to response |
| **Swagger** | `connection-management.yaml` | Added `PatientTargetThresholds` schema |
| **Frontend** | `BloodPressureChartBlock.tsx` | Use API thresholds instead of props |

### 7.3 Database Query (READ-only)

```sql
SELECT systolic_threshold_lower, systolic_threshold_upper,
       diastolic_threshold_lower, diastolic_threshold_upper
FROM health_profile 
WHERE user_id = {patient_id}
```

### 7.4 Business Rule

| Rule | Description |
|------|-------------|
| BR-CHART-001 | Display patient's own thresholds, not caregiver's |

### 7.5 Risk Assessment

| Risk | Level | Mitigation |
|------|:-----:|------------|
| Null thresholds | 🟢 LOW | Frontend handles nullable field |
| Performance | 🟢 LOW | Parallel query with measurements |
| Cross-context bug | ✅ FIXED | Thresholds from API, not Redux |
