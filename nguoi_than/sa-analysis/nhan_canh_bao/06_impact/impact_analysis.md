# Impact Analysis: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 6 - Impact Analysis  
> **Date:** 2026-02-02

---

## Impact Level: 🟡 MEDIUM-HIGH

**Criteria:** 4-5 services affected, 2 new tables, no breaking changes

---

## Service Impact Summary

| Service | Impact | Changes | Breaking? |
|---------|:------:|:-------:|:---------:|
| schedule-service | 🔴 HIGH | +12 files, core trigger logic | No |
| Mobile App | 🔴 HIGH | +15 files, 4 new screens | No |
| user-service | 🟡 MEDIUM | +14 files, gRPC service + BP delta | No |
| api-gateway-service | 🟡 MEDIUM | +8 files, new endpoints | No |

---

## Detailed Impact Analysis

### schedule-service (🔴 HIGH)

**Scope:** Core of trigger evaluation and push dispatch

| Category | Impact |
|----------|--------|
| **New Files** | 12 |
| **Modified Files** | 4 |
| **New Celery Tasks** | 4 |
| **New Kafka Consumer** | 1 |
| **New Services** | 2 (Debounce, PushNotification extension) |

**Key Changes:**
1. Alert trigger evaluation engine
2. Debounce service (Redis-based)
3. FCM push dispatcher for alerts
4. Batch 21:00 compliance evaluator
5. Kafka consumer for trigger events

**Risk:** High complexity, requires careful design

---

### Mobile App (🔴 HIGH)

**Scope:** 4 new screens, push handling, navigation

| Category | Impact |
|----------|--------|
| **New Screens** | 2 (AlertHistoryScreen, SOSDetailScreen) |
| **New Components** | 4 (AlertBlock, AlertCard, AlertModal, SOSModal) |
| **Modified Files** | 6 (Dashboard, DeepLinkHandler, PushHandler, Navigation) |
| **New Services** | 1 (alert.service.ts) |
| **New Stores** | 1 (alertStore.ts) |

**Key Changes:**
1. Alert Block on Dashboard (max 5 cards)
2. Alert History with filter/pagination
3. In-app modal for foreground alerts
4. SOS modal with "Gọi ngay" button
5. Deep link handling for all alert types

**Risk:** UI complexity, state management

---

### user-service (🟡 MEDIUM)

**Scope:** Alert storage and history API

| Category | Impact |
|----------|--------|
| **New Proto** | 1 (alert_service.proto) |
| **New Entities** | 2 (CaregiverAlert, AlertType) |
| **New Repositories** | 2 |
| **New Services** | 2 (AlertService, BPDeltaEvaluator) |
| **New Handler** | 1 (AlertServiceGrpcImpl) |
| **New Tables** | 2 |

**Key Changes:**
1. Alert CRUD operations
2. History pagination with filters
3. Mark as read (single/all)
4. Unread count for badge
5. **BP delta calculation** (delta vs 7-day avg) when saving BP record
6. **Kafka producer** for alert triggers

**Risk:** Moderate - includes trigger logic previously considered for agents-service

---

### api-gateway-service (🟡 MEDIUM)

**Scope:** REST API for alert management

| Category | Impact |
|----------|--------|
| **New Handler** | 1 (AlertHandler) |
| **New Client** | 1 (AlertServiceClient) |
| **New DTOs** | 5 |
| **Modified** | RouteConfig, Swagger |

**Key Changes:**
1. 6 new REST endpoints
2. gRPC client for alert service
3. Swagger documentation

**Risk:** Standard thin gateway pattern

---

## Database Impact

### New Tables

| Table | Rows (Est.) | Growth | Partition? |
|-------|:-----------:|:------:|:----------:|
| caregiver_alerts | 450,000 | 5,000/day | Consider |
| caregiver_alert_types | 8 (static) | None | No |

### Modified Tables

None - all changes are additive

### Breaking Changes

None

---

## API Impact

### New Endpoints

| Endpoint | Method | Impact |
|----------|:------:|--------|
| /api/v1/alerts | GET | New |
| /api/v1/patients/{id}/alerts | GET | New |
| /api/v1/alerts/{id} | GET | New |
| /api/v1/alerts/mark-read | POST | New |
| /api/v1/alerts/mark-all-read | POST | New |
| /api/v1/alerts/unread-count | GET | New |

### Breaking Changes

None - all new endpoints

---

## Integration Impact

### Kafka Topics

| Topic | Direction | Status |
|-------|:---------:|--------|
| topic-alert-triggers | NEW | Create |
| topic-alert-dispatched | NEW | Create |

### Existing Features Affected

| Feature | Impact | Change Type |
|---------|--------|-------------|
| Dashboard (Caregiver) | Add Alert Block | Extension |
| BP Recording | Emit trigger event via user-service | Extension |
| Medication Reporting | Emit wrong dose event via user-service | Extension |
| SOS | Subscribe to events | Extension |
| Connection | Read permissions | Read-only |

---

## Timeline Impact

### Dependencies

```
Connection Feature (US 1.1) ─────────────────────────────┐
                                                         │
BP Feature ──────────────────┬───────────────────────────┤
                             │                           │
Medication Feature ──────────┼───────────────────────────┤
                             │                           │
SOS Feature ─────────────────┤                           ▼
                             ▼                   Alert Feature (US 1.2)
                      Trigger Events ──────────► schedule-service
                                                         │
                                                         ▼
                                                    Push + Store
```

### Critical Path

1. Connection feature deployed (Permission #2)
2. schedule-service alert trigger framework
3. user-service alert storage
4. Mobile UI components
5. Integration testing

---

## Rollback Strategy

### Feature Flags

| Flag | Default | Purpose |
|------|:-------:|---------|
| `alerts.enabled` | false | Master switch |
| `alerts.sos.enabled` | true | SOS alerts only |
| `alerts.push.enabled` | true | Push notifications |
| `alerts.batch.enabled` | true | 21:00 batch |

### Rollback Steps

1. Set `alerts.enabled = false` in config
2. Stop Kafka consumer for alerts
3. Mobile app gracefully handles disabled state
4. Data preserved for re-enable
