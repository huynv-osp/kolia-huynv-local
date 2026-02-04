# Impact Analysis: US 1.3 - Gửi Lời Động Viên

> **Phase:** 6 - Impact Analysis  
> **Date:** 2026-02-04  
> **Impact Level:** 🟡 MEDIUM

---

## Summary

| Metric | Count |
|--------|:-----:|
| Services Affected | 4 |
| New Tables | 1 |
| Modified Tables | 0 |
| New API Endpoints | 4 |
| New gRPC Methods | 4 |
| Estimated Files | ~29 |
| Estimated Hours | 54 |

---

## Impact Level Assessment

| Criteria | Value | Level |
|----------|:-----:|:-----:|
| Services Affected | 4 | 🟡 |
| Database Tables | 1 NEW | 🟢 |
| Breaking Changes | 0 | 🟢 |
| Data Migration | None | 🟢 |
| External Dependencies | None | 🟢 |

**Overall Impact:** 🟡 MEDIUM

---

## Service Impact Details

### 1. user-service

| Impact Type | Details |
|-------------|---------|
| **New Files** | 12 files |
| **Modified Files** | 2 files (config, constants) |
| **Proto Changes** | New encouragement_service.proto |
| **Database** | 1 new table |
| **Kafka** | 1 new producer |

**Risk Assessment:**
- No breaking changes to existing services
- New module isolated from existing features
- Permission check reuses existing infrastructure

---

### 2. api-gateway-service

| Impact Type | Details |
|-------------|---------|
| **New Files** | 8 files |
| **Modified Files** | 1 file (RouteConfig.java) |
| **Route Changes** | 4 new routes |

**Risk Assessment:**
- Additive changes only
- No modification to existing handlers
- Standard routing pattern

---

### 3. agents-service [⏸️ DEFERRED]

> **Status:** AI Suggestions deferred to future release

---

### 4. schedule-service

| Impact Type | Details |
|-------------|---------|
| **New Files** | 3 files |
| **Modified Files** | 1 file (kafka_config.py) |
| **Kafka** | 1 new consumer |

**Risk Assessment:**
- New Kafka topic consumer
- Reuses existing push notification service
- Isolated task

---

### 5. Mobile App

| Impact Type | Details |
|-------------|---------|
| **New Files** | 6 files |
| **Modified Files** | 2 files (Dashboard, NavigationStack) |
| **UI Changes** | 1 widget, 1 modal |

**Risk Assessment:**
- New widget in existing Dashboard layout
- Modal pattern from existing components
- No breaking changes to navigation

---

## Database Impact

### New Table

| Table | Rows/Day | Retention | Size Estimate |
|-------|:--------:|:---------:|:-------------:|
| encouragement_messages | 30,000 | 90 days | ~500 MB |

### No Alterations Required

- ✅ users: No changes
- ✅ user_emergency_contacts: No changes
- ✅ connection_permissions: No changes
- ✅ connection_permission_types: Already has #6

---

## Kafka Topology Changes

### New Topic

| Topic | Partitions | Producers | Consumers |
|-------|:----------:|-----------|-----------|
| topic-encouragement-events | 3 | user-service | schedule-service |

---

## Breaking Changes

| Type | Description |
|------|-------------|
| API | ❌ None - All new endpoints |
| Database | ❌ None - Additive only |
| Proto | ❌ None - New service definition |
| Mobile | ❌ None - Additive UI |

---

## Rollback Strategy

### If Issues Detected

1. **Database:** DROP TABLE encouragement_messages
2. **Kafka:** Delete topic-encouragement-events
3. **Code:** Feature flag OFF (disable widget)
4. **Mobile:** OTA update to hide widget

### Feature Flag Plan

```yaml
feature_flags:
  encouragement_enabled:
    default: false
    production: false (until verified)
    staging: true
    
rollout_plan:
  - 10% → 25% → 50% → 100%
  - Monitor: error rate, latency, quota usage
```

---

## Cross-Feature Impact

| Feature | Impact | Notes |
|---------|:------:|-------|
| Kết nối Người thân | READ | Uses connection data |
| User Profile | READ | Uses patient name |
| Medication Schedule | READ | AI context (optional) |
| BP Schedule | READ | AI context (optional) |
| Push Notification | EXTEND | New template |

---

## Performance Impact

| Operation | Expected Load | SLA |
|-----------|:-------------:|:---:|
| Create Message | 5,000/day | 500ms |
| Get List (Patient) | 50,000/day | 300ms |
| Push Delivery | 5,000/day | 5s |

**Database Load:**
- INSERT: ~5K/day (low)
- SELECT: ~50K/day (moderate)
- UPDATE (mark read): ~5K/day (low)

---

## Monitoring Requirements

| Metric | Alert Threshold |
|--------|-----------------|
| Create Error Rate | > 1% |
| Push Failure Rate | > 5% |
| Avg Create Latency | > 1s |
| Quota Exhaustion | > 50% users |

---

## Testing Impact

### New Test Cases Required

| Type | Count | Priority |
|------|:-----:|:--------:|
| Unit Tests | 25 | P0 |
| Integration Tests | 10 | P0 |
| E2E Tests | 5 | P1 |
| Performance Tests | 3 | P2 |

### Test Scenarios

1. ✅ Permission granted → Send success
2. ✅ Permission denied → 403 error
3. ✅ Quota exceeded → 429 error
4. ✅ Content too long → 400 error
5. ✅ Push delivery → Patient receives
6. ✅ Mark as read → Batch update

---

## Next Steps

➡️ Proceed to Phase 7: Technical Risks & Recommendations
