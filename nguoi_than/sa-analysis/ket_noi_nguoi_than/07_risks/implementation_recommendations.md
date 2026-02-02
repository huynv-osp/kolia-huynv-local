# Implementation Recommendations: KOLIA-1517 - Kết nối Người thân

> **Phase:** 7 - Technical Risks & Recommendations  
> **Date:** 2026-01-28

---

## 1. Implementation Strategy

### Recommended Approach: Phased Rollout

```
Phase 1 (Week 1-2): Core Foundation
├── Database migration
├── Entities & Repositories
├── gRPC service implementation
└── Gateway handlers

Phase 2 (Week 3): Permissions & Notifications
├── Permission service
├── Kafka events
└── Celery notification tasks

Phase 3 (Week 4): Testing & Polish
├── Unit tests
├── Integration tests
└── UAT
```

---

## 2. Technical Recommendations

### 2.1 Database

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Use partial indexes | HIGH | Optimize pending/active queries |
| Auto-create permissions via trigger | HIGH | Ensure 6 perms always exist |
| Soft delete for connections | MEDIUM | Preserve audit trail |
| JSONB for initial_permissions | MEDIUM | Flexibility for future changes |

### 2.2 Service Layer

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Transactional accept flow | HIGH | Ensure atomicity |
| Event sourcing for state changes | MEDIUM | Audit trail, debugging |
| Idempotent invite creation | HIGH | Handle retries |
| Permission caching | LOW | Performance (defer to Phase 2) |

### 2.3 API Design

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Separate invite/connection endpoints | HIGH | Clear resource separation |
| Group connections by role | HIGH | Better mobile UX |
| Include last_active in response | MEDIUM | Reduce additional calls |
| Use ETags for permissions | LOW | Optimistic locking |

### 2.4 Notifications

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Implement retry logic first | HIGH | BR-004 requirement |
| Track delivery status | HIGH | Debugging, metrics |
| Abstract notification channel | MEDIUM | Easy to add channels |
| Rate limit per user | MEDIUM | Prevent spam |

---

## 3. Testing Strategy

| Test Type | Coverage Target | Focus Area |
|-----------|:---------------:|------------|
| Unit Tests | >80% | Business logic, validation |
| Integration Tests | Core flows | End-to-end invite/accept |
| Load Tests | 100 concurrent | Permission updates |
| Security Tests | Auth/authz | User can only modify own data |

---

## 4. Monitoring Recommendations

| Metric | Alert Threshold | Action |
|--------|:---------------:|--------|
| Invite creation rate | >100/min | Investigate potential abuse |
| ZNS failure rate | >10% | Check ZNS service |
| Accept latency (p95) | >500ms | Optimize query |
| Orphan invites | >100 | Review expiration logic |

---

## 5. Documentation Requirements

| Document | Owner | Due |
|----------|-------|-----|
| API Documentation (Swagger) | Gateway Team | Week 2 |
| Proto Documentation | Backend Team | Week 2 |
| User Guide | PM | Week 4 |
| Runbook | DevOps | Week 4 |

---

## 6. Action Items Before Start

| # | Action | Owner | Due |
|---|--------|-------|-----|
| 1 | Submit ZNS templates for approval | DevOps | Day 1 |
| 2 | Verify deep link infrastructure | Mobile | Week 1 |
| 3 | Create DB migration PR | Backend | Day 2 |
| 4 | Allocate Kafka topics | DevOps | Day 1 |
| 5 | Set up feature flag | Backend | Day 1 |
