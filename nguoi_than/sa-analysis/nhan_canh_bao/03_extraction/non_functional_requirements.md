# Non-Functional Requirements: US 1.2 - Nhận Cảnh Báo

> **Phase:** 3 - Requirements Extraction  
> **Date:** 2026-02-02

---

## Performance Requirements

| ID | Metric | Target | Priority |
|----|--------|--------|:--------:|
| PERF-001 | Alert Delivery (real-time) | ≤ 5 seconds from event | P0 |
| PERF-002 | Badge Update | ≤ 10 seconds | P1 |
| PERF-003 | History Load (20 items) | ≤ 1 second | P1 |
| PERF-004 | Filter Response | Real-time (< 200ms) | P2 |

---

## Security Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| SEC-01 | PII hidden on lock screen | P0 |
| SEC-02 | Deeplink requires valid session | P0 |
| SEC-03 | Only caregivers with Permission #2 can view history | P1 |
| SEC-04 | Data encryption at rest and in transit | P0 |

---

## Availability Requirements

| ID | Metric | Target |
|----|--------|--------|
| AVAIL-001 | Push Service Uptime | 99.9% |
| AVAIL-002 | Fallback (Phase 2) | ZNS → SMS if Push fails |

---

## Scalability Requirements

| ID | Metric | Target |
|----|--------|--------|
| SCALE-001 | Concurrent alerts | 10,000/minute |
| SCALE-002 | History records | 450,000 active (90-day) |
| SCALE-003 | Daily new alerts | ~5,000 rows |

---

## Reliability Requirements

| ID | Requirement | Implementation |
|----|-------------|----------------|
| REL-001 | At-least-once delivery | Kafka consumer with manual commit |
| REL-002 | Retry mechanism | Max 3 retries for failed push |
| REL-003 | Idempotency | Debounce index + unique constraint |

---

## Maintainability Requirements

| ID | Requirement | Implementation |
|----|-------------|----------------|
| MAINT-001 | Audit logging | Log all alert triggers |
| MAINT-002 | Configurable thresholds | DB-driven or config file |
| MAINT-003 | Feature flags | Toggle new alert types |

---

## Compliance Requirements

| ID | Requirement | Standard |
|----|-------------|----------|
| COMP-001 | Data retention | 90 days per BR-ALT-009 |
| COMP-002 | User consent | Permission #2 opt-in |
| COMP-003 | Timezone handling | Patient's timezone (BR-ALT-011) |
