# Sequence Diagram: US 1.3 - Gửi Lời Động Viên

> **Phase:** 6 - Dependency & Sequence Planning  
> **Date:** 2026-02-04

---

## 1. Task Dependencies Graph (FA-005)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              TASK DEPENDENCIES                                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────┐                                                                        │
│  │  DB-001  │ Database Migration                                                     │
│  └────┬─────┘                                                                        │
│       │                                                                              │
│       ├────────────────────────────────────────┐                                     │
│       │                                        │                                     │
│       ▼                                        ▼                                     │
│  ┌──────────┐                            ┌───────────┐                               │
│  │ENTITY-001│ Entity                     │ PROTO-001 │ Proto Definition              │
│  └────┬─────┘                            └─────┬─────┘                               │
│       │                                        │                                     │
│       ▼                                        ▼                                     │
│  ┌──────────┐                            ┌───────────┐                               │
│  │ REPO-001 │ Repository                 │ PROTO-002 │ Sync to Gateway               │
│  └────┬─────┘                            └─────┬─────┘                               │
│       │                                        │                                     │
│       ▼                                        ▼                                     │
│  ┌──────────┐                            ┌───────────┐                               │
│  │ SVC-001  │ Service Logic              │ CLIENT-001│ gRPC Client                   │
│  └────┬─────┘                            └─────┬─────┘                               │
│       │                                        │                                     │
│       │                                        ▼                                     │
│       │                                  ┌───────────┐                               │
│       │                                  │HANDLER-001│ REST Handler                  │
│       │                                  └─────┬─────┘                               │
│       │                                        │                                     │
│       ├────────────────────────────────────────┤                                     │
│       │                                        │                                     │
│       ▼                                        ▼                                     │
│  ┌──────────┐                            ┌───────────┐                               │
│  │ GRPC-001 │ gRPC Handler               │ ROUTE-001 │ Config Routes                 │
│  └────┬─────┘                            └─────┬─────┘                               │
│       │                                        │                                     │
│       │                                        ▼                                     │
│       │                                  ┌───────────┐                               │
│       │                                  │MOBILE-001 │ Store & Service               │
│       │                                  └─────┬─────┘                               │
│       │                                        │                                     │
│       │           ┌────────────────────────────┼────────────────────────────┐        │
│       │           │                            │                            │        │
│       │           ▼                            ▼                            ▼        │
│       │    ┌───────────┐               ┌───────────┐                ┌───────────┐    │
│       │    │MOBILE-002 │               │MOBILE-003 │                │MOBILE-004 │    │
│       │    │  Widget   │               │   Modal   │                │Push Handle│    │
│       │    └───────────┘               └───────────┘                └───────────┘    │
│       │                                                                              │
│       ▼                                                                              │
│  ┌──────────┐                                                                        │
│  │ KAFKA-001│ Kafka Consumer                                                         │
│  └────┬─────┘                                                                        │
│       │                                                                              │
│       ▼                                                                              │
│  ┌──────────┐                                                                        │
│  │ PUSH-001 │ Push Notification                                                      │
│  └──────────┘                                                                        │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Parallel Execution Tracks

```
Week 1                              Week 2
─────────────────────────────────────────────────────────────────
Track A (Backend):
  DB-001 → ENTITY-001 → REPO-001 → SVC-001 → GRPC-001
    2h        3h           3h         6h         4h    (18h)

Track B (Gateway):
  PROTO-001 → PROTO-002 → CLIENT-001 → HANDLER-001 → ROUTE-001
     2h          1h           3h           5h           2h   (13h)

Track C (Scheduler):
  ────────────────────────→ KAFKA-001 → PUSH-001
                               2h          2h    (4h)

Track D (Mobile):
  ─────────────────────────────→ MOBILE-001 → MOBILE-002/003/004
                                     4h            12h       (16h)
```

---

## 3. Critical Path

```
DB-001 → ENTITY-001 → REPO-001 → SVC-001 → GRPC-001 → KAFKA-001 → PUSH-001
  2h        3h          3h         6h         4h          2h         2h
                                                                    ═══════
                                                            Total: 22 hours
```

---

## 4. Sequence Diagrams

### 4.1 Create Encouragement (Caregiver → Patient)

```
┌──────────┐     ┌─────────────┐     ┌────────────┐     ┌─────────────┐     ┌────────────┐
│  Mobile  │     │ API Gateway │     │user-service│     │schedule-svc │     │   FCM      │
│(Caregiver)│     │             │     │            │     │             │     │            │
└────┬─────┘     └──────┬──────┘     └─────┬──────┘     └──────┬──────┘     └─────┬──────┘
     │                  │                  │                   │                  │
     │ POST /encouragements               │                   │                  │
     │─────────────────>│                  │                   │                  │
     │                  │                  │                   │                  │
     │                  │ gRPC CreateEnc   │                   │                  │
     │                  │─────────────────>│                   │                  │
     │                  │                  │                   │                  │
     │                  │                  │ Check Permission #6                  │
     │                  │                  │──────────┐        │                  │
     │                  │                  │          │        │                  │
     │                  │                  │<─────────┘        │                  │
     │                  │                  │                   │                  │
     │                  │                  │ Check Quota <10   │                  │
     │                  │                  │──────────┐        │                  │
     │                  │                  │          │        │                  │
     │                  │                  │<─────────┘        │                  │
     │                  │                  │                   │                  │
     │                  │                  │ INSERT INTO DB    │                  │
     │                  │                  │──────────┐        │                  │
     │                  │                  │          │        │                  │
     │                  │                  │<─────────┘        │                  │
     │                  │                  │                   │                  │
     │                  │                  │ Kafka: topic-enc-created             │
     │                  │                  │──────────────────>│                  │
     │                  │                  │                   │                  │
     │                  │  EncouragementResponse               │                  │
     │                  │<─────────────────│                   │                  │
     │                  │                  │                   │                  │
     │ 201 Created      │                  │                   │                  │
     │<─────────────────│                  │                   │                  │
     │                  │                  │                   │                  │
     │                  │                  │                   │ send_push        │
     │                  │                  │                   │─────────────────>│
     │                  │                  │                   │                  │
     │                  │                  │                   │                  │
     │                  │                  │           ┌───────│──────────────────│
     │                  │                  │           │       │            Push to Patient
     │                  │                  │           │       │                  │
     │                  │                  │           ▼       │                  │
     │                  │                  │  ┌──────────────┐ │                  │
     │                  │                  │  │Mobile Patient│<┘                  │
     │                  │                  │  │ReceivePush   │                    │
     │                  │                  │  └──────────────┘                    │
```

---

### 4.2 Get Encouragement List (Patient)

```
┌──────────┐     ┌─────────────┐     ┌────────────┐     ┌────────────┐
│  Mobile  │     │ API Gateway │     │user-service│     │ PostgreSQL │
│(Patient) │     │             │     │            │     │            │
└────┬─────┘     └──────┬──────┘     └─────┬──────┘     └─────┬──────┘
     │                  │                  │                  │
     │ GET /encouragements                 │                  │
     │─────────────────>│                  │                  │
     │                  │                  │                  │
     │                  │ gRPC GetList     │                  │
     │                  │─────────────────>│                  │
     │                  │                  │                  │
     │                  │                  │ SELECT WHERE     │
     │                  │                  │ patient_id AND   │
     │                  │                  │ sent_at > 24h    │
     │                  │                  │─────────────────>│
     │                  │                  │                  │
     │                  │                  │      Results     │
     │                  │                  │<─────────────────│
     │                  │                  │                  │
     │                  │ EncListResponse  │                  │
     │                  │<─────────────────│                  │
     │                  │                  │                  │
     │ 200 OK (messages)│                  │                  │
     │<─────────────────│                  │                  │
```

---

## 5. Milestone Schedule

| Milestone | Tasks | End Date | Owner |
|-----------|-------|----------|-------|
| M1: DB Ready | DB-001 | Day 1 | Backend |
| M2: Proto Ready | PROTO-001, PROTO-002 | Day 1 | Backend |
| M3: user-service Complete | ENTITY→GRPC | Day 4 | Backend |
| M4: Gateway Complete | CLIENT→ROUTE | Day 5 | Backend |
| M5: Push Working | KAFKA→PUSH | Day 6 | Backend |
| M6: Mobile Complete | MOBILE-001→004 | Day 8 | Mobile |
| M7: Integration Test | All | Day 9 | QA |

---

## Next Phase

➡️ Proceed to Phase 7: Review & Confirmation
