# Implementation Recommendations

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Date** | 2026-01-26 |

---

## 1. Recommended Implementation Approach

### 1.1 Phased Delivery Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SOS FEATURE DELIVERY PHASES                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PHASE 1: Core SOS (Week 1-3)                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ ✅ SOS activation + countdown                                  │  │
│  │ ✅ ZNS/SMS sending (to health profile emergency contact)      │  │
│  │ ✅ Call 115 integration                                        │  │
│  │ ✅ Hospital map                                                │  │
│  │ ✅ First aid guide                                             │  │
│  │ ✅ Offline queue                                               │  │
│  │ ❌ No escalation (deferred)                                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  PHASE 2: Contact Management (Week 4)                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ ✅ Emergency contacts CRUD                                     │  │
│  │ ✅ ZNS to ALL contacts                                         │  │
│  │ ✅ Contact list screen                                         │  │
│  │ ❌ Auto-escalation (deferred or simplified)                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  PHASE 3: Full Escalation (Week 5-6)                                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ ✅ Push notification escalation                                │  │
│  │ ✅ Manual call tracking                                        │  │
│  │ ⚠️ Auto-call (if technically feasible)                        │  │
│  │ ✅ CSKH integration                                            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Feature Flag Configuration

```yaml
# Feature flags for controlled rollout
feature_flags:
  # Master switch
  sos_feature_enabled: true
  
  # Phase 1
  sos_countdown_enabled: true
  sos_115_call_enabled: true
  sos_hospital_map_enabled: true
  sos_first_aid_enabled: true
  sos_offline_queue_enabled: true
  
  # Phase 2
  sos_multi_contacts_enabled: false  # Enable when contacts ready
  sos_zns_enabled: false             # Enable when OA approved
  sos_sms_fallback_enabled: true     # SMS backup
  
  # Phase 3
  sos_escalation_enabled: false      # Enable when tested
  sos_auto_call_enabled: false       # May stay disabled
  sos_cskh_integration_enabled: false
```

---

## 2. Technical Recommendations

### 2.1 Architecture Decisions

| Decision | Recommendation | Rationale |
|----------|----------------|-----------|
| **Countdown sync** | Server as source of truth | Avoid client/server drift |
| **ZNS sending** | Async via Celery | Don't block API response |
| **Escalation calls** | Push notification approach | Avoid complex call automation |
| **Offline queue** | SQLite on mobile | Persistent, reliable |
| **Location storage** | Store with event | Immutable at trigger time |

### 2.2 API Design Recommendations

| Endpoint | Recommendation |
|----------|----------------|
| `POST /sos/activate` | Return immediately, process async |
| `GET /sos/status` | Support polling for countdown sync |
| `POST /sos/cancel` | Idempotent, handle race conditions |
| Contacts API | Separate from SOS activation path |

### 2.3 Database Recommendations

| Recommendation | Details |
|----------------|---------|
| Partition SOS events | Monthly partitions, 90-day retention |
| Denormalize contact info | Store name/phone in notifications for audit |
| Use JSONB for device_info | Flexible metadata storage |
| Add audit triggers | Track all state changes |

### 2.4 Mobile Recommendations

| Recommendation | Details |
|----------------|---------|
| Use native calls | `tel:115` scheme for reliability |
| Cache first aid | Background sync on install |
| Queue locally | SQLite with retry logic |
| Handle all states | Include all error screens |

---

## 3. Development Team Recommendations

### 3.1 Team Structure

| Role | Count | Responsibilities |
|------|:-----:|------------------|
| Backend Dev (Vert.x) | 1 | api-gateway, user-service |
| Backend Dev (Python) | 1 | schedule-service, ZNS client |
| Mobile Dev | 1-2 | All mobile screens + integration |
| QA | 1 | Test automation + manual testing |

### 3.2 Sprint Planning

| Sprint | Deliverables | Team Focus |
|--------|--------------|------------|
| Sprint 1 (Week 1-2) | DB migration, API stubs, Mobile UI | Foundation |
| Sprint 2 (Week 3-4) | ZNS integration, Contact mgmt | Integration |
| Sprint 3 (Week 5-6) | Escalation, E2E testing, Polish | Completion |

### 3.3 Definition of Done

- [ ] Code reviewed and approved
- [ ] Unit tests passing (>80% coverage for new code)
- [ ] Integration tests passing
- [ ] API documentation updated
- [ ] Feature flag configured
- [ ] Monitoring/logging in place
- [ ] Rollback tested

---

## 4. Testing Recommendations

### 4.1 Test Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SOS TESTING PYRAMID                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                        ┌─────────┐                                   │
│                       /   E2E    \          ~15 tests               │
│                      /   Tests    \         (Slower)                │
│                     ├─────────────┤                                  │
│                    /  Integration  \        ~30 tests               │
│                   /     Tests       \       (Medium)                │
│                  ├───────────────────┤                               │
│                 /     Unit Tests      \     ~100 tests              │
│                /                       \    (Fast)                  │
│               └─────────────────────────┘                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Critical Test Scenarios

| Scenario | Type | Priority |
|----------|:----:|:--------:|
| SOS activation happy path | E2E | 🔴 P0 |
| SOS cancellation | E2E | 🔴 P0 |
| ZNS delivery success | Integration | 🔴 P0 |
| ZNS retry on failure | Integration | 🔴 P0 |
| Offline SOS + sync | E2E | 🔴 P0 |
| Cooldown enforcement | Integration | 🟡 P1 |
| Low battery countdown | Integration | 🟡 P1 |
| Contact CRUD | Integration | 🟡 P1 |
| Hospital map display | E2E | 🟡 P1 |
| First aid content sync | Integration | 🟢 P2 |

### 4.3 Test Environment Requirements

| Environment | Purpose | ZNS Mode |
|-------------|---------|:--------:|
| Local | Development | Mock |
| Dev | Integration testing | Sandbox |
| Staging | Pre-production | Sandbox |
| Production | Live | Production |

---

## 5. Deployment Recommendations

### 5.1 Deployment Order

```
1. Database migrations (all tables)
     ↓
2. schedule-service (new tasks)
     ↓
3. user-service (new gRPC methods)
     ↓
4. api-gateway (new endpoints)
     ↓
5. Mobile app update
     ↓
6. Enable feature flags
```

### 5.2 Rollout Strategy

| Phase | Target | Criteria |
|-------|--------|----------|
| Alpha | Internal team | Functional testing |
| Beta | 5% users | Stability monitoring |
| Staged | 25% → 50% → 100% | Error rate <0.1% |

### 5.3 Monitoring During Rollout

| Metric | Alert Threshold |
|--------|-----------------|
| API error rate | >1% |
| ZNS failure rate | >5% |
| Response time P99 | >3s |
| SOS completion rate | <95% |

---

## 6. Post-Launch Recommendations

### 6.1 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| SOS completion rate | >99% | Events completed/activated |
| Alert delivery rate | >95% | ZNS delivered/sent |
| Time to first contact | <60s | Avg escalation response |
| User satisfaction | >4.0/5 | Post-SOS survey |

### 6.2 Iteration Areas

| Area | Potential Enhancement |
|------|----------------------|
| Escalation | Add auto-call if technically viable |
| Contact sync | Integrate with "Kết nối người thân" |
| Analytics | Add SOS usage dashboard |
| ML/AI | Anomaly detection for abuse |

---

## 7. Summary Checklist

### Pre-Development
- [ ] Confirm "Kết nối người thân" timeline
- [ ] Initiate ZNS OA approval
- [ ] Apply for iOS Critical Alerts
- [ ] Define CSKH API contract

### During Development
- [ ] Follow phased approach
- [ ] Implement feature flags
- [ ] Build with fallbacks
- [ ] Write comprehensive tests

### Pre-Launch
- [ ] Load test ZNS integration
- [ ] Test all offline scenarios
- [ ] Validate feature flags
- [ ] Prepare rollback plan

### Post-Launch
- [ ] Monitor success metrics
- [ ] Collect user feedback
- [ ] Iterate on escalation
- [ ] Plan Phase 2 features

---

## Next Phase

✅ **Phase 7: Implementation Recommendations** - COMPLETE

➡️ **Phase 8: Executive Summary & Complete Report**
