# Risk Register: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 7 - Risk Analysis  
> **Date:** 2026-02-02

---

## Risk Summary

| Level | Count |
|:-----:|:-----:|
| 🔴 HIGH | 2 |
| 🟡 MEDIUM | 4 |
| 🟢 LOW | 3 |

---

## High Risks

### RISK-001: Real-time Push Delivery SLA Breach

| Attribute | Value |
|-----------|-------|
| **Category** | Performance |
| **Probability** | Medium (40%) |
| **Impact** | High |
| **Risk Score** | 🔴 HIGH |

**Description:**
SRS requires ≤5 second push delivery for critical alerts (SOS, BP Critical). FCM infrastructure may have latency spikes, especially during peak hours.

**Mitigation:**
1. Use FCM high-priority channel with `apns-priority: 10`
2. Monitor P95 latency with alerting threshold at 3s
3. Optimize trigger-to-dispatch path (remove unnecessary DB calls)
4. Pre-compute caregiver list to avoid JOIN on hot path

**Owner:** schedule-service team  
**Status:** Open

---

### RISK-002: Debounce State Loss on Service Restart

| Attribute | Value |
|-----------|-------|
| **Category** | Reliability |
| **Probability** | Medium (30%) |
| **Impact** | Medium-High |
| **Risk Score** | 🔴 HIGH |

**Description:**
If Redis goes down or schedule-service restarts mid-window, debounce state is lost, potentially causing duplicate alerts.

**Mitigation:**
1. Redis persistence (RDB/AOF) enabled
2. Database-level UNIQUE constraint as secondary check
3. Add `duplicate = true` flag in payload for client-side dedup
4. Accept occasional duplicates (better than missed alerts)

**Owner:** schedule-service team  
**Status:** Open

---

## Medium Risks

### RISK-003: 7-day Average Calculation Performance

| Attribute | Value |
|-----------|-------|
| **Category** | Performance |
| **Probability** | Medium (35%) |
| **Impact** | Medium |
| **Risk Score** | 🟡 MEDIUM |

**Description:**
Calculating rolling 7-day average on every BP reading may cause latency if user has many readings.

**Mitigation:**
1. Cache last 7-day average in Redis with 1-hour TTL
2. Update cache incrementally on new reading
3. Use efficient SQL with proper indexes
4. Pre-compute during off-peak hours if needed

**Owner:** user-service team  
**Status:** Open

---

### RISK-004: Cross-Service Event Ordering

| Attribute | Value |
|-----------|-------|
| **Category** | Architecture |
| **Probability** | Low (20%) |
| **Impact** | High |
| **Risk Score** | 🟡 MEDIUM |

**Description:**
Alert trigger event may arrive at schedule-service before BP record is visible in user-service DB (eventual consistency).

**Mitigation:**
1. Include all necessary data in Kafka event payload
2. Use event-sourcing pattern (don't re-read from DB)
3. Add idempotency key to prevent duplicate processing

**Owner:** All service teams  
**Status:** Open

---

### RISK-005: Permission #2 Toggle Race Condition

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Probability** | Low (15%) |
| **Impact** | Medium |
| **Risk Score** | 🟡 MEDIUM |

**Description:**
Caregiver may toggle Permission #2 OFF while an alert is being processed, leading to unwanted notification.

**Mitigation:**
1. Re-check permission at dispatch time (just before FCM call)
2. Cache permission with short TTL (30 seconds)
3. Accept occasional false positive (user experience > strict correctness)

**Owner:** schedule-service team  
**Status:** Open

---

### RISK-006: Mobile Badge/Modal Synchronization

| Attribute | Value |
|-----------|-------|
| **Category** | UX |
| **Probability** | Medium (35%) |
| **Impact** | Low |
| **Risk Score** | 🟡 MEDIUM |

**Description:**
Badge count may desync if silent push fails or app is force-killed.

**Mitigation:**
1. Sync badge on app launch from API
2. Silent push with fallback to API polling
3. Mark-all-read recalculates true count

**Owner:** Mobile team  
**Status:** Open

---

## Low Risks

### RISK-007: 21:00 Batch Job Overload

| Attribute | Value |
|-----------|-------|
| **Category** | Performance |
| **Probability** | Low (15%) |
| **Impact** | Medium |
| **Risk Score** | 🟢 LOW |

**Description:**
All compliance evaluations run at 21:00 may cause temporary load spike.

**Mitigation:**
1. Spread batch over 21:00-21:30 window
2. Process in chunks with rate limiting
3. Use dedicated Celery worker pool

**Owner:** schedule-service team  
**Status:** Open

---

### RISK-008: Alert History Table Growth

| Attribute | Value |
|-----------|-------|
| **Category** | Operations |
| **Probability** | Medium (40%) |
| **Impact** | Low |
| **Risk Score** | 🟢 LOW |

**Description:**
caregiver_alerts table grows to ~450K rows in 90 days, may impact query performance.

**Mitigation:**
1. Proper indexes on common query patterns
2. Consider partitioning by month if volume exceeds estimate
3. Scheduled cleanup job for records > 90 days

**Owner:** DBA / user-service team  
**Status:** Open

---

### RISK-009: Deep Link Handling on Disconnected Patient

| Attribute | Value |
|-----------|-------|
| **Category** | UX |
| **Probability** | Low (10%) |
| **Impact** | Low |
| **Risk Score** | 🟢 LOW |

**Description:**
Tapping old alert for disconnected patient may lead to "Access denied" or broken screen.

**Mitigation:**
1. Check connection status on navigation
2. Show "[Đã ngắt kết nối]" badge per EC-15
3. Disable navigation but keep alert visible for history

**Owner:** Mobile team  
**Status:** Open

---

## Risk Matrix

```
                    IMPACT
           Low      Medium     High
         ┌─────────┬──────────┬──────────┐
    High │         │          │          │
         ├─────────┼──────────┼──────────┤
PROBABILITY      
  Medium │ RISK-006│ RISK-003 │ RISK-001 │
         │ RISK-008│ RISK-004 │ RISK-002 │
         ├─────────┼──────────┼──────────┤
    Low  │ RISK-009│ RISK-005 │          │
         │         │ RISK-007 │          │
         └─────────┴──────────┴──────────┘
```

---

## Contingency Plans

### If Push SLA Fails (RISK-001)
1. Enable ZNS/SMS fallback (Phase 2 feature)
2. In-app pull-based refresh every 30 seconds when foreground
3. Alert user to check app history manually

### If Debounce Fails (RISK-002)
1. Client-side deduplication by alert_type + patient + 5min window
2. User can dismiss duplicate, no action needed
3. Monitor duplicate rate, rollback if excessive

### If Batch Job Fails (RISK-007)
1. Automatic retry with exponential backoff
2. Manual trigger from admin panel
3. Alerts delayed to next day (compliance, not emergency)
