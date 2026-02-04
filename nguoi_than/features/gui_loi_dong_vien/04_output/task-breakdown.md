# Task Breakdown: US 1.3 - Gửi Lời Động Viên

> **Date:** 2026-02-04  
> **Total Tasks:** 15  
> **Total Effort:** 54 hours

---

## Summary by Service

| Service | Tasks | Hours |
|---------|:-----:|:-----:|
| user-service | 6 | 24h |
| api-gateway | 3 | 10h |
| schedule-service | 2 | 4h |
| Mobile App | 4 | 16h |

---

## Phase 1: Foundation (6h)

| ID | Task | Service | Est. | Deps |
|:--:|------|---------|:----:|:----:|
| DB-001 | Create encouragement_messages table | user-service | 2h | - |
| PROTO-001 | Define encouragement_service.proto | user-service | 2h | - |
| PROTO-002 | Sync proto to api-gateway | api-gateway | 2h | PROTO-001 |

---

## Phase 2: user-service (18h)

| ID | Task | Est. | Deps |
|:--:|------|:----:|:----:|
| ENTITY-001 | Create EncouragementMessage entity | 3h | DB-001 |
| REPO-001 | Create EncouragementRepository | 3h | ENTITY-001 |
| SVC-001 | Create EncouragementService | 6h | REPO-001 |
| GRPC-001 | Create gRPC Handler + Kafka | 4h | SVC-001, PROTO-001 |

---

## Phase 3: api-gateway (10h)

| ID | Task | Est. | Deps |
|:--:|------|:----:|:----:|
| CLIENT-001 | Create gRPC Client | 3h | PROTO-002 |
| HANDLER-001 | Create REST Handler + DTOs | 5h | CLIENT-001 |
| ROUTE-001 | Configure Routes | 2h | HANDLER-001 |

---

## Phase 4: schedule-service (4h)

| ID | Task | Est. | Deps |
|:--:|------|:----:|:----:|
| KAFKA-001 | Create Kafka Consumer | 2h | SVC-001 |
| PUSH-001 | Create Push Notification Task | 2h | KAFKA-001 |

---

## Phase 5: Mobile App (16h)

| ID | Task | Est. | Deps |
|:--:|------|:----:|:----:|
| MOBILE-001 | Create Store & Service | 4h | ROUTE-001 |
| MOBILE-002 | Create Caregiver Widget | 6h | MOBILE-001 |
| MOBILE-003 | Create Patient Modal | 4h | MOBILE-001 |
| MOBILE-004 | Push Handling | 2h | MOBILE-003 |

---

## Critical Path

```
DB-001 → ENTITY-001 → REPO-001 → SVC-001 → GRPC-001 → KAFKA-001 → PUSH-001
  2h        3h          3h         6h         4h          2h         2h
                                                          Total: 22h
```

---

## Parallel Tracks

**Track A (Backend):** DB → Entity → Repo → Service → gRPC  
**Track B (Gateway):** Proto → Sync → Client → Handler → Routes  
**Track C (Scheduler):** Wait for SVC → Consumer → Push  
**Track D (Mobile):** Wait for Routes → Store → Widget/Modal
