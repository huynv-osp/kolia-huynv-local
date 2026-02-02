# Feasibility Report: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 5 - Feasibility Assessment  
> **Date:** 2026-02-02  
> **Revision:** v1.5  
> **Source:** SRS-Nhận-Cảnh-Báo_v1.5

---

## Overall Assessment

### Feasibility Score: 87/100 ✅ FEASIBLE

> **Score improved from 85 → 87** với SRS v1.5:
> - Simplified BP logic (chỉ còn 1 rule, loại bỏ hoàn toàn hard thresholds)
> - Consolidated medication notifications (giảm complexity)
> - Display logic đơn giản: CAO/THẤP dựa vào delta sign

---

## Technical Feasibility Matrix

| Criteria | Weight | Score (1-5) | Weighted | Notes |
|----------|:------:|:-----------:|:--------:|-------|
| Architecture Fit | 25% | 4.4 | 22.0 | Simplified BP logic từ v1.4 |
| Database Compatibility | 20% | 4.0 | 16.0 | Extension of existing schema |
| API/gRPC Compatibility | 15% | 4.2 | 12.6 | Same patterns as Connection feature |
| Service Boundary Clarity | 15% | 4.2 | 12.6 | Cleaner with consolidated notifications |
| Technology Stack Match | 10% | 4.5 | 9.0 | All technologies available |
| Team Expertise | 10% | 3.8 | 7.6 | Requires cross-team coordination |
| Time/Resource Estimate | 5% | 4.0 | 4.0 | Reduced with simpler BP logic |
| **Total** | **100%** | | **83.8** | |

---

## Feasibility by Component

### ✅ Infrastructure (HIGH CONFIDENCE)

| Component | Status | Notes |
|-----------|:------:|-------|
| FCM Push | ✅ Ready | Already configured for medication reminders |
| Kafka | ✅ Ready | Used for connection events |
| Redis | ✅ Ready | Used for debounce/cache |
| PostgreSQL | ✅ Ready | Extension only |

### ✅ Architecture Patterns (HIGH CONFIDENCE)

| Pattern | Status | Notes |
|---------|:------:|-------|
| Event-driven notifications | ✅ Exists | Connection feature uses same pattern |
| gRPC service extension | ✅ Standard | Same as existing services |
| Thin gateway | ✅ Standard | ARCH-001 compliant |

### ⚠️ Complex Logic (MEDIUM → LOW CONFIDENCE with v1.4)

| Logic | Complexity | Risk Mitigation |
|-------|:----------:|-----------------|
| 7-day BP average + >10mmHg delta | Medium | Pre-compute in BP recording flow (BR-HA-017) |
| Debounce mechanism | Medium | Redis TTL with unique constraint |
| Batch 21:00 evaluation | Medium | Celery Beat scheduled task |
| ~~Priority resolution (Critical > Abnormal)~~ | ~~Low~~ | **Removed in v1.4** - chỉ còn 1 rule |
| Medication consolidation (BR-ALT-019) | Low | Simple count/group logic |

### ⚠️ Cross-Service Coordination (MEDIUM CONFIDENCE)

| Integration | Owner | Coordination Need |
|-------------|-------|-------------------|
| BP → Alert trigger | user-service | Calculate delta when saving BP, emit Kafka event |
| Medication events | user-service | Emit events on wrong dose |
| SOS events | schedule-service | Subscribe to existing topic |
| Push delivery | schedule-service | Extend FCM wrapper |

---

## Feasibility Concerns

### 1. Real-time Delivery SLA (PERF-001)

**Concern:** ≤5 second push delivery requirement

**Mitigation:**
- Use high-priority FCM channels
- Minimize processing in trigger flow
- Monitor latency with alerting

**Risk Level:** 🟡 Medium

---

### 2. 7-day Average Calculation Performance

**Concern:** Calculating rolling average on every BP reading

**Mitigation:**
- Cache last 7-day average in Redis
- Update cache incrementally on new reading
- Fallback to on-demand calculation

**Risk Level:** 🟢 Low

---

### 3. Debounce State Persistence

**Concern:** Debounce state loss on service restart

**Mitigation:**
- Use Redis with TTL (5 minutes)
- Database-level unique constraint as backup
- Accept potential duplicate on restart (rare)

**Risk Level:** 🟢 Low

---

### 4. Permission #2 Race Conditions

**Concern:** Permission changed during alert processing

**Mitigation:**
- Cache permission state per session
- Re-check at dispatch time
- Accept occasional false positive (user toggles during event)

**Risk Level:** 🟢 Low

---

## NOT FEASIBLE Items (Out of Scope)

| Feature | Reason | Alternative |
|---------|--------|-------------|
| Custom thresholds per caregiver | Scope increase | Phase 2 |
| Auto-dial on SOS | Platform restrictions | Manual "Gọi ngay" button |
| Custom ringtones | Platform complexity | Standard system sounds |
| ZNS/SMS fallback | Additional integration | Phase 2 |

---

## Dependencies Check

| Dependency | Status | Blocker? |
|------------|:------:|:--------:|
| SRS Đo Huyết áp | ✅ Available | No |
| SRS Uống thuốc MVP0.3 | ✅ Available | No |
| SRS SOS | ✅ Available | No |
| FCM configured | ✅ Available | No |
| Kafka configured | ✅ Available | No |
| Connection feature deployed | ⚠️ In progress | Partial |

---

## Recommendation

### ✅ PROCEED WITH IMPLEMENTATION

**Rationale:**
1. Core infrastructure exists and is proven
2. Architecture patterns match existing Connection feature
3. Complexity is manageable with proper design
4. No blocking dependencies

**Conditions:**
1. Connection feature (US 1.1) must be deployed first
2. schedule-service is primary owner for trigger logic
3. Phased approach recommended (MVP → Enhancement)
