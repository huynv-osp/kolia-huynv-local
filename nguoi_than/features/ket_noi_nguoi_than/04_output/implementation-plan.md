# Implementation Plan: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Output  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0  
> **Revision:** v4.0 - 5-phase, 20 tasks, ~80h, 5 services

---

## 1. Architecture Overview

```
┌──────────────┐  REST   ┌────────────────┐  gRPC  ┌───────────────┐
│   Mobile App │ ──────→ │ api-gateway    │ ─────→ │ user-service  │
└──────────────┘         └────────────────┘        └───────┬───────┘
                                                           │ gRPC
                                                    ┌──────▼───────┐
                                                    │payment-service│
                                                    └──────────────┘
                                                           │ Kafka
                         ┌────────────────┐        ┌──────▼───────┐
                         │ auth-service   │ ─gRPC→ │schedule-service│
                         │ (backfill)     │        │ (notifications)│
                         └────────────────┘        └──────────────┘
```

---

## 2. Service Responsibilities (5)

| Service | Impact | Effort | Key Responsibility |
|---------|:------:|:------:|-------------------|
| user-service | 🔴 HIGH | ~30h | Family Group, connections, permissions, auto-connect, soft disconnect |
| api-gateway-service | 🔴 HIGH | ~20h | REST endpoints (14), DTO routing |
| payment-service | 🟡 MEDIUM | ~10h | Slot check, GetSubscription |
| schedule-service | 🟡 MEDIUM | ~10h | Member broadcast, ZNS/Push |
| auth-service | 🟢 LOW | ~5h | Backfill receiver_id |

---

## 3. Implementation Phases

### Phase 0: Database & Foundation (~12h)

| Task | Description | Service | Effort |
|------|-------------|---------|:------:|
| TASK-001 | DB migration (family_groups, family_group_members, ALTER UEC, invite_type) | user-service | 4h |
| TASK-002 | FamilyGroup, FamilyGroupMember entities + repositories | user-service | 4h |
| TASK-003 | FamilyGroupService (group lifecycle management) | user-service | 4h |

### Phase 1: Core Business Logic (~18h)

| Task | Description | Service | Effort | Depends |
|------|-------------|---------|:------:|:-------:|
| TASK-004 | Admin-only invite validation + self-add | user-service | 3h | TASK-003 |
| TASK-005 | PaymentServiceClient (slot check gRPC) | user-service | 3h | TASK-002 |
| TASK-006 | Auto-connect on CG accept (→ ALL patients) | user-service | 4h | TASK-004,005 |
| TASK-007 | Soft disconnect (permission_revoked revoke/restore) | user-service | 4h | TASK-002 |
| TASK-008 | Leave group + Admin remove member | user-service | 4h | TASK-003,005 |

### Phase 2: API Layer (~20h)

| Task | Description | Service | Effort | Depends |
|------|-------------|---------|:------:|:-------:|
| TASK-009 | Family Group REST endpoints (3) | api-gateway | 6h | TASK-003 |
| TASK-010 | Connection endpoints update (5) | api-gateway | 6h | TASK-004,007 |
| TASK-011 | Deprecated DELETE endpoint migration | api-gateway | 2h | TASK-010 |
| TASK-012 | DTO/Proto definitions update | api-gateway | 6h | TASK-009,010 |

### Phase 3: Cross-Service (~15h)

| Task | Description | Service | Effort | Depends |
|------|-------------|---------|:------:|:-------:|
| TASK-013 | Member broadcast notifications | schedule-service | 5h | TASK-006 |
| TASK-014 | ZNS templates (add_patient, add_caregiver) | schedule-service | 3h | TASK-004 |
| TASK-015 | Auth backfill verification | auth-service | 2h | TASK-001 |
| TASK-016 | Payment GetSubscription verification | payment-service | 5h | — |

### Phase 4: Testing (~15h)

| Task | Description | Scope | Effort |
|------|-------------|-------|:------:|
| TASK-017 | Unit tests | user + gateway | 5h |
| TASK-018 | Integration tests | Cross-service | 5h |
| TASK-019 | Regression tests | All | 3h |
| TASK-020 | Data migration tests | Database | 2h |

---

## 4. Key API Changes

### New Endpoints (6)
1. `GET /api/v1/family-groups`
2. `DELETE /api/v1/family-groups/members/:memberId`
3. `PUT /api/v1/connections/:contactId/revoke`
4. `PUT /api/v1/connections/:contactId/restore`
5. `PUT /api/v1/connections/:contactId/relationship`
6. `POST /api/v1/family-groups/leave`

### Modified Endpoints (2)
1. `POST /connections/invite` — phone only, Admin auth
2. `POST /connections/invites/:id/accept` — auto-connect response

### Deprecated (1)
1. ~~`DELETE /connections/:id`~~ → use revoke or remove

---

## 5. Database Changes Summary

| Table | Operation | Key Changes |
|-------|:---------:|-------------|
| `family_groups` | CREATE | admin_user_id, subscription_id, name, status |
| `family_group_members` | CREATE | user_id UNIQUE, role, family_group_id FK |
| `user_emergency_contacts` | ALTER | +permission_revoked, +family_group_id |
| `connection_invites` | ALTER | invite_type CHECK update |

---

## 6. Risk Mitigation

| Risk | Mitigation | Priority |
|------|------------|:--------:|
| Slot race condition | Pessimistic lock + double-check at accept | P0 |
| Payment unavailable | Circuit breaker, graceful fallback | P0 |
| Auto-connect failure | Transaction rollback | P0 |
| SOS regression | contact_type='emergency' unchanged | P0 |
| Silent revoke confusion | Badge "🚫" in CG UI | P1 |

---

## References

- [FA Implementation Tasks v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/02_planning/implementation-tasks.md)
- [SA Implementation Recommendations v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/07_risks/implementation_recommendations.md)
