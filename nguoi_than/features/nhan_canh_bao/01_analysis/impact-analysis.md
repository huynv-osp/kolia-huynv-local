# Impact Analysis: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 3 - Impact Analysis  
> **Date:** 2026-02-02

---

## 1. Service Impact Summary

| Service | Impact | Files | Effort |
|---------|:------:|:-----:|:------:|
| user-service | 🟡 MEDIUM | ~14 | 36h |
| api-gateway | 🟡 MEDIUM | ~8 | 12h |
| schedule-service | 🔴 HIGH | ~12 | 40h |
| Mobile App | 🔴 HIGH | ~15 | 48h |
| **Total** | | **~49** | **132h** |

---

## 2. Database Impact

| Table | Change | Rows (90 days) |
|-------|:------:|:--------------:|
| caregiver_alerts | CREATE | ~450,000 |
| caregiver_alert_types | CREATE | 4 (static) |

**Indexes:** 7 new indexes including debounce constraint

---

## 3. API Impact

### New Endpoints

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connections/alerts` | List alerts |
| GET | `/api/v1/connections/alerts/{id}` | Alert detail |
| POST | `/api/v1/connections/alerts/mark-read` | Mark as read |
| POST | `/api/v1/connections/alerts/mark-all-read` | Mark all |
| GET | `/api/v1/connections/alerts/unread-count` | Badge count |
| GET | `/api/v1/connections/alerts/types` | Alert categories |

### New gRPC Methods

- `CreateAlert`, `GetAlertHistory`, `GetAlertDetail`
- `MarkAlertAsRead`, `MarkAllAlertsAsRead`, `GetUnreadCount`

---

## 4. Breaking Changes

❌ **None** - Feature additive only

---

## 5. Risks

| Risk | Level | Mitigation |
|------|:-----:|------------|
| Push SLA ≤5s breach | 🔴 HIGH | FCM high priority, monitoring |
| Debounce state loss | 🔴 HIGH | Redis + DB constraint |
| 7-day avg performance | 🟡 MEDIUM | Redis cache |

---

## 6. Complexity Score

| Factor | Weight | Score |
|--------|:------:|:-----:|
| Services affected (4) | 25% | 3 |
| Database changes | 20% | 3 |
| New API endpoints (6) | 15% | 3 |
| Business logic | 20% | 4 |
| Integration | 10% | 3 |
| Testing | 10% | 3 |
| **Total** | | **19/30 (Complex)** |

---

## Next Phase

➡️ [02_planning/service-decomposition.md](../02_planning/service-decomposition.md)
