# Feasibility Report: US 1.3 - Gửi Lời Động Viên

> **Phase:** 5 - Feasibility Assessment  
> **Date:** 2026-02-04  
> **Source:** SA Analysis Workflow

---

## Executive Summary

| Attribute | Value |
|-----------|-------|
| **Feasibility Score** | 85/100 |
| **Status** | ✅ FEASIBLE |
| **Estimated Effort** | 54 hours |
| **Risk Level** | 🟡 MEDIUM |
| **Recommendation** | Proceed with implementation |

---

## Technical Feasibility Matrix

| Criteria | Weight | Score (1-5) | Weighted | Notes |
|----------|:------:|:-----------:|:--------:|-------|
| Architecture Fit | 25% | 5 | 1.25 | Fits microservices pattern perfectly |
| Database Compatibility | 20% | 4 | 0.80 | 1 new table, reuses existing schema |
| API/gRPC Compatibility | 15% | 5 | 0.75 | Standard REST/gRPC patterns |
| Service Boundary Clarity | 15% | 4 | 0.60 | Clear separation of concerns |
| Technology Stack Match | 10% | 5 | 0.50 | All existing tech stacks |
| Team Expertise | 10% | 4 | 0.40 | Familiar patterns |
| Time/Resource Estimate | 5% | 4 | 0.20 | 54 hours reasonable |
| **Total** | **100%** | | **4.50** | **90/100** |

**Final Score:** 85/100 (adjusted for complexity factors)

---

## Feasibility by Service

### user-service ✅

| Factor | Assessment |
|--------|------------|
| **Existing Patterns** | Follows ConnectionService patterns |
| **Proto Integration** | Standard gRPC method definition |
| **Database Access** | Dedicated repository pattern |
| **Permission Check** | Reuses PermissionType.ENCOURAGEMENT |
| **Quota Logic** | Simple date-based counting |

**Complexity:** MEDIUM  
**Risk:** LOW  
**Confidence:** HIGH

---

### api-gateway-service ✅

| Factor | Assessment |
|--------|------------|
| **Routing** | Standard REST endpoints |
| **gRPC Client** | Follows existing patterns |
| **DTO Mapping** | Proto ↔ JSON conversion |
| **Authentication** | Existing JWT middleware |

**Complexity:** LOW  
**Risk:** LOW  
**Confidence:** HIGH

---

### agents-service [⏸️ DEFERRED]

> **Status:** AI Suggestions deferred to future release

---

### schedule-service ✅

| Factor | Assessment |
|--------|------------|
| **Kafka Consumer** | Existing consumer patterns |
| **Push Notification** | Existing push service |
| **Task Pattern** | Standard Celery task |

**Complexity:** LOW  
**Risk:** LOW  
**Confidence:** HIGH

---

### Mobile App ✅

| Factor | Assessment |
|--------|------------|
| **Widget Pattern** | Fits existing dashboard layout |
| **Modal Pattern** | Existing modal components |
| **State Management** | Standard Zustand store |
| **API Integration** | Standard service pattern |

**Complexity:** MEDIUM  
**Risk:** LOW  
**Confidence:** HIGH

---

## Component Reuse Assessment

| Component | Reuse Level | Description |
|-----------|:-----------:|-------------|
| PermissionType.ENCOURAGEMENT | 100% | Exists in code and DB |
| connection_permission_types | 100% | Permission #6 seeded |
| PushNotificationService | 90% | Add new template |
| CaregiverModal | 70% | Adapt existing modal |

---

## Database Feasibility

### New Table Assessment

| Aspect | Assessment | Notes |
|--------|:----------:|-------|
| Schema Design | ✅ | Simple, normalized with denormalization for display |
| FK Integrity | ✅ | Uses existing users, contacts tables |
| Index Strategy | ✅ | Optimized for quota and list queries |
| Data Volume | ✅ | ~30K rows/day, 90-day retention manageable |

### Migration Risk

| Risk | Level | Mitigation |
|------|:-----:|------------|
| Table Creation | LOW | Additive change, no alter |
| FK References | LOW | Uses existing tables |
| Index Creation | LOW | Async index build |

---

## Integration Feasibility

### Permission Check Flow

```
✅ VERIFIED: Permission #6 (encouragement) exists
   - Database: connection_permission_types ✓
   - Code: PermissionType.ENCOURAGEMENT ✓
   - Default: Enabled for new connections ✓
```

### Kafka Integration

```
✅ VERIFIED: Kafka topology available
   - topic-encouragement-created: New topic needed
   - Consumer pattern in schedule-service ✓
```

### Push Notification Flow

```
✅ VERIFIED: Push infrastructure ready
   - FCM integration ✓
   - Template engine ✓
   - Retry mechanism ✓
```

---

## Risks Identified

| Risk | Probability | Impact | Mitigation |
|------|:-----------:|:------:|------------|
| Push Failure | LOW | MEDIUM | Retry queue |
| Permission Race | LOW | LOW | Real-time check |
| Quota Bypass | LOW | LOW | Server-side enforcement |

---

## Recommendations

### ✅ PROCEED WITH IMPLEMENTATION

1. **Phase Ordering:**
   - P1: Database migration (2h)
   - P2: user-service proto + entity (8h)
   - P3: user-service logic + tests (14h)
   - P4: api-gateway endpoints (10h)
   - P5: schedule-service push (4h)
   - P6: Mobile implementation (16h)

2. **Critical Path:**
   - Database → user-service → api-gateway → Mobile
   - schedule-service can be developed in parallel

3. **Quality Gates:**
   - Unit tests for quota logic
   - Integration test for permission check
   - E2E test for full send flow

---

## Approval

| Reviewer | Status | Date |
|----------|:------:|------|
| SA Lead | ⏳ Pending | - |
| Tech Lead | ⏳ Pending | - |
| Product Owner | ⏳ Pending | - |

---

## Next Steps

➡️ Proceed to Phase 6: Impact Analysis
