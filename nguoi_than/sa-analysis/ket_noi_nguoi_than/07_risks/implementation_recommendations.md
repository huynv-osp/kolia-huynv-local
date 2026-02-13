# Implementation Recommendations: KOLIA-1517 - Kết nối Người thân

> **Phase:** 7 - Technical Risks & Recommendations  
> **Date:** 2026-02-13  
> **Revision:** v4.0 - Family Group model, 5-service architecture

---

## 1. Implementation Strategy

### Recommended Approach: Phased Rollout (5 Phases)

```
Phase 1 (Week 1-2): Core Foundation
├── Database migration (family_groups, family_group_members)
├── FamilyGroup entities & repositories (user-service)
├── FamilyGroupService (CRUD + membership)
├── PaymentServiceClient integration (slot check)
└── gRPC service implementation (new RPCs)

Phase 2 (Week 2-3): Invite & Connection Flow
├── Admin-only invite logic (BR-041)
├── Simplified invite form (phone only, BR-055)
├── Auto-connect on CG accept (BR-045)
├── Slot pre-check + consume (BR-033, BR-059)
└── Gateway handlers for new endpoints

Phase 3 (Week 3-4): Permissions & Soft Disconnect
├── Permission revoke/restore flow (BR-040, BR-056)
├── Exclusive group validation (BR-057)
├── Admin remove member + slot release (BR-036)
├── Leave group for Non-Admin (BR-061)
└── invite_type migration (add_patient/add_caregiver)

Phase 4 (Week 4-5): Notifications & Events
├── Kafka events for member lifecycle
├── Member broadcast notifications (BR-052)
├── ZNS template updates (add_patient, add_caregiver)
├── Silent revoke implementation (BR-056)
└── Schedule-service consumer updates

Phase 5 (Week 5-6): Testing & Polish
├── Unit tests (>80% coverage)
├── Integration tests (cross-service)
├── Load tests (slot race conditions)
├── UAT with mobile app
└── Migration validation on staging
```

---

## 2. Technical Recommendations

### 2.1 Database

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Use partial indexes | HIGH | Optimize pending/active queries |
| Auto-create permissions via trigger | HIGH | Ensure 5 perms always exist |
| **Soft disconnect via flag** | **HIGH** | **v4.0:** permission_revoked instead of delete |
| JSONB for initial_permissions | MEDIUM | Flexibility for future changes |
| **Exclusive group unique constraint** | **HIGH** | **v4.0:** DB-enforced 1 user = 1 group (BR-057) |
| **Family group cascade rules** | **HIGH** | **v4.0:** Define ON DELETE behavior |

### 2.2 Service Layer

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Transactional accept flow | HIGH | Ensure atomicity |
| **Auto-connect in transaction** | **HIGH** | **v4.0:** CG accept → N connections atomically |
| Idempotent invite creation | HIGH | Handle retries |
| **Circuit breaker for payment-service** | **HIGH** | **v4.0:** Prevent cascade failure |
| **Admin validation middleware** | **HIGH** | **v4.0:** Centralized Admin check |
| Event sourcing for state changes | MEDIUM | Audit trail, debugging |
| Permission caching | LOW | Performance (defer to later) |

### 2.3 API Design

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Separate invite/connection endpoints | HIGH | Clear resource separation |
| Group connections by role | HIGH | Better mobile UX |
| **Deprecate DELETE /connections** | **HIGH** | **v4.0:** Replace with revoke/remove |
| **Family group endpoints** | **HIGH** | **v4.0:** New resource group |
| Include last_active in response | MEDIUM | Reduce additional calls |
| Use ETags for permissions | LOW | Optimistic locking |

### 2.4 Notifications

| Recommendation | Priority | Rationale |
|----------------|:--------:|-----------|
| Implement retry logic first | HIGH | BR-004 requirement |
| Track delivery status | HIGH | Debugging, metrics |
| **Member broadcast via Kafka** | **HIGH** | **v4.0:** Push to all members (BR-052) |
| **Silent permission changes** | **HIGH** | **v4.0:** No notification (BR-056) |
| Abstract notification channel | MEDIUM | Easy to add channels |
| Rate limit per user | MEDIUM | Prevent spam |

---

## 3. Testing Strategy

| Test Type | Coverage Target | Focus Area |
|-----------|:---------------:|------------|
| Unit Tests | >80% | Business logic, validation, Admin checks |
| Integration Tests | Core flows | End-to-end invite/accept, auto-connect |
| **Cross-service Tests** | **Key flows** | **v4.0:** Slot check → invite → accept → broadcast |
| Load Tests | 100 concurrent | Slot race conditions, auto-connect fan-out |
| Security Tests | Auth/authz | Admin-only operations, exclusive group |
| **Migration Tests** | **invite_type** | **v4.0:** Verify invite_type migration correctness |

---

## 4. Monitoring Recommendations

| Metric | Alert Threshold | Action |
|--------|:---------------:|--------|
| Invite creation rate | >100/min | Investigate potential abuse |
| ZNS failure rate | >10% | Check ZNS service |
| Accept latency (p95) | >500ms | Optimize auto-connect query |
| Orphan invites | >100 | Review expiration logic |
| **payment-service error rate** | **>5%** | **Check gRPC connectivity** |
| **Slot mismatch** | **Any** | **Reconcile slot counts** |
| **Auto-connect failures** | **Any** | **Manual remediation alert** |

---

## 5. Documentation Requirements

| Document | Owner | Due |
|----------|-------|-----|
| API Documentation (Swagger) | Gateway Team | Phase 2 |
| Proto Documentation | Backend Team | Phase 2 |
| **Service Mapping** | **SA** | **Phase 1 ✅** |
| User Guide | PM | Phase 5 |
| Runbook | DevOps | Phase 5 |

---

## 6. Action Items Before Start

| # | Action | Owner | Due |
|---|--------|-------|-----|
| 1 | Submit ZNS templates for approval (add_patient, add_caregiver) | DevOps | Day 1 |
| 2 | Verify deep link infrastructure | Mobile | Week 1 |
| 3 | Create DB migration PR (family_groups + members) | Backend | Day 2 |
| 4 | Allocate Kafka topics (member lifecycle) | DevOps | Day 1 |
| 5 | **Verify payment-service GetSubscription RPC** | **Backend** | **Day 1** |
| 6 | **Configure gRPC channel user-service → payment-service** | **DevOps** | **Day 1** |
| 7 | **Plan invite_type data migration** | **Backend** | **Week 1** |
