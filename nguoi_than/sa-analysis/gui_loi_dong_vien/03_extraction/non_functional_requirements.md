# Non-Functional Requirements: US 1.3 - Gửi Lời Động Viên

> **Phase:** 3 - Functional Requirements Extraction  
> **Date:** 2026-02-04  
> **Source:** SRS v1.3

---

## Performance Requirements

| ID | Requirement | Target | Measurement |
|:--:|-------------|:------:|-------------|
| NFR-001 | ~~AI Suggestions response time~~ | ⏸️ DEFERRED | - |
| NFR-002 | Create message response time | ≤ 500ms | 95th percentile |
| NFR-003 | List messages response time | ≤ 300ms | 95th percentile |
| NFR-004 | Push notification delivery | ≤ 5 seconds | After create success |
| ~~NFR-005~~ | ~~AI suggestion timeout~~ | ⏸️ DEFERRED | - |

---

## Scalability Requirements

| ID | Requirement | Target | Notes |
|:--:|-------------|:------:|-------|
| SCA-001 | Daily messages volume | 50,000 msgs/day | Based on 5,000 active connections |
| SCA-002 | Concurrent users | 1,000 | Widget access |

---

## Availability Requirements

| ID | Requirement | Target | Notes |
|:--:|-------------|:------:|-------|
| AVA-001 | System uptime | 99.9% | Core messaging function |
| AVA-002 | Database availability | 99.99% | Via PostgreSQL replication |

---

## Security Requirements

| ID | Requirement | Implementation | Priority |
|:--:|-------------|----------------|:--------:|
| SEC-001 | TLS encryption | TLS 1.3 for all API calls | P0 |
| SEC-002 | JWT authentication | Bearer token validation | P0 |
| SEC-003 | Permission check | Real-time check before action | P0 |
| SEC-004 | XSS protection | Sanitize content before display | P1 |
| SEC-005 | Rate limiting | 60 req/min per user | P1 |
| SEC-006 | Input validation | Max 150 chars, no empty | P0 |

---

## Data Retention

| ID | Requirement | Value | Notes |
|:--:|-------------|:-----:|-------|
| RET-001 | Message retention | 90 days | After creation |
| RET-002 | Modal display window | 24 hours | Unread only |
| RET-003 | Quota reset frequency | Daily | 00:00 UTC+7 |

---

## Reliability Requirements

| ID | Requirement | Implementation |
|:--:|-------------|----------------|
| REL-001 | Network retry | Pull-to-refresh + manual retry |
| REL-002 | Push delivery retry | schedule-service retry queue |
| REL-003 | Database transaction | ACID compliance |

---

## Usability Requirements

| ID | Requirement | Target |
|:--:|-------------|--------|
| USA-001 | Character counter | Real-time update |
| USA-002 | Chip tap-to-fill | Single tap fills input |
| USA-003 | Success feedback | Toast notification |
| USA-004 | Error messaging | Actionable error text |

---

## Monitoring & Observability

| Metric | Type | Alert Threshold |
|--------|:----:|-----------------|
| Send success rate | Counter | < 99% |
| Permission denials | Counter | Spike > 100/5min |
| Quota exhaustion rate | Gauge | > 50% users/day |
| Push delivery success | Counter | < 98% |

---

## Next Steps

➡️ Proceed to Phase 4: Architecture Mapping & Analysis
